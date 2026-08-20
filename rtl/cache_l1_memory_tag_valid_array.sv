// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Synthesizable single-port L1 cache tag/valid memory array model.
// Words: 64
// Word size: 128

module cache_l1_memory_tag_valid_array#(
  parameter DATA_WIDTH = 10, // tag size (9 bits) + valid bit (1 bit)
  parameter ADDR_WIDTH = 6, // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter RAM_DEPTH = 1 << ADDR_WIDTH, // 2^6 = 64 (depth)
  /* verilator lint_off UNUSEDPARAM */
  parameter INSTR_MEMORY = 0
  /* verilator lint_on UNUSEDPARAM */
  )
  (
  input  clk, // clock input
  input  rst_n,
  input  we, // write enable input
  input  invalidate,
  input  [ADDR_WIDTH-1:0] addr, // address input
  input  [ADDR_WIDTH-1:0] invalidate_addr,
  input  [DATA_WIDTH-2:0] invalidate_tag,
  input  [DATA_WIDTH-1:0] write_data, // data input
  output reg [DATA_WIDTH-1:0] read_data // data output
  );

`ifdef SRAM_MACRO_ENABLE
  generate
    if (INSTR_MEMORY == 0) begin : gen_data_tag_valid_macro
`ifndef CACHE_L1_DATA_TAG_VALID_ARRAY_MACRO
      `error "SRAM_MACRO_ENABLE requires CACHE_L1_DATA_TAG_VALID_ARRAY_MACRO"
`endif
      `CACHE_L1_DATA_TAG_VALID_ARRAY_MACRO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .RAM_DEPTH(RAM_DEPTH)
      ) cache_l1_data_tag_valid_array_macro_inst (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .invalidate(invalidate),
        .addr(addr),
        .invalidate_addr(invalidate_addr),
        .invalidate_tag(invalidate_tag),
        .write_data(write_data),
        .read_data(read_data)
      );
    end else begin : gen_instr_tag_valid_macro
`ifndef CACHE_L1_INSTR_TAG_VALID_ARRAY_MACRO
      `error "SRAM_MACRO_ENABLE requires CACHE_L1_INSTR_TAG_VALID_ARRAY_MACRO"
`endif
      `CACHE_L1_INSTR_TAG_VALID_ARRAY_MACRO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .RAM_DEPTH(RAM_DEPTH)
      ) cache_l1_instr_tag_valid_array_macro_inst (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .invalidate(invalidate),
        .addr(addr),
        .invalidate_addr(invalidate_addr),
        .invalidate_tag(invalidate_tag),
        .write_data(write_data),
        .read_data(read_data)
      );
    end
  endgenerate
`else
  // Core Memory
  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  reg [DATA_WIDTH-1:0] inv_word;
  integer mem_index;
  // Port-1 Operation Read First
  always @ (posedge clk) begin : MEM_WRITE
    if (!rst_n) begin
      for (mem_index = 0; mem_index < RAM_DEPTH; mem_index = mem_index + 1) begin
        /* verilator lint_off BLKSEQ */
        mem[mem_index] = {DATA_WIDTH{1'b0}};
        /* verilator lint_on BLKSEQ */
      end
      read_data <= {DATA_WIDTH{1'b0}};
    end else begin
      // The stored word is read into a whole-word temporary before its valid
      // bit and tag are examined. Selecting them straight out of the array --
      // mem[invalidate_addr][DATA_WIDTH-1] and mem[invalidate_addr][DATA_WIDTH-2:0]
      // -- chains a variable array index with a parameter-width part select,
      // which was evaluated against the module's *default* DATA_WIDTH rather
      // than the overridden one. At the default geometry the two happen to be
      // equal (tag 9 + valid = 10) and the invalidate worked; at any geometry
      // that changes the tag width they diverge, the valid bit is read from the
      // wrong position and the tag compare comes out false, so a line invalidate
      // silently did nothing and the line kept answering hits.
      //
      // Reading the word first removes the chained select entirely, so the
      // widths come from the declaration in every case.
      // Blocking on purpose: a local temporary read and used within this
      // same evaluation, not state. Same idiom as the reset loop above.
      /* verilator lint_off BLKSEQ */
      inv_word = mem[invalidate_addr];
      /* verilator lint_on BLKSEQ */
      if (invalidate && inv_word[DATA_WIDTH-1] &&
          (inv_word[DATA_WIDTH-2:0] == invalidate_tag)) begin
        // Whole-word write rather than a bit select on the array element, for
        // the same reason the read above goes through inv_word: the chained
        // select cleared the bit at the *default* DATA_WIDTH position, so on
        // any geometry with a different tag width it cleared a tag bit and left
        // the valid bit standing.
        mem[invalidate_addr] <= {1'b0, inv_word[DATA_WIDTH-2:0]};
      end
      if (we) begin
        mem[addr][DATA_WIDTH-1:0] <= write_data[DATA_WIDTH-1:0];
      end
      read_data <= mem[addr];
    end
  end
`endif

  endmodule
