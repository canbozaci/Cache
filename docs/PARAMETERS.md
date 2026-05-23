# Cache Parameter Contract

This document records the current parameter contract for `cache`.

The cache now has width-clean RTL elaboration for selected non-default configurations. Full behavioral verification is still complete only for the default configuration used by the smoke and scoreboard tests.

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

- `ADDR_WIDTH=19`
- `DATA_WIDTH=64`
- `MEM_DATA_WIDTH=32`
- `LINE_WIDTH=128`
- `L1_INDEX_WIDTH=6`
- `L2_INDEX_WIDTH=8`

Compile/lint swept by `make parameter-compile`:

- default configuration
- `ADDR_WIDTH=20`
- `DATA_WIDTH=32`
- `MEM_DATA_WIDTH=64`
- `LINE_WIDTH=256`

The compile sweep proves these configurations are width-clean at elaboration. It does not yet prove all cache behavior for those non-default configurations.

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

Do not claim behavioral support for non-default configurations until tests cover them.

Specific remaining risks:

- Fill sequencing still follows the existing controller flow and is not yet behaviorally tested for non-default memory beat counts.
- Write-through sequencing is not yet behaviorally tested for non-default `DATA_WIDTH` or `MEM_DATA_WIDTH`.
- L1 and L2 replacement behavior is not yet swept across non-default index widths.
- Testbenches still use the default configuration for functional checks.
