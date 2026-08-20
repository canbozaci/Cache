// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps
module cache_l2#( // L2 cache
    parameter LINE_WIDTH = 128,
    parameter TAG_WIDTH = 7,
    parameter INDEX_WIDTH = 8,
    parameter SET_COUNT = 256,
    parameter LINE_BYTE_COUNT = LINE_WIDTH / 8
    )
    (
    input clk,
    input rst_n,
    input read_p1,
    input read_p2,
    input write_p1,
    input write_p2,
    input [LINE_WIDTH-1:0] data_block_write_p1,
    input [LINE_WIDTH-1:0] data_block_write_p2,
    input [LINE_BYTE_COUNT-1:0] byte_enable_p1,
    input [LINE_BYTE_COUNT-1:0] byte_enable_p2,
    input [TAG_WIDTH+INDEX_WIDTH-1:0] addr_p1,
    input [TAG_WIDTH+INDEX_WIDTH-1:0] addr_p2,
    input invalidate_line,
    input [TAG_WIDTH+INDEX_WIDTH-1:0] invalidate_addr,
    input ram_write_start,
    input write_through,
    output [LINE_WIDTH-1:0] data_block_read_p1, // data out read port 1 (data cache & main memory write)
    output [LINE_WIDTH-1:0] data_block_read_p2, // data out read port 2 (instr cache write)
    output hit_p1,
    output hit_p2
    );
    // wires
    wire valid_out_s1_p1; // valid bits with addressing
    wire valid_out_s2_p1; // valid bits with addressing
    wire valid_out_s1_p2;
    wire valid_out_s2_p2;

    wire [TAG_WIDTH-1:0] tag_out_s1_p1;
    wire [TAG_WIDTH-1:0] tag_out_s2_p1;
    wire [TAG_WIDTH-1:0] tag_out_s1_p2;
    wire [TAG_WIDTH-1:0] tag_out_s2_p2;


    wire [TAG_WIDTH -1:0] tag_input_p1;
    wire [INDEX_WIDTH -1:0] idx_input_p1;
    wire [TAG_WIDTH -1:0] tag_input_p2;
    wire [INDEX_WIDTH -1:0] idx_input_p2;

    wire cache_set_output_select_p1;
    wire cache_set_output_select_p2;

    wire [LINE_WIDTH -1:0] data_out_s1_p1;
    wire [LINE_WIDTH -1:0] data_out_s2_p1;
    wire [LINE_WIDTH -1:0] data_out_s1_p2;
    wire [LINE_WIDTH -1:0] data_out_s2_p2;

    wire we_s1_p1;
    wire we_s2_p1;
    wire we_s1_p2;
    wire we_s2_p2;

    wire hit_s1_p1;
    wire hit_s2_p1;
    wire hit_s1_p2;
    wire hit_s2_p2;

    wire we_set1_p1;
    wire we_set2_p1;
    wire we_set1_p2;
    wire we_set2_p2;

    assign tag_input_p2    = addr_p2[TAG_WIDTH + INDEX_WIDTH - 1:INDEX_WIDTH];
    assign idx_input_p2    = addr_p2[INDEX_WIDTH - 1:0];

    assign tag_input_p1    = addr_p1[TAG_WIDTH + INDEX_WIDTH - 1:INDEX_WIDTH];
    assign idx_input_p1    = addr_p1[INDEX_WIDTH - 1:0];


    assign we_set2_p1  = write_p1 & we_s2_p1;
    assign we_set1_p1  = write_p1 & we_s1_p1;
    assign we_set2_p2  = write_p2 & we_s2_p2;
    assign we_set1_p2  = write_p2 & we_s1_p2;

    assign hit_p1 = ((read_p1) & (hit_s1_p1 | hit_s2_p1)) & rst_n;
    assign hit_p2 = ((read_p2) & (hit_s1_p2 | hit_s2_p2)) & rst_n;

    assign cache_set_output_select_p1 = ((read_p1) & (hit_s2_p1 & (~hit_s1_p1)));
    assign cache_set_output_select_p2 = ((read_p2) & (hit_s2_p2 & (~hit_s1_p2)));

    cache_l2_memory_way #(
        .LINE_WIDTH(LINE_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT)
    ) cache_l2_memory_way_0(
        .clk(clk),
        .rst_n(rst_n),
        .block_write_p1(data_block_write_p1),
        .block_write_p2(data_block_write_p2),
        .tag_and_idx_p1({tag_input_p1,idx_input_p1}),
        .tag_and_idx_p2({tag_input_p2,idx_input_p2}),
        .we_p1(we_set1_p1),
        .we_p2(we_set1_p2),
        .invalidate(invalidate_line),
        .invalidate_tag_and_idx(invalidate_addr),
        .byte_enable_p1(byte_enable_p1),
        .byte_enable_p2(byte_enable_p2),
        .block_read_p1(data_out_s1_p1),
        .block_read_p2(data_out_s1_p2),
        .valid_p1(valid_out_s1_p1),
        .valid_p2(valid_out_s1_p2),
        .tag_p1(tag_out_s1_p1),
        .tag_p2(tag_out_s1_p2)
    );

    cache_l2_memory_way #(
        .LINE_WIDTH(LINE_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT)
    ) cache_l2_memory_way_1(
        .clk(clk),
        .rst_n(rst_n),
        .block_write_p1(data_block_write_p1),
        .block_write_p2(data_block_write_p2),
        .tag_and_idx_p1({tag_input_p1,idx_input_p1}),
        .tag_and_idx_p2({tag_input_p2,idx_input_p2}),
        .we_p1(we_set2_p1),
        .we_p2(we_set2_p2),
        .invalidate(invalidate_line),
        .invalidate_tag_and_idx(invalidate_addr),
        .byte_enable_p1(byte_enable_p1),
        .byte_enable_p2(byte_enable_p2),
        .block_read_p1(data_out_s2_p1),
        .block_read_p2(data_out_s2_p2),
        .valid_p1(valid_out_s2_p1),
        .valid_p2(valid_out_s2_p2),
        .tag_p1(tag_out_s2_p1),
        .tag_p2(tag_out_s2_p2)
    );

    cache_tag_match#( // IDENTIFICATION FOR SET1 READ PORT 1
        .TAG_WIDTH(TAG_WIDTH)
        )
    cache_identification_set_1_r1(
        .tag(tag_input_p1),
        .valid_mem(valid_out_s1_p1),
        .tag_mem(tag_out_s1_p1),
        .hit(hit_s1_p1)
        );

    cache_tag_match#( // IDENTIFICATION FOR SET1 READ PORT 2
        .TAG_WIDTH(TAG_WIDTH)
        )
    cache_identification_set_1_r2(
        .tag(tag_input_p2),
        .valid_mem(valid_out_s1_p2),
        .tag_mem(tag_out_s1_p2),
        .hit(hit_s1_p2)
        );

    cache_tag_match#( // IDENTIFICATION FOR SET2 READ PORT 1
        .TAG_WIDTH(TAG_WIDTH)
        )
    cache_identification_set_2_r1(
        .tag(tag_input_p1),
        .valid_mem(valid_out_s2_p1),
        .tag_mem(tag_out_s2_p1),
        .hit(hit_s2_p1)
        );

    cache_tag_match#( // IDENTIFICATION FOR SET2 READ PORT 2
        .TAG_WIDTH(TAG_WIDTH)
        )
    cache_identification_set_2_r2(
        .tag(tag_input_p2),
        .valid_mem(valid_out_s2_p2),
        .tag_mem(tag_out_s2_p2),
        .hit(hit_s2_p2)
        );

    cache_l2_replacement#( // REPLACEMENT ALGORITMASI
        .INDEX_WIDTH(INDEX_WIDTH),
        .SET_COUNT(SET_COUNT)
        )
    cache_replacement_L2_inst(
        .clk(clk),
        .rst_n(rst_n),
        .read_p1(read_p1),
        .read_p2(read_p2),
        .write_p1(write_p1),
        .write_p2(write_p2),
        .idx_p1(idx_input_p1),
        .idx_p2(idx_input_p2),
        .hit_s1_p1(hit_s1_p1),
        .hit_s2_p1(hit_s2_p1),
        .hit_s1_p2(hit_s1_p2),
        .hit_s2_p2(hit_s2_p2),
        .valid_out_s1_p1(valid_out_s1_p1),
        .valid_out_s2_p1(valid_out_s2_p1),
        .valid_out_s1_p2(valid_out_s1_p2),
        .valid_out_s2_p2(valid_out_s2_p2),
        .ram_write_start(ram_write_start),
        .write_through(write_through),
        .we_s1_p1(we_s1_p1),
        .we_s2_p1(we_s2_p1),
        .we_s1_p2(we_s1_p2),
        .we_s2_p2(we_s2_p2)
        );

    cache_way_select #(
        .LINE_WIDTH(LINE_WIDTH)
        )
    cache_way_select_inst_P1(
        .hit(hit_p1 | write_through),
        .cache_set_output_select(cache_set_output_select_p1),
        .data_out_s2(data_out_s2_p1),
        .data_out_s1(data_out_s1_p1),
        .data_block(data_block_read_p1)
        );

    cache_way_select #(
        .LINE_WIDTH(LINE_WIDTH)
        )
    cache_way_select_inst_P2(
        .hit(hit_p2),
        .cache_set_output_select(cache_set_output_select_p2),
        .data_out_s2(data_out_s2_p2),
        .data_out_s1(data_out_s1_p2),
        .data_block(data_block_read_p2)
        );

endmodule
