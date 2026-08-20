// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Constrained-random traffic.
//
// The directed sequences each prove one contract with the smallest stimulus
// that can prove it, which is what makes them readable and what makes them
// blind: every access in them was placed by someone who already knew what the
// cache would do. This sequence exists for the interactions nobody wrote down —
// an eviction landing on the line a queued invalidate is about to clear, a
// refill that starts while the previous store is still draining to memory.
//
// It checks nothing itself. The scoreboard, the burst checker and the bound
// assertions do the checking; this only produces traffic they can judge, which
// is why it can afford to be as unstructured as it is.
//
// Ordering is still one command at a time, because the DUT is blocking and its
// drivers wait for `busy` to fall. The randomness is in what is asked for and
// where, not in overlapping commands the contract does not permit.
class cache_random_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_random_vseq)

    // Overridden by cache_random_test from +TRAFFIC_OPS.
    int unsigned op_count = 400;

    // Per-op tallies, reported at the end so a run states what it actually did
    // rather than only that it finished.
    protected int unsigned n_read, n_write, n_fetch, n_both;
    protected int unsigned n_maint, n_maint_busy, n_reset;

    function new(string name = "cache_random_vseq");
        super.new(name);
    endfunction

    task body();
        cache_traffic_item item;

        `uvm_info("TRAFFIC",
                  $sformatf("random traffic: %0d ops, data region [0,0x%0h), instr region [0x%0h,0x%0h), %0d data aliases over %0d sets",
                            op_count, cache_traffic_item::REGION_BYTES,
                            cache_traffic_item::INSTR_REGION_BASE,
                            cache_traffic_item::INSTR_REGION_BASE + cache_traffic_item::REGION_BYTES,
                            cache_traffic_item::DATA_ALIASES, L1_DATA_SET_COUNT_P), UVM_LOW)

        wait_idle("random traffic entry");

        for (int unsigned i = 0; i < op_count; i++) begin
            item = cache_traffic_item::type_id::create("item");
            if (item.randomize() == 0)
                `uvm_fatal("RANDFAIL", "cache_traffic_item randomization failed")

            dispatch(item, i);

            // Progress on a long soak, so a run that is working is
            // distinguishable from a run that is stuck.
            if ((op_count >= 200) && (((i + 1) % 100) == 0))
                `uvm_info("TRAFFIC", $sformatf("%0d/%0d ops issued", i + 1, op_count), UVM_LOW)
        end

        wait_idle("random traffic exit");

        `uvm_info("TRAFFIC",
                  $sformatf("issued %0d reads, %0d writes, %0d fetches, %0d concurrent read+fetch, %0d maintenance (%0d mid-traffic), %0d resets",
                            n_read, n_write, n_fetch, n_both, n_maint, n_maint_busy, n_reset), UVM_LOW)

        if ((n_read + n_write + n_fetch) == 0)
            `uvm_error("NO_TRAFFIC", "random traffic produced no CPU accesses")
    endtask

    protected task dispatch(cache_traffic_item item, int unsigned index);
        string       tag = $sformatf("random[%0d] %s/%s", index, item.op.name(), item.addr_mode.name());
        int unsigned reads_before = read_count();

        // Full history of what was asked for, at MEDIUM so it stays out of the
        // way of a normal run. Random stimulus is only debuggable if the run can
        // say what it did: a failure names an address, and the first question is
        // always what touched that address before.
        `uvm_info("TRAFFIC_OP",
                  $sformatf("%0s data=0x%0h line=0x%0h instr=0x%0h wdata=0x%0h wstrb=0x%0h",
                            tag, item.data_addr(), item.data_line_addr(),
                            item.instr_addr(), item.wdata, item.wstrb), UVM_MEDIUM)

        case (item.op)
            TRAF_DATA_READ: begin
                n_read++;
                data_read(item.data_addr(), tag);
            end

            TRAF_DATA_WRITE: begin
                n_write++;
                data_write(item.data_addr(), item.wdata, item.wstrb, tag);
            end

            TRAF_INSTR_FETCH: begin
                n_fetch++;
                instr_fetch(item.instr_addr(), tag);
            end

            // The one command overlap the contract permits. Both ports share
            // `busy`, so this is the only stimulus that can show one port's miss
            // handling corrupting the other's response.
            TRAF_READ_AND_FETCH: begin
                n_both++;
                n_read++;
                n_fetch++;
                data_and_instr_read(item.data_addr(), item.instr_addr(), tag);
            end

            TRAF_MAINT_GLOBAL_INVALIDATE: begin
                n_maint++;
                global_invalidate(tag);
            end

            TRAF_MAINT_GLOBAL_FLUSH: begin
                n_maint++;
                global_flush(tag);
            end

            TRAF_MAINT_LINE_INVALIDATE: begin
                n_maint++;
                line_invalidate(item.data_line_addr(), tag);
            end

            TRAF_MAINT_LINE_FLUSH: begin
                n_maint++;
                line_flush(item.data_line_addr(), tag);
            end

            TRAF_MAINT_WHILE_BUSY: begin
                n_maint++;
                n_maint_busy++;
                maint_during_traffic(item, tag);
            end

            // Reset lands between commands rather than inside one: the drivers
            // already wait for `busy` to fall, so the cache is idle here. What
            // it tests is that the cache comes back empty and refills correctly
            // from a memory that reset did not touch — which is also the check
            // that catches a write-through that never reached memory.
            TRAF_RESET: begin
                n_reset++;
                `uvm_info("TRAFFIC", $sformatf("%s: %0d cycles", tag, item.reset_cycles), UVM_MEDIUM)
                reset_pulse(item.reset_cycles);
                wait_idle(tag);
            end
        endcase

        // Whether the op went to memory, which is the first question to ask of a
        // read that returned the wrong value. A wrong value with no memory read
        // was answered from inside the cache, so the fault is in what the cache
        // was holding; a wrong value *with* a memory read means memory itself
        // holds the wrong thing, and the fault is upstream in write-through.
        // Recording it per op is what makes that a lookup rather than a rerun.
        `uvm_info("TRAFFIC_OP",
                  $sformatf("%0s done, memory reads +%0d",
                            tag, read_count() - reads_before), UVM_MEDIUM)
    endtask

    // Maintenance raised while a miss is in flight, then released after a single
    // cycle. This is the path the `busy` widening changed: maintenance executes
    // only when cache traffic has drained, so extending `busy` over the
    // write-through pipeline also moved when a queued command is allowed to
    // retire. Landing it at random points in random traffic is the stress that
    // directed tests cannot provide, because a directed test has to pick one
    // point.
    protected task maint_during_traffic(cache_traffic_item item, string tag);
        fork
            data_read(item.data_addr(), tag);

            begin
                // Ride into the transaction before raising the request, so this
                // does not quietly degenerate into the idle case.
                wait (vif.data_req_read);
                repeat (2) @(posedge vif.clk);
                maint_cmd(.flush(0), .invalidate(0), .flush_line(0), .invalidate_line(1),
                          .addr_valid(1), .addr(item.data_line_addr()), .expect_error(0),
                          .label(tag), .issue_while_busy(1), .pulse_only(1));
            end
        join
    endtask

endclass
