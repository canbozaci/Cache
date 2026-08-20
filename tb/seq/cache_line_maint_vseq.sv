// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Address-selective maintenance. The contract has three distinct parts, and all
// three are about *precision*: invalidating one line must not disturb another,
// flushing must be a no-op on a write-through cache, and invalidating the
// targeted line must actually force a refill.
//
// Each is checked by counting memory reads across the access, because the cache
// exposes no hit/miss signal.
class cache_line_maint_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_line_maint_vseq)

    function new(string name = "cache_line_maint_vseq");
        super.new(name);
    endfunction

    task body();
        int unsigned reads_before;

        wait_idle("line maintenance idle entry");

        // Establish that line 0 is resident to begin with.
        reads_before = read_count();
        data_read('0, "line maintenance pre-hit line 0");
        expect_no_memory_reads(reads_before, "line maintenance pre-hit line 0");

        // Invalidating a different line must leave line 0 alone.
        line_invalidate(NEXT_LINE_ADDR, "line invalidate different line");
        reads_before = read_count();
        data_read('0, "line maintenance hit after other-line invalidate");
        expect_no_memory_reads(reads_before, "line maintenance hit after other-line invalidate");

        // Write-through means a flush has nothing to write back, so it must not
        // evict anything either.
        line_flush('0, "line flush no-op");
        reads_before = read_count();
        data_read('0, "line maintenance hit after line flush");
        expect_no_memory_reads(reads_before, "line maintenance hit after line flush");

        // Invalidating the targeted line must force it to refill.
        line_invalidate('0, "line invalidate line 0");
        reads_before = read_count();
        data_read('0, "line maintenance refill after line invalidate");
        expect_memory_reads(reads_before, "line maintenance refill after line invalidate");

        wait_idle("line maintenance idle exit");
    endtask

endclass
