// OpenRAM SRAM model
// Words: 64
// Word size: 128

module L1_instr_tgv#(
    parameter DATA_WIDTH = 10,// tag size (9 bits) + valid bit (1 bit)
    parameter ADDR_WIDTH = 6, // idx size (6 bits) log2(64) = 6 (64 = block no)
    parameter RAM_DEPTH = 1 << ADDR_WIDTH // 2^6 = 64 (depth)
    )
    (
    input  clk_i, // clock input
    input  we_i,  // write enable input
    input  we_next_i, // write enable input for next idx
    input  [ADDR_WIDTH-1:0] addr_i, // address input
    input  [DATA_WIDTH-1:0] data_i, // data input
    output reg [DATA_WIDTH-1:0] data_o, // data output
    output reg [DATA_WIDTH-1:0] data_next_o // next data output
    );

    // Core Memory
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0]    mem [0:RAM_DEPTH-1]; // memory delete attribute for ASIC design
    // Port-1 Operation Current Address Read First
    always @ (posedge clk_i) begin : MEM_WRITE
      if (we_i & ~(we_next_i)) begin // if write enable & not write next 
          mem[addr_i][DATA_WIDTH-1:0] <= data_i[DATA_WIDTH-1:0];
      end
      data_o <= mem[addr_i];
    end
    // Port-1 Operation Next idx Address Read First
    always @(posedge clk_i) begin: MEM_WRITE_NEXT
      if(we_i & we_next_i) begin // if write enable & write next
        mem[addr_i+1'b1][DATA_WIDTH-1:0] <= data_i[DATA_WIDTH-1:0];
      end
      data_next_o <= mem[addr_i + 6'd1];
    end
    
  endmodule
  