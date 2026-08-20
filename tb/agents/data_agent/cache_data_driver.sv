// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Drives the CPU data port. Commands are applied on `negedge` so they are
// stable across the sampling edge, which is the timing the RTL was written
// against.
class cache_data_driver extends uvm_driver #(cache_data_txn);

    cache_vif_t vif;

    `uvm_component_utils(cache_data_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(cache_vif_t)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "virtual interface not set for cache_data_driver")
    endfunction

    // Every item races against reset. Without this a reset applied mid-read
    // would strand the driver waiting on a `busy` that reset already cleared,
    // and leave the request asserted into the next transaction.
    task run_phase(uvm_phase phase);
        idle_signals();
        forever begin
            seq_item_port.get_next_item(req);
            fork
                begin
                    case (req.op)
                        CACHE_DATA_READ:  do_read(req);
                        CACHE_DATA_WRITE: do_write(req);
                    endcase
                end
                cache_sync::wait_reset_assert(vif);
            join_any
            disable fork;
            if (!vif.rst_n) idle_signals();
            seq_item_port.item_done();
        end
    endtask

    protected function void idle_signals();
        vif.data_req_read  = 1'b0;
        vif.data_req_write = 1'b0;
        vif.data_req_addr  = '0;
        vif.data_req_wdata = '0;
        vif.data_req_wstrb = '0;
    endfunction

    // Hold the read command until `busy` clears, then sample the response.
    protected task do_read(cache_data_txn t);
        @(negedge vif.clk);
        vif.data_req_addr  = t.addr;
        vif.data_req_read  = 1'b1;
        vif.data_req_write = 1'b0;

        cache_sync::wait_for_read_response(vif, t.label);
        t.rdata = vif.data_resp_rdata;

        @(negedge vif.clk);
        vif.data_req_read = 1'b0;
        cache_sync::wait_for_idle(vif, t.label);
    endtask

    // Writes are a two-cycle pulse, not a held command: the controller latches
    // the store and completes it through the write-through path, so the command
    // is dropped before waiting for the memory side to drain.
    protected task do_write(cache_data_txn t);
        @(negedge vif.clk);
        vif.data_req_addr  = t.addr;
        vif.data_req_wdata = t.wdata;
        vif.data_req_wstrb = t.wstrb;
        vif.data_req_write = 1'b1;
        vif.data_req_read  = 1'b0;

        repeat (2) @(posedge vif.clk);
        @(negedge vif.clk);
        vif.data_req_write = 1'b0;

        cache_sync::wait_for_idle(vif, t.label);

        vif.data_req_wstrb = '0;
        vif.data_req_wdata = '0;
    endtask

endclass
