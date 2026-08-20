// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_block_test extends uvm_test;

    cache_block_env env;

    `uvm_component_utils(cache_block_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cache_block_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        cache_block_full_seq seq;
        virtual cache_block_if vif;

        phase.raise_objection(this);

        if (!uvm_config_db#(virtual cache_block_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_block_test")

        // Wait for the power-on reset in the top to release.
        while (!vif.rst_n) @(posedge vif.clk);
        repeat (2) @(posedge vif.clk);

        seq = cache_block_full_seq::type_id::create("seq");
        seq.start(env.agent.sqr);

        phase.drop_objection(this);
    endtask

    // Same explicit banner as the cache-top test: the regression gate reads
    // this rather than the exit status, which UVM always leaves at zero.
    function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        int unsigned errors = svr.get_severity_count(UVM_ERROR) +
                              svr.get_severity_count(UVM_FATAL);
        super.report_phase(phase);
        if (errors == 0) $display("CACHE BLOCK TEST PASS");
        else             $display("CACHE BLOCK TEST FAIL: %0d error(s)", errors);
    endfunction

endclass
