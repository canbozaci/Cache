# Cache Soft-IP Gap Analysis

## Current Baseline

- Repository scope is generic cache IP only; CPU and memory bus adaptors live in sibling repositories.
- Active RTL is under `rtl/`, uses `.sv`, and builds from `filelists/rtl.f`.
- Public integration top is `cache`.
- CI is configured on GitHub Actions for the cleanup branch using a current checkout action.
- `make verify` runs compile, lint/style, smoke simulation, five scoreboard configurations, and parameter compile sweep.
- Width plumbing derives byte-enable widths, data-side strobe width, memory-side strobe width, line byte count, L1 tag width, L2 tag width, and L2 address width from top-level parameters.
- Line fill sequencing uses a derived `LINE_WIDTH / MEM_DATA_WIDTH` beat count instead of fixed four-beat controller states.
- Write-through sequencing uses a derived write-beat index, memory-byte strobes generated per beat, `MEM_ADDR_STEP`, and line-offset based memory data selection.
- The scoreboard now covers one-beat, two-beat, and unaligned three-beat write-through cases across the current width matrix.

## Remaining Design Gaps

- Behavioral support is proven only for the default configuration and single-parameter scoreboard overrides: `ADDR_WIDTH=20`, `DATA_WIDTH=32`, `MEM_DATA_WIDTH=64`, and `LINE_WIDTH=256`.
- Combined non-default configurations are not behaviorally swept.
- Data widths above 64 bits are not release-supported yet; the line-boundary behavior for a single data request must be specified before advertising wider `DATA_WIDTH` support.
- The public cache timing contract is incomplete: request stability, response validity, and legal simultaneous command behavior need to be frozen.
- The native memory side has no ready/valid, wait-state, burst, or variable-latency contract.
- `clk` and `mem_clk` are treated as related clocks; there is no CDC implementation or constraint guidance.
- Instruction and data L1 caches are not coherent with each other after data-side writes.
- Runtime flush, invalidate, and maintenance operations are not defined.
- ASIC SRAM macro replacement wrappers and read/write behavior assumptions are not defined.
- Historical module names remain in several internal blocks.

## Remaining Verification Gaps

- Combined parameter sweeps are missing.
- L1/L2 index-width sweeps are missing.
- Data widths wider than 64 bits need dedicated line-boundary tests after the contract is defined.
- Replacement, eviction, same-index dual-port, and write-through corner cases need focused tests.
- There are no block-level self-checking tests for arrays, replacement modules, load/store helpers, or controller subflows.
- Native memory verification does not model backpressure or variable latency.
- Reset-during-transaction and repeated-reset scenarios are not covered.
- Assertions and functional coverage are missing.
- Unsupported instruction/data coherency behavior is documented but not locked by a dedicated contract test.

## Remaining Documentation Gaps

- The IP contract needs a dedicated timing document for clocks, reset, requests, responses, memory transactions, and legal command combinations.
- Timing diagrams are missing for read hit, read miss, instruction miss, data write hit, data write miss, and simultaneous instruction/data traffic.
- `docs/PARAMETERS.md` documents the currently swept matrix, but a release-facing support matrix still needs more corner-case evidence.
- Reset, invalidate, SRAM macro integration, and known limitations need release-facing integration notes.
- License and reuse terms still need to be checked before describing the IP as redistributable.

## Priority Plan

P0 before first real version:

- Keep `make verify` passing after every update.
- Define whether a data-side request may cross a cache-line boundary, then add or reject tests for that behavior.
- Add combined parameter scoreboard runs after the line-boundary rule is explicit.
- Freeze the public cache request/response and native memory timing contract.
- Add focused replacement and eviction tests.
- Decide whether `clk` and `mem_clk` are synchronous-only or require real CDC.

P1 for stronger bus-width genericity:

- Add parameter checks for illegal combinations.
- Add scoreboard coverage for wider `DATA_WIDTH` values if the line-boundary contract allows them.
- Sweep L1/L2 index widths after replacement tests are stronger.
- Add directed tests around write strobes at memory-beat and line boundaries.

P2 before release maturity:

- Add protocol assertions and functional coverage.
- Define ASIC SRAM macro wrappers and memory behavior assumptions.
- Add flush/invalidate if instruction/data coherency or runtime maintenance is required.
- Clean remaining historical module names after verification protects the behavior.
