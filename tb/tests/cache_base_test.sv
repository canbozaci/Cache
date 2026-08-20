// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_base_test extends uvm_test;

    cache_env     env;
    cache_env_cfg cfg;

    `uvm_component_utils(cache_base_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = cache_env_cfg::type_id::create("cfg");
        configure(cfg);
        uvm_config_db#(cache_env_cfg)::set(this, "env", "cfg", cfg);
        env = cache_env::type_id::create("env", this);
    endfunction

    // Derived tests override this to change memory-side behaviour. Kept
    // separate from build_phase so a subclass cannot forget to publish the
    // config afterwards.
    virtual function void configure(cache_env_cfg c);
        // Memory responder knobs come from plusargs so one compiled image can
        // cover the ready-stall and latency configurations, which do not change
        // any port width and therefore do not need a rebuild.
        int unsigned v;
        if ($value$plusargs("MEM_READY_STALLS=%d", v))        c.mem_ready_stalls        = v;
        if ($value$plusargs("MEM_RSP_EXTRA_LATENCY=%d", v))   c.mem_rsp_extra_latency   = v;
        if ($value$plusargs("MEM_RSP_VARIABLE_LATENCY=%d", v)) c.mem_rsp_variable_latency = (v != 0);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("CFG", $sformatf("geometry: ADDR=%0d DATA=%0d MEM_DATA=%0d LINE=%0d L1D=%0d L1I=%0d L2=%0d",
                                   ADDR_WIDTH_P, DATA_WIDTH_P, MEM_DATA_WIDTH_P, LINE_WIDTH_P,
                                   L1_DATA_SET_COUNT_P, L1_INSTR_SET_COUNT_P, L2_SET_COUNT_P), UVM_LOW)
        `uvm_info("CFG", $sformatf("responder: %s", cfg.sprint()), UVM_LOW)
    endfunction

    // A UVM run reports failure through the report server, but the regression
    // scripts key off an explicit line so a pass cannot be inferred from a
    // simulation that merely finished.
    function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        int unsigned errors = svr.get_severity_count(UVM_ERROR) +
                              svr.get_severity_count(UVM_FATAL);
        super.report_phase(phase);
        if (errors == 0) $display("CACHE UVM PASS");
        else             $display("CACHE UVM FAIL: %0d error(s)", errors);
    endfunction

endclass
