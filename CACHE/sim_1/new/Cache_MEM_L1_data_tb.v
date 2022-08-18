`timescale 1ns / 1ps
module Cache_MEM_L1_data_tb();
    parameter block_size = 128;
    parameter tag_size = 9;
    parameter idx_size = 6;
    parameter word_size = 2;
    parameter offset_size = 2;
    reg cpu_clk;
    reg clk_i;
    reg rst_i;
    reg read_i;
    reg write_i;
    reg [2:0] read_instruction_i; 
    reg [2:0] write_instruction_i;
    reg write_L2_i;
    wire [tag_size+idx_size+word_size+offset_size-1:0] addr_i;
    reg [63:0] data_core_i;
    reg [block_size-1:0] data_L2_i;
    wire [block_size-1:0] data_block_o;
    wire [63:0] data_o;
    wire hit_o;

    reg [tag_size-1:0] tag;
    reg [idx_size-1:0] idx;
    reg [word_size-1:0] word;
    reg [offset_size-1:0] offset;
    assign addr_i = {tag, idx, word, offset};

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

    Cache_MEM_L1_data#(
        .block_size(128),
        .tag_size(tag_size),
        .idx_size(idx_size),
        .block_no(64),
        .word_size(word_size),
        .offset_size(offset_size)
        )
    Cache_MEMORY_L1_data_inst(
        .clk_i(clk_i),
        .rst_i(rst_i),
        .read_i(read_i),
        .write_i(write_i),
        .read_instruction_i(read_instruction_i),  
        .write_instruction_i(write_instruction_i),
        .write_L2_i(write_L2_i),
        .addr_i(addr_i),
        .data_core_i(data_core_i),
        .data_L2_i(data_L2_i),
        .data_block_o(data_block_o),
        .data_o(data_o),
        .hit_o(hit_o)
        );
    
    always #4 clk_i = ~clk_i;
    always #10 cpu_clk =~cpu_clk;
    initial begin
        cpu_clk = 0;
        clk_i = 0;
        reset_mem;
        write_from_L2(128'hF0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0,6'd0,9'd0,2'd0,2'd0);
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LHU); // F0F0
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LBU); // F0
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LD);  // F0F0F0F0F0F0F0F0
        write_from_L2(128'h0000AAAA,6'd0,9'd5,2'd0,2'd0);
        read_L1_data(6'd0,9'd5,2'd0,2'd0,LBU); // 00aa
        read_L1_data(6'd0,9'd5,2'd0,2'd0,LD);  // aaaa
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LHU); // F0F0
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LBU); // F0
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LD);  // F0F0F0F0F0F0F0F0
        #500;
        write_core(64'hABCD_EFFF_0000_00BB,6'd0,9'd0,2'd0,2'd2,SD);
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LBU); // 00BB
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LHU); // 0000_00BB
        //read_L1_data(6'd0,9'd5,2'd0,2'd1,LD);
        //read_L1_data(6'd0,9'd5,2'd0,2'd1,LD);
        write_from_L2(128'hDDDDDDDD,6'd0,9'd10,2'd0,2'd0);  
        read_L1_data(6'd0,9'd0,2'd0,2'd0,LD); // abcdefff000000bb
        read_L1_data(6'd0,9'd10,2'd0,2'd0,LD); // DDDDDDDD
        #20;
        $finish;
    end

    task reset_mem();
    begin
        rst_i = 1'b1;
        #100;
        rst_i = 1'b0;
    end
    endtask
    task write_core(
        input [63:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input [word_size-1:0] word_i,
        input [offset_size-1:0] offset_i,
        input [2:0] write_instr);
    begin
        @(posedge cpu_clk);
        write_instruction_i = write_instr;
        idx = idx_i;
        tag = tag_i;
        word = word_i;
        offset = offset_i;
        data_core_i = data;
        #3;
        write_i = 1'b1;
        @(posedge cpu_clk);
        write_i = 1'b0;
    end
    endtask
    task write_from_L2(
        input [block_size-1:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input[word_size-1:0] word_i,
        input[offset_size-1:0] offset_i);
    begin
        write_L2_i <= 1'b1;
        @(posedge cpu_clk);
        idx = idx_i;
        tag = tag_i;
        word = word_i;
        offset = offset_i;
        data_L2_i = data;
        #3;
        write_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        write_i = 1'b0;
        write_L2_i <= 1'b0;
    end
    endtask
    task read_L1_data(
    input [idx_size-1:0] idx_i,
    input [tag_size-1:0] tag_i,
    input[word_size-1:0] word_i,
    input[offset_size-1:0] offset_i,
    input [2:0] read_instr);
    begin
        @(posedge cpu_clk);
        read_instruction_i = read_instr;
        idx = idx_i;
        tag = tag_i;
        word = word_i;
        offset = offset_i;
        #3;
        read_i = 1'b1;
        #5;
        @(posedge cpu_clk);
        read_i = 1'b0;
    end
    endtask
endmodule
