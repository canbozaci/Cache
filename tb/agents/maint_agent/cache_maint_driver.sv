// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_maint_driver extends uvm_driver #(cache_maint_txn);

    cache_vif_t vif;

    `uvm_component_utils(cache_maint_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_maint_driver")
    endfunction

    task run_phase(uvm_phase phase);
        clear_requests();
        // See cache_data_driver for why items race against reset.
        forever begin
            seq_item_port.get_next_item(req);
            fork
                drive(req);
                cache_sync::wait_reset_assert(vif);
            join_any
            disable fork;
            if (!vif.rst_n) clear_requests();
            seq_item_port.item_done();
        end
    endtask

    protected function void clear_requests();
        vif.maint_flush_req           = 1'b0;
        vif.maint_invalidate_req      = 1'b0;
        vif.maint_flush_line_req      = 1'b0;
        vif.maint_invalidate_line_req = 1'b0;
        vif.maint_addr_valid          = 1'b0;
        vif.maint_addr                = '0;
    endfunction

    protected task drive(cache_maint_txn t);
        // Normal maintenance is issued from an idle cache. The busy case
        // deliberately skips this so the command lands mid-transaction.
        if (!t.issue_while_busy)
            cache_sync::wait_for_idle(vif, t.label);

        @(negedge vif.clk);
        vif.maint_addr                = t.addr;
        vif.maint_addr_valid          = t.addr_valid;
        vif.maint_flush_req           = t.flush_req;
        vif.maint_invalidate_req      = t.invalidate_req;
        vif.maint_flush_line_req      = t.flush_line_req;
        vif.maint_invalidate_line_req = t.invalidate_line_req;

        if (t.pulse_only) begin
            // One cycle of request, then release. The cache must latch the
            // command and retire it after the in-flight transaction drains.
            @(posedge vif.clk);
            @(negedge vif.clk);
            clear_requests();
            cache_sync::wait_for_maint_complete(vif, t.label);
        end else begin
            cache_sync::wait_for_maint_complete(vif, t.label);
            @(negedge vif.clk);
            clear_requests();
        end

        if (!t.issue_while_busy)
            cache_sync::wait_for_idle(vif, t.label);
    endtask

endclass
