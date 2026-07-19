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
  Return wire events preserve `releaseParamCaps` and `noFinishNeeded` flags
  while still projecting to the simplified answer-resolving event.
  Returns with `releaseParamCaps` release imports introduced by the matching
  Call params cap table; callers can retain them when the flag is false.
  Finish with `releaseResultCaps` releases imports introduced by matching
  Return results.
  No-finish-needed returns without result capabilities mark the corresponding
  question finished so its ID can be reused.
  Release wire events preserve `referenceCount` so `State.applyWireEvent()` can
  decrement import lifetimes without silently collapsing batched releases.
  Resolve wire events mark an existing export promise as resolved, can decode,
  write, and apply a replacement cap descriptor, and do not conflate the
  official `ExportId` with answer IDs.
  Finish wire events preserve the official `releaseResultCaps` flag while still
  projecting to the simplified question-closing event.
  Provide/Accept/Join wire events open questions using their official
  `QuestionId` payloads rather than treating them as capability-table IDs.
  Accept wire readers expose their optional embargo bytes alongside the question
  ID, and can write that information back to generated builders, for future
  provision/embargo handling.
  Disembargo wire readers/builders can decode and write targets plus
  sender/receiver loopback context IDs, though full embargo queue handling
  remains future work.
  ThirdPartyAnswer wire events resolve existing answers by official `AnswerId`
  while remaining distinct from ordinary Return events.
  Completed question IDs can be reused once both Finish and Return-like answer
  resolution have been observed.
  Generated RPC `Call.target` readers can be decoded into a lightweight
  `CallTarget` for imported capabilities and promised answers, written back into
  generated target builders, and validated against tracked imports/answers. An
  owning target decoder can include promised-answer transform paths, which can
  also be decoded and written for noop and get-pointer-field operations.
  Generated RPC `CapDescriptor` readers can be decoded for the common
  none/sender/receiver entries plus the third-party vine ID, and written back
  into generated payload builders. `Payload.capTable` can be decoded into a
  caller-owned descriptor slice, with absent tables treated as empty. Payload
  content capability indexes can be validated against the decoded cap table length.
  Decoded descriptor tables can be applied to `State` for basic import
  creation/reference counting and receiver-hosted export/answer validation.
  `Call.params.capTable` can be decoded through the same descriptor pipeline, as
  can `Return.results.capTable`; convenience helpers can apply those generated
  Call/Return payload tables directly to `State`, and generated Call/Return
  builders can initialize those cap tables directly from descriptors. A
  generated Call reader can also be applied as a unit: target validation,
  question opening, and params capability-table bookkeeping. A generated Return
  reader can resolve its answer and apply result
  capability-table bookkeeping. A generated top-level Message reader can route
  call/return payload-aware application or simpler state events; Provide/Join
  top-level messages validate their targets before opening questions, while
  Accept top-level messages have an explicit question-opening route ready for
  future provision/embargo handling.
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

1. Model the remaining official RPC semantics that are still only structural:
   `Resolve` target replacement, `Disembargo`, `Accept.provision`/`embargo`,
   `Join` result handling, and third-party cap descriptors.
2. Add higher-level generated request/response builders that combine
   `CapabilityRegistry(T)`, payload content construction, cap-table descriptor
   emission, and state validation.
3. Add a minimal dispatch loop for bootstrap/call/return over an application
   callback before attempting promise pipelining, vats, or network transports.
4. Add generated service skeleton types only after the runtime can execute and
   validate that minimal bootstrap/call/return flow.
