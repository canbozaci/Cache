// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// The regression test: the whole directed contract suite in one run.
class cache_full_test extends cache_base_test;

    `uvm_component_utils(cache_full_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        cache_full_vseq vseq;
        cache_vif_t     vif;
        phase.raise_objection(this);

        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_full_test")

        // Nothing may be driven until the power-on reset in tb_top releases.
        cache_sync::wait_reset_release(vif);
        repeat (4) @(posedge vif.clk);

        vseq = cache_full_vseq::type_id::create("vseq");
        vseq.start(env.vsqr);

        phase.drop_objection(this);
    endtask

endclass
