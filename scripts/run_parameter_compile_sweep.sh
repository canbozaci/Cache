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
run_case "data_width_128_line_width_256" -GDATA_WIDTH=128 -GLINE_WIDTH=256
run_case "addr_width_20_data_width_32" -GADDR_WIDTH=20 -GDATA_WIDTH=32
run_case "mem_data_width_64_line_width_256" -GMEM_DATA_WIDTH=64 -GLINE_WIDTH=256
run_case "addr_width_20_mem_data_width_64_line_width_256" -GADDR_WIDTH=20 -GMEM_DATA_WIDTH=64 -GLINE_WIDTH=256
run_case "data_width_32_mem_data_width_64_line_width_256" -GDATA_WIDTH=32 -GMEM_DATA_WIDTH=64 -GLINE_WIDTH=256
run_case "data_width_128_mem_data_width_64_line_width_256" -GDATA_WIDTH=128 -GMEM_DATA_WIDTH=64 -GLINE_WIDTH=256
