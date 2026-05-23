# Cache Soft-IP Gap Analysis

## Current Baseline

- Repository scope is generic cache IP only; CPU and memory bus adaptors live in sibling repositories.
- Active RTL is under `rtl/`, uses `.sv`, and builds from `filelists/rtl.f`.
- Public integration top is `cache`.
- CI is configured on GitHub Actions for the cleanup branch using a current checkout action.
- `make verify` now runs compile, lint/style, smoke simulation, scoreboard, and parameter compile sweep.
- Width plumbing now derives byte-enable widths, data-side strobe width, memory-side strobe width, line byte count, L1 tag width, L2 tag width, and L2 address width from top-level parameters.

## Remaining Design Gaps

- Full behavioral support is still proven only for the default configuration: `ADDR_WIDTH=19`, `DATA_WIDTH=64`, `MEM_DATA_WIDTH=32`, `LINE_WIDTH=128`.
- Non-default `ADDR_WIDTH`, `DATA_WIDTH`, `MEM_DATA_WIDTH`, and `LINE_WIDTH` now compile cleanly in selected sweeps, but functional tests for those configurations are not implemented yet.
- The controller still uses the historical fixed flow for line fills and write-through sequencing. It needs a beat-counter based controller before non-default beat counts can be considered behaviorally supported.
- The public cache timing contract is incomplete: request stability, response validity, and legal simultaneous command behavior need to be frozen.
- The native memory side has no ready/valid, wait-state, burst, or variable-latency contract.
- `clk` and `mem_clk` are treated as related clocks; there is no CDC implementation or constraint guidance.
- Instruction and data L1 caches are not coherent with each other after data-side writes.
- Runtime flush, invalidate, and maintenance operations are not defined.
- ASIC SRAM macro replacement wrappers and read/write behavior assumptions are not defined.
- Historical module names remain in several internal blocks.

## Remaining Verification Gaps

- Functional parameter sweeps are missing beyond the default configuration.
- Replacement, eviction, same-index dual-port, and write-through corner cases need focused tests.
- There are no block-level self-checking tests for arrays, replacement modules, load/store helpers, or controller subflows.
- Native memory verification does not model backpressure or variable latency.
- Reset-during-transaction and repeated-reset scenarios are not covered.
- Assertions and functional coverage are missing.
- Unsupported instruction/data coherency behavior is documented but not locked by a dedicated contract test.

## Remaining Documentation Gaps

- The IP contract needs a dedicated timing document for clocks, reset, requests, responses, memory transactions, and legal command combinations.
- Timing diagrams are missing for read hit, read miss, instruction miss, data write hit, data write miss, and simultaneous instruction/data traffic.
- `docs/PARAMETERS.md` documents compile-clean non-default configurations, but the release-facing supported behavior matrix still needs functional evidence.
- Reset, invalidate, SRAM macro integration, and known limitations need release-facing integration notes.
- License and reuse terms still need to be checked before describing the IP as redistributable.

## Priority Plan

P0 before first real version:

- Keep `make verify` passing after every update.
- Replace fixed fill/write-through state progression with beat-counter based sequencing.
- Freeze the public cache request/response and native memory timing contract.
- Add focused replacement and eviction tests.
- Decide whether `clk` and `mem_clk` are synchronous-only or require real CDC.

P1 for true bus-width genericity:

- Add behavioral smoke/scoreboard configurations for `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, and `LINE_WIDTH=256`.
- Add parameter checks for illegal combinations.
- Derive memory address word selection from `MEM_DATA_WIDTH`, not fixed 32-bit word positions.
- Sweep L1/L2 index widths after replacement tests are stronger.

P2 before release maturity:

- Add protocol assertions and functional coverage.
- Define ASIC SRAM macro wrappers and memory behavior assumptions.
- Add flush/invalidate if instruction/data coherency or runtime maintenance is required.
- Clean remaining historical module names after verification protects the behavior.
