// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// One maintenance command.
//
// The four request bits are carried individually rather than as an opcode enum
// because a large part of the maintenance contract is about *illegal*
// combinations — flush and invalidate together, global and line together, line
// maintenance without an address. An enum could not express those, and they are
// exactly the cases that must return maint_error.
class cache_maint_txn extends uvm_sequence_item;

    rand bit                    flush_req;
    rand bit                    invalidate_req;
    rand bit                    flush_line_req;
    rand bit                    invalidate_line_req;
    rand bit                    addr_valid;
    rand bit [ADDR_WIDTH_P-1:0] addr;

    // Expected outcome. Set by the sequence, checked by the driver's monitor
    // counterpart via the scoreboard.
    bit                         expect_error = 0;

    // When set, the driver does not wait for the cache to be idle first. Used
    // for the queued-maintenance-while-busy contract, where the whole point is
    // to issue the command mid-transaction.
    bit                         issue_while_busy = 0;

    // For the busy case: drop the request after a single cycle instead of
    // holding it until completion.
    bit                         pulse_only = 0;

    string                      label = "";

    `uvm_object_utils_begin(cache_maint_txn)
        `uvm_field_int(flush_req, UVM_DEFAULT)
        `uvm_field_int(invalidate_req, UVM_DEFAULT)
        `uvm_field_int(flush_line_req, UVM_DEFAULT)
        `uvm_field_int(invalidate_line_req, UVM_DEFAULT)
        `uvm_field_int(addr_valid, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(expect_error, UVM_DEFAULT)
        `uvm_field_int(issue_while_busy, UVM_DEFAULT)
        `uvm_field_int(pulse_only, UVM_DEFAULT)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_maint_txn");
        super.new(name);
    endfunction

endclass
