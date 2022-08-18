`timescale 1ns / 1ps
module Cache_replacement_instr#(
    parameter idx_size = 6,
    parameter block_no = 64
    )
    (
    input rst_i,
    input read_i,
    input instr_write_start_i,
    input write_i,
    input [idx_size -1 :0] idx_i,
    input hit_s1_i,      // set 1 hit input 
    input hit_s2_i,      // set 2 hit input 
    input hit_s1_next_i, // set 1 hit input next
    input hit_s2_next_i, // set 2 hit input next
    input valid_out_s1_i, // set 1 valid input
    input valid_out_s2_i, // set 2 valid input
    output reg we_s1_o,// set1 write signal
    output reg we_s2_o // set2 write signal
  );
  reg [block_no-1:0] lru_holder_s2; // holding the LRU (either LRU or not) for each block on set1
  // if lru_holder_s2 is 0 means set 1 was last read, if it is 1 means set 2 was last read
  always @ (*) begin 
    if(rst_i) begin
      lru_holder_s2[block_no-1:0] = 1'b0;
    end
    else begin
      if (hit_s1_i & read_i) begin
          lru_holder_s2[idx_i] = 1'b0;
        end
      else if(hit_s2_i & read_i ) begin
          lru_holder_s2[idx_i] = 1'b1;
        end
      if (hit_s1_next_i & read_i) begin // update lru holder for next_idx
          lru_holder_s2[idx_i + 1] = 1'b0;
        end
      else if(hit_s2_next_i & read_i) begin // update lru holder for next_idxes
          lru_holder_s2[idx_i + 1] = 1'b1;
        end
    end
  end
  
  always@ (*) begin 
    if(rst_i) begin
      we_s2_o = 0;
      we_s1_o = 0;
    end
    else if (instr_write_start_i) begin // start only if first data is being transferred to not corrupt write enable signals 
      if (write_i) begin
        if(valid_out_s1_i & valid_out_s2_i) begin // if both sets are written (valid bits indicate that) 
          we_s2_o = ~lru_holder_s2[idx_i]; // logical not value of lru holder decide we signal (because it holds lastly used)
          we_s1_o = lru_holder_s2[idx_i]; //  value of lru holder decide we signal (because it holds lastly used)
        end
        else if(valid_out_s1_i) begin // if only set 1 is written than write into set 2
          we_s2_o = 1;
          we_s1_o = 0;
        end
        else begin // if written for first time always write to set 1 first
          we_s2_o = 0;
          we_s1_o = 1;
        end
      end
    end
  end
endmodule

