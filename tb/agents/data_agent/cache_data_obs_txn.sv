// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// What the data monitor actually saw on the bus. Kept separate from the
// stimulus item so the scoreboard can never accidentally check a value against
// the intent that produced it.
class cache_data_obs_txn extends uvm_sequence_item;

    cache_data_op_e                 op;
    bit [ADDR_WIDTH_P-1:0]          addr;
    bit [DATA_WIDTH_P-1:0]          wdata;
    bit [(DATA_WIDTH_P/8)-1:0]      wstrb;
    bit [DATA_WIDTH_P-1:0]          rdata;
    string                          label = "";

    `uvm_object_utils_begin(cache_data_obs_txn)
        `uvm_field_enum(cache_data_op_e, op, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wstrb, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(rdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_data_obs_txn");
        super.new(name);
    endfunction

endclass
