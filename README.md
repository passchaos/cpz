# cpz

`cpz` is a Zig implementation of the Cap'n Proto wire format. The first milestone focuses on the runtime layer that must be fast, safe, and compatible with the C++ implementation:

- zero-copy readers and flat-message views over caller-owned byte slices;
- segmented stream framing compatible with `capnp::serialize`, with bounded segment-count validation;
- word/pointer/capability encoding, lazy pointer validation, and schema-agnostic full-message validation stats with capability index limits;
- arena-backed builders for structs with in-progress scalar reads, scalar fields and plus-prefixed/scientific numeric defaults/lists, pointer lists, UTF-8 text/data blobs with reader defaults, composite struct lists, schema-evolution list upgrades, and deep-copying from readers, and explicit pointer clearing;
- packed stream codec compatible with Cap'n Proto packing, including allocation-free pack/unpack helpers.
- one-call flat/packed stream framing helpers (`messageToFlatBytes`, `writeMessageToWriter`, `messageToPackedBytes`, `writePackedMessageToWriter`, `readMessageFromReader`, `readPackedMessageFromReader`, `readPackedMessage`) plus builder byte/writer convenience methods.
- single-segment normalization helper for deterministic flat output (`toSingleSegmentFlatBytes`) and schema-less canonical segment bytes with struct/list truncation (`toCanonicalSegmentBytes`).
- initial `.capnp` schema parser, ordinal-aware compact layout planner, and Zig typed reader/builder scalar/blob readback/nested-struct builder readback/copy/list-reader/pointer-list-builder scalar/blob readback/list-builder copy/clear-element/reader-builder presence accessor skeleton generator with scalar and escaped text/data default values plus raw enum get/set accessors for structs, enums with ordinal collision checks and fields with name collision checks, scalar fields and plus-prefixed/scientific numeric defaults, typed scalar/float/enum/struct/text/data/bool lists, TypeList shorthand, optional pointer syntax, dotted/keyword-safe named types with Zig identifier sanitization, nested/union/group declaration tolerance, string literals, skipped using/const/annotation/interface declarations and annotations, and file IDs.

The long-term target is to grow into a full schema/compiler/RPC stack while keeping Zig-friendly APIs and predictable performance.

## Build

```sh
zig build test
zig build run
zig build cpzc -- --runtime-import cpz --emit-raw-schema-comments schema.capnp generated/generated.zig
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
