// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Functional coverage for the cache, bound into the DUT from tb_top.
//
// These are SVA `cover property` statements rather than covergroups. That is a
// tool constraint, not a preference: the simulator this project's regression
// runs on implements SVA cover directives under --coverage-user, but does not
// implement SystemVerilog covergroups at all. The bins below are what a
// covergroup would have held, expressed in the facility that actually collects.
//
// (A comment line here must never begin with the simulator's name: any comment
// whose first word is that name is parsed as a tool pragma and rejected.)
//
// Every bin is phrased in interface-observable terms. The cache exposes no
// hit/miss signal, so "this line missed" is written as "a memory read burst
// opened", and "a store landed during a fill" as the coincidence of a CPU write
// with an open read burst. Bins that could only be written against internal
// state belong in the block-level environment, not here.
//
// Cover directives cost nothing in a normal build: without --coverage-user they
// are elaborated and discarded.
module cache_cov #(
    parameter int ADDR_WIDTH     = 19,
    parameter int DATA_WIDTH     = 64,
    parameter int MEM_DATA_WIDTH = 32,
    parameter int LINE_WIDTH     = 128
) (
    input logic                          clk,
    input logic                          rst_n,

    input logic                          instr_req_valid,
    input logic                          data_req_read,
    input logic                          data_req_write,
    input logic [(DATA_WIDTH/8)-1:0]     data_req_wstrb,

    input logic                          mem_req_valid,
    input logic                          mem_req_ready,
    input logic                          mem_req_write,
    input logic                          mem_req_burst,
    input logic [7:0]                    mem_req_burst_len,
    input logic                          mem_req_burst_start,
    input logic                          mem_req_burst_last,
    input logic [(MEM_DATA_WIDTH/8)-1:0] mem_req_wstrb,
    input logic                          mem_rsp_valid,

    input logic                          maint_flush_req,
    input logic                          maint_invalidate_req,
    input logic                          maint_flush_line_req,
    input logic                          maint_invalidate_line_req,
    input logic                          maint_ready,
    input logic                          maint_done,
    input logic                          maint_error,

    input logic                          busy
);

    localparam int DATA_BYTES = DATA_WIDTH / 8;

    // A read burst is in flight between its first and last accepted beat. Used
    // to express the collision bins below, which are the whole reason a long
    // random run is worth more than a longer directed one.
    logic read_burst_active;
    always_ff @(posedge clk) begin
        if (!rst_n)
            read_burst_active <= 1'b0;
        else if (mem_req_valid && mem_req_ready && !mem_req_write && mem_req_burst)
            read_burst_active <= !mem_req_burst_last;
    end

    // Set when the CPU write strobe has a gap in it, which is the case that
    // splits a write-through across memory beats non-contiguously.
    logic strobe_has_gap;
    always_comb begin
        automatic bit seen_one  = 1'b0;
        automatic bit seen_gap  = 1'b0;
        strobe_has_gap = 1'b0;
        for (int i = 0; i < DATA_BYTES; i++) begin
            if (data_req_wstrb[i]) begin
                if (seen_one && seen_gap) strobe_has_gap = 1'b1;
                seen_one = 1'b1;
            end else if (seen_one) begin
                seen_gap = 1'b1;
            end
        end
    end

    function automatic int unsigned popcount_strb(logic [DATA_BYTES-1:0] s);
        popcount_strb = 0;
        for (int i = 0; i < DATA_BYTES; i++) if (s[i]) popcount_strb++;
    endfunction

    // ---- memory request shapes ------------------------------------------
    c_read_burst:        cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_ready && !mem_req_write && mem_req_burst_start);
    c_write_single_beat: cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_ready && mem_req_write && (mem_req_burst_len == 8'd1));
    c_write_two_beats:   cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_ready && mem_req_write && (mem_req_burst_len == 8'd2));
    c_write_many_beats:  cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_ready && mem_req_write && (mem_req_burst_len > 8'd2));

    // A stalled request is the only way the ready/valid handshake is exercised
    // at all; without a stall the interface is effectively always-ready.
    c_req_stalled:       cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && !mem_req_ready);
    c_req_stalled_mid_burst: cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && !mem_req_ready && mem_req_burst && !mem_req_burst_start);

    // Back-to-back acceptance with no idle cycle between requests.
    //
    // Measured empty across 1840 read bursts and a 2000-access random soak: this
    // cache never accepts two beats in consecutive cycles, because it settles
    // internal state between beats. That is a throughput property rather than a
    // coverage hole, and the bin is kept precisely so the claim stays measured
    // instead of remembered — an adaptor sized on the assumption of a one-beat
    // gap would be relying on it.
    c_req_back_to_back:  cover property (@(posedge clk) disable iff (!rst_n)
        (mem_req_valid && mem_req_ready) ##1 (mem_req_valid && mem_req_ready));

    // ---- memory write strobe shapes -------------------------------------
    c_mem_wstrb_full:    cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_write && (mem_req_wstrb == '1));
    c_mem_wstrb_partial: cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_write && (mem_req_wstrb != '1) && (mem_req_wstrb != '0));

    // A write burst always opens at beat 0 but is only as long as its highest
    // strobed beat, so a store confined to an upper beat spends a bus cycle
    // writing nothing. Correct against any strobe-honouring memory, and
    // invisible to the scoreboard, but a bus without byte enables cannot
    // express it — so it is worth counting rather than assuming it never
    // happens. See docs/GAP_ANALYSIS.md.
    c_write_beat_no_strobe: cover property (@(posedge clk) disable iff (!rst_n)
        mem_req_valid && mem_req_ready && mem_req_write && (mem_req_wstrb == '0));

    // ---- CPU write strobe shapes ----------------------------------------
    c_cpu_wstrb_full:    cover property (@(posedge clk) disable iff (!rst_n)
        data_req_write && (data_req_wstrb == '1));
    c_cpu_wstrb_single:  cover property (@(posedge clk) disable iff (!rst_n)
        data_req_write && (popcount_strb(data_req_wstrb) == 1));
    c_cpu_wstrb_gapped:  cover property (@(posedge clk) disable iff (!rst_n)
        data_req_write && strobe_has_gap);

    // ---- port collisions -------------------------------------------------
    // The interactions a directed run of thirty accesses never produces.
    c_read_and_fetch:    cover property (@(posedge clk) disable iff (!rst_n)
        data_req_read && instr_req_valid);
    // No store-during-fill bin: a fill holds its requesting CPU port asserted
    // for its whole duration, so a data write overlapping one would be either a
    // read and a write on the data port at once, or the fetch-plus-write
    // combination the contract excludes. Both are assertion failures rather
    // than coverage holes, and a_no_fetch_with_write is what watches for them.
    c_fetch_during_fill: cover property (@(posedge clk) disable iff (!rst_n)
        instr_req_valid && read_burst_active);
    c_read_during_fill:  cover property (@(posedge clk) disable iff (!rst_n)
        data_req_read && read_burst_active);

    // ---- maintenance -----------------------------------------------------
    c_maint_global_flush_done: cover property (@(posedge clk) disable iff (!rst_n)
        maint_done && $past(maint_flush_req));
    c_maint_global_inv_done:   cover property (@(posedge clk) disable iff (!rst_n)
        maint_done && $past(maint_invalidate_req));
    c_maint_line_flush_done:   cover property (@(posedge clk) disable iff (!rst_n)
        maint_done && $past(maint_flush_line_req));
    c_maint_line_inv_done:     cover property (@(posedge clk) disable iff (!rst_n)
        maint_done && $past(maint_invalidate_line_req));
    c_maint_error:             cover property (@(posedge clk) disable iff (!rst_n)
        maint_error);

    // Maintenance accepted mid-traffic and held in the single queue entry.
    // This is the path the widened `busy` changed, so it needs a bin of its own.
    c_maint_queued_while_busy: cover property (@(posedge clk) disable iff (!rst_n)
        !maint_ready && busy);
    c_maint_queued_during_fill: cover property (@(posedge clk) disable iff (!rst_n)
        !maint_ready && read_burst_active);
    c_maint_retires_after_traffic: cover property (@(posedge clk) disable iff (!rst_n)
        (!maint_ready && busy) ##[1:$] (maint_done || maint_error));

    // ---- reset -----------------------------------------------------------
    //
    // The two mid-transfer bins below are currently unhit. Random traffic
    // resets between commands rather than inside one, and deliberately so: a
    // reset that lands mid-write-through drops a store the scoreboard has
    // already applied to its oracle, which would make every later read appear
    // wrong for a reason that is not a defect. Reaching them needs the oracle
    // to learn that a store was abandoned, which is real work rather than a
    // stimulus tweak. cache_reset_vseq covers reset mid-CPU-transaction, which
    // is the part that can be checked today.
    c_reset_while_busy:  cover property (@(posedge clk) !rst_n && $past(busy));
    c_reset_mid_burst:   cover property (@(posedge clk) !rst_n && $past(read_burst_active));
    c_reset_mid_write:   cover property (@(posedge clk) !rst_n && $past(mem_req_valid && mem_req_write));

endmodule
