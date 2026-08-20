// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps
module cache_l1_replacement#(
      parameter INDEX_WIDTH = 6,
      parameter SET_COUNT = 64
      )
      (
      input clk,
      input rst_n,
      input read,
      input write,
      input [INDEX_WIDTH -1 :0] idx,
      input hit_s1, // set 1 hit input
      input hit_s2, // set 2 hit input
      // Both of these became unused when the residency check below stopped
      // being conditional. They are kept on the port list because they are
      // real signals of cache_l1_data's interface, and removing them here
      // would push the same removal up through cache_l1_data into cache.sv
      // for no gain. Retained so the two levels keep matching port lists.
      /* verilator lint_off UNUSEDSIGNAL */
      input write_L2, // L2 write signal
      input write_through, // write will be done as write through
      /* verilator lint_on UNUSEDSIGNAL */
      input valid_out_s1,
      input valid_out_s2,
      output reg we_s1, // set1 write signal
      output reg we_s2  // set2 write signal
      );

      reg [SET_COUNT-1:0] lru_holder_s2; // holding the LRU (either LRU or not) for each block on set2
  // if lru_holder_s2 is 0 means set 1 was last read, if it is 1 means set 2 was last read
      always @(posedge clk) begin
        if (!rst_n) begin
          lru_holder_s2 <= {SET_COUNT{1'b0}};
        end
        else if (hit_s1 & (read | write)) begin // If set 1 has hits and can be read or written then lru_holder_s2 should be 0
            lru_holder_s2[idx] <= 1'b0;
        end
        else if(hit_s2 & (read | write)) begin // If set 2 has hits and can be read or written then lru_holder_s2 should be 1
            lru_holder_s2[idx] <= 1'b1;
        end
        end

      always@ (*) begin
        we_s2 = 1'b0;
        we_s1 = 1'b0;
        if (!rst_n) begin
          we_s2 = 1'b0;
          we_s1 = 1'b0;
        end
        else if (write) begin
          // A line already resident in a way must be rewritten in that way,
          // whatever kind of write this is. The hit checks used to be qualified
          // by (~write_L2 | write_through), which excluded exactly the fill
          // case: a fill of a line the set already held fell through to the LRU
          // victim below and installed a second copy in the other way. Both
          // copies then read as valid with the same tag, and since a two-way
          // hit resolves to way 0 (cache_set_output_select is asserted only for
          // hit_s2 & ~hit_s1), the way-1 copy became unreachable. Stores that
          // landed in it were lost silently until the set was evicted.
          if(hit_s1) begin  // line already lives in set 1, so rewrite it there
            we_s1 = 1'b1;
            we_s2 = 1'b0;
          end
          else if(hit_s2) begin // line already lives in set 2, so rewrite it there
            we_s2 = 1'b1;
            we_s1 = 1'b0;
          end
          else if(valid_out_s1 & valid_out_s2) begin // if both sets are written (valid bits indicate that)
            we_s2 = ~lru_holder_s2[idx];  // logical not value of lru holder decide we signal (because it holds lastly used)
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
