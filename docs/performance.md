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
- serializes it to flat bytes;
- parses it once;
- performs 100,000 dynamic reader iterations reading the scalar and one list
  element;
- prints total nanoseconds and a checksum.

Example output on the current aarch64 development host (Debug):

```text
100000 iterations, 80420839 ns, checksum 5900000
```

This is approximately 0.8 microseconds per iteration. The checksum ensures the
compiler cannot eliminate the reads.

## Codegen size

Generated code size is part of the performance story because it affects compile
time and binary size. Current measurements:

| Schema | Default | `--no-metadata` |
|---|---:|---:|
| Two-field `struct Tiny` | 3,392 lines / 166 KB | 926 lines / 39.7 KB |
| `tests/schema_smoke.capnp` | 92,327 lines / 4.7 MB | 63,033 lines / 3.1 MB |

Lean mode removes schema introspection tables, `@"cpz.*"` lookup helpers, and
root-level convenience helpers. Complex schemas still contain per-const and
per-enum metadata; further trimming is planned.

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
