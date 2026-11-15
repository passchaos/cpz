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
- `CodegenOptions.emit_introspection` and `cpzc --no-introspection` to omit
  per-pointer-field and list-wrapper introspection helpers while keeping
  readers, builders, list wrappers, and element accessors. Combining both modes
  drops `tests/schema_smoke.capnp` generated output from 92,327 lines / 4.7 MB
  to 24,734 lines / 1.2 MB.
- `--no-metadata` now also omits per-const, per-alias, and per-enum metadata
  for values that are emitted directly, while retaining metadata required by
  aggregate const values.
- `--no-introspection` also omits scalar/blob/enum default-value flat
  containers, struct-level actual-size/section diagnostics, and text/data
  byte-count/match helpers; pointer/list default containers remain because
  builders use them.
- `cpzc --minimal` enables both lean modes for production accessors and roughly
  halves generated-code compile time on the smoke schema.
- `CodegenOptions.emit_orphan_helpers` and `cpzc --no-orphans` omit generated
  Orphan wrapper types and typed orphan/copy helpers. Combining
  `--minimal --no-orphans` drops the smoke schema to 20,216 lines / 1.0 MB and
  the two-field schema to 298 lines / 10.5 KB.
- `ListBuilder.setAll(T, values)` copies primitive slices (including floats and
  bools) into a whole list in one pass instead of calling `set*` per element.
- `ListReader.getAll(T, out)` copies a whole primitive list into a caller slice
  in one pass; the fixed-buffer microbenchmark is roughly 20-30x faster than a
  per-element loop and close to `memcpy` speed.
- Configurable upstream fixture paths via `CPZ_CAPNP_SRC`,
  `CPZ_CAPNP_TESTDATA`, and `CPZ_RPC_SCHEMA`.
- `cpzc --output-dir <dir>` writes `<schema-stem>.zig`, making it easier to
  generate a directory of schemas without spelling each output path.
- A generated-code addressbook example (`zig build run-generated`) and a more
  rigorous benchmark covering dynamic reads, flat serialization, and packed
  serialization.

### Changed

- The segment builder now zeroes capacity lazily as words are allocated instead
  of zeroing the whole first segment up front, and the benchmark measures
  message building with `ListBuilder.setAll` (ReleaseFast build time roughly
  8.2 us -> 0.9 us).
- Allocating `unpack` now allocates the exact decoded size and reuses
  `unpackInto` instead of appending to an `ArrayList` per word; the fixed-buffer
  microbenchmark is about 17% faster.
- Allocating `messageToPackedBytes` now allocates `maxPackedMessageSize` and
  shrinks to the written length, avoiding the packed-size pre-pass; it is about
  40% faster in the fixed-buffer microbenchmark.
- The benchmark now also measures allocating packed serialization and unpacking
  into a caller-provided buffer.
- `messageToPackedBytesInto` no longer performs a redundant packed-size
  pre-pass; packed serialization is roughly 40% faster in the benchmark
  (ReleaseFast 5.2 us -> 3.1 us per 4 KB message). A too-small destination may
  now contain a partial prefix.
- `build.zig` generated-schema test wiring is now declarative and shared through
  helpers instead of repeated blocks.
- The 33k-line RPC smoke suite was split into focused files under
  `tests/codegen/rpc_event/` with shared helpers in `tests/support/rpc_event.zig`.
- RPC vocabulary/wire types and the `State` machine were extracted into
  `src/rpc/types.zig` and `src/rpc/state.zig`, reducing `src/rpc.zig` size.
- The schema lexer/parser/AST/layout front-end was extracted into
  `src/schema/frontend.zig`, reducing `src/schema.zig` size.
- The schema frontend now lives in cohesive modules under
  `src/schema/frontend/` (types, parser, layout, validation, resolution, embed),
  with `src/schema/frontend.zig` as a compatibility facade.
- The schema code generator now lives in cohesive modules under
  `src/schema/codegen/` (entry, validation, text, flat buffers, consts, field
  defaults, metadata, interfaces, structs, pointers, lists, state), with
  `src/schema/codegen.zig` as a compatibility facade.
- Shared schema helpers moved into the frontend and `src/schema/zig_names.zig`,
  removing the frontend-to-facade import cycle and pruning dead facade aliases.
- RPC dispatch and wire helpers now live in cohesive modules under `src/rpc/`
  (wire, call, dispatch_wire, turn, output, event), with `src/rpc.zig` keeping
  the public facade and integration tests.
- The dynamic message runtime now lives in cohesive modules under
  `src/message/` (options, capability, reader, builder, pointer, struct, list,
  validate), with `src/message.zig` keeping the public facade and tests.
- The schema integration test suite moved from `src/schema.zig` into focused
  files under `src/schema/tests/` (parser, layout, resolve, codegen,
  integration), leaving `src/schema.zig` as a pure facade.
- The RPC integration tests moved from `src/rpc.zig` into
  `src/rpc/tests/integration_tests.zig`, leaving `src/rpc.zig` as a pure facade.
- The message runtime tests moved from `src/message.zig` into
  `src/message/tests/integration_tests.zig`, leaving `src/message.zig` as a
  pure facade.
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
