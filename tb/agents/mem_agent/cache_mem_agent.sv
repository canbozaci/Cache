// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Memory-side agent. Active, but with no sequencer: the DUT drives the traffic
// and this agent only responds, so there is no stimulus to sequence.
class cache_mem_agent extends uvm_agent;

    cache_mem_driver  drv;
    cache_mem_monitor mon;

    `uvm_component_utils(cache_mem_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = cache_mem_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE)
            drv = cache_mem_driver::type_id::create("drv", this);
    endfunction

endclass
