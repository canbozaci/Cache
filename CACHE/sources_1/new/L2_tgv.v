// True-Dual-Port BRAM with Byte-wide Write Enable
module L2_tgv#(
  parameter   NUM_COL             =   1, // no byte enables
  parameter   COL_WIDTH           =   8, // tag size (7 bits) + valid bit (1 bit)
  parameter   ADDR_WIDTH          =   8, // idx size = 8, log2(256) = 8 (256 = block no)
  // Addr  Width in bits : 2 *ADDR_WIDTH = RAM Depth
  parameter   DATA_WIDTH      =  NUM_COL*COL_WIDTH  // Data  Width in bits
  ) 
  (
  input clk_i,   // clock input
  input we_p1_i, // port 1 write enable signal (data cache)
  input we_p2_i, // port 2 write enable signal (instruction cache)
  input [ADDR_WIDTH-1:0] addr_p1_i, // port 1 address
  input [ADDR_WIDTH-1:0] addr_p2_i, // port 2 address
  input [DATA_WIDTH-1:0] data_p1_i, // port 1 data in
  input [DATA_WIDTH-1:0] data_p2_i, // port 2 data in
  output reg [DATA_WIDTH-1:0] data_p1_o, // data out port 1
  output reg [DATA_WIDTH-1:0] data_p2_o  // data out port 2
  );
  
  // Core Memory  
  (* ram_style = "block" *) reg [DATA_WIDTH-1:0]   ram_block [(2**ADDR_WIDTH)-1:0]; // memory delete attribute for ASIC design
 // Port-1 Operation Read First
 always @ (posedge clk_i) begin 
    if(we_p1_i) begin
      ram_block[addr_p1_i][DATA_WIDTH-1:0] <= data_p1_i[DATA_WIDTH-1:0];
    end
    data_p1_o <= ram_block[addr_p1_i];  
 end
 // Port-2 Operation Read First
 always @ (posedge clk_i) begin
    if(we_p2_i) begin
      ram_block[addr_p2_i][DATA_WIDTH-1:0] <= data_p2_i[DATA_WIDTH-1:0];
    end
    data_p2_o <= ram_block[addr_p2_i];  
 end

endmodule