// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_instr_agent extends uvm_agent;

    cache_instr_sequencer sqr;
    cache_instr_driver    drv;
    cache_instr_monitor   mon;

    `uvm_component_utils(cache_instr_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = cache_instr_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = cache_instr_sequencer::type_id::create("sqr", this);
            drv = cache_instr_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass
