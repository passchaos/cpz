# Compatibility

`cpz` targets wire compatibility with the Cap'n Proto C++ implementation while
using Zig-native APIs.

## Wire format

The following are compatible with the reference implementation:

- pointer bit layout for struct, list, far, and capability pointers;
- standard stream segment table framing (`segment count - 1`, word sizes,
  padding, segment bytes);
- flat and packed stream messages;
- packing codec with `0x00` zero runs and `0xff` raw runs;
- text NUL terminators and UTF-8 text accessors;
- bool bit packing;
- composite list tags and struct-list layout;
- signed pointer offsets and far-pointer landing pads.

`toSingleSegmentFlatBytes()` removes far pointers and produces deterministic
single-segment output. `toCanonicalSegmentBytes()` additionally truncates
trailing zero struct/struct-list sections. This is a practical schema-less
canonicalization pass, not a claim of complete Cap'n Proto canonicalization for
every schema-level rule.

## Schema language

Implemented:

| Feature | Status |
|---|---|
| File IDs, file annotations | Yes |
| Structs, fields, ordinals | Yes |
| Enums and enumerants | Yes |
| Interfaces, methods, parameters/results | Metadata and generated constants |
| Constants and defaults | Yes, including aggregate/list defaults |
| Annotations | Yes, including targets and raw metadata |
| Imports, `using` aliases, re-exports | Parsed and emitted |
| Named/anonymous unions, groups | Yes |
| Generics and type applications | Yes |
| `AnyPointer`, `AnyStruct`, `AnyList`, capability fields | Yes |
| Optional pointer syntax | Yes |
| Compact ordinal-aware layout | Yes |
| Embed constants | Yes |
| Full Cap'n Proto compiler semantics | Not complete |

Known gaps and caveats:

- `cpzc` compiles one input file at a time; import modules must be wired by the
  caller in `build.zig`.
- Exotic or ambiguous schema constructs may be rejected rather than lowered.
- The generated metadata tier is large for complex schemas; use
  `--no-metadata` when introspection is not needed.
- RPC is transport-independent and does not yet implement a network message
  loop, promise pipelining, vats, or generated service stubs.

## RPC

See [rpc.md](rpc.md). The implemented subset covers message vocabulary, state
tracking, capability tables/descriptors, bootstrap/call/return helpers, handoff
bookkeeping, and output planning. It is suitable for embedding experiments and
schema/codegen work, not for production RPC yet.

## Upstream C++ fixtures

The optional compatibility tests under `tests/upstream_*` validate against a
local Cap'n Proto C++ checkout. They skip when the checkout is absent.

Resolution order:

1. `CPZ_CAPNP_TESTDATA` for the `testdata` directory;
2. `CPZ_RPC_SCHEMA` for `rpc.capnp`;
3. `CPZ_CAPNP_SRC` for a Cap'n Proto checkout root;
4. `/home/passchaos/Work/capnproto` as a historical local default.

Example:

```sh
git clone --depth 1 https://github.com/capnproto/capnproto.git /tmp/capnproto
CPZ_CAPNP_SRC=/tmp/capnproto zig build test
```

The GitHub Actions workflow exposes the same check as a manual
`workflow_dispatch` job.

## Verification baseline

- `zig build check` passes.
- `zig build test` passes in Debug.
- `zig build test -Doptimize=ReleaseSafe` passes.
- Cross-compilation is checked for `x86_64-linux` and `aarch64-linux`.
- Every test schema is validated with `cpzc --check`.
