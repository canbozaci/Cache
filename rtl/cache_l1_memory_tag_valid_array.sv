// Synthesizable single-port L1 cache tag/valid memory array model.
// Words: 64
// Word size: 128

module cache_l1_memory_tag_valid_array#(
  parameter DATA_WIDTH = 10, // tag size (9 bits) + valid bit (1 bit)
  parameter ADDR_WIDTH = 6, // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter RAM_DEPTH = 1 << ADDR_WIDTH // 2^6 = 64 (depth)
  )
  (
  input  clk, // clock input
  input  rst,
  input  we, // write enable input
  input  invalidate,
  input  [ADDR_WIDTH-1:0] addr, // address input
  input  [ADDR_WIDTH-1:0] invalidate_addr,
  input  [DATA_WIDTH-2:0] invalidate_tag,
  input  [DATA_WIDTH-1:0] write_data, // data input
  output reg [DATA_WIDTH-1:0] read_data // data output
  );

`ifdef SRAM_MACRO_ENABLE
`ifndef CACHE_L1_TAG_VALID_ARRAY_MACRO
  `error "SRAM_MACRO_ENABLE requires CACHE_L1_TAG_VALID_ARRAY_MACRO"
`endif

  `CACHE_L1_TAG_VALID_ARRAY_MACRO #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .RAM_DEPTH(RAM_DEPTH)
  ) cache_l1_tag_valid_array_macro_inst (
    .clk(clk),
    .rst(rst),
    .we(we),
    .invalidate(invalidate),
    .addr(addr),
    .invalidate_addr(invalidate_addr),
    .invalidate_tag(invalidate_tag),
    .write_data(write_data),
    .read_data(read_data)
  );
`else
  // Core Memory
  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  integer mem_index;
  // Port-1 Operation Read First
  always @ (posedge clk) begin : MEM_WRITE
    if (rst) begin
      for (mem_index = 0; mem_index < RAM_DEPTH; mem_index = mem_index + 1) begin
        /* verilator lint_off BLKSEQ */
        mem[mem_index] = {DATA_WIDTH{1'b0}};
        /* verilator lint_on BLKSEQ */
      end
      read_data <= {DATA_WIDTH{1'b0}};
    end else begin
      if (invalidate && mem[invalidate_addr][DATA_WIDTH-1] &&
          (mem[invalidate_addr][DATA_WIDTH-2:0] == invalidate_tag)) begin
        mem[invalidate_addr][DATA_WIDTH-1] <= 1'b0;
      end
      if (we) begin
        mem[addr][DATA_WIDTH-1:0] <= write_data[DATA_WIDTH-1:0];
      end
      read_data <= mem[addr];
    end
  end
`endif

  endmodule
