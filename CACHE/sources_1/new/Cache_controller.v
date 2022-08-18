`timescale 1ns / 1ps

module Cache_controller#(
    parameter block_size = 128
    )
    (
        input clk_i,
        input mem_clk_i,
        input rst_i,
        input [127:0] L2_data_block_p1_i,
        input [18:0] L1_data_addr_i,
        input [18:0] L1_instr_addr_i,
        input L2_p1_hit_i,
        input L2_p2_hit_i,
        input L1_data_hit_i,
        input L1_instr_hit_i,
        input L1_miss_next_i,
        input read_instr_i,
        input read_data_i,
        input write_data_i,
        input [2:0] DATA_write_instruction_i, 
        output reg write_L2_o, 
        output reg L1_instr_write_o,
        output reg L2_read_p1_o,
        output reg L2_read_p2_o,
        output reg L2_write_p1_o,
        output reg L2_write_p2_o,
        output reg [15:0] L2_byte_enable_p1_o,
        output reg [15:0] L2_byte_enable_p2_o,
        output [18:0] L2_p2_addr_o,
        output [31:0] ram_data_o,
        output [31:0] ram_read_addr_o,
        output [31:0] ram_write_addr_o,
        output ram_read_o,
        output miss_o,
        output ram_write_start_o,
        output reg write_next_o,
        output reg [3:0] wr_strb_o,
        output reg read_data_o,
        output reg read_instr_o,
        output reg write_data_o,
        output reg write_through_o, 
        output reg instr_write_start_o
        );
    // State for Instruction Cache Control
    reg [3:0] state_instr;
    parameter state_instr_idle                  = 4'd0,  // idle state waiting for read instruction input, if there is a read go into state_instr_read
              state_instr_read                  = 4'd1,  // read state decides if there is a hit or there is a miss and read L2, if there is a hit go state_data_idle else go state_instr_miss_L2_step0
              state_instr_miss_L1_step0         = 4'd2,  // read L2 signal will be read on next state, this is delay state, go into state state_instr_miss_L1_step0
              state_instr_miss_L1_step1         = 4'd3,  // read L2 signal and decides if there is a hit or start main memory transfer, if L1 hit go into state_instr_hit_L2_step0 if not go into state_instr_miss_L2_s
              state_instr_hit_L2_step0          = 4'd4,  // there is a hit in L2, start writing into L1 instr cache, blockram will write 64 bits at once max step0, go into state_instr_hit_L2_step1
              state_instr_hit_L2_step1          = 4'd5,  // there is a hit in L2, start writing into L1 instr cache, blockram will write 64 bits at once max step1, if L1 hit go into state_instr_idle
              state_instr_miss_L2_step0         = 4'd6,  // main memory transfer [31:0],wait for memory done signals if instr is using memory and done signal then go into state_instr_miss_L2_step0
              state_instr_miss_L2_step1         = 4'd7,  // main memory transfer [63:32], wait for memory done signals if instr is using memory and done signal then go into state_instr_miss_L2_step1
              state_instr_miss_L2_step2         = 4'd8,  // main memory transfer [95:64], wait for memory done signals if instr is using memory and done signal then go into state_instr_miss_L2_step2
              state_instr_miss_L2_step3         = 4'd9,  // main memory transfer [127:96], wait for memory done signals if instr is using memory and done signal then go into state_instr_miss_L2_done_step0
              state_instr_miss_L2_done_step0    = 4'd10, // main memory transfer is done, start writing into L1 instr cache, blockram will write 64 bits at once max step0, go into state_instr_miss_L2_done_step1
              state_instr_miss_L2_done_step1    = 4'd11; // main memory transfer is done, start writing into L1 instr cache, blockram will write 64 bits at once max step1, if hit go into state_instr_idle
    reg miss_L1_instr;           // indicates that there is a miss in L1_instr (output from FSM)
    reg main_mem_transfer_instr; // indicates that main memory will be used for instruction cache
    reg transfer_instr_step1;    // step 1 for instruction transfer is done
    reg transfer_instr_step2;    // step 2 for instruction transfer is done
    reg transfer_instr_step3;    // step 3 for instruction transfer is done
    reg ram_write_start_instr_o; // First write signal for L2 cache from instruction, for replacement algorithm
    
    // State for Data Cache Control & Registers
    reg [4:0] state_data;
    parameter state_data_idle                   = 5'd0, // idle state looking for read or write instruction, if read go into state_data_read, if write go into state_data_write_step0
              state_data_read                   = 5'd1, // data read state looking if there is a hit or not if there is a hit go into state_data_idle, if not go into state_data_miss_L1_step0 and look into L2 cache
              state_data_miss_L1_step0          = 5'd2, // read L2 signal will be read on next state, this is delay state, go into state state_data_miss_L1_step1
              state_data_miss_L1_step1          = 5'd3, // if there is a hit go into state state_data_hit_L2_step0 if there is not go into state_data_miss_L2_step0
              state_data_hit_L2_step0           = 5'd4, // there is a hit in L2, start writing into L1 data cache, blockram will write 64 bits at once max step0, go into state_data_hit_L2_step1
              state_data_hit_L2_step1           = 5'd5, // there is a hit in L2, start writing into L1 data cache, blockram will write 64 bits at once max step1, if L1 hit go into state_data_idle
              state_data_miss_L2_step           = 5'd6,  // wait before memory transfer in case instruction is trying to read and do not conflict go into state state_data_miss_L2_step0
              state_data_miss_L2_step0          = 5'd7, // main memory transfer [31:0],wait for memory done signals if data is using memory and done signal then go into state_data_miss_L2_step0
              state_data_miss_L2_step1          = 5'd8, // main memory transfer [63:32], wait for memory done signals if data is using memory and done signal then go into state_data_miss_L2_step1
              state_data_miss_L2_step2          = 5'd9, // main memory transfer [95:64], wait for memory done signals if data is using memory and done signal then go into state_data_miss_L2_step2
              state_data_miss_L2_step3          = 5'd10,// main memory transfer [127:96], wait for memory done signals if data is using memory and done signal then go into state_data_miss_L2_done_step0
              state_data_miss_L2_done_step0     = 5'd11,  // main memory transfer is done, start writing into L1 instr cache, blockram will write 64 bits at once max step0, go into state_data_miss_L2_done_step1
              state_data_miss_L2_done_step1     = 5'd12,  // main memory transfer is done, start writing into L1 instr cache, blockram will write 64 bits at once max step1, if hit go into state_data_idle
              state_data_write_step0            = 5'd13,  // state to stabilize reading to decide write on which set go into state_data_write_step1
              state_data_write_step1            = 5'd14,  // state to decide if written address is read before in L1 if it is not after write to main memory is done it will be read back, enable write signals  go into state_data_writethrough_step0
              state_data_writethrough_step0     = 5'd15,  // because blockram is being used 2 states for data transfer go into state_data_writethrough_step1
              state_data_writethrough_step1     = 5'd16,  // because blockram is being used 2 states for data transfer, data written into L1 data, go into state_data_writethrough_step2
              state_data_writethrough_step2     = 5'd17,  // write data into L2 cache from L1 data first 64 bit go inot state_data_writethrough_step3
              state_data_writethrough_step3     = 5'd18,  // write data into L2 cache from L1 data last 64 bit go into state_data_writethrough_step4
              state_data_writethrough_step4     = 5'd19,  // read data from L2, go into state state_data_writethrough_step5
              state_data_writethrough_step5     = 5'd20,  // stabilise read data from L2 if it is not done on step4, go into state_data_writethrough_step6
              state_data_writethrough_step6     = 5'd21,  // start writing data and give output signals to main memory, if instruction is SD go into state_data_writethrough_SD, if not go into state_data_writethrough_done
              state_data_writethrough_SD        = 5'd22,  // if instrution is SD (Store Data Word), because main memory can be written 32 bit once, transfer last 32 bits, wait for transfer done signal and if it is done go into state state_data_writethrough_done
              state_data_writethrough_done      = 5'd23;  // wait for transfer done if it is done and if there were miss in state state_data_write_step1 then go into state_data_miss_L1_step1 if not then go into state_data_idle 
              parameter SB = 3'b000, // Store byte instruction 
              SH = 3'b001, // Store half-word instruction 
              SW = 3'b010, // Store word instruction 
              SD = 3'b011; // Store double-word instruction
    reg miss_L1_data; // indicates that there is a miss in L1_data (output from FSM)
    reg main_mem_transfer_data; // indicates that main memory will be used for data cache 
    reg transfer_data_step1; // step 1 for data transfer is done// 
    reg transfer_data_step2; // step 2 for data transfer is done
    reg transfer_data_step3; // step 3 for data transfer is done
    reg ram_write_start_data_o; // First write signal for L2 cache from data, for replacement algorithm
    reg write_through_miss; // write through miss occurs when writing into an address that does not exist in L1 data cache
    reg start_write_transfer; // start write transfer 
    reg start_write_transfer2; // start write transfer2 if instruction was SD first 32 bits been transferred now transfer other 32 bits
    // State for Main Memory Transfer (While Reading instruction or data)
    reg [2:0] state_main_mem;
    parameter state_main_mem_idle          = 3'd0, // idle waiting for instruction or data transfer
              state_main_mem_transfer_0    = 3'd1, // main memory transfer [31:0],   wait for done signals from instruction or data cache controller
              state_main_mem_transfer_1    = 3'd2, // main memory transfer [63:32],  wait for done signals from instruction or data cache controller
              state_main_mem_transfer_2    = 3'd3, // main memory transfer [95:64],  wait for done signals from instruction or data cache controller
              state_main_mem_transfer_3    = 3'd4; // main memory transfer [127:96], wait for done signals from instruction or data cache controller
    reg main_mem_done; // memory transfer is done
    reg main_mem_done_step0; // memory transfer transfer 0 is done
    reg main_mem_done_step1; // memory transfer transfer 1 is done
    reg main_mem_done_step2; // memory transfer transfer 2 is done
    // State for Main Memory Usage Control (Because only one read port on main memory)
    reg [1:0] state_main_mem_usage;
    parameter state_main_mem_usage_idle       = 2'd0, // wait for instruction or data transfer
              state_main_mem_usage_instr      = 2'd1, // instruction is being used state
              state_main_mem_usage_data       = 2'd2; // data is being used state
    reg transfer_data;  // data transfer is being done by main memory
    reg transfer_instr; // instruction transfer is being done by main memory
    // State for Main Memory Write Control
    reg [1:0] state_main_mem_write;
    parameter   state_main_mem_write_idle          = 2'd0,  // waiting for write transfer signal
                state_main_mem_write_transfer_SD   = 2'd1,  // SD is instruction transfer MSB 32 bits
                state_main_mem_write_transfer_done = 2'd2;   // write transfer is done
    reg main_mem_write_step1_done; // if instruction is SD and first 32 bit write is done
    reg main_mem_write_done;  // write transfer is done
    // Registers for L2
    reg [18:0] ram_addr_L2_instr;  // L2 instr address port
    reg [18:0] ram_addr_L2_data;  // L2 data address port
    reg [18:0] ram_addr_L2_data_write; // ram write address
    //
    assign ram_data_o = (ram_write_addr_o[3:2] == 2'b11) ? L2_data_block_p1_i[127:96] : 
                        ((ram_write_addr_o[3:2] == 2'b10) ? L2_data_block_p1_i[95:64] : 
                        ((ram_write_addr_o[3:2] == 2'b01) ? L2_data_block_p1_i[63:32] : L2_data_block_p1_i[31:0]));
    assign ram_read_o       = main_mem_transfer_instr | main_mem_transfer_data;
    assign ram_write_addr_o = {13'b0100_0000_0000_0,ram_addr_L2_data_write};  // from specification ram address is being arranged
    assign ram_read_addr_o  = transfer_instr == 1 ? {13'b0100_0000_0000_0,ram_addr_L2_instr} : {13'b0100_0000_0000_0,ram_addr_L2_data}; // decide on which address will be used for ram
    assign miss_o = miss_L1_instr | miss_L1_data | (~L1_data_hit_i & (read_data_i | read_data_o)) | (~L1_instr_hit_i & (read_instr_i | read_instr_o)); // miss output
    assign L2_p2_addr_o = ((L1_instr_hit_i & L1_miss_next_i)) == 1'b1 ? (L1_instr_addr_i + 2'b10) : L1_instr_addr_i; // L2 address being decided if there is a miss next it will be next idx address
    assign ram_write_start_o = ram_write_start_instr_o | ram_write_start_data_o;
    //


    always @(posedge clk_i) begin // main memoryden okuma sirasini belirlemek icin yapilan state machine
        if(rst_i) begin
            transfer_instr       <= 1'b0;
            transfer_data        <= 1'b0;
            state_main_mem_usage <= state_main_mem_usage_idle;
        end
        else begin
            case(state_main_mem_usage)
            state_main_mem_usage_idle: begin
                if(main_mem_transfer_instr) begin
                    transfer_instr       <= 1'b1;
                    transfer_data        <= 1'b0;
                    state_main_mem_usage <= state_main_mem_usage_instr;
                end
                else if(main_mem_transfer_data) begin
                    transfer_data        <= 1'b1;
                    transfer_instr       <= 1'b0;
                    state_main_mem_usage <= state_main_mem_usage_data;
                end
            end

            state_main_mem_usage_instr: begin
                if(main_mem_transfer_instr) begin
                    transfer_instr       <= 1'b1;
                    transfer_data        <= 1'b0;
                    state_main_mem_usage <= state_main_mem_usage_instr;
                end
                else begin
                    transfer_data        <= 1'b0;
                    transfer_instr       <= 1'b0;
                    state_main_mem_usage <= state_main_mem_usage_idle;
                end
            end

            state_main_mem_usage_data: begin
                if(main_mem_transfer_data) begin
                    transfer_data        <= 1'b1;
                    transfer_instr       <= 1'b0;
                    state_main_mem_usage <= state_main_mem_usage_data;
                end
                else begin
                    transfer_data        <= 1'b0;
                    transfer_instr       <= 1'b0;
                    state_main_mem_usage <= state_main_mem_usage_idle;
                end
            end
            default: state_main_mem_usage <= state_main_mem_usage_idle;
            endcase
        end
    end

    always @(posedge clk_i) begin // instruction cache control
        if(rst_i) begin
            read_instr_o        <= 1'b0;
            L2_read_p2_o        <= 1'b0;
            miss_L1_instr       <= 1'b0;
            write_next_o        <= 1'b0;
            L1_instr_write_o    <= 1'b0;
            transfer_instr_step1 <= 1'b0;
            transfer_instr_step2 <= 1'b0;
            transfer_instr_step3 <= 1'b0;
            ram_write_start_instr_o   <= 1'b0;
            main_mem_transfer_instr   <= 1'b0;
            L2_write_p2_o       <= 1'b0;
            state_instr         <= state_instr_idle;
        end
        else begin
            case(state_instr)
                state_instr_idle: begin // idle state read var mi diye bakiyor surekli
                    if(read_instr_i) begin // read_instr_reg_o
                        read_instr_o            <= 1'b1;
                        state_instr             <= state_instr_read;
                    end
                    else begin
                        read_instr_o        <= 1'b0;
                        L2_read_p2_o        <= 1'b0;
                        miss_L1_instr       <= 1'b0;
                        write_next_o        <= 1'b0;
                        L1_instr_write_o    <= 1'b0;
                        main_mem_transfer_instr   <= 1'b0;
                        L2_write_p2_o       <= 1'b0;
                        ram_write_start_instr_o   <= 1'b0;
                        state_instr         <= state_instr_idle;
                    end
                end


                state_instr_read: begin // read varsa buraya geliyor.
                    if(L1_instr_hit_i & ~L1_miss_next_i) begin // basarili sekilde okundu
                        miss_L1_instr <= 1'b0;
                        state_instr   <= state_instr_idle;
                        read_instr_o  <= 1'b0;
                    end
                    else begin // L1_instr cache'de miss
                        if(L1_instr_hit_i & L1_miss_next_i) begin // Eger ki miss_next ise write_next_o'yu 1'e cek sonraki adrese yazilsin. (L1_instr_hit_i eklendi cunku bir turlu jump
                                                                  // ile o kosul olusturulursa hata olucak normal adresste miss olmasina ragmen yine sonraki adrese yazilacak.)
                            write_next_o     <= 1'b1;
                        end
                        read_instr_o      <= 1'b1;
                        miss_L1_instr     <= 1'b1;
                        L2_read_p2_o      <= 1'b1;  
                        state_instr       <= state_instr_miss_L1_step0;
                    end
                end

                state_instr_miss_L1_step0: begin // 1 clock cycle gecikme ile datayi daha stabil hale getirmek icin
                    state_instr <= state_instr_miss_L1_step1;
                end

                state_instr_miss_L1_step1: begin // L1_instr cache'de miss olmus.
                    if(L2_p2_hit_i) begin // data L2'de var. L2'den L1'e yazma yapilacak.
                        L1_instr_write_o <= 1'b1;
                        instr_write_start_o <= 1'b1;
                        state_instr      <= state_instr_hit_L2_step0;
                    end
                    else if(~transfer_data) begin // L2'de de miss, Eger ki Data cache'de de onceden miss varsa ve main memory'yi kullaniyorsa girme bekle.
                        main_mem_transfer_instr   <= 1'b1; // instruction'dan main memory'ye transfer yapilacagini belirtir.
                        L2_write_p2_o             <= 1'b1; // L2'nin 2.portunun yazma sinyalini ac.
                        L2_byte_enable_p2_o       <= 16'h000F;
                        ram_write_start_instr_o   <= 1'b1;
                        ram_addr_L2_instr         <= L2_p2_addr_o & 19'b111_1111_1111_1111_0000;
                        state_instr               <= state_instr_miss_L2_step0;
                    end
                end
                
                state_instr_hit_L2_step0: begin
                    instr_write_start_o <= 1'b0;
                    state_instr      <= state_instr_hit_L2_step1;
                end

                state_instr_hit_L2_step1: begin 
                    L1_instr_write_o <= 1'b0;
                    instr_write_start_o <= 1'b0;
                    if(L1_instr_hit_i) begin
                        miss_L1_instr    <= 1'b0;
                        write_next_o     <= 1'b0;
                        read_instr_o     <= 1'b0;
                        state_instr      <= state_instr_idle;
                    end
                end
                
                state_instr_miss_L2_step0: begin
                    ram_write_start_instr_o   <= 1'b0;
                    if(main_mem_done_step0 & transfer_instr) begin
                        ram_addr_L2_instr       <= ram_addr_L2_instr + 3'b100;
                        L2_byte_enable_p2_o     <= 16'h00F0;
                        transfer_instr_step1    <= 1'b1;
                        state_instr             <= state_instr_miss_L2_step1;
                    end
                end

                state_instr_miss_L2_step1: begin
                    if(main_mem_done_step1 & transfer_instr) begin
                        ram_addr_L2_instr       <= ram_addr_L2_instr + 3'b100;
                        L2_byte_enable_p2_o     <= 16'h0F00;
                        transfer_instr_step1    <= 1'b0;
                        transfer_instr_step2    <= 1'b1;
                        state_instr             <= state_instr_miss_L2_step2;
                    end
                end

                state_instr_miss_L2_step2: begin
                    if(main_mem_done_step2 & transfer_instr) begin
                        ram_addr_L2_instr       <= ram_addr_L2_instr + 3'b100;
                        L2_byte_enable_p2_o     <= 16'hF000;
                        transfer_instr_step2    <= 1'b0;
                        transfer_instr_step3    <= 1'b1;
                        state_instr             <= state_instr_miss_L2_step3;
                    end
                end

                state_instr_miss_L2_step3: begin
                    if(main_mem_done & transfer_instr) begin
                        ram_addr_L2_instr         <= L1_instr_addr_i;
                        L2_write_p2_o             <= 1'b0;
                        main_mem_transfer_instr   <= 1'b0;
                        transfer_instr_step3      <= 1'b0;
                        L2_byte_enable_p2_o       <= 16'h0000;
                        L1_instr_write_o          <= 1'b1;
                        instr_write_start_o <= 1'b1;

                        state_instr               <= state_instr_miss_L2_done_step0;
                    end
                end

                state_instr_miss_L2_done_step0: begin
                    instr_write_start_o <= 1'b0;
                    state_instr               <= state_instr_miss_L2_done_step1;
                end

                state_instr_miss_L2_done_step1: begin
                    L1_instr_write_o <= 1'b0;
                    instr_write_start_o <= 1'b0;
                    if(L1_instr_hit_i & ~L1_miss_next_i) begin
                        miss_L1_instr    <= 1'b0;
                        read_instr_o     <= 1'b0;
                        write_next_o     <= 1'b0;
                        state_instr      <= state_instr_idle;
                    end
                end

                default: state_instr <= state_instr_idle;
            endcase
        end
    end    
 
    always @(posedge mem_clk_i) begin // main memory okuma yaparken senkronizasyon amacli state machine
        if(rst_i) begin
            state_main_mem <= state_main_mem_idle;
            main_mem_done  <= 1'b0;
            main_mem_done_step0 <= 1'b0;
            main_mem_done_step1 <= 1'b0;
            main_mem_done_step2 <= 1'b0;
        end
        else begin
            case(state_main_mem) 
                state_main_mem_idle: begin
                    main_mem_done     <= 1'b0;
                    main_mem_done_step0 <= 1'b0;
                    main_mem_done_step1 <= 1'b0;
                    main_mem_done_step2 <= 1'b0;
                    if(main_mem_transfer_instr | main_mem_transfer_data) begin
                        state_main_mem          <= state_main_mem_transfer_0;
                    end
                end

                state_main_mem_transfer_0: begin
                    main_mem_done_step0 <= 1'b1;
                    if(transfer_data_step1 | transfer_instr_step1) begin
                        state_main_mem      <= state_main_mem_transfer_1;
                    end
                end

                state_main_mem_transfer_1: begin
                    main_mem_done_step0 <= 1'b0;
                    main_mem_done_step1 <= 1'b1;
                    if(transfer_data_step2 | transfer_instr_step2) begin
                        state_main_mem       <= state_main_mem_transfer_2;
                    end
                end

                state_main_mem_transfer_2: begin
                    main_mem_done_step1 <= 1'b0;
                    main_mem_done_step2 <= 1'b1;
                    if(transfer_data_step3 | transfer_instr_step3) begin
                        state_main_mem      <= state_main_mem_transfer_3;
                    end

                end

                state_main_mem_transfer_3: begin
                    if(main_mem_done) begin
                        state_main_mem <= state_main_mem_idle;
                    end
                    main_mem_done_step2 <= 1'b0;
                    main_mem_done       <= 1'b1;
                    //state_main_mem      <= state_main_mem_idle;
                end

                default: state_main_mem <= state_main_mem_idle;
            endcase
        end
    end    
  
    always @(posedge mem_clk_i) begin // main memory yazma yaparken senkronizasyon amacli state machine
        if(rst_i) begin
            state_main_mem_write <= state_main_mem_write_idle;
            main_mem_write_done  <= 1'b0;
        end
        else begin
            case(state_main_mem_write) 
                state_main_mem_write_idle: begin
                    main_mem_write_done <= 1'b0;    
                    if(start_write_transfer) begin
                        if(DATA_write_instruction_i == SD) begin
                            state_main_mem_write      <= state_main_mem_write_transfer_SD;
                        end
                        else begin
                            state_main_mem_write      <= state_main_mem_write_transfer_done;
                        end
                    end
                end
                state_main_mem_write_transfer_SD: begin
                    main_mem_write_step1_done       <= 1'b1;
                    if(start_write_transfer2) begin
                        state_main_mem_write      <= state_main_mem_write_transfer_done;
                    end
                end 
                state_main_mem_write_transfer_done: begin
                    state_main_mem_write        <= state_main_mem_write_idle;
                    main_mem_write_step1_done   <= 1'b0;
                    main_mem_write_done         <= 1'b1;
                end
                default: state_main_mem_write <= state_main_mem_write_idle;
            endcase
        end
    end

    always @(posedge clk_i) begin // data cache control
        if(rst_i) begin
            write_through_miss              <= 1'b0;
            read_data_o                     <= 1'b0;
            L2_read_p1_o                    <= 1'b0;
            miss_L1_data                    <= 1'b0;
            write_L2_o                      <= 1'b0;
            write_through_o                 <= 1'b0;
            L2_byte_enable_p1_o             <= 16'b0;
            main_mem_transfer_data          <= 1'b0;
            L2_write_p1_o                   <= 1'b0;
            wr_strb_o                       <= 4'b0;
            start_write_transfer            <= 1'b0;
            start_write_transfer2           <= 1'b0;
            transfer_data_step1             <= 1'b0;
            transfer_data_step2             <= 1'b0;
            transfer_data_step3             <= 1'b0;
            ram_write_start_data_o          <= 1'b0;
            state_data                      <= state_data_idle;
        end
        else begin
            case(state_data)
            state_data_idle: begin
                if(read_data_i) begin // read_data_reg_o
                    //miss_L1_data                   <= 1'b1;
                    read_data_o                    <= 1'b1;
                    state_data                     <= state_data_read; // eger cpu yavas olcaksa direk state_data_read'e gitmeli
                end
                else if(write_data_i) begin
                    read_data_o                    <= 1'b1;
                    state_data                     <= state_data_write_step0;
                end
                else begin
                    write_through_miss              <= 1'b0;
                    read_data_o                     <= 1'b0;
                    L2_read_p1_o                    <= 1'b0;
                    miss_L1_data                    <= 1'b0;
                    write_L2_o                      <= 1'b0;
                    write_through_o                 <= 1'b0;
                    L2_byte_enable_p1_o             <= 16'b0;
                    main_mem_transfer_data          <= 1'b0;
                    L2_write_p1_o                   <= 1'b0;
                    wr_strb_o                       <= 4'b0;
                    start_write_transfer            <= 1'b0;
                    start_write_transfer2           <= 1'b0;
                    transfer_data_step1             <= 1'b0;
                    transfer_data_step2             <= 1'b0;
                    transfer_data_step3             <= 1'b0;
                    ram_write_start_data_o          <= 1'b0;
                    state_data                      <= state_data_idle;
                end
            end


            state_data_read: begin
                if(L1_data_hit_i) begin
                    miss_L1_data   <= 1'b0;
                    read_data_o    <= 1'b0;
                    state_data     <= state_data_idle;
                end
                else begin
                    L2_read_p1_o  <= 1'b1;
                    read_data_o   <= 1'b1;
                    miss_L1_data  <= 1'b1;
                    state_data    <= state_data_miss_L1_step0;
                end
            end

            state_data_miss_L1_step0: begin
                state_data <= state_data_miss_L1_step1;
            end

            state_data_miss_L1_step1: begin
                if(L2_p1_hit_i & ~write_through_miss) begin // ~write_through miss, yazma yapilmis ve daha once o adres cache'lerde bulunmuyorsa yapilacak bir sey.
                    write_L2_o      <= 1'b1;
                    state_data      <= state_data_hit_L2_step0;
                end
                else if(~transfer_instr & ~((state_instr == state_instr_miss_L1_step1) & ~L2_p2_hit_i))begin // L2'de de miss var. L1 instr cache main memory'yi kullanmiyorsa ve su anda kullanmiyacaksa buraya gir.
                    
                    L2_write_p1_o          <= 1'b1;
                    L2_byte_enable_p1_o    <= 16'h000F;
                    ram_write_start_data_o   <= 1'b1;
                    ram_addr_L2_data       <= L1_data_addr_i & 19'b111_1111_1111_1111_0000; // 
                    state_data             <= state_data_miss_L2_step;
                end
            end

            state_data_hit_L2_step0: begin
                state_data <= state_data_hit_L2_step1;
            end

            state_data_hit_L2_step1: begin
                if(L1_data_hit_i) begin
                    write_L2_o   <= 1'b0;
                    miss_L1_data <= 1'b0;
                    read_data_o  <= 1'b0;
                    state_data   <= state_data_idle;
                end
            end
            state_data_miss_L2_step: begin
                ram_write_start_data_o   <= 1'b0;
                if(~transfer_instr & ~((state_instr == state_instr_miss_L1_step1) & ~L2_p2_hit_i)) begin
                    main_mem_transfer_data <= 1'b1;
                    state_data             <= state_data_miss_L2_step0;
                end
                
            end
            state_data_miss_L2_step0: begin
                ram_write_start_data_o  <= 1'b0;
                if(main_mem_done_step0 & transfer_data) begin
                    ram_addr_L2_data        <= ram_addr_L2_data + 3'b100;
                    L2_byte_enable_p1_o     <= 16'h00F0;
                    transfer_data_step1     <= 1'b1;
                    state_data              <= state_data_miss_L2_step1;
                end
            end

            state_data_miss_L2_step1: begin
                if(main_mem_done_step1 & transfer_data) begin
                    ram_addr_L2_data        <= ram_addr_L2_data + 3'b100;
                    L2_byte_enable_p1_o     <= 16'h0F00;
                    transfer_data_step2     <= 1'b1;
                    transfer_data_step1     <= 1'b0;
                    state_data              <= state_data_miss_L2_step2;
                end
            end

            state_data_miss_L2_step2: begin
                if(main_mem_done_step2 & transfer_data) begin
                    ram_addr_L2_data        <= ram_addr_L2_data + 3'b100;
                    L2_byte_enable_p1_o     <= 16'hF000;
                    transfer_data_step3     <= 1'b1;
                    transfer_data_step2     <= 1'b0;
                    state_data              <= state_data_miss_L2_step3;
                end
            end

            state_data_miss_L2_step3: begin
                if(main_mem_done & transfer_data) begin
                    ram_addr_L2_data        <= L1_data_addr_i & 19'b111_1111_1111_1111_0000;
                    transfer_data_step3     <= 1'b0;
                    main_mem_transfer_data  <= 1'b0;
                    L2_byte_enable_p1_o     <= 16'b0;
                    L2_write_p1_o           <= 1'b0;
                    write_L2_o              <= 1'b1;
                    state_data              <= state_data_miss_L2_done_step0;
                end
            end

            state_data_miss_L2_done_step0: begin
                state_data              <= state_data_miss_L2_done_step1;
            end

            state_data_miss_L2_done_step1: begin
                write_L2_o          <= 1'b0;
                if(L1_data_hit_i) begin
                    miss_L1_data        <= 1'b0;
                    read_data_o         <= 1'b0;
                    write_through_o     <= 1'b0;
                    write_through_miss  <= 1'b0;
                    state_data          <= state_data_idle;
                end
            end

            state_data_write_step0: begin // read'i stable hale getirmek icin olan state
                state_data               <= state_data_write_step1;
            end

            state_data_write_step1: begin
                if(~L1_data_hit_i) begin
                    write_through_miss <= 1'b1;
                    miss_L1_data       <= 1'b1;
                end
                write_through_o          <= 1'b1;
                write_data_o             <= 1'b1;
                state_data               <= state_data_writethrough_step0;
            end

            state_data_writethrough_step0: begin
                state_data      <= state_data_writethrough_step1;
            end
            
            state_data_writethrough_step1: begin
                state_data      <= state_data_writethrough_step2;
            end

            state_data_writethrough_step2: begin
                L2_write_p1_o            <= 1'b1;
                ram_write_start_data_o   <= 1'b1; 
                L2_byte_enable_p1_o      <= 16'hFFFF;
                state_data               <= state_data_writethrough_step3;
            end

            state_data_writethrough_step3: begin
                ram_write_start_data_o  <= 1'b0;
                state_data              <= state_data_writethrough_step4;
            end

            state_data_writethrough_step4: begin
                ram_write_start_data_o   <= 1'b0; 
                L2_write_p1_o            <= 1'b0;
                L2_byte_enable_p1_o      <= 16'h0000;
                L2_read_p1_o             <= 1'b1;
                state_data               <= state_data_writethrough_step5;
            end

            state_data_writethrough_step5: begin
                state_data <= state_data_writethrough_step6;
            end

            state_data_writethrough_step6: begin // L2'den okuma yapildi.
                start_write_transfer     <= 1'b1;
                ram_addr_L2_data_write   <= L1_data_addr_i;
                if(DATA_write_instruction_i == SD) begin 
                    wr_strb_o        <= 4'b1111;
                    state_data       <= state_data_writethrough_SD;
                end
                else if(DATA_write_instruction_i == SW) begin
                    wr_strb_o        <= 4'b1111;
                    state_data       <= state_data_writethrough_done;
                end
                else if(DATA_write_instruction_i == SH) begin
                    if(L1_data_addr_i[1:0] == 2'b00) begin
                        wr_strb_o        <= 4'b0011;
                    end
                    else if(L1_data_addr_i[1:0] == 2'b01) begin
                        wr_strb_o        <= 4'b0110;
                    end
                    else if(L1_data_addr_i[1:0] == 2'b10) begin
                        wr_strb_o        <= 4'b1100;
                    end
                    //else if(L1_data_addr_i[1:0] == 2'b11) begin
                    //    wr_strb_o        <= 4'b1000;
                    //end

                    state_data       <= state_data_writethrough_done;
                end
                else if(DATA_write_instruction_i == SB) begin
                    if(L1_data_addr_i[1:0] == 2'b00) begin
                        wr_strb_o        <= 4'b0001;
                    end
                    else if(L1_data_addr_i[1:0] == 2'b01) begin
                        wr_strb_o        <= 4'b0010;
                    end
                    else if(L1_data_addr_i[1:0] == 2'b10) begin
                        wr_strb_o        <= 4'b0100;
                    end
                    else if(L1_data_addr_i[1:0] == 2'b11) begin
                        wr_strb_o        <= 4'b1000;
                    end
                    state_data       <= state_data_writethrough_done;
                end
            end

            state_data_writethrough_SD: begin // 1 kere daha transfer yapilacagi icin SD yapilirken
                if(main_mem_write_step1_done) begin
                    start_write_transfer      <= 1'b0;
                    ram_addr_L2_data_write    <= ram_addr_L2_data_write + 3'b100;
                    start_write_transfer2     <= 1'b1;
                    state_data                <= state_data_writethrough_done;
                end
            end

            state_data_writethrough_done: begin
                if(main_mem_write_done) begin
                    wr_strb_o               <= 4'b0;
                    ram_addr_L2_data_write  <= L1_data_addr_i;
                    start_write_transfer    <= 1'b0;
                    start_write_transfer2   <= 1'b0;
                    write_data_o            <= 1'b0;
                    if(write_through_miss) begin
                        state_data             <= state_data_miss_L1_step1;
                    end
                    else begin
                        L2_read_p1_o            <= 1'b0;
                        read_data_o             <= 1'b0;
                        write_through_o         <= 1'b0;
                        state_data              <= state_data_idle;
                    end
                end
            end

            default: state_data <= state_data_idle;
            endcase
        end
    end

endmodule
