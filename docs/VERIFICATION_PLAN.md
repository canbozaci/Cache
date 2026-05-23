# Cache Verification Plan

## Baseline Gate

`make check` is the current clean baseline. It runs:

- RTL elaboration of the `cache` top.
- RTL style checks and Verilator lint.
- Directed smoke simulation with the native memory model.

## Scoreboard Regression

`make scoreboard` builds and runs `tb/cache_scoreboard_tb.sv`.

The scoreboard keeps an independent byte-addressed reference memory initialized to match `tb/cache_memory_model.sv`. It checks:

- Cold data reads from external memory.
- L1 hit reads after a fill.
- Instruction fetch reads.
- Byte and word write-through behavior.
- Repeated hit reads after writes.
- Simultaneous instruction and data requests.

`make verify` runs `make check`, `make scoreboard`, and `make parameter-compile`.

## Parameter Compile Sweep

`make parameter-compile` elaborates the cache with selected non-default parameter overrides:

- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`

This is a compile/lint compatibility gate. It proves the RTL is width-clean for these configurations, but it does not yet prove full behavioral correctness for each non-default configuration.

## Current Result

The scoreboard is expected to pass as part of `make verify`.

Known areas not yet covered:

- Instruction/data L1 coherency after data writes to instruction addresses.
- Native memory backpressure or variable latency.
- Behavioral parameter sweeps.
- Protocol assertions.

## Parameter Verification Direction

The current supported parameter set is documented in `docs/PARAMETERS.md`. Before any non-default value is advertised as supported, verification should add:

- A compile/lint sweep for the new parameter value.
- A scoreboard run for at least one non-default cache geometry when the testbench supports it.
- Directed tests for line-fill beat count, write-strobe width, address offset decode, and partial writes at line boundaries.

The next design work should keep this scoreboard passing before simplifying controller wiring or changing cache internals.
