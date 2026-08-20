// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Write-through behaviour across byte-strobe and memory-beat boundaries.
//
// The cases are chosen for where the write-through path has to do something
// non-trivial: a single byte at a line base, a fully-strobed aligned word, an
// unaligned store that spans three memory beats, a single byte at an unaligned
// offset, and a partial low-word store. Each is followed by a read back, so a
// store that reaches memory with the wrong strobe or the wrong beat split is
// caught by the value, and the burst checker independently catches it by shape.
class cache_write_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_write_vseq)

    function new(string name = "cache_write_vseq");
        super.new(name);
    endfunction

    task body();
        data_write('h0, 64'h0000_0000_0000_00a5, 8'h01,
                   "single byte write at line base");
        data_read('h0, "read after single byte write");

        data_write('h4, 64'h1122_3344_5566_7788, 8'hff,
                   "aligned 64-bit write at word 1");
        data_read('h4, "read after aligned 64-bit write");

        data_write('h2, 64'haabb_ccdd_eeff_1234, 8'hff,
                   "unaligned 64-bit write crossing three memory beats");
        data_read('h0, "read lower bytes after three-beat write");
        data_read('h8, "read upper bytes after three-beat write");

        data_write('h5, 64'h0000_0000_0000_00cc, 8'h01,
                   "unaligned single byte write");
        data_read('h4, "read after unaligned single byte write");

        data_write('h10, 64'h0000_0000_dead_beef, 8'h0f,
                   "aligned low-word partial write");
        data_read('h10, "read after low-word partial write");

        // Repeat hits after a run of writes: the write path must not have left
        // the L1 line in a state that breaks subsequent hits.
        data_read('h4, "repeat hit after writes");
        data_read('h4, "second repeat hit after writes");

        // Write-through must actually reach memory, not merely update the cache
        // array. Reading back through a hit proves nothing: the array would
        // return the right value even if nothing was ever written out. So the
        // line is invalidated to force the next read to refetch from memory,
        // which is the only way to observe what write-through really produced.
        // A global invalidate is used rather than a line invalidate: the line
        // invalidate left the value reachable from L2, so the read-back never
        // consulted memory and the check proved nothing.
        data_write('h8, 64'hcafe_f00d_1234_5678, 8'hff, "write-through to memory");
        global_invalidate("invalidate everything to force refetch from memory");
        data_read('h8, "read after invalidate must return the written value");
    endtask

endclass
