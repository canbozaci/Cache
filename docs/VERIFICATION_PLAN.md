# Cache Verification Plan

## Tooling

Verification uses two UVM environments under `tb/`, described in
`tb/README.md`: the cache-level environment, and a block-level environment in
`tb/block/` for the leaf modules.
It requires a UVM-capable Verilator (>= 5.046) and the Accellera `uvm-core`
sources, with `UVM_HOME` pointing at their `src/` directory.

## Baseline Gate

`make check` is the current clean baseline. It runs:

- RTL elaboration of the `cache` top.
- RTL style checks and Verilator lint.
- The UVM regression test in its default configuration.

## Block Tests

`make block-tests` runs the block-level UVM environment in `tb/block/`, which
instantiates the leaf modules directly — there is no cache instance in it.

It has its own top, package and test (`cache_block_test`), separate from the
cache-level environment, because the DUTs are different. Geometry is fixed
rather than swept: these tests target internal behaviour that the cache-top
configuration matrix cannot reach, and sweeping widths here would add runtime
without adding coverage.

The agent has a driver but no monitor. These DUTs have no handshake and several
are purely combinational, so the sampling instant is defined entirely by the
stimulus; an independent monitor could only duplicate the driver's timing. The
comparison still lives in the scoreboard, so the component that drives is not
the component that decides pass or fail.

The block tests check:

- L1 line memory byte-write behavior.
- L1 tag/valid write and address-selective invalidate behavior.
- L2 dual-port line memory writes and byte enables.
- L1 load and store helper byte placement.
- L1 replacement choices for empty, partially valid, and LRU-selected sets.
- L2 replacement same-index dual-port write selection.
- A controller data-side line-fill subflow with four native memory read beats.

## Scoreboard Regression

`make uvm-scoreboard` runs the UVM regression test across the configuration
matrix below. Geometry cases rebuild because they change port widths; the
memory-responder cases are runtime plusargs and reuse the default build.

The environment keeps two independent copies of a byte-addressed reference
memory: one is the scoreboard's oracle, updated from observed CPU writes, and
one is the memory responder's backing store, updated from observed memory
writes. Both start from the same generated pattern, so a write-through defect
appears as divergence between them on the next access that reaches memory.

A run that observes no CPU-side traffic fails rather than passing silently, and
each case is gated on an explicit pass banner rather than the simulator exit
status, which UVM always leaves at zero.

It checks:

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
- Write-through data actually reaching main memory, checked by invalidating the
  cache and re-reading so the value is served from memory rather than the array.
- Runtime global and address-selective line maintenance handshakes.
- Address-selective line invalidate forcing a refill only for the targeted line.
- Address-selective line flush as a write-through no-op.
- Illegal maintenance request combinations returning `maint_error`.
- Queued maintenance requests accepted while cache traffic is active.
- Reset during an active transaction and repeated reset recovery.
- The documented unsupported I/D coherency contract: data-side writes do not update an already-filled instruction L1 line until maintenance invalidates the line.

`make uvm-random` generates six legal parameter combinations from a time-based seed and runs the regression on them. The runner prints the seed and accepts `RANDOM_SEED=<seed>` and `RANDOM_CASE_COUNT=<count>` overrides for reproducing failures.

`make verify` runs `make check`, `make uvm-scoreboard`, `make uvm-random`,
`make uvm-traffic`, `make block-tests`, and `make parameter-compile`. It is the
gate CI enforces on every push and pull request.

Three always-on checkers run inside every one of those cases, alongside the
scoreboard:

- `tb/sva/cache_sva.sv` -- protocol assertions on the interface pins, each one
  stated in `docs/TIMING_CONTRACT.md`.
- `tb/sva/cache_dup_tag_check.sv` -- no set may hold the same tag valid in both
  ways. Structural, so it reaches into the DUT; a duplicate has no expression at
  the interface, which is why D5 went unnoticed until a read happened to land on
  the shadowed copy.
- `tb/sva/cache_wt_l2_check.sv` -- a store that updates an L1 way under
  write-through must also update L2's copy of the same line. Validated by fault
  injection rather than by never having failed: gating write-through out of L2's
  write enable makes it fire within 9us.

The first two fire at the cycle the fault is created rather than whenever a read
later exposes it, which is the difference between a defect that is debuggable
and one that is a mystery hundreds of accesses later.

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
