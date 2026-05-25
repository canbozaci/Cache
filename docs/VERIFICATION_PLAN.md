# Cache Verification Plan

## Baseline Gate

`make check` is the current clean baseline. It runs:

- RTL elaboration of the `cache` top.
- RTL style checks and Verilator lint.
- Directed smoke simulation with the native memory model.

## Block Tests

`make block-tests` builds and runs `tb/cache_block_tb.sv`.

The block tests check:

- L1 line memory byte-write behavior.
- L1 tag/valid write and address-selective invalidate behavior.
- L2 dual-port line memory writes and byte enables.
- L1 load and store helper byte placement.
- L1 replacement choices for empty, partially valid, and LRU-selected sets.
- L2 replacement same-index dual-port write selection.
- A controller data-side line-fill subflow with four native memory read beats.

## Scoreboard Regression

`make scoreboard` builds and runs `tb/cache_scoreboard_tb.sv` across multiple configurations.

The scoreboard keeps an independent byte-addressed reference memory initialized to match `tb/cache_memory_model.sv`. It checks:

- Cold data reads from external memory.
- L1 hit reads after a fill.
- Instruction fetch reads.
- Byte, word, and unaligned multi-beat write-through behavior.
- Repeated hit reads after writes.
- L1 replacement eviction using three lines that alias to one L1 set.
- Simultaneous instruction and data requests.
- Native memory request wait states.
- Fixed and variable native memory response latency.
- Native memory line-fill burst metadata.
- Native memory write-through burst metadata.
- Runtime global and address-selective line maintenance handshakes.
- Address-selective line invalidate forcing a refill only for the targeted line.
- Address-selective line flush as a write-through no-op.
- Illegal maintenance request combinations returning `maint_error`.
- Queued maintenance requests accepted while cache traffic is active.
- Reset during an active transaction and repeated reset recovery.
- The documented unsupported I/D coherency contract: data-side writes do not update an already-filled instruction L1 line until maintenance invalidates the line.

`make random-scoreboard` generates six legal parameter combinations from a time-based seed and runs the scoreboard on them. The runner prints the seed and accepts `RANDOM_SEED=<seed>` and `RANDOM_CASE_COUNT=<count>` overrides for reproducing failures.

`make verify` runs `make check`, `make scoreboard`, `make random-scoreboard`, `make block-tests`, and `make parameter-compile`.

Current scoreboard configurations:

- default
- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`
- `L1_SET_COUNT=32`, `L2_SET_COUNT=128`
- `L1_SET_COUNT=16`, `L2_SET_COUNT=64`
- split L1 set counts with `L1_DATA_SET_COUNT=32`, `L1_INSTR_SET_COUNT=64`, `L2_SET_COUNT=128`
- split L1 set counts with `L1_DATA_SET_COUNT=64`, `L1_INSTR_SET_COUNT=32`, `L2_SET_COUNT=128`
- ready-stalled native memory
- fixed extra response latency
- variable response latency
- `DATA_WIDTH=128`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=128`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`, `L1_DATA_SET_COUNT=32`, `L1_INSTR_SET_COUNT=64`, `L2_SET_COUNT=128`
- `DATA_WIDTH=128`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`, `L1_SET_COUNT=32`, `L2_SET_COUNT=128`

Random scoreboard parameters are selected from the currently supported legal set:

- `ADDR_WIDTH`: 19, 20, 21
- `DATA_WIDTH`: 32, 64, 128
- `MEM_DATA_WIDTH`: 32, 64
- `LINE_WIDTH`: 128, 256
- `L1_DATA_SET_COUNT`: 16, 32, 64
- `L1_INSTR_SET_COUNT`: 16, 32, 64
- `L2_SET_COUNT`: 64, 128, 256

## Parameter Compile Sweep

`make parameter-compile` elaborates the cache with selected non-default parameter overrides:

- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`
- `L1_SET_COUNT=32`, `L2_SET_COUNT=128`
- `L1_SET_COUNT=16`, `L2_SET_COUNT=64`
- split L1 set counts with `L1_DATA_SET_COUNT=32`, `L1_INSTR_SET_COUNT=64`, `L2_SET_COUNT=128`
- split L1 set counts with `L1_DATA_SET_COUNT=64`, `L1_INSTR_SET_COUNT=32`, `L2_SET_COUNT=128`
- `DATA_WIDTH=128`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `DATA_WIDTH=128`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`
- `ADDR_WIDTH=20`, `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`, `L1_DATA_SET_COUNT=32`, `L1_INSTR_SET_COUNT=64`, `L2_SET_COUNT=128`
- `DATA_WIDTH=128`, `MEM_DATA_WIDTH=64`, `LINE_WIDTH=256`, `L1_SET_COUNT=32`, `L2_SET_COUNT=128`

This is a compile/lint compatibility gate. Scoreboard covers the same single-parameter and combined width overrides listed above.

## Current Result

The scoreboard is expected to pass as part of `make verify`.

Known cache areas not yet covered:

- Protocol assertions.

Adaptor/integration responsibilities:

- CPU adaptors must include negative contract tests that split transfers crossing a cache-line boundary before they reach this cache.
- Memory adaptors or higher-level SoC tests must cover bus-specific burst coalescing and protocol encoding.

## Parameter Verification Direction

The current supported parameter set is documented in `docs/PARAMETERS.md`. Before any non-default value is advertised as supported, verification should add:

- A compile/lint sweep for the new parameter value.
- A scoreboard run for at least one non-default cache geometry when the testbench supports it.
- Directed tests for line-fill beat count, write-strobe width, address offset decode, and partial writes at line boundaries.

The next design work should keep this scoreboard passing before simplifying controller wiring or changing cache internals.
