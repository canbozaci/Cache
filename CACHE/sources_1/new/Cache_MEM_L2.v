`timescale 1ns / 1ps
module Cache_MEM_L2#( // L2 cache
    parameter block_size = 128,
    parameter tag_size = 7,
    parameter idx_size = 8,
    parameter block_no = 256
    )
    ( 
    input clk_i,
    input rst_i,
    input read_p1_i,                
    input read_p2_i,                
    input write_p1_i,               
    input write_p2_i,               
    input [block_size-1:0] data_block_p1_i, 
    input [block_size-1:0] data_block_p2_i, 
    input [15:0] byte_enable_p1_i,   
    input [15:0] byte_enable_p2_i,   
    input [tag_size+idx_size-1:0] addr_p1_i,         
    input [tag_size+idx_size-1:0] addr_p2_i,         
    input ram_write_start_i,
    input write_through_i,
    output [block_size-1:0] data_block_p1_o, // data out read port 1 (data cache & main memory write)
    output [block_size-1:0] data_block_p2_o, // data out read port 2 (instr cache write)
    output hit_p1_o, 
    output hit_p2_o  
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

    wire we_s1_p1_o;
    wire we_s2_p1_o;
    wire we_s1_p2_o;
    wire we_s2_p2_o;

    wire hit_s1_p1;
    wire hit_s2_p1; 
    wire hit_s1_p2;
    wire hit_s2_p2;

    wire we_set1_p1;
    wire we_set2_p1;
    wire we_set1_p2;
    wire we_set2_p2;

    assign tag_input_p2    = addr_p2_i[tag_size + idx_size - 1:idx_size];
    assign idx_input_p2    = addr_p2_i[idx_size - 1:0];

    assign tag_input_p1    = addr_p1_i[tag_size + idx_size - 1:idx_size];
    assign idx_input_p1    = addr_p1_i[idx_size - 1:0];

    
    assign we_set2_p1  = write_p1_i & we_s2_p1_o;
    assign we_set1_p1  = write_p1_i & we_s1_p1_o;
    assign we_set2_p2  = write_p2_i & we_s2_p2_o;
    assign we_set1_p2  = write_p2_i & we_s1_p2_o;

    assign hit_p1_o = ((read_p1_i) & (hit_s1_p1 | hit_s2_p1)) & (~rst_i);
    assign hit_p2_o = ((read_p2_i) & (hit_s1_p2 | hit_s2_p2)) & (~rst_i);

    assign cache_set_output_select_p1 = ((read_p1_i) & (hit_s2_p1 & (~hit_s1_p1)));
    assign cache_set_output_select_p2 = ((read_p2_i) & (hit_s2_p2 & (~hit_s1_p2)));

    Cache_SET_L2 Cache_L2_set1(
        .clk_i(clk_i),
        .block_p1_i(data_block_p1_i),
        .block_p2_i(data_block_p2_i),
        .tag_and_idx_p1_i({tag_input_p1,idx_input_p1}),
        .tag_and_idx_p2_i({tag_input_p2,idx_input_p2}),
        .we_p1_i(we_set1_p1), 
        .we_p2_i(we_set1_p2), 
        .byte_enable_p1_i(byte_enable_p1_i),
        .byte_enable_p2_i(byte_enable_p2_i),
        .block_p1_o(data_out_s1_p1),
        .block_p2_o(data_out_s1_p2),
        .valid_p1_o(valid_out_s1_p1),
        .valid_p2_o(valid_out_s1_p2),
        .tag_p1_o(tag_out_s1_p1),
        .tag_p2_o(tag_out_s1_p2)
    );

    Cache_SET_L2 Cache_L2_set2(
        .clk_i(clk_i),
        .block_p1_i(data_block_p1_i),
        .block_p2_i(data_block_p2_i),
        .tag_and_idx_p1_i({tag_input_p1,idx_input_p1}),
        .tag_and_idx_p2_i({tag_input_p2,idx_input_p2}),
        .we_p1_i(we_set2_p1), 
        .we_p2_i(we_set2_p2), 
        .byte_enable_p1_i(byte_enable_p1_i),
        .byte_enable_p2_i(byte_enable_p2_i),
        .block_p1_o(data_out_s2_p1),
        .block_p2_o(data_out_s2_p2),
        .valid_p1_o(valid_out_s2_p1),
        .valid_p2_o(valid_out_s2_p2),
        .tag_p1_o(tag_out_s2_p1),
        .tag_p2_o(tag_out_s2_p2)
    );

    Cache_identification#( // IDENTIFICATION FOR SET1 READ PORT 1
        .tag_size(tag_size)
        ) 
    cache_identification_set_1_r1(
        .tag_i(tag_input_p1),
        .valid_mem(valid_out_s1_p1),
        .tag_mem(tag_out_s1_p1),
        .hit_o(hit_s1_p1)
        );
    
    Cache_identification#( // IDENTIFICATION FOR SET1 READ PORT 2
        .tag_size(tag_size)
        ) 
    cache_identification_set_1_r2(
        .tag_i(tag_input_p2),
        .valid_mem(valid_out_s1_p2),
        .tag_mem(tag_out_s1_p2),
        .hit_o(hit_s1_p2)
        );

    Cache_identification#( // IDENTIFICATION FOR SET2 READ PORT 1
        .tag_size(tag_size)
        ) 
    cache_identification_set_2_r1(
        .tag_i(tag_input_p1),
        .valid_mem(valid_out_s2_p1),
        .tag_mem(tag_out_s2_p1),
        .hit_o(hit_s2_p1)
        );

    Cache_identification#( // IDENTIFICATION FOR SET2 READ PORT 2
        .tag_size(tag_size)
        ) 
    cache_identification_set_2_r2(
        .tag_i(tag_input_p2),
        .valid_mem(valid_out_s2_p2),
        .tag_mem(tag_out_s2_p2),
        .hit_o(hit_s2_p2)
        );

    Cache_replacement_L2#( // REPLACEMENT ALGORITMASI
        .idx_size(idx_size),
        .block_no(block_no)
        ) 
    cache_replacement_L2_inst(
        .rst_i(rst_i),
        .read_p1_i(read_p1_i),
        .read_p2_i(read_p2_i),
        .write_p1_i(write_p1_i),
        .write_p2_i(write_p2_i),
        .idx_p1_i(idx_input_p1),
        .idx_p2_i(idx_input_p2),
        .hit_s1_p1_i(hit_s1_p1),
        .hit_s2_p1_i(hit_s2_p1),
        .hit_s1_p2_i(hit_s1_p2),
        .hit_s2_p2_i(hit_s2_p2),
        .valid_out_s1_p1_i(valid_out_s1_p1),
        .valid_out_s2_p1_i(valid_out_s2_p1),
        .valid_out_s1_p2_i(valid_out_s1_p2),
        .valid_out_s2_p2_i(valid_out_s2_p2),
        .ram_write_start_i(ram_write_start_i),
        .write_through_i(write_through_i),
        .we_s1_p1_o(we_s1_p1_o),
        .we_s2_p1_o(we_s2_p1_o),
        .we_s1_p2_o(we_s1_p2_o),
        .we_s2_p2_o(we_s2_p2_o) 
        );

    Cache_output_set_select #( 
        .block_size(block_size)
        )
    Cache_output_set_select_inst_P1(
        .hit_i(hit_p1_o | write_through_i),
        .cache_set_output_select_i(cache_set_output_select_p1),
        .data_out_s2_i(data_out_s2_p1),
        .data_out_s1_i(data_out_s1_p1),
        .data_block_o(data_block_p1_o)
        );

    Cache_output_set_select #( 
        .block_size(block_size)
        )
    Cache_output_set_select_inst_P2(
        .hit_i(hit_p2_o),
        .cache_set_output_select_i(cache_set_output_select_p2),
        .data_out_s2_i(data_out_s2_p2),
        .data_out_s1_i(data_out_s1_p2),
        .data_block_o(data_block_p2_o)
        );

endmodule