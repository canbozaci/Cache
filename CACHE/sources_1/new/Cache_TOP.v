`timescale 1ns / 1ps
module Cache_TOP(
    input clk_i,            // cache clock
    input mem_clk_i,        // main mem clock if it is different from cache clock
    input rst_i,            // active high reset signal
    input read_instr_i,     // coming from core! read instruction signal
    input read_data_i,      // coming from core! read data signal
    input write_data_i,     // coming from core! write data signal
    input [18:0] L1_instr_addr_i, // coming from core ! instruction address
    input [18:0] L1_data_addr_i, // coming from core ! data address
    input [2:0] DATA_read_instruction_i, // coming from core  ! what kind of read in data cache (LB, LWU, LH, LD...)
    input [2:0] DATA_write_instruction_i, // coming from core ! what kind of read in data cache (SB, SW, SH, SD...)
    input [63:0] core_data_i, // coming from core ! data input from core 64 bits
    input [31:0] ram_data_i, // data output from ram
    output [31:0] core_instr_o, // goes to the core instruction output
    output [63:0] core_data_o, // goes to the core data output
    output [31:0] ram_data_o, // data input to the ram
    output [31:0] ram_read_addr_o, // ram read addr
    output [31:0] ram_write_addr_o, // ram write addr
    output ram_read_o, // ram read signal
    output miss_o,     // output miss signal
    output [3:0] wr_strb_o, // write strobe output
    output write_data_o // data cache is writing to main memory
    );
    wire write_through_o;  // write through signal indicating that there is will be a write through in L2 and L1 data cache
    // L2 wires
    wire [127:0] L2_data_block_p1_o;
    wire [127:0] L2_data_block_p2_o;
    wire [127:0] L2_data_block_p1_i;
    wire [18:0] L2_p2_addr; //miss_next varsa sonraki adres olcak 
    wire [15:0] L2_byte_enable_p1_i;
    wire [15:0] L2_byte_enable_p2_i;
    wire L2_read_p1;
    wire L2_read_p2;
    wire L2_write_p1;
    wire L2_write_p2;
    wire L2_p1_hit;
    wire L2_p2_hit;
    wire ram_write_start_o; // first write will be done on L2 cache (to not corrupt replacement algorithm)
    // L1_instr wires
    wire L1_instr_hit;
    wire L1_instr_write;
    wire L1_miss_next; // miss in next idx and (only given if data is needed from next idx)
    wire read_instr_o; // read instruction command coming from controller in case of miss
    wire instr_write_start_o; // write start on instruction cache (because of block rams it is being done in 2 clock period)
    wire write_next_i; 
    // L1_data wires
    wire write_L2; // write from L2 to the L1 cache
    wire read_data_o; // read data command coming from controller in case of miss 
    wire L1_data_hit;
    wire [127:0] L1_data_block_o;
    assign L2_data_block_p1_i = (ram_read_o == 1) ? {4{ram_data_i}} : L1_data_block_o; // if there is a ram_read then data port 1 must be ram data input else it is coming from L1 data cache

    Cache_MEM_L1_data Cache_L1_DATA_INST( 
    .clk_i(clk_i),
    .rst_i(rst_i),
    .read_i(read_data_o | read_data_i), 
    .write_i(write_L2 | write_data_o),  
    .read_instruction_i(DATA_read_instruction_i),  
    .write_instruction_i(DATA_write_instruction_i), 
    .write_L2_i(write_L2),  
    .write_through_i(write_through_o),
    .addr_i(L1_data_addr_i),        
    .data_core_i(core_data_i), 
    .data_L2_i(L2_data_block_p1_o), 
    .data_block_o(L1_data_block_o), // buna gerek yok core_data_o'dan yola cikilarak ta yapilabilir?
    .data_o(core_data_o), 
    .hit_o(L1_data_hit)             
    );

    Cache_MEM_L1_instr Cache_L1_INSTR(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .read_i(read_instr_o | read_instr_i),  //| read_instr_reg_o
    .instr_write_start_i(instr_write_start_o),
    .write_i(L1_instr_write), 
    .write_next_i(write_next_i),
    .addr_i(L1_instr_addr_i[18:1]),          // 
    .data_L2_i(L2_data_block_p2_o), 
    .data_o(core_instr_o),
    .hit_o(L1_instr_hit),           
    .miss_next_o(L1_miss_next)      
    );

    Cache_MEM_L2 Cache_L2_inst( 
    .clk_i(clk_i),
    .rst_i(rst_i), 
    .read_p1_i(L2_read_p1),                 
    .read_p2_i(L2_read_p2),                 
    .write_p1_i(L2_write_p1),                
    .write_p2_i(L2_write_p2),                
    .data_block_p1_i(L2_data_block_p1_i),  
    .data_block_p2_i({4{ram_data_i}}),      
    .byte_enable_p1_i(L2_byte_enable_p1_i),
    .byte_enable_p2_i(L2_byte_enable_p2_i),
    .addr_p1_i(L1_data_addr_i[14:0]),      // word and offset bits do not matter for L2 cache 
    .addr_p2_i(L2_p2_addr[14:0]),          // word and offset bits do not matter for L2 cache
    .ram_write_start_i(ram_write_start_o),  
    .write_through_i(write_through_o),      
    .data_block_p1_o(L2_data_block_p1_o), 
    .data_block_p2_o(L2_data_block_p2_o), 
    .hit_p1_o(L2_p1_hit),        
    .hit_p2_o(L2_p2_hit)         
    );

    Cache_controller Cache_controller_inst(
    .clk_i(clk_i),
    .mem_clk_i(mem_clk_i),
    .rst_i(rst_i),
    .L2_data_block_p1_i(L2_data_block_p1_o),
    .L1_data_addr_i(L1_data_addr_i),
    .L1_instr_addr_i(L1_instr_addr_i),
    .L2_p1_hit_i(L2_p1_hit),
    .L2_p2_hit_i(L2_p2_hit),
    .L1_data_hit_i(L1_data_hit),
    .L1_instr_hit_i(L1_instr_hit),
    .L1_miss_next_i(L1_miss_next),
    .read_instr_i(read_instr_i),
    .read_data_i(read_data_i),
    .write_data_i(write_data_i),
    .DATA_write_instruction_i(DATA_write_instruction_i),
    .write_L2_o(write_L2),
    .L1_instr_write_o(L1_instr_write),
    .L2_read_p1_o(L2_read_p1),
    .L2_read_p2_o(L2_read_p2),
    .L2_write_p1_o(L2_write_p1),
    .L2_write_p2_o(L2_write_p2),
    .L2_byte_enable_p1_o(L2_byte_enable_p1_i),
    .L2_byte_enable_p2_o(L2_byte_enable_p2_i),
    .L2_p2_addr_o(L2_p2_addr),
    .ram_data_o(ram_data_o),
    .ram_read_addr_o(ram_read_addr_o),
    .ram_write_addr_o(ram_write_addr_o),
    .ram_read_o(ram_read_o),
    .miss_o(miss_o),
    .ram_write_start_o(ram_write_start_o),
    .write_next_o(write_next_i),
    .wr_strb_o(wr_strb_o),
    .read_data_o(read_data_o),
    .read_instr_o(read_instr_o),
    .write_data_o(write_data_o),
    .write_through_o(write_through_o),
    .instr_write_start_o(instr_write_start_o)
    );

endmodule
