# Changelog

All notable changes to `cpz` are documented here.

## Unreleased

### Added

- GitHub Actions CI for formatting, Debug/ReleaseSafe tests, cross-compilation,
  schema codegen checks, and an optional upstream Cap'n Proto compatibility job.
- `tests/fuzz_smoke.zig` with `std.testing.fuzz` harnesses and a deterministic
  randomized corpus test; `zig build fuzz` runs the corpus.
- `CodegenOptions.emit_metadata` and `cpzc --no-metadata` / `--lean` for lean
  generated APIs. A two-field schema drops from 3,392 to 926 generated lines in
  the current test suite.
- Configurable upstream fixture paths via `CPZ_CAPNP_SRC`,
  `CPZ_CAPNP_TESTDATA`, and `CPZ_RPC_SCHEMA`.
- `cpzc --output-dir <dir>` writes `<schema-stem>.zig`, making it easier to
  generate a directory of schemas without spelling each output path.

### Changed

- `build.zig` generated-schema test wiring is now declarative and shared through
  helpers instead of repeated blocks.
- Documentation was restructured into architecture, codegen, compatibility,
  performance, RPC, design, contributing, and security documents.
- README was rewritten as a concise entry point with quick starts and status
  tables.

### Fixed

- Upstream compatibility tests no longer depend on a hardcoded local checkout
  path; they skip only when the configured fixtures are genuinely absent.

## 0.0.1

- Initial wire/runtime, schema/codegen, and transport-independent RPC
  foundation.
