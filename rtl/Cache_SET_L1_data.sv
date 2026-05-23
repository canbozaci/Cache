`timescale 1ns / 1ps
module Cache_SET_L1_data#(
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6
    )
    (
    input clk,
    input rst,
    input [block_size-1:0] block_write,
    input [tag_size + idx_size-1:0] tag_and_idx,
    input we,
    input [15:0] byte_enable,
    output [block_size-1:0] block_read,
    output valid,
    output [tag_size -1:0] tag
    );
    
    L1_data_dat L1_data_data_inst( // module that holds data bits L1 (1 kB) (128*64 bits)
        .clk(clk),
        .we(we),
        .byte_enable(byte_enable),
        .addr(tag_and_idx[idx_size-1:0]),
        .write_data(block_write),
        .read_data(block_read)
    );

    L1_data_tgv L1_data_valid_tag_inst( // module that holds the valid & data bits (10*64 bits)
        .clk(clk),
        .rst(rst),
        .we(we),
        .addr(tag_and_idx[idx_size-1:0]),
        .write_data({1'b1, tag_and_idx[tag_size + idx_size - 1:idx_size]}),
        .read_data({valid,tag})
    );

endmodule
