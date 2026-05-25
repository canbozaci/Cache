# Cache Architecture

## Product Profile

`cache` is a reusable, non-coherent, blocking, write-through SystemVerilog cache subsystem for embedded and single-core integration.

Supported profile:

- Single cache clock.
- Non-coherent instruction/data L1 behavior.
- Write-through data writes.
- Blocking command-style CPU-side interface.
- Native beat-based memory request/response interface.
- External CPU and memory adaptors.

Not supported yet:

- SMP coherency.
- DMA coherency.
- Built-in AXI, AHB, or TileLink bus adapters.
- Write-back mode.
- Multiple outstanding misses.
- ECC or parity.

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
- Maintenance side: queued global and address-selective line flush/invalidate requests.

The cache does not consume ISA-specific load/store encoding values and does not perform sign extension.

The cycle-level request, response, reset, maintenance, and native memory timing rules are frozen in `docs/TIMING_CONTRACT.md`.

The cache has one clock, `clk`. External memory can run at any frequency, but clock crossing is not part of the generic cache. A memory adaptor must bridge the native cache memory interface into the target memory clock domain, using an async FIFO or another CDC structure when needed.

The native memory request channel is:

- `mem_req_valid`
- `mem_req_ready`
- `mem_req_write`
- `mem_req_burst`
- `mem_req_burst_len`
- `mem_req_beat_index`
- `mem_req_burst_start`
- `mem_req_burst_last`
- `mem_req_addr`
- `mem_req_wdata`
- `mem_req_wstrb`

The native memory response channel is:

- `mem_rsp_valid`
- `mem_rsp_ready`
- `mem_rsp_rdata`

Writes complete when the request is accepted. Reads complete when the response is valid.

The maintenance channel is:

- `maint_flush_req`
- `maint_invalidate_req`
- `maint_flush_line_req`
- `maint_invalidate_line_req`
- `maint_addr_valid`
- `maint_addr`
- `maint_ready`
- `maint_done`
- `maint_error`

The cache has a fixed single-entry maintenance queue. This depth is intentional and is not parameterized. A maintenance request can be accepted while cache traffic is active when `maint_ready` is high. If accepted during active traffic, the operation is held until current cache traffic drains, then `maint_done` or `maint_error` pulses. `busy` remains high while a maintenance operation is queued. External logic must pace back-to-back maintenance requests with `maint_ready`, `maint_done`, and `maint_error`.

Global invalidate clears cache valid state. Global flush is a no-op because the cache is write-through. Address-selective line invalidate clears matching tag/valid entries for `maint_addr` in L1 data, L1 instruction, and L2. Address-selective line flush is also a write-through no-op. Global and line requests must not be asserted together; line requests require `maint_addr_valid`.

Instruction and data L1 caches are not coherent after data-side writes. This is an intentional integration contract, not an accidental cache miss behavior. Software or an external adaptor must invalidate an affected line before fetching modified data as instructions.

The native cache memory interface is beat-based with burst metadata:

- The cache issues at most one outstanding request.
- Each `mem_req_valid && mem_req_ready` handshake transfers exactly one memory beat.
- Read responses must return in request order.
- Line fills are emitted as ordered, contiguous, line-aligned read beats.
- For multi-beat line fills, `mem_req_burst` is asserted on each read beat.
- `mem_req_burst_len` is the total number of memory beats in the line fill.
- `mem_req_beat_index` is the zero-based beat number within that line fill.
- `mem_req_burst_start` is asserted on beat 0.
- `mem_req_burst_last` is asserted on the final line-fill beat.
- Write-through traffic is emitted as ordered contiguous write beats when a data-side write spans more than one native memory beat.
- Multi-beat write-through traffic uses the same burst metadata fields as line-fill reads.
- Single-beat write-through traffic reports `mem_req_burst=0`, `mem_req_burst_len=1`, and `mem_req_beat_index=0`.
- The generic cache does not expose bus-specific burst type, lock, exclusive, or ID fields.

Memory adaptors may use the burst metadata to coalesce cache read or write beats into a target bus burst. That coalescing is an adaptor optimization and must preserve the cache-visible beat order and response contract.

`cache` can be checked without any CPU adapter:

```sh
make compile-cache
```

## Parameter Contract

The public top exposes `ADDR_WIDTH`, `DATA_WIDTH`, `MEM_DATA_WIDTH`, `LINE_WIDTH`, `L1_SET_COUNT`, `L1_DATA_SET_COUNT`, `L1_INSTR_SET_COUNT`, and `L2_SET_COUNT`. L1 and L2 index widths are derived from the set counts. `L1_DATA_SET_COUNT` and `L1_INSTR_SET_COUNT` default to `L1_SET_COUNT`, but can be overridden independently for ASIC SRAM macro mappings. The current verified matrix is documented in `docs/PARAMETERS.md`; it includes the default configuration plus selected single-parameter and combined non-default configurations:

- `ADDR_WIDTH = 19`
- `DATA_WIDTH = 64`
- `MEM_DATA_WIDTH = 32`
- `LINE_WIDTH = 128`
- `L1_SET_COUNT = 64`
- `L1_DATA_SET_COUNT = L1_SET_COUNT`
- `L1_INSTR_SET_COUNT = L1_SET_COUNT`
- `L2_SET_COUNT = 256`

The current L1 and L2 way count is fixed at 2.

See `docs/PARAMETERS.md` for legal values, derived widths, unsupported combinations, and the bus-width genericity roadmap.

## Adaptor Repositories

The CPU adaptor repository owns load/store formatting and CPU-facing port conventions.

The memory adaptor repository owns translation from the beat-based native cache memory side into a SoC bus protocol. It also owns bus-specific burst encoding, burst coalescing, and CDC required by the target memory subsystem.
