`timescale 1ns / 1ps
module Cache_MEM_L1_instr#( // L1 instr cache top module
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6,
    parameter word_size = 2,
    parameter offset_size = 1 // normally it is 2 but lsb bit offset is not being used
    )
    ( 
    input clk_i,
    input rst_i,
    input read_i, 
    input instr_write_start_i,
    input write_i,
    input write_next_i, 
    input [tag_size+idx_size+word_size+offset_size-1:0] addr_i,
    input [block_size-1:0] data_L2_i, 
    output [31:0] data_o,
    output hit_o,
    output miss_next_o // Compressed instruction came once before and read from PC+2, and you are reading from the last offset of the last word, so there is slippage. And next address miss.
    );

    wire [block_size -1:0] data_out_s1;
    wire [block_size -1:0] data_out_s2;

    wire [15:0] data_out_s1_next;
    wire [15:0] data_out_s2_next;

    wire [tag_size-1:0] tag_out_s1;
    wire [tag_size-1:0] tag_out_s2;

    wire [tag_size-1:0] tag_out_s1_next;
    wire [tag_size-1:0] tag_out_s2_next;

    wire valid_out_s1; 
    wire valid_out_s2; 

    wire valid_out_s1_next;
    wire valid_out_s2_next;

    wire [block_size-1:0] data_block_o;
    wire [15:0] data_block_o_next;

    wire [tag_size -1:0] tag_input;
    wire [idx_size -1:0] idx_input;
    wire [word_size-1:0] word_input;
    wire offset_input;

    wire cache_set_output_select;
    wire cache_set_output_select_next;

    wire we_s1;
    wire we_s2;

    wire hit_s1;
    wire hit_s2; 

    wire hit_s1_next;
    wire hit_s2_next; 

    wire we_set1;
    wire we_set2;

    assign tag_input    = addr_i[tag_size + idx_size + word_size +  offset_size  - 1:idx_size + word_size + offset_size];
    assign idx_input    = addr_i[idx_size + word_size + offset_size - 1:word_size+offset_size];
    assign word_input   = addr_i[word_size+offset_size -1 :offset_size];
    assign offset_input = addr_i[0];

    assign we_set2 = write_i & we_s2;
    assign we_set1 = write_i & we_s1;

    assign hit_o = ((read_i | write_i) & (hit_s1 | hit_s2)) & (~rst_i);
    assign hit_o_next = ((read_i | write_i) & (hit_s1_next | hit_s2_next)) & (~rst_i);

    assign cache_set_output_select = ((read_i | write_i) & (hit_s2 & (~hit_s1)));
    assign cache_set_output_select_next = ((read_i | write_i) & (hit_s2_next & (~hit_s1_next)));

    Cache_SET_L1_instr cache_set_1( // SET1
        .clk_i(clk_i),
        .block_i(data_L2_i),
        .tag_and_idx_i({tag_input,idx_input}),
        .we_i(we_set1),
        .we_next_i(write_next_i),
        .block_o(data_out_s1),
        .valid_o(valid_out_s1),
        .tag_o(tag_out_s1),
        .block_next_o(data_out_s1_next),
        .valid_next_o(valid_out_s1_next),
        .tag_next_o(tag_out_s1_next)
        );

    Cache_SET_L1_instr cache_set_2( // SET2
        .clk_i(clk_i),
        .block_i(data_L2_i),
        .tag_and_idx_i({tag_input,idx_input}),
        .we_i(we_set2),
        .we_next_i(write_next_i),
        .block_o(data_out_s2),
        .valid_o(valid_out_s2),
        .tag_o(tag_out_s2),
        .block_next_o(data_out_s2_next),
        .valid_next_o(valid_out_s2_next),
        .tag_next_o(tag_out_s2_next)
        );

    Cache_identification cache_identification_set_0( // IDENTIFICATION FOR SET1
        .tag_i(tag_input),
        .valid_mem(valid_out_s1),
        .tag_mem(tag_out_s1),
        .hit_o(hit_s1)
        );
    
    Cache_identification cache_identification_set_0_next( // IDENTIFICATION FOR SET1 NEXT
        .tag_i(tag_input),
        .valid_mem(valid_out_s1_next),
        .tag_mem(tag_out_s1_next),
        .hit_o(hit_s1_next)
        );

    Cache_identification cache_identification_set_1(    // IDENTIFICATION FOR SET2
        .tag_i(tag_input),
        .valid_mem(valid_out_s2),
        .tag_mem(tag_out_s2),
        .hit_o(hit_s2)
        );

    Cache_identification cache_identification_set_1_next( // IDENTIFICATION FOR SET2 NEXT
        .tag_i(tag_input),
        .valid_mem(valid_out_s2_next),
        .tag_mem(tag_out_s2_next),
        .hit_o(hit_s2_next)
        );

    Cache_replacement_instr cache_replacement_instr_inst(
        .rst_i(rst_i),
        .read_i(read_i),
        .instr_write_start_i(instr_write_start_i),
        .write_i(write_i),
        .idx_i(idx_input),
        .hit_s1_i(hit_s1),
        .hit_s2_i(hit_s2),
        .hit_s1_next_i(hit_s1_next),
        .hit_s2_next_i(hit_s2_next),
        .valid_out_s1_i(valid_out_s1),
        .valid_out_s2_i(valid_out_s2),
        .we_s1_o(we_s1),
        .we_s2_o(we_s2)
        );

    Cache_output_set_select Cache_output_set_select_inst( 
        .hit_i(hit_o),
        .cache_set_output_select_i(cache_set_output_select),
        .data_out_s2_i(data_out_s2),
        .data_out_s1_i(data_out_s1),
        .data_block_o(data_block_o)
        );

    Cache_output_set_select#(
        .block_size(16) 
    )
    Cache_output_set_select_inst_next( 
        .hit_i(hit_o_next),
        .cache_set_output_select_i(cache_set_output_select_next),
        .data_out_s2_i(data_out_s2_next),
        .data_out_s1_i(data_out_s1_next),
        .data_block_o(data_block_o_next)
        );

    Cache_instruction_decode Cache_instruction_decoder_inst(
        .read_i(read_i),
        .hit_next_i(hit_o_next),
        .word_i(word_input),
        .offset_i(offset_input),
        .data_block_i(data_block_o),
        .data_block_next_i(data_block_o_next),
        .data_core_o(data_o),
        .flag_o(miss_next_o) 
        );

endmodule