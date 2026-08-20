// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_instr_sequencer extends uvm_sequencer #(cache_instr_txn);
    `uvm_component_utils(cache_instr_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
