# Performance

`cpz` prioritizes predictable, allocation-explicit behavior over benchmark
theater. The current benchmark is intentionally small; treat its numbers as a
smoke baseline, not a cross-engine claim.

## Running the benchmark

```sh
zig build bench
zig build bench -Doptimize=ReleaseFast
```

The current benchmark:

- builds a small message with a scalar, text field, and 1,024-element UInt32
  list using `ListBuilder.setAll`;
- serializes it to flat and packed bytes;
- parses it once;
- runs five rounds and reports the best round;
- measures message building, dynamic reader iteration, bulk-reading the UInt32
  list with `ListReader.getAll`, flat serialization into a caller buffer, packed
  serialization into a caller buffer, allocating packed serialization with
  `messageToPackedBytes`, allocating raw packing with `pack`, streaming packing
  with `packToWriter` and `packReaderToWriter`, unpacking into a caller buffer,
  and streaming unpacking with `unpackToWriter` and `unpackReaderToWriter`.

Example output on the current aarch64 development host:

```text
# Debug
message: 1 segments, 4160 bytes flat, 4160 bytes packed
dynamic reader: 200000 iterations, 163281743 ns total, 816.4 ns/op
bulk read list: 50000 iterations, 13100152 ns total, 262.0 ns/op
build message: 50000 iterations, 820873511 ns total, 16417.5 ns/op
flat serialize: 50000 iterations, 17624568 ns total, 352.5 ns/op
packed serialize: 50000 iterations, 863161200 ns total, 17263.2 ns/op
packed serialize (allocating): 50000 iterations, 935812750 ns total, 18716.3 ns/op
pack (allocating): 50000 iterations, 911944664 ns total, 18238.9 ns/op
pack to writer: 50000 iterations, 778003789 ns total, 15560.1 ns/op
pack reader to writer: 50000 iterations, 1472725453 ns total, 29454.5 ns/op
unpack: 50000 iterations, 645388432 ns total, 12907.8 ns/op
unpack to writer: 50000 iterations, 611924074 ns total, 12238.5 ns/op
unpack reader to writer: 50000 iterations, 630148806 ns total, 12603.0 ns/op

# ReleaseFast
message: 1 segments, 4160 bytes flat, 4160 bytes packed
dynamic reader: 200000 iterations, 6491904 ns total, 32.5 ns/op
bulk read list: 50000 iterations, 2557493 ns total, 51.1 ns/op
build message: 50000 iterations, 46251667 ns total, 925.0 ns/op
flat serialize: 50000 iterations, 3001487 ns total, 60.0 ns/op
packed serialize: 50000 iterations, 72481740 ns total, 1449.6 ns/op
packed serialize (allocating): 50000 iterations, 73158363 ns total, 1463.2 ns/op
pack (allocating): 50000 iterations, 72536685 ns total, 1450.7 ns/op
pack to writer: 50000 iterations, 124340173 ns total, 2486.8 ns/op
pack reader to writer: 50000 iterations, 131666586 ns total, 2633.3 ns/op
unpack: 50000 iterations, 67449820 ns total, 1349.0 ns/op
unpack to writer: 50000 iterations, 241652330 ns total, 4833.0 ns/op
unpack reader to writer: 50000 iterations, 157181690 ns total, 3143.6 ns/op
```

