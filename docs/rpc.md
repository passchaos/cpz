# RPC foundation status

`cpz.rpc` models the wire-level pieces needed for Cap'n Proto RPC-shaped
schemas, but it is **not** a complete RPC runtime. This document is the
authoritative scope boundary.

## Status matrix

| Area | Status |
|---|---|
| RPC message vocabulary (`rpc.capnp` shapes) | Implemented |
| Wire event decoding / encoding | Implemented for the documented subset |
| Question/answer state tracking | Implemented |
| Import/export capability lifetimes | Implemented |
| `CapabilityTable` / `CapabilityRegistry` views | Implemented |
| Capability descriptors and payload cap tables | Implemented |
| Bootstrap / Call / Return dispatch helpers | Transport-independent helpers implemented |
| Provide / Accept / Join handoff bookkeeping | Implemented |
| Disembargo and pending-embargo planning | Implemented |
| Turn plans, output sinks/queues, role tagging | Implemented |
| Network transports / message loop | Not implemented |
| Promise pipelining | Not implemented |
| Vats | Not implemented |
| Full embargo queues / tail calls | Not implemented |
| Generated service stubs/skeletons | Not implemented |

## Implemented foundation

### Message vocabulary and events

- `WireMessageTag`, `WireEvent`, `MessageKind`, `Event`, and
  `eventFromWireMessage()` decode the top-level RPC message union from
  generated readers.
- Exception metadata preserves reason, raw type, and optional trace text.
- Return outcomes cover exception, canceled, results-sent-elsewhere,
  take-from-other-question, and await-from-third-party.
- Call targets, send-results routing, flags, method IDs, and promised-answer
  transforms can be decoded and written.
- Resolve, Finish, Release, Provide, Accept, Join, and Disembargo metadata have
  decode/write helpers and state transitions.

### State

`cpz.rpc.State` tracks:

- open questions and their opening message kind;
- answers and resolution kind;
- import/export lifetimes, including released tombstones;
- parameter/result import references;
- Provide/Accept/Join handoff bookkeeping;
- tracked call info (method, options, target).

State queries expose predicates, counts, cleanup readiness, and batch cleanup
helpers.

### Capabilities and payloads

- `CapabilityTable(T)` is a non-owning view from wire indexes to application
  handles.
- `CapabilityRegistry(T)` assigns outgoing indexes and can seed sender-hosted
  descriptor tables.
- Capability descriptors support none/sender/receiver and third-party
  vine/contact forms, with optional attached-fd metadata.
- Payload cap tables can be decoded into caller-owned descriptor slices or
  initialized from descriptors/infos/registries.
- Payload content helpers cover capabilities, text/data, UInt32 lists, and
  caller-filled structs.

### Dispatch and output planning

- Bootstrap and Call dispatch helpers can apply requests, invoke application
  callbacks, and initialize Return messages.
- Method-table dispatch filters on interface/method IDs and emits unimplemented
  exceptions for mismatches.
- Forwarding helpers rewrite Call targets for already-resolved imports.
- Turn plans combine dispatch responses, ready handoff Returns, and pending
  Accept Disembargos.
- Output helpers support unified buffers, role-tagged sinks/queues, and
  role-specific sinks/queues.

## Not implemented yet

- RPC message loop and network transports.
- Vats and application service dispatch beyond callback helpers.
- Protocol-complete promise pipelining.
- Full embargo/disembargo queues and tail-call execution.
- Generated service stubs/skeletons.
- Production-grade capability lifetime management beyond the lightweight
  import/export bookkeeping in `State`.

## Next useful increments

1. Build a minimal end-to-end transport loop over a stream socket:
   bootstrap → call → return → finish.
2. Consolidate the output helper surface behind a small sink/queue/turn
   abstraction instead of adding more `...ToSink` / `...ToQueue` variants.
3. Add generated service skeleton types only after the minimal loop works.
4. Add promise pipelining and vat semantics after the transport loop is stable.

## Testing

- Unit tests live in `src/rpc.zig`.
- The integration suite is split under `tests/codegen/rpc_event/`, with shared
  helpers in `tests/support/rpc_event.zig`. It exercises wire, state, dispatch,
  handoff, turn, and output paths.
- `tests/schema_rpc_event.capnp` is the primary generated-schema fixture.

## Design note

`cpz.rpc` deliberately uses structural typing (`anytype`) so generated readers,
test doubles, and dynamic readers can share helpers without a compile-time
schema dependency. The trade-off is a very broad public helper surface. Future
work should introduce small protocol interfaces (wire message, output sink,
output queue) and reduce the number of combinatorial helper variants.
