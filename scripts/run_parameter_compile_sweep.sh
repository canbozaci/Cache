#!/usr/bin/env bash
set -euo pipefail

run_case() {
  local name="$1"
  shift

  printf "PARAMETER COMPILE: %s\n" "$name"
  verilator --lint-only --timing -Wall -Wno-DECLFILENAME --top-module cache "$@" -f filelists/rtl.f
}

run_case "default"
run_case "addr_width_20" -GADDR_WIDTH=20
run_case "data_width_32" -GDATA_WIDTH=32
run_case "mem_data_width_64" -GMEM_DATA_WIDTH=64
run_case "line_width_256" -GLINE_WIDTH=256
