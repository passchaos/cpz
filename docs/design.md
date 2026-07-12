# cpz design notes

The implementation follows Cap'n Proto's published encoding and the C++ runtime shape in `~/Work/capnproto/c++/src/capnp`, but uses Zig-native APIs.

## Milestone 1 runtime

- `wire.zig` encodes/decodes the four pointer families: struct, list, far, and capability; `message.zig` exposes low-level capability pointer accessors.
- `serialize.zig` implements the standard stream segment table (`segment count - 1`, segment word sizes, padding, segment bytes) with bounded segment-count parsing and packed stream framing helpers layered on `packing.zig`, with direct `std.Io.Reader`/`std.Io.Writer` streaming for flat and packed messages (including single-message packed reader semantics) and matching `MessageBuilder` convenience methods.
- `message.toSingleSegmentFlatBytes()` validates and recursively copies a message into one segment, removing far pointers while preserving data; `toCanonicalSegmentBytes()` additionally omits the stream table and truncates trailing zero struct sections.
- `packing.zig` implements Cap'n Proto packing/unpacking with the `0x00` zero-run and `0xff` raw-run special cases, including caller-buffer `packInto`/`unpackInto` paths.
- `message.zig` provides arena-backed builders and lazy-validating readers for structs, scalar fields/lists, pointer lists, composite lists, compatible pointer/eight-byte list-to-struct-list upgrades, UTF-8 text/data, far pointers, and recursive copy-from-reader operations.
- `schema.zig` and `cpzc` are the start of the compiler layer: they parse a practical subset of `.capnp` declarations (including common using/const top-level declarations, annotations, dotted names, Zig identifier sanitization, and nested declarations) into a small AST, plan ordinal-aware compact field data/pointer slots with padding-hole reuse, and emit configurable-import typed Zig reader/builder/nested-struct/list-reader/list-builder accessor skeletons for supported fields, including enums, typed lists, and scalar default values.

## Performance direction

- Readers are zero-copy over caller-provided byte slices; `readFlatMessageView()` also parses the standard stream framing without copying segment bytes.
- Validation is lazy and charged against traversal/nesting limits to preserve O(1) initial parse; callers that need eager checks can use `MessageReader.validate()` for schema-agnostic pointer traversal and layout stats.
- Builders allocate append-only word arenas and write wire-format words directly.
- APIs keep schemas out of the hot path; generated accessors can become thin wrappers around offset-based primitives.

## Compatibility

The stream framing, pointer bit layout, text NUL terminator, bool bit packing, composite-list tag, and packing codec are wire-compatible with the reference C++ implementation.
