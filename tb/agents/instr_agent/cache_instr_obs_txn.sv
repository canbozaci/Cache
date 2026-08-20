// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_instr_obs_txn extends uvm_sequence_item;

    bit [ADDR_WIDTH_P-1:0] addr;
    bit [31:0]             rdata;
    string                 label = "";

    // Mirrors cache_instr_txn: lets the scoreboard check a deliberately stale
    // fetch against a captured value rather than the reference model.
    bit                    use_expected = 0;
    bit [31:0]             expected     = '0;

    `uvm_object_utils_begin(cache_instr_obs_txn)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(rdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(use_expected, UVM_DEFAULT)
        `uvm_field_int(expected, UVM_DEFAULT | UVM_HEX)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_instr_obs_txn");
        super.new(name);
    endfunction

endclass
