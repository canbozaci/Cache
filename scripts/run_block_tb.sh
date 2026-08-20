#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Block-level UVM tests for the cache's leaf modules.
#
# Separate environment and separate top from the cache-level tests: the DUTs are
# the submodules themselves, so there is no cache instance here at all.
#
# Pass/fail is taken from the explicit banner, not the exit status, because a
# simulator that ends through $finish returns 0 regardless of what the test
# concluded.

set -euo pipefail

UVM_HOME="${UVM_HOME:-$HOME/uvm/src}"
VERILATOR="${VERILATOR:-verilator}"
VERBOSITY="${UVM_VERBOSITY:-UVM_LOW}"

if [[ ! -f "$UVM_HOME/uvm_pkg.sv" ]]; then
  echo "error: UVM not found at \$UVM_HOME ($UVM_HOME/uvm_pkg.sv missing)." >&2
  exit 1
fi

outdir="sim/build/block"
mkdir -p "$outdir"

# One build job per 2.5 GB, capped at the core count. See run_uvm_tb.sh for why
# core count alone is the wrong number: compiling the UVM library in parallel is
# memory-bound, not CPU-bound, and the budget has to cover the peak rather than
# the average.
mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
if [[ "$mem_kb" -gt 0 ]]; then
  jobs_by_mem=$(( mem_kb / 2621440 ))
  [[ "$jobs_by_mem" -lt 1 ]] && jobs_by_mem=1
  JOBS="${VERILATOR_JOBS:-$(( jobs_by_mem < $(nproc) ? jobs_by_mem : $(nproc) ))}"
else
  JOBS="${VERILATOR_JOBS:-$(nproc)}"
fi

printf "BLOCK TESTS: building with %s job(s)\n" "$JOBS"
"$VERILATOR" -Wno-fatal --binary --timing -j "$JOBS" \
  --top-module block_tb_top \
  -CFLAGS "${UVM_CFLAGS:--O0}" \
  +incdir+"$UVM_HOME" +define+UVM_NO_DPI \
  +incdir+tb \
  -f filelists/rtl.f \
  "$UVM_HOME/uvm_pkg.sv" \
  tb/block/cache_block_if.sv tb/block/cache_block_pkg.sv tb/block/block_tb_top.sv \
  -o block_sim --Mdir "$outdir" > "$outdir/build.log" 2>&1 || {
    echo "BLOCK TESTS BUILD FAILED; log tail:" >&2
    tail -30 "$outdir/build.log" >&2
    exit 1
  }

set -o pipefail
"$outdir/block_sim" +UVM_VERBOSITY="$VERBOSITY" 2>&1 | tee "$outdir/run.log"

if ! grep -q "CACHE BLOCK TEST PASS" "$outdir/run.log"; then
  echo "BLOCK TESTS FAILED (no pass banner; see $outdir/run.log)" >&2
  exit 1
fi
