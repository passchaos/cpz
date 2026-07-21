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
  elements, and orphans into the caller's handle type, with fallible and
  nullable lookup helpers for direct indexes and optional capability/interface
  fields.
- `CapabilityRegistry(T)` is an append-only application-owned handle registry
  for assigning outgoing capability indexes before writing capability pointers
  into builders, with direct index presence plus fallible and nullable handle
  lookup helpers and validation against message capability-count stats.
- `cpz.rpc` defines a transport-independent state-machine vocabulary for RPC
  message kinds, transport-independent `Event` values, question/answer
  transitions, import/export lifetimes, and a small `State` that tracks
  in-flight questions/answers plus accepted/provided capability lifetimes. It is
  intentionally not a networked dispatcher yet.
- `cpz.rpc.eventFromWireMessage()` can decode the top-level `rpc.capnp` message
  union shape from generated readers into lightweight `WireEvent` values,
  shares a `wireMessageTag()` helper with method/options metadata decoders, and
  projects only the semantically-aligned subset into `State.apply()` events.
  Abort wire events preserve their exception metadata while remaining
  state-inapplicable.
  RPC exception helpers preserve reason, raw type, and optional trace text, with
  typed `ExceptionType` conversion plus predicates for non-empty reason, trace,
  and standard exception-type matches.
  Return wire events preserve `releaseParamCaps` and `noFinishNeeded` flags
  while still projecting to the simplified answer-resolving event.
  Return outcomes for exception, canceled, results-sent-elsewhere,
  take-from-other-question, and await-from-third-party are decoded, expose
  result/non-result predicates plus variant-specific ID/capability accessors,
  and can resolve tracked answers without a results payload; these non-result
  outcomes can also be written.
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
  answer IDs. Resolve metadata exposes predicates and validation for the
  mutually-exclusive cap/exception payload, including broken-promise and
  forwardable-target helpers when the replacement descriptor can be used as a
  call target.
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
  capability count, and shared pointer-usage helpers expose capability presence,
  equality, and validation predicates.
  Disembargo wire readers/builders and wire events can decode and write targets
  plus sender/receiver loopback context IDs and accept embargo bytes, and
  applying accept disembargos reports how many tracked Accept embargos were
  released and can optionally return the released Accept question IDs for
  immediate follow-up Return initialization/enqueueing, including handler-based
  export selection from the released provision usage or caller-provided export
  IDs, and combined helpers can apply the disembargo then initialize or enqueue
  those follow-up Returns. Full embargo queue handling remains future work. Disembargo
  batches can be initialized and handed directly to an embedding transport/enqueue
  callback, pending Accept embargos can be queried, filtered by embargo token,
  snapshotted with non-empty, question, and token matching helpers, or
  selectively emitted to a sink or appended to caller-owned queues, and their
  targets are validated against tracked imports/answers before a full queue
  exists. Disembargo
  contexts and decoded infos expose sender/receiver/accept predicates, loopback
  IDs, accept-token matchers, and target matchers for embedding queues.
  ThirdPartyAnswer wire readers/builders expose completion pointer capability
  usage, can reconstitute that usage as `AnyPointerUsage`, and resolve existing
  answers by official `AnswerId` while remaining distinct from ordinary Return
  events.
  Completed question IDs can be queried for cleanup readiness, reused, or
  explicitly forgotten individually or in batches once both Finish and
  Return-like answer resolution have been observed. Question/answer states and
  trackers expose direct predicates; stats summarize open, finished, unresolved,
  resolved, complete, total, and active entries with role-specific convenience
  predicates, and a
  state cleanup helper can reclaim both completed questions and released
  capability tombstones together while reporting whether any work was done.
  Open questions remember the RPC message kind that created them, giving later
  protocol-state code a typed hook for bootstrap/call/handoff-specific rules.
  Resolved answers remember the message kind that resolved them. Capability
  states and trackers expose direct predicates, including resolved/replacement
  presence; stats summarize total/live/released/resolved import/export lifetimes
  and import reference counts with import/export/reference convenience
  predicates.
  Call `sendResultsTo` caller/yourself/third-party targets can be decoded,
  matched with role predicates, and written, including third-party contact
  pointer capability usage.
  Generated RPC `Call.target` readers can be decoded into a lightweight
  `CallTarget` for imported capabilities and promised answers, written back into
  generated target builders, and validated against tracked imports/answers. An
  owning target decoder can include promised-answer transform paths, which can
  also be decoded and written for noop and get-pointer-field operations with
  promised-question, transform presence, and transform operation predicates/accessors.
  Remembered Resolve targets can be queried as one-hop or transitive forwarding
  targets with cycle detection, giving dispatch loops a safe way to route calls
  that arrive for already-resolved imported promises.
  Generated RPC `CapDescriptor` readers can be decoded for the common
  none/sender/receiver entries plus third-party vine/contact capability usage
  and optional `attachedFd` index metadata, expose validation and contact usage
  helpers plus role/ID accessors and call-target forwarding predicates, and be
  written back into generated payload builders with third-party contact
  capability-index bounds validation.
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
  initialize question ID, target, registry-backed params cap tables, and
  caller-filled struct payloads together, and capability/capability-info/registry-backed-capability/text/text-info/registry-backed-text/data/data-info/registry-backed-data/UInt32-list/UInt32-list-info/registry-backed-UInt32-list/caller-filled-struct/caller-filled-struct-info/registry-backed-struct Call builders can apply the
  matching question/call-info/params bookkeeping to `State`; Return builders can initialize answer
  ID, flags, registry-backed results cap tables, and caller-filled struct
  payloads together, either at the Call/Return member level or through
  top-level Message builders, and generic dispatch-result, empty/exception/non-result/capability/capability-info/registry-backed-capability/text/text-info/registry-backed-text/data/data-info/registry-backed-data/UInt32-list/UInt32-list-info/registry-backed-UInt32-list/caller-filled-struct/caller-filled-struct-info/registry-backed-struct Return builders can
  initialize their wire payload while applying the matching answer/result
  capability bookkeeping to `State`. Top-level Unimplemented, Abort, Obsolete,
  Bootstrap, Finish/Release builders can initialize their tags, nested
  unimplemented-message payloads, exception metadata, question IDs, flags, and
  reference counts; Unimplemented wire events preserve and can match the nested
  original tag, payload helpers can copy or recover the nested original message
  tag/event, and a helper can build a Return containing a single capability
  result directly from a Bootstrap request reader. A minimal bootstrap
  dispatcher can apply the request and invoke an application callback that
  returns the bootstrap export ID. Typed Call dispatchers can also forward
  already-resolved targets without invoking local handlers. A minimal Call
  dispatcher can do the same for calls that return a single capability,
  text/data/UInt32-list payloads, or caller-filled struct payloads through
  generic or typed convenience dispatchers, with descriptor-info or
  registry-backed cap tables for those payload shapes, an empty no-finish result,
  exceptions, cancellation, results-sent-elsewhere,
  or take-from-other-question outcomes, including await-from-third-party
  tail-call handoffs. Generic dispatch results expose result/non-result shape
  predicates plus variant-specific payload, exception, ID, and capability
  accessors before they are materialized into Returns. A
  method-aware call dispatcher can filter on interface/method IDs, build
  capability, empty, text/data/UInt32-list payload returns and caller-filled struct payload returns with descriptor,
  descriptor-info, or registry-backed cap tables, and emit an unimplemented exception for
  mismatches; typed method helpers can also report or initialize forwarding
  for already-resolved targets without invoking local handlers. Generated
  interfaces with type IDs expose `cpz.rpc.CallMethod` constants plus runtime
  `CallMethod` helpers for `CallOptions` and method-table entries, metadata
  conversion/lookup helpers, and generated-or-metadata factories so method
  tables and Call builders can reference schema-defined interface/method IDs directly. A compile-time method table dispatcher
  can validate unique method entries, preview matching entry indexes, service
  actions, aggregate action stats/ranges plus split/output capacity checks,
  produce compact action queues for Call batches or top-level Message batches,
  top-level-message previews/outputs that skip non-Call messages and can fill
  split response/forward queues, send compact unified output prefixes with
  optional response/forward role tags, return lightweight output stats, record
  stats from service-action output positions, append outputs to caller-owned
  unified, role-tagged, or role-specific queues, or split them back to
  role-specific sinks,
  return and validate output stats from plain or plan-preserving
  service-action output sends against the selected service-action aggregate,
  and reuse existing plans when appending or sending source-preserving
  plan/message pairs to unified, role-tagged, or role-specific caller queues or sinks, including one-step
  init/dispatch wrappers and optional response/forward role tags, grouped action queues,
  or source-preserving plans that can materialize or enqueue split/combined/
  unified dispatch responses, forwarded Calls, and unimplemented Return exceptions for
  pre-apply wire calls and tracked calls, including one-call split/unified-output
  dispatch, source-preserving unified sinks, and one-call split/unified enqueue,
  select among multiple handlers, and
  can be used by the single-message dispatcher. A
  single-message dispatcher can route generated Bootstrap/Call readers through
  those callbacks, report whether a response was initialized, a resolved call
  target needs forwarding, or state was applied via outcome predicates, and apply other supported
  top-level wire messages to state; apply-handler variants, including
  forwarding, method-table, dense, dense-forwarding, and combined method-table
  forwarding equivalents, expose detailed state-only results such as released Accept IDs from
  Disembargo before deinitializing temporary result allocations, and a batch
  helper can aggregate those outcomes over caller-provided message readers,
  including method-table call dispatch.
  Response-sink variants can hand initialized Bootstrap/Call responses directly
  to an embedding transport/enqueue callback while ignoring state-only events,
  including dense response queues (with or without method tables) that skip
  state-only messages; no-sink dense variants can fill compact response queues
  for callers that want to enqueue or inspect initialized messages themselves.
  Non-mutating dispatch planning helpers can preview response, forward, and
  state-only counts plus dense output slot requirements before builders are
  allocated, with turn-level plans that expose output-presence predicates,
  distinguish dispatch-initialized responses from ready handoff Returns, and
  combine dispatch, ready handoff
  returns, and pending Disembargo queue counts plus capacity checks for split
  or unified output queues, including helpers for validating builders and
  slicing/querying unified output ranges and local indexes into response,
  forward, and Disembargo regions.
  Dense forwarding dispatch, with or without method-table handlers, can also
  fill a single caller-provided unified response/forward queue by using those
  ranges internally; ordinary and method-table forwarding unified dense paths
  also have apply-detail variants so embedders do not need to choose between
  compact output queues and observing state-only Disembargo release IDs.
  Separate builder-set validation is also available; pending Accept Disembargos can be planned, emitted to
  their own sink or caller-owned queue, or initialized into caller-owned builders without an immediate sink,
  from the same turn plan, either all at once or filtered by embargo token, including unified and role-tagged queue wrappers.
  Combined turn helpers, with or without method-table dispatch and
  apply-detail callbacks, can now dispatch dense responses/forwards, append
  ready handoff Returns, and initialize or send all or token-filtered pending Accept
  Disembargo messages in one validated call, including direct unified, role-tagged, or role-specific queue append, including ordinary apply-detail unified, role-tagged, and role-specific queues plus method-table apply-detail unified, role-tagged, and role-specific queues. A minimal
  turn helper, with or without method-table dispatch, can dispatch dense
  responses/forwards, expose state-only apply details, validate output builder
  slices, and append ready handoff Returns to the same response queue or sink
  for embedding transports; ordinary and method-table no-sink turn helpers can
  also populate a unified response/forward output queue with dispatch and ready
  handoff Returns before forwarded Calls, append pending Accept Disembargos into
  the same unified queue, including token-filtered Disembargo emission, and both
  unified forms can expose state-only apply details while doing so. Unified
  output queues can also be validated, appended to caller-owned queues with or
  without response/forward/Disembargo role tags, split into role-specific caller
  queues, sent as their initialized prefix to a single embedding
  transport/enqueue sink, sent to one sink with response/forward/Disembargo role
  tags, counted with lightweight output stats returned by untagged, tagged, or
  split send helpers, accumulated from unified output indexes, checked against
  dispatch/turn plans, or split by output role into separate sinks, including ordinary, method-table,
  token-filtered, and apply-detail variants.
  Forwarding helpers can copy an inbound Call into a new outgoing Call while
  preserving question ID, params, method/routing metadata, and flags, and only
  rewriting the target to an explicit or remembered resolved destination.
  Dispatch variants that accept caller-provided forward-message builders,
  including batch dispatch helpers, can initialize outgoing Calls when they
  return `forward_required`; companion sink-dispatch variants can immediately
  hand initialized forwarded Calls, or both ordinary responses and forwarded
  Calls, to embedding transport/enqueue callbacks. Dense batch variants can
  consume compact response/forward output queues instead of one output slot per
  input message, with or without immediate sink callbacks.
  Call initialization can include send-results routing (including third-party
  contact capability usage), boolean call flags, and non-capability payload
  helper variants, including registry-backed payloads, that also set
  method/routing options for descriptor-backed or registry-backed capability
  payloads, blobs, primitive lists,
  caller-filled structs, and descriptor-info metadata.
  Borrowed and owned Call targets expose predicates and ID matchers for imported
  capabilities and promised answers, and owned targets can be viewed as
  lightweight borrowed targets when transform ownership is not needed.
  Method IDs, result routing, and call flags can also be decoded from or written
  to generated Call readers/builders as a single `CallOptions` value, so
  dispatch and initialization paths share the same validation rules. Fluent
  `CallFlags` and `CallOptions` builders can toggle individual routing flags
  without replacing the whole `CallFlags` value.
  `CallOptions` exposes predicates for default state, explicit method IDs, and
  third-party result-target capability usage, and tracked `CallInfo`/`State`
  queries expose matching predicates.
  `CallOptions` can build the corresponding tracked `CallInfo`, and tracked
  calls can restore both `CallMethod` and `CallOptions` for later dispatch
  without each helper manually reassembling the same fields. Runtime and
  generated method-table entries expose the same tracked-info construction
  helper for code paths that select a handler before recording call state.
  Generated interfaces can also resolve methods, call options, and method
  entries directly from a generated Call reader's interface/method IDs or from
  a top-level Message reader when it contains a Call.
  Runtime call methods/options/entries expose matching predicates for
  `CallMethod` values, generated Call readers, and top-level Message readers
  that contain Calls, plus wire Call/Message method-entry index helpers; tracked calls can be compared directly with generated
  Call or Message readers. Top-level Message readers can
  also be queried for Call method/options when their active union member is
  `Call`, otherwise they report no Call metadata. Transport-independent state
  events expose the same role predicates as message kinds. Call readers and top-level
  Call messages can expose call targets and can be decoded into the same
  `CallInfo` shape used for tracked call dispatch snapshots.
  A generated Call reader can also be applied as a unit:
  target validation, question opening, method/routing metadata recording,
  tracked/effective target querying, dispatch-info snapshots that can directly
  compute method-entry indexes, service actions, and dispatch outcomes, direct
  call/message dispatch-outcome previews, service-action previews,
  `CallOptions` restoration, and direct `CallMethod`/send-results/
  third-party result-target/flag querying for future service dispatch, plus
  params capability-table bookkeeping. Individual service actions and plans
  report whether they need response or forward output slots, and aggregate
  stats expose predicates for output/gap presence. Message dispatch previews use
  the shared tag decoder before decoding Call-specific details. The same dispatch-info snapshot can be
  built from an unapplied wire Call or top-level Call message for pre-apply
  forwarding/dispatch previews while non-Call messages report no dispatch work.
  A generated Return reader can resolve its answer and apply result
  capability-table bookkeeping. A generated top-level Message reader can route
  call/return payload-aware application, apply simple message batches with
  optional per-message observation, return detailed Disembargo release
  information when requested with apply-result predicates and released-Accept
  ID helpers, aggregate or observe that detail across batches, or apply simpler
  state events; Provide
  top-level messages validate targets and record recipient pointer usage, and
  callers can query and count tracked recipient usage and initialize a tracked
  Provide Return only when that recipient is present; aggregate handoff stats
  and ready-ID snapshots summarize tracked, blocked, and ready
  Provide/Accept/Join state for polling runtimes, and readiness-validated
  completion plans can be
  materialized into batched handoff Return descriptors or initialized/sent
  directly, including through application handlers that compute result export
  IDs from the recorded pointer usage, report ready return counts, produce
  reusable completion arrays, validate return queue capacity, and optionally
  enqueue those returns.
  Accept top-level messages record provision pointer usage and owned embargo
  bytes, and matching Disembargo.accept contexts mark those embargos released
  for future provision handling; callers can query/count when an accepted
  provision is ready for completion plus its provision pointer usage, and
  initialize the accepted capability Return only after that readiness gate passes
  and a provision capability is present. Join top-level messages record target
  and key-part pointer usage; callers can query/count the tracked key-part usage
  and initialize a tracked Join result Return only when that key part is present.
  Handoff aggregate stats expose predicates for tracked, ready, and blocked
  work. Provide/Accept/Join/ThirdPartyAnswer info, tracker, and `State` query
  helpers can reconstitute, match, and validate their recorded pointer usage as
  `AnyPointerUsage` values.
  Provide/Accept/Join handoff completions can also initialize single or batched
  Return messages with readiness gates preserved, derive single
  Provide/Accept/Join result exports through application handlers, or hand those
  initialized returns directly to an embedding transport/enqueue callback. Both
  explicit completion lists and structured handoff return plans can be
  pre-validated against tracked readiness before callers allocate or fill
  response builders.
  Handoff return values expose their kind plus answer/export IDs, and return
  plans/stats and ready-ID snapshots report whether any returns are pending,
  whether each handoff return kind is present, and the role-specific output
  ranges for provide/accept/join returns. Join result
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
