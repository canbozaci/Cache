// Synthesizable dual-port tag/valid array model.
module L2_tgv#(
  parameter   NUM_COL             =   1, // no byte enables
  parameter   COL_WIDTH           =   8, // tag size (7 bits) + valid bit (1 bit)
  parameter   ADDR_WIDTH          =   8, // idx size = 8, log2(256) = 8 (256 = block no)
  // Addr  Width in bits : 2 *ADDR_WIDTH = RAM Depth
  parameter   DATA_WIDTH      =  NUM_COL*COL_WIDTH  // Data  Width in bits
  ) 
  (
  input clk,   // clock input
  input rst,
  input we_p1, // port 1 write enable signal (data cache)
  input we_p2, // port 2 write enable signal (instruction cache)
  input [ADDR_WIDTH-1:0] addr_p1, // port 1 address
  input [ADDR_WIDTH-1:0] addr_p2, // port 2 address
  input [DATA_WIDTH-1:0] write_data_p1, // port 1 data in
  input [DATA_WIDTH-1:0] write_data_p2, // port 2 data in
  output reg [DATA_WIDTH-1:0] read_data_p1, // data out port 1
  output reg [DATA_WIDTH-1:0] read_data_p2  // data out port 2
  );
  
  // Core Memory  
  reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
  integer mem_index;
  always @ (posedge clk) begin
    if (rst) begin
      for (mem_index = 0; mem_index < (2**ADDR_WIDTH); mem_index = mem_index + 1) begin
        /* verilator lint_off BLKSEQ */
        ram_block[mem_index] = {DATA_WIDTH{1'b0}};
        /* verilator lint_on BLKSEQ */
      end
      read_data_p1 <= {DATA_WIDTH{1'b0}};
      read_data_p2 <= {DATA_WIDTH{1'b0}};
    end else begin
      if(we_p1) begin
        ram_block[addr_p1][DATA_WIDTH-1:0] <= write_data_p1[DATA_WIDTH-1:0];
      end
      if(we_p2) begin
        ram_block[addr_p2][DATA_WIDTH-1:0] <= write_data_p2[DATA_WIDTH-1:0];
      end
      read_data_p1 <= ram_block[addr_p1];  
      read_data_p2 <= ram_block[addr_p2];  
    end
  end

endmodule
