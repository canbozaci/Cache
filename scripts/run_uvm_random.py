#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci
#
# Seeded random geometry sweep for the UVM testbench.
#
# The seed is printed and overridable so a failure found here is reproducible:
# RANDOM_SEED=<seed> re-runs the identical set of configurations.

import os
import random
import subprocess
import sys
import time


CASE_COUNT = int(os.environ.get("RANDOM_CASE_COUNT", "6"))
SEED = int(os.environ.get("RANDOM_SEED", str(int(time.time()))))


def legal_cases():
    """Every geometry the IP currently claims behavioural support for.

    The exclusions are the documented parameter contract, not arbitrary
    filtering: a line must be a whole number of memory beats, a line cannot be
    narrower than a CPU access, and 128-bit accesses are only supported against
    256-bit lines.
    """
    cases = []
    for addr_width in [19, 20, 21]:
        for data_width in [32, 64, 128]:
            for mem_data_width in [32, 64]:
                for line_width in [128, 256]:
                    if line_width < data_width:
                        continue
                    if line_width % mem_data_width != 0:
                        continue
                    if data_width == 128 and line_width != 256:
                        continue
                    for l1_data_set_count in [16, 32, 64]:
                        for l1_instr_set_count in [16, 32, 64]:
                            for l2_set_count in [64, 128, 256]:
                                cases.append({
                                    "ADDR_WIDTH": addr_width,
                                    "DATA_WIDTH": data_width,
                                    "MEM_DATA_WIDTH": mem_data_width,
                                    "LINE_WIDTH": line_width,
                                    "L1_DATA_SET_COUNT": l1_data_set_count,
                                    "L1_INSTR_SET_COUNT": l1_instr_set_count,
                                    "L2_SET_COUNT": l2_set_count,
                                })
    return cases


def case_defines(case):
    return [f"+define+CACHE_{key}={value}" for key, value in case.items()]


def main():
    random.seed(SEED)
    cases = random.sample(legal_cases(), CASE_COUNT)
    print(f"RANDOM UVM SEED: {SEED}", flush=True)
    print(f"RANDOM UVM CASES: {CASE_COUNT}", flush=True)

    for index, case in enumerate(cases):
        name = f"random_{index}"
        print(f"UVM RANDOM: {name} {case}", flush=True)
        subprocess.run(
            ["./scripts/run_uvm_tb.sh", name, *case_defines(case)],
            check=True,
        )


if __name__ == "__main__":
    sys.exit(main())
