`timescale 1ns / 1ps
module Cache_MEM_L1_instr_tb();
parameter block_size = 128;
parameter tag_size = 9;
parameter idx_size = 6;
parameter word_size = 2;
parameter offset_size = 2;
//reg flag_done_i;
reg cpu_clk;

reg clk_i;
reg rst_i;
reg read_i;
reg write_i;
wire [tag_size+idx_size+word_size+offset_size-1:0] addr_i;
reg [block_size-1:0] data_L2_i;
wire [31:0] data_o;
wire hit_o;
wire miss_next_o;
reg [tag_size-1:0] tag;
reg [idx_size-1:0] idx;
reg [word_size-1:0] word;
reg [offset_size-1:0] offset;
reg write_next_i;
assign addr_i = {tag, idx, word, offset};
    Cache_MEM_L1_instr#( // L1 instr cache top module
    .block_size(block_size),
    .tag_size(tag_size),
    .word_size(word_size),
    .offset_size(offset_size)
    )
    Cache_Memory_L1_instr_inst( 
    .clk_i(clk_i),
    .rst_i(rst_i),
    .read_i(read_i),            // disaridan gelen read sinyali
    .write_i(write_i),          // disaridan gelen write sinyali
    .write_next_i(write_next_i),
    .addr_i(addr_i),            // 32 bitlik address
    .data_L2_i(data_L2_i),      // L2'den gelecek block_size'lik data.
    //.flag_done_i(flag_done_i),  // there was a miss in next address and it is written correctly, read address is now next address
    .data_o(data_o),            // Core'a gidicek 32 bitlik data (Compressed ise lsb 16 okusun.)
    .hit_o(hit_o),              // set1 veya set0 da hit var sinyali.
    .miss_next_o(miss_next_o)   // compressed instruction gelmis onceden 1 kere ve PC+2'den okuma yapiliyor, ve son word'un son offset'inden okuma yapiyorsun yani kayma olmus. Ve sonraki address miss.
    );

    always #4 clk_i = ~clk_i;
    always #20 cpu_clk = ~cpu_clk;
    initial begin
        cpu_clk = 1'b0;
        clk_i = 1'b0;
        write_next_i = 1'b0;
        reset_mem;
        /*write_from_L2(
            {
            14'b101, 2'b11, 
            14'b101, 2'b00, 
            14'b100, 2'b10, 
            14'b111, 2'b11,
            14'b010, 2'b11, 
            14'b001, 2'b00, 
            14'b111, 2'b10,
            14'b1111_1111_1111_11, 2'b11  
            },6'd1,9'd0,2'd0,2'd0
            );
        read_L1_instr(6'd1,9'd0,2'd0,2'd0); // 001eFFFF
        write_from_L2(
            128'b0,6'd1,9'd1,2'd0,2'd0
            );
            read_L1_instr(6'd1,9'd1,2'd0,2'd0); // 0000_0000
            read_L1_instr(6'd1,9'd0,2'd0,2'd0); // 001eFFFF
        write_from_L2(
                128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF,6'd1,9'd2,2'd0,2'd0
            );
        read_L1_instr(6'd1,9'd0,2'd0,2'd0); // 001EFFFF
        read_L1_instr(6'd1,9'd1,2'd0,2'd0); // miss
        read_L1_instr(6'd1,9'd2,2'd0,2'd0); // FFFF
        */
        write_from_L2(
            {
            14'b101, 2'b11, // nc5
            14'b101, 2'b00, // c4
            14'b100, 2'b10, // c3
            14'b111, 2'b11, 
            14'b010, 2'b11, // nc2
            14'b001, 2'b00, // c1
            14'b111, 2'b10, 
            14'b000, 2'b11  // nc0
            },6'd0,9'd0,2'd0,2'd0);
        read_L1_instr(6'd0,9'd0,2'd0,2'd0); //nc0 001e0003
        read_L1_instr(6'd0,9'd0,2'd1,2'd0); //c1  0004
        read_L1_instr(6'd0,9'd0,2'd1,2'd2); //nc2 001f000b
        read_L1_instr(6'd0,9'd0,2'd2,2'd2); //c3  0012
        read_L1_instr(6'd0,9'd0,2'd3,2'd0); //c4  0014
        read_L1_instr(6'd0,9'd0,2'd3,2'd2); //nc5 if commented out miss_next, else ffff0017
        read_i = 1'b1;
        #20;
        write_next_i = 1'b1;
        //read_L1_instr(6'd1,9'd0,2'd3,2'd2); //miss next
        data_L2_i = {
            14'b101, 2'b11, 
            14'b101, 2'b00, 
            14'b100, 2'b10, 
            14'b111, 2'b11,
            14'b010, 2'b11, 
            14'b001, 2'b00, 
            14'b111, 2'b10,
            14'b1111_1111_1111_11, 2'b11  
            };
        write_i = 1'b1;
        #20;
        read_i = 1'b0;
        write_i = 1'b0;

        read_L1_instr(6'd0,9'd0,2'd3,2'd2); //nc5 if commented out miss_next, else ffff0017

        /*write_from_L2(
            {
            14'b101, 2'b11, 
            14'b101, 2'b00, 
            14'b100, 2'b10, 
            14'b111, 2'b11,
            14'b010, 2'b11, 
            14'b001, 2'b00, 
            14'b111, 2'b10,
            14'b1111_1111_1111_11, 2'b11  
            },6'd1,9'd0,2'd0,2'd0
            );*/
        //read_L1_instr(6'd0,9'd0,2'd3,2'd2); //nc5 ffff0017
        #10;
        $finish;
    end

    task reset_mem();
    begin
        rst_i = 1'b1;
        #100;
        rst_i = 1'b0;
    end
    endtask
    task write_from_L2(
        input [block_size-1:0] data,
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input[word_size-1:0] word_i,
        input[offset_size-1:0] offset_i
        );
    begin
        @(posedge cpu_clk);
        idx = idx_i;
        tag = tag_i;
        word = word_i;
        offset = offset_i;
        data_L2_i = data;
        write_i = 1'b1;
        #5;
        repeat(1)@(posedge cpu_clk);
        write_i = 1'b0;
    end
    endtask
    task read_L1_instr(
        input [idx_size-1:0] idx_i,
        input [tag_size-1:0] tag_i,
        input[word_size-1:0] word_i,
        input[offset_size-1:0] offset_i
        );
    begin
        @(posedge cpu_clk);
        idx = idx_i;
        tag = tag_i;
        word = word_i;
        offset = offset_i;
        read_i = 1'b1;
        #5;
        repeat(1)@(posedge cpu_clk);
        read_i = 1'b0;
    end
    endtask
endmodule
