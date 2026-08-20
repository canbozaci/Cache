// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// The documented I/D incoherency limitation, checked as a contract rather than
// tolerated as a bug.
//
// This cache is non-coherent between its instruction and data sides: a
// data-side write does not update an already-resident instruction line. That is
// a real constraint on integrators, who must invalidate before fetching
// freshly written code. Pinning it down with a test is what makes it a
// specification instead of an accident — if a future change made the
// instruction side coherent, this sequence would fail and force the
// documentation to be updated with it.
class cache_id_incoherency_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_id_incoherency_vseq)

    function new(string name = "cache_id_incoherency_vseq");
        super.new(name);
    endfunction

    task body();
        bit [ADDR_WIDTH_P-1:0]     test_addr = ADDR_WIDTH_P'(NEXT_LINE_ADDR * 4);
        bit [31:0]                 stale_instr;
        bit [DATA_WIDTH_P-1:0]     wdata = '0;
        bit [(DATA_WIDTH_P/8)-1:0] wstrb = '0;

        // Capture what the instruction side is about to cache.
        stale_instr = ref_model.read_instr(32'(test_addr));
        instr_fetch(test_addr, "i/d coherency prime instruction line");

        // Change the byte from the data side.
        wdata[7:0] = stale_instr[7:0] ^ 8'h5a;
        wstrb[0]   = 1'b1;
        data_write(test_addr, wdata, wstrb, "i/d coherency data-side write");

        // The instruction side must still return the pre-write value. This is
        // checked against the captured value, not the reference model, because
        // the reference model has already taken the write.
        instr_fetch_expect(test_addr, stale_instr,
                           "i/d coherency documented stale instruction hit");

        // Invalidation is the documented recovery path.
        line_invalidate(test_addr, "i/d coherency line invalidate recovery");
        instr_fetch(test_addr, "i/d coherency instruction refill after invalidate");
    endtask

endclass
