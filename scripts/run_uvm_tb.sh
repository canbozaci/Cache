#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Build and run one UVM configuration.
#
# Usage: run_uvm_tb.sh <case-name> [+define+... ...] [-- <plusargs>...]
#
# Geometry is passed as +define+ because it changes port widths and therefore
# needs a rebuild; responder knobs are passed as simulation plusargs after --,
# because they do not.

set -euo pipefail

UVM_HOME="${UVM_HOME:-$HOME/uvm/src}"
VERILATOR="${VERILATOR:-verilator}"
TEST="${UVM_TEST:-cache_full_test}"
VERBOSITY="${UVM_VERBOSITY:-UVM_LOW}"

if [[ ! -f "$UVM_HOME/uvm_pkg.sv" ]]; then
  echo "error: UVM not found at \$UVM_HOME ($UVM_HOME/uvm_pkg.sv missing)." >&2
  echo "       clone accellera-official/uvm-core and set UVM_HOME to its src/." >&2
  exit 1
fi

# Build parallelism is capped by memory, not by core count.
#
# Building this model compiles the whole UVM library, and each cc1plus on a
# Verilator-generated UVM translation unit can hold most of a gigabyte —
# more with --coverage, which enlarges every one of them. On a machine with
# many cores and comparatively little RAM, -j $(nproc) overcommits memory
# badly; under WSL2 that can take the whole VM down rather than losing a
# single compiler process, which leaves no log behind to explain it.
#
# Measured on this design: 2838 translation units, the largest compilers
# peaking at 1.29 GB resident each. The budget below is one job per 2.5 GB,
# which leaves roughly twice the measured worst case per job — necessary
# because the peak is what matters, not the average. A 15.8 GB machine gets 6
# jobs; a full build then tops out around 4 GB actual, well clear of trouble.
#
# For reference, the -j $(nproc) this replaced meant 32 concurrent compilers on
# that same machine: over 40 GB if the large units aligned.
#
# Override with VERILATOR_JOBS when the machine can take more.
default_jobs() {
  local cores mem_kb by_mem
  cores=$(nproc)
  mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  if [[ "$mem_kb" -le 0 ]]; then echo "$cores"; return; fi
  by_mem=$(( mem_kb / 2621440 ))
  [[ "$by_mem" -lt 1 ]] && by_mem=1
  if [[ "$by_mem" -lt "$cores" ]]; then echo "$by_mem"; else echo "$cores"; fi
}
JOBS="${VERILATOR_JOBS:-$(default_jobs)}"

name="${1:?usage: run_uvm_tb.sh <case-name> [defines...] [-- plusargs...]}"
shift

defines=()
plusargs=()
seen_sep=0
for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then seen_sep=1; continue; fi
  if [[ $seen_sep -eq 1 ]]; then plusargs+=("$arg"); else defines+=("$arg"); fi
done

# Run the simulation and decide pass/fail from its output.
#
# The exit status cannot be trusted here: UVM ends the run through $finish, so
# the simulator returns 0 whether or not any UVM_ERROR was reported. Keying the
# gate off the explicit pass banner is what stops a failing configuration from
# being reported as a passing regression.
run_sim() {
  local dir="$1"
  local log="$dir/run_${name}.log"
  set -o pipefail
  "$dir/uvm_sim" +UVM_TESTNAME="$TEST" +UVM_VERBOSITY="$VERBOSITY" "${plusargs[@]-}" \
    2>&1 | tee "$log"
  if ! grep -q "CACHE UVM PASS" "$log"; then
    echo "CASE FAILED: $name (no pass banner; see $log)" >&2
    return 1
  fi
}

# Cases that differ only in runtime plusargs can share one build. Set
# REUSE_BUILD to another case's name to skip compilation entirely.
if [[ -n "${REUSE_BUILD:-}" ]]; then
  outdir="sim/build/uvm_${REUSE_BUILD}"
  if [[ ! -x "$outdir/uvm_sim" ]]; then
    echo "error: REUSE_BUILD=$REUSE_BUILD requested but $outdir/uvm_sim not built." >&2
    exit 1
  fi
  printf "UVM CASE: %s (reusing %s build) %s\n" "$name" "$REUSE_BUILD" "${plusargs[*]-}"
  run_sim "$outdir"
  exit $?
