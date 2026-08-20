// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_env extends uvm_env;

    cache_data_agent  data_agent;
    cache_instr_agent instr_agent;
    cache_maint_agent maint_agent;
    cache_mem_agent   mem_agent;

    cache_scoreboard  sb;
    cache_mem_checker mem_checker;
    cache_vsqr        vsqr;

    cache_env_cfg     cfg;
    cache_ref_model   ref_model;
    cache_ctx         ctx;

    `uvm_component_utils(cache_env)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(cache_env_cfg)::get(this, "", "cfg", cfg)) begin
            cfg = cache_env_cfg::type_id::create("cfg");
            `uvm_info("ENV", "no cache_env_cfg provided, using defaults", UVM_LOW)
        end
        uvm_config_db#(cache_env_cfg)::set(this, "*", "cfg", cfg);

        // The oracle and the shared context are created here so every component
        // checks against the same instance. They are published at global scope
        // rather than under the env because sequences need them too, and a
        // sequence is not a component — it cannot look up a scope relative to
        // itself, so an env-relative entry would be invisible to it.
        ref_model = cache_ref_model::type_id::create("ref_model");
        ctx       = cache_ctx::type_id::create("ctx");
        uvm_config_db#(cache_ref_model)::set(null, "*", "ref_model", ref_model);
        uvm_config_db#(cache_ctx)::set(null, "*", "ctx", ctx);

        data_agent  = cache_data_agent::type_id::create("data_agent", this);
        instr_agent = cache_instr_agent::type_id::create("instr_agent", this);
        maint_agent = cache_maint_agent::type_id::create("maint_agent", this);
        mem_agent   = cache_mem_agent::type_id::create("mem_agent", this);

        sb          = cache_scoreboard::type_id::create("sb", this);
        mem_checker = cache_mem_checker::type_id::create("mem_checker", this);
        vsqr        = cache_vsqr::type_id::create("vsqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        data_agent.mon.ap.connect(sb.data_read_imp);
        data_agent.mon.write_ap.connect(sb.data_write_imp);
        instr_agent.mon.ap.connect(sb.instr_imp);
        maint_agent.mon.ap.connect(sb.maint_imp);

        mem_agent.mon.ap.connect(mem_checker.beat_imp);
        data_agent.mon.write_ap.connect(mem_checker.cpu_write_imp);

        vsqr.data_sqr  = data_agent.sqr;
        vsqr.instr_sqr = instr_agent.sqr;
        vsqr.maint_sqr = maint_agent.sqr;
    endfunction

endclass
