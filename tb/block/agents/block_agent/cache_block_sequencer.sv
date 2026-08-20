// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_block_sequencer extends uvm_sequencer #(cache_block_txn);
    `uvm_component_utils(cache_block_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
