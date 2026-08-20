// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// The full directed regression.
//
// The step order is load-bearing and is preserved deliberately. Several
// contracts are only meaningful against a particular cache state — the line
// maintenance checks need line 0 resident, the queued-maintenance check needs
// line 0 resident again afterwards, and the replacement check needs its alias
// set untouched. Reordering these would not fail; it would silently stop
// testing what they claim to test.
class cache_full_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_full_vseq)

    function new(string name = "cache_full_vseq");
        super.new(name);
    endfunction

    task body();
        cache_maint_vseq          maint_seq;
        cache_illegal_maint_vseq  illegal_seq;
        cache_reset_vseq          reset_seq;
        cache_line_maint_vseq     line_maint_seq;
        cache_busy_maint_vseq     busy_maint_seq;
        cache_id_incoherency_vseq id_seq;
        cache_write_vseq          write_seq;
        cache_replacement_vseq    repl_seq;
        cache_concurrent_vseq     concurrent_seq;
        cache_write_invalidate_vseq write_inv_seq;
        cache_write_evict_vseq      write_evict_seq;
        cache_wt_l2_vseq            wt_l2_seq;

        // --- maintenance and reset, before any data is cached --------------
        maint_seq = cache_maint_vseq::type_id::create("maint_seq");
        maint_seq.start(p_sequencer);

        illegal_seq = cache_illegal_maint_vseq::type_id::create("illegal_seq");
        illegal_seq.start(p_sequencer);

        reset_seq = cache_reset_vseq::type_id::create("reset_seq");
        reset_seq.start(p_sequencer);

        // --- cold read, then hits in the same line -------------------------
        data_read('h0, "data cold line 0 word 0");
        data_read('h4, "data hit line 0 word 1");
        data_read('h8, "data hit line 0 word 2");

        // Line maintenance runs here because it needs line 0 resident.
        line_maint_seq = cache_line_maint_vseq::type_id::create("line_maint_seq");
        line_maint_seq.start(p_sequencer);

        // Queued maintenance runs here because line maintenance left line 0
        // resident again, which is what makes its refill check meaningful.
        busy_maint_seq = cache_busy_maint_vseq::type_id::create("busy_maint_seq");
        busy_maint_seq.start(p_sequencer);

        data_read('h20, "data cold line 2 word 0");

        // --- instruction side ----------------------------------------------
        instr_fetch('h0, "instruction cold line 0 word 0");
        instr_fetch('h4, "instruction hit line 0 word 1");

        id_seq = cache_id_incoherency_vseq::type_id::create("id_seq");
        id_seq.start(p_sequencer);

        // --- write-through --------------------------------------------------
        write_seq = cache_write_vseq::type_id::create("write_seq");
        write_seq.start(p_sequencer);

        // --- replacement ----------------------------------------------------
        repl_seq = cache_replacement_vseq::type_id::create("repl_seq");
        repl_seq.start(p_sequencer);

        // --- both CPU ports at once -----------------------------------------
        data_and_instr_read('h20, 'h30, "simultaneous data and instruction reads");

        // Both ports resident, as above, only covers the easy half of the
        // contract. The concurrent sequence walks the whole miss/hit matrix,
        // including both sides missing at once, which is where the two ports
        // actually contend for the memory side.
        concurrent_seq = cache_concurrent_vseq::type_id::create("concurrent_seq");
        concurrent_seq.start(p_sequencer);

        // Write-through and line maintenance interact: the invalidate is what
        // removes the cached copy that has been answering read-backs, so this
        // is where a store that never reached memory finally shows up.
        write_inv_seq = cache_write_invalidate_vseq::type_id::create("write_inv_seq");
        write_inv_seq.start(p_sequencer);

        // The same contract against eviction rather than invalidation, which is
        // the case where L2 rather than L1 answers the read.
        write_evict_seq = cache_write_evict_vseq::type_id::create("write_evict_seq");
        write_evict_seq.start(p_sequencer);

        // Write-through has to update L2 as well as L1 and memory. The two
        // sequences above only ever read a line back through one path; this one
        // sweeps the maintenance history that precedes the store, which is what
        // separated a store that reached L2 from one that did not.
        wt_l2_seq = cache_wt_l2_vseq::type_id::create("wt_l2_seq");
        wt_l2_seq.start(p_sequencer);
    endtask

endclass
