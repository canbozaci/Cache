`timescale 1ns / 1ps
module Cache_SET_L2#(
    parameter block_size = 128,
    parameter tag_size = 7,
    parameter idx_size = 8
    )
    (
    input clk_i,
    input [block_size-1:0] block_p1_i,
    input [block_size-1:0] block_p2_i,
    input [tag_size + idx_size-1:0] tag_and_idx_p1_i,
    input [tag_size + idx_size-1:0] tag_and_idx_p2_i,
    input we_p1_i, 
    input we_p2_i, 
    input [15:0] byte_enable_p1_i,
    input [15:0] byte_enable_p2_i,
    output [block_size-1:0] block_p1_o,
    output [block_size-1:0] block_p2_o,
    output valid_p1_o,
    output valid_p2_o,
    output [tag_size -1:0] tag_p1_o,
    output [tag_size -1:0] tag_p2_o
    );
    

    L2_dat L2_data_inst( // module that holds data bits L2 (4 kB) (128*256 bits)
        .clk_i(clk_i), 
        .we_p1_i(we_p1_i),
        .we_p2_i(we_p2_i), 
        .byte_enable_p1_i(byte_enable_p1_i), 
        .byte_enable_p2_i(byte_enable_p2_i),
        .addr_p1_i(tag_and_idx_p1_i[idx_size-1:0]),
        .addr_p2_i(tag_and_idx_p2_i[idx_size-1:0]),
        .data_p1_i(block_p1_i),
        .data_p2_i(block_p2_i),
        .data_p1_o(block_p1_o),
        .data_p2_o(block_p2_o)
    );

    L2_tgv L2_valid_tag_inst( // module that holds the valid & data bits (10*256 bits)
        .clk_i(clk_i), 
        .we_p1_i(we_p1_i),
        .we_p2_i(we_p2_i), 
        .addr_p1_i(tag_and_idx_p1_i[idx_size-1:0]),
        .addr_p2_i(tag_and_idx_p2_i[idx_size-1:0]),
        .data_p1_i({1'b1,tag_and_idx_p1_i[tag_size+idx_size-1:idx_size]}),
        .data_p2_i({1'b1,tag_and_idx_p2_i[tag_size+idx_size-1:idx_size]}),
        .data_p1_o({valid_p1_o,tag_p1_o}),
        .data_p2_o({valid_p2_o,tag_p2_o})
    );

endmodule
