#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci

set -euo pipefail

mkdir -p sim/build

run_case() {
  local name="$1"
  shift

  printf "SCOREBOARD: %s\n" "$name"
  iverilog -g2012 -o "sim/build/cache_scoreboard_${name}_tb.vvp" "$@" -f filelists/scoreboard_tb.f
  vvp "sim/build/cache_scoreboard_${name}_tb.vvp"
}

run_case "default"
run_case "dw32" -P cache_scoreboard_tb.DATA_WIDTH=32
run_case "mem64" -P cache_scoreboard_tb.MEM_DATA_WIDTH=64
run_case "line256" -P cache_scoreboard_tb.LINE_WIDTH=256
run_case "set_counts" \
  -P cache_scoreboard_tb.L1_SET_COUNT=32 \
  -P cache_scoreboard_tb.L2_SET_COUNT=128
run_case "small_set_counts" \
  -P cache_scoreboard_tb.L1_SET_COUNT=16 \
  -P cache_scoreboard_tb.L2_SET_COUNT=64
run_case "split_l1_set_counts" \
  -P cache_scoreboard_tb.L1_DATA_SET_COUNT=32 \
  -P cache_scoreboard_tb.L1_INSTR_SET_COUNT=64 \
  -P cache_scoreboard_tb.L2_SET_COUNT=128
run_case "split_l1_set_counts_alt" \
  -P cache_scoreboard_tb.L1_DATA_SET_COUNT=64 \
  -P cache_scoreboard_tb.L1_INSTR_SET_COUNT=32 \
  -P cache_scoreboard_tb.L2_SET_COUNT=128
run_case "dw128_line256" \
  -P cache_scoreboard_tb.DATA_WIDTH=128 \
  -P cache_scoreboard_tb.LINE_WIDTH=256
run_case "addr20" -P cache_scoreboard_tb.ADDR_WIDTH=20
run_case "ready_stalls" -P cache_scoreboard_tb.MEM_READY_STALLS=1
run_case "rsp_latency_2" -P cache_scoreboard_tb.MEM_RSP_EXTRA_LATENCY=2
run_case "rsp_variable_latency" -P cache_scoreboard_tb.MEM_RSP_VARIABLE_LATENCY=1
run_case "read_error_first" -P cache_scoreboard_tb.MEM_RD_ERROR_BEAT=0
run_case "read_error_middle" -P cache_scoreboard_tb.MEM_RD_ERROR_BEAT=2
run_case "read_error_last" -P cache_scoreboard_tb.MEM_RD_ERROR_BEAT=3
run_case "write_error" -P cache_scoreboard_tb.MEM_WR_ERROR_ENABLE=1
run_case "write_rsp_latency" -P cache_scoreboard_tb.MEM_WR_RSP_EXTRA_LATENCY=3
run_case "instr_rsp_backpressure" -P cache_scoreboard_tb.INSTR_RSP_BACKPRESSURE=1
run_case "data_rsp_backpressure" -P cache_scoreboard_tb.DATA_RSP_BACKPRESSURE=1
run_case "addr20_dw32" \
  -P cache_scoreboard_tb.ADDR_WIDTH=20 \
  -P cache_scoreboard_tb.DATA_WIDTH=32
run_case "mem64_line256" \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -P cache_scoreboard_tb.LINE_WIDTH=256
run_case "addr20_mem64_line256" \
  -P cache_scoreboard_tb.ADDR_WIDTH=20 \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -P cache_scoreboard_tb.LINE_WIDTH=256
run_case "dw32_mem64_line256" \
  -P cache_scoreboard_tb.DATA_WIDTH=32 \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -P cache_scoreboard_tb.LINE_WIDTH=256
run_case "dw128_mem64_line256" \
  -P cache_scoreboard_tb.DATA_WIDTH=128 \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -P cache_scoreboard_tb.LINE_WIDTH=256
run_case "geometry_dw32_mem64_line256" \
  -P cache_scoreboard_tb.ADDR_WIDTH=20 \
  -P cache_scoreboard_tb.DATA_WIDTH=32 \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -P cache_scoreboard_tb.LINE_WIDTH=256 \
  -P cache_scoreboard_tb.L1_DATA_SET_COUNT=32 \
  -P cache_scoreboard_tb.L1_INSTR_SET_COUNT=64 \
  -P cache_scoreboard_tb.L2_SET_COUNT=128
run_case "geometry_dw128_mem64_line256" \
  -P cache_scoreboard_tb.DATA_WIDTH=128 \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -P cache_scoreboard_tb.LINE_WIDTH=256 \
  -P cache_scoreboard_tb.L1_SET_COUNT=32 \
  -P cache_scoreboard_tb.L2_SET_COUNT=128
