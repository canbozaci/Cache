// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Shared timing helpers for the blocking CPU-side protocol.
//
// The cache has no per-port handshake: `busy` is the single back-pressure
// signal for both CPU ports, so "has my request completed" is a question about
// a global signal, not about a response channel. Every CPU-side driver and
// monitor therefore has to agree bit-for-bit on how long to wait, which is why
// these live in one place instead of being re-derived per component.
class cache_sync;

    // Matches the legacy testbench's watchdog. Long enough for a full line fill
    // at the slowest configured memory latency, short enough to fail the test
    // rather than hang the regression.
    static const int unsigned TIMEOUT_CYCLES = 1000;

    // Wait until the DUT has fully settled: no CPU-side work, no outstanding
    // memory request, no in-flight memory response. The trailing two cycles
    // give the controller time to retire internal state before the next
    // command, which the RTL assumes.
    static task wait_for_idle(cache_vif_t vif, string label);
        int unsigned timeout = 0;
        repeat (2) @(posedge vif.clk);
        while (vif.busy || vif.mem_req_valid || vif.mem_rsp_valid) begin
            @(posedge vif.clk);
            if (++timeout > TIMEOUT_CYCLES) begin
                `uvm_error("TIMEOUT", $sformatf("%0s did not become idle", label))
                return;
            end
        end
        repeat (2) @(posedge vif.clk);
    endtask

    // Wait for a read command to produce its response. Two cycles of command
    // latency, then ride out any miss handling, then one more cycle for the
    // response register to update.
    static task wait_for_read_response(cache_vif_t vif, string label);
        int unsigned timeout = 0;
        repeat (2) @(posedge vif.clk);
        while (vif.busy) begin
            @(posedge vif.clk);
            if (++timeout > TIMEOUT_CYCLES) begin
                `uvm_error("TIMEOUT",
                           $sformatf("%0s read response did not complete", label))
                return;
            end
        end
        @(posedge vif.clk);
    endtask

    // Block until reset asserts. Drivers and monitors race this against their
    // in-flight activity so a mid-transaction reset aborts the transaction
    // instead of hanging on a `busy` that will never fall or publishing a
    // response that was never produced.
    static task wait_reset_assert(cache_vif_t vif);
        while (vif.rst_n) @(posedge vif.clk);
    endtask

    static task wait_reset_release(cache_vif_t vif);
        while (!vif.rst_n) @(posedge vif.clk);
    endtask

    // Wait for a maintenance command to retire, successfully or not.
    static task wait_for_maint_complete(cache_vif_t vif, string label);
        int unsigned timeout = 0;
        @(posedge vif.clk);
        while (!vif.maint_done && !vif.maint_error) begin
            @(posedge vif.clk);
            if (++timeout > TIMEOUT_CYCLES) begin
                `uvm_error("TIMEOUT",
                           $sformatf("%0s maintenance did not complete", label))
                return;
            end
        end
    endtask

endclass
