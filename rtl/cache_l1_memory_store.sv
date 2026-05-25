`timescale 1ns / 1ps

module cache_l1_memory_store#(
    parameter BYTE_OFFSET_WIDTH = 2,
    parameter WORD_OFFSET_WIDTH = 2,
    parameter LINE_WIDTH = 128,
    parameter DATA_WIDTH = 64,
    parameter LINE_BYTE_COUNT = LINE_WIDTH / 8
) (
    input write_L2,
    input [LINE_WIDTH-1:0] data_L2,
    input [DATA_WIDTH-1:0] write_data,
    input [(DATA_WIDTH/8)-1:0] write_strobe,
    input [BYTE_OFFSET_WIDTH-1:0] offset,
    input [WORD_OFFSET_WIDTH-1:0] word,
    output reg [LINE_BYTE_COUNT-1:0] byte_enable,
    output reg [LINE_WIDTH-1:0] data_in_write
);

    integer byte_index;
    integer line_byte_index;
    integer word_index;
    integer offset_index;

    always @(*) begin
        data_in_write = {LINE_WIDTH{1'b0}};
        byte_enable = {LINE_BYTE_COUNT{1'b0}};
        line_byte_index = 0;
        word_index = {{(32-WORD_OFFSET_WIDTH){1'b0}}, word};
        offset_index = {{(32-BYTE_OFFSET_WIDTH){1'b0}}, offset};

        if (write_L2) begin
            data_in_write = data_L2;
            byte_enable = {LINE_BYTE_COUNT{1'b1}};
            end else begin
            for (byte_index = 0; byte_index < (DATA_WIDTH / 8); byte_index = byte_index + 1) begin
                line_byte_index = byte_index + (word_index * 4) + offset_index;
                if (write_strobe[byte_index] && (line_byte_index < (LINE_WIDTH / 8))) begin
                    data_in_write[line_byte_index*8 +: 8] = write_data[byte_index*8 +: 8];
                    byte_enable[line_byte_index] = 1'b1;
                end
            end
        end
    end

endmodule
