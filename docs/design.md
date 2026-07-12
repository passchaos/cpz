# cpz design notes

The implementation follows Cap'n Proto's published encoding and the C++ runtime shape in `~/Work/capnproto/c++/src/capnp`, but uses Zig-native APIs.

## Milestone 1 runtime

- `wire.zig` encodes/decodes the four pointer families: struct, list, far, and capability.
- `serialize.zig` implements the standard stream segment table (`segment count - 1`, segment word sizes, padding, segment bytes) and packed stream framing helpers layered on `packing.zig`.
- `packing.zig` implements Cap'n Proto packing/unpacking with the `0x00` zero-run and `0xff` raw-run special cases.
- `message.zig` provides arena-backed builders and lazy-validating readers for structs, scalar fields/lists, pointer lists, composite lists, text/data, far pointers, and recursive copy-from-reader operations.
- `schema.zig` and `cpzc` are the start of the compiler layer: they parse a practical subset of `.capnp` declarations into a small AST, plan field data/pointer slots, and emit Zig accessor skeletons for supported fields, including scalar default values.

## Performance direction

- Readers are zero-copy over caller-provided byte slices; `readFlatMessageView()` also parses the standard stream framing without copying segment bytes.
- Validation is lazy and charged against traversal/nesting limits to preserve O(1) initial parse; callers that need eager checks can use `MessageReader.validate()` for schema-agnostic pointer traversal and layout stats.
- Builders allocate append-only word arenas and write wire-format words directly.
- APIs keep schemas out of the hot path; generated accessors can become thin wrappers around offset-based primitives.

## Compatibility

The stream framing, pointer bit layout, text NUL terminator, bool bit packing, composite-list tag, and packing codec are wire-compatible with the reference C++ implementation.
