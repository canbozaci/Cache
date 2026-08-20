// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Write-through must reach L2, not just L1 and main memory.
//
// Reduced from a random-traffic failure at access 99385 that took roughly
// 45 minutes to reach and did not survive instrumentation: adding probe modules
// shifted the simulation schedule by half a percent, which was enough to move
// the defect out of its window. This sequence recreates the pattern on demand
// instead of waiting for randomness to assemble it.
//
// The observed failure, from a probe on the failing line:
//
//   store hit  -> L1 way written, both memory beats emitted, NO L2 write
//   ...
//   L1 evicts the line
//   refill     -> comes from L2, not memory, and carries the pre-store word
//   read       -> stale, with zero memory reads
//
// Main memory held the correct value the whole time and was never consulted,
// because a line evicted from L1 refills from L2 whenever L2 still has it.
//
// What makes the pattern worth reproducing precisely is that two write-through
// hits to the *same line*, thirty accesses apart, behaved differently: the
// partial store to the upper word reached L2, the full-width store to the lower
// word did not. So the trigger is not "write-through never updates L2" -- it is
// conditional on something in the line's recent history. The knobs below sweep
// the history the failing line actually had: an invalidate, then a flush, then a
// refill, then stores to both words in each order and width.
//
// Two independent checks fire on a failure:
//   - cache_wt_l2_check, at the store itself, on every occurrence
//   - the scoreboard, at the read-back, only when the stale line survives to be
//     read -- which is the rare event that made this a 1-in-300000 defect
class cache_wt_l2_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_wt_l2_vseq)

    // Clear of the fixed addresses the other directed sequences use.
    static const bit [ADDR_WIDTH_P-1:0] BASE = ADDR_WIDTH_P'('h1800);

    // Distinct lines, so a failure in one iteration cannot be masked by the
    // next one refilling the same set.
    static const int unsigned LINE_COUNT = 4;

    function new(string name = "cache_wt_l2_vseq");
        super.new(name);
    endfunction

    // One pass of the pattern. The four bits select which parts of the failing
    // line's history are reproduced.
    task run_pattern(bit [ADDR_WIDTH_P-1:0] line_addr,
                     bit                    do_invalidate,
                     bit                    do_flush,
                     bit                    upper_word_first,
                     bit                    partial_second,
                     bit                    with_fetch,
                     int unsigned           iter);

        // L2 is dual-ported: the instruction port runs its own fills, with its
        // own arming state in cache_l2_replacement, concurrently with data-side
        // write-throughs. The failing random window had fetch traffic
        // immediately before the store, and the quiescent version of this
        // pattern does not reproduce, so instruction activity is swept here as
        // its own dimension. Each iteration uses a distinct instruction line so
        // the fetch genuinely misses and drives a fill rather than hitting.
        bit [ADDR_WIDTH_P-1:0] instr_addr =
            ADDR_WIDTH_P'(cache_traffic_item::INSTR_REGION_BASE +
                          ((iter * 4 * LINE_BYTES) %
                           (cache_traffic_item::REGION_BYTES - LINE_BYTES)));

        bit [ADDR_WIDTH_P-1:0] word0 = line_addr;
        bit [ADDR_WIDTH_P-1:0] word1 = line_addr + (DATA_WIDTH_P / 8);
        bit [DATA_WIDTH_P-1:0] first_val;
        bit [DATA_WIDTH_P-1:0] final_val;
        string                 tag;
        int unsigned           reads_before;

        tag = $sformatf("wt/l2[%0d] addr=0x%0h inv=%0b flush=%0b upper_first=%0b partial=%0b fetch=%0b",
                        iter, line_addr, do_invalidate, do_flush,
                        upper_word_first, partial_second, with_fetch);

        // Seed values that are distinguishable in a log at a glance: the stale
        // value and the expected value must not resemble each other.
        first_val = {32'hda6c0a2f, 32'h59cc44be} ^ {32'(iter), 32'(iter)};
        final_val = {32'hb1b6d110, 32'hc17b3eac} ^ {32'(iter), 32'(iter)};

        // ---- establish the line, then disturb its history ----------------
        data_write(word0, first_val, '1, {tag, ": initial store"});

        if (do_invalidate) line_invalidate(line_addr, {tag, ": invalidate"});
        if (do_flush)      line_flush(line_addr,      {tag, ": flush"});

        // Refill it, so the line is resident and both L1 and L2 hold a copy.
        // With the fetch knob set this is a concurrent data read plus
        // instruction fetch, which is the shape the failing window had.
        if (with_fetch)
            data_and_instr_read(word0, instr_addr,
                                {tag, ": refill with concurrent fetch"});
        else
            data_read(word0, {tag, ": refill after maintenance"});

        // A second, missing fetch immediately before the stores, so an
        // instruction-side L2 fill has just armed when the write-through runs.
        if (with_fetch)
            instr_fetch(instr_addr + ADDR_WIDTH_P'(2 * LINE_BYTES),
                        {tag, ": fetch a further line before the stores"});

        // ---- the two write-through hits that behaved differently ----------
        if (upper_word_first) begin
            data_write(word1, ~first_val, partial_second ? 'hae : '1,
                       {tag, ": store upper word"});
            data_write(word0, final_val, '1, {tag, ": store lower word"});
        end else begin
            data_write(word0, final_val, '1, {tag, ": store lower word"});
            data_write(word1, ~first_val, partial_second ? 'hae : '1,
                       {tag, ": store upper word"});
        end

        // Read both words while L1 still holds the line. These pass even when
        // the defect is present -- L1 is correct; it is L2 that is stale.
        data_read(word0, {tag, ": lower word while L1 holds it"});
        data_read(word1, {tag, ": upper word while L1 holds it"});

        // ---- force L1 to lose the line ------------------------------------
        // L1 is two-way, so two aliases fill the set and evict this line. After
        // this, whatever answers is L2 or main memory.
        data_read(line_addr + L1_ALIAS_STRIDE,
                  {tag, ": alias one fills the set"});
        data_read(line_addr + (L1_ALIAS_STRIDE * 2),
                  {tag, ": alias two evicts the line"});

        // ---- the read that exposes a stale L2 -----------------------------
        reads_before = read_count();
        data_read(word0, {tag, ": lower word must survive eviction"});

        // Logged rather than asserted: whether L2 or main memory answers
        // depends on whether the aliases above also collide in L2, which varies
        // across the configuration matrix. The value must be right either way.
        // Zero memory reads means L2 answered, which is the case that exposes
        // the defect; a non-zero count means memory answered and the stale L2
        // copy went unread this time.
        `uvm_info("WT_L2",
                  $sformatf("%0s: read after eviction took %0d memory read(s)",
                            tag, read_count() - reads_before), UVM_HIGH)

        data_read(word1, {tag, ": upper word must survive eviction"});
    endtask

    task body();
        int unsigned iter = 0;

        global_invalidate("wt/l2: start from an empty cache");

        // Sweep the history knobs across distinct lines. Thirty-two
        // combinations per line, four lines: about a thousand accesses and
        // seconds of simulation, against the 99400 accesses and 45 minutes the
        // random soak needed to reach this defect once.
        for (int unsigned l = 0; l < LINE_COUNT; l++) begin
            bit [ADDR_WIDTH_P-1:0] line_addr =
                BASE + ADDR_WIDTH_P'(l * LINE_BYTES * 4);

            for (int unsigned combo = 0; combo < 32; combo++) begin
                run_pattern(line_addr,
                            combo[0],   // invalidate
                            combo[1],   // flush
                            combo[2],   // upper word stored first
                            combo[3],   // upper store is partial
                            combo[4],   // instruction-port activity
                            iter);
                iter++;
            end
        end

        wait_idle("wt/l2 exit");
    endtask

endclass
