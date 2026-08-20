// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_block_env extends uvm_env;

    cache_block_agent      agent;
    cache_block_scoreboard sb;

    `uvm_component_utils(cache_block_env)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = cache_block_agent::type_id::create("agent", this);
        sb    = cache_block_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.drv.ap.connect(sb.imp);
    endfunction

endclass
