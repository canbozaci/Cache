// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci
//
// Concurrent instruction fetch and data read, across the miss/hit matrix.
//
// docs/TIMING_CONTRACT.md lists "Fetch + Read" as legal and promises that both
// responses are valid when `busy` returns low. The two ports share `busy` and
// share the L2, so the interesting cases are the ones where they need the
// memory side at the same time: the cache has to arbitrate one line fill behind
// the other without either response being lost.
//
// This came out of a random-traffic failure. The directed suite already issued
// concurrent read+fetch, but only with at least one side resident, so the
// both-miss case had never run.
class cache_concurrent_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_concurrent_vseq)

    // Data and instruction stimulus are kept in separate regions, so a fetch can
    // never alias a line the data side wrote. The IP does not promise I/D
    // coherency, and mixing the two here would be testing an unsupported case
    // instead of the arbitration this is aimed at.
    // Same split as cache_traffic_item: the low half of the reference memory is
    // data, the high half instructions. Anything past REF_BYTES reads as zero in
    // the oracle, so the walk below has to stay inside its half — an address
    // that escapes produces a mismatch that looks exactly like a cache bug.
    static const int unsigned REGION_BYTES  = cache_ref_model::REF_BYTES / 2;
    static const int unsigned I_REGION_BASE = REGION_BYTES;

    static const bit [ADDR_WIDTH_P-1:0] D_BASE = ADDR_WIDTH_P'('h0400);
    static const bit [ADDR_WIDTH_P-1:0] I_BASE = ADDR_WIDTH_P'(I_REGION_BASE + 'h0400);

    // Way-span of each L1, so successive passes collide in the same set with
    // different tags. The two L1s can be sized independently, so they get their
    // own strides rather than sharing the data-side one.
    static const int unsigned D_STRIDE = L1_DATA_SET_COUNT_P  * (LINE_WIDTH_P / 8);
    static const int unsigned I_STRIDE = L1_INSTR_SET_COUNT_P * (LINE_WIDTH_P / 8);

    function new(string name = "cache_concurrent_vseq");
        super.new(name);
    endfunction

    task body();
        bit [DATA_WIDTH_P-1:0] payload = {DATA_WIDTH_P/16{16'hbeef}};

        // ---- both sides cold -------------------------------------------
        global_invalidate("concurrent: empty the cache before the cold case");
        data_and_instr_read(D_BASE, I_BASE,
                            "concurrent cold fetch and cold read");
        wait_idle("concurrent cold");

        // ---- both sides resident ---------------------------------------
        data_and_instr_read(D_BASE, I_BASE,
                            "concurrent warm fetch and warm read");
        wait_idle("concurrent warm");

        // ---- data cold, instruction resident ---------------------------
        line_invalidate(D_BASE + NEXT_LINE_ADDR, "concurrent: cool the data line");
        data_and_instr_read(D_BASE + NEXT_LINE_ADDR, I_BASE,
                            "concurrent warm fetch and cold read");
        wait_idle("concurrent data-cold");

        // ---- instruction cold, data resident ---------------------------
        line_invalidate(I_BASE + NEXT_LINE_ADDR, "concurrent: cool the instruction line");
        data_and_instr_read(D_BASE, I_BASE + NEXT_LINE_ADDR,
                            "concurrent cold fetch and warm read");
        wait_idle("concurrent instr-cold");

        // ---- the case the random run failed on -------------------------
        // A value written through the cache, read back once to prove it is
        // there, then read again concurrently with a cold fetch. The write and
        // the first read are what make a wrong second read unambiguous: the
        // data is known good right up to the moment the fetch joins it.
        global_invalidate("concurrent: empty the cache before the write case");
        data_write(D_BASE, payload, '1, "concurrent: seed a known value");
        data_read(D_BASE, "concurrent: value is readable on its own");
        data_and_instr_read(D_BASE, I_BASE + (NEXT_LINE_ADDR * 2),
                            "concurrent read of a written line with a cold fetch");
        wait_idle("concurrent written-line");

        // ---- sustained alternation -------------------------------------
        // Walk both ports across several lines so each pass evicts what the
        // previous one filled, which is what the random run was doing when it
        // failed rather than any single arrangement.
        // Each half holds this many way-spans, and the walk uses every one of
        // them so the last pass is still inside the reference memory.
        for (int unsigned i = 0; i < (REGION_BYTES / D_STRIDE); i++) begin
            bit [ADDR_WIDTH_P-1:0] d = ADDR_WIDTH_P'(i * D_STRIDE);
            bit [ADDR_WIDTH_P-1:0] a = ADDR_WIDTH_P'(I_REGION_BASE +
                                                     ((i * I_STRIDE) % REGION_BYTES));
            int unsigned reads_before = read_count();

            data_and_instr_read(d, a,
                                $sformatf("concurrent thrash pass %0d", i));

            // Whether the pass went to memory. Successive passes are one L1
            // way-span apart, so they land in the same set with different tags
            // and must start missing once the ways are full. A pass that
            // returns the wrong value *without* reading memory was answered
            // from L2, which points at the fill rather than at the CPU path.
            `uvm_info("CONCURRENT",
                      $sformatf("thrash pass %0d addr=0x%0h memory reads +%0d",
                                i, d, read_count() - reads_before), UVM_LOW)
        end
        wait_idle("concurrent thrash");
    endtask

endclass
