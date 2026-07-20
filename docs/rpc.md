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
  RPC exception helpers preserve reason, raw type, and optional trace text.
  Return wire events preserve `releaseParamCaps` and `noFinishNeeded` flags
  while still projecting to the simplified answer-resolving event.
  Return outcomes for exception, canceled, results-sent-elsewhere, and
  take-from-other-question are decoded and can resolve tracked answers without a
  results payload; these non-result outcomes can also be written.
  Await-from-third-party returns expose their pointer capability usage and can be
  written for future third-party answer handling with capability-index bounds
  validation.
  Call interface/method IDs and routing flags for third-party tail calls,
  no-promise-pipelining, and only-promise-pipeline can be decoded and written.
  Returns with `releaseParamCaps` release imports introduced by the matching
  Call params cap table; callers can retain them when the flag is false. These
  tracked releases are validated before answer/question state is mutated.
  Finish with `releaseResultCaps` releases imports introduced by matching
  Return results.
  No-finish-needed returns without result capabilities mark the corresponding
  question finished so its ID can be reused.
  Release wire events preserve `referenceCount` so `State.applyWireEvent()` can
  decrement import lifetimes without silently collapsing batched releases.
  Resolve wire events mark an existing import or export promise as resolved,
  remember the replacement cap descriptor for future forwarding, expose
  remembered imported-cap target resolution queries/predicates and next-hop
  target/effective-target mapping helpers, can decode/write/apply
  replacement cap descriptors or broken-promise exceptions, can initialize
  top-level Resolve messages, and do not conflate the official `ExportId` with
  answer IDs.
  Finish wire events preserve the official `releaseResultCaps` flag while still
  projecting to the simplified question-closing event.
  Provide/Accept/Join wire events open questions using their official
  `QuestionId` payloads rather than treating them as capability-table IDs.
  Provide wire readers/builders expose target and recipient pointer capability
  usage for future third-party handoff validation.
  Accept wire readers/builders expose provision pointer
  presence/capability usage and optional embargo bytes alongside the question
  ID, for future provision/embargo handling.
  Join wire readers/builders expose target and key-part pointer capability
  usage for future join result handling. Handoff and third-party pointer-usage
  writers reject capability indexes outside the encoded pointer's declared
  capability count.
  Disembargo wire readers/builders and wire events can decode and write targets
  plus sender/receiver loopback context IDs and accept embargo bytes, and
  applying accept disembargos reports how many tracked Accept embargos were
  released and can optionally return the released Accept question IDs for
  immediate follow-up scheduling. Full embargo queue handling remains future
  work. Disembargo
  batches can be initialized and handed directly to an embedding transport/enqueue
  callback, pending Accept embargos can be queried, filtered by embargo token,
  snapshotted, or emitted to a sink for queueing, and their targets are
  validated against tracked imports/answers before a full queue exists.
  ThirdPartyAnswer wire readers/builders expose completion pointer capability
  usage and resolve existing answers by official `AnswerId` while remaining
  distinct from ordinary Return events.
  Completed question IDs can be queried for cleanup readiness, reused, or
  explicitly forgotten individually or in batches once both Finish and
  Return-like answer resolution have been observed. Question/answer stats
  summarize open, finished, unresolved, resolved, and complete entries, and a
  state cleanup helper can reclaim both completed questions and released
  capability tombstones together.
  Open questions remember the RPC message kind that created them, giving later
  protocol-state code a typed hook for bootstrap/call/handoff-specific rules.
  Resolved answers remember the message kind that resolved them. Capability
  stats summarize live/released/resolved import/export lifetimes and import
  reference counts.
  Call `sendResultsTo` caller/yourself/third-party targets can be decoded and
  written, including third-party contact pointer capability usage.
  Generated RPC `Call.target` readers can be decoded into a lightweight
  `CallTarget` for imported capabilities and promised answers, written back into
  generated target builders, and validated against tracked imports/answers. An
  owning target decoder can include promised-answer transform paths, which can
  also be decoded and written for noop and get-pointer-field operations.
  Remembered Resolve targets can be queried as one-hop or transitive forwarding
  targets with cycle detection, giving dispatch loops a safe way to route calls
  that arrive for already-resolved imported promises.
  Generated RPC `CapDescriptor` readers can be decoded for the common
  none/sender/receiver entries plus third-party vine/contact capability usage
  and optional `attachedFd` index metadata, and written back into generated
  payload builders with third-party contact capability-index bounds validation.
  `CapabilityRegistry(T)` can seed sender-hosted descriptor tables for outgoing
  payloads. `Payload.capTable` can be decoded into caller-owned descriptor or
  descriptor-info slices, with absent tables treated as empty; helpers can
  initialize payload content capability indexes, text/data blobs, primitive
  UInt32 lists, or caller-filled struct content together with descriptor tables,
  including registry-backed sender-hosted descriptor tables for struct/text/data
  and UInt32-list payloads.
  Payload content capability indexes can be decoded and validated against the
  decoded cap table length.
  Decoded descriptor tables can be applied to `State` for basic import
  creation/reference counting and receiver-hosted export/answer validation;
  direct Call/Return payload application also validates payload content
  capability indexes before mutating state.
  `Call.params.capTable` can be decoded through the same descriptor pipeline, as
  can `Return.results.capTable`; convenience helpers can apply those generated
  Call/Return payload tables directly to `State`, and generated Call/Return
  builders can initialize those cap tables directly from descriptors or
  descriptor-info metadata, or combine them with payload content capability
  indexes, primitive UInt32 lists, or caller-filled struct payloads at either
  the Call/Return member level or through top-level Message builders. Generated Call builders can
  initialize question ID, target, and registry-backed params cap tables together;
  Return builders can initialize answer ID, flags, and registry-backed results
  cap tables together, either at the Call/Return member level or through
  top-level Message builders. Top-level Bootstrap,
  Finish/Release builders can initialize their question IDs, flags, and
  reference counts, and a helper can build a Return containing a single
  capability result directly from a Bootstrap request reader. A minimal
  bootstrap dispatcher can apply the request and invoke an application callback
  that returns the bootstrap export ID. A minimal Call dispatcher can do the
  same for calls that return a single capability, text/data/UInt32-list payloads
  through generic or typed convenience dispatchers, an empty no-finish result,
  exceptions, cancellation, results-sent-elsewhere,
  or take-from-other-question outcomes, including await-from-third-party
  tail-call handoffs. A
  method-aware call dispatcher can filter on interface/method IDs and emit an
  unimplemented exception for mismatches; a compile-time method table dispatcher
  can validate unique method entries, select among multiple handlers, and can be
  used by the single-message dispatcher. A
  single-message dispatcher can route generated Bootstrap/Call readers through
  those callbacks, report whether a response was initialized, a resolved call
  target needs forwarding, or state was applied, and apply other supported
  top-level wire messages to state; a batch helper can aggregate those outcomes
  over caller-provided message readers, including method-table call dispatch.
  Response-sink variants can hand initialized Bootstrap/Call responses directly
  to an embedding transport/enqueue callback while ignoring state-only events.
  Forwarding helpers can copy an inbound Call into a new outgoing Call while
  preserving question ID, params, method/routing metadata, and flags, and only
  rewriting the target to an explicit or remembered resolved destination.
  Dispatch variants that accept caller-provided forward-message builders,
  including batch dispatch helpers, can initialize outgoing Calls when they
  return `forward_required`; companion sink-dispatch variants can immediately
  hand initialized forwarded Calls, or both ordinary responses and forwarded
  Calls, to embedding transport/enqueue callbacks, including dense batch
  variants that consume compact response/forward output queues instead of one
  output slot per input message.
  Call initialization can include send-results routing (including third-party
  contact capability usage) and boolean call flags.
  A generated Call reader can also be applied as a unit:
  target validation, question opening, method/routing metadata recording, and
  method-match querying for future service dispatch, plus params
  capability-table bookkeeping.
  A generated Return reader can resolve its answer and apply result
  capability-table bookkeeping. A generated top-level Message reader can route
  call/return payload-aware application or simpler state events; Provide
  top-level messages validate targets and record recipient pointer usage, and
  callers can query and count tracked recipient usage and initialize a tracked
  Provide Return only when that recipient is present; aggregate handoff stats
  and ready-ID snapshots summarize tracked and ready Provide/Accept/Join state
  for polling runtimes, and readiness-validated completion plans can be
  materialized into batched handoff Return descriptors or initialized/sent
  directly, including through application handlers that compute result export
  IDs from the recorded pointer usage and optionally enqueue those returns.
  Accept top-level messages record provision pointer usage and owned embargo
  bytes, and matching Disembargo.accept contexts mark those embargos released
  for future provision handling; callers can query/count when an accepted
  provision is ready for completion plus its provision pointer usage, and
  initialize the accepted capability Return only after that readiness gate passes
  and a provision capability is present. Join top-level messages record target
  and key-part pointer usage; callers can query/count the tracked key-part usage
  and initialize a tracked Join result Return only when that key part is present.
  Provide/Accept/Join handoff completions can also initialize single or batched
  Return messages with readiness gates preserved, or hand those initialized
  returns directly to an embedding transport/enqueue callback. Join result
  returns can initialize and decode their result capability payloads. Finish clears recorded Provide/Accept/Join handoff
  bookkeeping for the finished question. Top-level
  Provide/Accept/Join/Disembargo builders can initialize their
  currently-structured handoff fields.
