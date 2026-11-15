# cpz

`cpz` is a Zig implementation of the Cap'n Proto wire format, schema compiler,
and transport-independent RPC foundation.

The runtime is designed around zero-copy readers, caller-owned buffers, and
append-only builders. The schema layer parses a practical `.capnp` subset and
generates typed Zig reader/builder accessors.

## Status

| Area | Status |
|---|---|
| Wire pointers, structs, lists, far pointers, capabilities | Implemented |
| Flat and packed stream framing | Implemented |
| Dynamic readers/builders, orphans, canonical copy | Implemented |
| `.capnp` parser and layout planner | Broad subset implemented |
| Zig code generation | Broad subset implemented; `--no-metadata` and `--no-introspection` lean modes available |
| RPC message vocabulary and state machine | Foundation implemented |
| RPC transport, promise pipelining, vats, generated service stubs | Not implemented |
| Fuzzing | Deterministic corpus fuzzing in `zig build fuzz`; `std.testing.fuzz` harnesses included |
| CI | GitHub Actions: formatting, Debug/ReleaseSafe tests, cross-compile, schema codegen checks |

See [docs/compatibility.md](docs/compatibility.md) for the exact supported
subset and known gaps.

## Install

Add the package with `zig fetch`:

```sh
zig fetch --save git+https://github.com/passchaos/cpz.git
```

Then import it from your build:

```zig
const cpz = @import("cpz");
```

`cpz` targets Zig `0.16.0`.

## Quick start: runtime

```zig
const std = @import("std");
const cpz = @import("cpz");

pub fn main() !void {
    var builder = try cpz.MessageBuilder.init(std.heap.page_allocator, .{});
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 1234, 0);
    try root.setText(0, "hello");

    const bytes = try cpz.messageToFlatBytes(
        std.heap.page_allocator,
        try builder.segmentsConst(),
    );
    defer std.heap.page_allocator.free(bytes);
}
```

Readers are views over caller-owned bytes. See
[docs/architecture.md](docs/architecture.md) for the ownership and lifetime
rules.

## Quick start: schema code generation

```sh
zig build cpzc -- schema.capnp generated.zig
zig build cpzc -- --no-metadata schema.capnp generated.zig
zig build cpzc -- --no-metadata --no-introspection schema.capnp generated.zig
```

```zig
const generated = @import("generated.zig");

_ = try builder.initRoot(generated.Person.size);
const person = try generated.Person.getRootTyped(&builder);
try person.set_id(1234);
try person.set_name("Alice");
```

`--no-metadata` omits schema introspection tables and `@"cpz.*"` lookup
helpers. `--no-introspection` additionally omits per-pointer-field
introspection helpers (pointer kind/location, struct/list shape, stats, and
match predicates), list-wrapper diagnostics, and scalar/blob/enum default-value
flat containers while keeping the readers, builders, list wrappers, and element
accessors needed to read and write messages. For
`tests/schema_smoke.capnp`, enabling both drops generated output from 92,327
lines / 4.7 MB to 24,734 lines / 1.2 MB.

See [docs/codegen.md](docs/codegen.md) for all CLI options, the supported
schema subset, and multi-file import wiring.

## Build and test

```sh
zig build check          # formatting, tests, examples, bench compile
zig build test           # unit and integration tests
zig build test -Doptimize=ReleaseSafe
zig build fuzz           # deterministic fuzz smoke
zig build bench          # dynamic reader / serialization microbenchmark
zig build run-generated  # generated-code addressbook example
zig build cpzc -- --help
```

CI runs the same commands for Debug and ReleaseSafe, plus cross-compilation and
schema codegen checks.

## Documentation

- [Architecture and ownership](docs/architecture.md)
- [Code generation](docs/codegen.md)
- [Compatibility and supported schema subset](docs/compatibility.md)
- [Performance methodology](docs/performance.md)
- [RPC foundation status](docs/rpc.md)
- [Design principles](docs/design.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Scope and limitations

`cpz` is not yet a complete Cap'n Proto RPC runtime. It provides the wire
format, schema/codegen foundation, capability table/registry views, and
transport-independent RPC state/dispatch helpers. Network transports, promise
pipelining, vats, full embargo queues, and generated service stubs remain future
work.

The schema compiler intentionally supports a practical subset rather than the
entire Cap'n Proto language. Unsupported syntax is rejected with an error rather
than silently approximated.

## License

MIT. See [LICENSE](LICENSE).
