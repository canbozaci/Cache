`timescale 1ns / 1ps
module Cache_replacement_L2#(
    parameter idx_size = 6,
    parameter block_no = 64
    )
    (
    input rst_i,
    input read_p1_i,
    input read_p2_i,
    input write_p1_i,
    input write_p2_i,
    input [idx_size -1 :0] idx_p1_i,
    input [idx_size -1 :0] idx_p2_i,
    input hit_s1_p1_i,
    input hit_s2_p1_i,
    input hit_s1_p2_i,
    input hit_s2_p2_i,
    input valid_out_s1_p1_i,
    input valid_out_s2_p1_i,
    input valid_out_s1_p2_i,
    input valid_out_s2_p2_i,
    input ram_write_start_i,
    input write_through_i,
    output reg we_s1_p1_o, // set1 write signal port 1
    output reg we_s2_p1_o, // set2 write signal port 1
    output reg we_s1_p2_o, // set1 write signal port 2
    output reg we_s2_p2_o  // set2 write signal port 2
  );

  reg [block_no-1:0] lru_holder_s2; // holding the LRU (either LRU or not) for each block on set 2
  // if lru_holder_s2 is 0 means set 1 was last read, if it is 1 means set 2 was last read
  always @ (*) begin 
    if(rst_i) begin
      lru_holder_s2[block_no-1:0] = 1'b0;
    end
    else if (~(read_p2_i & read_p1_i && (idx_p1_i == idx_p2_i))) begin // Do not update if reading from addresses with the same index
        if (hit_s1_p1_i & read_p1_i) begin // if hit port 1  set 1 and read port 1 update lru holder idx_p1 to 0 
            lru_holder_s2[idx_p1_i] = 1'b0;
        end
        else if(hit_s2_p1_i & read_p1_i) begin // if hit port 1 set 2 and read port 1 update lru holder idx_p1 to 1 
            lru_holder_s2[idx_p1_i] = 1'b1;
        end
        if (hit_s1_p2_i & read_p2_i) begin // if hit port 2 set 1 and read port 2 update lru holder idx_p2 to 0 
            lru_holder_s2[idx_p2_i] = 1'b0;
        end
        else if(hit_s2_p2_i & read_p2_i) begin // if hit port 2 set2 and read port 2 update lru holder idx_p2 to 1 
            lru_holder_s2[idx_p2_i] = 1'b1;
        end
    end
  end
  
  always@ (*) begin 
    if(rst_i) begin
      we_s2_p1_o = 0;
      we_s1_p1_o = 0;
      we_s2_p2_o = 0;
      we_s1_p2_o = 0;
    end
    else if(ram_write_start_i) begin // start only if first data is being transferred to not corrupt write enable signals 
        if ((write_p1_i & write_p2_i) && (idx_p1_i == idx_p2_i)) begin // if writing into same indexes
          if(hit_s1_p1_i & write_through_i) begin // if there is write_through look for hit in port 1 if there is a hit in set 1 then write into set1
            we_s1_p1_o = 1'b1;
            we_s2_p1_o = 1'b0;
            we_s1_p2_o = 1'b0;
            we_s2_p2_o = 1'b1;
          end
          else if(hit_s2_p1_i & write_through_i) begin // if there is write_through look for hit in port 1 if there is a hit in set 2 then write into set2
            we_s1_p1_o = 1'b0;
            we_s2_p1_o = 1'b1;
            we_s1_p2_o = 1'b1;
            we_s2_p2_o = 1'b0;
          end
          else begin // if not both than port 1 will be always written to set 1, port 2 will be written to set 2
            we_s2_p1_o = 1'b0;
            we_s1_p1_o = 1'b1;
            we_s2_p2_o = 1'b1;
            we_s1_p2_o = 1'b0;
          end
        end
        else begin
          if(write_p1_i) begin // if write port 1
              if(hit_s1_p1_i & write_through_i) begin // if there is write_through look for hit in port 1 if there is a hit in set 1 then write into set1 
                we_s1_p1_o = 1'b1;
                we_s2_p1_o = 1'b0;
              end
              else if (hit_s2_p1_i & write_through_i) begin  // if there is write_through look for hit in port 1 if there is a hit in set 2 then write into set2
                we_s2_p1_o = 1'b1;
                we_s1_p1_o = 1'b0;
              end
              else if(valid_out_s1_p1_i & valid_out_s2_p1_i) begin // if both sets are written (valid bits indicate that) 
                we_s2_p1_o = ~lru_holder_s2[idx_p1_i]; // logical not value of lru holder decide we signal (because it holds lastly used)
                we_s1_p1_o = lru_holder_s2[idx_p1_i]; // value of lru holder decide we signal (because it holds lastly used)
              end
              else if(valid_out_s1_p1_i) begin // if only set 1 is written than write into set 2
                we_s2_p1_o = 1;
                we_s1_p1_o = 0;
              end
              else begin // if written for first time always write to set 1 first
                we_s2_p1_o = 0;
                we_s1_p1_o = 1;
              end
          end
          if(write_p2_i) begin // if write port 1
            if(valid_out_s1_p2_i & valid_out_s2_p2_i) begin // if both sets are written (valid bits indicate that) 
              we_s2_p2_o = ~lru_holder_s2[idx_p2_i]; // logical not value of lru holder decide we signal (because it holds lastly used)
              we_s1_p2_o = lru_holder_s2[idx_p2_i]; // value of lru holder decide we signal (because it holds lastly used)
            end
            else if(valid_out_s1_p2_i) begin // if only set 1 is written than write into set 2
              we_s2_p2_o = 1;
              we_s1_p2_o = 0;
            end
            else begin // if written for first time always write to set 1 first
              we_s2_p2_o = 0;
              we_s1_p2_o = 1;
            end
          end
      end
    end
    end
endmodule

