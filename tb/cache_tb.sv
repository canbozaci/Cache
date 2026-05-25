// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps

module cache_tb;
    localparam ADDR_WIDTH = 19;
    localparam DATA_WIDTH = 64;
    localparam MEM_DATA_WIDTH = 32;
    localparam L1_SET_COUNT = 64;
    localparam L2_SET_COUNT = 256;
    localparam RAM_ADDR_WIDTH = 17;

    reg clk;
    reg rst;
    reg mem_ready;
    reg instr_req_valid;
    reg instr_rsp_ready;
    reg data_req_valid;
    reg data_req_write;
    reg data_rsp_ready;
    reg [ADDR_WIDTH-1:0] instr_req_addr;
    reg [ADDR_WIDTH-1:0] data_req_addr;
    reg [DATA_WIDTH-1:0] data_req_wdata;
    reg [(DATA_WIDTH/8)-1:0] data_req_wstrb;
    reg mem_rd_rsp_valid;
    reg mem_rd_rsp_error;
    reg mem_wr_rsp_valid;
    reg mem_wr_rsp_error;

    wire instr_req_ready;
    wire instr_rsp_valid;
    wire [31:0] instr_rsp_data;
    wire instr_rsp_error;
    wire data_req_ready;
    wire data_rsp_valid;
    wire [DATA_WIDTH-1:0] data_rsp_rdata;
    wire data_rsp_error;
    wire [31:0] mem_req_addr;
    wire [MEM_DATA_WIDTH-1:0] mem_req_wdata;
    wire [MEM_DATA_WIDTH-1:0] mem_rd_rsp_rdata;
    wire mem_req_valid;
    wire mem_req_ready;
    wire mem_req_write;
    wire mem_req_burst;
    wire [7:0] mem_req_burst_len;
    wire [7:0] mem_req_beat_index;
    wire mem_req_burst_start;
    wire mem_req_burst_last;
    wire [(MEM_DATA_WIDTH/8)-1:0] mem_req_wstrb;
    wire mem_rd_rsp_ready;
    wire mem_wr_rsp_ready;

    assign mem_req_ready = mem_ready;

    cache_memory_model #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DATA_WIDTH(MEM_DATA_WIDTH)
    ) main_memory (
        .clk(clk),
        .rst_ni(~rst),
        .write_addr(mem_req_addr[RAM_ADDR_WIDTH+1:2]),
        .read_addr(mem_req_addr[RAM_ADDR_WIDTH+1:2]),
        .write_data(mem_req_wdata),
        .write_strobe(mem_req_write ? mem_req_wstrb : {(MEM_DATA_WIDTH/8){1'b0}}),
        .read_enable(mem_req_valid && mem_req_ready && !mem_req_write),
        .ready(1'b1),
        .read_data(mem_rd_rsp_rdata)
    );

    cache #(
        .L1_SET_COUNT(L1_SET_COUNT),
        .L2_SET_COUNT(L2_SET_COUNT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .instr_req_valid(instr_req_valid),
        .instr_req_ready(instr_req_ready),
        .instr_req_addr(instr_req_addr),
        .instr_rsp_valid(instr_rsp_valid),
        .instr_rsp_ready(instr_rsp_ready),
        .instr_rsp_data(instr_rsp_data),
        .instr_rsp_error(instr_rsp_error),
        .data_req_valid(data_req_valid),
        .data_req_ready(data_req_ready),
        .data_req_write(data_req_write),
        .data_req_addr(data_req_addr),
        .data_req_wdata(data_req_wdata),
        .data_req_wstrb(data_req_wstrb),
        .data_rsp_valid(data_rsp_valid),
        .data_rsp_ready(data_rsp_ready),
        .data_rsp_rdata(data_rsp_rdata),
        .data_rsp_error(data_rsp_error),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_write(mem_req_write),
        .mem_req_burst(mem_req_burst),
        .mem_req_burst_len(mem_req_burst_len),
        .mem_req_beat_index(mem_req_beat_index),
        .mem_req_burst_start(mem_req_burst_start),
        .mem_req_burst_last(mem_req_burst_last),
        .mem_req_addr(mem_req_addr),
        .mem_req_wdata(mem_req_wdata),
        .mem_req_wstrb(mem_req_wstrb),
        .mem_rd_rsp_valid(mem_rd_rsp_valid),
        .mem_rd_rsp_ready(mem_rd_rsp_ready),
        .mem_rd_rsp_rdata(mem_rd_rsp_rdata),
        .mem_rd_rsp_error(mem_rd_rsp_error),
        .mem_wr_rsp_valid(mem_wr_rsp_valid),
        .mem_wr_rsp_ready(mem_wr_rsp_ready),
        .mem_wr_rsp_error(mem_wr_rsp_error),
        .maint_flush_req(1'b0),
        .maint_invalidate_req(1'b0),
        .maint_flush_line_req(1'b0),
        .maint_invalidate_line_req(1'b0),
        .maint_addr_valid(1'b0),
        .maint_addr({ADDR_WIDTH{1'b0}}),
        .maint_ready(),
        .maint_done(),
        .maint_error()
    );

    always #6.25 clk = ~clk;

    initial begin
        clk = 1'b1;
        rst = 1'b1;
        mem_ready = 1'b1;
        instr_req_valid = 1'b0;
        instr_rsp_ready = 1'b1;
        data_req_valid = 1'b0;
        data_req_write = 1'b0;
        data_rsp_ready = 1'b1;
        instr_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        mem_rd_rsp_valid = 1'b0;
        mem_rd_rsp_error = 1'b0;
        mem_wr_rsp_valid = 1'b0;
        mem_wr_rsp_error = 1'b0;

        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (8) @(posedge clk);

        read_data(19'h00014);
        read_data(19'h00018);
        write_data(19'h00000, 64'h0000_0000_0000_0064, 8'b0000_0001);
        read_data(19'h00000);
        read_instr(19'h00000);
        read_instr(19'h00008);
        read_data_instr(19'h00014, 19'h00020);

        repeat (10) @(posedge clk);
        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_rd_rsp_valid <= 1'b0;
            mem_wr_rsp_valid <= 1'b0;
        end else begin
            if (mem_rd_rsp_ready) begin
                mem_rd_rsp_valid <= 1'b0;
            end
            if (mem_wr_rsp_ready) begin
                mem_wr_rsp_valid <= 1'b0;
            end
            if (mem_req_valid && mem_req_ready && !mem_req_write) begin
                mem_rd_rsp_valid <= 1'b1;
            end
            if (mem_req_valid && mem_req_ready && mem_req_write) begin
                mem_wr_rsp_valid <= 1'b1;
            end
        end
    end

    task read_instr(input [ADDR_WIDTH-1:0] addr);
    begin
        @(negedge clk);
        instr_req_addr = addr;
        instr_req_valid = 1'b1;
        while (!instr_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        instr_req_valid = 1'b0;
        while (!instr_rsp_valid) begin
            @(posedge clk);
        end
        @(posedge clk);
    end
    endtask

    task read_data(input [ADDR_WIDTH-1:0] addr);
    begin
        @(negedge clk);
        data_req_addr = addr;
        data_req_write = 1'b0;
        data_req_valid = 1'b1;
        while (!data_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        data_req_valid = 1'b0;
        while (!data_rsp_valid) begin
            @(posedge clk);
        end
        @(posedge clk);
    end
    endtask

    task write_data(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data,
        input [(DATA_WIDTH/8)-1:0] strobe
    );
    begin
        @(negedge clk);
        data_req_addr = addr;
        data_req_wdata = data;
        data_req_wstrb = strobe;
        data_req_write = 1'b1;
        data_req_valid = 1'b1;
        while (!data_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        data_req_valid = 1'b0;
        while (!data_rsp_valid) begin
            @(posedge clk);
        end
        @(posedge clk);
        data_req_write = 1'b0;
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
    end
    endtask

    task read_data_instr(
        input [ADDR_WIDTH-1:0] data_addr,
        input [ADDR_WIDTH-1:0] instr_addr
    );
    begin
        @(negedge clk);
        data_req_addr = data_addr;
        instr_req_addr = instr_addr;
        data_req_write = 1'b0;
        data_req_valid = 1'b1;
        instr_req_valid = 1'b1;
        while (!data_req_ready || !instr_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        data_req_valid = 1'b0;
        instr_req_valid = 1'b0;
        while (!data_rsp_valid || !instr_rsp_valid) begin
            @(posedge clk);
        end
        @(posedge clk);
    end
    endtask
endmodule
