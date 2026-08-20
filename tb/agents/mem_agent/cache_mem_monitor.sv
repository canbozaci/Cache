// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Observes native memory request beats and tallies read handshakes.
//
// The read count is the testbench's only handle on hit/miss behaviour: the
// cache exposes no hit signal, so "did this access come from the array or from
// memory" is answered by whether a memory read happened. Sequences snapshot
// ctx.mem_read_count around a step to assert on that.
class cache_mem_monitor extends uvm_monitor;

    cache_vif_t vif;
    cache_ctx   ctx;

    uvm_analysis_port #(cache_mem_obs_txn) ap;

    `uvm_component_utils(cache_mem_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_mem_monitor")
        if (!uvm_config_db#(cache_ctx)::get(this, "", "ctx", ctx))
            `uvm_fatal("NOCTX", "cache_ctx not set for cache_mem_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.mem_req_valid && vif.mem_req_ready) begin
                cache_mem_obs_txn t = cache_mem_obs_txn::type_id::create("t");
                t.write       = vif.mem_req_write;
                t.burst       = vif.mem_req_burst;
                t.burst_len   = vif.mem_req_burst_len;
                t.beat_index  = vif.mem_req_beat_index;
                t.burst_start = vif.mem_req_burst_start;
                t.burst_last  = vif.mem_req_burst_last;
                t.addr        = vif.mem_req_addr;
                t.wdata       = vif.mem_req_wdata;
                t.wstrb       = vif.mem_req_wstrb;
                t.cpu_busy    = vif.busy;
                t.cpu_write   = vif.data_req_write;

                if (!t.write) ctx.mem_read_count++;

                ap.write(t);
            end
        end
    endtask

endclass
