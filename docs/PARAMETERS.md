# Cache Parameter Contract

This document records the current parameter contract for `cache`.

The cache now has width-clean RTL elaboration and scoreboard coverage for selected non-default configurations. The supported matrix is still intentionally narrow and should grow only with regression coverage.

## Top-Level Parameters

| Parameter | Default | Meaning |
| --- | ---: | --- |
| `ADDR_WIDTH` | 19 | CPU/cache byte-address width. |
| `DATA_WIDTH` | 64 | Data-side raw request and response width. |
| `MEM_DATA_WIDTH` | 32 | Native memory-side beat width. |
| `LINE_WIDTH` | 128 | Cache line width. |
| `L1_INDEX_WIDTH` | 6 | L1 set index width per way. |
| `L2_INDEX_WIDTH` | 8 | L2 set index width per way. |
| `MEMORY_BASE_ADDR` | `32'h2000_0000` | Native memory address base added to cache-local addresses. The default preserves the original low cache-local address bits. |

## Derived Widths

For the default configuration:

| Derived value | Formula | Value |
| --- | --- | ---: |
| Data-side byte lanes | `DATA_WIDTH / 8` | 8 |
| Memory-side byte lanes | `MEM_DATA_WIDTH / 8` | 4 |
| Line bytes | `LINE_WIDTH / 8` | 16 |
| Memory beats per line | `LINE_WIDTH / MEM_DATA_WIDTH` | 4 |
| L1 word offset bits | `log2((LINE_WIDTH / 8) / 4)` | 2 |
| Line byte offset bits | `log2(LINE_WIDTH / 8)` | 4 |
| L1 tag width | `ADDR_WIDTH - L1_INDEX_WIDTH - L1_WORD_OFFSET_WIDTH - 2` | 9 |
| L2 address width | `ADDR_WIDTH - LINE_OFFSET_WIDTH` | 15 |
| L2 tag width | `L2_ADDR_WIDTH - L2_INDEX_WIDTH` | 7 |

## Current Verification Status

Behaviorally verified by smoke and scoreboard:

- default: `ADDR_WIDTH=19`, `DATA_WIDTH=64`, `MEM_DATA_WIDTH=32`, `LINE_WIDTH=128`
- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`

Compile/lint swept by `make parameter-compile`:

- default configuration
- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`

The scoreboard runs prove the directed cache behaviors listed in `docs/VERIFICATION_PLAN.md` for those single-parameter overrides. Combined non-default configurations and index-width changes are not proven yet.

## Legal Range Rules

The intended legal range is:

- `ADDR_WIDTH` must be large enough to contain tag, index, word offset, and byte offset fields.
- `DATA_WIDTH`, `MEM_DATA_WIDTH`, and `LINE_WIDTH` must be byte multiples.
- `DATA_WIDTH`, `MEM_DATA_WIDTH`, and `LINE_WIDTH` should be powers of two.
- `LINE_WIDTH` must be an integer multiple of `MEM_DATA_WIDTH`.
- `LINE_WIDTH` must be at least as wide as `DATA_WIDTH`.
- `L1_INDEX_WIDTH` and `L2_INDEX_WIDTH` must leave at least one tag bit.
- `MEMORY_BASE_ADDR + cache-local address` must fit within the 32-bit native memory address output.

## Remaining Unsupported Claims

Do not claim behavioral support for combinations that are not explicitly covered by scoreboard or directed tests.

Specific remaining risks:

- Fill sequencing now uses a derived memory-beat count and is tested for `MEM_DATA_WIDTH=64` and `LINE_WIDTH=256`.
- Write-through sequencing now uses a derived memory-beat index and is tested for one-beat, two-beat, and three-beat directed writes in the current scoreboard matrix.
- Wider `DATA_WIDTH` values above the current 64-bit default are not behaviorally supported until load/store line-boundary behavior is specified and tested.
- L1 and L2 replacement behavior is not yet swept across non-default index widths.
- Combined non-default configurations are not yet swept behaviorally.
