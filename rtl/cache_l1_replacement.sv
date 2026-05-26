// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps
module cache_l1_replacement#(
      parameter INDEX_WIDTH = 6,
      parameter SET_COUNT = 64
      )
      (
      input clk,
      input rst,
      input read,
      input write,
      input [INDEX_WIDTH -1 :0] idx,
      input hit_s1, // set 1 hit input
      input hit_s2, // set 2 hit input
      input write_L2, // L2 write signal
      input write_through, // write will be done as write throug
      input valid_out_s1,
      input valid_out_s2,
      output reg we_s1, // set1 write signal
      output reg we_s2  // set2 write signal
      );

      reg [SET_COUNT-1:0] lru_holder_s2; // holding the LRU (either LRU or not) for each block on set2
  // if lru_holder_s2 is 0 means set 1 was last read, if it is 1 means set 2 was last read
      always @(posedge clk) begin
        if(rst) begin
          lru_holder_s2 <= {SET_COUNT{1'b0}};
        end
        else if (hit_s1 & (read | write)) begin
            // If set 1 has hits and can be read or written then lru_holder_s2 should be 0
            lru_holder_s2[idx] <= 1'b0;
        end
        else if(hit_s2 & (read | write)) begin
            // If set 2 has hits and can be read or written then lru_holder_s2 should be 1
            lru_holder_s2[idx] <= 1'b1;
        end
        end

      always@ (*) begin
        we_s2 = 1'b0;
        we_s1 = 1'b0;
        if(rst) begin
          we_s2 = 1'b0;
          we_s1 = 1'b0;
        end
        else if (write) begin
          if(hit_s1 & (~write_L2 | write_through)) begin
            // if there is write_through look for hit  if there is a hit in set 1 then write into set1
            we_s1 = 1'b1;
            we_s2 = 1'b0;
          end
          else if(hit_s2 & (~write_L2 | write_through)) begin
            // if there is write_through look for hit if there is a hit in set 2 then write into set2
            we_s2 = 1'b1;
            we_s1 = 1'b0;
          end
          else if(valid_out_s1 & valid_out_s2) begin // if both sets are written (valid bits indicate that)
            // logical not value of lru holder decide we signal (because it holds lastly used)
            we_s2 = ~lru_holder_s2[idx];
            we_s1 = lru_holder_s2[idx];// value of lru holder decide we signal (because it holds lastly used)
          end
          else if(valid_out_s1) begin  // if only set 1 is written than write into set 2
            we_s2 = 1'b1;
            we_s1 = 1'b0;
          end
          else begin  // if written for first time always write to set 1 first
            we_s2 = 1'b0;
            we_s1 = 1'b1;
          end
        end
      end
endmodule
