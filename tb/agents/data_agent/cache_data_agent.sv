// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_data_agent extends uvm_agent;

    cache_data_sequencer sqr;
    cache_data_driver    drv;
    cache_data_monitor   mon;

    `uvm_component_utils(cache_data_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = cache_data_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = cache_data_sequencer::type_id::create("sqr", this);
            drv = cache_data_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass
