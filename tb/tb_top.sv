// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`timescale 1ns / 1ps

module tb_top;
    import uvm_pkg::*;
    import cache_pkg::*;

    // Same 80 MHz clock the legacy testbench used, so cycle-count-based
    // expectations carry over unchanged.
    logic clk = 1'b1;
    always #6.25 clk = ~clk;

    cache_if #(
        .ADDR_WIDTH(ADDR_WIDTH_P),
        .DATA_WIDTH(DATA_WIDTH_P),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH_P)
    ) vif (.clk(clk));

    cache #(
        .ADDR_WIDTH(ADDR_WIDTH_P),
        .DATA_WIDTH(DATA_WIDTH_P),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH_P),
        .LINE_WIDTH(LINE_WIDTH_P),
        .L1_SET_COUNT(L1_SET_COUNT_P),
        .L1_DATA_SET_COUNT(L1_DATA_SET_COUNT_P),
        .L1_INSTR_SET_COUNT(L1_INSTR_SET_COUNT_P),
        .L2_SET_COUNT(L2_SET_COUNT_P)
    ) dut (
        .clk                      (clk),
        .rst_n                    (vif.rst_n),
        .instr_req_valid          (vif.instr_req_valid),
        .instr_req_addr           (vif.instr_req_addr),
        .instr_resp_data          (vif.instr_resp_data),
        .data_req_read            (vif.data_req_read),
        .data_req_write           (vif.data_req_write),
        .data_req_addr            (vif.data_req_addr),
        .data_req_wdata           (vif.data_req_wdata),
        .data_req_wstrb           (vif.data_req_wstrb),
        .data_resp_rdata          (vif.data_resp_rdata),
        .mem_req_valid            (vif.mem_req_valid),
        .mem_req_ready            (vif.mem_req_ready),
        .mem_req_write            (vif.mem_req_write),
        .mem_req_burst            (vif.mem_req_burst),
        .mem_req_burst_len        (vif.mem_req_burst_len),
        .mem_req_beat_index       (vif.mem_req_beat_index),
        .mem_req_burst_start      (vif.mem_req_burst_start),
        .mem_req_burst_last       (vif.mem_req_burst_last),
        .mem_req_addr             (vif.mem_req_addr),
        .mem_req_wdata            (vif.mem_req_wdata),
        .mem_req_wstrb            (vif.mem_req_wstrb),
        .mem_rsp_valid            (vif.mem_rsp_valid),
        .mem_rsp_ready            (vif.mem_rsp_ready),
        .mem_rsp_rdata            (vif.mem_rsp_rdata),
        .maint_flush_req          (vif.maint_flush_req),
        .maint_invalidate_req     (vif.maint_invalidate_req),
        .maint_flush_line_req     (vif.maint_flush_line_req),
        .maint_invalidate_line_req(vif.maint_invalidate_line_req),
        .maint_addr_valid         (vif.maint_addr_valid),
        .maint_addr               (vif.maint_addr),
        .maint_ready              (vif.maint_ready),
        .maint_done               (vif.maint_done),
        .maint_error              (vif.maint_error),
        .busy                     (vif.busy)
    );

    // Protocol assertions and functional coverage. They live outside the DUT so
    // the deliverable RTL carries no testbench-only code, and they watch the
    // interface rather than the DUT's internals — every rule they enforce is
    // stated in docs/TIMING_CONTRACT.md in terms of these pins.
    //
    // Instantiated here rather than `bind`-ed into the cache. A bind would be
    // the more usual idiom, but binding a module that imports uvm_pkg makes
    // the simulator re-elaborate the UVM package inside every parameterized
    // submodule of the DUT and abort with an internal error (checked against
    // 5.050). Since all the checked signals are interface signals, an ordinary
    // instance connected to the same wires checks exactly the same thing.
    cache_sva #(
        .ADDR_WIDTH(ADDR_WIDTH_P),
        .DATA_WIDTH(DATA_WIDTH_P),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH_P),
        .LINE_WIDTH(LINE_WIDTH_P)
    ) u_cache_sva (
        .clk(clk), .rst_n(vif.rst_n),
        .instr_req_valid(vif.instr_req_valid), .instr_req_addr(vif.instr_req_addr),
        .data_req_read(vif.data_req_read), .data_req_write(vif.data_req_write),
        .data_req_addr(vif.data_req_addr), .data_req_wdata(vif.data_req_wdata),
        .data_req_wstrb(vif.data_req_wstrb),
        .mem_req_valid(vif.mem_req_valid), .mem_req_ready(vif.mem_req_ready),
        .mem_req_write(vif.mem_req_write), .mem_req_burst(vif.mem_req_burst),
        .mem_req_burst_len(vif.mem_req_burst_len), .mem_req_beat_index(vif.mem_req_beat_index),
        .mem_req_burst_start(vif.mem_req_burst_start), .mem_req_burst_last(vif.mem_req_burst_last),
        .mem_req_addr(vif.mem_req_addr), .mem_req_wdata(vif.mem_req_wdata),
        .mem_req_wstrb(vif.mem_req_wstrb), .mem_rsp_valid(vif.mem_rsp_valid),
        .maint_flush_req(vif.maint_flush_req), .maint_invalidate_req(vif.maint_invalidate_req),
        .maint_flush_line_req(vif.maint_flush_line_req),
        .maint_invalidate_line_req(vif.maint_invalidate_line_req),
        .maint_addr_valid(vif.maint_addr_valid), .maint_ready(vif.maint_ready),
        .maint_done(vif.maint_done), .maint_error(vif.maint_error),
        .busy(vif.busy)
    );

    cache_cov #(
        .ADDR_WIDTH(ADDR_WIDTH_P),
        .DATA_WIDTH(DATA_WIDTH_P),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH_P),
        .LINE_WIDTH(LINE_WIDTH_P)
    ) u_cache_cov (
        .clk(clk), .rst_n(vif.rst_n),
        .instr_req_valid(vif.instr_req_valid),
        .data_req_read(vif.data_req_read), .data_req_write(vif.data_req_write),
        .data_req_wstrb(vif.data_req_wstrb),
        .mem_req_valid(vif.mem_req_valid), .mem_req_ready(vif.mem_req_ready),
        .mem_req_write(vif.mem_req_write), .mem_req_burst(vif.mem_req_burst),
        .mem_req_burst_len(vif.mem_req_burst_len),
        .mem_req_burst_start(vif.mem_req_burst_start), .mem_req_burst_last(vif.mem_req_burst_last),
        .mem_req_wstrb(vif.mem_req_wstrb), .mem_rsp_valid(vif.mem_rsp_valid),
        .maint_flush_req(vif.maint_flush_req), .maint_invalidate_req(vif.maint_invalidate_req),
        .maint_flush_line_req(vif.maint_flush_line_req),
        .maint_invalidate_line_req(vif.maint_invalidate_line_req),
        .maint_ready(vif.maint_ready),
        .maint_done(vif.maint_done), .maint_error(vif.maint_error),
        .busy(vif.busy)
    );

    // Structural invariant on the tag arrays. Unlike the two above it reaches
    // into the DUT, because "the same line is resident in two ways" has no
    // expression at the interface — which is precisely why it can go unnoticed
    // for hundreds of accesses before a read finally lands on the stale copy.
    cache_dup_tag_check u_cache_dup_tag_check (
        .clk(clk), .rst_n(vif.rst_n)
    );

    // Write-through must keep L2 in step with L1. See the module header: this
    // is the invariant the access-99385 failure violates, and it fires at the
    // store rather than at the read that eventually sees the stale line.
    cache_wt_l2_check u_cache_wt_l2_check (
        .clk(clk), .rst_n(vif.rst_n)
    );

    // Temporary debug instrument for the lost store at access 99385. Inert
    // unless +PROBE_LINE=<addr> is given, so it costs nothing in a normal run.
    cache_store_probe u_cache_store_probe (
        .clk(clk), .rst_n(vif.rst_n)
    );

    // Power-on reset. Mid-test resets are driven by cache_base_vseq, which owns
    // reset as a testbench-wide event rather than a per-agent command.
    initial begin
        vif.rst_n = 1'b0;
        repeat (8) @(posedge clk);
        vif.rst_n = 1'b1;
    end

    initial begin
        if ($test$plusargs("DUMP")) begin
            $dumpfile("sim/build/waves.fst");
            $dumpvars(0, tb_top);
        end
    end

    // Safety net so a stuck testbench fails the regression instead of hanging
    // it. Five milliseconds covers the directed suite many times over, but a
    // random soak of a few thousand accesses runs longer than that, so the
    // budget is a plusarg rather than a constant. Timescale is 1ns, so the
    // multiplier below converts milliseconds to time units.
    initial begin
        static int unsigned watchdog_ms = 5;
        void'($value$plusargs("WATCHDOG_MS=%d", watchdog_ms));
        #(watchdog_ms * 1_000_000);
        `uvm_fatal("TIMEOUT",
                   $sformatf("simulation exceeded %0dms watchdog", watchdog_ms))
    end

    initial begin
        uvm_config_db#(cache_vif_t)::set(null, "*", "vif", vif);
        run_test("cache_full_test");
    end

endmodule
