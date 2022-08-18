`timescale 1ns / 1ps

module Cache_MEM_L1_data#( // L1 data cache top module
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6,
    parameter block_no = 64,
    parameter word_size = 2,
    parameter offset_size = 2
    )
    ( 
    input clk_i,
    input rst_i,
    input read_i,  
    input write_i, 
    input [2:0] read_instruction_i,  //load : 000 => LBU, 001 => LB, 010 => LHU, 011 => LH, 100 => LWU, 101 => LW, 110 => LD
    input [2:0] write_instruction_i, //store: 00 => SB, 01 => SH, 10 => SW, 11 => SD
    input write_L2_i, 
    input write_through_i,
    input [tag_size+idx_size+word_size+offset_size-1:0] addr_i, 
    input [63:0] data_core_i,
    input [block_size-1:0] data_L2_i,
    output [block_size-1:0]  data_block_o, 
    output [63:0] data_o, 
    output hit_o 
    );
    // wires
    wire [block_size-1:0] data_in_write; 
    wire [7:0] byte_enable_l; 
    wire [7:0] byte_enable_h; 
    wire [tag_size -1:0] tag_input;
    wire [idx_size -1:0] idx_input;
    wire [word_size-1:0] word_input;
    wire [offset_size-1:0] offset_input;
    wire cache_set_output_select;
    wire [block_size -1:0] data_out_s1;
    wire [block_size -1:0] data_out_s2;
    wire [tag_size -1:0] tag_out_s1;
    wire [tag_size -1:0] tag_out_s2;
    wire valid_out_s1; // valid bits with addressing
    wire valid_out_s2; // valid bits with addressing
    wire we_s1;
    wire we_s2;
    wire hit_s1;
    wire hit_s2; 
    wire we_set1;
    wire we_set2;

    assign tag_input    = addr_i[tag_size + idx_size + word_size +  offset_size  - 1:idx_size + word_size + offset_size];
    assign idx_input    = addr_i[idx_size + word_size + offset_size - 1:word_size+offset_size];
    assign word_input   = addr_i[word_size+offset_size -1 :offset_size];
    assign offset_input = addr_i[offset_size-1:0];

    assign we_set2 = write_i & we_s2;
    assign we_set1 = write_i & we_s1;
    assign hit_o = ((read_i | write_i) & (hit_s1 | hit_s2)) & (~rst_i);
    assign cache_set_output_select = ((read_i | write_i) & (hit_s2 & (~hit_s1)));

    Cache_SET_L1_data#( // SET1
        .block_size(block_size),
        .tag_size(tag_size),
        .idx_size(idx_size)
        ) 
    cache_set_0(
        .clk_i(clk_i),
        .block_i(data_in_write),
        .tag_and_idx_i({tag_input,idx_input}),
        .we_i(we_set1),
        .byte_enable_i({byte_enable_h,byte_enable_l}),
        .block_o(data_out_s1),
        .valid_o(valid_out_s1),
        .tag_o(tag_out_s1)
        );

    Cache_SET_L1_data#( // SET2
        .block_size(block_size),
        .tag_size(tag_size),
        .idx_size(idx_size)
        ) 
    cache_set_1(
        .clk_i(clk_i),
        .block_i(data_in_write),
        .tag_and_idx_i({tag_input,idx_input}),
        .we_i(we_set2),
        .byte_enable_i({byte_enable_h,byte_enable_l}),
        .block_o(data_out_s2),
        .valid_o(valid_out_s2),
        .tag_o(tag_out_s2)
        );

    Cache_identification#( // IDENTIFICATION FOR SET1
        .tag_size(tag_size)
        ) 
    cache_identification_set_0(
        .tag_i(tag_input),
        .valid_mem(valid_out_s1),
        .tag_mem(tag_out_s1),
        .hit_o(hit_s1)
        );

    Cache_identification#( // IDENTIFICATION FOR SET2
        .tag_size(tag_size)
        ) 
    cache_identification_set_1(
        .tag_i(tag_input),
        .valid_mem(valid_out_s2),
        .tag_mem(tag_out_s2),
        .hit_o(hit_s2)
        );

    Cache_replacement_data#( 
        .idx_size(idx_size),
        .block_no(block_no)
        ) 
    cache_replacement_inst(
        .rst_i(rst_i),
        .read_i(read_i),
        .write_i(write_i),
        .idx_i(idx_input),
        .hit_s1_i(hit_s1),
        .hit_s2_i(hit_s2),
        .write_L2_i(write_L2_i),
        .write_through_i(write_through_i),
        .valid_out_s1_i(valid_out_s1),
        .valid_out_s2_i(valid_out_s2),
        .we_s1_o(we_s1),
        .we_s2_o(we_s2)
        );

    Cache_output_set_select #( 
        .block_size(block_size)
        )
    Cache_output_set_select_inst(
        .hit_i(hit_o),
        .cache_set_output_select_i(cache_set_output_select),
        .data_out_s2_i(data_out_s2),
        .data_out_s1_i(data_out_s1),
        .data_block_o(data_block_o)
        );

    Cache_LOAD_L1_data #( // MODULE THAT DOES THE NECESSARY WORKS FOR LOAD OPERATIONS FROM CORE
        .offset_size(offset_size),
        .word_size(word_size)
        )
    Cache_LOAD_L1_data_inst(
        .data_block_i(data_block_o),
        .offset_i(offset_input),
        .word_i(word_input),
        .read_instruction_i(read_instruction_i),
        .data_o(data_o)
        );

    Cache_STORE_L1_data#( // MODULE THAT DOES THE NECESSARY WORKS FOR STORE OPERATIONS FROM CORE AND IN CASE OF WRITING FROM L2
        .offset_size(offset_size),
        .word_size(word_size),
        .block_size(block_size)
        )
    Cache_STORE_L1_data_inst(
        .write_L2_i(write_L2_i),
        .data_L2_i(data_L2_i),
        .data_core_i(data_core_i),
        .offset_i(offset_input),
        .word_i(word_input),
        .write_instruction_i(write_instruction_i),
        .byte_enable_h_o(byte_enable_h),
        .byte_enable_l_o(byte_enable_l),
        .data_in_write_o(data_in_write)
        );
endmodule

