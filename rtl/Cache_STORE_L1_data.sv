`timescale 1ns / 1ps

module Cache_STORE_L1_data#(
    parameter offset_size = 2,
    parameter word_size = 2,
    parameter block_size = 128,
    parameter data_width = 64,
    parameter line_byte_count = block_size / 8
) (
    input write_L2,
    input [block_size-1:0] data_L2,
    input [data_width-1:0] write_data,
    input [(data_width/8)-1:0] write_strobe,
    input [offset_size-1:0] offset,
    input [word_size-1:0] word,
    output reg [line_byte_count-1:0] byte_enable,
    output reg [block_size-1:0] data_in_write
);

    integer byte_index;
    integer line_byte_index;
    integer word_index;
    integer offset_index;

    always @(*) begin
        data_in_write = {block_size{1'b0}};
        byte_enable = {line_byte_count{1'b0}};
        line_byte_index = 0;
        word_index = {{(32-word_size){1'b0}}, word};
        offset_index = {{(32-offset_size){1'b0}}, offset};

        if (write_L2) begin
            data_in_write = data_L2;
            byte_enable = {line_byte_count{1'b1}};
            end else begin
            for (byte_index = 0; byte_index < (data_width / 8); byte_index = byte_index + 1) begin
                line_byte_index = byte_index + (word_index * 4) + offset_index;
                if (write_strobe[byte_index] && (line_byte_index < (block_size / 8))) begin
                    data_in_write[line_byte_index*8 +: 8] = write_data[byte_index*8 +: 8];
                    byte_enable[line_byte_index] = 1'b1;
                end
            end
        end
    end

endmodule
