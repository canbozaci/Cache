`timescale 1ns / 1ps
module Cache_output_set_select#( // Whether set0 output or set1 output to cache output, the module that chooses accordingly
    parameter block_size = 128
    )
    (
    input hit_i,
    input cache_set_output_select_i,
    input [block_size-1:0] data_out_s2_i,
    input [block_size-1:0] data_out_s1_i,
    output reg [block_size-1:0] data_block_o
  );
  always @(*) begin
        if(cache_set_output_select_i & (hit_i)) begin // If cache_set_output_select is 1, we will get output from set2
            data_block_o = data_out_s2_i;
        end
        else if(~cache_set_output_select_i & (hit_i)) begin // If cache_set_output_select is 0, we will get output from set1
            data_block_o = data_out_s1_i;
        end
end
endmodule
