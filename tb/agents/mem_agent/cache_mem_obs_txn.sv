// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// One native-memory request beat, captured at its handshake.
class cache_mem_obs_txn extends uvm_sequence_item;

    bit                          write;
    bit                          burst;
    bit [7:0]                    burst_len;
    bit [7:0]                    beat_index;
    bit                          burst_start;
    bit                          burst_last;
    bit [31:0]                   addr;
    bit [MEM_DATA_WIDTH_P-1:0]   wdata;
    bit [(MEM_DATA_WIDTH_P/8)-1:0] wstrb;

    // CPU-side state sampled at the same edge as the beat. The write burst
    // fields are combinational off the live CPU store, so knowing whether the
    // CPU still had a command asserted is what distinguishes a testbench
    // protocol violation from the cache issuing a write it can no longer
    // describe.
    bit                          cpu_busy;
    bit                          cpu_write;

    `uvm_object_utils_begin(cache_mem_obs_txn)
        `uvm_field_int(write, UVM_DEFAULT)
        `uvm_field_int(burst, UVM_DEFAULT)
        `uvm_field_int(burst_len, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(beat_index, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(burst_start, UVM_DEFAULT)
        `uvm_field_int(burst_last, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wdata, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(wstrb, UVM_DEFAULT | UVM_HEX)
    `uvm_object_utils_end

    function new(string name = "cache_mem_obs_txn");
        super.new(name);
    endfunction

endclass
