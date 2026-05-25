`timescale 1ns / 1ps
module cache_l1_data_way#(
    parameter LINE_WIDTH = 128,
    parameter TAG_WIDTH = 9,
    parameter INDEX_WIDTH = 6,
    parameter LINE_BYTE_COUNT = LINE_WIDTH / 8
    )
    (
    input clk,
    input rst,
    input [LINE_WIDTH-1:0] block_write,
    input [TAG_WIDTH + INDEX_WIDTH-1:0] tag_and_idx,
    input we,
    input invalidate,
    input [TAG_WIDTH + INDEX_WIDTH-1:0] invalidate_tag_and_idx,
    input [LINE_BYTE_COUNT-1:0] byte_enable,
    output [LINE_WIDTH-1:0] block_read,
    output valid,
    output [TAG_WIDTH -1:0] tag
    );

    cache_l1_data_array #(
        .DATA_WIDTH(LINE_WIDTH),
        .ADDR_WIDTH(INDEX_WIDTH),
        .BYTE_COUNT(LINE_BYTE_COUNT)
    ) cache_l1_data_arraya_inst( // module that holds data bits L1
        .clk(clk),
        .we(we),
        .byte_enable(byte_enable),
        .addr(tag_and_idx[INDEX_WIDTH-1:0]),
        .write_data(block_write),
        .read_data(block_read)
    );

    cache_l1_tag_valid_array #(
        .DATA_WIDTH(TAG_WIDTH + 1),
        .ADDR_WIDTH(INDEX_WIDTH),
        .RAM_DEPTH(1 << INDEX_WIDTH)
    ) cache_l1_tag_valid_array_inst( // module that holds the valid & data bits
        .clk(clk),
        .rst(rst),
        .we(we),
        .invalidate(invalidate),
        .addr(tag_and_idx[INDEX_WIDTH-1:0]),
        .invalidate_addr(invalidate_tag_and_idx[INDEX_WIDTH-1:0]),
        .invalidate_tag(invalidate_tag_and_idx[TAG_WIDTH + INDEX_WIDTH - 1:INDEX_WIDTH]),
        .write_data({1'b1, tag_and_idx[TAG_WIDTH + INDEX_WIDTH - 1:INDEX_WIDTH]}),
        .read_data({valid,tag})
    );

endmodule
