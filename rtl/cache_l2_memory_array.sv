// Synthesizable dual-port L2 cache line memory array model with byte enables.
module cache_l2_memory_array#(
   parameter   NUM_COL             =   16,// no byte enables
   parameter   COL_WIDTH           =   8, // 1 byte = 8 bits
   parameter   ADDR_WIDTH          =   8, // idx size = 8, log2(256) = 8 (256 = block no)
   // Addr  Width in bits : 2 *ADDR_WIDTH = RAM Depth
   parameter   DATA_WIDTH      =  NUM_COL*COL_WIDTH  // Data  Width in bits = 1 byte * 16 = 16 byte = 128 bits ==> LINE SIZE
   )
   (
   input clk,// clock input
   input we_p1,// port 1 write enable signal (data cache)
   input we_p2,// port 2 write enable signal (instruction cache)
   input [NUM_COL-1:0] byte_enable_p1, // byte enable signals for port 1
   input [NUM_COL-1:0] byte_enable_p2, // byte enable signals for port 2
   input [ADDR_WIDTH-1:0] addr_p1, // port 1 address
   input [ADDR_WIDTH-1:0] addr_p2, // port 2 address
   input [DATA_WIDTH-1:0] write_data_p1, // port 1 data in
   input [DATA_WIDTH-1:0] write_data_p2, // port 2 data in
   output reg [DATA_WIDTH-1:0] read_data_p1, // data out port 1
   output reg [DATA_WIDTH-1:0] read_data_p2 // data out port 2
   );

`ifdef SRAM_MACRO_ENABLE
`ifndef CACHE_L2_MEMORY_ARRAY_MACRO
  `error "SRAM_MACRO_ENABLE requires CACHE_L2_MEMORY_ARRAY_MACRO"
`endif

  `CACHE_L2_MEMORY_ARRAY_MACRO #(
    .NUM_COL(NUM_COL),
    .COL_WIDTH(COL_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) cache_l2_memory_array_macro_inst (
    .clk(clk),
    .we_p1(we_p1),
    .we_p2(we_p2),
    .byte_enable_p1(byte_enable_p1),
    .byte_enable_p2(byte_enable_p2),
    .addr_p1(addr_p1),
    .addr_p2(addr_p2),
    .write_data_p1(write_data_p1),
    .write_data_p2(write_data_p2),
    .read_data_p1(read_data_p1),
    .read_data_p2(read_data_p2)
  );
`else
   reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
  integer                i;
  // Port-1 Operation - Read First
  always @ (posedge clk) begin
    if(we_p1) begin
        for(i=0;i<NUM_COL;i=i+1) begin // for loop for byte enable signals
           if(byte_enable_p1[i]) begin // byte write
              ram_block[addr_p1][i*COL_WIDTH +: COL_WIDTH] <= write_data_p1[i*COL_WIDTH +: COL_WIDTH];
           end
        end
     end
    read_data_p1 <= ram_block[addr_p1];
  end
  // Port-2 Operation - Read First
  always @ (posedge clk) begin
    if(we_p2) begin
        for(i=0;i<NUM_COL;i=i+1) begin // for loop for byte enable signals
           if(byte_enable_p2[i]) begin // byte write
              ram_block[addr_p2][i*COL_WIDTH +: COL_WIDTH] <= write_data_p2[i*COL_WIDTH +: COL_WIDTH];
           end
        end
     end
    read_data_p2 <= ram_block[addr_p2];
  end
`endif

endmodule
