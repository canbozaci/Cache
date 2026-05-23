#!/usr/bin/env bash
set -euo pipefail

if rg -n '\b(function|endfunction)\b|initial[[:space:]]+begin' rtl; then
  printf 'RTL style check failed: functions and initial blocks are not allowed in synthesizable RTL.\n' >&2
  exit 1
fi

if rg -n 'ram_style|BRAM|blockram|OpenRAM|xilinx|Xilinx' rtl; then
  printf 'RTL style check failed: FPGA/OpenRAM-specific memory markers remain in RTL.\n' >&2
  exit 1
fi
