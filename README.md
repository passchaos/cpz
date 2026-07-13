# cpz

`cpz` is a Zig implementation of the Cap'n Proto wire format. The first milestone focuses on the runtime layer that must be fast, safe, and compatible with the C++ implementation:

- zero-copy readers and flat-message views over caller-owned byte slices;
- segmented stream framing compatible with `capnp::serialize`, with bounded segment-count validation;
- C++-style stream prefix sizing via `expectedSizeInWordsFromPrefix`;
- word/pointer/capability encoding with low-level pointer kind/decode/asReader/total-size inspection, lazy pointer validation, and schema-agnostic full-message validation/total-size stats with capability index limits;
- arena-backed builders for structs and arbitrary root pointers with list/text/data/capability root helpers and root pointer introspection/null-checking/clearing and in-progress scalar reads, scalar fields and plus-prefixed/scientific numeric defaults/lists, data-section/pointer-section/shape views, pointer lists, UTF-8 text/data blobs with reader defaults, composite struct lists, schema-evolution list upgrades, list slicing/isEmpty/lastIndex/raw primitive byte views including unaligned primitive reader/builder slices, same-message pointer/root disown/adopt moves with orphanage/orphan allocation/scalar-allocation/copy/scalar-accessors/accessors/release including raw pointer orphan copies, whole-list/struct/pointer/root-pointer deep-copying from readers including bit lists, and explicit pointer clearing;
- packed stream codec compatible with Cap'n Proto packing, including allocation-free pack/unpack helpers.
- one-call flat/packed stream framing helpers (`messageToFlatBytes`, `writeMessageToWriter`, `messageToPackedBytes`, `writePackedMessageToWriter`, `readMessageFromReader`, `readPackedMessageFromReader`, `readPackedMessage`) plus builder byte/writer convenience methods.
- single-segment normalization helper for deterministic flat output (`toSingleSegmentFlatBytes`) and schema-less canonical segment bytes with struct/list truncation (`toCanonicalSegmentBytes`).
- initial `.capnp` schema parser, ordinal-aware compact layout planner, and Zig typed reader/builder root/root-pointer/reader-builder-options-asReader-segments-byte-slice-count-length-capacity-bytes-root-validation-with-options/root-stats-with-options-builder-validate-with-options/builder-root-stats-with-options-reader-options-traversal-budget/reader-builder-segments-size-table-byte-writer-canonical-single-segment-methods/byte-writer-size-builder-single-segment-serialization/reader-builder-root-null/direct-root-pointer-null/root-scalar/root-list/root-move-copy/typed-root-orphan/asReader/validate/validate-with-options/orphan-stats/totalSize-with-options/totalSize/actualSize/dataSection/pointerSection/orphanage/copyFrom/clear/newOrphan/newOrphanIn/newOrphanCopy/newOrphanCopyIn helpers plus scalar/blob/scalar-orphan/asReader/pointer-view/pointer-kind/raw-pointer/decode/stats/total-size/stats-size/stats-state/max-capability-count/size-state/hasWords readback/nested-struct builder readback/copy/typed-orphan fromRaw/get/getReader/asReader/asPointerReader/decode/validate/adopt/disown/list-reader/isEmpty/lastIndex/validate-with-options/pointer-list-builder scalar/blob/scalar-orphan/asReader/rawBytes/rawPrimitiveBytes/presence/pointer-kind/raw-pointer/decode/stats/totalSize/elementSize/structElementSize/slice/orphanage/element pointer introspection/stats readback/list-builder stats-with-options copy/clear-element/typed-orphan fromRaw/get/getReader/asReader/asPointerReader/decode/validate/newOrphan/newOrphanIn/newOrphanCopy/newOrphanCopyIn/adopt/disown/slice-set/whole-list-copy/reader-builder presence accessor skeleton generator with helper parameter names escaped away from schema-field shadowing, scalar and escaped text/data default values plus raw enum get/set/helper/schema-name/value-count/metadata lookup accessors for structs, enums with ordinal/name collision checks, simple scalar/text/data/enum/list top-level, struct-local, and interface-local constants with count metadata plus top-level, struct-local, and interface-local indexed constant metadata/resolved-type/list-item-count/list-item metadata/lookup helpers plus per-const and per-list-item metadata constants including raw unsupported const literals, raw file/declaration/enumerant/const annotation metadata, total enumerant constants, and file annotation count/tables/lookup helpers/per-file-annotation constants, structured enum value and struct field count/metadata with declaration indexes and physical slots, enum declaration indexes, plus total field index/ordinal/type/resolved-type/default/annotation/slot/union metadata and lookup helpers and fields/top-level declarations with name collision checks, scalar fields and plus-prefixed/scientific/special-float numeric defaults, typed scalar/float/enum/struct/text/data/bool/void/nested/imported-schema/generic-parameter lists and indexed import count/metadata/lookup helpers and per-import metadata constants, generic declaration/method parameter count metadata/lookup helpers and per-parameter constants and type-application parsing/canonicalization including branded dotted suffixes, simple named and anonymous top-level and struct-local scoped `using` alias/import resolution plus generated top-level/struct-local/interface-local alias declarations and indexed alias count/resolved alias metadata/lookup helpers and per-alias metadata constants plus imported type references, built-in AnyPointer init/cast/scalar-set/copy/scalar-orphan/orphan allocation accessors and full list element/orphan/cast helpers, AnyStruct data-section/pointer-section/struct/list/orphan/list-element reader-builder section accessors, AnyList primitive/composite initialization, orphan allocation, and list element introspection helpers, Capability and named-interface capability accessors plus parsed/generated interface method count and indexed method table/lookup helpers plus method index/name/ordinal/signature/parameter/result/type/resolved-type/annotation/parameter-result-field counts/arrays/field-count/field-index/field-default/field-hex-default/field-annotation/field-lookup/per-method-field/resolved-type/streaming constants and superclass count/metadata/resolved-name/lookup helpers/per-superclass constants/aliases, parsed/generated top-level, struct-local, and interface-local annotation declarations with count and indexed type/resolved-type/target metadata tables, lookup helpers, and per-annotation metadata constants, anonymous union discriminants/accessors/count/metadata/lookup helpers and per-union layout constants with overlapping storage, TypeList shorthand, optional pointer syntax, dotted/keyword-safe named types with Zig identifier sanitization/collision checks, qualified nested struct/enum/interface declaration lowering in structs and interfaces with local type aliases, nested/interface declaration tolerance and simple named group/union field lowering, list/struct/block-text/hex-data/embed default syntax tolerance, skipped complex const/annotation declarations and annotations, and generated file/type ID constants plus declaration kind counts/declaration count/parameter-count and indexed declaration metadata/lookup helpers and per-declaration metadata constants.

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
