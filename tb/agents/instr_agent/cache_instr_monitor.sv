// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Observes the CPU instruction port. Completion is inferred from `busy`, using
// the same timing the data monitor uses; see cache_sync for why that is shared.
class cache_instr_monitor extends uvm_monitor;

    cache_vif_t vif;
    cache_ctx   ctx;

    uvm_analysis_port #(cache_instr_obs_txn) ap;

    `uvm_component_utils(cache_instr_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_instr_monitor")
        if (!uvm_config_db#(cache_ctx)::get(this, "", "ctx", ctx))
            `uvm_fatal("NOCTX", "cache_ctx not set for cache_instr_monitor")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.instr_req_valid) begin
                cache_instr_obs_txn t = cache_instr_obs_txn::type_id::create("t");
                t.addr         = vif.instr_req_addr;
                t.label        = ctx.label;
                t.use_expected = ctx.instr_use_expected;
                t.expected     = ctx.instr_expected;

                // Raced against reset for the same reason as the data monitor:
                // an aborted fetch has no response worth checking.
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
                    t.rdata = vif.instr_resp_data;
                    ap.write(t);
                end

                while (vif.instr_req_valid && vif.rst_n) @(posedge vif.clk);
            end
        end
    endtask

endclass
