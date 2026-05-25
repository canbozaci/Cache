#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci

set -euo pipefail

mkdir -p sim/build
iverilog -g2012 -o sim/build/cache_block_tb.vvp -f filelists/block_tb.f
vvp sim/build/cache_block_tb.vvp
