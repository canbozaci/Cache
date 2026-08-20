// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Temporary probe: everything that touches one cache line, in order.
//
// Written for a lost store. A full-width CPU write to a resident line
// completed as a hit, emitted no memory reads, and left no trace anywhere:
// the following read of the same address returned the value from a store 275
// accesses earlier, and a read of the other word of the same line, made in
// between, was correct. So the line was present and current except for the one
// word that store should have written.
//
// The interface checks in cache_sva.sv cannot see this. From outside, the
// write was accepted, busy behaved, and no protocol rule was broken. The store
// simply did not land in any array. This probe watches the two places it must
// land -- the L1 data ways and the L2 ways -- plus the memory write beats, and
// prints one line per event for the target line only.
//
// Filtering to a single line is what makes this usable: an unfiltered trace of
// every array write over 99400 accesses is millions of lines, and the window
// that matters is about twenty cycles wide.
//
// This is a debug instrument, not a permanent check. It is not in the default
// filelist; add it and set +PROBE_LINE=<addr> to arm it.
//
// (A comment line here must never begin with the simulator's name: any comment
// whose first word is that name is parsed as a tool pragma and rejected.)
module cache_store_probe (
    input logic clk,
    input logic rst_n
);
    import uvm_pkg::*;
    import cache_pkg::*;
