#!/usr/bin/env bash
set -euo pipefail

./scripts/check_rtl_style.sh
verilator --lint-only --timing -Wall -Wno-DECLFILENAME --top-module cache -f filelists/rtl.f
