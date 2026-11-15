# Architecture

`cpz` is split into a wire/runtime layer, a schema compiler layer, and a
transport-independent RPC layer. The public entry point is `src/cpz.zig`.

## Module map

```text
src/
  cpz.zig        public facade and curated re-exports
  wire.zig       pointer encoding/decoding and low-level size helpers
  packing.zig    Cap'n Proto packing codec and streaming helpers
  serialize.zig  stream segment tables, flat/packed framing, Io.Reader/Writer
  message.zig    dynamic readers/builders, orphans, capability views, validation
  schema.zig             public schema facade plus parser/layout/codegen tests
  schema/frontend.zig    facade over the schema frontend stages
  schema/frontend/
    types.zig            AST/data model and metadata types
    parser.zig           lexer, tokenizer, parser
    layout.zig           ordinal-aware slot planning and union layout
    validate.zig         semantic checks and default validation
    resolve.zig          name resolution, aliases, literal and const helpers
    embed.zig            embedded const file loading
  schema/codegen.zig     facade over the code generator modules
  schema/codegen/
    entry.zig            CodegenOptions and top-level generation flow
    validate.zig         generated Zig name-collision validation
    text.zig             Zig identifier/literal/type-name rendering
    flat.zig             flat-buffer literal construction and const encoding
    const_emit.zig       alias/const declarations and flat container emission
    field_defaults.zig   field default flat containers
    metadata.zig         introspection tables and metadata constants
    interface.zig        enum/interface/method/annotation emission
    struct.zig           struct/union declarations and scalar accessors
    pointer.zig          pointer getters and builder methods
    list.zig             list wrappers, element helpers, slice setters
    state.zig            shared codegen state and pointer-default kinds
  schema/zig_names.zig   Zig identifier escaping and keyword avoidance
  rpc.zig                RPC facade, re-exports, and integration tests
  rpc/types.zig          RPC vocabulary, call/capability/payload types, output plans
  rpc/state.zig          RPC question/answer/capability state machine
  rpc/wire.zig           wire message init/encode/decode helpers
  rpc/call.zig           bootstrap/call dispatch and dispatch planning
  rpc/dispatch_wire.zig  wire-message dispatch and forwarding variants
  rpc/turn.zig           RPC turn dispatch and output planning
  rpc/output.zig         service-action output sinks and queues
  rpc/event.zig          wire event decoding helpers
tools/
  cpzc.zig       schema-to-Zig command-line compiler
bench/
  bench.zig      dynamic reader and serialization microbenchmark
examples/
  addressbook.zig           hand-written dynamic API example
  generated_addressbook.*   end-to-end codegen example
```

Dependency direction:

```text
wire <- packing/serialize <- message <- schema/frontend <- schema/codegen <- tools/cpzc
cpz.zig (facade)
rpc.zig (uses anytype-based adapters instead of importing generated code)
```

The runtime modules do not depend on generated code. `rpc.zig` intentionally
uses structural typing (`anytype`) so generated readers and test doubles can be
passed without a compile-time dependency on a particular schema.

## Ownership and lifetimes

- `MessageReader`, `StructReader`, `ListReader`, and `PointerReader` are
  non-owning views over caller-provided segment slices.
- `MessageReaderView` owns only its segment-table storage; segment bytes remain
  caller-owned.
- `OwnedMessageReader` owns the decoded flat message and exposes a reader view.
- `MessageBuilder` owns append-only segment arenas. `segmentsConst()` returns a
  cached view into the builder and is invalidated by later builder mutation.
- `CapabilityTable(T)` is a non-owning view over application handles.
- `CapabilityRegistry(T)` is an append-only application-owned handle registry.
- `Orphan` is tied to its `MessageBuilder`; releasing or reusing the builder
  invalidates it.
- `toSingleSegmentFlatBytes` and `toCanonicalSegmentBytes` allocate new output
  buffers owned by the caller.

## Validation and limits

`ReaderOptions` controls the safety envelope for untrusted input:

- `traversal_limit_words` (default 64 MiB of words, matching the C++ default);
- `nesting_limit` (default 64);
- `capability_count_limit` (optional).

Readers are lazy: initial construction does not traverse the message.
`MessageReader.validate()` performs schema-agnostic pointer traversal and
returns `MessageStats`. Accessors charge traversal and nesting budgets as they
walk pointers.

## Schema compiler pipeline

```text
source bytes
  -> lexer
  -> parser / AST
  -> semantic validation
  -> layout planner (ordinal-aware data/pointer slots, unions, groups)
  -> Zig code generator
  -> generated reader/builder/accessor code
```

The code generator has two tiers:

1. **Core accessors**: typed readers/builders, list wrappers, orphans, copy
   helpers, and serialization helpers.
2. **Metadata**: declaration/field/const/alias/annotation introspection tables
   and `@"cpz.*"` lookup helpers.

`CodegenOptions.emit_metadata = false` (CLI `--no-metadata` / `--lean`) removes
the metadata tier and root-level convenience helpers. This is intended for
users who only need wire accessors and want smaller generated files.

## RPC boundary

`rpc.zig` currently models:

- message kinds and wire-event decoding;
- question/answer and import/export lifetime tracking;
- capability descriptors and payload cap tables;
- transport-independent bootstrap/call/return dispatch helpers;
- output planning, sinks, queues, and turn plans.

It does not implement network transports, a message loop, promise pipelining,
vats, or generated service stubs. See [rpc.md](rpc.md).

## Testing strategy

- Unit tests live next to the logic in `src/*.zig`.
- Integration/codegen tests live in `tests/` and compile generated code through
  `build.zig`.
- `tests/upstream_*` validate against an optional local Cap'n Proto C++
  checkout. Set `CPZ_CAPNP_SRC` (or the more specific
  `CPZ_CAPNP_TESTDATA` / `CPZ_RPC_SCHEMA`) to run them; otherwise they skip.
- `tests/fuzz_smoke.zig` contains `std.testing.fuzz` harnesses plus a
  deterministic randomized corpus test. `zig build fuzz` runs the deterministic
  corpus. Continuous `zig build test --fuzz` depends on the pinned Zig
  toolchain's fuzz runner being usable.
- CI runs formatting, Debug and ReleaseSafe tests, cross-compilation, and a
  codegen check over every test schema.

## Structural debt

`src/schema.zig` and `src/rpc.zig` are now public facades plus their integration
test suites. The schema frontend, schema code generator, and RPC layers are
split into cohesive modules under `src/schema/frontend/`, `src/schema/codegen/`,
and `src/rpc/`.

The largest remaining implementation file is `src/message.zig`. If it keeps
growing, the intended direction is to split readers/builders, capability views,
validation, and canonicalization into `src/message/` modules. The schema
integration tests in `src/schema.zig` can move into focused files under `tests/`
if the facade starts to grow again.

The runtime should remain low-level and allocation-explicit; convenience layers
belong above it.
