// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

class cache_instr_driver extends uvm_driver #(cache_instr_txn);

    cache_vif_t vif;

    `uvm_component_utils(cache_instr_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_instr_driver")
    endfunction

    task run_phase(uvm_phase phase);
        vif.instr_req_valid = 1'b0;
        vif.instr_req_addr  = '0;
        // See cache_data_driver: items race against reset so a mid-fetch reset
        // aborts cleanly rather than hanging.
        forever begin
            seq_item_port.get_next_item(req);
            fork
                do_fetch(req);
                cache_sync::wait_reset_assert(vif);
            join_any
            disable fork;
            if (!vif.rst_n) begin
                vif.instr_req_valid = 1'b0;
                vif.instr_req_addr  = '0;
            end
            seq_item_port.item_done();
        end
    endtask

    protected task do_fetch(cache_instr_txn t);
        @(negedge vif.clk);
        vif.instr_req_addr  = t.addr;
        vif.instr_req_valid = 1'b1;

        cache_sync::wait_for_read_response(vif, t.label);
        t.rdata = vif.instr_resp_data;

        @(negedge vif.clk);
        vif.instr_req_valid = 1'b0;
        cache_sync::wait_for_idle(vif, t.label);
    endtask

endclass
