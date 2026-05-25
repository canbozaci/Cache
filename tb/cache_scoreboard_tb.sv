// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps

module cache_scoreboard_tb #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 64,
    parameter MEM_DATA_WIDTH = 32,
    parameter LINE_WIDTH = 128,
    parameter L1_SET_COUNT = 64,
    parameter L1_DATA_SET_COUNT = L1_SET_COUNT,
    parameter L1_INSTR_SET_COUNT = L1_SET_COUNT,
    parameter L2_SET_COUNT = 256,
    parameter RAM_ADDR_WIDTH = 17,
    parameter REF_BYTES = 16384,
    parameter MEM_READY_STALLS = 0,
    parameter MEM_RSP_EXTRA_LATENCY = 0,
    parameter MEM_RSP_VARIABLE_LATENCY = 0,
    parameter integer MEM_RD_ERROR_BEAT = -1,
    parameter MEM_WR_ERROR_ENABLE = 0,
    parameter MEM_WR_RSP_EXTRA_LATENCY = 0,
    parameter INSTR_RSP_BACKPRESSURE = 0,
    parameter DATA_RSP_BACKPRESSURE = 0
) ();
    localparam REF_WORDS = REF_BYTES / 4;
    localparam MEM_ADDR_LSB = (MEM_DATA_WIDTH == 64) ? 3 : 2;
    localparam LINE_MEM_BEAT_COUNT = LINE_WIDTH / MEM_DATA_WIDTH;
    localparam LINE_BYTE_COUNT = LINE_WIDTH / 8;
    localparam [ADDR_WIDTH-1:0] NEXT_LINE_ADDR = LINE_BYTE_COUNT;
    localparam [ADDR_WIDTH-1:0] L1_ALIAS_STRIDE = L1_DATA_SET_COUNT * LINE_BYTE_COUNT;
    localparam [7:0] LINE_MEM_BEAT_COUNT_8 =
        (LINE_MEM_BEAT_COUNT == 1)  ? 8'd1  :
        (LINE_MEM_BEAT_COUNT == 2)  ? 8'd2  :
        (LINE_MEM_BEAT_COUNT == 4)  ? 8'd4  :
        (LINE_MEM_BEAT_COUNT == 8)  ? 8'd8  :
        (LINE_MEM_BEAT_COUNT == 16) ? 8'd16 : 8'd32;
    localparam [7:0] LINE_MEM_LAST_BEAT =
        (LINE_MEM_BEAT_COUNT == 1)  ? 8'd0  :
        (LINE_MEM_BEAT_COUNT == 2)  ? 8'd1  :
        (LINE_MEM_BEAT_COUNT == 4)  ? 8'd3  :
        (LINE_MEM_BEAT_COUNT == 8)  ? 8'd7  :
        (LINE_MEM_BEAT_COUNT == 16) ? 8'd15 : 8'd31;

    reg clk;
    reg rst;
    reg maint_flush_req;
    reg maint_invalidate_req;
    reg maint_flush_line_req;
    reg maint_invalidate_line_req;
    reg maint_addr_valid;
    reg [ADDR_WIDTH-1:0] maint_addr;
    reg [1:0] mem_ready_counter;
    reg mem_rsp_pending;
    reg mem_rsp_pending_error;
    integer mem_rsp_countdown;
    integer mem_rsp_latency_value;
    reg mem_wr_rsp_pending;
    reg mem_wr_rsp_pending_error;
    integer mem_wr_rsp_countdown;

    reg instr_req_valid;
    reg instr_rsp_ready;
    reg data_req_valid;
    reg data_req_write;
    reg data_rsp_ready;
    reg [ADDR_WIDTH-1:0] instr_req_addr;
    reg [ADDR_WIDTH-1:0] data_req_addr;
    reg [DATA_WIDTH-1:0] data_req_wdata;
    reg [(DATA_WIDTH/8)-1:0] data_req_wstrb;

    wire instr_req_ready;
    wire instr_rsp_valid;
    wire [31:0] instr_rsp_data;
    wire instr_rsp_error;
    wire data_req_ready;
    wire data_rsp_valid;
    wire [DATA_WIDTH-1:0] data_rsp_rdata;
    wire data_rsp_error;
    wire [MEM_DATA_WIDTH-1:0] mem_rd_rsp_rdata;
    wire [MEM_DATA_WIDTH-1:0] mem_req_wdata;
    wire [31:0] mem_req_addr;
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
    reg mem_rd_rsp_valid;
    reg mem_rd_rsp_error;
    wire mem_wr_rsp_ready;
    reg mem_wr_rsp_valid;
    reg mem_wr_rsp_error;
    wire maint_ready;
    wire maint_done;
    wire maint_error;

    reg [7:0] reference_memory [0:REF_BYTES-1];
    integer error_count;
    integer reference_word_index;
    integer reference_byte_index;
    integer mem_read_handshake_count;
    reg [31:0] reference_word_value;
    reg [7:0] expected_write_burst_len;
    reg [7:0] expected_write_beat_index;
    reg write_burst_check_active;

    assign mem_req_ready = (MEM_READY_STALLS == 0) ? 1'b1 : (mem_ready_counter != 2'd1);

    cache_memory_model #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DATA_WIDTH(MEM_DATA_WIDTH)
    ) main_memory (
        .clk(clk),
        .rst_ni(~rst),
        .write_addr(mem_req_addr[RAM_ADDR_WIDTH+MEM_ADDR_LSB-1:MEM_ADDR_LSB]),
        .read_addr(mem_req_addr[RAM_ADDR_WIDTH+MEM_ADDR_LSB-1:MEM_ADDR_LSB]),
        .write_data(mem_req_wdata),
        .write_strobe(mem_req_write ? mem_req_wstrb : {(MEM_DATA_WIDTH/8){1'b0}}),
        .read_enable(mem_req_valid && mem_req_ready && !mem_req_write),
        .ready(1'b1),
        .read_data(mem_rd_rsp_rdata)
    );

    cache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH),
        .LINE_WIDTH(LINE_WIDTH),
        .L1_SET_COUNT(L1_SET_COUNT),
        .L1_DATA_SET_COUNT(L1_DATA_SET_COUNT),
        .L1_INSTR_SET_COUNT(L1_INSTR_SET_COUNT),
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
        .maint_flush_req(maint_flush_req),
        .maint_invalidate_req(maint_invalidate_req),
        .maint_flush_line_req(maint_flush_line_req),
        .maint_invalidate_line_req(maint_invalidate_line_req),
        .maint_addr_valid(maint_addr_valid),
        .maint_addr(maint_addr),
        .maint_ready(maint_ready),
        .maint_done(maint_done),
        .maint_error(maint_error)
    );

    always #6.25 clk = ~clk;

    always @(posedge clk) begin
        if (rst) begin
            mem_ready_counter <= 2'b0;
            mem_rd_rsp_valid <= 1'b0;
            mem_wr_rsp_valid <= 1'b0;
            mem_rsp_pending <= 1'b0;
            mem_wr_rsp_pending <= 1'b0;
        end else begin
            mem_ready_counter <= mem_ready_counter + 2'd1;
            if (mem_rd_rsp_ready) begin
                mem_rd_rsp_valid <= 1'b0;
            end
            if (mem_wr_rsp_ready) begin
                mem_wr_rsp_valid <= 1'b0;
            end
            if (mem_rsp_pending) begin
                if (mem_rsp_countdown == 0) begin
                    mem_rd_rsp_valid <= 1'b1;
                    mem_rd_rsp_error <= mem_rsp_pending_error;
                    if (mem_rd_rsp_ready) begin
                        mem_rsp_pending <= 1'b0;
                    end
                end else begin
                    mem_rsp_countdown <= mem_rsp_countdown - 1;
                end
            end
            if (mem_req_valid && mem_req_ready && !mem_req_write) begin
                mem_read_handshake_count <= mem_read_handshake_count + 1;
                mem_rsp_pending <= 1'b1;
                if (MEM_RSP_VARIABLE_LATENCY != 0) begin
                    mem_rsp_latency_value = mem_read_handshake_count % 4;
                end else begin
                    mem_rsp_latency_value = MEM_RSP_EXTRA_LATENCY;
                end
                mem_rsp_countdown <= mem_rsp_latency_value;
                mem_rsp_pending_error <= (mem_read_handshake_count == MEM_RD_ERROR_BEAT);
            end
            if (mem_req_valid && mem_req_ready && mem_req_write) begin
                mem_wr_rsp_pending <= 1'b1;
                mem_wr_rsp_countdown <= MEM_WR_RSP_EXTRA_LATENCY;
                mem_wr_rsp_pending_error <= (MEM_WR_ERROR_ENABLE != 0);
            end
            if (mem_wr_rsp_pending) begin
                if (mem_wr_rsp_countdown == 0) begin
                    mem_wr_rsp_valid <= 1'b1;
                    mem_wr_rsp_error <= mem_wr_rsp_pending_error;
                    if (mem_wr_rsp_ready) begin
                        mem_wr_rsp_pending <= 1'b0;
                    end
                end else begin
                    mem_wr_rsp_countdown <= mem_wr_rsp_countdown - 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst && mem_req_valid && mem_req_ready) begin
            if (mem_req_write) begin
                if (write_burst_check_active && (mem_req_burst_len != expected_write_burst_len)) begin
                    $display("BURST MISMATCH: write len expected=%0d actual=%0d",
                             expected_write_burst_len, mem_req_burst_len);
                    error_count = error_count + 1;
                end
                if (write_burst_check_active && (mem_req_beat_index != expected_write_beat_index)) begin
                    $display("BURST MISMATCH: write beat expected=%0d actual=%0d",
                             expected_write_beat_index, mem_req_beat_index);
                    error_count = error_count + 1;
                end
                if ((mem_req_burst != (mem_req_burst_len != 8'd1)) ||
                    (mem_req_burst_start != (mem_req_burst && (mem_req_beat_index == 8'd0))) ||
                    (mem_req_burst_last != (mem_req_burst && (mem_req_beat_index == (mem_req_burst_len - 8'd1))))) begin
                    $display("BURST MISMATCH: write metadata burst=%0b len=%0d beat=%0d start=%0b last=%0b",
                             mem_req_burst, mem_req_burst_len, mem_req_beat_index,
                             mem_req_burst_start, mem_req_burst_last);
                    error_count = error_count + 1;
                end
                if (write_burst_check_active && (expected_write_beat_index != expected_write_burst_len)) begin
                    expected_write_beat_index = expected_write_beat_index + 8'd1;
                end
            end else if (LINE_MEM_BEAT_COUNT == 1) begin
                if (mem_req_burst || (mem_req_burst_len != 8'd1) || (mem_req_beat_index != 8'd0) ||
                    mem_req_burst_start || mem_req_burst_last) begin
                    $display("BURST MISMATCH: single-beat read metadata burst=%0b len=%0d beat=%0d start=%0b last=%0b",
                             mem_req_burst, mem_req_burst_len, mem_req_beat_index,
                             mem_req_burst_start, mem_req_burst_last);
                    error_count = error_count + 1;
                end
            end else begin
                if (!mem_req_burst || (mem_req_burst_len != LINE_MEM_BEAT_COUNT_8) ||
                    (mem_req_beat_index > LINE_MEM_LAST_BEAT) ||
                    (mem_req_burst_start != (mem_req_beat_index == 8'd0)) ||
                    (mem_req_burst_last != (mem_req_beat_index == LINE_MEM_LAST_BEAT))) begin
                    $display("BURST MISMATCH: read metadata burst=%0b len=%0d beat=%0d start=%0b last=%0b",
                             mem_req_burst, mem_req_burst_len, mem_req_beat_index,
                             mem_req_burst_start, mem_req_burst_last);
                    error_count = error_count + 1;
                end
            end
        end
    end

    initial begin
        initialize_reference_memory();
        initialize_signals();
        reset_dut();

        check_maintenance_contract();
        check_illegal_maintenance_contract();

        if (MEM_RD_ERROR_BEAT >= 0) begin
            check_memory_read_error_contract();
            finish_scoreboard();
        end
        if (MEM_WR_ERROR_ENABLE != 0) begin
            check_memory_write_error_contract();
            finish_scoreboard();
        end
        if (MEM_WR_RSP_EXTRA_LATENCY != 0) begin
            check_delayed_memory_write_response_contract();
            finish_scoreboard();
        end
        if (INSTR_RSP_BACKPRESSURE != 0) begin
            check_instruction_response_backpressure_contract();
            finish_scoreboard();
        end
        if (DATA_RSP_BACKPRESSURE != 0) begin
            check_data_response_backpressure_contract();
            finish_scoreboard();
        end

        check_reset_contract();

        expect_data_read(19'h00000, "data cold line 0 word 0");
        expect_data_read(19'h00004, "data hit line 0 word 1");
        expect_data_read(19'h00008, "data hit line 0 word 2");
        check_line_maintenance_contract();
        check_queued_maintenance_contract();
        expect_data_read(19'h00020, "data cold line 2 word 0");

        expect_instr_read(19'h00000, "instruction cold line 0 word 0");
        expect_instr_read(19'h00004, "instruction hit line 0 word 1");
        check_instruction_data_incoherency_contract();

        apply_data_write(19'h00000, 64'h0000_0000_0000_00a5, 8'h01, "single byte write at line base");
        expect_data_read(19'h00000, "read after single byte write");

        apply_data_write(19'h00004, 64'h1122_3344_5566_7788, 8'hff, "aligned 64-bit write at word 1");
        expect_data_read(19'h00004, "read after aligned 64-bit write");

        apply_data_write(19'h00002, 64'haabb_ccdd_eeff_1234, 8'hff, "unaligned 64-bit write crossing three memory beats");
        expect_data_read(19'h00000, "read lower bytes after three-beat write");
        expect_data_read(19'h00008, "read upper bytes after three-beat write");

        apply_data_write(19'h00005, 64'h0000_0000_0000_00cc, 8'h01, "unaligned single byte write");
        expect_data_read(19'h00004, "read after unaligned single byte write");

        apply_data_write(19'h00010, 64'h0000_0000_dead_beef, 8'h0f, "aligned low-word partial write");
        expect_data_read(19'h00010, "read after low-word partial write");

        expect_data_read(19'h00004, "repeat hit after writes");
        expect_data_read(19'h00004, "second repeat hit after writes");
        check_l1_replacement_eviction_contract();
        expect_data_and_instr_read(19'h00020, 19'h00030, "simultaneous data and instruction reads");

        finish_scoreboard();
    end

    task finish_scoreboard;
    begin
        if (error_count == 0) begin
            $display("CACHE SCOREBOARD PASS");
            $finish;
        end
        $display("CACHE SCOREBOARD FAIL: %0d mismatches", error_count);
        $fatal(1);
    end
    endtask

    task check_memory_read_error_contract;
    begin
        expect_data_read_error(19'h00000, "memory read error recovery");
        mem_rd_rsp_error = 1'b0;
        expect_data_read(19'h00020, "read after memory read error");
    end
    endtask

    task check_memory_write_error_contract;
    begin
        expect_data_write_error(19'h00000, 64'h0000_0000_0000_00a5, 8'h01,
                                "memory write error response");
        mem_wr_rsp_error = 1'b0;
        expect_data_read(19'h00020, "read after memory write error");
    end
    endtask

    task check_delayed_memory_write_response_contract;
    begin
        apply_data_write(19'h00000, 64'h0000_0000_0000_00a5, 8'h01,
                         "delayed memory write response");
        expect_data_read(19'h00000, "read after delayed write response");
    end
    endtask

    task check_instruction_response_backpressure_contract;
    begin
        instr_rsp_ready = 1'b0;
        @(negedge clk);
        instr_req_addr = 19'h00000;
        instr_req_valid = 1'b1;
        while (!instr_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        instr_req_valid = 1'b0;
        while (!instr_rsp_valid) begin
            @(posedge clk);
        end
        repeat (4) @(posedge clk);
        if (!instr_rsp_valid || instr_rsp_data !== instr_rsp_data) begin
            $display("INSTR BACKPRESSURE MISMATCH: response did not hold while ready was low");
            error_count = error_count + 1;
        end
        instr_rsp_ready = 1'b1;
        @(posedge clk);
        wait_for_idle("instruction response backpressure");
    end
    endtask

    task check_data_response_backpressure_contract;
        reg [DATA_WIDTH-1:0] held_data;
    begin
        data_rsp_ready = 1'b0;
        @(negedge clk);
        data_req_addr = 19'h00000;
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
        held_data = data_rsp_rdata;
        repeat (4) @(posedge clk);
        if (!data_rsp_valid || (data_rsp_rdata !== held_data)) begin
            $display("DATA BACKPRESSURE MISMATCH: response did not hold while ready was low");
            error_count = error_count + 1;
        end
        data_rsp_ready = 1'b1;
        @(posedge clk);
        wait_for_idle("data response backpressure");
    end
    endtask

    task initialize_signals;
    begin
        clk = 1'b1;
        rst = 1'b1;
        maint_flush_req = 1'b0;
        maint_invalidate_req = 1'b0;
        maint_flush_line_req = 1'b0;
        maint_invalidate_line_req = 1'b0;
        maint_addr_valid = 1'b0;
        maint_addr = {ADDR_WIDTH{1'b0}};
        mem_ready_counter = 2'b0;
        mem_rd_rsp_valid = 1'b0;
        mem_rd_rsp_error = 1'b0;
        mem_wr_rsp_valid = 1'b0;
        mem_wr_rsp_error = 1'b0;
        mem_rsp_pending = 1'b0;
        mem_rsp_pending_error = 1'b0;
        mem_rsp_countdown = 0;
        mem_rsp_latency_value = 0;
        mem_wr_rsp_pending = 1'b0;
        mem_wr_rsp_pending_error = 1'b0;
        mem_wr_rsp_countdown = 0;
        mem_read_handshake_count = 0;
        instr_req_valid = 1'b0;
        instr_rsp_ready = 1'b1;
        data_req_valid = 1'b0;
        data_req_write = 1'b0;
        data_rsp_ready = 1'b1;
        instr_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_addr = {ADDR_WIDTH{1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        error_count = 0;
        expected_write_burst_len = 8'd1;
        expected_write_beat_index = 8'd0;
        write_burst_check_active = 1'b0;
    end
    endtask

    task check_l1_replacement_eviction_contract;
        reg [ADDR_WIDTH-1:0] alias_addr_0;
        reg [ADDR_WIDTH-1:0] alias_addr_1;
        reg [ADDR_WIDTH-1:0] alias_addr_2;
        integer reads_before;
        integer reads_after;
    begin
        alias_addr_0 = 19'h00100;
        alias_addr_1 = alias_addr_0 + L1_ALIAS_STRIDE;
        alias_addr_2 = alias_addr_1 + L1_ALIAS_STRIDE;

        expect_data_read(alias_addr_0, "l1 replacement fill way 0");
        expect_data_read(alias_addr_1, "l1 replacement fill way 1");

        reads_before = mem_read_handshake_count;
        expect_data_read(alias_addr_0, "l1 replacement update lru hit");
        reads_after = mem_read_handshake_count;
        if (reads_after != reads_before) begin
            $display("REPLACEMENT MISMATCH: expected alias 0 to hit before eviction");
            error_count = error_count + 1;
        end

        expect_data_read(alias_addr_2, "l1 replacement force eviction");
        reads_before = mem_read_handshake_count;
        expect_data_read(alias_addr_1, "l1 replacement evicted line refills");
        reads_after = mem_read_handshake_count;
        if (reads_after == reads_before) begin
            $display("REPLACEMENT MISMATCH: expected alias 1 to miss after LRU eviction");
            error_count = error_count + 1;
        end
    end
    endtask

    task check_illegal_maintenance_contract;
    begin
        wait_for_idle("illegal maintenance idle entry");

        apply_illegal_maintenance(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, {ADDR_WIDTH{1'b0}},
                                  "global flush plus invalidate");
        apply_illegal_maintenance(1'b0, 1'b0, 1'b1, 1'b1, 1'b1, {ADDR_WIDTH{1'b0}},
                                  "line flush plus invalidate");
        apply_illegal_maintenance(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, {ADDR_WIDTH{1'b0}},
                                  "global plus line maintenance");
        apply_illegal_maintenance(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, {ADDR_WIDTH{1'b0}},
                                  "line maintenance without address");

        wait_for_idle("illegal maintenance idle exit");
    end
    endtask

    task apply_illegal_maintenance;
        input flush_req;
        input invalidate_req;
        input flush_line_req;
        input invalidate_line_req;
        input addr_valid;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
    begin
        @(negedge clk);
        maint_flush_req = flush_req;
        maint_invalidate_req = invalidate_req;
        maint_flush_line_req = flush_line_req;
        maint_invalidate_line_req = invalidate_line_req;
        maint_addr_valid = addr_valid;
        maint_addr = addr;
        wait_for_maintenance_error(label);
        @(negedge clk);
        maint_flush_req = 1'b0;
        maint_invalidate_req = 1'b0;
        maint_flush_line_req = 1'b0;
        maint_invalidate_line_req = 1'b0;
        maint_addr_valid = 1'b0;
        maint_addr = {ADDR_WIDTH{1'b0}};
        wait_for_idle(label);
    end
    endtask

    task check_maintenance_contract;
    begin
        wait_for_idle("maintenance idle entry");

        @(negedge clk);
        maint_flush_req = 1'b1;
        wait_for_maintenance_success("global flush");
        @(negedge clk);
        maint_flush_req = 1'b0;

        @(negedge clk);
        maint_invalidate_req = 1'b1;
        wait_for_maintenance_success("global invalidate");
        @(negedge clk);
        maint_invalidate_req = 1'b0;
        wait_for_idle("maintenance idle exit");
    end
    endtask

    task check_line_maintenance_contract;
        integer reads_before;
        integer reads_after;
    begin
        wait_for_idle("line maintenance idle entry");

        reads_before = mem_read_handshake_count;
        expect_data_read(19'h00000, "line maintenance pre-hit line 0");
        reads_after = mem_read_handshake_count;
        if (reads_after != reads_before) begin
            $display("MAINT LINE MISMATCH: expected pre-hit without memory read, before=%0d after=%0d",
                     reads_before, reads_after);
            error_count = error_count + 1;
        end

        apply_line_invalidate(NEXT_LINE_ADDR, "line invalidate different line");
        reads_before = mem_read_handshake_count;
        expect_data_read(19'h00000, "line maintenance hit after other-line invalidate");
        reads_after = mem_read_handshake_count;
        if (reads_after != reads_before) begin
            $display("MAINT LINE MISMATCH: other-line invalidate evicted line 0, before=%0d after=%0d",
                     reads_before, reads_after);
            error_count = error_count + 1;
        end

        apply_line_flush(19'h00000, "line flush no-op");
        reads_before = mem_read_handshake_count;
        expect_data_read(19'h00000, "line maintenance hit after line flush");
        reads_after = mem_read_handshake_count;
        if (reads_after != reads_before) begin
            $display("MAINT LINE MISMATCH: line flush caused refill, before=%0d after=%0d",
                     reads_before, reads_after);
            error_count = error_count + 1;
        end

        apply_line_invalidate(19'h00000, "line invalidate line 0");
        reads_before = mem_read_handshake_count;
        expect_data_read(19'h00000, "line maintenance refill after line invalidate");
        reads_after = mem_read_handshake_count;
        if (reads_after == reads_before) begin
            $display("MAINT LINE MISMATCH: line invalidate did not force memory refill");
            error_count = error_count + 1;
        end
        wait_for_idle("line maintenance idle exit");
    end
    endtask

    task apply_line_flush;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
    begin
        wait_for_idle(label);
        @(negedge clk);
        maint_addr = addr;
        maint_addr_valid = 1'b1;
        maint_flush_line_req = 1'b1;
        wait_for_maintenance_success("line flush");
        @(negedge clk);
        maint_flush_line_req = 1'b0;
        maint_addr_valid = 1'b0;
        maint_addr = {ADDR_WIDTH{1'b0}};
        wait_for_idle(label);
    end
    endtask

    task apply_line_invalidate;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
    begin
        wait_for_idle(label);
        @(negedge clk);
        maint_addr = addr;
        maint_addr_valid = 1'b1;
        maint_invalidate_line_req = 1'b1;
        wait_for_maintenance_success("line invalidate");
        @(negedge clk);
        maint_invalidate_line_req = 1'b0;
        maint_addr_valid = 1'b0;
        maint_addr = {ADDR_WIDTH{1'b0}};
        wait_for_idle(label);
    end
    endtask

    task wait_for_maintenance_success;
        input [1023:0] label;
        integer timeout_count;
    begin
        timeout_count = 0;
        @(posedge clk);
        while (!maint_done && !maint_error) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: %0s maintenance did not complete", label);
                error_count = error_count + 1;
                disable wait_for_maintenance_success;
            end
        end
        if (!maint_ready || !maint_done || maint_error) begin
            $display("MAINT MISMATCH: %0s ready=%0b done=%0b error=%0b",
                     label, maint_ready, maint_done, maint_error);
            error_count = error_count + 1;
        end
    end
    endtask

    task wait_for_maintenance_error;
        input [1023:0] label;
        integer timeout_count;
    begin
        timeout_count = 0;
        @(posedge clk);
        while (!maint_done && !maint_error) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: %0s illegal maintenance did not complete", label);
                error_count = error_count + 1;
                disable wait_for_maintenance_error;
            end
        end
        if (!maint_ready || maint_done || !maint_error) begin
            $display("MAINT NEGATIVE MISMATCH: %0s ready=%0b done=%0b error=%0b",
                     label, maint_ready, maint_done, maint_error);
            error_count = error_count + 1;
        end
    end
    endtask

    task check_queued_maintenance_contract;
        integer reads_before;
        integer reads_after;
        integer timeout_count;
    begin
        wait_for_idle("queued maintenance idle entry");

        @(negedge clk);
        data_req_addr = NEXT_LINE_ADDR;
        data_req_write = 1'b0;
        data_req_valid = 1'b1;
        @(posedge clk);
        @(posedge clk);

        if (data_req_ready && !mem_req_valid) begin
            $display("MAINT QUEUED MISMATCH: expected data miss to block new requests");
            error_count = error_count + 1;
        end

        @(negedge clk);
        maint_addr = {ADDR_WIDTH{1'b0}};
        maint_addr_valid = 1'b1;
        maint_invalidate_line_req = 1'b1;
        @(posedge clk);
        @(negedge clk);
        maint_invalidate_line_req = 1'b0;
        maint_addr_valid = 1'b0;
        maint_addr = {ADDR_WIDTH{1'b0}};
        data_req_valid = 1'b0;

        timeout_count = 0;
        while (!maint_done && !maint_error) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: queued maintenance did not complete");
                error_count = error_count + 1;
                disable check_queued_maintenance_contract;
            end
        end

        if (maint_error) begin
            $display("MAINT QUEUED MISMATCH: queued line invalidate returned error");
            error_count = error_count + 1;
        end

        wait_for_idle("queued maintenance idle exit");
        reads_before = mem_read_handshake_count;
        expect_data_read({ADDR_WIDTH{1'b0}}, "queued maintenance refill after queued line invalidate");
        reads_after = mem_read_handshake_count;
        if (reads_after == reads_before) begin
            $display("MAINT QUEUED MISMATCH: queued line invalidate did not force refill");
            error_count = error_count + 1;
        end
    end
    endtask

    task initialize_reference_memory;
    begin
        for (reference_word_index = 0; reference_word_index < REF_WORDS; reference_word_index = reference_word_index + 1) begin
            reference_word_value = 32'h1000_0000 ^ reference_word_index;
            for (reference_byte_index = 0; reference_byte_index < 4; reference_byte_index = reference_byte_index + 1) begin
                reference_memory[(reference_word_index * 4) + reference_byte_index] =
                    reference_word_value[reference_byte_index*8 +: 8];
            end
        end
    end
    endtask

    task reset_dut;
    begin
        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (8) @(posedge clk);
    end
    endtask

    task apply_reset_pulse;
        input integer reset_cycles;
    begin
        @(negedge clk);
        rst = 1'b1;
        instr_req_valid = 1'b0;
        data_req_valid = 1'b0;
        data_req_write = 1'b0;
        maint_flush_req = 1'b0;
        maint_invalidate_req = 1'b0;
        maint_flush_line_req = 1'b0;
        maint_invalidate_line_req = 1'b0;
        maint_addr_valid = 1'b0;
        maint_addr = {ADDR_WIDTH{1'b0}};
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
        repeat (reset_cycles) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (8) @(posedge clk);
    end
    endtask

    task check_reset_contract;
    begin
        wait_for_idle("reset contract idle entry");

        @(negedge clk);
        data_req_addr = NEXT_LINE_ADDR + NEXT_LINE_ADDR;
        data_req_write = 1'b0;
        data_req_valid = 1'b1;
        @(posedge clk);
        @(posedge clk);
        if (!mem_req_valid && data_req_ready) begin
            $display("RESET MISMATCH: expected transaction before reset pulse");
            error_count = error_count + 1;
        end
        apply_reset_pulse(4);
        wait_for_idle("reset during transaction recovery");
        expect_data_read(NEXT_LINE_ADDR + NEXT_LINE_ADDR, "read after reset during transaction");

        apply_reset_pulse(2);
        apply_reset_pulse(3);
        apply_reset_pulse(1);
        wait_for_idle("repeated reset recovery");
        expect_instr_read(NEXT_LINE_ADDR + NEXT_LINE_ADDR + NEXT_LINE_ADDR, "instruction read after repeated reset");
    end
    endtask

    task wait_for_idle;
        input [1023:0] label;
        integer timeout_count;
    begin
        timeout_count = 0;
        repeat (2) @(posedge clk);
        while (mem_req_valid || mem_rd_rsp_valid || mem_wr_rsp_valid ||
               instr_rsp_valid || data_rsp_valid || !instr_req_ready || !data_req_ready) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: %0s did not become idle req=%0b rd=%0b wr=%0b irsp=%0b drsp=%0b iready=%0b dready=%0b",
                         label, mem_req_valid, mem_rd_rsp_valid, mem_wr_rsp_valid,
                         instr_rsp_valid, data_rsp_valid, instr_req_ready, data_req_ready);
                error_count = error_count + 1;
                disable wait_for_idle;
            end
        end
        repeat (2) @(posedge clk);
    end
    endtask

    task wait_for_read_response;
        input [1023:0] label;
        integer timeout_count;
    begin
        timeout_count = 0;
        repeat (2) @(posedge clk);
        while (!instr_rsp_valid && !data_rsp_valid) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
            if (timeout_count > 1000) begin
                $display("TIMEOUT: %0s read response did not complete", label);
                error_count = error_count + 1;
                disable wait_for_read_response;
            end
        end
        @(posedge clk);
    end
    endtask

    task expect_data_read;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
        reg [DATA_WIDTH-1:0] expected_data;
    begin
        expected_data = read_reference64(addr);

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
        if (data_rsp_error) begin
            $display("DATA ERROR MISMATCH: %0s returned unexpected error", label);
            error_count = error_count + 1;
        end
        compare_data(label, addr, expected_data, data_rsp_rdata);
        @(posedge clk);
        wait_for_idle(label);
    end
    endtask

    task expect_data_read_error;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
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
        if (!data_rsp_error || (data_rsp_rdata !== {DATA_WIDTH{1'b0}})) begin
            $display("DATA ERROR MISMATCH: %0s error=%0b data=%h",
                     label, data_rsp_error, data_rsp_rdata);
            error_count = error_count + 1;
        end
        @(posedge clk);
        wait_for_idle(label);
    end
    endtask

    task expect_instr_read;
        input [ADDR_WIDTH-1:0] addr;
        input [1023:0] label;
        reg [31:0] expected_instr;
    begin
        expected_instr = read_reference32(addr);

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
        if (instr_rsp_error) begin
            $display("INSTR ERROR MISMATCH: %0s returned unexpected error", label);
            error_count = error_count + 1;
        end
        compare_instr(label, addr, expected_instr, instr_rsp_data);
        @(posedge clk);
        wait_for_idle(label);
    end
    endtask

    task expect_instr_value;
        input [ADDR_WIDTH-1:0] addr;
        input [31:0] expected_instr;
        input [1023:0] label;
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
        compare_instr(label, addr, expected_instr, instr_rsp_data);
        @(posedge clk);
        wait_for_idle(label);
    end
    endtask

    task check_instruction_data_incoherency_contract;
        reg [31:0] stale_instr;
        reg [DATA_WIDTH-1:0] write_data;
        reg [(DATA_WIDTH/8)-1:0] write_strobe;
        reg [ADDR_WIDTH-1:0] test_addr;
    begin
        test_addr = NEXT_LINE_ADDR + NEXT_LINE_ADDR + NEXT_LINE_ADDR + NEXT_LINE_ADDR;
        stale_instr = read_reference32(test_addr);
        expect_instr_read(test_addr, "i/d coherency prime instruction line");

        write_data = {DATA_WIDTH{1'b0}};
        write_strobe = {(DATA_WIDTH/8){1'b0}};
        write_data[7:0] = stale_instr[7:0] ^ 8'h5a;
        write_strobe[0] = 1'b1;
        apply_data_write(test_addr, write_data, write_strobe, "i/d coherency data-side write");

        expect_instr_value(test_addr, stale_instr, "i/d coherency documented stale instruction hit");
        apply_line_invalidate(test_addr, "i/d coherency line invalidate recovery");
        expect_instr_read(test_addr, "i/d coherency instruction refill after invalidate");
    end
    endtask

    task expect_data_and_instr_read;
        input [ADDR_WIDTH-1:0] data_addr;
        input [ADDR_WIDTH-1:0] instr_addr;
        input [1023:0] label;
        reg [DATA_WIDTH-1:0] expected_data;
        reg [31:0] expected_instr;
    begin
        expected_data = read_reference64(data_addr);
        expected_instr = read_reference32(instr_addr);

        @(negedge clk);
        data_req_addr = data_addr;
        instr_req_addr = instr_addr;
        data_req_valid = 1'b1;
        data_req_write = 1'b0;
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
        compare_data(label, data_addr, expected_data, data_rsp_rdata);
        compare_instr(label, instr_addr, expected_instr, instr_rsp_data);
        @(posedge clk);
        wait_for_idle(label);
    end
    endtask

    task apply_data_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] write_data;
        input [(DATA_WIDTH/8)-1:0] write_strobe;
        input [1023:0] label;
    begin
        expected_write_burst_len = expected_write_burst_length(addr, write_strobe);
        expected_write_beat_index = 8'd0;
        write_burst_check_active = 1'b1;

        @(negedge clk);
        data_req_addr = addr;
        data_req_wdata = write_data;
        data_req_wstrb = write_strobe;
        data_req_write = 1'b1;
        data_req_valid = 1'b1;
        while (!data_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        data_req_valid = 1'b0;
        data_req_write = 1'b0;

        while (!data_rsp_valid) begin
            @(posedge clk);
        end
        if (data_rsp_error) begin
            $display("WRITE ERROR MISMATCH: %0s returned unexpected error", label);
            error_count = error_count + 1;
        end
        @(posedge clk);
        wait_for_idle(label);
        write_burst_check_active = 1'b0;
        update_reference_write(addr, write_data, write_strobe);
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
    end
    endtask

    task expect_data_write_error;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] write_data;
        input [(DATA_WIDTH/8)-1:0] write_strobe;
        input [1023:0] label;
    begin
        @(negedge clk);
        data_req_addr = addr;
        data_req_wdata = write_data;
        data_req_wstrb = write_strobe;
        data_req_write = 1'b1;
        data_req_valid = 1'b1;
        while (!data_req_ready) begin
            @(posedge clk);
        end
        @(negedge clk);
        data_req_valid = 1'b0;
        data_req_write = 1'b0;
        while (!data_rsp_valid) begin
            @(posedge clk);
        end
        if (!data_rsp_error) begin
            $display("WRITE ERROR MISMATCH: %0s did not return error", label);
            error_count = error_count + 1;
        end
        @(posedge clk);
        wait_for_idle(label);
        data_req_wstrb = {(DATA_WIDTH/8){1'b0}};
        data_req_wdata = {DATA_WIDTH{1'b0}};
    end
    endtask

    function [7:0] expected_write_burst_length;
        input [ADDR_WIDTH-1:0] addr;
        input [(DATA_WIDTH/8)-1:0] write_strobe;
        integer byte_lane;
        integer byte_offset;
        integer beat_candidate;
        reg [7:0] last_beat_index;
    begin
        last_beat_index = 8'd0;
        for (byte_lane = 0; byte_lane < (DATA_WIDTH / 8); byte_lane = byte_lane + 1) begin
            byte_offset = byte_lane + (({{(32-ADDR_WIDTH){1'b0}}, addr}) % (MEM_DATA_WIDTH / 8));
            beat_candidate = byte_offset / (MEM_DATA_WIDTH / 8);
            if (write_strobe[byte_lane] && (beat_candidate > {24'b0, last_beat_index})) begin
                last_beat_index = beat_candidate[7:0];
            end
        end
        expected_write_burst_length = last_beat_index + 8'd1;
    end
    endfunction

    task compare_data;
        input [1023:0] label;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] expected_data;
        input [DATA_WIDTH-1:0] actual_data;
    begin
        if ((^actual_data) === 1'bx) begin
            $display("DATA X: %0s addr=0x%05h actual=%016h", label, addr, actual_data);
            error_count = error_count + 1;
        end else if (actual_data !== expected_data) begin
            $display("DATA MISMATCH: %0s addr=0x%05h expected=%016h actual=%016h",
                     label, addr, expected_data, actual_data);
            error_count = error_count + 1;
        end
    end
    endtask

    task compare_instr;
        input [1023:0] label;
        input [ADDR_WIDTH-1:0] addr;
        input [31:0] expected_instr;
        input [31:0] actual_instr;
    begin
        if ((^actual_instr) === 1'bx) begin
            $display("INSTR X: %0s addr=0x%05h actual=%08h", label, addr, actual_instr);
            error_count = error_count + 1;
        end else if (actual_instr !== expected_instr) begin
            $display("INSTR MISMATCH: %0s addr=0x%05h expected=%08h actual=%08h",
                     label, addr, expected_instr, actual_instr);
            error_count = error_count + 1;
        end
    end
    endtask

    task update_reference_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] write_data;
        input [(DATA_WIDTH/8)-1:0] write_strobe;
        integer byte_lane;
        integer byte_addr;
    begin
        for (byte_lane = 0; byte_lane < (DATA_WIDTH / 8); byte_lane = byte_lane + 1) begin
            byte_addr = addr + byte_lane;
            if (write_strobe[byte_lane] && (byte_addr < REF_BYTES)) begin
                reference_memory[byte_addr] = write_data[byte_lane*8 +: 8];
            end
        end
    end
    endtask

    function [DATA_WIDTH-1:0] read_reference64;
        input [ADDR_WIDTH-1:0] addr;
        integer byte_lane;
        integer byte_addr;
    begin
        read_reference64 = {DATA_WIDTH{1'b0}};
        for (byte_lane = 0; byte_lane < (DATA_WIDTH / 8); byte_lane = byte_lane + 1) begin
            byte_addr = addr + byte_lane;
            if (byte_addr < REF_BYTES) begin
                read_reference64[byte_lane*8 +: 8] = reference_memory[byte_addr];
            end
        end
    end
    endfunction

    function [31:0] read_reference32;
        input [ADDR_WIDTH-1:0] addr;
        integer byte_lane;
        integer byte_addr;
    begin
        read_reference32 = 32'b0;
        for (byte_lane = 0; byte_lane < 4; byte_lane = byte_lane + 1) begin
            byte_addr = addr + byte_lane;
            if (byte_addr < REF_BYTES) begin
                read_reference32[byte_lane*8 +: 8] = reference_memory[byte_addr];
            end
        end
    end
    endfunction

endmodule
