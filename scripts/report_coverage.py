#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Summarise a Verilator coverage database.
#
# The raw .dat is one record per coverage point and runs to millions of lines
# once the UVM library is instrumented, which is unreadable and mostly
# irrelevant: coverage of the UVM base classes says nothing about this IP. This
# filters to the RTL, splits line/branch/toggle, and prints the functional bins
# from tb/cov/cache_cov.sv individually, because a functional bin that was never
# hit is a specific unanswered question rather than a percentage.

import collections
import sys

# Record format: C '<\x01key\x02value>...' <count>
FIELD_SEP = "\x01"
KV_SEP = "\x02"


def parse(path):
    points = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.startswith("C '"):
                continue
            end = line.rfind("'")
            if end <= 2:
                continue
            body = line[3:end]
            try:
                count = int(line[end + 1:].strip())
            except ValueError:
                continue
            fields = {}
            for chunk in body.split(FIELD_SEP):
                if KV_SEP in chunk:
                    key, value = chunk.split(KV_SEP, 1)
                    fields[key] = value
            points.append((fields, count))
    return points


def pct(hit, total):
    return f"{100.0 * hit / total:5.1f}%" if total else "    - "


def main():
    if len(sys.argv) < 2:
        print("usage: report_coverage.py <merged.dat>", file=sys.stderr)
        return 2

    points = parse(sys.argv[1])
    if not points:
        print("error: no coverage points parsed", file=sys.stderr)
        return 2

    # kind -> file -> [hit, total]
    rtl = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0]))
    functional = []

    for fields, count in points:
        kind = fields.get("t", "?")
        path = fields.get("f", "")

        if kind == "user":
            functional.append((fields.get("o", "?"), count))
            continue

        if not path.startswith("rtl/"):
            continue

        bucket = rtl[kind][path.split("/", 1)[1]]
        bucket[1] += 1
        if count > 0:
            bucket[0] += 1

    kinds = [k for k in ("line", "branch", "toggle") if k in rtl]
    files = sorted({name for kind in kinds for name in rtl[kind]})

    print()
    print("RTL coverage")
    print("=" * 72)
    header = f"{'file':<34}" + "".join(f"{k:>12}" for k in kinds)
    print(header)
    print("-" * 72)

    totals = {k: [0, 0] for k in kinds}
    for name in files:
        row = f"{name:<34}"
        for kind in kinds:
            hit, total = rtl[kind].get(name, [0, 0])
            totals[kind][0] += hit
            totals[kind][1] += total
            row += f"{pct(hit, total):>12}"
        print(row)

    print("-" * 72)
    row = f"{'TOTAL':<34}"
    for kind in kinds:
        row += f"{pct(*totals[kind]):>12}"
    print(row)
    for kind in kinds:
        hit, total = totals[kind]
        print(f"  {kind:<8} {hit}/{total} points")

    print()
    print("Functional coverage (tb/cov/cache_cov.sv)")
    print("=" * 72)
    functional.sort(key=lambda item: (item[1] > 0, item[0]))
    hit_bins = sum(1 for _, count in functional if count > 0)
    for name, count in functional:
        state = "hit " if count > 0 else "MISS"
        print(f"  {state}  {name:<34} {count:>8}")
    print("-" * 72)
    print(f"  {hit_bins}/{len(functional)} functional bins hit")

    misses = [name for name, count in functional if count == 0]
    if misses:
        print()
        print("Unhit bins are unanswered questions, not noise. Either the")
        print("stimulus does not reach them yet, or they describe something the")
        print("IP does not do and the bin should say so:")
        for name in misses:
            print(f"  - {name}")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
