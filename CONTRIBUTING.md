# Contributing

## Setup

- Zig `0.16.0`.
- No external package dependencies.

```sh
zig build check
zig build test
zig build test -Doptimize=ReleaseSafe
zig build fuzz
zig build bench
```

## Code layout

See [docs/architecture.md](docs/architecture.md) for the module map and
ownership model. Keep the runtime core (`wire`, `packing`, `serialize`,
`message`) independent of generated code.

The largest current modules are `src/schema.zig` and `src/rpc.zig`. New work
should prefer extracting cohesive modules under `src/schema/` and `src/rpc/`
rather than growing those files further.

## Tests

- Put unit tests next to the logic they exercise.
- Put integration/codegen tests under `tests/`.
- Add a `.capnp` fixture and a focused smoke test when adding a schema feature,
  then register the pair in `generated_tests` in `build.zig`.
- Keep generated-code tests compiling through the build system; do not check in
  generated output.
- For parser/decoder changes, run `zig build fuzz`.

## Upstream compatibility

The `tests/upstream_*` tests are optional. Point them at a local Cap'n Proto
checkout:

```sh
CPZ_CAPNP_SRC=/path/to/capnproto zig build test
```

They skip when the checkout is absent. Do not reintroduce hardcoded paths.

## Style

- Run `zig fmt`.
- Prefer explicit allocators and caller-owned buffers in hot paths.
- Document public APIs, especially ownership and error semantics.
- Keep functions and files focused; extract cohesive modules when a file grows
  beyond a reviewable size.

## Commits and pull requests

- Keep changes scoped to one logical theme.
- Run `zig build check` before publishing.
- Include tests for behavior changes.
- Update the relevant document under `docs/` when scope or compatibility
  changes.
