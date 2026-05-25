`timescale 1ns / 1ps
module cache_way_select#( // Whether set0 output or set1 output to cache output, the module that chooses accordingly
    parameter LINE_WIDTH = 128
    )
    (
    input hit,
    input cache_set_output_select,
    input [LINE_WIDTH-1:0] data_out_s2,
    input [LINE_WIDTH-1:0] data_out_s1,
    output reg [LINE_WIDTH-1:0] data_block
  );
  always @(*) begin
        data_block = {LINE_WIDTH{1'b0}};
        if(cache_set_output_select & (hit)) begin // If cache_set_output_select is 1, we will get output from set2
            data_block = data_out_s2;
        end
        else if(~cache_set_output_select & (hit)) begin // If cache_set_output_select is 0, we will get output from set1
            data_block = data_out_s1;
        end
end
endmodule
