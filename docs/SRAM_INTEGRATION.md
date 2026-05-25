# SRAM Macro Integration

This repository does not contain foundry, compiler, or project-specific SRAM cells.

The cache RTL provides stable cache-facing memory wrapper modules. By default, those wrappers build generic synthesizable SystemVerilog memory models. For ASIC integration, a project can enable external SRAM adapter modules with preprocessor defines.

## Integration Model

Enable macro-backed memories with:

```text
+define+SRAM_MACRO_ENABLE
```

When `SRAM_MACRO_ENABLE` is set, all role-specific adapter defines must also be provided:

```text
+define+CACHE_L1_DATA_MEMORY_ARRAY_MACRO=<external_l1_data_line_adapter_module>
+define+CACHE_L1_DATA_TAG_VALID_ARRAY_MACRO=<external_l1_data_tag_valid_adapter_module>
+define+CACHE_L1_INSTR_MEMORY_ARRAY_MACRO=<external_l1_instr_line_adapter_module>
+define+CACHE_L1_INSTR_TAG_VALID_ARRAY_MACRO=<external_l1_instr_tag_valid_adapter_module>
+define+CACHE_L2_MEMORY_ARRAY_MACRO=<external_l2_line_adapter_module>
+define+CACHE_L2_TAG_VALID_ARRAY_MACRO=<external_l2_tag_valid_adapter_module>
```

These defines must name external adapter modules supplied by the integrating project. They should not normally name raw compiler SRAM cells directly, because real SRAM macro pins, depth, width, byte-write controls, and collision behavior are compiler-specific.

The adapter module is responsible for instantiating the real SRAM macro cell or another implementation outside this repository.

## Wrapper Roles

| Cache wrapper | Default model | External adapter define | Expected storage role |
| --- | --- | --- | --- |
| `cache_l1_memory_array` with `INSTR_MEMORY=0` | single-port inferred memory | `CACHE_L1_DATA_MEMORY_ARRAY_MACRO` | L1 data-cache line storage |
| `cache_l1_memory_tag_valid_array` with `INSTR_MEMORY=0` | single-port inferred memory | `CACHE_L1_DATA_TAG_VALID_ARRAY_MACRO` | L1 data-cache tag and valid storage |
| `cache_l1_memory_array` with `INSTR_MEMORY=1` | single-port inferred memory | `CACHE_L1_INSTR_MEMORY_ARRAY_MACRO` | L1 instruction-cache line storage |
| `cache_l1_memory_tag_valid_array` with `INSTR_MEMORY=1` | single-port inferred memory | `CACHE_L1_INSTR_TAG_VALID_ARRAY_MACRO` | L1 instruction-cache tag and valid storage |
| `cache_l2_memory_array` | dual-port inferred memory | `CACHE_L2_MEMORY_ARRAY_MACRO` | L2 cache line data storage |
| `cache_l2_memory_tag_valid_array` | dual-port inferred memory | `CACHE_L2_TAG_VALID_ARRAY_MACRO` | L2 tag and valid storage |

## Adapter Interface Contract

External adapter modules must support the same parameters and ports as the cache wrapper role they replace. The parameters allow the generic cache to elaborate consistently, but the adapter may check that the selected cache configuration matches a fixed SRAM macro size.

For example, an adapter for `CACHE_L1_DATA_MEMORY_ARRAY_MACRO` must provide:

```systemverilog
module project_l1_memory_array_adapter #(
  parameter DATA_WIDTH = 128,
  parameter ADDR_WIDTH = 6,
  parameter BYTE_COUNT = DATA_WIDTH / 8,
  parameter RAM_DEPTH = 1 << ADDR_WIDTH
) (
  input clk,
  input we,
  input [BYTE_COUNT-1:0] byte_enable,
  input [ADDR_WIDTH-1:0] addr,
  input [DATA_WIDTH-1:0] write_data,
  output [DATA_WIDTH-1:0] read_data
);
```

The adapter can instantiate a fixed macro such as a 64-deep by 128-bit SRAM internally, but that macro and any foundry collateral must live outside this repository.

The instruction and data L1 memories can map to different fixed-depth cells. Use `L1_DATA_SET_COUNT` and `L1_INSTR_SET_COUNT` to describe different logical depths at the cache top. If those parameters remain unset, both inherit `L1_SET_COUNT` for backward-compatible default geometry.

## Required Behavior

The current cache wrappers assume:

- one-cycle synchronous read latency;
- read-first behavior for read and write to the same address on a single port;
- byte-write enables for cache line data arrays;
- no asynchronous read path;
- no SRAM array reset requirement for line data memories;
- tag/valid memories must return invalid entries after reset before normal cache traffic is accepted;
- address-selective invalidate clears a matching valid bit;
- L2 same-address cross-port read/write and write/write collision behavior is integration-defined and must not be relied on by software.

ASIC SRAMs usually do not reset stored rows. Therefore, a tag/valid macro adapter must provide reset-clean valid behavior. It can do this by keeping valid bits in resettable flops, by using a reset scrub sequence, or by another project-specific mechanism that prevents stale valid entries after reset.

## Unsupported In This Repository

This repository intentionally does not provide:

- foundry SRAM cells;
- compiler-generated memory wrappers;
- Liberty, LEF, GDS, or timing collateral;
- macro selection logic for 16 KiB, 32 KiB, or other fixed physical instances;
- CDC between cache clock and an external memory/macro clock;
- signoff constraints for a specific memory compiler.

Those belong in the integrating SoC or memory-adaptor repository.
