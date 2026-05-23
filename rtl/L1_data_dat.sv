// Synthesizable single-port cache data array model.
// Words: 64
// Word size: 128

module L1_data_dat#(
  parameter DATA_WIDTH = 128,// data size 128 bit = LINE SIZE
  parameter ADDR_WIDTH = 6,  // idx size (6 bits), log2(64) = 6 (64 = block no)
  parameter RAM_DEPTH = 1 << ADDR_WIDTH // 2^6 = 64 (depth)
  )
  (
  input  clk, // clock input
  input  we, // write enable
  input  [15:0] byte_enable, // byte enable input
  input  [ADDR_WIDTH-1:0] addr, // address input
  input  [DATA_WIDTH-1:0] write_data, // data input
  output reg [DATA_WIDTH-1:0] read_data // data output
  );
  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  // Port-1 Operation Read First
  always @ (posedge clk) begin : MEM_WRITE
    if (we) begin // write enable 
      if(byte_enable[0]) begin 
        mem[addr][7:0] <= write_data[7:0];
      end
      if(byte_enable[1]) begin
        mem[addr][15:8] <= write_data[15:8];
      end
      if(byte_enable[2]) begin
        mem[addr][23:16] <= write_data[23:16];
      end
      if(byte_enable[3]) begin
        mem[addr][31:24] <= write_data[31:24];
      end
      if(byte_enable[4]) begin
        mem[addr][39:32] <= write_data[39:32];
      end
      if(byte_enable[5]) begin
        mem[addr][47:40] <= write_data[47:40];
      end
      if(byte_enable[6]) begin
        mem[addr][55:48] <= write_data[55:48];
      end
      if(byte_enable[7]) begin
        mem[addr][63:56] <= write_data[63:56];
      end
      if(byte_enable[8]) begin
        mem[addr][71:64] <= write_data[71:64];
      end
      if(byte_enable[9]) begin
        mem[addr][79:72] <= write_data[79:72];
      end
      if(byte_enable[10]) begin
        mem[addr][87:80] <= write_data[87:80];
      end
      if(byte_enable[11]) begin
        mem[addr][95:88] <= write_data[95:88];
      end
      if(byte_enable[12]) begin
        mem[addr][103:96] <= write_data[103:96];
      end
      if(byte_enable[13]) begin
        mem[addr][111:104] <= write_data[111:104];
      end
      if(byte_enable[14]) begin
        mem[addr][119:112] <= write_data[119:112];
      end
      if(byte_enable[15]) begin
        mem[addr][127:120] <= write_data[127:120];
      end
    end
    read_data <= mem[addr];
  end

  endmodule
  
