// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Synthesizable dual-port L2 cache tag/valid memory array model.
module cache_l2_memory_tag_valid_array#(
  parameter   NUM_COL             =   1, // no byte enables
  parameter   COL_WIDTH           =   8, // tag size (7 bits) + valid bit (1 bit)
  parameter   ADDR_WIDTH          =   8, // idx size = 8, log2(256) = 8 (256 = block no)
  // Addr  Width in bits : 2 *ADDR_WIDTH = RAM Depth
  parameter   DATA_WIDTH      =  NUM_COL*COL_WIDTH  // Data  Width in bits
  )
  (
  input clk,   // clock input
  input rst,
  input we_p1, // port 1 write enable signal (data cache)
  input we_p2, // port 2 write enable signal (instruction cache)
  input invalidate,
  input [ADDR_WIDTH-1:0] addr_p1, // port 1 address
  input [ADDR_WIDTH-1:0] addr_p2, // port 2 address
  input [ADDR_WIDTH-1:0] invalidate_addr,
  input [DATA_WIDTH-2:0] invalidate_tag,
  input [DATA_WIDTH-1:0] write_data_p1, // port 1 data in
  input [DATA_WIDTH-1:0] write_data_p2, // port 2 data in
  output reg [DATA_WIDTH-1:0] read_data_p1, // data out port 1
  output reg [DATA_WIDTH-1:0] read_data_p2  // data out port 2
  );

`ifdef SRAM_MACRO_ENABLE
`ifndef CACHE_L2_TAG_VALID_ARRAY_MACRO
  `error "SRAM_MACRO_ENABLE requires CACHE_L2_TAG_VALID_ARRAY_MACRO"
`endif

  `CACHE_L2_TAG_VALID_ARRAY_MACRO #(
    .NUM_COL(NUM_COL),
    .COL_WIDTH(COL_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) cache_l2_tag_valid_array_macro_inst (
    .clk(clk),
    .rst(rst),
    .we_p1(we_p1),
    .we_p2(we_p2),
    .invalidate(invalidate),
    .addr_p1(addr_p1),
    .addr_p2(addr_p2),
    .invalidate_addr(invalidate_addr),
    .invalidate_tag(invalidate_tag),
    .write_data_p1(write_data_p1),
    .write_data_p2(write_data_p2),
    .read_data_p1(read_data_p1),
    .read_data_p2(read_data_p2)
  );
`else
  // Core Memory
  reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
  integer mem_index;
  always @ (posedge clk) begin
    if (rst) begin
      for (mem_index = 0; mem_index < (2**ADDR_WIDTH); mem_index = mem_index + 1) begin
        /* verilator lint_off BLKSEQ */
        ram_block[mem_index] = {DATA_WIDTH{1'b0}};
        /* verilator lint_on BLKSEQ */
      end
      read_data_p1 <= {DATA_WIDTH{1'b0}};
      read_data_p2 <= {DATA_WIDTH{1'b0}};
    end else begin
      if (invalidate && ram_block[invalidate_addr][DATA_WIDTH-1] &&
          (ram_block[invalidate_addr][DATA_WIDTH-2:0] == invalidate_tag)) begin
        ram_block[invalidate_addr][DATA_WIDTH-1] <= 1'b0;
      end
      if(we_p1) begin
        ram_block[addr_p1][DATA_WIDTH-1:0] <= write_data_p1[DATA_WIDTH-1:0];
      end
      if(we_p2) begin
        ram_block[addr_p2][DATA_WIDTH-1:0] <= write_data_p2[DATA_WIDTH-1:0];
      end
      read_data_p1 <= ram_block[addr_p1];
      read_data_p2 <= ram_block[addr_p2];
    end
  end
`endif

endmodule
