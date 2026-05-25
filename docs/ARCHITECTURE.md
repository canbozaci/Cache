# Cache Architecture

## Repository Boundaries

This repository contains only the reusable generic cache IP. CPU-side and memory-side bus adaptors are intentionally kept in sibling repositories.

```text
filelists/rtl.f     Reusable cache build list
rtl/                     All synthesizable cache RTL
../cache_riscv_adaptor   CPU-side adaptor repository
../cache_ahb_adaptor     Memory-side bus adaptor repository
```

## Reusable Core Interface

`cache` is the architecture-neutral integration point. It accepts generic instruction and data requests:

- Instruction side: valid plus byte address, returning raw 32-bit fetch data.
- Data side: read/write command, byte address, raw write data, byte write strobes, and raw read data.
- Memory side: single-clock native request/response interface for line fills and write-through traffic.
- Maintenance side: idle-only flush and invalidate requests.

The cache does not consume ISA-specific load/store encoding values and does not perform sign extension.

The cache has one clock, `clk`. External memory can run at any frequency, but clock crossing is not part of the generic cache. A memory adaptor must bridge the native cache memory interface into the target memory clock domain, using an async FIFO or another CDC structure when needed.

The native memory request channel is:

- `mem_req_valid`
- `mem_req_ready`
- `mem_req_write`
- `mem_req_addr`
- `mem_req_wdata`
- `mem_req_wstrb`

The native memory response channel is:

- `mem_rsp_valid`
- `mem_rsp_ready`
- `mem_rsp_rdata`

Writes complete when the request is accepted. Reads complete when the response is valid.

The native cache memory interface is intentionally beat-based, not burst-based:

- The cache issues at most one outstanding request.
- Each `mem_req_valid && mem_req_ready` handshake transfers exactly one memory beat.
- Read responses must return in request order.
- Line fills are emitted as ordered, contiguous, line-aligned single-beat reads.
- Write-through traffic is emitted as independent single-beat writes.
- The generic cache does not expose burst length, burst type, lock, exclusive, or ID fields.

Memory adaptors may coalesce contiguous cache read beats into a bus burst when the target bus supports it. That coalescing is an adaptor optimization and must preserve the cache-visible beat order and response contract.

`cache` can be checked without any CPU adapter:

```sh
make compile-cache
```

## Parameter Contract

The public top exposes `ADDR_WIDTH`, `DATA_WIDTH`, `MEM_DATA_WIDTH`, and `LINE_WIDTH`. The current verified matrix is documented in `docs/PARAMETERS.md`; it includes the default configuration plus selected single-parameter and combined non-default configurations:

- `ADDR_WIDTH = 19`
- `DATA_WIDTH = 64`
- `MEM_DATA_WIDTH = 32`
- `LINE_WIDTH = 128`

See `docs/PARAMETERS.md` for legal values, derived widths, unsupported combinations, and the bus-width genericity roadmap.

## Adaptor Repositories

The CPU adaptor repository owns load/store formatting and CPU-facing port conventions.

The memory adaptor repository owns translation from the beat-based native cache memory side into a SoC bus protocol. It also owns any burst coalescing and CDC required by the target memory subsystem.
