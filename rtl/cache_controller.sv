`timescale 1ns / 1ps

module cache_controller #(
        parameter ADDR_WIDTH = 19,
        parameter DATA_WIDTH = 64,
        parameter MEM_DATA_WIDTH = 32,
        parameter LINE_WIDTH = 128,
        parameter LINE_BYTE_COUNT = LINE_WIDTH / 8,
        parameter DATA_BYTE_COUNT = DATA_WIDTH / 8,
        parameter MEM_BYTE_COUNT = MEM_DATA_WIDTH / 8,
        parameter LINE_OFFSET_WIDTH = 4,
        parameter L2_ADDR_WIDTH = ADDR_WIDTH - LINE_OFFSET_WIDTH,
        parameter MEMORY_BASE_ADDR = 32'h2000_0000
        ) (
        input clk,
        input rst,
        input ram_req_ready,
        input ram_rsp_valid,
        input [LINE_WIDTH-1:0] l2_data_block_p1,
        input [ADDR_WIDTH-1:0] L1_data_addr,
        input [ADDR_WIDTH-1:0] L1_instr_addr,
        input L2_p1_hit,
        input L2_p2_hit,
        input L1_data_hit,
        input L1_instr_hit,
        input L1_miss_next,
        input instr_request,
        input data_read_request,
        input data_write_request,
        input [DATA_BYTE_COUNT-1:0] data_write_strobe,
        output reg write_L2,
        output reg L1_instr_write,
        output reg L2_read_p1,
        output reg L2_read_p2,
        output reg L2_write_p1,
        output reg L2_write_p2,
        output reg [LINE_BYTE_COUNT-1:0] L2_byte_enable_p1,
        output reg [LINE_BYTE_COUNT-1:0] L2_byte_enable_p2,
        output [L2_ADDR_WIDTH-1:0] L2_p2_addr,
        output [MEM_DATA_WIDTH-1:0] ram_data,
        output [31:0] ram_read_addr,
        output [31:0] ram_write_addr,
        output [7:0] ram_read_beat_index,
        output [7:0] ram_write_beat_index,
        output [7:0] ram_write_burst_len,
        output reg ram_read,
        output miss,
        output ram_write_start,
        output reg write_next,
        output reg [MEM_BYTE_COUNT-1:0] wr_strb,
        output reg data_cache_read,
        output reg instr_cache_read,
        output memory_write,
        output reg write_through,
        output reg instr_write_start
        );
    localparam LINE_MEM_BEAT_COUNT = LINE_WIDTH / MEM_DATA_WIDTH;
    localparam [7:0] LINE_MEM_LAST_BEAT =
        (LINE_MEM_BEAT_COUNT == 1)  ? 8'd0  :
        (LINE_MEM_BEAT_COUNT == 2)  ? 8'd1  :
        (LINE_MEM_BEAT_COUNT == 4)  ? 8'd3  :
        (LINE_MEM_BEAT_COUNT == 8)  ? 8'd7  :
        (LINE_MEM_BEAT_COUNT == 16) ? 8'd15 : 8'd31;
    localparam [ADDR_WIDTH-1:0] MEM_ADDR_STEP =
        (MEM_BYTE_COUNT == 1) ? {{(ADDR_WIDTH-1){1'b0}}, 1'b1} :
        (MEM_BYTE_COUNT == 2) ? {{(ADDR_WIDTH-2){1'b0}}, 2'd2} :
        (MEM_BYTE_COUNT == 4) ? {{(ADDR_WIDTH-3){1'b0}}, 3'd4} :
                                {{(ADDR_WIDTH-4){1'b0}}, 4'd8};
    localparam [LINE_BYTE_COUNT-1:0] MEMORY_BEAT_BYTE_MASK =
        {{(LINE_BYTE_COUNT-MEM_BYTE_COUNT){1'b0}}, {MEM_BYTE_COUNT{1'b1}}};
    localparam MEM_BYTE_OFFSET_WIDTH = $clog2(MEM_BYTE_COUNT);

    // State for Instruction Cache Control
    reg [3:0] state_instr;
    parameter state_instr_idle                  = 4'd0,  // idle state waiting for read instruction input, if there is a read go into state_instr_read
              state_instr_read                  = 4'd1,  // read state decides if there is a hit or there is a miss and read L2, if there is a hit go state_data_idle else go state_instr_miss_L2_step0
              state_instr_miss_L1_step0         = 4'd2,  // read L2 signal will be read on next state, this is delay state, go into state state_instr_miss_L1_step0
              state_instr_miss_L1_step1         = 4'd3,  // read L2 signal and decides if there is a hit or start main memory transfer, if L1 hit go into state_instr_hit_L2_step0 if not go into state_instr_miss_L2_s
              state_instr_hit_L2_step0          = 4'd4,  // there is a hit in L2, start writing into L1 instr cache array step0, go into state_instr_hit_L2_step1
              state_instr_hit_L2_step1          = 4'd5,  // there is a hit in L2, start writing into L1 instr cache array step1, if L1 hit go into state_instr_idle
              state_instr_miss_L2_step0         = 4'd6,  // main memory line fill beat loop
              state_instr_miss_L2_done_step0    = 4'd10, // main memory transfer is done, start writing into L1 instr cache array step0, go into state_instr_miss_L2_done_step1
              state_instr_miss_L2_done_step1    = 4'd11; // main memory transfer is done, start writing into L1 instr cache array step1, if hit go into state_instr_idle
    reg miss_L1_instr;           // indicates that there is a miss in L1_instr (output from FSM)
    reg main_mem_transfer_instr; // indicates that main memory will be used for instruction cache
    reg transfer_instr_step1;    // step 1 for instruction transfer is done
    reg ram_write_start_instr; // First write signal for L2 cache from instruction, for replacement algorithm

    // State for Data Cache Control & Registers
    reg [4:0] state_data;
    parameter state_data_idle                   = 5'd0, // idle state looking for read or write instruction, if read go into state_data_read, if write go into state_data_write_step0
              state_data_read                   = 5'd1, // data read state looking if there is a hit or not if there is a hit go into state_data_idle, if not go into state_data_miss_L1_step0 and look into L2 cache
              state_data_miss_L1_step0          = 5'd2, // read L2 signal will be read on next state, this is delay state, go into state state_data_miss_L1_step1
              state_data_miss_L1_step1          = 5'd3, // if there is a hit go into state state_data_hit_L2_step0 if there is not go into state_data_miss_L2_step0
              state_data_hit_L2_step0           = 5'd4, // there is a hit in L2, start writing into L1 data cache array step0, go into state_data_hit_L2_step1
              state_data_hit_L2_step1           = 5'd5, // there is a hit in L2, start writing into L1 data cache array step1, if L1 hit go into state_data_idle
              state_data_miss_L2_step           = 5'd6,  // wait before memory transfer in case instruction is trying to read and do not conflict go into state state_data_miss_L2_step0
              state_data_miss_L2_step0          = 5'd7, // main memory line fill beat loop
              state_data_miss_L2_done_step0     = 5'd11,  // main memory transfer is done, start writing into L1 data cache array step0, go into state_data_miss_L2_done_step1
              state_data_miss_L2_done_step1     = 5'd12,  // main memory transfer is done, start writing into L1 data cache array step1, if hit go into state_data_idle
              state_data_write_step0            = 5'd13,  // state to stabilize reading to decide write on which set go into state_data_write_step1
              state_data_write_step1            = 5'd14,  // state to decide if written address is read before in L1 if it is not after write to main memory is done it will be read back, enable write signals  go into state_data_writethrough_step0
              state_data_writethrough_step0     = 5'd15,  // first data cache array transfer step, go into state_data_writethrough_step1
              state_data_writethrough_step1     = 5'd16,  // second data cache array transfer step, data written into L1 data, go into state_data_writethrough_step2
              state_data_writethrough_step2     = 5'd17,  // write data into L2 cache from L1 data first 64 bit go inot state_data_writethrough_step3
              state_data_writethrough_step3     = 5'd18,  // write data into L2 cache from L1 data last 64 bit go into state_data_writethrough_step4
              state_data_writethrough_step4     = 5'd19,  // read data from L2, go into state state_data_writethrough_step5
              state_data_writethrough_step5     = 5'd20,  // stabilise read data from L2 if it is not done on step4, go into state_data_writethrough_step6
              state_data_writethrough_step6     = 5'd21,  // start writing data and give output signals to main memory
              state_data_writethrough_SD        = 5'd22,  // transfer upper 32-bit write data when requested byte strobes cross the first memory word
              state_data_writethrough_done      = 5'd23;  // wait for transfer done if it is done and if there were miss in state state_data_write_step1 then go into state_data_miss_L1_step1 if not then go into state_data_idle
    reg miss_L1_data; // indicates that there is a miss in L1_data (output from FSM)
    reg main_mem_transfer_data; // indicates that main memory will be used for data cache
    reg transfer_data_step1; // step 1 for data transfer is done//
    reg ram_write_start_data; // First write signal for L2 cache from data, for replacement algorithm
    reg write_through_miss; // write through miss occurs when writing into an address that does not exist in L1 data cache
    reg start_write_transfer; // start write transfer
    reg start_write_transfer2; // acknowledge that the next write beat is ready
    // State for Main Memory Transfer (While Reading instruction or data)
    reg [2:0] state_main_mem;
    parameter state_main_mem_idle          = 3'd0, // idle waiting for instruction or data transfer
              state_main_mem_transfer_0    = 3'd1, // main memory line fill beat valid
              state_main_mem_transfer_1    = 3'd2, // wait for cache-side beat acknowledge
              state_main_mem_transfer_2    = 3'd3; // allow next read data to settle
    reg main_mem_done_step0; // memory transfer transfer 0 is done
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
                state_main_mem_write_transfer_SD   = 2'd1,  // wait for next write beat
                state_main_mem_write_transfer_done = 2'd2,   // write transfer is done
                state_main_mem_write_wait_next     = 2'd3;   // wait for cache-side next beat valid
    reg main_mem_write_step1_done; // current write beat is done
    reg main_mem_write_done;  // write transfer is done
    // Registers for L2
    reg [ADDR_WIDTH-1:0] ram_addr_L2_instr;  // L2 instr address port
    reg [ADDR_WIDTH-1:0] ram_addr_l2_data;  // L2 data address port
    reg [ADDR_WIDTH-1:0] ram_addr_l2_data_write; // ram write address
    reg [MEM_BYTE_COUNT-1:0] data_write_current_strobe;
    reg [MEM_BYTE_COUNT-1:0] data_write_next_strobe;
    reg [7:0] data_write_last_beat_index;
    reg [7:0] instr_fill_beat_index;
    reg [7:0] data_fill_beat_index;
    reg [7:0] main_mem_read_beat_index;
    reg [7:0] main_mem_write_beat_index;
    reg [7:0] data_write_beat_index;
    reg [LINE_BYTE_COUNT-1:0] instr_next_fill_byte_enable;
    reg [LINE_BYTE_COUNT-1:0] data_next_fill_byte_enable;
    reg [31:0] instr_next_fill_shift;
    reg [31:0] data_next_fill_shift;
    integer data_write_strobe_index;
    integer data_write_byte_index;
    integer data_write_beat_candidate;
    wire [ADDR_WIDTH-1:0] line_addr_mask;
    wire main_mem_read_beat_ack;
    //
    assign ram_data = l2_data_block_p1[(ram_addr_l2_data_write[LINE_OFFSET_WIDTH-1:MEM_BYTE_OFFSET_WIDTH] * MEM_DATA_WIDTH) +: MEM_DATA_WIDTH];
    assign ram_write_addr = MEMORY_BASE_ADDR + {{(32-ADDR_WIDTH){1'b0}}, ram_addr_l2_data_write};  // from specification ram address is being arranged
    assign ram_read_addr  = transfer_instr == 1 ?
                            (MEMORY_BASE_ADDR + {{(32-ADDR_WIDTH){1'b0}}, ram_addr_L2_instr}) :
                            (MEMORY_BASE_ADDR + {{(32-ADDR_WIDTH){1'b0}}, ram_addr_l2_data}); // decide on which address will be used for ram
    assign miss = miss_L1_instr | miss_L1_data |
                  (~L1_data_hit & (data_read_request | data_cache_read)) |
                  (~L1_instr_hit & (instr_request | instr_cache_read)); // miss output
    assign L2_p2_addr = ((L1_instr_hit & L1_miss_next)) == 1'b1 ?
                        (L1_instr_addr[L2_ADDR_WIDTH-1:0] + {{(L2_ADDR_WIDTH-2){1'b0}}, 2'b10}) :
                        L1_instr_addr[L2_ADDR_WIDTH-1:0]; // L2 address being decided if there is a miss next it will be next idx address
    assign ram_write_start = ram_write_start_instr | ram_write_start_data;
    assign line_addr_mask = {ADDR_WIDTH{1'b1}} << LINE_OFFSET_WIDTH;
    assign main_mem_read_beat_ack = transfer_data_step1 | transfer_instr_step1;
    assign ram_read_beat_index = main_mem_read_beat_index;
    assign ram_write_beat_index = data_write_beat_index;
    assign ram_write_burst_len = data_write_last_beat_index + 8'd1;
    assign memory_write =
        ((state_main_mem_write == state_main_mem_write_idle) & start_write_transfer & ~main_mem_write_done) |
        ((state_main_mem_write == state_main_mem_write_transfer_SD) & start_write_transfer2);
    //

    always @(*) begin
        instr_next_fill_shift = (({24'b0, instr_fill_beat_index} + 32'd1) * MEM_BYTE_COUNT);
        data_next_fill_shift = (({24'b0, data_fill_beat_index} + 32'd1) * MEM_BYTE_COUNT);
        instr_next_fill_byte_enable = MEMORY_BEAT_BYTE_MASK << instr_next_fill_shift;
        data_next_fill_byte_enable = MEMORY_BEAT_BYTE_MASK << data_next_fill_shift;

        data_write_current_strobe = {MEM_BYTE_COUNT{1'b0}};
        data_write_next_strobe = {MEM_BYTE_COUNT{1'b0}};
        data_write_last_beat_index = 8'b0;
        for (data_write_strobe_index = 0; data_write_strobe_index < DATA_BYTE_COUNT; data_write_strobe_index = data_write_strobe_index + 1) begin
            data_write_byte_index = data_write_strobe_index;
            data_write_byte_index = data_write_byte_index + (({{(32-ADDR_WIDTH){1'b0}}, L1_data_addr}) % MEM_BYTE_COUNT);
            data_write_beat_candidate = data_write_byte_index / MEM_BYTE_COUNT;
            if (data_write_strobe[data_write_strobe_index]) begin
                if (data_write_beat_candidate == {24'b0, data_write_beat_index}) begin
                    data_write_current_strobe[data_write_byte_index % MEM_BYTE_COUNT] = 1'b1;
                end
                if (data_write_beat_candidate == ({24'b0, data_write_beat_index} + 32'd1)) begin
                    data_write_next_strobe[data_write_byte_index % MEM_BYTE_COUNT] = 1'b1;
                end
                if (data_write_beat_candidate > {24'b0, data_write_last_beat_index}) begin
                    data_write_last_beat_index = data_write_beat_candidate[7:0];
                end
            end
        end
    end

    always @(posedge clk) begin // main memoryden okuma sirasini belirlemek icin yapilan state machine
        if(rst) begin
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

    always @(posedge clk) begin // instruction cache control
        if(rst) begin
            instr_cache_read <= 1'b0;
            L2_read_p2        <= 1'b0;
            miss_L1_instr       <= 1'b0;
            write_next        <= 1'b0;
            L1_instr_write    <= 1'b0;
            transfer_instr_step1 <= 1'b0;
            instr_fill_beat_index <= 8'b0;
            ram_write_start_instr   <= 1'b0;
            main_mem_transfer_instr   <= 1'b0;
            L2_write_p2       <= 1'b0;
            state_instr         <= state_instr_idle;
        end
        else begin
            case(state_instr)
                state_instr_idle: begin // idle state read var mi diye bakiyor surekli
                    if(instr_request) begin // read request
                        instr_cache_read <= 1'b1;
                        state_instr             <= state_instr_read;
                    end
                    else begin
                        instr_cache_read <= 1'b0;
                        L2_read_p2        <= 1'b0;
                        miss_L1_instr       <= 1'b0;
                        write_next        <= 1'b0;
                        L1_instr_write    <= 1'b0;
                        main_mem_transfer_instr   <= 1'b0;
                        L2_write_p2       <= 1'b0;
                        ram_write_start_instr   <= 1'b0;
                        state_instr         <= state_instr_idle;
                    end
                end


                state_instr_read: begin // read varsa buraya geliyor.
                    if(L1_instr_hit & ~L1_miss_next) begin // basarili sekilde okundu
                        miss_L1_instr <= 1'b0;
                        state_instr   <= state_instr_idle;
                        instr_cache_read <= 1'b0;
                    end
                    else begin // L1_instr cache'de miss
                        if(L1_instr_hit & L1_miss_next) begin // Eger ki miss_next ise write_next'yu 1'e cek sonraki adrese yazilsin. (L1_instr_hit eklendi cunku bir turlu jump
                                                                  // ile o kosul olusturulursa hata olucak normal adresste miss olmasina ragmen yine sonraki adrese yazilacak.)
                            write_next     <= 1'b1;
                        end
                        instr_cache_read <= 1'b1;
                        miss_L1_instr     <= 1'b1;
                        L2_read_p2      <= 1'b1;
                        state_instr       <= state_instr_miss_L1_step0;
                    end
                end

                state_instr_miss_L1_step0: begin // 1 clock cycle gecikme ile datayi daha stabil hale getirmek icin
                    state_instr <= state_instr_miss_L1_step1;
                end

                state_instr_miss_L1_step1: begin // L1_instr cache'de miss olmus.
                    if(L2_p2_hit) begin // data L2'de var. L2'den L1'e yazma yapilacak.
                        L1_instr_write <= 1'b1;
                        instr_write_start <= 1'b1;
                        state_instr      <= state_instr_hit_L2_step0;
                    end
                    else if(~transfer_data) begin // L2'de de miss, Eger ki Data cache'de de onceden miss varsa ve main memory'yi kullaniyorsa girme bekle.
                        main_mem_transfer_instr   <= 1'b1; // instruction'dan main memory'ye transfer yapilacagini belirtir.
                        L2_write_p2             <= 1'b1; // L2'nin 2.portunun yazma sinyalini ac.
                        instr_fill_beat_index   <= 8'b0;
                        L2_byte_enable_p2       <= MEMORY_BEAT_BYTE_MASK;
                        ram_write_start_instr   <= 1'b1;
                        ram_addr_L2_instr         <= {{(ADDR_WIDTH-L2_ADDR_WIDTH){1'b0}}, L2_p2_addr} & line_addr_mask;
                        state_instr               <= state_instr_miss_L2_step0;
                    end
                end

                state_instr_hit_L2_step0: begin
                    instr_write_start <= 1'b0;
                    state_instr      <= state_instr_hit_L2_step1;
                end

                state_instr_hit_L2_step1: begin
                    L1_instr_write <= 1'b0;
                    instr_write_start <= 1'b0;
                    if(L1_instr_hit) begin
                        miss_L1_instr    <= 1'b0;
                        write_next     <= 1'b0;
                        instr_cache_read <= 1'b0;
                        state_instr      <= state_instr_idle;
                    end
                end

                state_instr_miss_L2_step0: begin
                    ram_write_start_instr   <= 1'b0;
                    if(main_mem_done_step0 & transfer_instr) begin
                        transfer_instr_step1    <= 1'b1;
                        if(instr_fill_beat_index == LINE_MEM_LAST_BEAT) begin
                            ram_addr_L2_instr       <= L1_instr_addr;
                            L2_write_p2             <= 1'b0;
                            main_mem_transfer_instr <= 1'b0;
                            L2_byte_enable_p2       <= {LINE_BYTE_COUNT{1'b0}};
                            state_instr             <= state_instr_miss_L2_done_step0;
                        end else begin
                            instr_fill_beat_index <= instr_fill_beat_index + 8'd1;
                            ram_addr_L2_instr     <= ram_addr_L2_instr + MEM_ADDR_STEP;
                            L2_byte_enable_p2     <= instr_next_fill_byte_enable;
                        end
                    end else begin
                        transfer_instr_step1 <= 1'b0;
                    end
                end

                state_instr_miss_L2_done_step0: begin
                    L1_instr_write    <= 1'b1;
                    instr_write_start <= 1'b1;
                    state_instr       <= state_instr_miss_L2_done_step1;
                end

                state_instr_miss_L2_done_step1: begin
                    L1_instr_write <= 1'b0;
                    instr_write_start <= 1'b0;
                    if(L1_instr_hit & ~L1_miss_next) begin
                        miss_L1_instr    <= 1'b0;
                        instr_cache_read <= 1'b0;
                        write_next     <= 1'b0;
                        state_instr      <= state_instr_idle;
                    end
                end

                default: state_instr <= state_instr_idle;
            endcase
        end
    end

    always @(posedge clk) begin // native memory read valid/ready sequencing
        if(rst) begin
            state_main_mem <= state_main_mem_idle;
            main_mem_done_step0 <= 1'b0;
            main_mem_read_beat_index <= 8'b0;
            ram_read <= 1'b0;
        end
        else begin
            case(state_main_mem)
                state_main_mem_idle: begin
                    main_mem_done_step0 <= 1'b0;
                    main_mem_read_beat_index <= 8'b0;
                    ram_read <= 1'b0;
                    if(main_mem_transfer_instr | main_mem_transfer_data) begin
                        state_main_mem          <= state_main_mem_transfer_0;
                    end
                end

                state_main_mem_transfer_0: begin
                    ram_read <= 1'b1;
                    main_mem_done_step0 <= 1'b0;
                    if(ram_read & ram_req_ready) begin
                        ram_read <= 1'b0;
                        state_main_mem <= state_main_mem_transfer_1;
                    end
                end

                state_main_mem_transfer_1: begin
                    ram_read <= 1'b0;
                    if(ram_rsp_valid) begin
                        main_mem_done_step0 <= 1'b1;
                        state_main_mem <= state_main_mem_transfer_2;
                    end
                end

                state_main_mem_transfer_2: begin
                    main_mem_done_step0 <= 1'b0;
                    if(main_mem_read_beat_ack) begin
                        if(main_mem_read_beat_index == LINE_MEM_LAST_BEAT) begin
                            state_main_mem <= state_main_mem_idle;
                        end else begin
                            main_mem_read_beat_index <= main_mem_read_beat_index + 8'd1;
                            state_main_mem <= state_main_mem_transfer_0;
                        end
                    end
                end

                default: state_main_mem <= state_main_mem_idle;
            endcase
        end
    end

    always @(posedge clk) begin // native memory write valid/ready sequencing
        if(rst) begin
            state_main_mem_write <= state_main_mem_write_idle;
            main_mem_write_done  <= 1'b0;
            main_mem_write_step1_done <= 1'b0;
            main_mem_write_beat_index <= 8'b0;
        end
        else begin
            case(state_main_mem_write)
                state_main_mem_write_idle: begin
                    main_mem_write_done <= 1'b0;
                    main_mem_write_step1_done <= 1'b0;
                    main_mem_write_beat_index <= 8'b0;
                    if(start_write_transfer & ram_req_ready) begin
                        main_mem_write_step1_done <= 1'b1;
                        if(data_write_last_beat_index != 8'b0) begin
                            state_main_mem_write      <= state_main_mem_write_wait_next;
                        end
                        else begin
                            state_main_mem_write      <= state_main_mem_write_transfer_done;
                        end
                    end
                end
                state_main_mem_write_wait_next: begin
                    main_mem_write_done <= 1'b0;
                    main_mem_write_step1_done <= 1'b0;
                    if(start_write_transfer2) begin
                        state_main_mem_write <= state_main_mem_write_transfer_SD;
                    end
                end
                state_main_mem_write_transfer_SD: begin
                    main_mem_write_step1_done <= 1'b0;
                    if(start_write_transfer2 & ram_req_ready) begin
                        main_mem_write_step1_done <= 1'b1;
                        if(main_mem_write_beat_index == (data_write_last_beat_index - 8'd1)) begin
                            state_main_mem_write <= state_main_mem_write_transfer_done;
                        end else begin
                            main_mem_write_beat_index <= main_mem_write_beat_index + 8'd1;
                            state_main_mem_write <= state_main_mem_write_wait_next;
                        end
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

    always @(posedge clk) begin // data cache control
        if(rst) begin
            write_through_miss              <= 1'b0;
            data_cache_read <= 1'b0;
            L2_read_p1                    <= 1'b0;
            miss_L1_data                    <= 1'b0;
            write_L2                      <= 1'b0;
            write_through                 <= 1'b0;
            L2_byte_enable_p1             <= {LINE_BYTE_COUNT{1'b0}};
            main_mem_transfer_data          <= 1'b0;
            L2_write_p1                   <= 1'b0;
            wr_strb                       <= {MEM_BYTE_COUNT{1'b0}};
            start_write_transfer            <= 1'b0;
            start_write_transfer2           <= 1'b0;
            transfer_data_step1             <= 1'b0;
            data_fill_beat_index            <= 8'b0;
            data_write_beat_index            <= 8'b0;
            ram_write_start_data          <= 1'b0;
            state_data                      <= state_data_idle;
        end
        else begin
            case(state_data)
            state_data_idle: begin
                if(data_read_request) begin // read request
                    //miss_L1_data                   <= 1'b1;
                    data_cache_read <= 1'b1;
                    state_data                     <= state_data_read; // eger cpu yavas olcaksa direk state_data_read'e gitmeli
                end
                else if(data_write_request) begin
                    data_cache_read <= 1'b1;
                    state_data                     <= state_data_write_step0;
                end
                else begin
                    write_through_miss              <= 1'b0;
                    data_cache_read <= 1'b0;
                    L2_read_p1                    <= 1'b0;
                    miss_L1_data                    <= 1'b0;
                    write_L2                      <= 1'b0;
                    write_through                 <= 1'b0;
                    L2_byte_enable_p1             <= {LINE_BYTE_COUNT{1'b0}};
                    main_mem_transfer_data          <= 1'b0;
                    L2_write_p1                   <= 1'b0;
                    wr_strb                       <= {MEM_BYTE_COUNT{1'b0}};
                    start_write_transfer            <= 1'b0;
                    start_write_transfer2           <= 1'b0;
                    transfer_data_step1             <= 1'b0;
                    data_fill_beat_index            <= 8'b0;
                    data_write_beat_index            <= 8'b0;
                    ram_write_start_data          <= 1'b0;
                    state_data                      <= state_data_idle;
                end
            end


            state_data_read: begin
                if(L1_data_hit) begin
                    miss_L1_data   <= 1'b0;
                    data_cache_read <= 1'b0;
                    state_data     <= state_data_idle;
                end
                else begin
                    L2_read_p1  <= 1'b1;
                    data_cache_read <= 1'b1;
                    miss_L1_data  <= 1'b1;
                    state_data    <= state_data_miss_L1_step0;
                end
            end

            state_data_miss_L1_step0: begin
                state_data <= state_data_miss_L1_step1;
            end

            state_data_miss_L1_step1: begin
                if(L2_p1_hit & ~write_through_miss) begin // ~write_through miss, yazma yapilmis ve daha once o adres cache'lerde bulunmuyorsa yapilacak bir sey.
                    write_L2      <= 1'b1;
                    state_data      <= state_data_hit_L2_step0;
                end
                else if(~transfer_instr & ~((state_instr == state_instr_miss_L1_step1) & ~L2_p2_hit))begin // L2'de de miss var. L1 instr cache main memory'yi kullanmiyorsa ve su anda kullanmiyacaksa buraya gir.

                    L2_write_p1          <= 1'b1;
                    data_fill_beat_index <= 8'b0;
                    L2_byte_enable_p1    <= MEMORY_BEAT_BYTE_MASK;
                    ram_write_start_data   <= 1'b1;
                    ram_addr_l2_data       <= L1_data_addr & line_addr_mask;
                    state_data             <= state_data_miss_L2_step;
                end
            end

            state_data_hit_L2_step0: begin
                state_data <= state_data_hit_L2_step1;
            end

            state_data_hit_L2_step1: begin
                if(L1_data_hit) begin
                    write_L2   <= 1'b0;
                    miss_L1_data <= 1'b0;
                    data_cache_read <= 1'b0;
                    state_data   <= state_data_idle;
                end
            end
            state_data_miss_L2_step: begin
                ram_write_start_data   <= 1'b0;
                if(~transfer_instr & ~((state_instr == state_instr_miss_L1_step1) & ~L2_p2_hit)) begin
                    main_mem_transfer_data <= 1'b1;
                    state_data             <= state_data_miss_L2_step0;
                end

            end
            state_data_miss_L2_step0: begin
                ram_write_start_data  <= 1'b0;
                if(main_mem_done_step0 & transfer_data) begin
                    transfer_data_step1     <= 1'b1;
                    if(data_fill_beat_index == LINE_MEM_LAST_BEAT) begin
                        ram_addr_l2_data       <= L1_data_addr & line_addr_mask;
                        main_mem_transfer_data <= 1'b0;
                        L2_byte_enable_p1      <= {LINE_BYTE_COUNT{1'b0}};
                        L2_write_p1            <= 1'b0;
                        state_data             <= state_data_miss_L2_done_step0;
                    end else begin
                        data_fill_beat_index <= data_fill_beat_index + 8'd1;
                        ram_addr_l2_data     <= ram_addr_l2_data + MEM_ADDR_STEP;
                        L2_byte_enable_p1    <= data_next_fill_byte_enable;
                    end
                end else begin
                    transfer_data_step1 <= 1'b0;
                end
            end

            state_data_miss_L2_done_step0: begin
                write_L2                <= 1'b1;
                state_data              <= state_data_miss_L2_done_step1;
            end

            state_data_miss_L2_done_step1: begin
                write_L2          <= 1'b0;
                if(L1_data_hit) begin
                    miss_L1_data        <= 1'b0;
                    data_cache_read <= 1'b0;
                    write_through     <= 1'b0;
                    write_through_miss  <= 1'b0;
                    state_data          <= state_data_idle;
                end
            end

            state_data_write_step0: begin // read'i stable hale getirmek icin olan state
                state_data               <= state_data_write_step1;
            end

            state_data_write_step1: begin
                if(~L1_data_hit) begin
                    write_through_miss <= 1'b1;
                    miss_L1_data       <= 1'b1;
                end
                write_through          <= 1'b1;
                state_data               <= state_data_writethrough_step0;
            end

            state_data_writethrough_step0: begin
                state_data      <= state_data_writethrough_step1;
            end

            state_data_writethrough_step1: begin
                state_data      <= state_data_writethrough_step2;
            end

            state_data_writethrough_step2: begin
                if(~write_through_miss) begin
                    L2_write_p1            <= 1'b1;
                    ram_write_start_data   <= 1'b1;
                    L2_byte_enable_p1      <= {LINE_BYTE_COUNT{1'b1}};
                end
                state_data               <= state_data_writethrough_step3;
            end

            state_data_writethrough_step3: begin
                ram_write_start_data  <= 1'b0;
                state_data              <= state_data_writethrough_step4;
            end

            state_data_writethrough_step4: begin
                ram_write_start_data   <= 1'b0;
                L2_write_p1            <= 1'b0;
                L2_byte_enable_p1      <= {LINE_BYTE_COUNT{1'b0}};
                L2_read_p1             <= 1'b1;
                state_data               <= state_data_writethrough_step5;
            end

            state_data_writethrough_step5: begin
                state_data <= state_data_writethrough_step6;
            end

            state_data_writethrough_step6: begin // L2'den okuma yapildi.
                start_write_transfer     <= 1'b1;
                ram_addr_l2_data_write   <= L1_data_addr;
                data_write_beat_index    <= 8'b0;
                wr_strb                  <= data_write_current_strobe;
                if(data_write_last_beat_index != 8'b0) begin
                    state_data       <= state_data_writethrough_SD;
                end
                else begin
                    state_data       <= state_data_writethrough_done;
                end
            end

            state_data_writethrough_SD: begin
                if(main_mem_write_step1_done) begin
                    start_write_transfer      <= 1'b0;
                    data_write_beat_index     <= data_write_beat_index + 8'd1;
                    ram_addr_l2_data_write    <= ram_addr_l2_data_write + MEM_ADDR_STEP;
                    wr_strb                   <= data_write_next_strobe;
                    start_write_transfer2     <= 1'b1;
                    if(data_write_beat_index == (data_write_last_beat_index - 8'd1)) begin
                        state_data <= state_data_writethrough_done;
                    end
                end
            end

            state_data_writethrough_done: begin
                if(main_mem_write_done) begin
                    wr_strb               <= {MEM_BYTE_COUNT{1'b0}};
                    ram_addr_l2_data_write  <= L1_data_addr;
                    start_write_transfer    <= 1'b0;
                    start_write_transfer2   <= 1'b0;
                    if(write_through_miss) begin
                        state_data             <= state_data_miss_L1_step1;
                    end
                    else begin
                        L2_read_p1            <= 1'b0;
                        data_cache_read <= 1'b0;
                        write_through         <= 1'b0;
                        state_data              <= state_data_idle;
                    end
                end
            end

            default: state_data <= state_data_idle;
            endcase
        end
    end

endmodule
