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
  message kinds, transport-independent `Event` values, question/answer
  transitions, import/export lifetimes, and a small `State` that tracks
  in-flight questions/answers plus accepted/provided capability lifetimes. It is
  intentionally not a networked dispatcher yet.
- `cpz.rpc.eventFromWireMessage()` can decode the top-level `rpc.capnp` message
  union shape from generated readers into lightweight `WireEvent` values, and
  projects only the semantically-aligned subset into `State.apply()` events.
  Release wire events preserve `referenceCount` so `State.applyWireEvent()` can
  decrement import lifetimes without silently collapsing batched releases.
  Resolve wire events mark an existing export promise as resolved without
  conflating the official `ExportId` with answer IDs.
  Provide/Accept wire events open questions using their official `QuestionId`
  payloads rather than treating them as capability-table IDs.
- Generated accessors for capability and named-interface fields and list
  elements include `FromTable` / `OrNullFromTable` helpers that delegate to
  `CapabilityTable(T)`.

## Not implemented yet

- RPC message loop, vats, bootstrap dispatch, protocol-complete question/answer
  state machines, promise pipelining, embargo/disembargo, or tail calls.
- Network transports or event-loop integration.
- Application-level capability lifetime management beyond lightweight
  import/export bookkeeping and mapping wire indexes to handles supplied by the
  caller.
- Generated service stubs/skeletons for dispatching interface methods.

## Next useful increments

1. Extend decoded `WireEvent` application beyond the currently safe
   bootstrap/call/return/finish/release subset once `State` models official
   `Resolve`, `Provide`, `Accept`, and `Join` semantics precisely.
2. Add request/response builders that use `CapabilityTable(T)` and
   `CapabilityRegistry(T)` for import/export table validation.
3. Add generated service skeleton types only after the runtime state machine can
   execute a minimal bootstrap/call/return flow.
