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
dynamic reader: 200000 iterations, 161417501 ns total, 807.1 ns/op
bulk read list: 50000 iterations, 12852999 ns total, 257.1 ns/op
build message: 50000 iterations, 854857813 ns total, 17097.2 ns/op
flat serialize: 50000 iterations, 18348583 ns total, 367.0 ns/op
packed serialize: 50000 iterations, 1014301456 ns total, 20286.0 ns/op
packed serialize (allocating): 50000 iterations, 1106901294 ns total, 22138.0 ns/op
pack (allocating): 50000 iterations, 1039154958 ns total, 20783.1 ns/op
pack to writer: 50000 iterations, 1022964979 ns total, 20459.3 ns/op
pack reader to writer: 50000 iterations, 1071507034 ns total, 21430.1 ns/op
unpack: 50000 iterations, 653830959 ns total, 13076.6 ns/op
unpack to writer: 50000 iterations, 620356368 ns total, 12407.1 ns/op
unpack reader to writer: 50000 iterations, 764829271 ns total, 15296.6 ns/op

# ReleaseFast
message: 1 segments, 4160 bytes flat, 4160 bytes packed
dynamic reader: 200000 iterations, 6255628 ns total, 31.3 ns/op
bulk read list: 50000 iterations, 2738024 ns total, 54.8 ns/op
build message: 50000 iterations, 10424191 ns total, 208.5 ns/op
flat serialize: 50000 iterations, 2993608 ns total, 59.9 ns/op
packed serialize: 50000 iterations, 49306597 ns total, 986.1 ns/op
packed serialize (allocating): 50000 iterations, 49805415 ns total, 996.1 ns/op
pack (allocating): 50000 iterations, 49217558 ns total, 984.4 ns/op
pack to writer: 50000 iterations, 48676435 ns total, 973.5 ns/op
pack reader to writer: 50000 iterations, 51829914 ns total, 1036.6 ns/op
unpack: 50000 iterations, 59719003 ns total, 1194.4 ns/op
unpack to writer: 50000 iterations, 74090467 ns total, 1481.8 ns/op
unpack reader to writer: 50000 iterations, 79214373 ns total, 1584.3 ns/op
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
for reader packing and 13.7 us -> 3.2 us for reader unpacking.
`packReaderToWriter` now packs whole words directly from each buffer chunk
instead of copying one word at a time, which brings it within a few percent of
`packToWriter` (about 1.0 us per 4 KB message). `unpackReaderToWriter` decodes
directly from the reader's own buffer, avoiding a second copy of the packed
input. `packInto`, `unpackInto`, `messageToFlatBytesInto`,
`messageToPackedBytesInto`, `packToWriter`, `unpackToWriter`, and
`unpackReaderToWriter` are marked `noinline`, and every benchmark loop runs in
its own non-inlined function: inlining the bulk and streaming paths into one
large `main` previously made LLVM produce substantially worse code and
overstated streaming costs by up to 3x. Zeroing of segment allocations
and packed zero runs uses plain 16-byte stores instead of `@memset`, because the
C library `memset` `dc zva` path is very slow on some aarch64 virtual machines;
this cut ReleaseFast message building from about 0.9 us to 0.2 us. Packed
Building many small children of a full parent now reuses free space in
existing segments instead of allocating a new segment per child, and new
segments double in capacity up to 8 MiB. A struct list with 512 text fields
drops from 463 segments to 4; 64 lists of 4 KB drop from 64 segments to 7 and
build about 34% faster.
Packed serialization computes the tag with a branch-free SWAR expression and compacts
payload bytes with a NEON `tbl` byte shuffle on aarch64 (a 256-entry shuffle
table); other targets and Debug builds keep the scalar loop. ReleaseFast
packed serialization dropped from about 1.45 us to 1.0 us per 4 KB message. The
allocating
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
cut message build time from roughly 8.2 us to 0.9 us in ReleaseFast, and the
plain-store zeroing described above brings it to about 0.2 us.
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
scan tags and compress payload bytes, but tag computation and payload
compaction now run without per-byte branches on aarch64.

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
- `MessageBuilder` reuses free space in any existing segment before growing the
  segment list, using a rotating allocation hint so the search stays amortized
  O(1), and new segments double in capacity up to 8 MiB. A struct list with 512
  text children drops from 463 segments to 4; 64 lists of 4 KB drop from 64
  segments to 7 and build about 34% faster. Fewer segments also shrink the
  serialized segment table and far-pointer traffic.
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