These numbers are a local smoke baseline, not a cross-engine claim; absolute
values vary with host load, and the flat path is memory-bandwidth-bound.
`packInto` now writes the tag and payload bytes directly into the destination
when at least one word of headroom is available, avoiding a stack payload buffer
and two per-slice bounds checks. This cut packed serialization time by roughly
50% in ReleaseFast (3.1 us -> 1.4 us per 4 KB message). `packToWriter` and
`unpackToWriter` batch through a 4 KB buffer (and pack writes tag/payload
directly into it), roughly halving streaming time versus per-slice writer
calls. `packReaderToWriter` and `unpackReaderToWriter` now read through a 4 KB
buffer as well, and unpack decodes words directly from that buffer when enough
bytes are available; fixed-buffer microbenchmarks show roughly 6.6 us -> 2.3 us
for reader packing and 13.7 us -> 3.2 us for reader unpacking. The allocating
`pack` now allocates `maxPackedSize`, uses `packInto`, and shrinks to the written
length, avoiding the packed-size pre-pass and per-word `ArrayList` appends; it is
roughly 4x faster in a fixed-buffer microbenchmark. `ListReader.getAll`
copies a primitive list in one pass, and `ListBuilder.setAll` does the same for
writes. `getSlice`/`setSlice` provide the same fast path for subranges. A
fixed-buffer microbenchmark of the 1,024-element UInt32 list measures roughly
55 ns for `getAll` versus 1,200-1,800 ns for a per-element loop, essentially
`memcpy` speed; a 256-element `getSlice` takes about 15 ns versus 340 ns
per-element. The segment builder zeroes capacity lazily when words are allocated
instead of zeroing the whole first segment up front. Together with `setAll` this
cut message build time from roughly 8.2 us to 0.9 us in ReleaseFast.
`messageToPackedBytesInto` no longer
performs a redundant packed-size pre-pass; it relies on `packInto` bounds checks
and may leave a partial prefix when the destination is too small. This cut
packed serialization time by roughly 40% in both Debug and ReleaseFast. The
allocating `messageToPackedBytes` now allocates `maxPackedMessageSize` once and
shrinks to the written length, avoiding a full size pre-pass; it is also about
40% faster in the fixed-buffer microbenchmark. The allocating `unpack` now
computes the exact decoded size and reuses `unpackInto` instead of appending to
an `ArrayList` per word, which is about 17% faster in a fixed-buffer
microbenchmark. Packed output is still slower than flat output because it must
scan tags and compress payload bytes; further word-level optimizations are
tracked as follow-up work.

## Codegen size

Generated code size is part of the performance story because it affects compile
time and binary size. Current measurements:

| Schema | Default | `--no-metadata` | `--no-introspection` | Both |
|---|---:|---:|---:|---:|
| Two-field `struct Lean` | 3,394 lines / 163 KB | 928 lines / 39.6 KB | 2,776 lines / 134 KB | 310 lines / 10.8 KB |
| `tests/schema_smoke.capnp` | 92,327 lines / 4.7 MB | 60,631 lines / 3.0 MB | 46,886 lines / 2.4 MB | 15,190 lines / 0.71 MB |

`--no-metadata` removes schema introspection tables, `@"cpz.*"` lookup
helpers, root-level convenience helpers, and per-const/alias/enum metadata for
values that are emitted directly. Metadata needed by aggregate const values is
kept. `--no-introspection` removes the per-pointer-field diagnostic helpers
(pointer kind/location, decoded pointer, struct/list shape, stats, and match
predicates), list-wrapper diagnostics, pointer-list element diagnostics,
struct-level actual-size/section diagnostics, text/data byte-count/match
helpers, and scalar/blob/enum default-value flat containers, while keeping
readers, builders, list wrappers, element conversions, `validate`, and
`totalSize`. `--minimal` enables both modes. Combining both is intended for
production code that only reads and writes messages.

On the current aarch64 development host, a cold-cache
`zig build-obj -ODebug` of the generated `tests/schema_smoke.capnp` output takes
roughly 234 ms in default mode and 80-95 ms in the lean modes (median of three
runs).

Adding `--no-orphans` to `--minimal` removes generated Orphan wrapper types and
typed orphan/copy helpers, reducing the smoke schema to 10,672 lines / 0.54 MB
and the two-field schema to 152 lines / 5.8 KB. Raw `cpz.Orphan` builder methods
remain available because they are part of the core builder API.

## Runtime design notes

- Readers are zero-copy views over caller-owned segment slices.
- Validation is lazy and charged against traversal/nesting limits.
- Builders allocate append-only word arenas and write wire words directly;
  capacity is zeroed lazily as words are allocated.
- `MessageBuilder` creates a new segment when the preferred segment is full;
  the segment growth policy is intentionally simple and should be benchmarked
  for large messages.
- `toSingleSegmentFlatBytes` and `toCanonicalSegmentBytes` copy the reachable
  message into a fresh builder.

## Benchmark gaps

The current benchmark does not yet include:

- warmup and percentile reporting;
- flat vs packed comparisons;
- builder vs reader comparisons;
- multi-segment messages;
- a C++ `capnp` baseline;
- CI performance regression gates.

These are tracked as follow-up work. Until then, avoid presenting the current
numbers as evidence of superiority over other implementations.
