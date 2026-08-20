// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Constrained-random traffic against the same env and the same checkers as the
// directed suite.
//
// Kept separate from cache_full_test rather than appended to it so a failure
// says which kind of stimulus found it. A directed failure names a contract; a
// random failure names a seed, and the two want different first questions.
class cache_random_test extends cache_base_test;

    `uvm_component_utils(cache_random_test)

    int unsigned traffic_ops = 400;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void configure(cache_env_cfg c);
        int unsigned v;
        super.configure(c);
        if ($value$plusargs("TRAFFIC_OPS=%d", v)) traffic_ops = v;
    endfunction

    task run_phase(uvm_phase phase);
        cache_random_vseq vseq;
        cache_vif_t       vif;
        phase.raise_objection(this);

        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_random_test")

        cache_sync::wait_reset_release(vif);
        repeat (4) @(posedge vif.clk);

        vseq = cache_random_vseq::type_id::create("vseq");
        vseq.op_count = traffic_ops;
        vseq.start(env.vsqr);

        phase.drop_objection(this);
    endtask

endclass
