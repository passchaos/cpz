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
  list;
- serializes it to flat and packed bytes;
- parses it once;
- runs five rounds and reports the best round;
- measures dynamic reader iteration, flat serialization into a caller buffer,
  and packed serialization into a caller buffer.

Example output on the current aarch64 development host:

```text
# Debug
message: 1 segments, 4160 bytes flat, 4160 bytes packed
dynamic reader: 200000 iterations, 162932033 ns total, 814.7 ns/op
flat serialize: 50000 iterations, 17532161 ns total, 350.6 ns/op
packed serialize: 50000 iterations, 2632536186 ns total, 52650.7 ns/op

# ReleaseFast
message: 1 segments, 4160 bytes flat, 4160 bytes packed
dynamic reader: 200000 iterations, 3943798 ns total, 19.7 ns/op
flat serialize: 50000 iterations, 116881 ns total, 2.3 ns/op
packed serialize: 50000 iterations, 258453511 ns total, 5169.1 ns/op
```

These numbers are a local smoke baseline, not a cross-engine claim. The packed
serialization path is currently much slower than flat serialization and should
be profiled before optimizing.

## Codegen size

Generated code size is part of the performance story because it affects compile
time and binary size. Current measurements:

| Schema | Default | `--no-metadata` | `--no-introspection` | Both |
|---|---:|---:|---:|---:|
| Two-field `struct Lean` | 3,394 lines / 163 KB | 928 lines / 39.6 KB | 2,922 lines / 139 KB | 456 lines / 15.7 KB |
| `tests/schema_smoke.capnp` | 92,327 lines / 4.7 MB | 60,838 lines / 3.0 MB | 56,430 lines / 3.0 MB | 24,941 lines / 1.2 MB |

`--no-metadata` removes schema introspection tables, `@"cpz.*"` lookup
helpers, root-level convenience helpers, and per-const/alias/enum metadata for
values that are emitted directly. Metadata needed by aggregate const values is
kept. `--no-introspection` removes the per-pointer-field diagnostic helpers
(pointer kind/location, decoded pointer, struct/list shape, stats, and match
predicates), list-wrapper diagnostics, and scalar/blob/enum default-value flat
containers, while keeping readers, builders, list wrappers, and element
accessors. Combining both is intended for production code that only reads and
writes messages.

## Runtime design notes

- Readers are zero-copy views over caller-owned segment slices.
- Validation is lazy and charged against traversal/nesting limits.
- Builders allocate append-only word arenas and write wire words directly.
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
