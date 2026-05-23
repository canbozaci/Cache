`timescale 1ns / 1ps
module Cache_SET_L1_data#(
    parameter block_size = 128,
    parameter tag_size = 9,
    parameter idx_size = 6,
    parameter line_byte_count = block_size / 8
    )
    (
    input clk,
    input rst,
    input [block_size-1:0] block_write,
    input [tag_size + idx_size-1:0] tag_and_idx,
    input we,
    input [line_byte_count-1:0] byte_enable,
    output [block_size-1:0] block_read,
    output valid,
    output [tag_size -1:0] tag
    );
    
    L1_data_dat #(
        .DATA_WIDTH(block_size),
        .ADDR_WIDTH(idx_size),
        .BYTE_COUNT(line_byte_count)
    ) L1_data_data_inst( // module that holds data bits L1
        .clk(clk),
        .we(we),
        .byte_enable(byte_enable),
        .addr(tag_and_idx[idx_size-1:0]),
        .write_data(block_write),
        .read_data(block_read)
    );

    L1_data_tgv #(
        .DATA_WIDTH(tag_size + 1),
        .ADDR_WIDTH(idx_size),
        .RAM_DEPTH(1 << idx_size)
    ) L1_data_valid_tag_inst( // module that holds the valid & data bits
        .clk(clk),
        .rst(rst),
        .we(we),
        .addr(tag_and_idx[idx_size-1:0]),
        .write_data({1'b1, tag_and_idx[tag_size + idx_size - 1:idx_size]}),
        .read_data({valid,tag})
    );

endmodule
