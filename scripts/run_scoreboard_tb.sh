#!/usr/bin/env bash
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
run_case "addr20" -P cache_scoreboard_tb.ADDR_WIDTH=20
run_case "ready_stalls" -P cache_scoreboard_tb.MEM_READY_STALLS=1
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
