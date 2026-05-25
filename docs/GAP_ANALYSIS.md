# Cache Soft-IP Gap Analysis

This file tracks only unresolved gaps for the generic cache IP. Stable baseline and integration details live in:

- `docs/ARCHITECTURE.md` for repository boundaries, public interfaces, maintenance behavior, native memory protocol, and adaptor responsibilities.
- `docs/PARAMETERS.md` for legal parameter ranges, derived widths, supported configurations, and unsupported parameter claims.
- `docs/SRAM_INTEGRATION.md` for ASIC SRAM macro wrapper expectations and project-owned macro adapter hooks.
- `docs/VERIFICATION_PLAN.md` for the current regression gates, scoreboard matrix, random runs, block tests, and integration verification responsibilities.

## Remaining Design Gaps

- Data widths above 128 bits are not release-supported yet.
- The public cache timing contract is incomplete: request stability, response validity, and legal simultaneous command behavior need to be frozen.
- Instruction and data L1 caches are intentionally not coherent after data-side writes; if coherency becomes required, the cache needs a coherency or maintenance policy instead of the current documented limitation.

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
