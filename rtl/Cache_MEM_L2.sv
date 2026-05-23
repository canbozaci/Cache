`timescale 1ns / 1ps
module Cache_MEM_L2#( // L2 cache
    parameter block_size = 128,
    parameter tag_size = 7,
    parameter idx_size = 8,
    parameter block_no = 256
    )
    ( 
    input clk,
    input rst,
    input read_p1,                
    input read_p2,                
    input write_p1,               
    input write_p2,               
    input [block_size-1:0] data_block_write_p1, 
    input [block_size-1:0] data_block_write_p2, 
    input [15:0] byte_enable_p1,   
    input [15:0] byte_enable_p2,   
    input [tag_size+idx_size-1:0] addr_p1,         
    input [tag_size+idx_size-1:0] addr_p2,         
    input ram_write_start,
    input write_through,
    output [block_size-1:0] data_block_read_p1, // data out read port 1 (data cache & main memory write)
    output [block_size-1:0] data_block_read_p2, // data out read port 2 (instr cache write)
    output hit_p1, 
    output hit_p2  
    );
    // wires    
    wire valid_out_s1_p1; // valid bits with addressing
    wire valid_out_s2_p1; // valid bits with addressing
    wire valid_out_s1_p2;
    wire valid_out_s2_p2;

    wire [tag_size-1:0] tag_out_s1_p1;
    wire [tag_size-1:0] tag_out_s2_p1;
    wire [tag_size-1:0] tag_out_s1_p2;
    wire [tag_size-1:0] tag_out_s2_p2;


    wire [tag_size -1:0] tag_input_p1;
    wire [idx_size -1:0] idx_input_p1;
    wire [tag_size -1:0] tag_input_p2;
    wire [idx_size -1:0] idx_input_p2;

    wire cache_set_output_select_p1;
    wire cache_set_output_select_p2;

    wire [block_size -1:0] data_out_s1_p1;
    wire [block_size -1:0] data_out_s2_p1;
    wire [block_size -1:0] data_out_s1_p2;
    wire [block_size -1:0] data_out_s2_p2;

    wire we_s1_p1;
    wire we_s2_p1;
    wire we_s1_p2;
    wire we_s2_p2;

    wire hit_s1_p1;
    wire hit_s2_p1; 
    wire hit_s1_p2;
    wire hit_s2_p2;

    wire we_set1_p1;
    wire we_set2_p1;
    wire we_set1_p2;
    wire we_set2_p2;

    assign tag_input_p2    = addr_p2[tag_size + idx_size - 1:idx_size];
    assign idx_input_p2    = addr_p2[idx_size - 1:0];

    assign tag_input_p1    = addr_p1[tag_size + idx_size - 1:idx_size];
    assign idx_input_p1    = addr_p1[idx_size - 1:0];

    
    assign we_set2_p1  = write_p1 & we_s2_p1;
    assign we_set1_p1  = write_p1 & we_s1_p1;
    assign we_set2_p2  = write_p2 & we_s2_p2;
    assign we_set1_p2  = write_p2 & we_s1_p2;

    assign hit_p1 = ((read_p1) & (hit_s1_p1 | hit_s2_p1)) & (~rst);
    assign hit_p2 = ((read_p2) & (hit_s1_p2 | hit_s2_p2)) & (~rst);

    assign cache_set_output_select_p1 = ((read_p1) & (hit_s2_p1 & (~hit_s1_p1)));
    assign cache_set_output_select_p2 = ((read_p2) & (hit_s2_p2 & (~hit_s1_p2)));

    Cache_SET_L2 Cache_L2_set1(
        .clk(clk),
        .rst(rst),
        .block_write_p1(data_block_write_p1),
        .block_write_p2(data_block_write_p2),
        .tag_and_idx_p1({tag_input_p1,idx_input_p1}),
        .tag_and_idx_p2({tag_input_p2,idx_input_p2}),
        .we_p1(we_set1_p1), 
        .we_p2(we_set1_p2), 
        .byte_enable_p1(byte_enable_p1),
        .byte_enable_p2(byte_enable_p2),
        .block_read_p1(data_out_s1_p1),
        .block_read_p2(data_out_s1_p2),
        .valid_p1(valid_out_s1_p1),
        .valid_p2(valid_out_s1_p2),
        .tag_p1(tag_out_s1_p1),
        .tag_p2(tag_out_s1_p2)
    );

    Cache_SET_L2 Cache_L2_set2(
        .clk(clk),
        .rst(rst),
        .block_write_p1(data_block_write_p1),
        .block_write_p2(data_block_write_p2),
        .tag_and_idx_p1({tag_input_p1,idx_input_p1}),
        .tag_and_idx_p2({tag_input_p2,idx_input_p2}),
        .we_p1(we_set2_p1), 
        .we_p2(we_set2_p2), 
        .byte_enable_p1(byte_enable_p1),
        .byte_enable_p2(byte_enable_p2),
        .block_read_p1(data_out_s2_p1),
        .block_read_p2(data_out_s2_p2),
        .valid_p1(valid_out_s2_p1),
        .valid_p2(valid_out_s2_p2),
        .tag_p1(tag_out_s2_p1),
        .tag_p2(tag_out_s2_p2)
    );

    Cache_identification#( // IDENTIFICATION FOR SET1 READ PORT 1
        .tag_size(tag_size)
        ) 
    cache_identification_set_1_r1(
        .tag(tag_input_p1),
        .valid_mem(valid_out_s1_p1),
        .tag_mem(tag_out_s1_p1),
        .hit(hit_s1_p1)
        );
    
    Cache_identification#( // IDENTIFICATION FOR SET1 READ PORT 2
        .tag_size(tag_size)
        ) 
    cache_identification_set_1_r2(
        .tag(tag_input_p2),
        .valid_mem(valid_out_s1_p2),
        .tag_mem(tag_out_s1_p2),
        .hit(hit_s1_p2)
        );

    Cache_identification#( // IDENTIFICATION FOR SET2 READ PORT 1
        .tag_size(tag_size)
        ) 
    cache_identification_set_2_r1(
        .tag(tag_input_p1),
        .valid_mem(valid_out_s2_p1),
        .tag_mem(tag_out_s2_p1),
        .hit(hit_s2_p1)
        );

    Cache_identification#( // IDENTIFICATION FOR SET2 READ PORT 2
        .tag_size(tag_size)
        ) 
    cache_identification_set_2_r2(
        .tag(tag_input_p2),
        .valid_mem(valid_out_s2_p2),
        .tag_mem(tag_out_s2_p2),
        .hit(hit_s2_p2)
        );

    Cache_replacement_L2#( // REPLACEMENT ALGORITMASI
        .idx_size(idx_size),
        .block_no(block_no)
        ) 
    cache_replacement_L2_inst(
        .clk(clk),
        .rst(rst),
        .read_p1(read_p1),
        .read_p2(read_p2),
        .write_p1(write_p1),
        .write_p2(write_p2),
        .idx_p1(idx_input_p1),
        .idx_p2(idx_input_p2),
        .hit_s1_p1(hit_s1_p1),
        .hit_s2_p1(hit_s2_p1),
        .hit_s1_p2(hit_s1_p2),
        .hit_s2_p2(hit_s2_p2),
        .valid_out_s1_p1(valid_out_s1_p1),
        .valid_out_s2_p1(valid_out_s2_p1),
        .valid_out_s1_p2(valid_out_s1_p2),
        .valid_out_s2_p2(valid_out_s2_p2),
        .ram_write_start(ram_write_start),
        .write_through(write_through),
        .we_s1_p1(we_s1_p1),
        .we_s2_p1(we_s2_p1),
        .we_s1_p2(we_s1_p2),
        .we_s2_p2(we_s2_p2) 
        );

    Cache_output_set_select #( 
        .block_size(block_size)
        )
    Cache_output_set_select_inst_P1(
        .hit(hit_p1 | write_through),
        .cache_set_output_select(cache_set_output_select_p1),
        .data_out_s2(data_out_s2_p1),
        .data_out_s1(data_out_s1_p1),
        .data_block(data_block_read_p1)
        );

    Cache_output_set_select #( 
        .block_size(block_size)
        )
    Cache_output_set_select_inst_P2(
        .hit(hit_p2),
        .cache_set_output_select(cache_set_output_select_p2),
        .data_out_s2(data_out_s2_p2),
        .data_out_s1(data_out_s1_p2),
        .data_block(data_block_read_p2)
        );

endmodule