fi

outdir="sim/build/uvm_${name}"
mkdir -p "$outdir"

# Drop the previous binary before rebuilding. The build-failed check below tests
# for the executable, so leaving a stale one behind would let a compile error
# fall through to a run of the *previous* build and report it as a pass.
rm -f "$outdir/uvm_sim"

printf "UVM CASE: %s %s %s\n" "$name" "${defines[*]-}" "${plusargs[*]-}"

# -O0 for the generated C++ is deliberate. Building this model means compiling
# the whole UVM library, which dominates wall time; the tests themselves
# simulate around 12us, so optimising the model buys nothing and -Os costs
# minutes per configuration. Override with UVM_CFLAGS if you ever need a fast
# model for a long random run.
CFLAGS_OPT="${UVM_CFLAGS:--O0}"

# Coverage is opt-in. Instrumenting the model costs build time and slows the
# simulation, and the regression's job is to answer "does it still pass", not
# "how much did it reach" — that question gets its own dedicated run in
# scripts/run_coverage.sh.
cov_flags=()
if [[ -n "${COVERAGE:-}" ]]; then
  cov_flags=(--coverage-line --coverage-toggle --coverage-user)
fi

# Waveform tracing, also opt-in. tb_top honours +DUMP at run time, but the
# $dumpvars in it does nothing unless the model was built with tracing support
# compiled in, so the two have to be enabled together: TRACE=1 to build a
# traceable model, then +DUMP to make it write one.
#
# --trace-depth is unbounded on purpose. The interesting signals for a cache
# defect are the way valid bits and tag arrays several levels down, which is
# exactly what a shallow trace would omit.
trace_flags=()
if [[ -n "${TRACE:-}" ]]; then
  trace_flags=(--trace-fst --trace-structs --trace-params)
fi

# Build output is streamed with a progress counter, never swallowed. Building
# this model compiles the whole UVM library — dozens of translation units, a few
# minutes on a cold ccache — and a silent build is indistinguishable from a hang.
build_start=$(date +%s)
echo "  building (compiles the UVM library; minutes on a cold ccache, seconds warm)"

set -o pipefail
"$VERILATOR" -Wno-fatal --binary --timing -j "$JOBS" \
  --top-module tb_top \
  -CFLAGS "$CFLAGS_OPT" \
  +incdir+"$UVM_HOME" +define+UVM_NO_DPI \
  +incdir+tb \
  "${cov_flags[@]}" \
  "${trace_flags[@]}" \
  "${defines[@]}" \
  -f filelists/rtl.f \
  "$UVM_HOME/uvm_pkg.sv" \
  tb/cache_if.sv tb/cache_pkg.sv \
  tb/sva/cache_sva.sv tb/sva/cache_dup_tag_check.sv tb/sva/cache_store_probe.sv tb/sva/cache_wt_l2_check.sv tb/cov/cache_cov.sv tb/tb_top.sv \
  -o uvm_sim --Mdir "$outdir" 2>&1 \
  | tee "$outdir/build.log" \
  | awk '
      # Condense each compile line to a running count so progress is visible
      # without drowning the console in g++ command lines.
      /-c .*\.cpp$/ { n++; printf "\r  compiled %d translation units", n; fflush(); next }
      /^%Error|^%Warning|error:|Error:/ { printf "\n%s\n", $0; fflush(); next }
      /Verilator: Walltime/ { printf "\n  %s\n", $0; fflush(); next }
    END { if (n) printf "\r  compiled %d translation units\n", n }' || true

if [[ ! -x "$outdir/uvm_sim" ]]; then
  echo "BUILD FAILED for case $name; see $outdir/build.log" >&2
  tail -30 "$outdir/build.log" >&2
  exit 1
fi

echo "  built in $(( $(date +%s) - build_start ))s; running $TEST"

run_sim "$outdir"
