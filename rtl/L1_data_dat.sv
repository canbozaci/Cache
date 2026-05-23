// Synthesizable single-port cache data array model.
// Words: 64
// Word size: 128

module L1_data_dat#(
  parameter DATA_WIDTH = 128,// data size 128 bit = LINE SIZE
  parameter ADDR_WIDTH = 6,  // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter BYTE_COUNT = DATA_WIDTH / 8,
  parameter RAM_DEPTH = 1 << ADDR_WIDTH // 2^6 = 64 (depth)
  )
  (
  input  clk, // clock input
  input  we, // write enable
  input  [BYTE_COUNT-1:0] byte_enable, // byte enable input
  input  [ADDR_WIDTH-1:0] addr, // address input
  input  [DATA_WIDTH-1:0] write_data, // data input
  output reg [DATA_WIDTH-1:0] read_data // data output
  );
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

  endmodule
  
