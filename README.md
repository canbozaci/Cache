# Cache SystemVerilog IP

[![CI](https://github.com/canbozaci/Cache/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/canbozaci/Cache/actions/workflows/ci.yml)

Reusable, non-coherent, blocking, write-through SystemVerilog cache subsystem for embedded and single-core integration.

This repository contains the generic cache IP only. CPU-side protocol adaptation, ISA-specific load/store formatting, memory bus adaptation, CDC, and SoC-specific integration logic belong in external adaptor repositories or the integrating project.

## Supported Profile

- Single cache clock.
- Non-coherent instruction/data L1 behavior. Software or integration logic must invalidate affected instruction lines before fetching data-side writes as instructions.
- Write-through data writes.
- Blocking command-style CPU-side interface using `busy` as the cache-level back-pressure signal.
- Native beat-based memory request/response interface with ready/valid handshakes and generic burst metadata.
- External CPU and memory adaptors; no ISA-specific or bus-specific adaptor is built into this repository.

## Not Supported Yet

- SMP coherency.
- DMA coherency.
- Built-in AXI, AHB, or TileLink bus adapters.
- Write-back mode.
- Multiple outstanding misses.
- ECC or parity.

## Current Status

- Source tree has been converted from the original Vivado export layout into a soft-IP layout.
- Synthesizable RTL lives in `rtl/` and uses `.sv` extensions.
- The reusable architecture-neutral cache top is `cache` in `rtl/`.
- CPU-specific compatibility glue has been moved to sibling adaptor repositories.
- Testbench-only models and directed tests live in `tb/`.
- Reproducible build inputs live in `filelists/`.
- Project scripts live in `scripts/`.
- Current baseline command:

```sh
make check
```

This runs RTL elaboration, RTL style/lint checks, and the top-level directed smoke simulation.

For the stronger self-checking cache scoreboard:

```sh
make scoreboard
```

`make verify` runs the baseline check, directed scoreboard configurations, seeded random scoreboard configurations, block tests, and a compile-only parameter sweep. It is the preferred regression command before RTL changes are considered done.

To elaborate only the reusable cache top:

```sh
make compile-cache
```

## Parameter Support

The cache exposes configurable address, data, memory-beat, line-width, and set-count parameters, but not every legal-looking combination is release-supported. A parameter combination is release-supported only when it is listed in `docs/PARAMETERS.md` and covered by the documented scoreboard or compile/lint evidence.

Unsupported combinations may elaborate during development, but they should not be used as product claims or integration baselines until the supported matrix and verification evidence are updated.

## Directory Layout

```text
rtl/        Synthesizable cache RTL: top, arrays, replacement, controller, and datapath helpers
tb/         Testbenches and native memory model
filelists/  Tool source lists
scripts/    Compile, lint, style, and simulation scripts
docs/       Integration and gap-analysis notes
```

## ASIC-Oriented Cleanup Notes

The cache array models no longer contain FPGA `ram_style` attributes or OpenRAM/BRAM-specific markers in synthesizable RTL. The default array models are generic inferred SystemVerilog memories. ASIC SRAM macro integration is handled through external adapter hooks documented in `docs/SRAM_INTEGRATION.md`; this repository does not include foundry SRAM cells.

The top-level smoke test uses a small native 32-bit memory model instead of the historical demo memory, peripheral, and program image files.

The reusable cache boundary accepts generic request signals and byte write strobes. ISA-specific load/store interpretation belongs outside this repository in a CPU-side adaptor.

Memory-side bus adaptation belongs outside this repository in a memory-side adaptor.

See `docs/GAP_ANALYSIS.md` for current design, verification, documentation, and architecture gaps.

The current parameter contract is documented in `docs/PARAMETERS.md`. The public timing and integration contract is documented in `docs/TIMING_CONTRACT.md`. Release gates are tracked in `docs/RELEASE_CHECKLIST.md`.

## License

This project is licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE` for details.
