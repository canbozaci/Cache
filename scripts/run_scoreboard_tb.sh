#!/usr/bin/env bash
set -euo pipefail

mkdir -p sim/build
iverilog -g2012 -o sim/build/cache_scoreboard_tb.vvp -f filelists/scoreboard_tb.f
vvp sim/build/cache_scoreboard_tb.vvp

iverilog -g2012 -o sim/build/cache_scoreboard_dw32_tb.vvp \
  -P cache_scoreboard_tb.DATA_WIDTH=32 \
  -f filelists/scoreboard_tb.f
vvp sim/build/cache_scoreboard_dw32_tb.vvp

iverilog -g2012 -o sim/build/cache_scoreboard_mem64_tb.vvp \
  -P cache_scoreboard_tb.MEM_DATA_WIDTH=64 \
  -f filelists/scoreboard_tb.f
vvp sim/build/cache_scoreboard_mem64_tb.vvp

iverilog -g2012 -o sim/build/cache_scoreboard_line256_tb.vvp \
  -P cache_scoreboard_tb.LINE_WIDTH=256 \
  -f filelists/scoreboard_tb.f
vvp sim/build/cache_scoreboard_line256_tb.vvp

iverilog -g2012 -o sim/build/cache_scoreboard_addr20_tb.vvp \
  -P cache_scoreboard_tb.ADDR_WIDTH=20 \
  -f filelists/scoreboard_tb.f
vvp sim/build/cache_scoreboard_addr20_tb.vvp
