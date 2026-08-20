#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Everything, in order, into one log.
#
# This is the "can it be integrated" run rather than the "did I break it" run.
# `make verify` answers the second in a few minutes; this adds the coverage
# build and a long random soak, which is where the last two defects in this IP
# were found and where any remaining ones are most likely to be.
#
# Stages run even if an earlier one fails. A release check that stops at the
# first failure tells you one thing; running all of it tells you how much is
# wrong, which is the more useful answer when deciding whether to ship.
#
# Usage:
#   ./scripts/run_release_check.sh
#   SOAK_OPS=100000 SOAK_SEEDS="1 2 3" ./scripts/run_release_check.sh
#
# Runtime is dominated by the soak: roughly one minute per 1000 accesses per
# seed. The defaults below are about three hours, which is an overnight job.
# Drop SOAK_OPS to 5000 for something that finishes over lunch.

set -uo pipefail   # deliberately not -e; see above

SOAK_OPS="${SOAK_OPS:-25000}"
SOAK_SEEDS="${SOAK_SEEDS:-1 2 3 4 5 6}"

mkdir -p sim
LOG="${LOG:-sim/release_check_$(date +%Y%m%d_%H%M%S).log}"

# Absolute path so the line printed at the end is pasteable from anywhere.
LOG_ABS="$(cd "$(dirname "$LOG")" && pwd)/$(basename "$LOG")"

stage_names=()
stage_status=()
stage_secs=()

run_stage() {
  local name="$1"; shift
  local start finish rc
  start=$(date +%s)

  {
    printf '\n'
    printf '========================================================================\n'
    printf 'STAGE: %s\n' "$name"
    printf 'START: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '========================================================================\n'
  } >> "$LOG"

  "$@" >> "$LOG" 2>&1
  rc=$?

  finish=$(date +%s)
  stage_names+=("$name")
  stage_secs+=("$(( finish - start ))")
  if [[ $rc -eq 0 ]]; then stage_status+=("PASS"); else stage_status+=("FAIL($rc)"); fi

  printf '  %-22s %-9s %6ds\n' "$name" "${stage_status[-1]}" "${stage_secs[-1]}"
  {
    printf 'STAGE %s RESULT: %s after %ds\n' "$name" "${stage_status[-1]}" "${stage_secs[-1]}"
  } >> "$LOG"
}

{
  printf 'Cache release check\n'
  printf 'date      : %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf 'host      : %s\n' "$(uname -srm)"
  printf 'verilator : %s\n' "$(verilator --version 2>/dev/null || echo unknown)"
  printf 'soak      : %s accesses x seeds [%s]\n' "$SOAK_OPS" "$SOAK_SEEDS"
  printf 'git       : %s\n' "$(git rev-parse --short HEAD 2>/dev/null || echo 'not a repo')"
  printf 'dirty     : %s file(s) modified\n' "$(git status --porcelain 2>/dev/null | wc -l)"
} > "$LOG"

echo "Cache release check -> $LOG_ABS"
echo "  soak: $SOAK_OPS accesses x seeds [$SOAK_SEEDS]"
echo
printf '  %-22s %-9s %7s\n' "STAGE" "RESULT" "TIME"
printf '  %-22s %-9s %7s\n' "----------------------" "---------" "-------"

# The regression proper: compile, lint, directed suite over the configuration
# matrix, geometry sweep, short random traffic, block tests, compile sweep.
run_stage "verify"  make verify

# Instrumented build: RTL line/branch/toggle plus the functional bins. Also
# runs its own 1500-access random case and a stalled-memory case.
run_stage "coverage" make coverage

# The long one. This is the stage that has actually found defects the rest of
# the suite could not see.
run_stage "soak" env TRAFFIC_OPS="$SOAK_OPS" TRAFFIC_SEEDS="$SOAK_SEEDS" \
                     ./scripts/run_traffic.sh

# ---- summary ------------------------------------------------------------
failed=0
for s in "${stage_status[@]}"; do [[ "$s" == PASS ]] || failed=1; done

{
  printf '\n'
  printf '========================================================================\n'
  printf 'SUMMARY\n'
  printf '========================================================================\n'
  for i in "${!stage_names[@]}"; do
    printf '  %-22s %-9s %6ds\n' "${stage_names[$i]}" "${stage_status[$i]}" "${stage_secs[$i]}"
  done
  printf '\n'
  if [[ $failed -eq 0 ]]; then
    printf 'RELEASE CHECK PASSED\n'
  else
    printf 'RELEASE CHECK FAILED\n'
    printf '\nFailures, in the order they were reported:\n'
    grep -nE "UVM_ERROR|CASE FAILED|TRAFFIC FAILED|BUILD FAILED|%Error" "$LOG" \
      | grep -v "UVM_ERROR :    0" | head -40
  fi
} >> "$LOG"

echo
if [[ $failed -eq 0 ]]; then
  echo "RELEASE CHECK PASSED"
else
  echo "RELEASE CHECK FAILED — see the SUMMARY section of the log"
fi
echo "log: $LOG_ABS"

exit $failed
