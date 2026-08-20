// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Protocol assertions for the cache, bound into the DUT from tb_top.
//
// These encode the rules in docs/TIMING_CONTRACT.md as checks that fire at the
// cycle and signal that broke them, rather than as a data mismatch several
// sequences later. That distinction is the reason this file exists: the
// write-through defect this IP shipped with was a `busy` that dropped while a
// memory write beat was still in flight, and it surfaced only as a wrong read
// value long afterwards. `p_mem_req_implies_busy` below is one line and would
// have named it immediately.
//
// Failures are reported through the UVM report server, not through `$error`, so
// an assertion failure counts as a UVM_ERROR and suppresses the pass banner the
// regression scripts key off. A bare `$error` would leave the run "passing".
//
// The checker deliberately holds the CPU-side contract as well as the DUT's own
// outputs. Several rules here — hold the write payload until `busy` falls, never
// present a fetch alongside a data write — are obligations on whatever drives
// the cache. An adaptor that breaks them gets undefined behaviour from the RTL,
// so leaving them unchecked would mean the testbench is the only thing keeping
// itself honest.
module cache_sva #(
    parameter int ADDR_WIDTH     = 19,
    parameter int DATA_WIDTH     = 64,
    parameter int MEM_DATA_WIDTH = 32,
    parameter int LINE_WIDTH     = 128
) (
    input logic                          clk,
    input logic                          rst_n,

    input logic                          instr_req_valid,
    input logic [ADDR_WIDTH-1:0]         instr_req_addr,

    input logic                          data_req_read,
    input logic                          data_req_write,
    input logic [ADDR_WIDTH-1:0]         data_req_addr,
    input logic [DATA_WIDTH-1:0]         data_req_wdata,
    input logic [(DATA_WIDTH/8)-1:0]     data_req_wstrb,

    input logic                          mem_req_valid,
    input logic                          mem_req_ready,
    input logic                          mem_req_write,
    input logic                          mem_req_burst,
    input logic [7:0]                    mem_req_burst_len,
    input logic [7:0]                    mem_req_beat_index,
    input logic                          mem_req_burst_start,
    input logic                          mem_req_burst_last,
    input logic [31:0]                   mem_req_addr,
    input logic [MEM_DATA_WIDTH-1:0]     mem_req_wdata,
    input logic [(MEM_DATA_WIDTH/8)-1:0] mem_req_wstrb,
    input logic                          mem_rsp_valid,

    input logic                          maint_flush_req,
    input logic                          maint_invalidate_req,
    input logic                          maint_flush_line_req,
    input logic                          maint_invalidate_line_req,
    input logic                          maint_addr_valid,
    input logic                          maint_ready,
    input logic                          maint_done,
    input logic                          maint_error,

    input logic                          busy
);

    import uvm_pkg::*;
