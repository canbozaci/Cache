#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# The directed UVM scoreboard matrix.
#
# Geometry cases rebuild (widths change); the responder cases reuse the default
# geometry and only pass plusargs, so they cost a simulation each rather than a
# build each.

set -euo pipefail

run() { ./scripts/run_uvm_tb.sh "$@"; }

# --- geometry configurations (rebuild per case) ---------------------------
run default
run dw32                    +define+CACHE_DATA_WIDTH=32
run mem64                   +define+CACHE_MEM_DATA_WIDTH=64
run line256                 +define+CACHE_LINE_WIDTH=256
run set_counts              +define+CACHE_L1_SET_COUNT=32 +define+CACHE_L2_SET_COUNT=128
run small_set_counts        +define+CACHE_L1_SET_COUNT=16 +define+CACHE_L2_SET_COUNT=64
run split_l1_set_counts     +define+CACHE_L1_DATA_SET_COUNT=32 \
                            +define+CACHE_L1_INSTR_SET_COUNT=64 \
                            +define+CACHE_L2_SET_COUNT=128
run split_l1_set_counts_alt +define+CACHE_L1_DATA_SET_COUNT=64 \
                            +define+CACHE_L1_INSTR_SET_COUNT=32 \
                            +define+CACHE_L2_SET_COUNT=128
run dw128_line256           +define+CACHE_DATA_WIDTH=128 +define+CACHE_LINE_WIDTH=256
run addr20                  +define+CACHE_ADDR_WIDTH=20
run addr20_dw32             +define+CACHE_ADDR_WIDTH=20 +define+CACHE_DATA_WIDTH=32
run mem64_line256           +define+CACHE_MEM_DATA_WIDTH=64 +define+CACHE_LINE_WIDTH=256
run addr20_mem64_line256    +define+CACHE_ADDR_WIDTH=20 \
                            +define+CACHE_MEM_DATA_WIDTH=64 \
                            +define+CACHE_LINE_WIDTH=256
run dw32_mem64_line256      +define+CACHE_DATA_WIDTH=32 \
                            +define+CACHE_MEM_DATA_WIDTH=64 \
                            +define+CACHE_LINE_WIDTH=256
run dw128_mem64_line256     +define+CACHE_DATA_WIDTH=128 \
                            +define+CACHE_MEM_DATA_WIDTH=64 \
                            +define+CACHE_LINE_WIDTH=256
run geometry_dw32_mem64_line256 \
                            +define+CACHE_ADDR_WIDTH=20 \
                            +define+CACHE_DATA_WIDTH=32 \
                            +define+CACHE_MEM_DATA_WIDTH=64 \
                            +define+CACHE_LINE_WIDTH=256 \
                            +define+CACHE_L1_DATA_SET_COUNT=32 \
                            +define+CACHE_L1_INSTR_SET_COUNT=64 \
                            +define+CACHE_L2_SET_COUNT=128
run geometry_dw128_mem64_line256 \
                            +define+CACHE_DATA_WIDTH=128 \
                            +define+CACHE_MEM_DATA_WIDTH=64 \
                            +define+CACHE_LINE_WIDTH=256 \
                            +define+CACHE_L1_SET_COUNT=32 \
                            +define+CACHE_L2_SET_COUNT=128

# --- responder configurations (default geometry, plusargs only) -----------
# These reuse the `default` image built above: memory ready stalls and response
# latency are runtime knobs, so recompiling for them would be pure waste.
REUSE_BUILD=default run ready_stalls         -- +MEM_READY_STALLS=1
REUSE_BUILD=default run rsp_latency_2        -- +MEM_RSP_EXTRA_LATENCY=2
REUSE_BUILD=default run rsp_variable_latency -- +MEM_RSP_VARIABLE_LATENCY=1
