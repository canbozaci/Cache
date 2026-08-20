// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps
module cache_l2_replacement#(
    parameter INDEX_WIDTH = 6,
    parameter SET_COUNT = 64
    )
    (
    input clk,
    input rst_n,
    input read_p1,
    input read_p2,
    input write_p1,
    input write_p2,
    input [INDEX_WIDTH -1 :0] idx_p1,
    input [INDEX_WIDTH -1 :0] idx_p2,
    input hit_s1_p1,
    input hit_s2_p1,
    input hit_s1_p2,
    input hit_s2_p2,
    input valid_out_s1_p1,
    input valid_out_s2_p1,
    input valid_out_s1_p2,
    input valid_out_s2_p2,
    input ram_write_start,
    input write_through,
    output reg we_s1_p1, // set1 write signal port 1
    output reg we_s2_p1, // set2 write signal port 1
    output reg we_s1_p2, // set1 write signal port 2
    output reg we_s2_p2  // set2 write signal port 2
  );

  reg [SET_COUNT-1:0] lru_holder_s2; // holding the LRU (either LRU or not) for each block on set 2
  reg fill_active_p1;
  reg fill_active_p2;
  reg fill_way_s2_p1;
  reg fill_way_s2_p2;
  reg start_write_p1;
  reg start_write_p2;
  reg start_way_s2_p1;
  reg start_way_s2_p2;
  // if lru_holder_s2 is 0 means set 1 was last read, if it is 1 means set 2 was last read
  always @(*) begin
    start_write_p1 = 1'b0;
    start_write_p2 = 1'b0;
    start_way_s2_p1 = 1'b0;
    start_way_s2_p2 = 1'b0;

    if ((write_p1 & write_p2) && (idx_p1 == idx_p2)) begin
      start_write_p1 = 1'b1;
      start_write_p2 = 1'b1;
      if(hit_s1_p1 & write_through) begin
        start_way_s2_p1 = 1'b0;
        start_way_s2_p2 = 1'b1;
      end
      else if(hit_s2_p1 & write_through) begin
        start_way_s2_p1 = 1'b1;
        start_way_s2_p2 = 1'b0;
      end
      else begin
        start_way_s2_p1 = 1'b0;
        start_way_s2_p2 = 1'b1;
      end
    end else begin
      if(write_p1) begin
        start_write_p1 = 1'b1;
        // Residency wins over the replacement policy. Qualifying these two
        // checks with write_through, as they used to be, skipped them on a
        // fill: refilling a line the set already held picked an LRU victim and
        // left the same tag valid in both ways. Way 0 answers a two-way hit, so
        // the way-1 copy went unreachable and every later store into it was
        // lost. Same defect as in cache_l1_replacement.sv.
        if(hit_s1_p1) begin
          start_way_s2_p1 = 1'b0;
        end
        else if (hit_s2_p1) begin
          start_way_s2_p1 = 1'b1;
        end
        else if(valid_out_s1_p1 & valid_out_s2_p1) begin
          start_way_s2_p1 = ~lru_holder_s2[idx_p1];
        end
        else if(valid_out_s1_p1) begin
          start_way_s2_p1 = 1'b1;
        end
        else begin
          start_way_s2_p1 = 1'b0;
        end
      end

      if(write_p2) begin
        start_write_p2 = 1'b1;
        // The instruction port had no residency check at all, so an instruction
        // refill of an already-resident line duplicated it unconditionally.
        if(hit_s1_p2) begin
          start_way_s2_p2 = 1'b0;
        end
        else if (hit_s2_p2) begin
          start_way_s2_p2 = 1'b1;
        end
        else if(valid_out_s1_p2 & valid_out_s2_p2) begin
          start_way_s2_p2 = ~lru_holder_s2[idx_p2];
        end
        else if(valid_out_s1_p2) begin
          start_way_s2_p2 = 1'b1;
        end
        else begin
          start_way_s2_p2 = 1'b0;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      lru_holder_s2 <= {SET_COUNT{1'b0}};
      fill_active_p1 <= 1'b0;
      fill_active_p2 <= 1'b0;
      fill_way_s2_p1 <= 1'b0;
      fill_way_s2_p2 <= 1'b0;
    end
    else begin
      if (ram_write_start) begin
        if (start_write_p1) begin
          fill_active_p1 <= 1'b1;
          fill_way_s2_p1 <= start_way_s2_p1;
        end
        if (start_write_p2) begin
          fill_active_p2 <= 1'b1;
          fill_way_s2_p2 <= start_way_s2_p2;
        end
      end else begin
        if (!write_p1) begin
          fill_active_p1 <= 1'b0;
        end
        if (!write_p2) begin
          fill_active_p2 <= 1'b0;
        end
      end

      if (~(read_p2 & read_p1 && (idx_p1 == idx_p2))) begin // Do not update if reading from addresses with the same index
        if (hit_s1_p1 & read_p1) begin // if hit port 1  set 1 and read port 1 update lru holder idx_p1 to 0
            lru_holder_s2[idx_p1] <= 1'b0;
        end
        else if(hit_s2_p1 & read_p1) begin // if hit port 1 set 2 and read port 1 update lru holder idx_p1 to 1
            lru_holder_s2[idx_p1] <= 1'b1;
        end
        if (hit_s1_p2 & read_p2) begin // if hit port 2 set 1 and read port 2 update lru holder idx_p2 to 0
            lru_holder_s2[idx_p2] <= 1'b0;
        end
        else if(hit_s2_p2 & read_p2) begin // if hit port 2 set2 and read port 2 update lru holder idx_p2 to 1
            lru_holder_s2[idx_p2] <= 1'b1;
        end
      end
    end
  end

  always@ (*) begin
    we_s2_p1 = 1'b0;
    we_s1_p1 = 1'b0;
    we_s2_p2 = 1'b0;
    we_s1_p2 = 1'b0;
    if (!rst_n) begin
      we_s2_p1 = 1'b0;
      we_s1_p1 = 1'b0;
      we_s2_p2 = 1'b0;
      we_s1_p2 = 1'b0;
    end
    else begin
      if (write_p1 & (fill_active_p1 | (ram_write_start & start_write_p1))) begin
        we_s2_p1 = fill_active_p1 ? fill_way_s2_p1 : start_way_s2_p1;
        we_s1_p1 = ~(fill_active_p1 ? fill_way_s2_p1 : start_way_s2_p1);
      end
      if (write_p2 & (fill_active_p2 | (ram_write_start & start_write_p2))) begin
        we_s2_p2 = fill_active_p2 ? fill_way_s2_p2 : start_way_s2_p2;
        we_s1_p2 = ~(fill_active_p2 ? fill_way_s2_p2 : start_way_s2_p2);
      end
    end
  end
  endmodule
