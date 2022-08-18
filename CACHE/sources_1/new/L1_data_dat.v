// OpenRAM SRAM model
// Words: 64
// Word size: 128

module L1_data_dat#(
  parameter DATA_WIDTH = 128,// data size 128 bit = LINE SIZE
  parameter ADDR_WIDTH = 6,  // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter RAM_DEPTH = 1 << ADDR_WIDTH // 2^6 = 64 (depth)
  )
  (
  input  clk_i, // clock input
  input  we_i, // write enable
  input  [15:0] byte_enable_i, // byte enable input
  input  [ADDR_WIDTH-1:0] addr_i, // address input
  input  [DATA_WIDTH-1:0] data_i, // data input
  output reg [DATA_WIDTH-1:0] data_o // data output
  );
  // Core Memory
  (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1]; // memory delete attribute for ASIC design
  // Port-1 Operation Read First
  always @ (posedge clk_i) begin : MEM_WRITE
    if (we_i) begin // write enable 
      if(byte_enable_i[0]) begin 
        mem[addr_i][7:0] <= data_i[7:0];
      end
      if(byte_enable_i[1]) begin
        mem[addr_i][15:8] <= data_i[15:8];
      end
      if(byte_enable_i[2]) begin
        mem[addr_i][23:16] <= data_i[23:16];
      end
      if(byte_enable_i[3]) begin
        mem[addr_i][31:24] <= data_i[31:24];
      end
      if(byte_enable_i[4]) begin
        mem[addr_i][39:32] <= data_i[39:32];
      end
      if(byte_enable_i[5]) begin
        mem[addr_i][47:40] <= data_i[47:40];
      end
      if(byte_enable_i[6]) begin
        mem[addr_i][55:48] <= data_i[55:48];
      end
      if(byte_enable_i[7]) begin
        mem[addr_i][63:56] <= data_i[63:56];
      end
      if(byte_enable_i[8]) begin
        mem[addr_i][71:64] <= data_i[71:64];
      end
      if(byte_enable_i[9]) begin
        mem[addr_i][79:72] <= data_i[79:72];
      end
      if(byte_enable_i[10]) begin
        mem[addr_i][87:80] <= data_i[87:80];
      end
      if(byte_enable_i[11]) begin
        mem[addr_i][95:88] <= data_i[95:88];
      end
      if(byte_enable_i[12]) begin
        mem[addr_i][103:96] <= data_i[103:96];
      end
      if(byte_enable_i[13]) begin
        mem[addr_i][111:104] <= data_i[111:104];
      end
      if(byte_enable_i[14]) begin
        mem[addr_i][119:112] <= data_i[119:112];
      end
      if(byte_enable_i[15]) begin
        mem[addr_i][127:120] <= data_i[127:120];
      end
    end
    data_o <= mem[addr_i];
  end

  endmodule
  