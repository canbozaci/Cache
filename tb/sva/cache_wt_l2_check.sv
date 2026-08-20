// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Write-through coherence invariant: a store that updates an L1 way must also
// update L2's copy of the same line.
//
// This cache is write-through, and L2 is inclusive enough that a line evicted
// from L1 is refilled *from L2* rather than from memory. So if a store updates
// L1 and main memory but leaves L2 holding the old line, nothing is wrong until
// L1 happens to lose the line -- at which point L2, not memory, answers the
// refill and hands back the pre-store data. Main memory was correct the whole
// time and is never consulted, so the read reports zero memory reads.
//
// That is the observed failure this checks for. In the failing case the store
// wrote L1 way 1 and emitted both memory beats, and no L2 write to that line
// occurred anywhere in the window; fifteen microseconds later L1 missed, was
// refilled from L2, and returned the stale word.
//
// The trigger is L1's own write-enable rather than the controller's internal
// write_through_miss flag, deliberately. Keying off the flag would assume the
// flag is right, and "the flag was set even though L1 hit" is one of the two
// candidate causes. Keying off "an L1 way was actually written by a store"
// makes the check independent of why L2 was skipped.
//
// Fires at the end of the write-through pipeline -- microseconds to hundreds of
// accesses before the stale data is read, and on every occurrence rather than
// only the ones that happen to be read back before the line is evicted again.
//
// (A comment line here must never begin with the simulator's name: any comment
// whose first word is that name is parsed as a tool pragma and rejected.)
module cache_wt_l2_check (
    input logic clk,
    input logic rst_n
);
    import uvm_pkg::*;
    import cache_pkg::*;
`include "uvm_macros.svh"

    localparam int LINE_SHIFT = $clog2(LINE_WIDTH_P / 8);

    // A store into a resident L1 way: write_through asserted, not a fill
    // (write_L2 low), and one of the two way enables actually on.
    wire l1_store_write = l1d_write && l1d_wthru && !l1d_wl2 && (l1d_we1 || l1d_we2);

    // The L2 write the store is required to produce, for the same line.
    wire l2_line_write  = l2_write_p1 && (l2_we1_p1 || l2_we2_p1);

    logic                    wt_active;
    logic                    saw_l1_store;
    logic                    saw_l2_write;
    logic [ADDR_WIDTH_P-1:0] wt_line;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wt_active    <= 1'b0;
            saw_l1_store <= 1'b0;
            saw_l2_write <= 1'b0;
            wt_line      <= '0;
        end else if (l1d_wthru) begin
            if (!wt_active) begin
                wt_active    <= 1'b1;
                saw_l1_store <= l1_store_write;
                saw_l2_write <= 1'b0;
                wt_line      <= l1d_addr >> LINE_SHIFT;
            end else begin
                if (l1_store_write) saw_l1_store <= 1'b1;
                if (l2_line_write && (l2_addr_p1 == wt_line)) saw_l2_write <= 1'b1;
            end
        end else if (wt_active) begin
            wt_active <= 1'b0;
            if (saw_l1_store && !saw_l2_write)
                `uvm_error("WT_L2_STALE",
                           $sformatf("write-through updated an L1 way for line 0x%0h but never wrote L2. L2 keeps the pre-store data, and because a line evicted from L1 refills from L2 rather than memory, the next refill will resurrect it.",
                                     wt_line << LINE_SHIFT))
        end
    end

    wire [ADDR_WIDTH_P-1:0] l1d_addr  = tb_top.dut.cache_l1_data_inst.addr;
    wire                    l1d_write = tb_top.dut.cache_l1_data_inst.write;
    wire                    l1d_wl2   = tb_top.dut.cache_l1_data_inst.write_L2;
    wire                    l1d_wthru = tb_top.dut.cache_l1_data_inst.write_through;
    wire                    l1d_we1   = tb_top.dut.cache_l1_data_inst.we_set1;
    wire                    l1d_we2   = tb_top.dut.cache_l1_data_inst.we_set2;

    wire [ADDR_WIDTH_P-1:0] l2_addr_p1  = tb_top.dut.cache_l2_inst.addr_p1;
    wire                    l2_write_p1 = tb_top.dut.cache_l2_inst.write_p1;
    wire                    l2_we1_p1   = tb_top.dut.cache_l2_inst.we_set1_p1;
    wire                    l2_we2_p1   = tb_top.dut.cache_l2_inst.we_set2_p1;

endmodule
