#!/usr/bin/env python3
import os
import random
import subprocess
import time


CASE_COUNT = int(os.environ.get("RANDOM_CASE_COUNT", "6"))
SEED = int(os.environ.get("RANDOM_SEED", str(int(time.time()))))


def legal_cases():
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


def case_args(case):
    args = []
    for key, value in case.items():
        args.extend(["-P", f"cache_scoreboard_tb.{key}={value}"])
    return args


def main():
    random.seed(SEED)
    cases = random.sample(legal_cases(), CASE_COUNT)
    print(f"RANDOM SCOREBOARD SEED: {SEED}", flush=True)
    print(f"RANDOM SCOREBOARD CASES: {CASE_COUNT}", flush=True)
    os.makedirs("sim/build", exist_ok=True)

    for index, case in enumerate(cases):
        name = f"random_{index}"
        output_path = f"sim/build/cache_scoreboard_{name}_tb.vvp"
        print(f"SCOREBOARD: {name} {case}", flush=True)
        compile_cmd = [
            "iverilog",
            "-g2012",
            "-o",
            output_path,
            *case_args(case),
            "-f",
            "filelists/scoreboard_tb.f",
        ]
        subprocess.run(compile_cmd, check=True)
        subprocess.run(["vvp", output_path], check=True)


if __name__ == "__main__":
    main()