- Generated accessors for capability and named-interface fields and list
  elements include `FromTable` / `OrNullFromTable` helpers that delegate to
  `CapabilityTable(T)`.

## Not implemented yet

- RPC message loop, vats, generated/application service dispatch,
  protocol-complete question/answer state machines, promise pipelining,
  full embargo/disembargo queues, or tail calls.
- Network transports or event-loop integration.
- Application-level capability lifetime management beyond lightweight
  import/export bookkeeping, explicit single-entry and batch released-tombstone cleanup, and mapping
  wire indexes to handles supplied by the caller.
- Generated service stubs/skeletons for dispatching interface methods.

## Next useful increments

1. Turn the now-recorded structural RPC data into behavior: connect initialized
   forwarded Calls and handoff Returns to actual transport send queues,
   queue/release `Disembargo` traffic, and coordinate multi-part `Join` results.
2. Add higher-level generated request/response builders that combine
   `CapabilityRegistry(T)`, payload content construction, cap-table descriptor
   emission, and state validation for non-capability payload shapes as well as
   the current capability-result helpers.
3. Add a minimal dispatch loop for bootstrap/call/return over an application
   callback before attempting promise pipelining, vats, or network transports.
4. Add generated service skeleton types only after the runtime can execute and
   validate that minimal bootstrap/call/return flow.
