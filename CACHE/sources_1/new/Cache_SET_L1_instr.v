`timescale 1ns / 1ps
module Cache_SET_L1_instr#(
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6,
    parameter block_no = 64
    )
    (
    input clk_i,
    input [block_size-1:0] block_i,
    input [tag_size + idx_size-1:0] tag_and_idx_i,
    input we_i, 
    input we_next_i,
    output [block_size-1:0] block_o,
    output valid_o,
    output [tag_size -1:0] tag_o,
    output [15:0] block_next_o,
    output valid_next_o,
    output [tag_size -1:0] tag_next_o
    );

    L1_instr_dat L1_instr_data_inst( // module that holds data bits L1 (1 kB) (128*64 bits)
        .clk_i(clk_i),
        .we_i(we_i),
        .we_next_i(we_next_i),
        .addr_i(tag_and_idx_i[idx_size-1:0]),
        .data_i(block_i),
        .data_o(block_o),
        .data_next_o(block_next_o)
    );

    L1_instr_tgv L1_instr_valid_tag_inst( // module that holds the valid & data bits (10*64 bits)
        .clk_i(clk_i),
        .we_i(we_i),
        .we_next_i(we_next_i),
        .addr_i(tag_and_idx_i[idx_size-1:0]),
        .data_i({1'b1, tag_and_idx_i[tag_size + idx_size - 1:idx_size]}),
        .data_o({valid_o,tag_o}),
        .data_next_o({valid_next_o,tag_next_o})
    );

endmodule
