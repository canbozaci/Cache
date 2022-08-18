`timescale 1ns / 1ps
module Cache_SET_L1_data#(
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6
    )
    (
    input clk_i,
    input [block_size-1:0] block_i,
    input [tag_size + idx_size-1:0] tag_and_idx_i,
    input we_i,
    input [15:0] byte_enable_i,
    output [block_size-1:0] block_o,
    output valid_o,
    output [tag_size -1:0] tag_o
    );
    
    L1_data_dat L1_data_data_inst( // module that holds data bits L1 (1 kB) (128*64 bits)
        .clk_i(clk_i),
        .we_i(we_i),
        .byte_enable_i(byte_enable_i),
        .addr_i(tag_and_idx_i[idx_size-1:0]),
        .data_i(block_i),
        .data_o(block_o)
    );

    L1_data_tgv L1_data_valid_tag_inst( // module that holds the valid & data bits (10*64 bits)
        .clk_i(clk_i),
        .we_i(we_i),
        .addr_i(tag_and_idx_i[idx_size-1:0]),
        .data_i({1'b1, tag_and_idx_i[tag_size + idx_size - 1:idx_size]}),
        .data_o({valid_o,tag_o})
    );

endmodule
