// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Observes maintenance commands from request to retirement.
class cache_maint_monitor extends uvm_monitor;

    cache_vif_t vif;
    cache_ctx   ctx;

    uvm_analysis_port #(cache_maint_obs_txn) ap;

    `uvm_component_utils(cache_maint_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_maint_monitor")
        if (!uvm_config_db#(cache_ctx)::get(this, "", "ctx", ctx))
            `uvm_fatal("NOCTX", "cache_ctx not set for cache_maint_monitor")
    endfunction

    protected function bit any_request();
        return vif.maint_flush_req || vif.maint_invalidate_req ||
               vif.maint_flush_line_req || vif.maint_invalidate_line_req;
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && any_request()) begin
                cache_maint_obs_txn t = cache_maint_obs_txn::type_id::create("t");
                t.flush_req           = vif.maint_flush_req;
                t.invalidate_req      = vif.maint_invalidate_req;
                t.flush_line_req      = vif.maint_flush_line_req;
                t.invalidate_line_req = vif.maint_invalidate_line_req;
                t.addr_valid          = vif.maint_addr_valid;
                t.addr                = vif.maint_addr;
                t.label               = ctx.label;
                t.expect_error        = ctx.maint_expect_error;

                // The request may be released before completion (the queued
                // maintenance case), so track done/error rather than the
                // request bits.
                fork
                    begin
                        int unsigned timeout = 0;
                        while (!vif.maint_done && !vif.maint_error) begin
                            @(posedge vif.clk);
                            if (++timeout > cache_sync::TIMEOUT_CYCLES) begin
                                `uvm_error("TIMEOUT",
                                           $sformatf("%0s maintenance never retired", t.label))
                                break;
                            end
                        end
                    end
                    cache_sync::wait_reset_assert(vif);
                join_any
                disable fork;

                // A command that reset cancelled never retired, so it has no
                // outcome to check.
                if (vif.rst_n) begin
                    t.ready = vif.maint_ready;
                    t.done  = vif.maint_done;
                    t.error = vif.maint_error;
                    ap.write(t);
                end

                while (any_request() && vif.rst_n) @(posedge vif.clk);
            end
        end
    endtask

endclass
