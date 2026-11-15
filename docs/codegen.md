# Code generation

`cpzc` parses a supported subset of Cap'n Proto schemas and emits typed Zig
reader/builder accessors.

## CLI

```sh
zig build cpzc -- [options] <schema.capnp> [output.zig]
```

If `output.zig` is omitted, generated code is written to stdout. If `--check` is
set, parse/layout/codegen are validated and no file is written.

| Option | Meaning |
|---|---|
| `--runtime-import <name>` | Import name used by generated code (default `cpz`). |
| `--namespace <name>` | Wrap generated declarations in `pub const <name> = struct { ... };`. |
| `--check` | Validate parsing, layout, and code generation without writing output. |
| `--no-metadata`, `--lean` | Omit schema introspection tables and `@"cpz.*"` lookup helpers. |
| `--emit-metadata` | Re-enable metadata after a previous lean flag. |
| `--no-introspection` | Omit per-pointer-field and struct-level introspection helpers (kind, location, struct/list shape, stats, actual sizes, sections, match predicates). |
| `--emit-introspection` | Re-enable introspection helpers after `--no-introspection`. |
| `--minimal` | Enable both lean modes (`--no-metadata --no-introspection`) for production accessors only. |
| `--no-orphans` | Omit generated Orphan wrapper types and typed orphan/copy helpers. |
| `--emit-orphans` | Re-enable orphan helpers after `--no-orphans`. |
| `--emit-raw-schema-comments` | Include the source schema as comments in generated output. |
| `--output-dir <dir>` | Write `<schema-stem>.zig` into `dir` instead of an explicit output path. |
| `--help`, `-h` | Show usage. |

Examples:

```sh
zig build cpzc -- schema.capnp generated.zig
zig build cpzc -- --namespace api schema.capnp generated.zig
zig build cpzc -- --no-metadata schema.capnp generated.zig
zig build cpzc -- --no-metadata --no-introspection schema.capnp generated.zig
zig build cpzc -- --minimal schema.capnp generated.zig
zig build cpzc -- --minimal --no-orphans schema.capnp generated.zig
zig build cpzc -- --output-dir generated schemas/person.capnp
zig build cpzc -- --check schema.capnp
```

For a directory of schemas:

```sh
mkdir -p generated
for schema in schemas/*.capnp; do
  zig build cpzc -- --output-dir generated "$schema"
done
```

A complete generated-code example lives in `examples/generated_addressbook.zig`
and runs with:

```sh
zig build run-generated
```

## Generated API shape

For a schema such as:

```capnp
struct Person {
  id @0 :UInt32;
  name @1 :Text;
}
```

the generated module contains:

- `Person.size` and struct layout constants;
- `Person` reader with field accessors;
- `Person.Builder` with typed setters and pointer/list helpers;
- `Person.Orphan` and copy/orphan helpers;
- list wrapper types for list fields;
- serialization helpers;
- optionally, metadata tables and `@"cpz.*"` lookup helpers.

Typical use:

```zig
_ = try builder.initRoot(generated.Person.size);
const person = try generated.Person.getRootTyped(&builder);
try person.set_id(1234);
try person.set_name("Alice");

var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
const view = try generated.Person.getRoot(&reader);
try std.testing.expectEqual(@as(u32, 1234), view.id());
```

## Lean mode

Metadata and root convenience helpers dominate generated output for small
schemas. `--no-metadata` removes that tier:

| Schema | Default output | `--no-metadata` |
|---|---:|---:|
| Two-field `struct Tiny` | 3,392 lines / 166 KB | 926 lines / 39.7 KB |
| `tests/schema_smoke.capnp` | 92,327 lines / 4.7 MB | 63,033 lines / 3.1 MB |

Lean mode keeps typed field accessors, builders, list wrappers, orphan helpers,
and serialization helpers. It is the recommended mode when only wire access is
needed.

## Supported schema subset

The parser supports:

- file IDs and file-level annotations;
- structs, enums, interfaces, constants, annotations, aliases, and imports;
- scalar, text, data, enum, struct, list, optional, `AnyPointer`, `AnyStruct`,
  `AnyList`, and capability fields;
- unions (including anonymous unions), groups, and overlapping union storage;
- generic declarations and type applications;
- ordinal-aware compact layout with padding-hole reuse;
- scalar/string/enum/struct/list defaults, including nested and aggregate
  defaults;
- annotations on declarations, fields, methods, parameters, and results;
- imports and `using` aliases, including re-exports;
- Zig identifier sanitization and collision checks.

Unsupported or incomplete areas are rejected with an error rather than silently
approximated. See [compatibility.md](compatibility.md) for the current gaps.

## Multi-file schemas

The parser records import declarations, but `cpzc` currently compiles one input
file at a time. Generated code refers to imported modules with
`@import("<import-name>")`, so the caller must wire each imported module in
`build.zig`:

```zig
const base = b.createModule(.{
    .root_source_file = generated_base,
    .imports = &.{.{ .name = "cpz", .module = cpz_mod }},
});
const use = b.createModule(.{
    .root_source_file = generated_use,
    .imports = &.{
        .{ .name = "cpz", .module = cpz_mod },
        .{ .name = "Base", .module = base },
    },
});
```

The repository's `build.zig` demonstrates this pattern for
`tests/schema_import_use.capnp`.

## Testing generated code

The build system compiles generated modules and runs their smoke tests through
`zig build test`. The test schemas under `tests/` cover structs, enums,
interfaces, constants, defaults, imports, namespaces, keyword escaping, and RPC
event shapes.

When adding a schema feature:

1. Add a `.capnp` fixture under `tests/`.
2. Add a focused smoke test that compiles and exercises the generated code.
3. Add the schema/test pair to the `generated_tests` list in `build.zig`.
4. Run `zig build check`.
