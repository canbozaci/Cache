#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Coverage run: how much of the RTL the tests actually reach.
#
# Separate from `make verify` on purpose. The regression answers "does it still
# pass"; this answers "against how much". Instrumenting the model costs build
# time and slows the simulation, and mixing the two would make every ordinary
# run pay for a number nobody reads on every commit.
#
# Three kinds of coverage are collected in one build:
#   line    - which RTL statements executed
#   toggle  - which RTL signal bits changed in both directions
#   user    - the functional bins in tb/cov/cache_cov.sv
#
# The functional bins are SVA cover directives rather than covergroups because
# the simulator here implements the former and not the latter; see the header of
# tb/cov/cache_cov.sv.

set -euo pipefail

UVM_HOME="${UVM_HOME:-$HOME/uvm/src}"
VERILATOR="${VERILATOR:-verilator}"
VERILATOR_COVERAGE="${VERILATOR_COVERAGE:-verilator_coverage}"
TRAFFIC_OPS="${TRAFFIC_OPS:-1500}"

if [[ ! -f "$UVM_HOME/uvm_pkg.sv" ]]; then
  echo "error: UVM not found at \$UVM_HOME ($UVM_HOME/uvm_pkg.sv missing)." >&2
  exit 1
fi

outdir="sim/build/coverage"
mkdir -p "$outdir"
rm -f "$outdir"/*.dat

sim="sim/build/uvm_coverage/uvm_sim"

# The build helper also runs the directed suite, and its result is deliberately
# ignored here: what this step must produce is the instrumented binary. Coverage
# on a design with a known open defect is still worth measuring — arguably more
# so, since the first question about a defect is what the tests were reaching
# when they missed it. Failing runs are reported at the end instead.
echo "COVERAGE: building instrumented model"
COVERAGE=1 UVM_CFLAGS="${UVM_CFLAGS:--O0}" ./scripts/run_uvm_tb.sh coverage \
  > "$outdir/build_run.log" 2>&1 || true

if [[ ! -x "$sim" ]]; then
  echo "COVERAGE BUILD FAILED; log tail:" >&2
  tail -30 "$outdir/build_run.log" >&2
  exit 1
fi

# Each run contributes a separate data file, merged afterwards. The directed
# suite and the random soak reach different things — the directed tests walk the
# maintenance and error paths deliberately, the soak grinds the replacement and
# write-through paths — and the union is the honest number.
failed_cases=()

run_case() {
  local label="$1"; local test="$2"; shift 2
  echo "COVERAGE: running $label"
  "$sim" +UVM_TESTNAME="$test" +UVM_VERBOSITY=UVM_NONE \
    "+verilator+coverage+file+$outdir/$label.dat" "$@" \
    > "$outdir/run_$label.log" 2>&1 || true
  if ! grep -q "CACHE UVM PASS" "$outdir/run_$label.log"; then
    failed_cases+=("$label")
  fi
}

run_case directed cache_full_test
run_case random   cache_random_test "+TRAFFIC_OPS=$TRAFFIC_OPS" "+WATCHDOG_MS=400"
run_case stalls   cache_random_test "+TRAFFIC_OPS=$((TRAFFIC_OPS / 3))" "+WATCHDOG_MS=400" \
                                    "+MEM_READY_STALLS=1" "+MEM_RSP_VARIABLE_LATENCY=1"

echo "COVERAGE: merging"
"$VERILATOR_COVERAGE" --write "$outdir/merged.dat" \
  "$outdir/directed.dat" "$outdir/random.dat" "$outdir/stalls.dat" \
  > "$outdir/merge.log" 2>&1

# Annotated sources, for reading which specific lines were never reached.
"$VERILATOR_COVERAGE" --annotate "$outdir/annotated" --annotate-min 1 "$outdir/merged.dat" \
  >> "$outdir/merge.log" 2>&1 || true

# The build step above runs the simulation once without the output-file plusarg,
# which drops a coverage.dat in the working directory. It is redundant with the
# per-case files below and does not belong in the source tree.
rm -f coverage.dat

./scripts/report_coverage.py "$outdir/merged.dat"

# Reported after the numbers, not instead of them. The coverage above is still
# valid — it says what the stimulus reached — but it was collected from runs
# that found real failures, and that has to be stated rather than implied.
if (( ${#failed_cases[@]} > 0 )); then
  echo "COVERAGE: the following runs reported failures: ${failed_cases[*]}" >&2
  for label in "${failed_cases[@]}"; do
    echo "  see $outdir/run_$label.log" >&2
  done
  exit 1
fi
