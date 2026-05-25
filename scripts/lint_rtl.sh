#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Can Bozaci

set -euo pipefail

./scripts/check_rtl_style.sh
verilator --lint-only --timing -Wall -Wno-DECLFILENAME --top-module cache -f filelists/rtl.f
