#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Constrained-random CPU traffic against the default geometry.
#
# Complements run_uvm_random.py, which randomises *geometry* and runs the
# directed suite against each one. This randomises the *stimulus* and holds the
# geometry fixed. Both are needed: a directed suite over many shapes still only
# ever performs the accesses somebody wrote down, and thirty accesses cannot
# produce an eviction landing on a queued invalidate no matter how many
# configurations they run in.
#
# Each seed is a separate run against one shared build, because the stimulus is
# runtime and only the geometry needs a rebuild. A failing seed is printed and
# reproduces exactly: TRAFFIC_SEEDS=<seed> re-runs just that stream.

set -euo pipefail

# 1200 rather than a few hundred. The defect tracked as D3 first appeared at
# access 822 of a stream and was invisible below roughly 800, so a regression
# that stops at 400 would have let it back in silently. This is the length the
# design has actually been shown to need, not a round number.
OPS="${TRAFFIC_OPS:-1200}"

# One watchdog millisecond covers roughly four accesses at the default geometry
# and memory latency; the floor keeps short runs from tripping on setup alone.
WATCHDOG="${WATCHDOG_MS:-$(( (OPS / 3) + 30 ))}"

# Distinct streams rather than one long one: independent seeds reach different
# eviction orders, and a single stream of the same total length explores fewer
# of them.
read -r -a seeds <<< "${TRAFFIC_SEEDS:-1 2 3}"

build_case="${REUSE_BUILD:-default}"
build_bin="sim/build/uvm_${build_case}/uvm_sim"

# Rebuild if the binary is missing *or older than any source*. Testing only for
# existence, as this used to, silently reuses a stale model: a soak launched
# right after adding a checker ran for hours against a build that did not
# contain it and reported a clean pass. A long run that quietly answers a
# different question than the one asked is worse than no run at all.
needs_build=0
if [[ ! -x "$build_bin" ]]; then
  needs_build=1
else
  newest=$(find rtl tb filelists -type f \( -name '*.sv' -o -name '*.svh' -o -name '*.f' \) \
             -newer "$build_bin" -print -quit 2>/dev/null)
  if [[ -n "$newest" ]]; then
    echo "TRAFFIC: ${build_bin} is older than ${newest}; rebuilding"
    needs_build=1
  fi
fi

if [[ $needs_build -eq 1 ]]; then
  echo "TRAFFIC: building ${build_case}"
  rm -f "$build_bin"
  ./scripts/run_uvm_tb.sh "$build_case" > /dev/null
fi

echo "TRAFFIC: ${OPS} ops per seed, seeds: ${seeds[*]}"

status=0
for seed in "${seeds[@]}"; do
  echo "TRAFFIC: seed ${seed}"
  if ! REUSE_BUILD="$build_case" UVM_TEST=cache_random_test \
       ./scripts/run_uvm_tb.sh "traffic_s${seed}" -- \
         "+TRAFFIC_OPS=${OPS}" "+WATCHDOG_MS=${WATCHDOG}" \
         "+verilator+seed+${seed}"; then
    echo "TRAFFIC FAILED at seed ${seed}; reproduce with TRAFFIC_SEEDS=${seed} TRAFFIC_OPS=${OPS} $0" >&2
    status=1
  fi
done

exit $status
