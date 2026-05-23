`timescale 1ns / 1ps
module Cache_SET_L2#(
    parameter block_size = 128,
    parameter tag_size = 7,
    parameter idx_size = 8,
    parameter line_byte_count = block_size / 8
    )
    (
    input clk,
    input rst,
    input [block_size-1:0] block_write_p1,
    input [block_size-1:0] block_write_p2,
    input [tag_size + idx_size-1:0] tag_and_idx_p1,
    input [tag_size + idx_size-1:0] tag_and_idx_p2,
    input we_p1, 
    input we_p2, 
    input [line_byte_count-1:0] byte_enable_p1,
    input [line_byte_count-1:0] byte_enable_p2,
    output [block_size-1:0] block_read_p1,
    output [block_size-1:0] block_read_p2,
    output valid_p1,
    output valid_p2,
    output [tag_size -1:0] tag_p1,
    output [tag_size -1:0] tag_p2
    );
    

    L2_dat #(
        .NUM_COL(line_byte_count),
        .COL_WIDTH(8),
        .ADDR_WIDTH(idx_size),
        .DATA_WIDTH(block_size)
    ) L2_data_inst( // module that holds data bits L2
        .clk(clk), 
        .we_p1(we_p1),
        .we_p2(we_p2), 
        .byte_enable_p1(byte_enable_p1), 
        .byte_enable_p2(byte_enable_p2),
        .addr_p1(tag_and_idx_p1[idx_size-1:0]),
        .addr_p2(tag_and_idx_p2[idx_size-1:0]),
        .write_data_p1(block_write_p1),
        .write_data_p2(block_write_p2),
        .read_data_p1(block_read_p1),
        .read_data_p2(block_read_p2)
    );

    L2_tgv #(
        .NUM_COL(1),
        .COL_WIDTH(tag_size + 1),
        .ADDR_WIDTH(idx_size),
        .DATA_WIDTH(tag_size + 1)
    ) L2_valid_tag_inst( // module that holds the valid & data bits
        .clk(clk), 
        .rst(rst),
        .we_p1(we_p1),
        .we_p2(we_p2), 
        .addr_p1(tag_and_idx_p1[idx_size-1:0]),
        .addr_p2(tag_and_idx_p2[idx_size-1:0]),
        .write_data_p1({1'b1,tag_and_idx_p1[tag_size+idx_size-1:idx_size]}),
        .write_data_p2({1'b1,tag_and_idx_p2[tag_size+idx_size-1:idx_size]}),
        .read_data_p1({valid_p1,tag_p1}),
        .read_data_p2({valid_p2,tag_p2})
    );

endmodule
