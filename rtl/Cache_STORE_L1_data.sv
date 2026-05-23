`timescale 1ns / 1ps

module Cache_STORE_L1_data#(
    parameter offset_size = 2,
    parameter word_size = 2,
    parameter block_size = 128,
    parameter data_width = 64
) (
    input write_L2,
    input [block_size-1:0] data_L2,
    input [data_width-1:0] write_data,
    input [(data_width/8)-1:0] write_strobe,
    input [offset_size-1:0] offset,
    input [word_size-1:0] word,
    output reg [7:0] byte_enable_h,
    output reg [7:0] byte_enable_l,
    output reg [block_size-1:0] data_in_write
);

    integer byte_index;
    integer line_byte_index;

    always @(*) begin
        data_in_write = {block_size{1'b0}};
        byte_enable_h = 8'b0;
        byte_enable_l = 8'b0;
        line_byte_index = 0;

        if (write_L2) begin
            data_in_write = data_L2;
            byte_enable_h = 8'hff;
            byte_enable_l = 8'hff;
            end else begin
            for (byte_index = 0; byte_index < (data_width / 8); byte_index = byte_index + 1) begin
                line_byte_index = byte_index;
                case (word)
                    2'b01: line_byte_index = line_byte_index + 4;
                    2'b10: line_byte_index = line_byte_index + 8;
                    2'b11: line_byte_index = line_byte_index + 12;
                    default: line_byte_index = line_byte_index;
                endcase
                case (offset)
                    2'b01: line_byte_index = line_byte_index + 1;
                    2'b10: line_byte_index = line_byte_index + 2;
                    2'b11: line_byte_index = line_byte_index + 3;
                    default: line_byte_index = line_byte_index;
                endcase
                if (write_strobe[byte_index] && (line_byte_index < (block_size / 8))) begin
                    data_in_write[line_byte_index*8 +: 8] = write_data[byte_index*8 +: 8];
                    if (line_byte_index < 8) begin
                        byte_enable_l[line_byte_index] = 1'b1;
                    end else begin
                        byte_enable_h[line_byte_index-8] = 1'b1;
                    end
                end
            end
        end
    end

endmodule
