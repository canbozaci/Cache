# Cache Soft-IP Gap Analysis

## Current Baseline

- Repository scope is generic cache IP only; CPU and memory bus adaptors live in sibling repositories.
- Active RTL is under `rtl/`, uses `.sv`, and builds from `filelists/rtl.f`.
- Public integration top is `cache`.
- CI is configured on GitHub Actions for the cleanup branch using a current checkout action.
- `make verify` runs compile, lint/style, smoke simulation, ten scoreboard configurations, and parameter compile sweep.
- `cache` is single-clock; `mem_clk` has been removed from the public cache interface.
- Native memory traffic uses a single-clock request/response interface with request ready and response valid handshakes.
- Width plumbing derives byte-enable widths, data-side strobe width, memory-side strobe width, line byte count, L1 tag width, L2 tag width, and L2 address width from top-level parameters.
- Line fill sequencing uses a derived `LINE_WIDTH / MEM_DATA_WIDTH` beat count instead of fixed four-beat controller states.
- Write-through sequencing uses a derived write-beat index, memory-byte strobes generated per beat, `MEM_ADDR_STEP`, and line-offset based memory data selection.
- Behavioral support is proven for the default configuration, single-parameter overrides, and the combined non-default scoreboard configurations documented in `docs/PARAMETERS.md`.
- The scoreboard now covers one-beat, two-beat, and unaligned three-beat write-through cases across the current width matrix.
- The scoreboard includes a ready-stall memory run.
- Runtime flush is defined as a write-through no-op, and runtime invalidate clears the cache arrays while idle.

## Remaining Design Gaps

- Combined non-default configurations outside the current scoreboard matrix are not behaviorally swept.
- Data widths above 64 bits are not release-supported yet; the line-boundary behavior for a single data request must be specified before advertising wider `DATA_WIDTH` support.
- The public cache timing contract is incomplete: request stability, response validity, and legal simultaneous command behavior need to be frozen.
- The native memory side supports single-beat request/response handshakes, but burst semantics are not defined.
- CDC is intentionally outside the generic cache; asynchronous clock crossing must be implemented in a memory adaptor.
- Instruction and data L1 caches are not coherent with each other after data-side writes.
- Maintenance is currently global idle-only flush/invalidate; address-selective line maintenance is not implemented.
- ASIC SRAM macro replacement wrappers and read/write behavior assumptions are not defined.
- Historical module names remain in several internal blocks.

## Remaining Verification Gaps

- Combined parameter sweeps are present for the current width matrix, but are not exhaustive.
- L1/L2 index-width sweeps are missing.
- Data widths wider than 64 bits need dedicated line-boundary tests after the contract is defined.
- Replacement, eviction, same-index dual-port, and write-through corner cases need focused tests.
- There are no block-level self-checking tests for arrays, replacement modules, load/store helpers, or controller subflows.
- Native memory verification has a ready-stall run, but does not yet cover broad response-latency patterns.
- Reset-during-transaction and repeated-reset scenarios are not covered.
- Assertions and functional coverage are missing.
- Unsupported instruction/data coherency behavior is documented but not locked by a dedicated contract test.

## Remaining Documentation Gaps

- The IP contract needs a dedicated timing document for clocks, reset, requests, responses, memory transactions, and legal command combinations.
- Timing diagrams are missing for read hit, read miss, instruction miss, data write hit, data write miss, and simultaneous instruction/data traffic.
- `docs/PARAMETERS.md` documents the currently swept matrix, but a release-facing support matrix still needs more corner-case evidence.
- Reset, maintenance, SRAM macro integration, and known limitations need release-facing integration notes.
- License and reuse terms still need to be checked before describing the IP as redistributable.

## Priority Plan

P0 before first real version:

- Keep `make verify` passing after every update.
- Define whether a data-side request may cross a cache-line boundary, then add or reject tests for that behavior.
- Extend combined parameter scoreboard runs after the line-boundary rule is explicit.
- Write the public cache request/response and native memory timing contract as a dedicated integration document.
- Add focused replacement and eviction tests.
- Define memory-adaptor CDC expectations for external memory clocks.

P1 for stronger bus-width genericity:

- Add parameter checks for illegal combinations.
- Add scoreboard coverage for wider `DATA_WIDTH` values if the line-boundary contract allows them.
- Sweep L1/L2 index widths after replacement tests are stronger.
- Add directed tests around write strobes at memory-beat and line boundaries.

P2 before release maturity:

- Add protocol assertions and functional coverage.
- Define ASIC SRAM macro wrappers and memory behavior assumptions.
- Add address-selective line flush/invalidate if instruction/data coherency or runtime maintenance requires it.
- Clean remaining historical module names after verification protects the behavior.
