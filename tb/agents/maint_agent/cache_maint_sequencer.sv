// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_maint_sequencer extends uvm_sequencer #(cache_maint_txn);
    `uvm_component_utils(cache_maint_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