`include "uvm_macros.svh"

    localparam int LINE_BYTES  = LINE_WIDTH_P / 8;
    // Set count comes from the package, which is the same source the DUT is
    // parameterized from, rather than from $size() on the array itself.
    localparam int L1D_DEPTH   = L1_DATA_SET_COUNT_P;
    localparam int LINE_SHIFT  = $clog2(LINE_BYTES);

    bit [ADDR_WIDTH_P-1:0] probe_line = '0;
    bit                    armed      = 1'b0;
    // Logs every L2 write regardless of address, and the CPU address alongside
    // it. Used to answer whether a write-through's L2 update lands on the line
    // the store named: cache.sv drives cache_l2's addr_p1 from the live
    // data_req_addr, while the write-through pipeline that asserts L2_write_p1
    // runs for a dozen cycles after the CPU strobe has dropped.
    bit                    probe_all_l2 = 1'b0;

    initial begin
        int unsigned v;
        if ($value$plusargs("PROBE_LINE=%h", v)) begin
            probe_line = ADDR_WIDTH_P'(v) >> LINE_SHIFT;
            armed      = 1'b1;
            $display("STORE_PROBE armed on line 0x%0h",
                     probe_line << LINE_SHIFT);
        end
        if ($test$plusargs("PROBE_ALL_L2")) begin
            probe_all_l2 = 1'b1;
            armed        = 1'b1;
            $display("STORE_PROBE logging all L2 writes");
        end
    end

    function automatic bit is_target(input logic [ADDR_WIDTH_P-1:0] a);
        is_target = armed && ((a >> LINE_SHIFT) == probe_line);
    endfunction

    // The CPU-side request, and the two array write paths it must reach.
    always @(posedge clk) begin
        if (rst_n && armed) begin
            // ---- CPU data port -------------------------------------------
            if (vif_data_write && is_target(vif_data_addr))
                $display("[%0t] CPU_WRITE  addr=0x%0h wdata=0x%0h wstrb=0x%0h busy=%0b",
                         $time, vif_data_addr, vif_data_wdata, vif_data_wstrb, vif_busy);
            if (vif_data_read && is_target(vif_data_addr))
                $display("[%0t] CPU_READ   addr=0x%0h busy=%0b | L1 v0=%0b tag0=0x%0h v1=%0b tag1=0x%0h hit=%0b%0b",
                         $time, vif_data_addr, vif_busy,
                         l1d_v0, l1d_tag0, l1d_v1, l1d_tag1, l1d_hit1, l1d_hit2);

            // ---- L1 data ways --------------------------------------------
            if (is_target(l1d_addr) && (l1d_write || l1d_we1 || l1d_we2))
                $display("[%0t] L1        addr=0x%0h write=%0b wL2=%0b wthru=%0b hit=%0b%0b we=%0b%0b be=0x%0h din=0x%0h",
                         $time, l1d_addr, l1d_write, l1d_write_l2, l1d_write_through,
                         l1d_hit1, l1d_hit2, l1d_we1, l1d_we2, l1d_be, l1d_din);

            // ---- L2 ways, port 1 (data side) ------------------------------
            // addr_p1 is already a line address, so it compares to probe_line
            // directly rather than being shifted like the byte addresses above.
            if (armed && (probe_all_l2 || (l2_addr_p1 == probe_line)) &&
                (l2_write_p1 || l2_we1_p1 || l2_we2_p1))
                $display("[%0t] L2        line=0x%0h idx=0x%0h tag=0x%0h write=%0b hit=%0b%0b we=%0b%0b be=0x%0h cpu_addr=0x%0h din=0x%0h",
                         $time, l2_addr_p1, l2_idx_p1, l2_tag_p1, l2_write_p1,
                         l2_hit1_p1, l2_hit2_p1, l2_we1_p1, l2_we2_p1, l2_be_p1,
                         vif_data_addr, l2_din_p1);

            // ---- memory write beats ---------------------------------------
            if (vif_mem_valid && vif_mem_ready && vif_mem_write && is_target(vif_mem_addr))
                $display("[%0t] MEM_WRITE addr=0x%0h wdata=0x%0h wstrb=0x%0h beat=%0d last=%0b",
                         $time, vif_mem_addr, vif_mem_wdata, vif_mem_wstrb,
                         vif_mem_beat, vif_mem_last);

            // ---- write-through control state ------------------------------
            // The question this answers: a write-through hit is supposed to
            // update L2 as well as L1 and memory (cache_controller.sv asserts
            // L2_write_p1 at state_data_writethrough_step2 when
            // ~write_through_miss). In the failing case no L2 write to the
            // stored line was observed at all, so either write_through_miss was
            // set even though L1 hit, or L2_write_p1 never asserted. These two
            // signals plus the state distinguish those.
            if (is_target(l1d_addr) && (ctl_write_through || ctl_wt_miss))
                $display("[%0t] WT        state=%0d wt_miss=%0b L1_hit=%0b l2_write_p1=%0b l2_be=0x%0h",
                         $time, ctl_state, ctl_wt_miss, ctl_l1_hit,
                         ctl_l2_write_p1, l2_be_p1);

            // ---- invalidate pulses ----------------------------------------
            if (l1d_inv_line)
                $display("[%0t] L1_INVAL  inv_tag_and_idx=0x%0h | concurrent: l1_addr=0x%0h write=%0b we=%0b%0b | w0=0x%0h w1=0x%0h",
                         $time, l1d_inv_tagidx, l1d_addr, l1d_write,
                         l1d_we1, l1d_we2, tv_w0, tv_w1);
            if (arr_inv)
                $display("[%0t] L1_INVAL_ARR inv_addr=0x%0h inv_tag=0x%0h stored=0x%0h rst_n=%0b",
                         $time, arr_inv_addr, arr_inv_tag, tv_w0, arr_rstn);

            // The stored tag/valid words for the probed line's set, printed
            // whenever they change. A line invalidate that pulses with the
            // right address but leaves the valid bit set shows up here as an
            // absent transition rather than having to be inferred from a later
            // hit.
            if ((tv_w0 !== tv_w0_q) || (tv_w1 !== tv_w1_q))
                $display("[%0t] L1_TAGV   set=%0d w0=0x%0h w1=0x%0h", $time, tv_set, tv_w0, tv_w1);
            tv_w0_q <= tv_w0;
            tv_w1_q <= tv_w1;
        end
    end

    // Hierarchical aliases, kept together so the paths are in one place.
    wire                         vif_data_write = tb_top.vif.data_req_write;
    wire                         vif_data_read  = tb_top.vif.data_req_read;
    wire [ADDR_WIDTH_P-1:0]      vif_data_addr  = tb_top.vif.data_req_addr;
    wire [DATA_WIDTH_P-1:0]      vif_data_wdata = tb_top.vif.data_req_wdata;
    wire [(DATA_WIDTH_P/8)-1:0]  vif_data_wstrb = tb_top.vif.data_req_wstrb;
    wire                         vif_busy       = tb_top.vif.busy;

    wire                         vif_mem_valid  = tb_top.vif.mem_req_valid;
    wire                         vif_mem_ready  = tb_top.vif.mem_req_ready;
    wire                         vif_mem_write  = tb_top.vif.mem_req_write;
    wire [ADDR_WIDTH_P-1:0]      vif_mem_addr   = tb_top.vif.mem_req_addr;
    wire [MEM_DATA_WIDTH_P-1:0]  vif_mem_wdata  = tb_top.vif.mem_req_wdata;
    wire [(MEM_DATA_WIDTH_P/8)-1:0] vif_mem_wstrb = tb_top.vif.mem_req_wstrb;
    wire [7:0]                   vif_mem_beat   = tb_top.vif.mem_req_beat_index;
    wire                         vif_mem_last   = tb_top.vif.mem_req_burst_last;

    wire [ADDR_WIDTH_P-1:0]      l1d_addr          = tb_top.dut.cache_l1_data_inst.addr;
    wire                         l1d_write         = tb_top.dut.cache_l1_data_inst.write;
    wire                         l1d_write_l2      = tb_top.dut.cache_l1_data_inst.write_L2;
    wire                         l1d_write_through = tb_top.dut.cache_l1_data_inst.write_through;
    wire                         l1d_hit1          = tb_top.dut.cache_l1_data_inst.hit_s1;
    wire                         l1d_hit2          = tb_top.dut.cache_l1_data_inst.hit_s2;
    wire                         l1d_we1           = tb_top.dut.cache_l1_data_inst.we_set1;
    wire                         l1d_we2           = tb_top.dut.cache_l1_data_inst.we_set2;
    wire [LINE_BYTES-1:0]        l1d_be            = tb_top.dut.cache_l1_data_inst.byte_enable;
    wire [LINE_WIDTH_P-1:0]      l1d_din           = tb_top.dut.cache_l1_data_inst.data_in_write;
    wire                         l1d_inv_line      = tb_top.dut.cache_l1_data_inst.invalidate_line;
    wire [31:0]                  l1d_inv_tagidx    = 32'(tb_top.dut.cache_l1_data_inst.invalidate_tag_and_idx);

    // The stored tag/valid words are printed as raw hex, with no attempt to
    // split out the valid bit or the tag here.
    //
    // That is deliberate, and it cost time to learn: $bits() and $size() on a
    // *hierarchical* reference resolve against the referenced module's DEFAULT
    // parameters, not the elaborated instance's. An earlier version of this
    // probe derived the word width that way, read the valid bit from the wrong
    // position on every non-default geometry, and made a working cache look
    // broken. The same underlying trap -- a parameter width that is not the
    // width actually in force -- turned out to be defect D6 in the RTL itself.
    //
    // Print the whole word and decode it by hand against the geometry, or read
    // valid/tag from the DUT's own decoded signals (l1d_v0/l1d_tag0 below),
    // which are sized by the instance and therefore always right.
    localparam int TV_MAX = 32;

    wire [31:0] tv_set = 32'(probe_line) % 32'(L1D_DEPTH);
    wire [TV_MAX-1:0] tv_w0 = TV_MAX'(tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.mem[tv_set]);
    wire [TV_MAX-1:0] tv_w1 = TV_MAX'(tb_top.dut.cache_l1_data_inst.cache_set_1.cache_l1_memory_tag_valid_array_inst.mem[tv_set]);
    logic [TV_MAX-1:0] tv_w0_q, tv_w1_q;

    wire        l1d_v0   = tb_top.dut.cache_l1_data_inst.valid_out_s1;
    wire        l1d_v1   = tb_top.dut.cache_l1_data_inst.valid_out_s2;
    wire [31:0] l1d_tag0 = 32'(tb_top.dut.cache_l1_data_inst.tag_out_s1);
    wire [31:0] l1d_tag1 = 32'(tb_top.dut.cache_l1_data_inst.tag_out_s2);

    wire arr_inv      = tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.invalidate;
    wire arr_rstn     = tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.rst_n;
    wire [31:0] arr_inv_addr = 32'(tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.invalidate_addr);
    wire [31:0] arr_inv_tag  = 32'(tb_top.dut.cache_l1_data_inst.cache_set_0.cache_l1_memory_tag_valid_array_inst.invalidate_tag);

    wire [4:0]                   ctl_state       = tb_top.dut.cache_controller_inst.state_data;
    wire                         ctl_wt_miss     = tb_top.dut.cache_controller_inst.write_through_miss;
    wire                         ctl_l1_hit      = tb_top.dut.cache_controller_inst.L1_data_hit;
    wire                         ctl_write_through = tb_top.dut.cache_controller_inst.write_through;
    wire                         ctl_l2_write_p1 = tb_top.dut.cache_controller_inst.L2_write_p1;

    wire [31:0]                  l2_addr_p1  = 32'(tb_top.dut.cache_l2_inst.addr_p1);
    wire [31:0]                  l2_tag_p1   = 32'(tb_top.dut.cache_l2_inst.tag_input_p1);
    wire [31:0]                  l2_idx_p1   = 32'(tb_top.dut.cache_l2_inst.idx_input_p1);
    wire                         l2_write_p1 = tb_top.dut.cache_l2_inst.write_p1;
    wire                         l2_hit1_p1  = tb_top.dut.cache_l2_inst.hit_s1_p1;
    wire                         l2_hit2_p1  = tb_top.dut.cache_l2_inst.hit_s2_p1;
    wire                         l2_we1_p1   = tb_top.dut.cache_l2_inst.we_set1_p1;
    wire                         l2_we2_p1   = tb_top.dut.cache_l2_inst.we_set2_p1;
    wire [LINE_BYTES-1:0]        l2_be_p1    = tb_top.dut.cache_l2_inst.byte_enable_p1;
    wire [LINE_WIDTH_P-1:0]      l2_din_p1   = tb_top.dut.cache_l2_inst.data_block_write_p1;

endmodule
