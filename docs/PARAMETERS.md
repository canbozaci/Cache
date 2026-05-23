# Cache Parameter Contract

This document records the current parameter contract for `cache`.

The top-level has width parameters, but the full RTL is not yet proven across multiple configurations. Until the internal controller, arrays, and tests are generalized, only the defaults below are supported.

## Current Supported Configuration

| Parameter | Default | Current legal value | Rationale |
| --- | ---: | ---: | --- |
| `ADDR_WIDTH` | 19 | 19 | Matches the existing controller address slicing and 512 KiB byte-addressed test space. |
| `DATA_WIDTH` | 64 | 64 | The data-side cache request path currently supports one 64-bit CPU-side data access. |
| `MEM_DATA_WIDTH` | 32 | 32 | The native memory side currently moves one 32-bit beat at a time. |
| `LINE_WIDTH` | 128 | 128 | Cache line fill state machines currently fetch four 32-bit memory beats per line. |

## Derived Widths

For the default configuration:

| Derived value | Formula | Value |
| --- | --- | ---: |
| Data-side byte lanes | `DATA_WIDTH / 8` | 8 |
| Memory-side byte lanes | `MEM_DATA_WIDTH / 8` | 4 |
| Line bytes | `LINE_WIDTH / 8` | 16 |
| Memory beats per line | `LINE_WIDTH / MEM_DATA_WIDTH` | 4 |
| Data beats per line | `LINE_WIDTH / DATA_WIDTH` | 2 |
| Byte offset bits inside memory word | `log2(MEM_DATA_WIDTH / 8)` | 2 |
| Byte offset bits inside line | `log2(LINE_WIDTH / 8)` | 4 |

## Unsupported Combinations

These are not supported yet:

- `MEM_DATA_WIDTH` other than 32.
- `DATA_WIDTH` other than 64.
- `LINE_WIDTH` other than 128.
- `ADDR_WIDTH` other than 19.
- `DATA_WIDTH > LINE_WIDTH`.
- `MEM_DATA_WIDTH > LINE_WIDTH`.
- Widths that are not byte multiples.
- Widths that are not powers of two.
- Any configuration where `LINE_WIDTH` is not an integer multiple of both `DATA_WIDTH` and `MEM_DATA_WIDTH`.

## Direction For True Bus-Width Genericity

The desired long-term contract is:

- CPU/data-side raw data width is controlled by `DATA_WIDTH`.
- Native memory beat width is controlled by `MEM_DATA_WIDTH`.
- Cache line size is controlled by `LINE_WIDTH`.
- Internal fill and write-through sequencing derives the number of memory beats from `LINE_WIDTH / MEM_DATA_WIDTH`.
- Store and load datapath helpers derive byte-lane counts from `DATA_WIDTH / 8`.
- Cache arrays derive byte-enable width from `LINE_WIDTH / 8`.
- Tests run a parameter sweep across at least 32-bit and 64-bit data-side widths and 32-bit and 64-bit memory-side widths.

Before allowing non-default parameter values, the controller must remove hard-coded 19-bit addresses, 15-bit L2 addresses, 32-bit memory beats, four-beat fills, 64-bit data-side accesses, and fixed byte-strobe widths.
