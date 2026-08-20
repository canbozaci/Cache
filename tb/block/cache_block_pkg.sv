// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Block-level UVM environment for the cache's leaf modules.
//
// Geometry is fixed rather than swept. These DUTs are exercised for their
// internal behaviour — byte-lane placement, valid-bit handling, replacement
// decisions — which is what the cache-top configuration matrix cannot reach.
// Sweeping widths here would multiply runtime without testing anything the top
// level does not already cover.
package cache_block_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int BLK_LINE_WIDTH     = 128;
    parameter int BLK_DATA_WIDTH     = 64;
    parameter int BLK_MEM_DATA_WIDTH = 32;
    parameter int BLK_ADDR_WIDTH     = 19;
    parameter int BLK_INDEX_WIDTH    = 2;
    parameter int BLK_SET_COUNT      = 4;
    parameter int BLK_TAG_WIDTH      = 5;
    parameter int BLK_L2_ADDR_WIDTH  = BLK_ADDR_WIDTH - 4;

    `include "block/agents/block_agent/cache_block_txn.sv"
    `include "block/agents/block_agent/cache_block_obs_txn.sv"
    `include "block/agents/block_agent/cache_block_sequencer.sv"
    `include "block/agents/block_agent/cache_block_driver.sv"
    `include "block/agents/block_agent/cache_block_agent.sv"

    `include "block/env/cache_block_scoreboard.sv"
    `include "block/env/cache_block_env.sv"

    `include "block/seq/cache_block_base_seq.sv"
    `include "block/seq/cache_block_full_seq.sv"

    `include "block/tests/cache_block_test.sv"

endpackage
