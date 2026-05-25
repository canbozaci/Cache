`timescale 1ns / 1ps
module cache_tag_match#(parameter TAG_WIDTH = 9)(
    input [TAG_WIDTH-1:0] tag,
    input valid_mem,
    input [TAG_WIDTH-1:0] tag_mem,
    output reg hit
  );
  always @* begin
    if(valid_mem == 1'b1) begin // if valid_mem is 1
        if(tag_mem == tag) begin // if tag mem & tag input is equal it is hit
          hit = 1'b1;
        end
        else begin // if not it is not hit
          hit = 1'b0;
        end
    end
    else begin // if mem is not valid then it is not hit
      hit = 1'b0;
    end
  end
endmodule
