`timescale 1ns / 1ps
module Cache_replacement_data#(
      parameter idx_size = 6,
      parameter block_no = 64
      )
      (
      input rst_i,
      input read_i,
      input write_i,
      input [idx_size -1 :0] idx_i,
      input hit_s1_i, // set 1 hit input
      input hit_s2_i, // set 2 hit input
      input write_L2_i, // L2 write signal
      input write_through_i, // write will be done as write throug
      input valid_out_s1_i,
      input valid_out_s2_i,
      output reg we_s1_o, // set1 write signal
      output reg we_s2_o  // set2 write signal
      );

      reg [block_no-1:0] lru_holder_s2; // holding the LRU (either LRU or not) for each block on set2
  // if lru_holder_s2 is 0 means set 1 was last read, if it is 1 means set 2 was last read
      always @ (*) begin 
        if(rst_i) begin
          lru_holder_s2[block_no-1:0] = 64'b0;
        end
        else if (hit_s1_i & (read_i | write_i)) begin // If set 1 has hits and can be read or written then lru_holder_s2 should be 0
            lru_holder_s2[idx_i] = 1'b0; 
        end
        else if(hit_s2_i & (read_i | write_i)) begin // If set 2 has hits and can be read or written then lru_holder_s2 should be 1
            lru_holder_s2[idx_i] = 1'b1;
        end
        end
      
      always@ (*) begin 
        if(rst_i) begin
          we_s2_o = 1'b0;
          we_s1_o = 1'b0;
        end
        else if (write_i) begin 
          if(hit_s1_i & (~write_L2_i | write_through_i)) begin  // if there is write_through look for hit  if there is a hit in set 1 then write into set1
            we_s1_o = 1'b1; 
            we_s2_o = 1'b0; 
          end
          else if(hit_s2_i & (~write_L2_i | write_through_i)) begin // if there is write_through look for hit if there is a hit in set 2 then write into set2
            we_s2_o = 1'b1;
            we_s1_o = 1'b0;
          end
          else if(valid_out_s1_i & valid_out_s2_i) begin // if both sets are written (valid bits indicate that) 
            we_s2_o = ~lru_holder_s2[idx_i];  // logical not value of lru holder decide we signal (because it holds lastly used)
            we_s1_o = lru_holder_s2[idx_i];// value of lru holder decide we signal (because it holds lastly used)
          end
          else if(valid_out_s1_i) begin  // if only set 1 is written than write into set 2
            we_s2_o = 1'b1;
            we_s1_o = 1'b0;
          end
          else begin  // if written for first time always write to set 1 first
            we_s2_o = 1'b0;
            we_s1_o = 1'b1;
          end
        end
      end
endmodule

