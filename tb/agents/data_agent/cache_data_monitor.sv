// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Observes the CPU data port without driving it.
//
// The DUT has no data-valid strobe, so completion has to be inferred from the
// same `busy` protocol the driver uses. This is deliberately an independent
// re-derivation off the interface rather than a hook into the driver: if the
// driver's notion of "done" drifts from the RTL's, the monitor is what catches
// it.
class cache_data_monitor extends uvm_monitor;

    cache_vif_t vif;

    // Read completions, checked against the reference model.
    uvm_analysis_port #(cache_data_obs_txn) ap;

    // Write commands, published as soon as they are seen so the memory-side
    // burst checker can arm before the first write beat appears.
    uvm_analysis_port #(cache_data_obs_txn) write_ap;

    // Shared context: supplies the label for the stimulus in flight.
    cache_ctx ctx;

    `uvm_component_utils(cache_data_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap       = new("ap", this);
        write_ap = new("write_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_data_monitor")
        if (!uvm_config_db#(cache_ctx)::get(this, "", "ctx", ctx))
            `uvm_fatal("NOCTX", "cache_ctx not set for cache_data_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_reads();
            monitor_writes();
        join
    endtask

    protected task monitor_reads();
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.data_req_read) begin
                cache_data_obs_txn t = cache_data_obs_txn::type_id::create("t");
                t.op    = CACHE_DATA_READ;
                t.addr  = vif.data_req_addr;
                t.label = ctx.label;

                // One posedge of the command has already been consumed above,
                // so wait one more to reach the driver's two-cycle point.
                // Raced against reset: a read that reset aborted never
                // produced a response, so there is nothing to check and
                // publishing one would be a false failure.
                fork
                    begin
                        @(posedge vif.clk);
                        while (vif.busy) @(posedge vif.clk);
                        @(posedge vif.clk);
                    end
                    cache_sync::wait_reset_assert(vif);
                join_any
                disable fork;

                if (vif.rst_n) begin
                    t.rdata = vif.data_resp_rdata;
                    ap.write(t);
                end

                // Do not re-trigger on the same held command.
                while (vif.data_req_read && vif.rst_n) @(posedge vif.clk);
            end
        end
    endtask

    protected task monitor_writes();
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.data_req_write) begin
                cache_data_obs_txn t = cache_data_obs_txn::type_id::create("t");
                t.op    = CACHE_DATA_WRITE;
                t.addr  = vif.data_req_addr;
                t.wdata = vif.data_req_wdata;
                t.wstrb = vif.data_req_wstrb;
                t.label = ctx.label;
                write_ap.write(t);

                while (vif.data_req_write) @(posedge vif.clk);
            end
        end
    endtask

endclass
