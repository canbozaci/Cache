// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

`uvm_analysis_imp_decl(_data_read)
`uvm_analysis_imp_decl(_data_write)
`uvm_analysis_imp_decl(_instr)
`uvm_analysis_imp_decl(_maint)

// Checks CPU-visible behaviour against the reference model.
//
// The oracle is updated from *observed* CPU writes rather than from the
// stimulus that requested them, so a write that the DUT drops or mangles on the
// CPU side is caught rather than absorbed into the expectation.
class cache_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp_data_read  #(cache_data_obs_txn,  cache_scoreboard) data_read_imp;
    uvm_analysis_imp_data_write #(cache_data_obs_txn,  cache_scoreboard) data_write_imp;
    uvm_analysis_imp_instr      #(cache_instr_obs_txn, cache_scoreboard) instr_imp;
    uvm_analysis_imp_maint      #(cache_maint_obs_txn, cache_scoreboard) maint_imp;

    cache_ref_model ref_model;

    int unsigned checks_data  = 0;
    int unsigned checks_instr = 0;
    int unsigned checks_maint = 0;

    `uvm_component_utils(cache_scoreboard)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        data_read_imp  = new("data_read_imp",  this);
        data_write_imp = new("data_write_imp", this);
        instr_imp      = new("instr_imp",      this);
        maint_imp      = new("maint_imp",      this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_ref_model)::get(this, "", "ref_model", ref_model))
            `uvm_fatal("NOREF", "cache_ref_model not set for cache_scoreboard")
    endfunction

    function void write_data_read(cache_data_obs_txn t);
        bit [DATA_WIDTH_P-1:0] expected = ref_model.read_data(32'(t.addr));
        checks_data++;

        // An X on the response is called out separately: it usually means an
        // uninitialised array read rather than a wrong value, and comparing X
        // against a clean expectation would report it as an ordinary mismatch.
        if ((^t.rdata) === 1'bx) begin
            `uvm_error("DATA_X", $sformatf("%0s addr=0x%0h response contains X: %0h",
                                           t.label, t.addr, t.rdata))
        end else if (t.rdata !== expected) begin
            `uvm_error("DATA_MISMATCH",
                       $sformatf("%0s addr=0x%0h expected=%0h actual=%0h",
                                 t.label, t.addr, expected, t.rdata))
        end
    endfunction

    function void write_data_write(cache_data_obs_txn t);
        ref_model.apply_write(32'(t.addr), t.wdata, t.wstrb);
    endfunction

    function void write_instr(cache_instr_obs_txn t);
        // A stale-by-contract fetch is checked against the value captured
        // before the data-side write, not against the reference model.
        bit [31:0] expected = t.use_expected ? t.expected
                                             : ref_model.read_instr(32'(t.addr));
        checks_instr++;

        if ((^t.rdata) === 1'bx) begin
            `uvm_error("INSTR_X", $sformatf("%0s addr=0x%0h fetch contains X: %0h",
                                            t.label, t.addr, t.rdata))
        end else if (t.rdata !== expected) begin
            `uvm_error("INSTR_MISMATCH",
                       $sformatf("%0s addr=0x%0h expected=%0h actual=%0h",
                                 t.label, t.addr, expected, t.rdata))
        end
    endfunction

    function void write_maint(cache_maint_obs_txn t);
        checks_maint++;

        if (!t.ready) begin
            `uvm_error("MAINT_READY",
                       $sformatf("%0s retired with maint_ready low", t.label))
        end

        if (t.expect_error) begin
            if (t.done || !t.error)
                `uvm_error("MAINT_NEG_MISMATCH",
                           $sformatf("%0s expected error, got done=%0b error=%0b",
                                     t.label, t.done, t.error))
        end else begin
            if (!t.done || t.error)
                `uvm_error("MAINT_MISMATCH",
                           $sformatf("%0s expected success, got done=%0b error=%0b",
                                     t.label, t.done, t.error))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD",
                  $sformatf("checked %0d data reads, %0d instruction fetches, %0d maintenance commands",
                            checks_data, checks_instr, checks_maint), UVM_LOW)

        // A silent scoreboard is indistinguishable from a passing one, so a run
        // that checked nothing is treated as a failure.
        if (checks_data == 0 && checks_instr == 0)
            `uvm_error("NO_CHECKS", "scoreboard observed no CPU-side traffic")
    endfunction

endclass
