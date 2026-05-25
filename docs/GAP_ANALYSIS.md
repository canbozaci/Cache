# Cache Soft-IP Gap Analysis

## Current Baseline

- Repository scope is generic cache IP only; CPU and memory bus adaptors live in sibling repositories.
- Active RTL is under `rtl/`, uses `.sv`, and builds from `filelists/rtl.f`.
- Public integration top is `cache`.
- CI is configured on GitHub Actions for the cleanup branch using a current checkout action.
- `make verify` runs compile, lint/style, smoke simulation, twenty directed scoreboard configurations, seeded random scoreboard configurations, block-level tests, and parameter compile sweep.
- `cache` is single-clock; `mem_clk` has been removed from the public cache interface.
- Native memory traffic uses a single-clock, beat-based request/response interface with request ready and response valid handshakes.
- Native memory line-fill reads expose generic burst metadata: burst valid, total beat count, beat index, first beat, and last beat.
- Multi-beat write-through traffic exposes the same generic burst metadata as line fills.
- The generic cache still transfers one memory beat per handshake; bus-specific burst encoding and coalescing belong in a memory adaptor or higher-level SoC integration.
- Internal RTL module and file names have been normalized to lowercase `cache_*` names; shared L1/L2 storage helpers use `cache_l*_memory_*` names to avoid implying data-cache-only ownership.
- Public set geometry uses `L1_DATA_SET_COUNT`, `L1_INSTR_SET_COUNT`, and `L2_SET_COUNT`; L1/L2 index widths are derived internally, and `L1_SET_COUNT` remains as the backward-compatible default for both L1 sides.
- L1 and L2 way count is fixed at 2.
- Width plumbing derives byte-enable widths, data-side strobe width, memory-side strobe width, line byte count, L1 tag width, L2 tag width, and L2 address width from top-level parameters.
- Line fill sequencing uses a derived `LINE_WIDTH / MEM_DATA_WIDTH` beat count instead of fixed four-beat controller states.
- Write-through sequencing uses a derived write-beat index, memory-byte strobes generated per beat, `MEM_ADDR_STEP`, and line-offset based memory data selection.
- Behavioral support is proven for the default configuration, single-parameter overrides, multiple L1/L2 set-count cases, split L1 set counts, and the combined non-default scoreboard configurations documented in `docs/PARAMETERS.md`.
- CI also runs seeded random scoreboard parameter combinations, with the seed printed for reproduction.
- `DATA_WIDTH=128` is proven for `LINE_WIDTH=256`, including the `MEM_DATA_WIDTH=64` combination.
- The line-boundary contract is defined: one data request must not cross a cache-line boundary.
- The scoreboard now covers one-beat, two-beat, and unaligned three-beat write-through cases across the current width matrix.
- The scoreboard includes a ready-stall memory run.
- Runtime global flush is defined as a write-through no-op, and runtime global invalidate clears the cache arrays while idle.
- Maintenance requests use an intentional fixed single-entry queue and may be accepted while cache traffic is active.
- Address-selective line flush/invalidate is implemented; line flush is a write-through no-op, and line invalidate clears matching tag/valid entries in L1 data, L1 instruction, and L2.
- The scoreboard covers illegal maintenance request combinations, reset during active traffic, repeated reset recovery, and the documented unsupported I/D coherency behavior.
- Focused verification covers L1 replacement eviction, L2 replacement same-index dual-port selection, write-through burst corner cases, block-level arrays, replacement helpers, load/store helpers, and a controller line-fill subflow.
- Native memory verification includes ready stalls plus fixed and variable response-latency scoreboard runs.

## Remaining Design Gaps

- Data widths above 128 bits are not release-supported yet.
- The public cache timing contract is incomplete: request stability, response validity, and legal simultaneous command behavior need to be frozen.
- Instruction and data L1 caches are not coherent with each other after data-side writes.

## Integration Notes

- CDC is intentionally outside the generic cache; asynchronous clock crossing must be implemented in a memory adaptor or higher-level SoC integration.
- Bus-specific burst semantics are intentionally outside the generic cache; adaptors translate generic burst metadata into the target bus protocol.
- Maintenance queue depth is intentionally fixed at one; back-to-back software maintenance streams require external request pacing.
- SRAM macro hooks are adapter-based and role-specific for L1 data/instruction memories. Project-specific macro-backed configurations belong in integration repositories and are not expected to compile in this generic cache CI.

## Remaining Verification Gaps

- Assertions and functional coverage are missing.

## Remaining Documentation Gaps

- The IP contract needs a dedicated timing document for clocks, reset, requests, responses, memory transactions, and legal command combinations.
- Timing diagrams are missing for read hit, read miss, instruction miss, data write hit, data write miss, and simultaneous instruction/data traffic.
- `docs/PARAMETERS.md` documents the currently swept matrix, but a release-facing support matrix still needs more corner-case evidence.
- Reset, maintenance, and known limitations need release-facing integration notes.
- License and reuse terms still need to be checked before describing the IP as redistributable.

## Priority Plan

P0 before first real version:

- Keep `make verify` passing after every update.
- Write the public cache request/response and native memory timing contract as a dedicated integration document.

P1 for stronger bus-width genericity:

- Add parameter checks for illegal combinations.
- Add scoreboard coverage for `DATA_WIDTH` values above 128 bits when needed.
- Sweep more L1/L2 set counts after replacement tests are stronger.
- Add directed tests around write strobes at memory-beat and line boundaries.

P2 before release maturity:

- Add protocol assertions and functional coverage.
- Clean remaining historical module names after verification protects the behavior.
