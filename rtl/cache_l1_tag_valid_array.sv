// Synthesizable single-port tag/valid array model.
// Words: 64
// Word size: 128

module cache_l1_tag_valid_array#(
  parameter DATA_WIDTH = 10, // tag size (9 bits) + valid bit (1 bit)
  parameter ADDR_WIDTH = 6, // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter RAM_DEPTH = 1 << ADDR_WIDTH // 2^6 = 64 (depth)
  )
  (
  input  clk, // clock input
  input  rst,
  input  we, // write enable input
  input  [ADDR_WIDTH-1:0] addr, // address input
  input  [DATA_WIDTH-1:0] write_data, // data input
  output reg [DATA_WIDTH-1:0] read_data // data output
  );
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
      if (we) begin
        mem[addr][DATA_WIDTH-1:0] <= write_data[DATA_WIDTH-1:0];
      end
      read_data <= mem[addr];
    end
  end

  endmodule

