#!/usr/bin/env bash
set -euo pipefail

verilator --lint-only --timing -Wall -Wno-DECLFILENAME --top-module cache -f filelists/rtl.f
