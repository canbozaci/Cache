// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// The completion status of a maintenance command as seen on the bus.
class cache_maint_obs_txn extends uvm_sequence_item;

    bit                    flush_req;
    bit                    invalidate_req;
    bit                    flush_line_req;
    bit                    invalidate_line_req;
    bit                    addr_valid;
    bit [ADDR_WIDTH_P-1:0] addr;

    bit                    ready;
    bit                    done;
    bit                    error;

    bit                    expect_error;
    string                 label = "";

    `uvm_object_utils_begin(cache_maint_obs_txn)
        `uvm_field_int(flush_req, UVM_DEFAULT)
        `uvm_field_int(invalidate_req, UVM_DEFAULT)
        `uvm_field_int(flush_line_req, UVM_DEFAULT)
        `uvm_field_int(invalidate_line_req, UVM_DEFAULT)
        `uvm_field_int(addr_valid, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(ready, UVM_DEFAULT)
        `uvm_field_int(done, UVM_DEFAULT)
        `uvm_field_int(error, UVM_DEFAULT)
        `uvm_field_int(expect_error, UVM_DEFAULT)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_maint_obs_txn");
        super.new(name);
    endfunction

endclass
