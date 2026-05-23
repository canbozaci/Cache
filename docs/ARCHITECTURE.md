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
- Memory side: native 32-bit read/write interface for line fills and write-through traffic.

The cache does not consume ISA-specific load/store encoding values and does not perform sign extension.

`cache` can be checked without any CPU adapter:

```sh
make compile-cache
```

## Parameter Contract

The public top exposes `ADDR_WIDTH`, `DATA_WIDTH`, `MEM_DATA_WIDTH`, and `LINE_WIDTH`. Today these parameters document the intended generic boundary, but only the default configuration is supported by the full RTL and verification:

- `ADDR_WIDTH = 19`
- `DATA_WIDTH = 64`
- `MEM_DATA_WIDTH = 32`
- `LINE_WIDTH = 128`

See `docs/PARAMETERS.md` for legal values, derived widths, unsupported combinations, and the bus-width genericity roadmap.

## Adaptor Repositories

The CPU adaptor repository owns load/store formatting and CPU-facing port conventions.

The memory adaptor repository is reserved for translating the generic cache native memory side into a SoC bus protocol once the native cache memory contract is frozen.
