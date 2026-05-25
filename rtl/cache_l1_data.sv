`timescale 1ns / 1ps

module cache_l1_data#( // L1 data cache top module
    parameter LINE_WIDTH = 128,
    parameter TAG_WIDTH = 9,
    parameter INDEX_WIDTH = 6,
    parameter SET_COUNT = 64,
    parameter WORD_OFFSET_WIDTH = 2,
    parameter BYTE_OFFSET_WIDTH = 2,
    parameter DATA_WIDTH = 64,
    parameter LINE_BYTE_COUNT = LINE_WIDTH / 8
    )
    (
    input clk,
    input rst,
    input read,
    input write,
    input write_L2,
    input write_through,
    input invalidate_line,
    input [TAG_WIDTH+INDEX_WIDTH-1:0] invalidate_tag_and_idx,
    input [TAG_WIDTH+INDEX_WIDTH+WORD_OFFSET_WIDTH+BYTE_OFFSET_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] write_data,
    input [(DATA_WIDTH/8)-1:0] write_strobe,
    input [LINE_WIDTH-1:0] data_L2,
    output [LINE_WIDTH-1:0]  data_block,
    output [DATA_WIDTH-1:0] data,
    output hit
    );
    // wires
    wire [LINE_WIDTH-1:0] data_in_write;
    wire [LINE_BYTE_COUNT-1:0] byte_enable;
    wire [TAG_WIDTH -1:0] tag_input;
    wire [INDEX_WIDTH -1:0] idx_input;
    wire [WORD_OFFSET_WIDTH-1:0] word_input;
    wire [BYTE_OFFSET_WIDTH-1:0] offset_input;
    wire cache_set_output_select;
    wire [LINE_WIDTH -1:0] data_out_s1;
    wire [LINE_WIDTH -1:0] data_out_s2;
    wire [TAG_WIDTH -1:0] tag_out_s1;
    wire [TAG_WIDTH -1:0] tag_out_s2;
    wire valid_out_s1; // valid bits with addressing
    wire valid_out_s2; // valid bits with addressing
    wire we_s1;
    wire we_s2;
    wire hit_s1;
    wire hit_s2;
    wire we_set1;
    wire we_set2;

    assign tag_input    = addr[TAG_WIDTH + INDEX_WIDTH + WORD_OFFSET_WIDTH +  BYTE_OFFSET_WIDTH  - 1:INDEX_WIDTH + WORD_OFFSET_WIDTH + BYTE_OFFSET_WIDTH];
    assign idx_input    = addr[INDEX_WIDTH + WORD_OFFSET_WIDTH + BYTE_OFFSET_WIDTH - 1:WORD_OFFSET_WIDTH+BYTE_OFFSET_WIDTH];
    assign word_input   = addr[WORD_OFFSET_WIDTH+BYTE_OFFSET_WIDTH -1 :BYTE_OFFSET_WIDTH];
    assign offset_input = addr[BYTE_OFFSET_WIDTH-1:0];
    assign we_set2 = write & we_s2;
    assign we_set1 = write & we_s1;
    assign hit = ((read | write) & (hit_s1 | hit_s2)) & (~rst);
    assign cache_set_output_select = ((read | write) & (hit_s2 & (~hit_s1)));

    cache_l1_data_way#( // SET1
        .LINE_WIDTH(LINE_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT)
        )
    cache_set_0(
        .clk(clk),
        .rst(rst),
        .block_write(data_in_write),
        .tag_and_idx({tag_input,idx_input}),
        .we(we_set1),
        .invalidate(invalidate_line),
        .invalidate_tag_and_idx(invalidate_tag_and_idx),
        .byte_enable(byte_enable),
        .block_read(data_out_s1),
        .valid(valid_out_s1),
        .tag(tag_out_s1)
        );

    cache_l1_data_way#( // SET2
        .LINE_WIDTH(LINE_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .LINE_BYTE_COUNT(LINE_BYTE_COUNT)
        )
    cache_set_1(
        .clk(clk),
        .rst(rst),
        .block_write(data_in_write),
        .tag_and_idx({tag_input,idx_input}),
        .we(we_set2),
        .invalidate(invalidate_line),
        .invalidate_tag_and_idx(invalidate_tag_and_idx),
        .byte_enable(byte_enable),
        .block_read(data_out_s2),
        .valid(valid_out_s2),
        .tag(tag_out_s2)
        );

    cache_tag_match#( // IDENTIFICATION FOR SET1
        .TAG_WIDTH(TAG_WIDTH)
        )
    cache_identification_set_0(
        .tag(tag_input),
        .valid_mem(valid_out_s1),
        .tag_mem(tag_out_s1),
        .hit(hit_s1)
        );

    cache_tag_match#( // IDENTIFICATION FOR SET2
        .TAG_WIDTH(TAG_WIDTH)
        )
    cache_identification_set_1(
        .tag(tag_input),
        .valid_mem(valid_out_s2),
        .tag_mem(tag_out_s2),
        .hit(hit_s2)
        );

    cache_l1_replacement#(
        .INDEX_WIDTH(INDEX_WIDTH),
        .SET_COUNT(SET_COUNT)
        )
    cache_replacement_inst(
        .clk(clk),
        .rst(rst),
        .read(read),
        .write(write),
        .idx(idx_input),
        .hit_s1(hit_s1),
        .hit_s2(hit_s2),
        .write_L2(write_L2),
        .write_through(write_through),
        .valid_out_s1(valid_out_s1),
        .valid_out_s2(valid_out_s2),
        .we_s1(we_s1),
        .we_s2(we_s2)
        );

    cache_way_select #(
        .LINE_WIDTH(LINE_WIDTH)
        )
    cache_way_select_inst(
        .hit(hit),
        .cache_set_output_select(cache_set_output_select),
        .data_out_s2(data_out_s2),
        .data_out_s1(data_out_s1),
        .data_block(data_block)
        );

    cache_l1_data_load #(
        .BYTE_OFFSET_WIDTH(BYTE_OFFSET_WIDTH),
        .WORD_OFFSET_WIDTH(WORD_OFFSET_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
        )
    cache_l1_data_load_inst(
        .data_block(data_block),
        .offset(offset_input),
        .word(word_input),
        .data(data)
        );

    cache_l1_data_store#(
        .BYTE_OFFSET_WIDTH(BYTE_OFFSET_WIDTH),
        .WORD_OFFSET_WIDTH(WORD_OFFSET_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
        )
    cache_l1_data_store_inst(
        .write_L2(write_L2),
        .data_L2(data_L2),
        .write_data(write_data),
        .write_strobe(write_strobe),
        .offset(offset_input),
        .word(word_input),
        .byte_enable(byte_enable),
        .data_in_write(data_in_write)
        );
endmodule
