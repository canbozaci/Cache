// Synthesizable single-port L1 cache line memory array model.
// Words: 64
// Word size: 128

module cache_l1_memory_array#(
  parameter DATA_WIDTH = 128,// line size in bits
  parameter ADDR_WIDTH = 6,  // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter BYTE_COUNT = DATA_WIDTH / 8,
  parameter RAM_DEPTH = 1 << ADDR_WIDTH, // 2^6 = 64 (depth)
  /* verilator lint_off UNUSEDPARAM */
  parameter INSTR_MEMORY = 0
  /* verilator lint_on UNUSEDPARAM */
  )
  (
  input  clk, // clock input
  input  we, // write enable
  input  [BYTE_COUNT-1:0] byte_enable, // byte enable input
  input  [ADDR_WIDTH-1:0] addr, // address input
  input  [DATA_WIDTH-1:0] write_data, // data input
  output reg [DATA_WIDTH-1:0] read_data // data output
  );

`ifdef SRAM_MACRO_ENABLE
  generate
    if (INSTR_MEMORY == 0) begin : gen_data_memory_macro
`ifndef CACHE_L1_DATA_MEMORY_ARRAY_MACRO
      `error "SRAM_MACRO_ENABLE requires CACHE_L1_DATA_MEMORY_ARRAY_MACRO"
`endif
      `CACHE_L1_DATA_MEMORY_ARRAY_MACRO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BYTE_COUNT(BYTE_COUNT),
        .RAM_DEPTH(RAM_DEPTH)
      ) cache_l1_data_memory_array_macro_inst (
        .clk(clk),
        .we(we),
        .byte_enable(byte_enable),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
      );
    end else begin : gen_instr_memory_macro
`ifndef CACHE_L1_INSTR_MEMORY_ARRAY_MACRO
      `error "SRAM_MACRO_ENABLE requires CACHE_L1_INSTR_MEMORY_ARRAY_MACRO"
`endif
      `CACHE_L1_INSTR_MEMORY_ARRAY_MACRO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BYTE_COUNT(BYTE_COUNT),
        .RAM_DEPTH(RAM_DEPTH)
      ) cache_l1_instr_memory_array_macro_inst (
        .clk(clk),
        .we(we),
        .byte_enable(byte_enable),
        .addr(addr),
        .write_data(write_data),
        .read_data(read_data)
      );
    end
  endgenerate
`else
  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  integer byte_index;
  // Port-1 Operation Read First
  always @ (posedge clk) begin : MEM_WRITE
    if (we) begin // write enable
      for (byte_index = 0; byte_index < BYTE_COUNT; byte_index = byte_index + 1) begin
        if (byte_enable[byte_index]) begin
          mem[addr][byte_index*8 +: 8] <= write_data[byte_index*8 +: 8];
        end
      end
    end
    read_data <= mem[addr];
  end
`endif

  endmodule
