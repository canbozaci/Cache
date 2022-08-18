`timescale 1ns / 1ps
module Cache_identification#(parameter tag_size = 9)(
    input [tag_size-1:0] tag_i, 
    input valid_mem,
    input [tag_size-1:0] tag_mem, 
    output reg hit_o 
  );
  always @* begin
    if(valid_mem == 1'b1) begin // if valid_mem is 1
        if(tag_mem == tag_i) begin // if tag mem & tag input is equal it is hit
          hit_o = 1'b1;  
        end
        else begin // if not it is not hit
          hit_o = 1'b0;
        end
    end
    else begin // if mem is not valid then it is not hit
      hit_o = 1'b0;
    end
  end
endmodule
