// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Knobs that the legacy directed testbench exposed as module parameters but
// that do not change the DUT geometry. Geometry parameters (ADDR_WIDTH,
// DATA_WIDTH, ...) stay compile-time in cache_pkg because they change port
// widths; these are runtime because they only change responder behaviour.
class cache_env_cfg extends uvm_object;

    // Deassert mem_req_ready every fourth cycle when non-zero.
    int unsigned mem_ready_stalls = 0;

    // Fixed extra response latency, in cycles, on top of the base one.
    int unsigned mem_rsp_extra_latency = 0;

    // When non-zero, latency cycles through 0..3 per read handshake instead of
    // using mem_rsp_extra_latency.
    bit mem_rsp_variable_latency = 0;

    `uvm_object_utils_begin(cache_env_cfg)
        `uvm_field_int(mem_ready_stalls, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(mem_rsp_extra_latency, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(mem_rsp_variable_latency, UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "cache_env_cfg");
        super.new(name);
    endfunction

endclass
