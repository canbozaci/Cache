# Cache Verification Plan

## Baseline Gate

`make check` is the current clean baseline. It runs:

- RTL elaboration of the `cache` top.
- RTL style checks and Verilator lint.
- Directed smoke simulation with the native memory model.

## Scoreboard Regression

`make scoreboard` builds and runs `tb/cache_scoreboard_tb.sv` across multiple configurations.

The scoreboard keeps an independent byte-addressed reference memory initialized to match `tb/cache_memory_model.sv`. It checks:

- Cold data reads from external memory.
- L1 hit reads after a fill.
- Instruction fetch reads.
- Byte, word, and unaligned multi-beat write-through behavior.
- Repeated hit reads after writes.
- Simultaneous instruction and data requests.
- Native memory request wait states.
- Native memory line-fill burst metadata.
- Native memory write-through burst metadata.
- Runtime maintenance flush and invalidate handshakes.

`make verify` runs `make check`, `make scoreboard`, and `make parameter-compile`.

Current scoreboard configurations:

- default
- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`
- ready-stalled native memory
- `DATA_WIDTH=128`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=128`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`

## Parameter Compile Sweep

`make parameter-compile` elaborates the cache with selected non-default parameter overrides:

- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`
- `DATA_WIDTH=128`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=128`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`

This is a compile/lint compatibility gate. Scoreboard covers the same single-parameter and combined width overrides listed above.

## Current Result

The scoreboard is expected to pass as part of `make verify`.

Known areas not yet covered:

- Instruction/data L1 coherency after data writes to instruction addresses.
- Broader native memory response-latency patterns.
- Memory-adaptor burst coalescing tests for bus-specific read and write burst encoding.
- Combined non-default parameter sweeps outside the current scoreboard matrix.
- Protocol assertions.

## Parameter Verification Direction

The current supported parameter set is documented in `docs/PARAMETERS.md`. Before any non-default value is advertised as supported, verification should add:

- A compile/lint sweep for the new parameter value.
- A scoreboard run for at least one non-default cache geometry when the testbench supports it.
- Directed tests for line-fill beat count, write-strobe width, address offset decode, and partial writes at line boundaries.
- Negative contract tests for adaptors that must split transfers crossing a cache-line boundary.

The next design work should keep this scoreboard passing before simplifying controller wiring or changing cache internals.
