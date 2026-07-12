# cpz

`cpz` is a Zig implementation of the Cap'n Proto wire format. The first milestone focuses on the runtime layer that must be fast, safe, and compatible with the C++ implementation:

- zero-copy readers and flat-message views over caller-owned byte slices;
- segmented stream framing compatible with `capnp::serialize`;
- word/pointer/capability encoding, lazy pointer validation, and schema-agnostic full-message validation stats;
- arena-backed builders for structs, scalar fields/lists, pointer lists, text/data blobs, composite struct lists, schema-evolution list upgrades, and deep-copying from readers;
- packed stream codec compatible with Cap'n Proto packing.
- one-call packed stream framing helpers (`messageToPackedBytes` / `readPackedMessage`).
- single-segment normalization helper for deterministic flat output (`toSingleSegmentFlatBytes`).
- initial `.capnp` schema parser, layout planner, and Zig reader/builder accessor skeleton generator with scalar default values for structs, enums, scalar fields, lists, named types, and file IDs.

The long-term target is to grow into a full schema/compiler/RPC stack while keeping Zig-friendly APIs and predictable performance.

## Build

```sh
zig build test
zig build run
zig build cpzc -- schema.capnp generated.zig
```

This repository targets Zig 0.16.0.

## Example

```zig
const cpz = @import("cpz");

var builder = try cpz.MessageBuilder.init(std.heap.page_allocator, .{});
defer builder.deinit();
const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
try root.setUInt32(0, 1234, 0);
try root.setText(0, "hello");

const bytes = try cpz.serialize.messageToFlatBytes(std.heap.page_allocator, builder.segmentsConst());
defer std.heap.page_allocator.free(bytes);
```

## Scope

The public API is intentionally low-level today. Generated schema accessors can build on top of `StructReader` / `StructBuilder` without changing the wire-format core.
