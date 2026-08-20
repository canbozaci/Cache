// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Duplicate-tag invariant: no set may hold the same tag valid in both ways.
//
// This is a real cache invariant rather than a testbench convenience. Both L1
// and L2 here are two-way, and both resolve a two-way hit by preferring way 0
// (`cache_set_output_select` is asserted only for `hit_s2 & ~hit_s1`). So if a
// line is ever installed in both ways, way 0 answers every subsequent read and
// way 1 becomes unreachable — whatever it holds, however fresh, is invisible.
// A store that lands in way 1 is then silently lost, and stays lost until the
// set is evicted or invalidated.
//
// That failure is separated from its cause by however long it takes for the
// shadowed line to be read: in the case this was written for, 275 accesses.
// Checking the invariant directly collapses that gap to zero — it fires on the
// cycle the second copy becomes valid, which is the cycle that contains the bug.
//
// Only the set currently being addressed is examined, not the whole array. A
// duplicate can only be created by a tag write, and a tag write only touches
// the set it addresses, so watching the addressed index catches every creation
// while keeping the check O(1) per cycle. Scanning all sets every cycle costs
// roughly two orders of magnitude more in a soak run and finds nothing extra.
//
// The references below are hierarchical into the DUT. That is deliberate: this
// is an internal structural invariant with no interface expression, which is
// exactly why the interface-level checks in cache_sva.sv cannot see it.
//
// (A comment line here must never begin with the simulator's name: any comment
// whose first word is that name is parsed as a tool pragma and rejected.)
module cache_dup_tag_check (
    input logic clk,
    input logic rst_n
);
    import uvm_pkg::*;
`include "uvm_macros.svh"

    // The valid bit is the top bit of each tag/valid word; the tag is the rest.
    // Widths are taken from the arrays themselves so this tracks the geometry
    // sweep without a parameter of its own.
    localparam int L1D_W = $bits(tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.mem[0]);
    localparam int L1I_W = $bits(tb_top.dut.cache_l1_instr_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.mem[0]);
    localparam int L2_W  = $bits(tb_top.dut.cache_l2_inst.cache_l2_memory_way_0.cache_l2_memory_tag_valid_array_inst.ram_block[0]);

    int unsigned dup_count = 0;

    // One report per level per set, so a duplicate that persists for thousands
    // of cycles does not bury the rest of the log. The first occurrence is the
    // one that matters; later ones are the same fault still standing.
    bit l1d_reported [int];
    bit l1i_reported [int];
    bit l2_reported  [int];

    function automatic void check_pair(
        input string        level,
        input int unsigned  idx,
        input logic         v0,
        input logic         v1,
        input logic [63:0]  t0,
        input logic [63:0]  t1,
        ref   bit           reported [int]
    );
        if (v0 && v1 && (t0 == t1)) begin
            if (!reported.exists(int'(idx))) begin
                reported[int'(idx)] = 1'b1;
                dup_count++;
                `uvm_error("DUP_TAG",
                           $sformatf("%0s set %0d holds tag 0x%0h valid in BOTH ways. Way 0 wins every hit, so way 1 is now unreachable and any store that lands in it is lost.",
                                     level, idx, t0))
            end
        end
    endfunction

    // Sampled after the nonblocking updates of the arrays have settled, so a
    // duplicate created this cycle is seen this cycle rather than the next.
    always @(posedge clk) begin
        if (rst_n) begin
            automatic int unsigned i1d = tb_top.dut.cache_l1_data_inst.idx_input;
            automatic int unsigned i1i = tb_top.dut.cache_l1_instr_inst.idx_input;
            automatic int unsigned i2a = tb_top.dut.cache_l2_inst.idx_input_p1;
            automatic int unsigned i2b = tb_top.dut.cache_l2_inst.idx_input_p2;

            automatic logic [L1D_W-1:0] d0 = tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.mem[i1d];
            automatic logic [L1D_W-1:0] d1 = tb_top.dut.cache_l1_data_inst.cache_set_1.cache_l1_memory_tag_valid_array_inst.mem[i1d];
            automatic logic [L1I_W-1:0] f0 = tb_top.dut.cache_l1_instr_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.mem[i1i];
            automatic logic [L1I_W-1:0] f1 = tb_top.dut.cache_l1_instr_inst.cache_set_1.cache_l1_memory_tag_valid_array_inst.mem[i1i];
            automatic logic [L2_W-1:0]  a0 = tb_top.dut.cache_l2_inst.cache_l2_memory_way_0.cache_l2_memory_tag_valid_array_inst.ram_block[i2a];
            automatic logic [L2_W-1:0]  a1 = tb_top.dut.cache_l2_inst.cache_l2_memory_way_1.cache_l2_memory_tag_valid_array_inst.ram_block[i2a];
            automatic logic [L2_W-1:0]  b0 = tb_top.dut.cache_l2_inst.cache_l2_memory_way_0.cache_l2_memory_tag_valid_array_inst.ram_block[i2b];
            automatic logic [L2_W-1:0]  b1 = tb_top.dut.cache_l2_inst.cache_l2_memory_way_1.cache_l2_memory_tag_valid_array_inst.ram_block[i2b];

            check_pair("L1-data",  i1d, d0[L1D_W-1], d1[L1D_W-1],
                       64'(d0[L1D_W-2:0]), 64'(d1[L1D_W-2:0]), l1d_reported);
            check_pair("L1-instr", i1i, f0[L1I_W-1], f1[L1I_W-1],
                       64'(f0[L1I_W-2:0]), 64'(f1[L1I_W-2:0]), l1i_reported);
            check_pair("L2(p1)",   i2a, a0[L2_W-1],  a1[L2_W-1],
                       64'(a0[L2_W-2:0]),  64'(a1[L2_W-2:0]),  l2_reported);
            check_pair("L2(p2)",   i2b, b0[L2_W-1],  b1[L2_W-1],
                       64'(b0[L2_W-2:0]),  64'(b1[L2_W-2:0]),  l2_reported);
        end
    end

    final begin
        if (dup_count != 0)
            $display("DUP_TAG SUMMARY: %0d distinct duplicated set(s) observed", dup_count);
        else
            $display("DUP_TAG SUMMARY: no duplicate tags observed");
    end

endmodule
