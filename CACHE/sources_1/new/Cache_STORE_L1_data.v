`timescale 1ns / 1ps
module Cache_STORE_L1_data#(parameter offset_size = 2, parameter word_size = 2, parameter block_size = 128)(
    input write_L2_i, // write from L2
    input [block_size-1:0] data_L2_i, // input from L2 cahe
    input [63:0] data_core_i, // input from core
    input [offset_size-1:0] offset_i,
    input [word_size-1:0] word_i,
    input [2:0] write_instruction_i,
    output reg [7:0] byte_enable_h_o, // high indexed byte enable signals
    output reg [7:0] byte_enable_l_o, // low  indexed byte enable signals
    output reg [block_size-1:0] data_in_write_o // which data will be written into L1 data cache
  );

    parameter SB = 3'b000, // parametric STORE signals (according to RISC-V FUNCT3)
              SH = 3'b001,
              SW = 3'b010,
              SD = 3'b011;

    always @(*) begin 
        if(write_L2_i) begin // If write from L2 all byte enables are 1
            data_in_write_o = data_L2_i;
            byte_enable_h_o = 8'b1111_1111;
            byte_enable_l_o = 8'b1111_1111;
        end
        else begin
            case(write_instruction_i) // Here, actually byte_enables are manipulated and controlled according to the word and offsets. At the same time, data_in_write should be changed in the same way so that the written data is compatible with the byte_enable signals there.
            SB: begin
                data_in_write_o = {16{data_core_i[7:0]}}; // Since LSB will be written in 8 bits, we will copy it to all bits so that there is no error.
                if(word_i == 2'b11) begin
                    byte_enable_l_o = 8'b0000_0000; //word_i [1] == 1 so byte_enable_l_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_h_o = 8'b0001_0000; // the most meaningless byte_enable of the high word of the high side 1
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_h_o = 8'b0010_0000; // byte_enable of the 1st byte of the high word of the high side is 1
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_h_o = 8'b0100_0000; // byte_enable of the 2nd byte of the high word of the high side is 1
                    end
                    else begin
                        byte_enable_h_o = 8'b1000_0000; // byte_enable of the 3rd byte of the high word of the high side is 1
                    end
                end
                else if (word_i == 2'b10) begin
                    byte_enable_l_o = 8'b0000_0000; //word_i [1] == 1 so byte_enable_l_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_h_o = 8'b0000_0001; // the most meaningless byte_enable of the low word of the high side is 1
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_h_o = 8'b0000_0010; // byte_enable of the 1st byte of the low word of the high side is 1
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_h_o = 8'b0000_0100; // byte_enable of the 2nd byte of the low word of the high side is 1
                    end
                    else begin
                        byte_enable_h_o = 8'b0000_1000; // byte_enable of the 3rd byte of the low word of the high side is 1
                    end
                end
                else if (word_i == 2'b01) begin
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 so byte_enable_h_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_l_o = 8'b0001_0000; // the most meaningless byte_enable of the high word of the low side is 1
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_l_o = 8'b0010_0000; // byte_enable of the 1st byte of the high word of the low side is 1
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_l_o = 8'b0100_0000; // byte_enable of the 2nd byte of the high word of the low side is 1
                    end
                    else begin
                        byte_enable_l_o = 8'b1000_0000; // byte_enable of the 3rd byte of the high word of the low side is 1
                    end
                end
                else begin
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 so byte_enable_h_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_l_o = 8'b0000_0001; // the most meaningless byte_enable of the low word of the low side is 1
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_l_o = 8'b0000_0010;  // byte_enable of 1st byte of low word of low side is 1
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_l_o = 8'b0000_0100;  // byte_enable of 2nd byte of low word of low side is 1
                    end
                    else begin
                        byte_enable_l_o = 8'b0000_1000;  // byte_enable of 3rd byte of low word of low side is 1
                    end
                end
                end
            SH: begin 
                if(word_i == 2'b11) begin
                    byte_enable_l_o = 8'b0000_0000; //word_i [1] == 1 so byte_enable_l_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_h_o = 8'b0011_0000;  // byte_enable of the 2 most meaningless bytes of the high word of the high side is 1
                        data_in_write_o = {16'b0,data_core_i[15:0],32'b0,64'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_h_o = 8'b0110_0000; // 2nd and 3rd byte of high word of high side byte_enable is 1
                        data_in_write_o = {8'b0,data_core_i[15:0],8'b0,32'b0,64'b0};  // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_h_o = 8'b1100_0000; // 3rd and 4th byte of high word of high side byte_enable is 1
                        data_in_write_o = {data_core_i[15:0],16'b0,32'b0,64'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else begin // Logic ERROR. Reading is made from non-Word. Algorithmic continuation can also be done here, but it is non-logical.
                        byte_enable_h_o = 8'b0000_0000;
                        data_in_write_o = {128'b0};
                    end
                end
                else if(word_i == 2'b10) begin
                    byte_enable_l_o = 8'b0000_0000; //word_i [1] == 1 so byte_enable_l_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_h_o = 8'b0000_0011; // byte_enable of the 2 most meaningless bytes of the low word of the high side is 1
                        data_in_write_o = {48'b0,data_core_i[15:0],64'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_h_o = 8'b0000_0110; // 2nd and 3rd byte of low word of high side byte_enable is 1
                        data_in_write_o = {40'b0,data_core_i[15:0],8'b0,64'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_h_o = 8'b0000_1100; // 3rd and 4th byte of low word of high side byte_enable is 1
                        data_in_write_o = {32'b0,data_core_i[15:0],16'b0,64'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else begin // Logic ERROR. Reading is made from non-Word. Algorithmic continuation can also be done here, but it is non-logical.
                        byte_enable_h_o = 8'b0000_0000;
                        data_in_write_o = {128'b0};
                    end
                end
                else if(word_i == 2'b01) begin
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 so byte_enable_h_o = 0
                    if (offset_i == 2'b00) begin
                        byte_enable_l_o = 8'b0011_0000; // byte_enable of the 2 most meaningless bytes of the high word of the low side is 1
                        data_in_write_o = {64'b0,16'b0,data_core_i[15:0],32'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_l_o = 8'b0110_0000; // 2nd and 3rd byte of high word of low side byte_enable is 1
                        data_in_write_o = {64'b0,8'b0,data_core_i[15:0],8'b0,32'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_l_o = 8'b1100_0000; // 3rd and 4th byte of high word of low side byte_enable is 1
                        data_in_write_o = {64'b0,data_core_i[15:0],16'b0,32'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else begin // Logic ERROR. Reading is made from non-Word. Algorithmic continuation can also be done here, but it is non-logical.
                        byte_enable_l_o = 8'b0000_0000;
                        data_in_write_o = {128'b0};
                    end
                end
                else begin
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 oldugundan byte_enable_h_o = 0 olacak
                    if (offset_i == 2'b00) begin
                        byte_enable_l_o = 8'b0000_0011; // byte_enable of the 2 most meaningless bytes of the low word of the low side is 1
                        data_in_write_o = {64'b0,48'b0,data_core_i[15:0]}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b01) begin
                        byte_enable_l_o = 8'b0000_0110; // 2nd and 3rd byte of low word of low side byte_enable is 1
                        data_in_write_o = {64'b0,40'b0,data_core_i[15:0],8'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else if(offset_i == 2'b10) begin
                        byte_enable_l_o = 8'b0000_1100; // 3rd and 4th byte of low word of low side byte_enable is 1
                        data_in_write_o = {64'b0,32'b0,data_core_i[15:0],16'b0}; // data is aligned to the same place as the byte_enable signals
                    end
                    else begin // Logic ERROR. Reading is made from non-Word. Algorithmic continuation can also be done here, but it is non-logical.
                        byte_enable_l_o = 8'b0000_0000;
                        data_in_write_o = {128'b0};
                    end
                end
            end
            SW: begin
                data_in_write_o = {4{data_core_i[31:0]}}; // Since LSB will be written in 32 bits, we will copy it to all bits so that there is no error.            
                if(word_i == 2'b11) begin
                    byte_enable_l_o = 8'b0000_0000; //word_i [1] == 1 so byte_enable_l_o = 0
                    byte_enable_h_o = 8'b1111_0000; // Since word_i == 2'b11, the byte enable of the high word of the high side is 1
                end
                else if(word_i == 2'b10) begin
                    byte_enable_l_o = 8'b0000_0000; //Since word_i [1] == 1, so byte_enable_l_o = 0
                    byte_enable_h_o = 8'b0000_1111; // Since word_i == 2'b10, the byte enable of the low word of the high side is 1
                end
                else if(word_i == 2'b01) begin
                    byte_enable_l_o = 8'b1111_0000; // Since word i == 2'b01, byte enable of high word of low side is 1
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 so byte_enable_h_o = 0
                end
                else begin
                    byte_enable_l_o = 8'b0000_1111; // Since word i == 2'b00, byte enable of low word of low side is 1
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 so byte_enable_h_o = 0
                end
            end
            SD: begin
                data_in_write_o = {2{data_core_i[63:0]}}; // Since LSB 64 bit is written, we will copy it to all bits so that there is no error.
                if(word_i[1] == 1'b1) begin
                    byte_enable_h_o = 8'b1111_1111; // Since the store will be made into a double word and word_i is [1] == 1, all byte_enable_h_o will be 1
                    byte_enable_l_o = 8'b0000_0000; //word_i [1] == 1 so byte_enable_l_o = 0
                end
                else begin
                    byte_enable_h_o = 8'b0000_0000; //word_i [1] == 0 so byte_enable_h_o = 0
                    byte_enable_l_o = 8'b1111_1111; // Since the store will be made into a double word and word_i is [1] == 0, all byte_enable_l_o will be 1
                end
            end
            default: begin
                byte_enable_h_o = 8'b0000_0000;
                byte_enable_l_o = 8'b0000_0000;
                data_in_write_o = 128'b0;
            end
            endcase
        end
    end
endmodule
