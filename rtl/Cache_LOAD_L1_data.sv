`timescale 1ns / 1ps
module Cache_LOAD_L1_data#(
    parameter offset_size = 2,
    parameter word_size = 2,
    parameter block_size = 128,
    parameter data_width = 64
    )
    (
    input [block_size-1:0] data_block,
    input [offset_size-1:0] offset,
    input [word_size-1:0] word,
    output reg [data_width-1:0] data
    );

    integer byte_index;
    integer line_byte_index;
    integer word_index;
    integer offset_index;

    always @(*) begin
        data = {data_width{1'b0}};
        word_index = {{(32-word_size){1'b0}}, word};
        offset_index = {{(32-offset_size){1'b0}}, offset};
        for (byte_index = 0; byte_index < (data_width / 8); byte_index = byte_index + 1) begin
            line_byte_index = byte_index + (word_index * 4) + offset_index;
            if (line_byte_index < (block_size / 8)) begin
                data[byte_index*8 +: 8] = data_block[line_byte_index*8 +: 8];
            end
        end
    end
endmodule
