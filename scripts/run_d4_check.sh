#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Validation for the duplicate-tag fix in cache_l1_replacement.sv and
# cache_l2_replacement.sv.
#
# Two questions, in the order they matter:
#
#   1. Does the defect that motivated the fix still reproduce? Seed 1 at 99400
#      accesses failed at access 99385 with a value written 275 accesses
#      earlier. That is the case the fix has to close.
#
#   2. Did the fix break anything else? The change is in replacement policy,
#      which every configuration in the matrix exercises differently, so the
#      directed regression matters more here than it would for a local fix.
#
# The duplicate-tag checker added in tb/sva/cache_dup_tag_check.sv runs in both
# stages. It reports as a UVM_ERROR, so a duplicated set fails the run on its
# own even if the scoreboard never sees a wrong value.
#
# Runtime is about an hour, dominated by stage 1.

set -uo pipefail   # not -e: run both stages and report both

cd "$(dirname "$0")/.." || exit 1

mkdir -p sim
LOG="sim/d4_check_$(date +%Y%m%d_%H%M%S).log"
LOG_ABS="$(cd "$(dirname "$LOG")" && pwd)/$(basename "$LOG")"

{
  printf 'Cache duplicate-tag fix validation\n'
  printf 'date      : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf 'verilator : %s\n' "$(verilator --version 2>/dev/null || echo unknown)"
} > "$LOG"

echo "Duplicate-tag fix validation -> $LOG_ABS"
echo

# ---- stage 1: the D4 reproduction -------------------------------------
echo "[1/2] D4 repro: seed 1, 99400 accesses (~45 min)"
{
  printf '\n======== STAGE: d4_repro ========\n'
} >> "$LOG"

UVM_TEST=cache_random_test UVM_VERBOSITY=UVM_MEDIUM \
  ./scripts/run_uvm_tb.sh d4fix -- \
    +TRAFFIC_OPS=99400 +WATCHDOG_MS=900 +verilator+seed+1 >> "$LOG" 2>&1
rc_d4=$?
[[ $rc_d4 -eq 0 ]] && echo "      PASS" || echo "      FAIL ($rc_d4)"

# ---- stage 2: the directed regression ---------------------------------
echo "[2/2] make verify: full matrix (~15 min)"
{
  printf '\n======== STAGE: verify ========\n'
} >> "$LOG"

make verify >> "$LOG" 2>&1
rc_verify=$?
[[ $rc_verify -eq 0 ]] && echo "      PASS" || echo "      FAIL ($rc_verify)"

# ---- summary -----------------------------------------------------------
{
  printf '\n======== SUMMARY ========\n'
  printf '  d4_repro : %s\n' "$([[ $rc_d4     -eq 0 ]] && echo PASS || echo "FAIL($rc_d4)")"
  printf '  verify   : %s\n' "$([[ $rc_verify -eq 0 ]] && echo PASS || echo "FAIL($rc_verify)")"
  printf '\nDuplicate-tag observations:\n'
  grep -c "DUP_TAG SUMMARY: no duplicate" "$LOG" | sed 's/^/  clean runs: /'
  grep -n "DUP_TAG\]" "$LOG" | head -20 || true
  printf '\nErrors, if any:\n'
  grep -nE "UVM_ERROR|CASE FAILED|BUILD FAILED|%Error" "$LOG" \
    | grep -v "UVM_ERROR :    0" | head -40 || true
} >> "$LOG"

echo
if [[ $rc_d4 -eq 0 && $rc_verify -eq 0 ]]; then
  echo "DUPLICATE-TAG FIX VALIDATED"
else
  echo "VALIDATION FAILED - see the SUMMARY section of the log"
fi
echo "log: $LOG_ABS"

[[ $rc_d4 -eq 0 && $rc_verify -eq 0 ]]
