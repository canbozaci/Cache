# Cache Soft-IP Gap Analysis

## Current Baseline

- Repository scope is generic cache IP only; CPU and memory bus adaptors live in sibling repositories.
- Active RTL is under `rtl/`, uses `.sv`, and builds from `filelists/rtl.f`.
- Public integration top is `cache`.
- Historical demo RAM, UART, and program-image files are out of the active tree.
- `make verify` passes: compile, lint/style, smoke simulation, and self-checking scoreboard.
- Parameter intent is now documented in `docs/PARAMETERS.md`.
- CI is configured on GitHub Actions for the cleanup branch.

## Remaining Design Gaps

- The cache is not truly parameter-generic yet. The supported configuration is still `ADDR_WIDTH=19`, `DATA_WIDTH=64`, `MEM_DATA_WIDTH=32`, `LINE_WIDTH=128`.
- The controller still contains hard-coded address slices, 32-bit memory beats, four-beat fills, 64-bit data accesses, and fixed strobe widths.
- The public cache timing contract is incomplete: request stability, response validity, and legal simultaneous command behavior need to be frozen.
- The native memory side has no ready/valid, wait-state, burst, or variable-latency contract.
- `clk` and `mem_clk` are treated as related clocks; there is no CDC implementation or constraint guidance.
- Instruction and data L1 caches are not coherent with each other after data-side writes.
- Runtime flush, invalidate, and maintenance operations are not defined.
- ASIC SRAM macro replacement wrappers and read/write behavior assumptions are not defined.
- Historical module names remain in several internal blocks.
- Tag/valid inferred-memory resets are written to satisfy both local and GitHub Actions Verilator versions, but the release SRAM strategy is still unresolved.

## Remaining Verification Gaps

- No parameter sweep exists beyond the default configuration.
- Replacement, eviction, same-index dual-port, and write-through corner cases need focused tests.
- There are no block-level self-checking tests for arrays, replacement modules, load/store helpers, or controller subflows.
- Native memory verification does not model backpressure or variable latency.
- Reset-during-transaction and repeated-reset scenarios are not covered.
- Assertions and functional coverage are missing.
- Unsupported instruction/data coherency behavior is documented but not locked by a dedicated contract test.

## Remaining Documentation Gaps

- The IP contract needs a dedicated timing document for clocks, reset, requests, responses, memory transactions, and legal command combinations.
- Timing diagrams are missing for read hit, read miss, instruction miss, data write hit, data write miss, and simultaneous instruction/data traffic.
- `docs/PARAMETERS.md` exists, but it currently documents mostly unsupported non-default combinations rather than proven generic operation.
- Reset, invalidate, SRAM macro integration, and known limitations need release-facing integration notes.
- License and reuse terms still need to be checked before describing the IP as redistributable.

## Priority Plan

P0 before first real version:

- Keep `make verify` passing after every update.
- Freeze the default parameter contract and reject/avoid unsupported parameter claims.
- Freeze the public cache request/response and native memory timing contract.
- Add focused replacement and eviction tests.
- Decide whether `clk` and `mem_clk` are synchronous-only or require real CDC.

P1 for real bus-width genericity:

- Derive line fill count from `LINE_WIDTH / MEM_DATA_WIDTH`.
- Derive data byte lanes and write strobes from `DATA_WIDTH / 8`.
- Derive memory byte lanes and write strobes from `MEM_DATA_WIDTH / 8`.
- Replace hard-coded address slices with derived tag/index/offset parameters.
- Add parameter sweeps for at least 32/64-bit data width and 32/64-bit memory width.

P2 before release maturity:

- Add protocol assertions and functional coverage.
- Define ASIC SRAM macro wrappers and memory behavior assumptions.
- Add flush/invalidate if instruction/data coherency or runtime maintenance is required.
- Clean remaining historical module names after verification protects the behavior.
