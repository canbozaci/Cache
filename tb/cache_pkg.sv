// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Can Bozaci

// Cache geometry, mirrored from the DUT parameters.
//
// These are `define`-driven compile-time constants rather than class
// parameters. The cache's geometry changes port widths, field widths and the
// beat structure of every burst, so a run is tied to one geometry anyway; the
// parameter sweep recompiles per configuration, which is what the legacy
// testbench's -P sweep did too. Making the classes parameterized would buy
// nothing and cost a type parameter on every handle in the environment.
//
// Runtime-only knobs (memory ready stalls, response latency) deliberately live
// in cache_env_cfg instead, because they do not change any width and so do not
// justify a rebuild.

`ifndef CACHE_ADDR_WIDTH
  `define CACHE_ADDR_WIDTH 19
`endif
`ifndef CACHE_DATA_WIDTH
  `define CACHE_DATA_WIDTH 64
`endif
`ifndef CACHE_MEM_DATA_WIDTH
  `define CACHE_MEM_DATA_WIDTH 32
`endif
`ifndef CACHE_LINE_WIDTH
  `define CACHE_LINE_WIDTH 128
`endif
`ifndef CACHE_L1_SET_COUNT
  `define CACHE_L1_SET_COUNT 64
`endif
`ifndef CACHE_L1_DATA_SET_COUNT
  `define CACHE_L1_DATA_SET_COUNT `CACHE_L1_SET_COUNT
`endif
`ifndef CACHE_L1_INSTR_SET_COUNT
  `define CACHE_L1_INSTR_SET_COUNT `CACHE_L1_SET_COUNT
`endif
`ifndef CACHE_L2_SET_COUNT
  `define CACHE_L2_SET_COUNT 256
`endif

package cache_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int ADDR_WIDTH_P          = `CACHE_ADDR_WIDTH;
    parameter int DATA_WIDTH_P          = `CACHE_DATA_WIDTH;
    parameter int MEM_DATA_WIDTH_P      = `CACHE_MEM_DATA_WIDTH;
    parameter int LINE_WIDTH_P          = `CACHE_LINE_WIDTH;
    parameter int L1_SET_COUNT_P        = `CACHE_L1_SET_COUNT;
    parameter int L1_DATA_SET_COUNT_P   = `CACHE_L1_DATA_SET_COUNT;
    parameter int L1_INSTR_SET_COUNT_P  = `CACHE_L1_INSTR_SET_COUNT;
    parameter int L2_SET_COUNT_P        = `CACHE_L2_SET_COUNT;

    typedef virtual cache_if #(
        .ADDR_WIDTH(ADDR_WIDTH_P),
        .DATA_WIDTH(DATA_WIDTH_P),
        .MEM_DATA_WIDTH(MEM_DATA_WIDTH_P)
    ) cache_vif_t;

    // ---- shared infrastructure ------------------------------------------
    `include "env/cache_env_cfg.sv"
    `include "env/cache_ref_model.sv"
    `include "env/cache_ctx.sv"
    `include "env/cache_sync.sv"

    // ---- agents ----------------------------------------------------------
    `include "agents/data_agent/cache_data_txn.sv"
    `include "agents/data_agent/cache_data_obs_txn.sv"
    `include "agents/data_agent/cache_data_sequencer.sv"
    `include "agents/data_agent/cache_data_driver.sv"
    `include "agents/data_agent/cache_data_monitor.sv"
    `include "agents/data_agent/cache_data_agent.sv"

    `include "agents/instr_agent/cache_instr_txn.sv"
    `include "agents/instr_agent/cache_instr_obs_txn.sv"
    `include "agents/instr_agent/cache_instr_sequencer.sv"
    `include "agents/instr_agent/cache_instr_driver.sv"
    `include "agents/instr_agent/cache_instr_monitor.sv"
    `include "agents/instr_agent/cache_instr_agent.sv"

    `include "agents/maint_agent/cache_maint_txn.sv"
    `include "agents/maint_agent/cache_maint_obs_txn.sv"
    `include "agents/maint_agent/cache_maint_sequencer.sv"
    `include "agents/maint_agent/cache_maint_driver.sv"
    `include "agents/maint_agent/cache_maint_monitor.sv"
    `include "agents/maint_agent/cache_maint_agent.sv"

    `include "agents/mem_agent/cache_mem_obs_txn.sv"
    `include "agents/mem_agent/cache_mem_driver.sv"
    `include "agents/mem_agent/cache_mem_monitor.sv"
    `include "agents/mem_agent/cache_mem_agent.sv"

    // ---- env -------------------------------------------------------------
    `include "env/cache_scoreboard.sv"
    `include "env/cache_mem_checker.sv"
    `include "env/cache_vsqr.sv"
    `include "env/cache_env.sv"

    // ---- sequences -------------------------------------------------------
    `include "seq/cache_base_vseq.sv"
    `include "seq/cache_maint_vseq.sv"
    `include "seq/cache_illegal_maint_vseq.sv"
    `include "seq/cache_line_maint_vseq.sv"
    `include "seq/cache_busy_maint_vseq.sv"
    `include "seq/cache_reset_vseq.sv"
    `include "seq/cache_replacement_vseq.sv"
    `include "seq/cache_id_incoherency_vseq.sv"
    `include "seq/cache_write_vseq.sv"
    `include "seq/cache_concurrent_vseq.sv"
    `include "seq/cache_write_invalidate_vseq.sv"
    `include "seq/cache_write_evict_vseq.sv"
    `include "seq/cache_wt_l2_vseq.sv"
    `include "seq/cache_full_vseq.sv"
    `include "seq/cache_traffic_item.sv"
    `include "seq/cache_random_vseq.sv"

    // ---- tests -----------------------------------------------------------
    `include "tests/cache_base_test.sv"
    `include "tests/cache_full_test.sv"
    `include "tests/cache_random_test.sv"

endpackage
