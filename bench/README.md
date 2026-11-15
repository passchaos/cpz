# Benchmarks

```sh
zig build bench
zig build bench -Doptimize=ReleaseFast
```

The benchmark builds a small message with:

- one UInt32 data field;
- one text pointer field;
- one 1,024-element UInt32 list.

It measures, over five rounds and reporting the best round:

1. dynamic reader iteration (root + scalar + list element);
2. flat serialization into a caller-owned buffer;
3. packed serialization into a caller-owned buffer.

The output includes total nanoseconds and nanoseconds per operation. These are
local smoke numbers, not cross-engine claims. See
[`docs/performance.md`](../docs/performance.md) for current results and known
gaps (warmup/percentiles, multi-segment messages, C++ baseline, CI regression
gates).
