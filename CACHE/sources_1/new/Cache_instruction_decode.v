`timescale 1ns / 1ps
module Cache_instruction_decode#(
    parameter word_size = 2,
    parameter block_size = 128,
    parameter offset_size = 2
    )
    (
    input read_i,
    input hit_next_i,
    input [word_size-1:0] word_i,
    input  offset_i, // MSB bit offset
    input [block_size-1:0] data_block_i,
    input [15:0] data_block_next_i,
    output reg [31:0] data_core_o,
    output reg flag_o   // there is a need to read from next idx address and there is a miss in next address
    );
    wire [31:0] data_word_next; // 32 bit = next word data
    wire [31:0] data_word;   // 32 bit = word data
    wire [63:0] data_normal; // 64 bit = double word data
    reg [15:0] data_temp; // holding the 16 bit data because current address will not be read if there is a flag_o
    
    assign data_normal = word_i[1] == 1'b0 ? data_block_i[63:0] : data_block_i[127:64]; 
    assign data_word = word_i[0] == 1 ? data_normal[63:32] : data_normal[31:0]; 
    assign data_word_next = word_i == 2'b00 ? data_block_i[63:32] : ((word_i == 2'b01) ? data_block_i[95:64] : ((word_i == 2'b10) ? data_block_i[127:96] : {16'b0,data_block_next_i})); // word_input == 2'b11 olunca problem olcak.

    always @(*) begin
        if (read_i) begin 
            if(offset_i == 1'b1) begin // Whether we are reading PC + 2 or PC + 4, we should do a decoding according to it (here we are reading from PC+2.)
                if(data_word[17:16] != 2'b11) begin // instruction compressed if the last two bits are not 11
                    data_core_o = {16'b0, data_word[31:16]};
                    flag_o = 1'b0;  
                end
                else begin
                    data_core_o = {data_word_next [15:0], data_word[31:16]};        
                    if(word_i == 2'b11 & ~hit_next_i) begin
                        flag_o = 1'b1; // write to the next address, then go back to the first address
                    end
                    else begin
                        flag_o = 1'b0;
                    end 
                end
            end
            else begin // offset_i[1] == 0, we are reading from PC+4
                if(data_word[1:0] != 2'b11) begin // instruction compressed if the last two bits are 11
                    data_core_o = {16'b0, data_word[15:0]};
                    flag_o = 1'b0;
                end
                else begin
                    data_core_o = data_word;
                    flag_o = 1'b0;
                end
            end
        end
    end
endmodule
