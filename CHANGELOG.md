# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
intends to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) when the first release
is ready.

## [Unreleased]

### Added

- Reusable generic cache soft-IP structure with `rtl/`, `tb/`, `filelists/`, `scripts/`, and
  `docs/`.
- Architecture-neutral `cache` top for embedded and single-core integration.
- Native beat-based memory request/response interface with generic burst metadata.
- Runtime global and address-selective maintenance operations.
- Directed scoreboard, random scoreboard, block tests, lint/style checks, and parameter compile
  sweep.
- Apache-2.0 licensing collateral.
- Release-management collateral for pre-release development.

### Changed

- Converted the original Vivado-export style tree into a reusable SystemVerilog soft-IP layout.
- Removed FPGA/block-RAM-specific RTL markers from cache memory models.
- Moved CPU-side and memory-side adaptor responsibilities outside this repository.

### Fixed

- Generalized line-fill and write-through sequencing across the currently supported width matrix.
- Documented the non-coherent instruction/data L1 behavior as an explicit integration contract.

### Security

- No security changes.
