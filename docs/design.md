# Design principles

See [architecture.md](architecture.md) for the module map, ownership model,
validation limits, and compiler pipeline.

## Principles

1. **Wire compatibility first.** Pointer layouts, stream framing, packing, text
   terminators, bool packing, and composite-list tags follow the Cap'n Proto
   specification and the C++ reference implementation.
2. **Zero-copy readers.** Readers are views over caller-owned bytes. Eager
   validation is opt-in through `MessageReader.validate()`.
3. **Allocation-explicit builders.** Builders own append-only word arenas and
   write wire words directly. Caller-buffer serialization paths are preferred in
   hot paths.
4. **Small runtime core.** `wire`, `packing`, `serialize`, and `message` should
   remain independent of generated code.
5. **Schema compiler as a pipeline.** Lexer → parser/AST → validation → layout →
   code generation. Each stage should be testable in isolation.
6. **Lean generated code when introspection is not needed.** Use
   `--no-metadata` for wire-access-only APIs.
7. **Transport-independent RPC.** `rpc.zig` models protocol state and dispatch
   helpers without assuming a transport. Network/vat semantics are a later
   layer.
8. **Untrusted input is hostile.** Keep traversal/nesting/capability limits,
   fuzz the decoders, and never trust segment tables or pointer offsets.

## Non-goals

- Replacing the C++ Cap'n Proto implementation feature-for-feature in one step.
- Hiding allocation or ownership behind implicit copies.
- Declaring RPC complete before a minimal end-to-end transport loop exists.
