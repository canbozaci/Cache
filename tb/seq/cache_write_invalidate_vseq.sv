// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// A written line, invalidated, then read back.
//
// cache_line_maint_vseq already invalidates a line and checks that the next read
// refills. It does so on a line that was only ever *read*, though, so the line
// arrives in the cache by the fill path and leaves by the invalidate path, and
// nothing about the write-through path is involved.
//
// This runs the same contract over a line that was written first. The value has
// to survive in main memory, because the invalidate is precisely what removes
// the cached copy that has been answering the reads until now — so this is the
// combination where a write-through defect and a maintenance defect become
// indistinguishable from each other unless both are checked.
//
// It came out of a random-traffic failure: write, write, line invalidate, read,
// returning zero.
class cache_write_invalidate_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_write_invalidate_vseq)

    // Line-aligned, and clear of the addresses the other directed sequences
    // leave in a particular state.
    static const bit [ADDR_WIDTH_P-1:0] LINE = ADDR_WIDTH_P'('h0200);

    function new(string name = "cache_write_invalidate_vseq");
        super.new(name);
    endfunction

    task body();
        bit [DATA_WIDTH_P-1:0] first  = {DATA_WIDTH_P/16{16'h5a5a}};
        bit [DATA_WIDTH_P-1:0] second = {DATA_WIDTH_P/16{16'ha5a5}};
        int unsigned reads_before;

        // --- full-width store, invalidate, read back ----------------------
        data_write(LINE, first, '1, "write/invalidate: full store");
        data_read(LINE, "write/invalidate: value readable while cached");

        line_invalidate(LINE, "write/invalidate: drop the written line");

        reads_before = read_count();
        data_read(LINE, "write/invalidate: read back after line invalidate");
        expect_memory_reads(reads_before, "write/invalidate: read back after line invalidate");

        // --- partial store into a resident line, then invalidate ----------
        // Byte-strobed stores are the case the random run failed on. A partial
        // store has to merge with what memory already holds, so if the merge
        // happens only in the cache array the invalidate exposes it.
        data_write(LINE, second, 'h2, "write/invalidate: partial store");
        data_read(LINE, "write/invalidate: partial value readable while cached");

        line_invalidate(LINE, "write/invalidate: drop the partially written line");

        reads_before = read_count();
        data_read(LINE, "write/invalidate: read back after partial store");
        expect_memory_reads(reads_before, "write/invalidate: read back after partial store");

        // --- second word of the same line ---------------------------------
        // The random failure read an offset inside the line rather than its
        // base, so the check has to reach a word the invalidate did not target
        // directly but did remove.
        data_write(LINE + ADDR_WIDTH_P'(DATA_WIDTH_P / 8), first, '1,
                   "write/invalidate: store to the second word");
        line_invalidate(LINE, "write/invalidate: drop the line again");
        data_read(LINE + ADDR_WIDTH_P'(DATA_WIDTH_P / 8),
                  "write/invalidate: read the second word after invalidate");

        wait_idle("write/invalidate exit");
    endtask

endclass
