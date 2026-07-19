# RPC foundation status

`cpz` currently models the wire-format pieces that RPC-shaped schemas need, but
it does not implement Cap'n Proto RPC dispatch or networking yet. This document
keeps that boundary explicit so schema/codegen work can advance without implying
that a complete RPC runtime exists.

## Implemented foundation

- Interface declarations are parsed and emitted as metadata, including method
  signatures, parameter/result fields, annotations, generic parameters, and
  superclass metadata.
- Capability and named-interface fields are represented as Cap'n Proto
  capability pointers on the wire. Readers, builders, list elements, and orphans
  expose capability indexes and maximum-capability-count helpers.
- `ReaderOptions.capability_count_limit` and schema-agnostic validation reject
  capability indexes outside the caller-provided table size.
- `CapabilityTable(T)` is a lightweight, non-owning view over application-owned
  handles. It maps capability indexes from pointer readers/builders, list
  elements, and orphans into the caller's handle type, with nullable lookup
  helpers for optional capability/interface fields.
- `CapabilityRegistry(T)` is an append-only application-owned handle registry
  for assigning outgoing capability indexes before writing capability pointers
  into builders.
- `cpz.rpc` defines a transport-independent state-machine vocabulary for RPC
  message kinds, question/answer transitions, and import/export lifetimes. It is
  intentionally not a networked dispatcher yet.
- Generated accessors for capability and named-interface fields and list
  elements include `FromTable` / `OrNullFromTable` helpers that delegate to
  `CapabilityTable(T)`.

## Not implemented yet

- RPC message loop, vats, bootstrap, question/answer state machines, promise
  pipelining, embargo/disembargo, or tail calls.
- Network transports or event-loop integration.
- Application-level capability lifetime management beyond mapping wire indexes
  to handles supplied by the caller.
- Generated service stubs/skeletons for dispatching interface methods.

## Next useful increments

1. Connect `cpz.rpc` state-machine events to generated `rpc.capnp` message
   builders/readers for bootstrap/call/return/finish smoke flows.
2. Add request/response builders that use `CapabilityTable(T)` and
   `CapabilityRegistry(T)` for import/export table validation.
3. Add generated service skeleton types only after the runtime state machine can
   execute a minimal bootstrap/call/return flow.
