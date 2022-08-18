`timescale 1ns / 1ps
module Cache_LOAD_L1_data#(
    parameter offset_size = 2,
    parameter word_size = 2
    )
    (
    input [127:0] data_block_i,
    input [offset_size-1:0] offset_i,
    input [word_size-1:0] word_i,
    input [2:0] read_instruction_i, 
    output reg [63:0] data_o
    );
    wire [31:0] data_word; // 32 bit = word data
    wire [63:0] data_normal; // 64 bit = double word data
    wire [63:0] data_normal_SD; 
    assign data_normal_SD = word_i[1:0] == 2'b00 ? data_block_i[63:0] : (word_i[1:0] == 2'b01) ? data_block_i[95:32] : (word_i[1:0] == 2'b10) ? data_block_i[127:64] : data_block_i[127:64]; // word_i == 2'b11 olması mantiksal hata.
    assign data_normal = word_i[1] == 1'b0 ? data_block_i[63:0] : data_block_i[127:64]; 
    assign data_word = word_i[0] == 1 ? data_normal[63:32] : data_normal[31:0];

    parameter LBU = 3'b100, // parametric LOAD signal (FUNC3)
    LB  = 3'b000,
    LHU = 3'b101,
    LH =  3'b001,
    LWU = 3'b110,
    LW  = 3'b010,
    LD  = 3'b011;
    
    always @(*) begin
        case(read_instruction_i)
        LBU: begin //We choose which byte to sent according to the offset bits, the rest is 0 because it is unsigned
            if (offset_i == 2'b00) begin
                data_o = {56'd0,data_word[7:0]};
            end
            else if(offset_i == 2'b01) begin
                data_o = {56'd0,data_word[15:8]};
            end
            else if(offset_i == 2'b10) begin
                data_o = {56'd0,data_word[23:16]};
            end
            else begin
                data_o = {56'd0,data_word[31:24]};
            end
        end
        LB: begin //We choose which byte to sent according to the offset bits, the rest is MSB of byte because it is signed
            if (offset_i == 2'b00) begin
                data_o = {{56{data_word[7]}},data_word[7:0]};
            end
            else if(offset_i == 2'b01) begin
                data_o = {{56{data_word[15]}},data_word[15:8]};
            end
            else if(offset_i == 2'b10) begin
                data_o = {{56{data_word[23]}},data_word[23:16]};
            end
            else begin
                data_o = {{56{data_word[31]}},data_word[31:24]};
            end
        end
        LHU: begin //We choose which half-word to sent according to the offset bits, the rest is 0 because it is unsigned
            if (offset_i == 2'b00) begin
                data_o = {48'd0,data_word[15:0]};
            end
            else if(offset_i == 2'b01) begin
                data_o = {48'd0,data_word[23:8]};
            end
            else if(offset_i == 2'b10) begin
                data_o = {48'd0,data_word[31:16]};
            end
            else begin // Logic Error
                data_o = {48'd0,data_normal[39:24]};
            end
        end
        LH: begin //We choose which half-word to sent according to the offset bits, the rest is MSB of half-word because it is signed
            if (offset_i == 2'b00) begin
                data_o = {{48{data_word[15]}},data_word[15:0]};
            end
            else if(offset_i == 2'b01) begin
                data_o = {{48{data_word[23]}},data_word[23:8]};
            end
            else if(offset_i == 2'b10) begin
                data_o = {{48{data_word[31]}},data_word[31:16]};
            end
            else begin // Logic Error
                data_o = {{48{data_normal[39]}},data_normal[39:24]};
            end
        end
        LWU: begin // msb is 0 bcs unsigned
                data_o = {32'd0,data_word};
        end
        LW: begin // msbs are MSB of data_word bcs signed
                data_o = {{32{data_word[31]}},data_word}; 
        end
        LD: begin
            data_o = data_normal_SD;
        end
        default: data_o = data_normal;
        endcase
    end
endmodule
