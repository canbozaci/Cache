// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Maintenance issued while the cache is mid-miss.
//
// `maint_ready` is not a request gate — the integrator is allowed to raise a
// maintenance request at any time, and the cache must queue it behind the
// in-flight transaction rather than reject it. This checks the request is
// accepted (no error), survives being released after a single cycle, and
// actually takes effect once the cache drains.
class cache_busy_maint_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_busy_maint_vseq)

    function new(string name = "cache_busy_maint_vseq");
        super.new(name);
    endfunction

    task body();
        int unsigned reads_before;

        wait_idle("busy maintenance idle entry");

        fork
            // A cold read of a different line, to guarantee the cache is busy.
            data_read(NEXT_LINE_ADDR, "busy maintenance in-flight read");

            begin
                // Wait for the miss to actually make the cache busy before
                // issuing maintenance, otherwise this degenerates into the
                // ordinary idle case.
                wait (vif.data_req_read);
                repeat (2) @(posedge vif.clk);
                if (!vif.busy)
                    `uvm_error("BUSY_EXPECTED",
                               "expected the data miss to assert busy before maintenance")

                // Single-cycle request, released while still busy.
                maint_cmd(.flush(0), .invalidate(0), .flush_line(0), .invalidate_line(1),
                          .addr_valid(1), .addr('0), .expect_error(0),
                          .label("busy queued line invalidate"),
                          .issue_while_busy(1), .pulse_only(1));
            end
        join

        wait_idle("busy maintenance idle exit");

        // The queued invalidate must have taken effect on line 0.
        reads_before = read_count();
        data_read('0, "busy maintenance refill after queued line invalidate");
        expect_memory_reads(reads_before, "busy maintenance refill after queued line invalidate");
    endtask

endclass
