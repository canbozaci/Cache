// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps
module cache_l1_memory_load#(
    parameter BYTE_OFFSET_WIDTH = 2,
    parameter WORD_OFFSET_WIDTH = 2,
    parameter LINE_WIDTH = 128,
    parameter DATA_WIDTH = 64
    )
    (
    input [LINE_WIDTH-1:0] data_block,
    input [BYTE_OFFSET_WIDTH-1:0] offset,
    input [WORD_OFFSET_WIDTH-1:0] word,
    output reg [DATA_WIDTH-1:0] data
    );

    integer byte_index;
    integer line_byte_index;
    integer word_index;
    integer offset_index;
    integer access_base;

    localparam integer ACCESS_BYTES = DATA_WIDTH / 8;

    always @(*) begin
        data = {DATA_WIDTH{1'b0}};
        word_index = {{(32-WORD_OFFSET_WIDTH){1'b0}}, word};
        offset_index = {{(32-BYTE_OFFSET_WIDTH){1'b0}}, offset};
        access_base = ((word_index * 4) + offset_index) & ~(ACCESS_BYTES - 1);
        for (byte_index = 0; byte_index < (DATA_WIDTH / 8); byte_index = byte_index + 1) begin
            // byte_index already carries the position inside the access:
            // the strobe is pre-shifted by the low address bits. So the base
            // must be the access-aligned byte offset, or addr[2:0] is counted
            // twice and two distinct words alias onto one slot in the line.
            line_byte_index = byte_index + access_base;
            if (line_byte_index < (LINE_WIDTH / 8)) begin
                data[byte_index*8 +: 8] = data_block[line_byte_index*8 +: 8];
            end
        end
    end
endmodule
