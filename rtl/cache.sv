`timescale 1ns / 1ps

module cache #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 64,
    parameter MEM_DATA_WIDTH = 32,
    parameter LINE_WIDTH = 128
) (
    input clk,
    input mem_clk,
    input rst,

    input instr_req_valid,
    input [ADDR_WIDTH-1:0] instr_req_addr,
    output [31:0] instr_resp_data,

    input data_req_read,
    input data_req_write,
    input [ADDR_WIDTH-1:0] data_req_addr,
    input [DATA_WIDTH-1:0] data_req_wdata,
    input [(DATA_WIDTH/8)-1:0] data_req_wstrb,
    output [DATA_WIDTH-1:0] data_resp_rdata,

    input [MEM_DATA_WIDTH-1:0] mem_rdata,
    output [MEM_DATA_WIDTH-1:0] mem_wdata,
    output [31:0] mem_read_addr,
    output [31:0] mem_write_addr,
    output mem_read,
    output [3:0] mem_wstrb,
    output mem_write,

    output busy
);

    wire write_through;

    wire [LINE_WIDTH-1:0] l2_write_block_p1;
    wire [LINE_WIDTH-1:0] l2_write_block_p2;
    wire [LINE_WIDTH-1:0] l2_read_block_p1;
    wire [LINE_WIDTH-1:0] l2_read_block_p2;
    wire [14:0] l2_p2_addr;
    wire [15:0] l2_byte_enable_p1;
    wire [15:0] l2_byte_enable_p2;
    wire l2_read_p1;
    wire l2_read_p2;
    wire l2_write_p1;
    wire l2_write_p2;
    wire l2_p1_hit;
    wire l2_p2_hit;
    wire mem_write_start;

    wire l1_instr_hit;
    wire l1_instr_write;
    wire l1_miss_next;
    wire instr_cache_read;
    wire instr_write_start;
    wire write_next;
    wire controller_busy;
    wire unused_controller_outputs;

    wire write_l2;
    wire data_cache_read;
    wire l1_data_hit;
    wire [LINE_WIDTH-1:0] l1_data_block;

    assign l2_write_block_p1 = (mem_read == 1'b1) ? {4{mem_rdata}} : l1_data_block;
    assign l2_write_block_p2 = {4{mem_rdata}};
    assign unused_controller_outputs = instr_write_start | write_next;
    assign busy = controller_busy | (unused_controller_outputs & 1'b0);

    Cache_MEM_L1_data #(
        .block_size(LINE_WIDTH),
        .data_width(DATA_WIDTH)
    ) cache_l1_data_inst (
        .clk(clk),
        .rst(rst),
        .read(data_cache_read | data_req_read),
        .write(write_l2 | mem_write),
        .write_L2(write_l2),
        .write_through(write_through),
        .addr(data_req_addr),
        .write_data(data_req_wdata),
        .write_strobe(data_req_wstrb),
        .data_L2(l2_read_block_p1),
        .data_block(l1_data_block),
        .data(data_resp_rdata),
        .hit(l1_data_hit)
    );

    cache_l1_read_cache #(
        .BLOCK_WIDTH(LINE_WIDTH),
        .DATA_WIDTH(32)
    ) cache_l1_instr_inst (
        .clk(clk),
        .rst(rst),
        .read(instr_cache_read | instr_req_valid),
        .fill(l1_instr_write),
        .addr(instr_req_addr),
        .fill_block(l2_read_block_p2),
        .data(instr_resp_data),
        .hit(l1_instr_hit)
    );

    assign l1_miss_next = 1'b0;

    Cache_MEM_L2 #(
        .block_size(LINE_WIDTH)
    ) cache_l2_inst (
        .clk(clk),
        .rst(rst),
        .read_p1(l2_read_p1),
        .read_p2(l2_read_p2),
        .write_p1(l2_write_p1),
        .write_p2(l2_write_p2),
        .data_block_write_p1(l2_write_block_p1),
        .data_block_write_p2(l2_write_block_p2),
        .byte_enable_p1(l2_byte_enable_p1),
        .byte_enable_p2(l2_byte_enable_p2),
        .addr_p1(data_req_addr[14:0]),
        .addr_p2(l2_p2_addr),
        .ram_write_start(mem_write_start),
        .write_through(write_through),
        .data_block_read_p1(l2_read_block_p1),
        .data_block_read_p2(l2_read_block_p2),
        .hit_p1(l2_p1_hit),
        .hit_p2(l2_p2_hit)
    );

    Cache_controller cache_controller_inst (
        .clk(clk),
        .mem_clk(mem_clk),
        .rst(rst),
        .L2_data_block_p1(l2_read_block_p1),
        .L1_data_addr(data_req_addr),
        .L1_instr_addr(instr_req_addr),
        .L2_p1_hit(l2_p1_hit),
        .L2_p2_hit(l2_p2_hit),
        .L1_data_hit(l1_data_hit),
        .L1_instr_hit(l1_instr_hit),
        .L1_miss_next(l1_miss_next),
        .instr_request(instr_req_valid),
        .data_read_request(data_req_read),
        .data_write_request(data_req_write),
        .data_write_strobe(data_req_wstrb),
        .write_L2(write_l2),
        .L1_instr_write(l1_instr_write),
        .L2_read_p1(l2_read_p1),
        .L2_read_p2(l2_read_p2),
        .L2_write_p1(l2_write_p1),
        .L2_write_p2(l2_write_p2),
        .L2_byte_enable_p1(l2_byte_enable_p1),
        .L2_byte_enable_p2(l2_byte_enable_p2),
        .L2_p2_addr(l2_p2_addr),
        .ram_data(mem_wdata),
        .ram_read_addr(mem_read_addr),
        .ram_write_addr(mem_write_addr),
        .ram_read(mem_read),
        .miss(controller_busy),
        .ram_write_start(mem_write_start),
        .write_next(write_next),
        .wr_strb(mem_wstrb),
        .data_cache_read(data_cache_read),
        .instr_cache_read(instr_cache_read),
        .memory_write(mem_write),
        .write_through(write_through),
        .instr_write_start(instr_write_start)
    );

endmodule
