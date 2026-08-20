// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// A written line, pushed out of L1, then read back.
//
// Write-through installs a store in three places: the L1 data array, the L2
// array, and main memory. Every existing read-back test is answered by L1,
// because L1 is where the line still is — so if the L2 copy were wrong, nothing
// would notice until L1 lost the line and L2 became the thing answering.
//
// That is what this arranges, with the smallest stimulus that can: write a
// line, then touch two other lines that alias it in L1 so its set fills up and
// it is evicted, then read it back. L1 is two-way, so two aliases are exactly
// enough.
//
// This was reduced from a random-traffic failure via a concurrent fetch/read
// thrash loop, both of which reached it by accident. Neither the fetch port nor
// the concurrency turned out to be necessary; the eviction is the whole trigger.
class cache_write_evict_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_write_evict_vseq)

    // Clear of the addresses other directed sequences leave in a known state.
    static const bit [ADDR_WIDTH_P-1:0] BASE = ADDR_WIDTH_P'('h0200);

    function new(string name = "cache_write_evict_vseq");
        super.new(name);
    endfunction

    task body();
        bit [DATA_WIDTH_P-1:0] payload = {DATA_WIDTH_P/16{16'hbeef}};
        int unsigned           reads_before;

        global_invalidate("write/evict: start from an empty cache");

        data_write(BASE, payload, '1, "write/evict: store the line");
        data_read(BASE, "write/evict: value is correct while L1 holds it");

        // Two aliases of the same L1 set, which is two-way. After these the
        // written line can no longer be in L1, so whatever answers the read
        // below is L2 or main memory rather than the copy the store wrote
        // directly.
        data_read(BASE + L1_ALIAS_STRIDE,
                  "write/evict: first alias fills the set");
        data_read(BASE + (L1_ALIAS_STRIDE * 2),
                  "write/evict: second alias evicts the written line");

        reads_before = read_count();
        data_read(BASE, "write/evict: value must survive eviction from L1");

        // Logged rather than asserted. Whether L2 or main memory answers depends
        // on whether the two aliases above also collide in L2, which varies with
        // L2_SET_COUNT across the configuration matrix. The value has to be
        // right either way, and that is what the scoreboard checks; this line
        // just records which path was exercised.
        `uvm_info("WRITE_EVICT",
                  $sformatf("read after eviction took %0d memory read(s) (0 means L2 answered it)",
                            read_count() - reads_before), UVM_LOW)

        // Same again for a partial store, which has to merge with the rest of
        // the line rather than replace it.
        data_write(BASE, ~payload, 'h3, "write/evict: partial store");
        data_read(BASE + L1_ALIAS_STRIDE,  "write/evict: refill alias one");
        data_read(BASE + (L1_ALIAS_STRIDE * 2), "write/evict: refill alias two");
        data_read(BASE, "write/evict: partial store must survive eviction too");

        wait_idle("write/evict exit");
    endtask

endclass
