// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// One CPU instruction-fetch command. The instruction port is read-only and
// always 32 bits wide regardless of DATA_WIDTH.
class cache_instr_txn extends uvm_sequence_item;

    rand bit [ADDR_WIDTH_P-1:0] addr;

    // Driver-filled observation.
    bit [31:0]                  rdata;

    // When set, the scoreboard checks against `expected` instead of the
    // reference model. This is how the documented I/D incoherency contract is
    // checked: the fetch is *supposed* to return a stale value that the
    // reference model no longer holds.
    bit                         use_expected = 0;
    bit [31:0]                  expected     = '0;

    string                      label = "";

    constraint c_word_aligned { addr % 4 == 0; }
    constraint c_in_ref_range { addr < cache_ref_model::REF_BYTES - 4; }

    `uvm_object_utils_begin(cache_instr_txn)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(rdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(use_expected, UVM_DEFAULT)
        `uvm_field_int(expected, UVM_DEFAULT | UVM_HEX)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_instr_txn");
        super.new(name);
    endfunction

endclass
