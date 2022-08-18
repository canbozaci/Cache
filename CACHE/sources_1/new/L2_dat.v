// True-Dual-Port BRAM with Byte-wide Write Enable
module L2_dat#(
   parameter   NUM_COL             =   16,// no byte enables
   parameter   COL_WIDTH           =   8, // 1 byte = 8 bits
   parameter   ADDR_WIDTH          =   8, // idx size = 8, log2(256) = 8 (256 = block no)
   // Addr  Width in bits : 2 *ADDR_WIDTH = RAM Depth
   parameter   DATA_WIDTH      =  NUM_COL*COL_WIDTH  // Data  Width in bits = 1 byte * 16 = 16 byte = 128 bits ==> LINE SIZE
   ) 
   (
   input clk_i,// clock input
   input we_p1_i,// port 1 write enable signal (data cache)
   input we_p2_i,// port 2 write enable signal (instruction cache)
   input [NUM_COL-1:0] byte_enable_p1_i, // byte enable signals for port 1
   input [NUM_COL-1:0] byte_enable_p2_i, // byte enable signals for port 2
   input [ADDR_WIDTH-1:0] addr_p1_i, // port 1 address
   input [ADDR_WIDTH-1:0] addr_p2_i, // port 2 address
   input [DATA_WIDTH-1:0] data_p1_i, // port 1 data in
   input [DATA_WIDTH-1:0] data_p2_i, // port 2 data in
   output reg [DATA_WIDTH-1:0] data_p1_o, // data out port 1
   output reg [DATA_WIDTH-1:0] data_p2_o // data out port 2
   );
   
   // Core Memory  
   (* ram_style = "block" *) reg [DATA_WIDTH-1:0]   ram_block [(2**ADDR_WIDTH)-1:0]; // memory delete attribute for ASIC design
  integer                i;
  // Port-1 Operation - Read First
  always @ (posedge clk_i) begin
    if(we_p1_i) begin
        for(i=0;i<NUM_COL;i=i+1) begin // for loop for byte enable signals
           if(byte_enable_p1_i[i]) begin // byte write
              ram_block[addr_p1_i][i*COL_WIDTH +: COL_WIDTH] <= data_p1_i[i*COL_WIDTH +: COL_WIDTH];
           end
        end
     end
    data_p1_o <= ram_block[addr_p1_i];  
  end
  // Port-2 Operation - Read First
  always @ (posedge clk_i) begin
    if(we_p2_i) begin
        for(i=0;i<NUM_COL;i=i+1) begin // for loop for byte enable signals
           if(byte_enable_p2_i[i]) begin // byte write
              ram_block[addr_p2_i][i*COL_WIDTH +: COL_WIDTH] <= data_p2_i[i*COL_WIDTH +: COL_WIDTH];
           end
        end     
     end
    data_p2_o <= ram_block[addr_p2_i];  
  end

endmodule