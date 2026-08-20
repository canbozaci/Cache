// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Agent for the block-level DUT bundle. There is no monitor: see
// cache_block_driver for why an independent observer is not meaningful for
// leaf modules with no handshake.
class cache_block_agent extends uvm_agent;

    cache_block_sequencer sqr;
    cache_block_driver    drv;

    `uvm_component_utils(cache_block_agent)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = cache_block_sequencer::type_id::create("sqr", this);
        drv = cache_block_driver::type_id::create("drv", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass
