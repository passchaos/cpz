# cpz

`cpz` is a Zig implementation of the Cap'n Proto wire format. The first milestone focuses on the runtime layer that must be fast, safe, and compatible with the C++ implementation:

- zero-copy readers and flat-message views over caller-owned byte slices;
- segmented stream framing compatible with `capnp::serialize`, with bounded segment-count validation;
- C++-style stream prefix sizing via `expectedSizeInWordsFromPrefix`;
- word/pointer/capability encoding with low-level pointer kind/decode/total-size inspection, lazy pointer validation, and schema-agnostic full-message validation/total-size stats with capability index limits;
- arena-backed builders for structs and arbitrary root pointers with in-progress scalar reads, scalar fields and plus-prefixed/scientific numeric defaults/lists, data-section and pointer-section views, pointer lists, UTF-8 text/data blobs with reader defaults, composite struct lists, schema-evolution list upgrades, list slicing, same-message pointer disown/adopt moves with orphanage/orphan allocation/copy/accessors/release including raw pointer orphan copies, whole-list/struct/pointer deep-copying from readers, and explicit pointer clearing;
- packed stream codec compatible with Cap'n Proto packing, including allocation-free pack/unpack helpers.
- one-call flat/packed stream framing helpers (`messageToFlatBytes`, `writeMessageToWriter`, `messageToPackedBytes`, `writePackedMessageToWriter`, `readMessageFromReader`, `readPackedMessageFromReader`, `readPackedMessage`) plus builder byte/writer convenience methods.
- single-segment normalization helper for deterministic flat output (`toSingleSegmentFlatBytes`) and schema-less canonical segment bytes with struct/list truncation (`toCanonicalSegmentBytes`).
- initial `.capnp` schema parser, ordinal-aware compact layout planner, and Zig typed reader/builder root/asReader/totalSize/orphanage/newOrphan/newOrphanIn/newOrphanCopy/newOrphanCopyIn helpers plus scalar/blob readback/nested-struct builder readback/copy/typed-orphan fromRaw/get/getReader/adopt/disown/list-reader/pointer-list-builder scalar/blob/asReader/totalSize/slice/orphanage readback/list-builder copy/clear-element/typed-orphan fromRaw/get/getReader/newOrphan/newOrphanIn/newOrphanCopy/newOrphanCopyIn/adopt/disown/slice-set/whole-list-copy/reader-builder presence accessor skeleton generator with scalar and escaped text/data default values plus raw enum get/set accessors for structs, enums with ordinal/name collision checks and fields and top-level declarations with name collision checks, scalar fields and plus-prefixed/scientific/special-float numeric defaults, typed scalar/float/enum/struct/text/data/bool/void/nested/imported-schema lists, simple `using` alias resolution plus imported type references, built-in AnyPointer init/copy/orphan allocation accessors, AnyStruct data-section/pointer-section/struct/list accessors, AnyList/Capability and named-interface capability accessors, anonymous union discriminants/accessors with overlapping storage, TypeList shorthand, optional pointer syntax, dotted/keyword-safe named types with Zig identifier sanitization/collision checks, nested/named-union/named-group/interface declaration tolerance, list/struct/block-text/hex-data default syntax tolerance, skipped const/annotation declarations and annotations, and file IDs.

The long-term target is to grow into a full schema/compiler/RPC stack while keeping Zig-friendly APIs and predictable performance.

## Build

```sh
zig build test
zig build run
zig build cpzc -- --check schema.capnp
zig build cpzc -- --runtime-import cpz --namespace api --emit-raw-schema-comments schema.capnp generated/generated.zig
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
