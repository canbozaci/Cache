# Cache Soft-IP Gap Analysis

This file tracks only unresolved gaps for the generic cache IP. Stable baseline and integration
details live in:

- `docs/ARCHITECTURE.md` for repository boundaries, public interfaces, maintenance behavior, native
  memory protocol, and adaptor responsibilities.
- `docs/PARAMETERS.md` for legal parameter ranges, derived widths, supported configurations, and
  unsupported parameter claims.
- `docs/SRAM_INTEGRATION.md` for ASIC SRAM macro wrapper expectations and project-owned macro
  adapter hooks.
- `docs/TIMING_CONTRACT.md` for clocks, reset, CPU-side request timing, native memory handshakes,
  maintenance commands, known coherency limitations, and timing diagrams.
- `docs/NATIVE_MEMORY_PROTOCOL.md` for native memory request, read-response, and write-response
  channels.
- `docs/ERROR_HANDLING.md` for CPU-side and native-memory error behavior.
- `docs/VERIFICATION_PLAN.md` for the current regression gates, scoreboard matrix, random runs,
  block tests, and integration verification responsibilities.
- `docs/RELEASE_CHECKLIST.md` for release gates and pre-tag checklist items.

## Remaining Design Gaps

- Data widths above 128 bits are not release-supported yet.

## Remaining Verification Gaps

- Assertions and functional coverage are missing.

## Priority Plan

P0 before first real version:

- Keep `make verify` passing after every update.
- Keep release collateral aligned with the current public IP contract.

P1 for stronger bus-width genericity:

- Add parameter checks for illegal combinations.
- Add scoreboard coverage for `DATA_WIDTH` values above 128 bits when needed.
- Sweep more L1/L2 set counts after replacement tests are stronger.
- Add directed tests around write strobes at memory-beat and line boundaries.

P2 before release maturity:

- Add protocol assertions and functional coverage.
