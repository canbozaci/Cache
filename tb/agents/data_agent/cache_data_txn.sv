// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

typedef enum {
    CACHE_DATA_READ,
    CACHE_DATA_WRITE
} cache_data_op_e;

// One CPU data-port command. `rdata` is filled in by the driver on a read so a
// sequence can reason about the value it just fetched; the scoreboard does the
// actual checking off the monitor, not off this field.
class cache_data_txn extends uvm_sequence_item;

    rand cache_data_op_e                 op;
    rand bit [ADDR_WIDTH_P-1:0]          addr;
    rand bit [DATA_WIDTH_P-1:0]          wdata;
    rand bit [(DATA_WIDTH_P/8)-1:0]      wstrb;

    // Driver-filled observation.
    bit [DATA_WIDTH_P-1:0]               rdata;

    // Free-text tag carried into scoreboard messages, so a failure names the
    // stimulus that produced it the way the legacy tb's labels did.
    string                               label = "";

    // A single data request must not cross a cache-line boundary; the IP
    // contract pushes that split onto the CPU adaptor, so the stimulus here
    // must respect it too.
    constraint c_within_line {
        (addr % (LINE_WIDTH_P / 8)) + (DATA_WIDTH_P / 8) <= (LINE_WIDTH_P / 8);
    }

    constraint c_in_ref_range {
        addr < cache_ref_model::REF_BYTES - (DATA_WIDTH_P / 8);
    }

    `uvm_object_utils_begin(cache_data_txn)
        `uvm_field_enum(cache_data_op_e, op, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wstrb, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(rdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_string(label, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "cache_data_txn");
        super.new(name);
    endfunction

endclass
