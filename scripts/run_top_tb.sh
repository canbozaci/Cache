#!/usr/bin/env bash
set -euo pipefail

mkdir -p sim/build
iverilog -g2012 -o sim/build/cache_top_tb.vvp -f filelists/top_tb.f
vvp sim/build/cache_top_tb.vvp
