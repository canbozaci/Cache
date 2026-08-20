// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps
module cache_l2_memory_way#(
    parameter LINE_WIDTH = 128,
    parameter TAG_WIDTH = 7,
    parameter INDEX_WIDTH = 8,
    parameter LINE_BYTE_COUNT = LINE_WIDTH / 8
    )
    (
    input clk,
    input rst_n,
    input [LINE_WIDTH-1:0] block_write_p1,
    input [LINE_WIDTH-1:0] block_write_p2,
    input [TAG_WIDTH + INDEX_WIDTH-1:0] tag_and_idx_p1,
    input [TAG_WIDTH + INDEX_WIDTH-1:0] tag_and_idx_p2,
    input we_p1,
    input we_p2,
    input invalidate,
    input [TAG_WIDTH + INDEX_WIDTH-1:0] invalidate_tag_and_idx,
    input [LINE_BYTE_COUNT-1:0] byte_enable_p1,
    input [LINE_BYTE_COUNT-1:0] byte_enable_p2,
    output [LINE_WIDTH-1:0] block_read_p1,
    output [LINE_WIDTH-1:0] block_read_p2,
    output valid_p1,
    output valid_p2,
    output [TAG_WIDTH -1:0] tag_p1,
    output [TAG_WIDTH -1:0] tag_p2
    );


    cache_l2_memory_array #(
        .NUM_COL(LINE_BYTE_COUNT),
        .COL_WIDTH(8),
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(LINE_WIDTH)
    ) cache_l2_memory_array_inst(
        .clk(clk),
        .we_p1(we_p1),
        .we_p2(we_p2),
        .byte_enable_p1(byte_enable_p1),
        .byte_enable_p2(byte_enable_p2),
        .addr_p1(tag_and_idx_p1[INDEX_WIDTH-1:0]),
        .addr_p2(tag_and_idx_p2[INDEX_WIDTH-1:0]),
        .write_data_p1(block_write_p1),
        .write_data_p2(block_write_p2),
        .read_data_p1(block_read_p1),
        .read_data_p2(block_read_p2)
    );

    cache_l2_memory_tag_valid_array #(
        .NUM_COL(1),
        .COL_WIDTH(TAG_WIDTH + 1),
        .ADDR_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(TAG_WIDTH + 1)
    ) cache_l2_memory_tag_valid_array_inst(
        .clk(clk),
        .rst_n(rst_n),
        .we_p1(we_p1),
        .we_p2(we_p2),
        .invalidate(invalidate),
        .addr_p1(tag_and_idx_p1[INDEX_WIDTH-1:0]),
        .addr_p2(tag_and_idx_p2[INDEX_WIDTH-1:0]),
        .invalidate_addr(invalidate_tag_and_idx[INDEX_WIDTH-1:0]),
        .invalidate_tag(invalidate_tag_and_idx[TAG_WIDTH+INDEX_WIDTH-1:INDEX_WIDTH]),
        .write_data_p1({1'b1,tag_and_idx_p1[TAG_WIDTH+INDEX_WIDTH-1:INDEX_WIDTH]}),
        .write_data_p2({1'b1,tag_and_idx_p2[TAG_WIDTH+INDEX_WIDTH-1:INDEX_WIDTH]}),
        .read_data_p1({valid_p1,tag_p1}),
        .read_data_p2({valid_p2,tag_p2})
    );

endmodule