`include "uvm_macros.svh"

    localparam int LINE_MEM_BEATS = LINE_WIDTH / MEM_DATA_WIDTH;

    // ---------------------------------------------------------------------
    // Memory request contract
    // ---------------------------------------------------------------------

    // The one that matters most. `busy` is the only completion signal this IP
    // exposes, and the memory-side request fields are combinational functions
    // of the live CPU inputs. If a request is on the bus while `busy` is low,
    // the CPU adaptor is entitled to have already moved on, and whatever the
    // beat carries is whatever happened to be left on the CPU port.
    property p_mem_req_implies_busy;
        @(posedge clk) disable iff (!rst_n) mem_req_valid |-> busy;
    endproperty
    a_mem_req_implies_busy: assert property (p_mem_req_implies_busy)
        else `uvm_error("SVA_REQ_NOT_BUSY",
             $sformatf("memory request on the bus with busy low (write=%0b addr=0x%0h wstrb=0x%0h)",
                       mem_req_write, mem_req_addr, mem_req_wstrb))

    // A read response belongs to a fill, and a fill is cache work in progress.
    property p_mem_rsp_implies_busy;
        @(posedge clk) disable iff (!rst_n) mem_rsp_valid |-> busy;
    endproperty
    a_mem_rsp_implies_busy: assert property (p_mem_rsp_implies_busy)
        else `uvm_error("SVA_RSP_NOT_BUSY", "memory read response accepted with busy low")

    // A write burst must actually write something. This is checked on the final
    // beat rather than on every beat, and the distinction is the contract:
    // `burst_len` is defined by the *highest* strobed beat while the burst
    // always starts at beat 0, so a store whose enabled bytes land only in an
    // upper memory beat legitimately emits leading beats with no strobe. The
    // last beat, by that same definition, always carries one.
    //
    // Checking every beat instead would be stricter than the RTL contract, and
    // was: it reported 25 failures per 200 random accesses against correct
    // hardware. It still catches the lost-store defect, because that collapsed
    // the strobes on *all* beats including the last.
    property p_write_burst_writes_something;
        @(posedge clk) disable iff (!rst_n)
            (mem_req_valid && mem_req_write && (!mem_req_burst || mem_req_burst_last))
                |-> (mem_req_wstrb != '0);
    endproperty
    a_write_burst_writes_something: assert property (p_write_burst_writes_something)
        else `uvm_error("SVA_WRITE_NO_STROBE",
             $sformatf("memory write burst ending at 0x%0h wrote no byte", mem_req_addr))

    // Ready/valid: an unaccepted request must hold every field until it is
    // taken, and must not be withdrawn.
    property p_req_stable_while_stalled;
        @(posedge clk) disable iff (!rst_n)
            (mem_req_valid && !mem_req_ready) |=>
                (mem_req_valid &&
                 (mem_req_addr        == $past(mem_req_addr))        &&
                 (mem_req_write       == $past(mem_req_write))       &&
                 (mem_req_wdata       == $past(mem_req_wdata))       &&
                 (mem_req_wstrb       == $past(mem_req_wstrb))       &&
                 (mem_req_burst       == $past(mem_req_burst))       &&
                 (mem_req_burst_len   == $past(mem_req_burst_len))   &&
                 (mem_req_beat_index  == $past(mem_req_beat_index)));
    endproperty
    a_req_stable_while_stalled: assert property (p_req_stable_while_stalled)
        else `uvm_error("SVA_REQ_UNSTABLE",
             "stalled memory request changed or was withdrawn before it was accepted")

    // Burst metadata has to describe the burst it is part of, or a bus adaptor
    // cannot translate it into AXI/AHB at all.
    property p_beat_index_in_range;
        @(posedge clk) disable iff (!rst_n)
            (mem_req_valid && mem_req_burst) |-> (mem_req_beat_index < mem_req_burst_len);
    endproperty
    a_beat_index_in_range: assert property (p_beat_index_in_range)
        else `uvm_error("SVA_BEAT_RANGE",
             $sformatf("beat index %0d outside burst of length %0d",
                       mem_req_beat_index, mem_req_burst_len))

    property p_burst_start_consistent;
        @(posedge clk) disable iff (!rst_n)
            (mem_req_valid && mem_req_burst) |->
                (mem_req_burst_start == (mem_req_beat_index == 8'd0));
    endproperty
    a_burst_start_consistent: assert property (p_burst_start_consistent)
        else `uvm_error("SVA_BURST_START",
             $sformatf("burst_start=%0b at beat %0d", mem_req_burst_start, mem_req_beat_index))

    property p_burst_last_consistent;
        @(posedge clk) disable iff (!rst_n)
            (mem_req_valid && mem_req_burst) |->
                (mem_req_burst_last == (mem_req_beat_index == (mem_req_burst_len - 8'd1)));
    endproperty
    a_burst_last_consistent: assert property (p_burst_last_consistent)
        else `uvm_error("SVA_BURST_LAST",
             $sformatf("burst_last=%0b at beat %0d of %0d",
                       mem_req_burst_last, mem_req_beat_index, mem_req_burst_len))

    // A read burst fills exactly one line, so its length is fixed by geometry.
    property p_read_burst_len;
        @(posedge clk) disable iff (!rst_n)
            (mem_req_valid && mem_req_burst && !mem_req_write) |->
                (mem_req_burst_len == 8'(LINE_MEM_BEATS));
    endproperty
    a_read_burst_len: assert property (p_read_burst_len)
        else `uvm_error("SVA_READ_BURST_LEN",
             $sformatf("read burst length %0d, expected %0d",
                       mem_req_burst_len, LINE_MEM_BEATS))

    // ---------------------------------------------------------------------
    // CPU-side contract
    // ---------------------------------------------------------------------

    property p_no_read_and_write;
        @(posedge clk) disable iff (!rst_n) !(data_req_read && data_req_write);
    endproperty
    a_no_read_and_write: assert property (p_no_read_and_write)
        else `uvm_error("SVA_RW_BOTH", "data port asserted read and write in the same cycle")

    // docs/TIMING_CONTRACT.md lists "Fetch + Write" as not release-supported,
    // because the two L1s are not coherent after a data-side write. Nothing in
    // the RTL rejects it, so without this the rule is a sentence in a document
    // and an adaptor that breaks it just gets a wrong answer.
    property p_no_fetch_with_write;
        @(posedge clk) disable iff (!rst_n) !(instr_req_valid && data_req_write);
    endproperty
    a_no_fetch_with_write: assert property (p_no_fetch_with_write)
        else `uvm_error("SVA_FETCH_WITH_WRITE",
             "instruction fetch presented with a data write; that combination is not release-supported")

    // A line maintenance request without an address is illegal by contract, and
    // the DUT must call it out rather than act on a stale address register.
    property p_line_maint_needs_addr;
        @(posedge clk) disable iff (!rst_n)
            ((maint_flush_line_req || maint_invalidate_line_req) && !maint_addr_valid && maint_ready)
                |=> ##[0:$] (maint_error || !rst_n);
    endproperty
    a_line_maint_needs_addr: assert property (p_line_maint_needs_addr)
        else `uvm_error("SVA_MAINT_NO_ADDR",
             "line maintenance without maint_addr_valid did not retire as an error")

    // ---------------------------------------------------------------------
    // Maintenance contract
    // ---------------------------------------------------------------------

    property p_maint_done_error_exclusive;
        @(posedge clk) disable iff (!rst_n) !(maint_done && maint_error);
    endproperty
    a_maint_done_error_exclusive: assert property (p_maint_done_error_exclusive)
        else `uvm_error("SVA_MAINT_BOTH", "maint_done and maint_error asserted together")

    // Both are specified as one-cycle pulses; a level would make a second
    // command indistinguishable from the first still completing.
    property p_maint_done_is_pulse;
        @(posedge clk) disable iff (!rst_n) maint_done |=> !maint_done;
    endproperty
    a_maint_done_is_pulse: assert property (p_maint_done_is_pulse)
        else `uvm_error("SVA_MAINT_DONE_LEVEL", "maint_done held for more than one cycle")

    property p_maint_error_is_pulse;
        @(posedge clk) disable iff (!rst_n) maint_error |=> !maint_error;
    endproperty
    a_maint_error_is_pulse: assert property (p_maint_error_is_pulse)
        else `uvm_error("SVA_MAINT_ERROR_LEVEL", "maint_error held for more than one cycle")

    // "busy remains high while a maintenance command is queued or executing" —
    // a queued command is exactly the window in which maint_ready is low.
    property p_maint_queued_implies_busy;
        @(posedge clk) disable iff (!rst_n) !maint_ready |-> busy;
    endproperty
    a_maint_queued_implies_busy: assert property (p_maint_queued_implies_busy)
        else `uvm_error("SVA_MAINT_NOT_BUSY", "maintenance command queued but busy is low")

    // ---------------------------------------------------------------------
    // Reset
    // ---------------------------------------------------------------------

    property p_reset_clears_mem_req;
        @(posedge clk) !rst_n |=> !mem_req_valid;
    endproperty
    a_reset_clears_mem_req: assert property (p_reset_clears_mem_req)
        else `uvm_error("SVA_RESET_REQ", "memory request still asserted a cycle after reset")

    property p_reset_clears_maint;
        @(posedge clk) !rst_n |=> (!maint_done && !maint_error);
    endproperty
    a_reset_clears_maint: assert property (p_reset_clears_maint)
        else `uvm_error("SVA_RESET_MAINT", "maintenance status still asserted a cycle after reset")

    // ---------------------------------------------------------------------
    // Stateful checks
    //
    // These track history across an indefinite number of cycles, which a
    // property built from `$past` cannot express without knowing the bound in
    // advance. They are written as immediate assertions inside a clocked block,
    // which is the same SVA facility applied where it fits better.
    // ---------------------------------------------------------------------

    // The CPU must hold a write's address, data and strobes stable from the
    // cycle the command is presented until `busy` falls, because the cache
    // samples all three combinationally right up to the memory write beat. This
    // is the obligation the RTL defect made unsatisfiable — `busy` used to fall
    // first — so it is checked from both directions: here, and by
    // p_mem_req_implies_busy above.
    logic                      wr_tracking;
    logic [ADDR_WIDTH-1:0]     wr_addr_held;
    logic [DATA_WIDTH-1:0]     wr_wdata_held;
    logic [(DATA_WIDTH/8)-1:0] wr_wstrb_held;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_tracking <= 1'b0;
        end else if (wr_tracking) begin
            a_write_payload_held: assert ((data_req_addr  == wr_addr_held)  &&
                                          (data_req_wdata == wr_wdata_held) &&
                                          (data_req_wstrb == wr_wstrb_held))
                else `uvm_error("SVA_WRITE_PAYLOAD_MOVED",
                     $sformatf("write payload changed while busy was still high (addr 0x%0h->0x%0h, wstrb 0x%0h->0x%0h)",
                               wr_addr_held, data_req_addr, wr_wstrb_held, data_req_wstrb))
            if (!busy) wr_tracking <= 1'b0;
        end else if (data_req_write) begin
            wr_tracking   <= 1'b1;
            wr_addr_held  <= data_req_addr;
            wr_wdata_held <= data_req_wdata;
            wr_wstrb_held <= data_req_wstrb;
        end
    end

    // A read command must likewise hold its address until the response is
    // valid, which is the same `busy` window.
    logic                  rd_tracking;
    logic [ADDR_WIDTH-1:0] rd_addr_held;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_tracking <= 1'b0;
        end else if (rd_tracking) begin
            if (data_req_read) begin
                a_read_addr_held: assert (data_req_addr == rd_addr_held)
                    else `uvm_error("SVA_READ_ADDR_MOVED",
                         $sformatf("read address changed from 0x%0h to 0x%0h while busy",
                                   rd_addr_held, data_req_addr))
            end
            if (!busy) rd_tracking <= 1'b0;
        end else if (data_req_read) begin
            rd_tracking  <= 1'b1;
            rd_addr_held <= data_req_addr;
        end
    end

    // Beat indices inside a burst must ascend by one per accepted beat. Bursts
    // are interrupted by ready-stalls and by the cache pausing between beats,
    // so this cannot be phrased as a same-cycle relation.
    logic [7:0] next_read_beat;
    logic       read_burst_open;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            read_burst_open <= 1'b0;
            next_read_beat  <= 8'd0;
        end else if (mem_req_valid && mem_req_ready && mem_req_burst && !mem_req_write) begin
            if (!read_burst_open) begin
                a_read_burst_starts_at_zero: assert (mem_req_beat_index == 8'd0)
                    else `uvm_error("SVA_BURST_FIRST_BEAT",
                         $sformatf("read burst opened at beat %0d", mem_req_beat_index))
            end else begin
                a_read_beat_ascends: assert (mem_req_beat_index == next_read_beat)
                    else `uvm_error("SVA_BEAT_ORDER",
                         $sformatf("read beat %0d out of order, expected %0d",
                                   mem_req_beat_index, next_read_beat))
            end
            read_burst_open <= !mem_req_burst_last;
            next_read_beat  <= mem_req_beat_index + 8'd1;
        end
    end

    // The cache must never receive more read responses than it asked for.
    // Overrun here would mean the response the scoreboard checks belongs to a
    // different request than the one it thinks it does.
    int unsigned outstanding_reads;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            outstanding_reads <= 0;
        end else begin
            automatic int unsigned accepted =
                (mem_req_valid && mem_req_ready && !mem_req_write) ? 1 : 0;
            if (mem_rsp_valid) begin
                a_no_unsolicited_response: assert ((outstanding_reads + accepted) > 0)
                    else `uvm_error("SVA_RSP_UNSOLICITED",
                                    "memory read response with no outstanding read request")
                outstanding_reads <= (outstanding_reads + accepted) -
                                     (((outstanding_reads + accepted) > 0) ? 1 : 0);
            end else begin
                outstanding_reads <= outstanding_reads + accepted;
            end
        end
    end

endmodule
