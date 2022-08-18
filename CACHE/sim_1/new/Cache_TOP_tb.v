`timescale 1ns / 1ps
module Cache_TOP_tb();
parameter block_size = 128;
parameter tag_size = 9;
parameter idx_size = 6;
parameter word_size = 2;
parameter offset_size = 2;
parameter RAM_DEPTH = 131072;
reg mem_clk_i;
reg cpu_clk;
reg clk_i;
reg rst_i;
reg read_instr_i; // coming from core!
reg read_data_i; // coming from core!
reg write_data_i;  // coming from core!
wire [18:0] L1_instr_addr_i; // coming from core !
wire [18:0] L1_data_addr_i; // coming from core !
reg [2:0] DATA_read_instruction_i; // coming from core !
reg [2:0] DATA_write_instruction_i; // coming from core !
reg [63:0] core_data_i; // coming from core !
wire [31:0] ram_data_i; // data that will read from RAM
wire [31:0] core_instr_o; // goes to the core
wire [63:0] core_data_o; // goes to the core
wire [31:0] ram_data_o; // data that will be written to RAM
wire [31:0] ram_read_addr_o;
wire [31:0] ram_write_addr_o;
wire ram_read_o;
wire miss_o;
wire [3:0] wr_strb_o;
//wire write_data_o;
reg ram_prog_rx_i;
wire system_reset_o;
wire prog_mode_led_o;

reg [tag_size-1:0] tag_instr;
reg [idx_size-1:0] idx_instr;
reg [word_size-1:0] word_instr;
reg [offset_size-1:0] offset_instr;

assign L1_instr_addr_i = {tag_instr,idx_instr,word_instr,offset_instr};

reg [tag_size-1:0] tag_data;
reg [idx_size-1:0] idx_data;
reg [word_size-1:0] word_data;
reg [offset_size-1:0] offset_data;

assign L1_data_addr_i = {tag_data,idx_data,word_data,offset_data};

parameter SB = 3'b000,
SH = 3'b001,
SW = 3'b010,
SD = 3'b011;
parameter LBU = 3'b100,
LB  = 3'b000,
LHU = 3'b101,
LH =  3'b001,
LWU = 3'b110,
LW  = 3'b010,
LD  = 3'b011;
teknofest_ram #(
  .NB_COL(4),
  .COL_WIDTH(8),
  .RAM_DEPTH(RAM_DEPTH),
  .INIT_FILE("tekno_example.hex")  // Location of the init file
) main_memory
(
  .clk_i           (mem_clk_i ),
  .rst_ni          (~rst_i),
  .wr_addr         (ram_write_addr_o[18:2]),
  .rd_addr         (ram_read_addr_o[18:2]),
  .wr_data         (ram_data_o),

  .wr_strb         (wr_strb_o   ),
  .rd_data         (ram_data_i   ),
  .rd_en           (ram_read_o   ),
  .ram_prog_rx_i   (ram_prog_rx_i     ),
  .system_reset_o  (system_reset_o),
  .prog_mode_led_o (prog_mode_led_o  )
);

Cache_TOP Cache_top_inst(
    .clk_i(clk_i),
    .mem_clk_i(mem_clk_i),
    .rst_i(rst_i),
    .read_instr_i(read_instr_i), 
    .read_data_i(read_data_i),
    .write_data_i(write_data_i),//
    .L1_instr_addr_i(L1_instr_addr_i), 
    .L1_data_addr_i(L1_data_addr_i), //
    .DATA_read_instruction_i(DATA_read_instruction_i),//
    .DATA_write_instruction_i(DATA_write_instruction_i), //
    .core_data_i(core_data_i), 
    .ram_data_i(ram_data_i),   
    .core_instr_o(core_instr_o),
    .core_data_o(core_data_o), 
    .ram_data_o(ram_data_o), 
    .ram_read_addr_o(ram_read_addr_o),
    .ram_write_addr_o(ram_write_addr_o),
    .ram_read_o(ram_read_o),
    .miss_o(miss_o),
    .wr_strb_o(wr_strb_o),
    .write_data_o(write_data_o)
    );

    always #6.25 clk_i = ~clk_i;
    always #6.25 cpu_clk = ~cpu_clk;
    always #6.25 mem_clk_i =~mem_clk_i;
    initial begin // initiliaze and reset
        read_instr_i = 1'b0;
        read_data_i  = 1'b0;
        write_data_i = 1'b0;
        DATA_read_instruction_i = 3'b0;
        DATA_write_instruction_i = 3'b0;
        core_data_i = 64'b0;
        ram_prog_rx_i = 1'b0;
        mem_clk_i = 1'b1;
        clk_i = 1'b1;
        cpu_clk = 1'b1; 
        #100;
        reset_mem();
        #2000;
        //$finish;
    end

    /*
	initial begin // test instruction
        #100;
        ram_data_i = 32'd50;
        read_instr(0,0,0,0); // miss L1 & L2, then read 50
        ram_data_i = 32'd40;
        read_instr(0,1,0,0); // miss L1 & L2, then read 40
        ram_data_i = 32'b1111_1111_1111_1111_1111_1111_1111_1111;
        read_instr(0,2,0,0); // miss L1 & L2, then read 80
        read_instr(0,0,0,0); // miss L1, then read 50
        ram_data_i = 32'd100;
        read_instr(1,2,0,0); // write 100 to next ix
        read_instr(0,2,3,3); // miss next. 
        #100;
    end
	*/

    initial begin // test finalized
        #2500;
        read_data(5,0,0,0,LD); //  00000b9300000b13 -miss L1 data,L2 unified
        read_data(5,0,1,0,LD); //  00000c1300000b93 -hit
        read_data(5,0,2,0,LD); //  00000c9300000c13 -hit 
        read_data(9,0,0,0,LW); // 00000093 -Miss L1 data, L2 unified
        read_data(9,0,1,0,LW); // 7850006f -hit 
        read_data(9,0,2,0,LW); // 00001797 -hit 
        read_data(9,0,3,0,LW); // 4c878793 -hit 
        write_data(64'b100,0,0,0,0,SB); // store 4 to address 0  -write Miss will occur 
        read_data(0,0,0,0,LW); // 0000000000000004 -hit
        read_data(0,0,1,0,LW); // 0000000000001100 -hit 
        read_data(0,0,2,0,LW); // 0000000000000002 -hit 
        read_data(0,0,3,0,LW); // 0000000000000003 -hit 
        write_data(64'B1111,0,0,2,0,SB); // store 1111 to address 2 -write
        read_data(0,0,2,0,LD); // 000000030000000f -hit
        read_data(1,0,0,1,LBU); // 00000000000000ba -miss L1 data, L2 unified
        read_instr(0,0,0,0); // 00000004 -miss L1 instr
        read_instr(2,0,0,0);// 00000513 -miss L1 instr, L2 unified
        read_instr(2,0,3,2);//  07130593 -miss L1 instr, L2 unified (next idx)
        read_instr(2,1,0,0);//  0016f693 -miss L1 instr, L2 unified
        read_instr(2,0,0,0);// 00000513 -hit
        read_instr(2,1,0,0);//  0016f693 -hit
        read_instr(2,2,0,0);// 00812e23 -miss L1 instr, L2 unified
        read_instr(2,1,0,0);//  0016f693 -hitt
        read_instr(2,0,0,0);// 00000513 -miss L1 instr, L2 unified
        read_data(0,0,0,0,LW); // 0000000000000004 -hit
        read_instr(0,0,1,0); // 00001100 - hit
        read_instr(1,0,0,0); // 0000ba98 - hit
        read_data_instr(0,0,1,0_,0,0,0,0,LD); // data: 0000110000000004, instr: 00001100   -- hit 
        read_data_instr(5,0,1,0_,6,0,0,0,LD); // data: 00000d9300000d13, instr: 00000b93   -- miss L1 instr & data, miss L2 
        #500;
        $finish;
        
    end
    
    task reset_mem();
    begin
        rst_i = 1'b1;
        #1000;
        rst_i = 1'b0;
    end
    endtask

task read_instr(
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input[word_size-1:0] word_i,
        input[offset_size-1:0] offset_i
        );
    begin
        #4;
        idx_instr = idx_i;
        tag_instr = tag_i;
        word_instr = word_i;
        offset_instr = offset_i;
        read_instr_i = 1'b1;
        repeat(2)@(posedge cpu_clk);
        read_instr_i = 1'b0;
        #2;
        @(posedge cpu_clk);
        while(miss_o) 
        @(posedge cpu_clk);
    end
    endtask

    task read_data(
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input[word_size-1:0] word_i,
        input[offset_size-1:0] offset_i,
        input [2:0] read_instr);
        begin
            #4;
            DATA_read_instruction_i = read_instr;
            idx_data = idx_i;
            tag_data = tag_i;
            word_data = word_i;
            offset_data = offset_i;
            read_data_i = 1'b1;
            repeat(2)@(posedge cpu_clk);
            read_data_i = 1'b0;
            #2;
            @(posedge cpu_clk);
            
            while(miss_o) 
            @(posedge cpu_clk);
            

        end
        endtask

    task write_data(
        input [63:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i,
        input [2:0] write_instr);
    begin
        #4;
        DATA_write_instruction_i = write_instr;
        idx_data = idx_i;
        tag_data = tag_i;
        word_data = word_i;
        offset_data = offset_i;
        core_data_i = data;
        write_data_i = 1'b1;
        repeat(2)@(posedge cpu_clk);
        write_data_i = 1'b0;
        #2;
        repeat(2)@(posedge cpu_clk);
        #2;
        while(miss_o | write_data_o == 1'b1) 
        @(posedge cpu_clk);

    end 

    endtask

    task read_data_instr(
        input [idx_size-1:0] idx_instr_i,
        input [tag_size-1:0] tag_instr_i,
        input[word_size-1:0] word_instr_i,
        input[offset_size-1:0] offset_instr_i,
        input [idx_size-1:0] idx_data_i,
        input [tag_size-1:0] tag_data_i,
        input[word_size-1:0] word_data_i,
        input[offset_size-1:0] offset_data_i,
        input [2:0] read_instr
        );
    begin
        #4;
        idx_instr = idx_instr_i;
        tag_instr = tag_instr_i;
        word_instr = word_instr_i;
        offset_instr = offset_instr_i;
        idx_data = idx_data_i;
        tag_data = tag_data_i;
        word_data = word_data_i;
        offset_data = offset_data_i;
        DATA_read_instruction_i = read_instr;
        read_data_i  = 1'b1;
        read_instr_i = 1'b1;
        repeat(2)@(posedge cpu_clk);
        read_data_i  = 1'b0;
        read_instr_i = 1'b0;
        #2;
        while(miss_o == 1'b1) 
        @(posedge cpu_clk);
    end
    endtask
endmodule
