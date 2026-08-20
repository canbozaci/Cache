// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// L1 replacement, using three lines that alias to the same L1 set.
//
// Checking data values alone would not catch a broken replacement policy — the
// data stays correct whether or not the right way was evicted, because a wrong
// eviction just costs a refill. The policy is only observable through memory
// traffic, so this sequence asserts on hits and misses rather than on data.
class cache_replacement_vseq extends cache_base_vseq;

    `uvm_object_utils(cache_replacement_vseq)

    function new(string name = "cache_replacement_vseq");
        super.new(name);
    endfunction

    task body();
        bit [ADDR_WIDTH_P-1:0] alias_0 = 'h100;
        bit [ADDR_WIDTH_P-1:0] alias_1 = ADDR_WIDTH_P'(alias_0 + L1_ALIAS_STRIDE);
        bit [ADDR_WIDTH_P-1:0] alias_2 = ADDR_WIDTH_P'(alias_1 + L1_ALIAS_STRIDE);
        int unsigned reads_before;

        // Fill both ways of the set.
        data_read(alias_0, "l1 replacement fill way 0");
        data_read(alias_1, "l1 replacement fill way 1");

        // Touching alias_0 must hit, and must also make it the more recently
        // used of the two.
        reads_before = read_count();
        data_read(alias_0, "l1 replacement update lru hit");
        expect_no_memory_reads(reads_before, "l1 replacement update lru hit");

        // A third alias forces an eviction, which must claim alias_1 — the
        // least recently used way — not alias_0.
        data_read(alias_2, "l1 replacement force eviction");
        reads_before = read_count();
        data_read(alias_1, "l1 replacement evicted line refills");
        expect_memory_reads(reads_before, "l1 replacement evicted line refills");
    endtask

endclass
