# Security policy

## Reporting

Please report security issues privately to the repository maintainers rather
than opening a public issue. Include:

- affected version/commit;
- a minimal reproducer or malformed input;
- expected vs actual behavior;
- whether the issue requires untrusted input.

## Untrusted input

`cpz` parses wire-format data that may come from untrusted peers. The runtime
applies:

- traversal limits (`ReaderOptions.traversal_limit_words`);
- nesting limits (`ReaderOptions.nesting_limit`);
- optional capability-index limits;
- bounded segment counts during stream parsing;
- checked arithmetic for offsets, sizes, and word counts.

Do not disable these limits for untrusted input.

## Fuzzing

`tests/fuzz_smoke.zig` exercises:

- wire pointer decoding;
- flat and packed message readers;
- streaming readers;
- schema parsing, layout, and code generation;
- packing/unpacking round trips.

`zig build fuzz` runs a deterministic randomized corpus. Continuous
coverage-guided fuzzing via `zig build test --fuzz` depends on the pinned Zig
toolchain's fuzz runner being usable.

## Supported versions

Security fixes target the current `main` branch. The project is pre-1.0; there
are no long-term support branches yet.

## RPC

The RPC layer is transport-independent and not yet a production network
runtime. Do not expose it directly to untrusted peers without an external
transport and authentication layer.
