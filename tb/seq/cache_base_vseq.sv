// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Base virtual sequence: the stimulus vocabulary every cache test is written
// in.
//
// The helpers below are deliberately thin wrappers over `start_item`/
// `finish_item` rather than sequences in their own right. Each one corresponds
// to a single CPU command, and because the DUT is blocking, a command is only
// meaningful as part of an ordered script — so tests read as procedures, not as
// sequence trees.
class cache_base_vseq extends uvm_sequence;

    `uvm_object_utils(cache_base_vseq)
    `uvm_declare_p_sequencer(cache_vsqr)

    cache_vif_t     vif;
    cache_ctx       ctx;
    cache_ref_model ref_model;

    // Geometry shorthands used to place stimulus at meaningful boundaries.
    // Sized to the address width so they can be passed straight into address
    // arguments without truncation warnings.
    static const int unsigned              LINE_BYTES      = LINE_WIDTH_P / 8;
    static const bit [ADDR_WIDTH_P-1:0]    NEXT_LINE_ADDR  = ADDR_WIDTH_P'(LINE_BYTES);
    static const bit [ADDR_WIDTH_P-1:0]    L1_ALIAS_STRIDE =
        ADDR_WIDTH_P'(L1_DATA_SET_COUNT_P * LINE_BYTES);

    function new(string name = "cache_base_vseq");
        super.new(name);
    endfunction

    virtual task pre_start();
        if (!uvm_config_db#(cache_vif_t)::get(null, "*", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for sequence")
        if (!uvm_config_db#(cache_ctx)::get(null, "*", "ctx", ctx))
            `uvm_fatal("NOCTX", "cache_ctx not available to sequence")
        if (!uvm_config_db#(cache_ref_model)::get(null, "*", "ref_model", ref_model))
            `uvm_fatal("NOREF", "cache_ref_model not available to sequence")
    endtask

    // ---- CPU data port ---------------------------------------------------

    virtual task data_read(bit [ADDR_WIDTH_P-1:0] addr, string label);
        cache_data_txn t = cache_data_txn::type_id::create("t");
        ctx.label = label;
        start_item(t, -1, p_sequencer.data_sqr);
        t.op    = CACHE_DATA_READ;
        t.addr  = addr;
        t.label = label;
        finish_item(t);
    endtask

    virtual task data_write(bit [ADDR_WIDTH_P-1:0] addr,
                            bit [DATA_WIDTH_P-1:0] wdata,
                            bit [(DATA_WIDTH_P/8)-1:0] wstrb,
                            string label);
        cache_data_txn t = cache_data_txn::type_id::create("t");
        ctx.label = label;
        start_item(t, -1, p_sequencer.data_sqr);
        t.op    = CACHE_DATA_WRITE;
        t.addr  = addr;
        t.wdata = wdata;
        t.wstrb = wstrb;
        t.label = label;
        finish_item(t);
    endtask

    // ---- CPU instruction port -------------------------------------------

    virtual task instr_fetch(bit [ADDR_WIDTH_P-1:0] addr, string label);
        cache_instr_txn t = cache_instr_txn::type_id::create("t");
        ctx.label              = label;
        ctx.instr_use_expected = 1'b0;
        start_item(t, -1, p_sequencer.instr_sqr);
        t.addr  = addr;
        t.label = label;
        finish_item(t);
    endtask

    // Fetch that must return a specific value rather than whatever the
    // reference model now holds. Used where a stale hit is the contract.
    virtual task instr_fetch_expect(bit [ADDR_WIDTH_P-1:0] addr,
                                    bit [31:0] expected,
                                    string label);
        cache_instr_txn t = cache_instr_txn::type_id::create("t");
        ctx.label              = label;
        ctx.instr_use_expected = 1'b1;
        ctx.instr_expected     = expected;
        start_item(t, -1, p_sequencer.instr_sqr);
        t.addr         = addr;
        t.label        = label;
        t.use_expected = 1'b1;
        t.expected     = expected;
        finish_item(t);
        ctx.instr_use_expected = 1'b0;
    endtask

    // Both CPU ports commanded in the same cycle. They share `busy`, so this is
    // the only way to check that one port's miss handling does not corrupt the
    // other's response.
    virtual task data_and_instr_read(bit [ADDR_WIDTH_P-1:0] data_addr,
                                     bit [ADDR_WIDTH_P-1:0] instr_addr,
                                     string label);
        fork
            data_read(data_addr, label);
            instr_fetch(instr_addr, label);
        join
    endtask

    // ---- Maintenance port ------------------------------------------------

    virtual task maint_cmd(bit flush, bit invalidate,
                           bit flush_line, bit invalidate_line,
                           bit addr_valid, bit [ADDR_WIDTH_P-1:0] addr,
                           bit expect_error, string label,
                           bit issue_while_busy = 0, bit pulse_only = 0);
        cache_maint_txn t = cache_maint_txn::type_id::create("t");
        ctx.label              = label;
        ctx.maint_expect_error = expect_error;
        start_item(t, -1, p_sequencer.maint_sqr);
        t.flush_req           = flush;
        t.invalidate_req      = invalidate;
        t.flush_line_req      = flush_line;
        t.invalidate_line_req = invalidate_line;
        t.addr_valid          = addr_valid;
        t.addr                = addr;
        t.expect_error        = expect_error;
        t.issue_while_busy    = issue_while_busy;
        t.pulse_only          = pulse_only;
        t.label               = label;
        finish_item(t);
        ctx.maint_expect_error = 1'b0;
    endtask

    virtual task global_flush(string label);
        maint_cmd(1, 0, 0, 0, 0, '0, 0, label);
    endtask

    virtual task global_invalidate(string label);
        maint_cmd(0, 1, 0, 0, 0, '0, 0, label);
    endtask

    virtual task line_flush(bit [ADDR_WIDTH_P-1:0] addr, string label);
        maint_cmd(0, 0, 1, 0, 1, addr, 0, label);
    endtask

    virtual task line_invalidate(bit [ADDR_WIDTH_P-1:0] addr, string label);
        maint_cmd(0, 0, 0, 1, 1, addr, 0, label);
    endtask

    // ---- Reset -----------------------------------------------------------

    // Drives `rst_n` directly. Reset is a testbench-wide event rather than a port
    // command, so it does not belong to any one agent; the drivers and monitors
    // are reset-aware and abort whatever they are doing when this fires.
    virtual task reset_pulse(int unsigned reset_cycles);
        @(negedge vif.clk);
        vif.rst_n = 1'b0;
        repeat (reset_cycles) @(posedge vif.clk);
        @(negedge vif.clk);
        vif.rst_n = 1'b1;
        repeat (8) @(posedge vif.clk);
    endtask

    virtual task wait_idle(string label);
        cache_sync::wait_for_idle(vif, label);
    endtask

    // ---- Memory-traffic assertions ---------------------------------------

    // Several contracts are stated as "this must hit" or "this must refill",
    // which are only observable as the presence or absence of memory reads.
    virtual function int unsigned read_count();
        return ctx.mem_read_count;
    endfunction

    virtual function void expect_no_memory_reads(int unsigned reads_before, string label);
        if (ctx.mem_read_count != reads_before)
            `uvm_error("HIT_EXPECTED",
                       $sformatf("%0s: expected a hit, but %0d memory read(s) occurred",
                                 label, ctx.mem_read_count - reads_before))
    endfunction

    virtual function void expect_memory_reads(int unsigned reads_before, string label);
        if (ctx.mem_read_count == reads_before)
            `uvm_error("MISS_EXPECTED",
                       $sformatf("%0s: expected a refill, but no memory read occurred", label))
    endfunction

endclass
