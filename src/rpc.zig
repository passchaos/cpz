const std = @import("std");
const types = @import("rpc/types.zig");

pub const State = @import("rpc/state.zig").State;

pub const anyPointerUsageFromWire = types.anyPointerUsageFromWire;
pub const capDescriptorsFromInfosAlloc = types.capDescriptorsFromInfosAlloc;
pub const validateCallMethodEntries = types.validateCallMethodEntries;
pub const callMethodEntryIndex = types.callMethodEntryIndex;
pub const exceptionInfoFromWireException = types.exceptionInfoFromWireException;
pub const writeExceptionInfoToWire = types.writeExceptionInfoToWire;
pub const initWireReturnException = types.initWireReturnException;

pub const QuestionId = types.QuestionId;
pub const AnswerId = types.AnswerId;
pub const ExportId = types.ExportId;
pub const ImportId = types.ImportId;
pub const Error = types.Error;
pub const CapabilityRef = types.CapabilityRef;
pub const CapabilityRelease = types.CapabilityRelease;
pub const Finish = types.Finish;
pub const Return = types.Return;
pub const ExceptionType = types.ExceptionType;
pub const ExceptionInfo = types.ExceptionInfo;
pub const ReturnOutcome = types.ReturnOutcome;
pub const DispatchResult = types.DispatchResult;
pub const WireDispatchOutcome = types.WireDispatchOutcome;
pub const OutputRange = types.OutputRange;
pub const WireDispatchStats = types.WireDispatchStats;
pub const WireDispatchOutputRole = types.WireDispatchOutputRole;
pub const WireDispatchOutputPosition = types.WireDispatchOutputPosition;
pub const wireDispatchUnifiedDenseOutputPosition = types.wireDispatchUnifiedDenseOutputPosition;
pub const StateCleanupStats = types.StateCleanupStats;
pub const StateHandoffStats = types.StateHandoffStats;
pub const StateReadyHandoffIds = types.StateReadyHandoffIds;
pub const HandoffReturnCapability = types.HandoffReturnCapability;
pub const HandoffReturn = types.HandoffReturn;
pub const HandoffReturnPlan = types.HandoffReturnPlan;
pub const StateHandoffReturnStats = types.StateHandoffReturnStats;
pub const HandoffReturnOutputRole = types.HandoffReturnOutputRole;
pub const HandoffReturnOutputPosition = types.HandoffReturnOutputPosition;
pub const handoffReturnUnifiedOutputPosition = types.handoffReturnUnifiedOutputPosition;
pub const sendHandoffReturnOutputsToTaggedSink = types.sendHandoffReturnOutputsToTaggedSink;
pub const sendHandoffReturnOutputsToTaggedSinkStats = types.sendHandoffReturnOutputsToTaggedSinkStats;
pub const appendHandoffReturnOutputsToTaggedQueue = types.appendHandoffReturnOutputsToTaggedQueue;
pub const sendHandoffReturnOutputsToSinks = types.sendHandoffReturnOutputsToSinks;
pub const sendHandoffReturnOutputsToSinksStats = types.sendHandoffReturnOutputsToSinksStats;
pub const appendHandoffReturnOutputsToQueues = types.appendHandoffReturnOutputsToQueues;
pub const RpcTurnPlan = types.RpcTurnPlan;
pub const RpcTurnResponseSourceRole = types.RpcTurnResponseSourceRole;
pub const RpcTurnResponseSourcePosition = types.RpcTurnResponseSourcePosition;
pub const RpcTurnResponseSourceStats = types.RpcTurnResponseSourceStats;
pub const rpcTurnResponseSourcePosition = types.rpcTurnResponseSourcePosition;
pub const rpcTurnResponseSourceOutputIndex = types.rpcTurnResponseSourceOutputIndex;
pub const RpcTurnOutputRole = types.RpcTurnOutputRole;
pub const RpcTurnOutputPosition = types.RpcTurnOutputPosition;
pub const RpcOutputStats = types.RpcOutputStats;
pub const rpcTurnUnifiedOutputPosition = types.rpcTurnUnifiedOutputPosition;
pub const sendRpcTurnResponsesToSourceTaggedSink = types.sendRpcTurnResponsesToSourceTaggedSink;
pub const sendRpcTurnResponsesToSourceTaggedSinkStats = types.sendRpcTurnResponsesToSourceTaggedSinkStats;
pub const appendRpcTurnResponsesToSourceTaggedQueue = types.appendRpcTurnResponsesToSourceTaggedQueue;
pub const sendRpcTurnResponsesToSourceSinks = types.sendRpcTurnResponsesToSourceSinks;
pub const sendRpcTurnResponsesToSourceSinksStats = types.sendRpcTurnResponsesToSourceSinksStats;
pub const appendRpcTurnResponsesToSourceQueues = types.appendRpcTurnResponsesToSourceQueues;
pub const sendRpcTurnUnifiedOutputsToSink = types.sendRpcTurnUnifiedOutputsToSink;
pub const sendRpcTurnUnifiedOutputsToSinkStats = types.sendRpcTurnUnifiedOutputsToSinkStats;
pub const appendRpcTurnUnifiedOutputsToQueue = types.appendRpcTurnUnifiedOutputsToQueue;
pub const appendRpcTurnUnifiedOutputsToTaggedQueue = types.appendRpcTurnUnifiedOutputsToTaggedQueue;
pub const appendRpcTurnUnifiedOutputsToQueues = types.appendRpcTurnUnifiedOutputsToQueues;
pub const sendRpcTurnUnifiedOutputsToTaggedSink = types.sendRpcTurnUnifiedOutputsToTaggedSink;
pub const sendRpcTurnUnifiedOutputsToTaggedSinkStats = types.sendRpcTurnUnifiedOutputsToTaggedSinkStats;
pub const sendRpcTurnUnifiedOutputsToSinks = types.sendRpcTurnUnifiedOutputsToSinks;
pub const sendRpcTurnUnifiedOutputsToSinksStats = types.sendRpcTurnUnifiedOutputsToSinksStats;
pub const StateQuestionStats = types.StateQuestionStats;
pub const StateCapabilityStats = types.StateCapabilityStats;
pub const AnyPointerUsage = types.AnyPointerUsage;
pub const AcceptInfo = types.AcceptInfo;
pub const ProvideInfo = types.ProvideInfo;
pub const JoinInfo = types.JoinInfo;
pub const ThirdPartyAnswerInfo = types.ThirdPartyAnswerInfo;
pub const AcceptTracker = types.AcceptTracker;
pub const JoinTracker = types.JoinTracker;
pub const ProvideTracker = types.ProvideTracker;
pub const CallInfo = types.CallInfo;
pub const TrackedCallDispatchInfo = types.TrackedCallDispatchInfo;
pub const TrackedCallServiceAction = types.TrackedCallServiceAction;
pub const TrackedCallServiceActionPlan = types.TrackedCallServiceActionPlan;
pub const TrackedCallServiceActionStats = types.TrackedCallServiceActionStats;
pub const TrackedCallServiceActionOutputRole = types.TrackedCallServiceActionOutputRole;
pub const TrackedCallServiceActionOutputPosition = types.TrackedCallServiceActionOutputPosition;
pub const trackedCallServiceActionUnifiedOutputPosition = types.trackedCallServiceActionUnifiedOutputPosition;
pub const DisembargoContext = types.DisembargoContext;
pub const DisembargoInfo = types.DisembargoInfo;
pub const DisembargoApplyInfo = types.DisembargoApplyInfo;
pub const PendingAcceptEmbargo = types.PendingAcceptEmbargo;
pub const PendingAcceptEmbargos = types.PendingAcceptEmbargos;
pub const WireMessageApplyResult = types.WireMessageApplyResult;
pub const WireMessageApplyStats = types.WireMessageApplyStats;
pub const ResolveInfo = types.ResolveInfo;
pub const PromisedAnswerTarget = types.PromisedAnswerTarget;
pub const PromisedAnswerOp = types.PromisedAnswerOp;
pub const PromisedAnswerTargetOwned = types.PromisedAnswerTargetOwned;
pub const CallTarget = types.CallTarget;
pub const CallTargetOwned = types.CallTargetOwned;
pub const CallSendResultsTo = types.CallSendResultsTo;
pub const CallFlags = types.CallFlags;
pub const CallMethod = types.CallMethod;
pub const CallMethodEntry = types.CallMethodEntry;
pub const CallOptions = types.CallOptions;
pub const CapDescriptor = types.CapDescriptor;
pub const CapDescriptorInfo = types.CapDescriptorInfo;
pub const callTargetFromForwardableCapDescriptor = types.callTargetFromForwardableCapDescriptor;
pub const WireMessageTag = types.WireMessageTag;
pub const wireMessageTag = types.wireMessageTag;
pub const WireEvent = types.WireEvent;
pub const MessageKind = types.MessageKind;
pub const Event = types.Event;
pub const QuestionState = types.QuestionState;
pub const AnswerState = types.AnswerState;
pub const CapabilityLifetime = types.CapabilityLifetime;
pub const QuestionTracker = types.QuestionTracker;
pub const AnswerTracker = types.AnswerTracker;
pub const CapabilityTracker = types.CapabilityTracker;
pub const ExportTracker = types.ExportTracker;
pub const ImportTracker = types.ImportTracker;
pub const targetFromWireMessageTarget = types.targetFromWireMessageTarget;
pub const targetFromWireMessageTargetAlloc = types.targetFromWireMessageTargetAlloc;
pub const writeCallTargetToWire = types.writeCallTargetToWire;
pub const writeCallTargetOwnedToWire = types.writeCallTargetOwnedToWire;
pub const promisedAnswerTransformFromWireAlloc = types.promisedAnswerTransformFromWireAlloc;
pub const initWirePromisedAnswerTransform = types.initWirePromisedAnswerTransform;
pub const callTargetFromWireCall = types.callTargetFromWireCall;
pub const callTargetFromWireCallAlloc = types.callTargetFromWireCallAlloc;
pub const callTargetFromWireMessage = types.callTargetFromWireMessage;
pub const callTargetFromWireMessageAlloc = types.callTargetFromWireMessageAlloc;
pub const callMethodFromWireCall = types.callMethodFromWireCall;
pub const writeCallMethodToWire = types.writeCallMethodToWire;
pub const sendResultsToFromWireCall = types.sendResultsToFromWireCall;
pub const writeSendResultsToToWire = types.writeSendResultsToToWire;
pub const sendResultsToThirdPartyUsageFromWireCall = types.sendResultsToThirdPartyUsageFromWireCall;
pub const writeSendResultsToThirdPartyToWire = types.writeSendResultsToThirdPartyToWire;
pub const callFlagsFromWireCall = types.callFlagsFromWireCall;
pub const writeCallFlagsToWire = types.writeCallFlagsToWire;
pub const callOptionsFromWireCall = types.callOptionsFromWireCall;
pub const callInfoFromWireCall = types.callInfoFromWireCall;
pub const writeCallOptionsToWire = types.writeCallOptionsToWire;
pub const callMethodFromWireMessage = types.callMethodFromWireMessage;
pub const callOptionsFromWireMessage = types.callOptionsFromWireMessage;
pub const callInfoFromWireMessage = types.callInfoFromWireMessage;
pub const acceptInfoFromWireAccept = types.acceptInfoFromWireAccept;
pub const writeAcceptInfoToWire = types.writeAcceptInfoToWire;
pub const initWireAcceptMessage = types.initWireAcceptMessage;
pub const provideInfoFromWireProvide = types.provideInfoFromWireProvide;
pub const writeProvideInfoToWire = types.writeProvideInfoToWire;
pub const initWireProvideMessage = types.initWireProvideMessage;
pub const joinInfoFromWireJoin = types.joinInfoFromWireJoin;
pub const writeJoinInfoToWire = types.writeJoinInfoToWire;
pub const initWireJoinMessage = types.initWireJoinMessage;
pub const thirdPartyAnswerInfoFromWireThirdPartyAnswer = types.thirdPartyAnswerInfoFromWireThirdPartyAnswer;
pub const writeThirdPartyAnswerInfoToWire = types.writeThirdPartyAnswerInfoToWire;
pub const initWireThirdPartyAnswerMessage = types.initWireThirdPartyAnswerMessage;
pub const disembargoInfoFromWireDisembargo = types.disembargoInfoFromWireDisembargo;
pub const writeDisembargoInfoToWire = types.writeDisembargoInfoToWire;
pub const initWireDisembargoMessage = types.initWireDisembargoMessage;
pub const initWireDisembargoMessages = types.initWireDisembargoMessages;
pub const initWireDisembargoMessagesToSink = types.initWireDisembargoMessagesToSink;
pub const initWireDisembargoMessagesToQueue = types.initWireDisembargoMessagesToQueue;
pub const targetFromWireTargetedMessage = types.targetFromWireTargetedMessage;
pub const capDescriptorFromWire = types.capDescriptorFromWire;
pub const capDescriptorInfoFromWire = types.capDescriptorInfoFromWire;
pub const resolveInfoFromWireResolve = types.resolveInfoFromWireResolve;
pub const writeResolveInfoToWire = types.writeResolveInfoToWire;
pub const initWireResolveMessage = types.initWireResolveMessage;
pub const writeCapDescriptorToWire = types.writeCapDescriptorToWire;
pub const writeCapDescriptorInfoToWire = types.writeCapDescriptorInfoToWire;
pub const initWirePayloadCapTable = types.initWirePayloadCapTable;
pub const initWirePayloadCapTableInfo = types.initWirePayloadCapTableInfo;
pub const initWirePayloadCapability = types.initWirePayloadCapability;
pub const initWirePayloadCapabilityInfo = types.initWirePayloadCapabilityInfo;
pub const initWirePayloadCapabilityFromRegistry = types.initWirePayloadCapabilityFromRegistry;
pub const initWirePayloadStructWith = types.initWirePayloadStructWith;
pub const initWirePayloadStructInfoWith = types.initWirePayloadStructInfoWith;
pub const initWirePayloadStructFromRegistry = types.initWirePayloadStructFromRegistry;
pub const initWirePayloadText = types.initWirePayloadText;
pub const initWirePayloadData = types.initWirePayloadData;
pub const initWirePayloadTextInfo = types.initWirePayloadTextInfo;
pub const initWirePayloadDataInfo = types.initWirePayloadDataInfo;
pub const initWirePayloadTextFromRegistry = types.initWirePayloadTextFromRegistry;
pub const initWirePayloadDataFromRegistry = types.initWirePayloadDataFromRegistry;
pub const initWirePayloadUInt32List = types.initWirePayloadUInt32List;
pub const initWirePayloadUInt32ListInfo = types.initWirePayloadUInt32ListInfo;
pub const initWirePayloadUInt32ListFromRegistry = types.initWirePayloadUInt32ListFromRegistry;
pub const senderHostedDescriptorsFromRegistryAlloc = types.senderHostedDescriptorsFromRegistryAlloc;
pub const initForwardedWireCall = types.initForwardedWireCall;
pub const initForwardedWireCallMessage = types.initForwardedWireCallMessage;
pub const initForwardedWireCallMessagesFromServiceActionPlans = types.initForwardedWireCallMessagesFromServiceActionPlans;
pub const initUnimplementedReturnMessagesFromServiceActionPlans = types.initUnimplementedReturnMessagesFromServiceActionPlans;

pub fn dispatchWireCallServiceActionPlans(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !usize {
    var response_count: usize = 0;
    for (plans) |plan| {
        switch (plan.action) {
            .dispatch => |entry_index| {
                if (plan.source_index >= calls.len) return error.InvalidTransition;
                if (plan.question_id != calls[plan.source_index].questionId()) return error.InvalidTransition;
                if (response_count >= response_messages.len) return error.InvalidTransition;
                var matched = false;
                inline for (entries, 0..) |entry, index| {
                    if (index == entry_index) {
                        try dispatchCallMethod(state, allocator, response_messages[response_count], calls[plan.source_index], entry.method, context, entry.handler);
                        response_count += 1;
                        matched = true;
                    }
                }
                if (!matched) return error.InvalidTransition;
            },
            .forward, .unimplemented => {},
        }
    }
    return response_count;
}

fn validateWireCallServiceActionPlans(calls: anytype, plans: []const TrackedCallServiceActionPlan, comptime entries: anytype) Error!TrackedCallServiceActionStats {
    var stats: TrackedCallServiceActionStats = .{};
    for (plans) |plan| {
        if (plan.source_index >= calls.len) return error.InvalidTransition;
        if (plan.question_id != calls[plan.source_index].questionId()) return error.InvalidTransition;
        switch (plan.action) {
            .dispatch => |entry_index| {
                var matched = false;
                inline for (entries, 0..) |_, index| {
                    if (index == entry_index) matched = true;
                }
                if (!matched) return error.InvalidTransition;
            },
            .forward, .unimplemented => {},
        }
        stats.record(plan.action);
    }
    return stats;
}

fn validateWireMessageServiceActionPlans(messages: anytype, plans: []const TrackedCallServiceActionPlan, comptime entries: anytype) !TrackedCallServiceActionStats {
    var stats: TrackedCallServiceActionStats = .{};
    for (plans) |plan| {
        if (plan.source_index >= messages.len) return error.InvalidTransition;
        const call = try messages[plan.source_index].call();
        if (plan.question_id != call.questionId()) return error.InvalidTransition;
        switch (plan.action) {
            .dispatch => |entry_index| {
                var matched = false;
                inline for (entries, 0..) |_, index| {
                    if (index == entry_index) matched = true;
                }
                if (!matched) return error.InvalidTransition;
            },
            .forward, .unimplemented => {},
        }
        stats.record(plan.action);
    }
    return stats;
}

pub fn initWireCallServiceActionPlanOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireCallServiceActionPlans(calls, plans, entries);
    try stats.validateOutputBuilders(response_messages, forward_messages);

    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (plans) |plan| {
        switch (plan.action) {
            .dispatch => |entry_index| {
                inline for (entries, 0..) |entry, index| {
                    if (index == entry_index) {
                        try dispatchCallMethod(state, allocator, response_messages[response_index], calls[plan.source_index], entry.method, context, entry.handler);
                        response_index += 1;
                    }
                }
            },
            .forward => |target| {
                try initForwardedWireCallMessage(forward_messages[forward_index], calls[plan.source_index], target);
                forward_index += 1;
            },
            .unimplemented => {
                try initWireReturnException(try response_messages[response_index].init_return_(), calls[plan.source_index].questionId(), true, false, .{
                    .reason = "unimplemented method",
                    .type_raw = 3,
                });
                response_index += 1;
            },
        }
    }
    return stats;
}

pub fn initWireCallServiceActionPlanOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanOutputs(state, allocator, calls, plans, response_messages, forward_messages, context, entries);
    for (try stats.outputResponseRange().slice(response_messages)) |message| try response_handler(response_context, message);
    for (forward_messages[0..stats.forward]) |message| try forward_handler(forward_context, message);
    return stats;
}

pub fn initWireMessageServiceActionPlanOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireMessageServiceActionPlans(messages, plans, entries);
    try stats.validateOutputBuilders(response_messages, forward_messages);

    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (plans) |plan| {
        const call = try messages[plan.source_index].call();
        switch (plan.action) {
            .dispatch => |entry_index| {
                inline for (entries, 0..) |entry, index| {
                    if (index == entry_index) {
                        try dispatchCallMethod(state, allocator, response_messages[response_index], call, entry.method, context, entry.handler);
                        response_index += 1;
                    }
                }
            },
            .forward => |target| {
                try initForwardedWireCallMessage(forward_messages[forward_index], call, target);
                forward_index += 1;
            },
            .unimplemented => {
                try initWireReturnException(try response_messages[response_index].init_return_(), call.questionId(), true, false, .{
                    .reason = "unimplemented method",
                    .type_raw = 3,
                });
                response_index += 1;
            },
        }
    }
    return stats;
}

pub fn initWireMessageServiceActionPlanOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    response_messages: anytype,
    forward_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanOutputs(state, allocator, messages, plans, response_messages, forward_messages, context, entries);
    for (try stats.outputResponseRange().slice(response_messages)) |message| try response_handler(response_context, message);
    for (forward_messages[0..stats.forward]) |message| try forward_handler(forward_context, message);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireCallServiceActionPlans(calls, plans, entries);
    try stats.validateActionCapacity(output_messages.len);
    return initWireCallServiceActionPlanOutputs(
        state,
        allocator,
        calls,
        plans,
        try stats.outputResponseRange().slice(output_messages),
        try stats.outputForwardRange().slice(output_messages),
        context,
        entries,
    );
}

pub fn sendRpcServiceActionUnifiedOutputsToSink(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcServiceActionUnifiedOutputsToSinkStats(stats, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputsToSinkStats(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()]) |message| try sink_handler(sink_context, message);
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputsToQueue(allocator: std.mem.Allocator, stats: TrackedCallServiceActionStats, output_messages: anytype, queue: anytype) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()]) |message| try queue.append(allocator, message);
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputsToQueues(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (try stats.outputResponseRange().slice(output_messages)) |message| {
        try response_queue.append(allocator, message);
    }
    for (try stats.outputForwardRange().slice(output_messages)) |message| {
        try forward_queue.append(allocator, message);
    }
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputsToTaggedQueue(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    queue: anytype,
) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    var output_stats: RpcOutputStats = .{};
    for (output_messages[0..stats.actions()], 0..) |message, output_index| {
        const position = trackedCallServiceActionUnifiedOutputPosition(stats, output_index).?;
        try queue.append(allocator, .{ .position = position, .message = message });
        output_stats.recordServiceActionPosition(position);
    }
    return output_stats;
}

/// Append source-preserving service-action outputs to an embedder-owned queue.
///
/// The compact unified output buffer is ordered as responses first, then
/// forwarded Calls.  The original service-action plans can be in source order,
/// so this helper walks the plans by action kind and pairs each output builder
/// with the plan that produced it.  Queue element types should provide
/// `plan` and `message` fields, for example:
/// `struct { plan: TrackedCallServiceActionPlan, message: Message.Builder }`.
pub fn appendRpcServiceActionUnifiedOutputPlansToQueue(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    queue: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);

    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try queue.append(allocator, .{ .plan = plan, .message = output_messages[forward_index] });
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputPlansToQueues(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);

    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try response_queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try response_queue.append(allocator, .{ .plan = plan, .message = output_messages[response_index] });
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try forward_queue.append(allocator, .{ .plan = plan, .message = output_messages[forward_index] });
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(
    allocator: std.mem.Allocator,
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    queue: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);

    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    var response_local_index: usize = 0;
    var forward_local_index: usize = 0;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            const position: TrackedCallServiceActionOutputPosition = .{ .role = .response, .local_index = response_local_index };
            try queue.append(allocator, .{ .plan = plan, .position = position, .message = output_messages[response_index] });
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            const position: TrackedCallServiceActionOutputPosition = .{ .role = .response, .local_index = response_local_index };
            try queue.append(allocator, .{ .plan = plan, .position = position, .message = output_messages[response_index] });
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            const position: TrackedCallServiceActionOutputPosition = .{ .role = .forward, .local_index = forward_local_index };
            try queue.append(allocator, .{ .plan = plan, .position = position, .message = output_messages[forward_index] });
            forward_index += 1;
            forward_local_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputsToTaggedSink(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcServiceActionUnifiedOutputsToTaggedSinkStats(stats, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputsToTaggedSinkStats(stats: TrackedCallServiceActionStats, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (output_messages[0..stats.actions()], 0..) |message, output_index| {
        try sink_handler(sink_context, trackedCallServiceActionUnifiedOutputPosition(stats, output_index).?, message);
    }
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputsToSinks(
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputsToSinksStats(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
}

pub fn sendRpcServiceActionUnifiedOutputsToSinksStats(
    stats: TrackedCallServiceActionStats,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !RpcOutputStats {
    try stats.validateActionCapacity(output_messages.len);
    for (try stats.outputResponseRange().slice(output_messages)) |message| try response_handler(response_context, message);
    for (try stats.outputForwardRange().slice(output_messages)) |message| try forward_handler(forward_context, message);
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSink(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputPlansToSinkStats(stats, plans, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSinkStats(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);
    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try sink_handler(sink_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try sink_handler(sink_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try sink_handler(sink_context, plan, output_messages[forward_index]);
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSinks(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputPlansToSinksStats(stats, plans, output_messages, response_context, response_handler, forward_context, forward_handler);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToSinksStats(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);
    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try response_handler(response_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try response_handler(response_context, plan, output_messages[response_index]);
            response_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try forward_handler(forward_context, plan, output_messages[forward_index]);
            forward_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToTaggedSink(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !void {
    _ = try sendRpcServiceActionUnifiedOutputPlansToTaggedSinkStats(stats, plans, output_messages, sink_context, sink_handler);
}

pub fn sendRpcServiceActionUnifiedOutputPlansToTaggedSinkStats(
    stats: TrackedCallServiceActionStats,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcOutputStats {
    if (plans.len != stats.actions()) return error.InvalidTransition;
    try stats.validateActionCapacity(output_messages.len);
    var response_index = stats.outputResponseRange().start;
    var forward_index = stats.outputForwardRange().start;
    var response_local_index: usize = 0;
    var forward_local_index: usize = 0;
    for (plans) |plan| switch (plan.action) {
        .dispatch => {
            try sink_handler(sink_context, plan, .{ .role = .response, .local_index = response_local_index }, output_messages[response_index]);
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .unimplemented => {
            try sink_handler(sink_context, plan, .{ .role = .response, .local_index = response_local_index }, output_messages[response_index]);
            response_index += 1;
            response_local_index += 1;
        },
        else => {},
    };
    for (plans) |plan| switch (plan.action) {
        .forward => {
            try sink_handler(sink_context, plan, .{ .role = .forward, .local_index = forward_local_index }, output_messages[forward_index]);
            forward_index += 1;
            forward_local_index += 1;
        },
        else => {},
    };
    return RpcOutputStats.fromServiceActionStats(stats);
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueues(allocator, stats, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSinks(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToTaggedSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputsToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToTaggedQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueues(allocator, stats, plans, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSinks(stats, plans, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToTaggedSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireCallServiceActionPlanUnifiedOutputPlansToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    calls: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireCallServiceActionPlanUnifiedOutputs(state, allocator, calls, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputs(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
) !TrackedCallServiceActionStats {
    const stats = try validateWireMessageServiceActionPlans(messages, plans, entries);
    try stats.validateActionCapacity(output_messages.len);
    return initWireMessageServiceActionPlanOutputs(
        state,
        allocator,
        messages,
        plans,
        try stats.outputResponseRange().slice(output_messages),
        try stats.outputForwardRange().slice(output_messages),
        context,
        entries,
    );
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToQueues(allocator, stats, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToSinks(stats, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputsToTaggedSink(stats, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputsToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputsToTaggedQueue(allocator, stats, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToQueues(allocator, stats, plans, output_messages, response_queue, forward_queue);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToSinks(stats, plans, output_messages, response_context, response_handler, forward_context, forward_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedSink(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    sink_context: anytype,
    sink_handler: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    try sendRpcServiceActionUnifiedOutputPlansToTaggedSink(stats, plans, output_messages, sink_context, sink_handler);
    return stats;
}

pub fn initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedQueue(
    state: *State,
    allocator: std.mem.Allocator,
    messages: anytype,
    plans: []const TrackedCallServiceActionPlan,
    output_messages: anytype,
    context: anytype,
    comptime entries: anytype,
    queue: anytype,
) !TrackedCallServiceActionStats {
    const stats = try initWireMessageServiceActionPlanUnifiedOutputs(state, allocator, messages, plans, output_messages, context, entries);
    _ = try appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(allocator, stats, plans, output_messages, queue);
    return stats;
}

pub fn initForwardedWireCallToResolvedTarget(state: *const State, call: anytype, source_call: anytype) !CallTarget {
    const target = (try state.wireCallTargetTransitiveForwardTarget(source_call)) orelse return error.InvalidTransition;
    try initForwardedWireCall(call, source_call, target);
    return target;
}

pub fn initForwardedWireCallMessageToResolvedTarget(state: *const State, message: anytype, source_call: anytype) !CallTarget {
    const target = (try state.wireCallTargetTransitiveForwardTarget(source_call)) orelse return error.InvalidTransition;
    try initForwardedWireCallMessage(message, source_call, target);
    return target;
}

pub fn initWireCallWithOptions(
    allocator: std.mem.Allocator,
    call: anytype,
    question_id: QuestionId,
    target: CallTarget,
    registry: anytype,
    options: CallOptions,
) !void {
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallParamsCapTable(call, descriptors);
}

fn initWireCallHeaderWithOptions(
    call: anytype,
    question_id: QuestionId,
    target: CallTarget,
    options: CallOptions,
) !void {
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try writeCallOptionsToWire(options, call);
}

pub fn initWireCall(allocator: std.mem.Allocator, call: anytype, question_id: QuestionId, target: CallTarget, registry: anytype) !void {
    try initWireCallWithOptions(allocator, call, question_id, target, registry, .{});
}

pub fn initWireCallMessageWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    registry: anytype,
    options: CallOptions,
) !void {
    try initWireCallWithOptions(allocator, try message.init_call(), question_id, target, registry, options);
}

pub fn initWireCallMessage(allocator: std.mem.Allocator, message: anytype, question_id: QuestionId, target: CallTarget, registry: anytype) !void {
    try initWireCall(allocator, try message.init_call(), question_id, target, registry);
}

pub fn initWireCallMessagePayloadCapability(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsCapability(call, capability_index, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsCapability(call, capability_index, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    if (capability_index >= descriptors.len) return error.InvalidCapabilityPointer;
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessagePayloadCapabilityWithOptions(message, question_id, target, capability_index, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(state, message, question_id, target, capability_index, descriptors, .{});
}

pub fn initWireCallMessagePayloadCapabilityInfo(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsCapabilityInfo(call, capability_index, infos);
}

pub fn initWireCallMessagePayloadCapabilityInfoWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsCapabilityInfo(call, capability_index, infos);
}

pub fn initWireCallMessagePayloadCapabilityInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    if (capability_index >= infos.len) return error.InvalidCapabilityPointer;
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessagePayloadCapabilityInfoWithOptions(message, question_id, target, capability_index, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessagePayloadCapabilityInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessagePayloadCapabilityInfoWithOptionsAndApplyState(state, message, question_id, target, capability_index, infos, .{});
}

pub fn initWireCallMessagePayloadCapabilityFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsCapabilityFromRegistry(allocator, call, capability_index, registry);
}

pub fn initWireCallMessagePayloadCapabilityFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsCapabilityFromRegistry(allocator, call, capability_index, registry);
}

pub fn initWireCallMessagePayloadCapabilityFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(
        state,
        message,
        question_id,
        target,
        capability_index,
        descriptors,
        options,
    );
}

pub fn initWireCallMessagePayloadCapabilityFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    capability_index: u32,
    registry: anytype,
) !void {
    try initWireCallMessagePayloadCapabilityFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, capability_index, registry, .{});
}

pub fn initWireCallMessageStructWith(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsStructWith(call, struct_size, descriptors, context, fill);
}

pub fn initWireCallMessageStructWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsStructWith(call, struct_size, descriptors, context, fill);
}

pub fn initWireCallMessageStructWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);

    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    const params = try call.init_params();
    const content_pointer = try params.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > descriptors.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTable(params, descriptors);

    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageStructWithAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    try initWireCallMessageStructWithOptionsAndApplyState(state, message, question_id, target, struct_size, descriptors, context, fill, .{});
}

pub fn initWireCallMessageStructInfoWith(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsStructInfoWith(call, struct_size, infos, context, fill);
}

pub fn initWireCallMessageStructInfoWithOptions(
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsStructInfoWith(call, struct_size, infos, context, fill);
}

pub fn initWireCallMessageStructInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);

    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    const params = try call.init_params();
    const content_pointer = try params.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > infos.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTableInfo(params, infos);

    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageStructInfoWithAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    try initWireCallMessageStructInfoWithOptionsAndApplyState(state, message, question_id, target, struct_size, infos, context, fill, .{});
}

pub fn initWireCallMessageStructFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsStructFromRegistry(allocator, call, struct_size, registry, context, fill);
}

pub fn initWireCallMessageStructFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsStructFromRegistry(allocator, call, struct_size, registry, context, fill);
}

pub fn initWireCallMessageStructFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageStructWithOptionsAndApplyState(
        state,
        message,
        question_id,
        target,
        struct_size,
        descriptors,
        context,
        fill,
        options,
    );
}

pub fn initWireCallMessageStructFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    try initWireCallMessageStructFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, struct_size, registry, context, fill, .{});
}

pub fn initWireCallMessageText(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, descriptors: []const CapDescriptor) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsText(call, text, descriptors);
}

pub fn initWireCallMessageTextWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, descriptors: []const CapDescriptor, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsText(call, text, descriptors);
}

pub fn initWireCallMessageTextWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessageTextWithOptions(message, question_id, target, text, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageTextAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessageTextWithOptionsAndApplyState(state, message, question_id, target, text, descriptors, .{});
}

pub fn initWireCallMessageData(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, descriptors: []const CapDescriptor) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsData(call, data, descriptors);
}

pub fn initWireCallMessageDataWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, descriptors: []const CapDescriptor, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsData(call, data, descriptors);
}

pub fn initWireCallMessageDataWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessageDataWithOptions(message, question_id, target, data, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageDataAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessageDataWithOptionsAndApplyState(state, message, question_id, target, data, descriptors, .{});
}

pub fn initWireCallMessageUInt32List(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, descriptors: []const CapDescriptor) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsUInt32List(call, values, descriptors);
}

pub fn initWireCallMessageUInt32ListWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, descriptors: []const CapDescriptor, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsUInt32List(call, values, descriptors);
}

pub fn initWireCallMessageUInt32ListWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    descriptors: []const CapDescriptor,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    try initWireCallMessageUInt32ListWithOptions(message, question_id, target, values, descriptors, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageUInt32ListAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    descriptors: []const CapDescriptor,
) !void {
    try initWireCallMessageUInt32ListWithOptionsAndApplyState(state, message, question_id, target, values, descriptors, .{});
}

pub fn initWireCallMessageTextInfo(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, infos: []const CapDescriptorInfo) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsTextInfo(call, text, infos);
}

pub fn initWireCallMessageTextInfoWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, text: []const u8, infos: []const CapDescriptorInfo, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsTextInfo(call, text, infos);
}

pub fn initWireCallMessageTextInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessageTextInfoWithOptions(message, question_id, target, text, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageTextInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessageTextInfoWithOptionsAndApplyState(state, message, question_id, target, text, infos, .{});
}

pub fn initWireCallMessageDataInfo(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, infos: []const CapDescriptorInfo) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsDataInfo(call, data, infos);
}

pub fn initWireCallMessageDataInfoWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, data: []const u8, infos: []const CapDescriptorInfo, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsDataInfo(call, data, infos);
}

pub fn initWireCallMessageDataInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessageDataInfoWithOptions(message, question_id, target, data, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageDataInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessageDataInfoWithOptionsAndApplyState(state, message, question_id, target, data, infos, .{});
}

pub fn initWireCallMessageUInt32ListInfo(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, infos: []const CapDescriptorInfo) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsUInt32ListInfo(call, values, infos);
}

pub fn initWireCallMessageUInt32ListInfoWithOptions(message: anytype, question_id: QuestionId, target: CallTarget, values: []const u32, infos: []const CapDescriptorInfo, options: CallOptions) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsUInt32ListInfo(call, values, infos);
}

pub fn initWireCallMessageUInt32ListInfoWithOptionsAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    infos: []const CapDescriptorInfo,
    options: CallOptions,
) !void {
    try state.validateCallTarget(target);
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    try initWireCallMessageUInt32ListInfoWithOptions(message, question_id, target, values, infos, options);
    try state.openQuestion(question_id, .call);
    try state.trackCallInfo(options.callInfo(question_id, target));
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackParamImports(question_id, descriptors);
}

pub fn initWireCallMessageUInt32ListInfoAndApplyState(
    state: *State,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    infos: []const CapDescriptorInfo,
) !void {
    try initWireCallMessageUInt32ListInfoWithOptionsAndApplyState(state, message, question_id, target, values, infos, .{});
}

pub fn initWireCallMessageTextFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsTextFromRegistry(allocator, call, text, registry);
}

pub fn initWireCallMessageTextFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsTextFromRegistry(allocator, call, text, registry);
}

pub fn initWireCallMessageTextFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageTextWithOptionsAndApplyState(state, message, question_id, target, text, descriptors, options);
}

pub fn initWireCallMessageTextFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    text: []const u8,
    registry: anytype,
) !void {
    try initWireCallMessageTextFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, text, registry, .{});
}

pub fn initWireCallMessageDataFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsDataFromRegistry(allocator, call, data, registry);
}

pub fn initWireCallMessageDataFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsDataFromRegistry(allocator, call, data, registry);
}

pub fn initWireCallMessageDataFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageDataWithOptionsAndApplyState(state, message, question_id, target, data, descriptors, options);
}

pub fn initWireCallMessageDataFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    data: []const u8,
    registry: anytype,
) !void {
    try initWireCallMessageDataFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, data, registry, .{});
}

pub fn initWireCallMessageUInt32ListFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
) !void {
    const call = try message.init_call();
    try call.set_questionId(question_id);
    try writeCallTargetToWire(target, try call.init_target());
    try initWireCallParamsUInt32ListFromRegistry(allocator, call, values, registry);
}

pub fn initWireCallMessageUInt32ListFromRegistryWithOptions(
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const call = try message.init_call();
    try initWireCallHeaderWithOptions(call, question_id, target, options);
    try initWireCallParamsUInt32ListFromRegistry(allocator, call, values, registry);
}

pub fn initWireCallMessageUInt32ListFromRegistryWithOptionsAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
    options: CallOptions,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireCallMessageUInt32ListWithOptionsAndApplyState(state, message, question_id, target, values, descriptors, options);
}

pub fn initWireCallMessageUInt32ListFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    question_id: QuestionId,
    target: CallTarget,
    values: []const u32,
    registry: anytype,
) !void {
    try initWireCallMessageUInt32ListFromRegistryWithOptionsAndApplyState(state, allocator, message, question_id, target, values, registry, .{});
}

pub fn initWireBootstrap(bootstrap: anytype, question_id: QuestionId) !void {
    try bootstrap.set_questionId(question_id);
}

pub fn initWireBootstrapMessage(message: anytype, question_id: QuestionId) !void {
    try initWireBootstrap(try message.init_bootstrap(), question_id);
}

pub fn initWireReturn(
    allocator: std.mem.Allocator,
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    registry: anytype,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnResultsCapTable(return_, descriptors);
}

pub fn initWireReturnAwaitFromThirdParty(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try return_.set_awaitFromThirdParty_capability(capability_index);
}

fn applyInitializedNonResultReturnState(
    state: *State,
    answer_id: AnswerId,
    release_param_caps: bool,
) !void {
    if (release_param_caps) try state.validateParamImports(answer_id);
    try state.resolveAnswer(answer_id, .return_);
    try state.trackResultImports(answer_id, &.{});
    if (release_param_caps) try state.releaseParamImports(answer_id);
}

pub fn initWireReturnAwaitFromThirdPartyMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
) !void {
    try initWireReturnAwaitFromThirdParty(try message.init_return_(), answer_id, release_param_caps, no_finish_needed, capability_index);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnExceptionMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    exception: ExceptionInfo,
) !void {
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnException(try message.init_return_(), answer_id, release_param_caps, no_finish_needed, exception);
    try state.resolveAnswer(answer_id, .return_);
    try state.trackResultImports(answer_id, &.{});
    if (release_param_caps) try state.releaseParamImports(answer_id);
}

pub fn initWireReturnCanceled(return_: anytype, answer_id: AnswerId, release_param_caps: bool) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_canceled();
}

pub fn initWireReturnCanceledMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
) !void {
    try initWireReturnCanceled(try message.init_return_(), answer_id, release_param_caps);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnResultsSentElsewhere(return_: anytype, answer_id: AnswerId, release_param_caps: bool) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_resultsSentElsewhere();
}

pub fn initWireReturnResultsSentElsewhereMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
) !void {
    try initWireReturnResultsSentElsewhere(try message.init_return_(), answer_id, release_param_caps);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnTakeFromOtherQuestion(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    other_question_id: QuestionId,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_takeFromOtherQuestion(other_question_id);
}

pub fn initWireReturnTakeFromOtherQuestionMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    other_question_id: QuestionId,
) !void {
    if (!state.answers.contains(other_question_id)) return error.QuestionNotOpen;
    try initWireReturnTakeFromOtherQuestion(try message.init_return_(), answer_id, release_param_caps, other_question_id);
    try applyInitializedNonResultReturnState(state, answer_id, release_param_caps);
}

pub fn initWireReturnMessage(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    registry: anytype,
) !void {
    try initWireReturn(allocator, try message.init_return_(), answer_id, release_param_caps, no_finish_needed, registry);
}

pub fn initWireReturnMessagePayloadCapability(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsCapability(return_, capability_index, descriptors);
}

pub fn initWireReturnMessagePayloadCapabilityAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    if (capability_index >= descriptors.len) return error.InvalidCapabilityPointer;
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessagePayloadCapability(message, answer_id, release_param_caps, no_finish_needed, capability_index, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessagePayloadCapabilityInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsCapabilityInfo(return_, capability_index, infos);
}

pub fn initWireReturnMessagePayloadCapabilityInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    infos: []const CapDescriptorInfo,
) !void {
    if (capability_index >= infos.len) return error.InvalidCapabilityPointer;
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessagePayloadCapabilityInfo(message, answer_id, release_param_caps, no_finish_needed, capability_index, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessagePayloadCapabilityFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsCapabilityFromRegistry(allocator, return_, capability_index, registry);
}

pub fn initWireReturnMessagePayloadCapabilityFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    capability_index: u32,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessagePayloadCapabilityAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        capability_index,
        descriptors,
    );
}

pub fn initWireReturnMessageStructWith(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsStructWith(return_, struct_size, descriptors, context, fill);
}

pub fn initWireReturnMessageStructWithAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);

    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const results = try return_.init_results();
    const content_pointer = try results.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > descriptors.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTable(results, descriptors);

    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageStructInfoWith(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsStructInfoWith(return_, struct_size, infos, context, fill);
}

pub fn initWireReturnMessageStructInfoWithAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);

    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const results = try return_.init_results();
    const content_pointer = try results.get_contentAsPointer();
    const content = try content_pointer.initStruct(struct_size);
    try fill(context, content);
    if ((try content.validate()).maxCapabilityCount() > infos.len) return error.InvalidCapabilityPointer;
    try initWirePayloadCapTableInfo(results, infos);

    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageStructFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsStructFromRegistry(allocator, return_, struct_size, registry, context, fill);
}

pub fn initWireReturnMessageStructFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageStructWithAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        struct_size,
        descriptors,
        context,
        fill,
    );
}

pub fn initWireReturnMessageText(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsText(return_, text, descriptors);
}

pub fn initWireReturnMessageTextAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageText(message, answer_id, release_param_caps, no_finish_needed, text, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageData(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsData(return_, data, descriptors);
}

pub fn initWireReturnMessageDataAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    descriptors: []const CapDescriptor,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageData(message, answer_id, release_param_caps, no_finish_needed, data, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageUInt32List(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    descriptors: []const CapDescriptor,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsUInt32List(return_, values, descriptors);
}

pub fn initWireReturnMessageUInt32ListAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    descriptors: []const CapDescriptor,
) !void {
    for (descriptors) |descriptor| try state.validateCapDescriptor(descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageUInt32List(message, answer_id, release_param_caps, no_finish_needed, values, descriptors);
    try state.resolveAnswer(answer_id, .return_);
    for (descriptors) |descriptor| try state.applyCapDescriptor(descriptor);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and descriptors.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageTextInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsTextInfo(return_, text, infos);
}

pub fn initWireReturnMessageTextInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageTextInfo(message, answer_id, release_param_caps, no_finish_needed, text, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageDataInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsDataInfo(return_, data, infos);
}

pub fn initWireReturnMessageDataInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    infos: []const CapDescriptorInfo,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageDataInfo(message, answer_id, release_param_caps, no_finish_needed, data, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageUInt32ListInfo(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    infos: []const CapDescriptorInfo,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsUInt32ListInfo(return_, values, infos);
}

pub fn initWireReturnMessageUInt32ListInfoAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    infos: []const CapDescriptorInfo,
) !void {
    for (infos) |info| try state.validateCapDescriptor(info.descriptor);
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initWireReturnMessageUInt32ListInfo(message, answer_id, release_param_caps, no_finish_needed, values, infos);
    try state.resolveAnswer(answer_id, .return_);
    for (infos) |info| try state.applyCapDescriptor(info.descriptor);
    const descriptors = try capDescriptorsFromInfosAlloc(state.allocator, infos);
    defer state.allocator.free(descriptors);
    try state.trackResultImports(answer_id, descriptors);
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed and infos.len == 0) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initWireReturnMessageTextFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsTextFromRegistry(allocator, return_, text, registry);
}

pub fn initWireReturnMessageTextFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    text: []const u8,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageTextAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        text,
        descriptors,
    );
}

pub fn initWireReturnMessageDataFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsDataFromRegistry(allocator, return_, data, registry);
}

pub fn initWireReturnMessageDataFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    data: []const u8,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageDataAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        data,
        descriptors,
    );
}

pub fn initWireReturnMessageUInt32ListFromRegistry(
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    registry: anytype,
) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    try initWireReturnResultsUInt32ListFromRegistry(allocator, return_, values, registry);
}

pub fn initWireReturnMessageUInt32ListFromRegistryAndApplyState(
    state: *State,
    allocator: std.mem.Allocator,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    values: []const u32,
    registry: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWireReturnMessageUInt32ListAndApplyState(
        state,
        message,
        answer_id,
        release_param_caps,
        no_finish_needed,
        values,
        descriptors,
    );
}

pub fn joinResultCapabilityFromWireReturn(return_: anytype) !?u32 {
    const outcome = try returnOutcomeFromWireReturn(return_);
    if (outcome != .results) return null;
    return payloadContentCapabilityIndex(try return_.results());
}

pub fn initWireJoinResultReturn(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try initWireReturnResultsCapability(return_, capability_index, descriptors);
}

pub fn initWireJoinResultReturnMessage(
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    capability_index: u32,
    descriptors: []const CapDescriptor,
) !void {
    try initWireJoinResultReturn(try message.init_return_(), answer_id, release_param_caps, capability_index, descriptors);
}

pub fn initCapabilityReturnMessage(message: anytype, answer_id: AnswerId, export_id: ExportId) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try initWirePayloadCapability(try return_.init_results(), 0, &.{.{ .sender_hosted = export_id }});
}

pub fn initEmptyReturnMessage(message: anytype, answer_id: AnswerId, release_param_caps: bool, no_finish_needed: bool) !void {
    const return_ = try message.init_return_();
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    _ = try return_.init_results();
}

pub fn initEmptyReturnMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
) !void {
    if (release_param_caps) try state.validateParamImports(answer_id);
    try initEmptyReturnMessage(message, answer_id, release_param_caps, no_finish_needed);
    try state.resolveAnswer(answer_id, .return_);
    try state.trackResultImports(answer_id, &.{});
    if (release_param_caps) try state.releaseParamImports(answer_id);
    if (no_finish_needed) {
        try state.finishQuestion(answer_id);
    }
}

pub fn initDispatchReturnMessage(message: anytype, answer_id: AnswerId, result: DispatchResult) !void {
    return switch (result) {
        .empty => initEmptyReturnMessage(message, answer_id, true, true),
        .capability => |export_id| initCapabilityReturnMessage(message, answer_id, export_id),
        .text => |text| initWireReturnMessageText(message, answer_id, true, false, text, &.{}),
        .data => |data| initWireReturnMessageData(message, answer_id, true, false, data, &.{}),
        .uint32_list => |values| initWireReturnMessageUInt32List(message, answer_id, true, false, values, &.{}),
        .exception => |exception| initWireReturnException(try message.init_return_(), answer_id, true, false, exception),
        .canceled => initWireReturnCanceled(try message.init_return_(), answer_id, true),
        .results_sent_elsewhere => initWireReturnResultsSentElsewhere(try message.init_return_(), answer_id, true),
        .take_from_other_question => |question_id| initWireReturnTakeFromOtherQuestion(try message.init_return_(), answer_id, true, question_id),
        .await_from_third_party => |capability_index| initWireReturnAwaitFromThirdParty(try message.init_return_(), answer_id, true, false, capability_index),
    };
}

pub fn initDispatchReturnMessageAndApplyState(
    state: *State,
    message: anytype,
    answer_id: AnswerId,
    result: DispatchResult,
) !void {
    return switch (result) {
        .empty => initEmptyReturnMessageAndApplyState(state, message, answer_id, true, true),
        .capability => |export_id| initWireReturnMessagePayloadCapabilityAndApplyState(
            state,
            message,
            answer_id,
            true,
            false,
            0,
            &.{.{ .sender_hosted = export_id }},
        ),
        .text => |text| initWireReturnMessageTextAndApplyState(state, message, answer_id, true, false, text, &.{}),
        .data => |data| initWireReturnMessageDataAndApplyState(state, message, answer_id, true, false, data, &.{}),
        .uint32_list => |values| initWireReturnMessageUInt32ListAndApplyState(state, message, answer_id, true, false, values, &.{}),
        .exception => |exception| initWireReturnExceptionMessageAndApplyState(state, message, answer_id, true, false, exception),
        .canceled => initWireReturnCanceledMessageAndApplyState(state, message, answer_id, true),
        .results_sent_elsewhere => initWireReturnResultsSentElsewhereMessageAndApplyState(state, message, answer_id, true),
        .take_from_other_question => |question_id| initWireReturnTakeFromOtherQuestionMessageAndApplyState(state, message, answer_id, true, question_id),
        .await_from_third_party => |capability_index| initWireReturnAwaitFromThirdPartyMessageAndApplyState(state, message, answer_id, true, false, capability_index),
    };
}

pub fn initBootstrapReturnMessage(message: anytype, answer_id: AnswerId, export_id: ExportId) !void {
    try initCapabilityReturnMessage(message, answer_id, export_id);
}

pub fn initBootstrapReturnForRequest(message: anytype, bootstrap: anytype, export_id: ExportId) !void {
    try initBootstrapReturnMessage(message, bootstrap.questionId(), export_id);
}

pub fn dispatchBootstrap(
    state: *State,
    response_message: anytype,
    bootstrap: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireEvent(.{ .bootstrap = bootstrap.questionId() });
    const export_id = try handler(context, bootstrap);
    try initBootstrapReturnForRequest(response_message, bootstrap, export_id);
}

pub fn dispatchCallReturningCapability(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const export_id = try handler(context, call);
    try initCapabilityReturnMessage(response_message, call.questionId(), export_id);
}

pub fn dispatchCallReturningCapabilityForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningCapability(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningEmpty(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    try handler(context, call);
    try initEmptyReturnMessage(response_message, call.questionId(), true, true);
}

pub fn dispatchCallReturningEmptyForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningEmpty(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningText(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageText(response_message, call.questionId(), true, false, text, &.{});
}

pub fn dispatchCallReturningData(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageData(response_message, call.questionId(), true, false, data, &.{});
}

pub fn dispatchCallReturningUInt32List(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32List(response_message, call.questionId(), true, false, values, &.{});
}

pub fn dispatchCallReturningTextInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageTextInfo(response_message, call.questionId(), true, false, text, infos);
}

pub fn dispatchCallReturningDataInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageDataInfo(response_message, call.questionId(), true, false, data, infos);
}

pub fn dispatchCallReturningUInt32ListInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListInfo(response_message, call.questionId(), true, false, values, infos);
}

pub fn dispatchCallReturningTextFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageTextFromRegistry(allocator, response_message, call.questionId(), true, false, text, registry);
}

pub fn dispatchCallReturningTextForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageText(response_message, call.questionId(), true, false, text, descriptors);
    return .response_initialized;
}

pub fn dispatchCallReturningTextInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const text = try handler(context, call);
    try initWireReturnMessageTextInfo(response_message, call.questionId(), true, false, text, infos);
    return .response_initialized;
}

pub fn dispatchCallReturningTextFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningTextForwardingOutcome(state, allocator, response_message, forward_message, call, descriptors, context, handler);
}

pub fn dispatchCallReturningDataFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageDataFromRegistry(allocator, response_message, call.questionId(), true, false, data, registry);
}

pub fn dispatchCallReturningDataForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageData(response_message, call.questionId(), true, false, data, descriptors);
    return .response_initialized;
}

pub fn dispatchCallReturningDataInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const data = try handler(context, call);
    try initWireReturnMessageDataInfo(response_message, call.questionId(), true, false, data, infos);
    return .response_initialized;
}

pub fn dispatchCallReturningDataFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningDataForwardingOutcome(state, allocator, response_message, forward_message, call, descriptors, context, handler);
}

pub fn dispatchCallReturningUInt32ListFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListFromRegistry(allocator, response_message, call.questionId(), true, false, values, registry);
}

pub fn dispatchCallReturningUInt32ListForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32List(response_message, call.questionId(), true, false, values, descriptors);
    return .response_initialized;
}

pub fn dispatchCallReturningUInt32ListInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try state.applyWireCall(allocator, call);
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListInfo(response_message, call.questionId(), true, false, values, infos);
    return .response_initialized;
}

pub fn dispatchCallReturningUInt32ListFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningUInt32ListForwardingOutcome(state, allocator, response_message, forward_message, call, descriptors, context, handler);
}

pub fn dispatchCallReturningStructWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTable(results, descriptors);
}

pub fn dispatchCallReturningStructInfoWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTableInfo(results, infos);
}

pub fn dispatchCallReturningStructFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallReturningStructWith(state, allocator, response_message, call, struct_size, descriptors, context, handler);
}

pub fn dispatchCallReturningStructForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningStructWith(state, allocator, response_message, call, struct_size, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningStructInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallReturningStructInfoWith(state, allocator, response_message, call, struct_size, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallReturningStructFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallReturningStructForwardingOutcome(state, allocator, response_message, forward_message, call, struct_size, descriptors, context, handler);
}

pub fn dispatchCall(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    const result = try handler(context, call);
    try initDispatchReturnMessage(response_message, call.questionId(), result);
}

pub fn dispatchCallOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    // Keep this check before invoking the application handler. A resolved
    // imported promise is not a local service target anymore; treating it as
    // local would duplicate work that should be forwarded to the replacement
    // capability once a transport loop exists.
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCall(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCall(state, allocator, response_message, call, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethod(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const result = try handler(context, call);
    try initDispatchReturnMessage(response_message, call.questionId(), result);
}

pub fn dispatchCallMethodReturningCapability(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const export_id = try handler(context, call);
    try initCapabilityReturnMessage(response_message, call.questionId(), export_id);
}

pub fn dispatchCallMethodReturningEmpty(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    try handler(context, call);
    try initEmptyReturnMessage(response_message, call.questionId(), true, true);
}

pub fn dispatchCallMethodReturningText(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const text = try handler(context, call);
    try initWireReturnMessageText(response_message, call.questionId(), true, false, text, descriptors);
}

pub fn dispatchCallMethodReturningTextInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const text = try handler(context, call);
    try initWireReturnMessageTextInfo(response_message, call.questionId(), true, false, text, infos);
}

pub fn dispatchCallMethodReturningTextFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningText(state, allocator, response_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningTextOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningText(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningTextForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningText(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningTextInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningTextInfo(state, allocator, response_message, call, expected_method, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningTextFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningTextForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningData(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const data = try handler(context, call);
    try initWireReturnMessageData(response_message, call.questionId(), true, false, data, descriptors);
}

pub fn dispatchCallMethodReturningDataInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const data = try handler(context, call);
    try initWireReturnMessageDataInfo(response_message, call.questionId(), true, false, data, infos);
}

pub fn dispatchCallMethodReturningDataFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningData(state, allocator, response_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningDataOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningData(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningDataForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningData(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningDataInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningDataInfo(state, allocator, response_message, call, expected_method, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningDataFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningDataForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningUInt32List(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const values = try handler(context, call);
    try initWireReturnMessageUInt32List(response_message, call.questionId(), true, false, values, descriptors);
}

pub fn dispatchCallMethodReturningUInt32ListInfo(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const values = try handler(context, call);
    try initWireReturnMessageUInt32ListInfo(response_message, call.questionId(), true, false, values, infos);
}

pub fn dispatchCallMethodReturningUInt32ListFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningUInt32List(state, allocator, response_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningUInt32ListOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningUInt32List(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningUInt32ListForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningUInt32List(state, allocator, response_message, call, expected_method, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningUInt32ListInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningUInt32ListInfo(state, allocator, response_message, call, expected_method, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningUInt32ListFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningUInt32ListForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningStructWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTable(results, descriptors);
}

pub fn dispatchCallMethodReturningStructInfoWith(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !void {
    try state.applyWireCall(allocator, call);
    if (!callMethodFromWireCall(call).matches(expected_method.interface_id, expected_method.method_id)) {
        try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
            .reason = "unimplemented method",
            .type_raw = 3,
        });
        return;
    }
    const return_ = try response_message.init_return_();
    try return_.set_answerId(call.questionId());
    try return_.set_releaseParamCaps(true);
    try return_.set_noFinishNeeded(false);
    const results = try return_.init_results();
    const content = try (try results.get_contentAsPointer()).initStruct(struct_size);
    try handler(context, call, content);
    try initWirePayloadCapTableInfo(results, infos);
}

pub fn dispatchCallMethodReturningStructFromRegistry(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try dispatchCallMethodReturningStructWith(state, allocator, response_message, call, expected_method, struct_size, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningStructOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningStructWith(state, allocator, response_message, call, expected_method, struct_size, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningStructForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningStructWith(state, allocator, response_message, call, expected_method, struct_size, descriptors, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningStructInfoForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningStructInfoWith(state, allocator, response_message, call, expected_method, struct_size, infos, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningStructFromRegistryForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    return dispatchCallMethodReturningStructForwardingOutcome(state, allocator, response_message, forward_message, call, expected_method, struct_size, descriptors, context, handler);
}

pub fn dispatchCallMethodReturningCapabilityOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningCapability(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningCapabilityForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningCapability(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningEmptyOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningEmpty(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodReturningEmptyForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    try state.validateWireCallTarget(call);
    if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethodReturningEmpty(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethod(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn dispatchCallMethodForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    expected_method: CallMethod,
    context: anytype,
    handler: anytype,
) !WireDispatchOutcome {
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethod(state, allocator, response_message, call, expected_method, context, handler);
    return .response_initialized;
}

pub fn wireCallMethodEntryIndex(call: anytype, comptime entries: anytype) Error!?usize {
    return callMethodEntryIndex(callMethodFromWireCall(call), entries);
}

pub fn wireMessageMethodEntryIndex(message: anytype, comptime entries: anytype) !?usize {
    const method = (try callMethodFromWireMessage(message)) orelse return null;
    return try callMethodEntryIndex(method, entries);
}

pub fn dispatchCallMethods(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !void {
    try validateCallMethodEntries(entries);
    inline for (entries) |entry| {
        if (entry.method.matchesWireCall(call)) {
            try dispatchCallMethod(state, allocator, response_message, call, entry.method, context, entry.handler);
            return;
        }
    }

    try state.applyWireCall(allocator, call);
    try initWireReturnException(try response_message.init_return_(), call.questionId(), true, false, .{
        .reason = "unimplemented method",
        .type_raw = 3,
    });
}

pub fn dispatchCallMethodsOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !WireDispatchOutcome {
    try validateCallMethodEntries(entries);
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        return .forward_required;
    }
    try dispatchCallMethods(state, allocator, response_message, call, context, entries);
    return .response_initialized;
}

pub fn dispatchCallMethodsForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    call: anytype,
    context: anytype,
    comptime entries: anytype,
) !WireDispatchOutcome {
    try validateCallMethodEntries(entries);
    const dispatch_info = try state.wireCallDispatchInfo(call);
    if (dispatch_info.needsForward()) {
        try state.applyWireCall(allocator, call);
        _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_message, call);
        return .forward_required;
    }
    try dispatchCallMethods(state, allocator, response_message, call, context, entries);
    return .response_initialized;
}

pub fn planWireMessageDispatch(state: *const State, request_message: anytype) !WireDispatchOutcome {
    switch (try wireMessageTag(request_message)) {
        .bootstrap => return .response_initialized,
        .call => {
            return try state.wireCallDispatchOutcome(try request_message.call());
        },
        else => return .state_applied,
    }
}

pub fn planWireMessagesDispatch(state: *const State, request_messages: anytype) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    for (request_messages) |request_message| {
        stats.record(try planWireMessageDispatch(state, request_message));
    }
    return stats;
}

pub fn planWireMessageMethodsDispatch(state: *const State, request_message: anytype, comptime call_entries: anytype) !WireDispatchOutcome {
    try validateCallMethodEntries(call_entries);
    return planWireMessageDispatch(state, request_message);
}

pub fn planWireMessagesMethodsDispatch(state: *const State, request_messages: anytype, comptime call_entries: anytype) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    for (request_messages) |request_message| {
        stats.record(try planWireMessageDispatch(state, request_message));
    }
    return stats;
}

pub fn planRpcTurn(state: *const State, request_messages: anytype) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesDispatch(state, request_messages),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoCount(),
    };
}

pub fn planRpcTurnMethods(state: *const State, request_messages: anytype, comptime call_entries: anytype) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesMethodsDispatch(state, request_messages, call_entries),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoCount(),
    };
}

pub fn planRpcTurnForAcceptEmbargo(state: *const State, request_messages: anytype, embargo: []const u8) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesDispatch(state, request_messages),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo),
    };
}

pub fn planRpcTurnMethodsForAcceptEmbargo(state: *const State, request_messages: anytype, comptime call_entries: anytype, embargo: []const u8) !RpcTurnPlan {
    return .{
        .dispatch = try planWireMessagesMethodsDispatch(state, request_messages, call_entries),
        .handoff_returns = state.readyHandoffReturnStats(),
        .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo),
    };
}

pub fn dispatchWireMessageOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallOutcome(state, allocator, response_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

fn applyStateWireMessageWithHandler(
    state: *State,
    allocator: std.mem.Allocator,
    request_message: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !void {
    var result = try state.applyWireMessageAlloc(allocator, request_message);
    defer result.deinit(allocator);
    try apply_handler(apply_context, result);
}

/// Variant of `dispatchWireMessageOutcome` for runtimes that need to observe
/// state-only apply details (for example released Accept IDs from Disembargo).
/// The callback receives a borrowed `WireMessageApplyResult`; copy any owned
/// slices before returning because dispatch deinitializes the result afterwards.
pub fn dispatchWireMessageOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallOutcome(state, allocator, response_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessage(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !bool {
    return (try dispatchWireMessageOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    )) == .response_initialized;
}

fn sendResponseMessageIfNeeded(outcome: WireDispatchOutcome, response_context: anytype, response_handler: anytype, response_message: anytype) !void {
    if (outcome == .response_initialized) {
        try response_handler(response_context, response_message);
    }
}

pub fn dispatchWireMessageToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessageForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

fn sendForwardedMessageIfNeeded(outcome: WireDispatchOutcome, forward_context: anytype, forward_handler: anytype, forward_message: anytype) !void {
    if (outcome == .forward_required) {
        try forward_handler(forward_context, forward_message);
    }
}

pub fn ignoreInitializedMessage(_: void, _: anytype) !void {}

pub fn dispatchWireMessageForwardingToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageForwardingToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageForwardingToSinksOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageForwardingOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_handler);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageForwardingToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageForwardingToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageForwardingToSinksOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsOutcome(state, allocator, response_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcome(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsOutcome(state, allocator, response_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try state.applyWireMessage(allocator, request_message);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsForwardingToSinkOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToQueueOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToSinksOutcome(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcome(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    switch (try eventFromWireMessage(request_message)) {
        .bootstrap => {
            try dispatchBootstrap(state, response_message, try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
            return .response_initialized;
        },
        .call => {
            return dispatchCallMethodsForwardingOutcome(state, allocator, response_message, forward_message, try request_message.call(), call_context, call_entries);
        },
        else => {
            try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
            return .state_applied;
        },
    }
}

pub fn dispatchWireMessageMethodsForwardingToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    if (outcome == .forward_required) {
        try queue.append(allocator, forward_message);
    }
    return outcome;
}

pub fn dispatchWireMessageMethodsForwardingToSinksOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    forward_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        forward_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    try sendForwardedMessageIfNeeded(outcome, forward_context, forward_handler, forward_message);
    return outcome;
}

pub fn dispatchWireMessages(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessageToSinkOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    try sendResponseMessageIfNeeded(outcome, response_context, response_handler, response_message);
    return outcome;
}

pub fn dispatchWireMessageToQueueOutcomeWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_message: anytype,
    request_message: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchOutcome {
    const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
        state,
        allocator,
        response_message,
        request_message,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    if (outcome == .response_initialized) {
        try queue.append(allocator, response_message);
    }
    return outcome;
}

pub fn dispatchWireMessagesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesToDenseSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesToDenseSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesToDenseSink(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchWireMessagesDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesDense(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesToDenseSinkWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwarding(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinksOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageForwardingToSinksOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_handler,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToDenseSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCall(state, allocator, response_messages[response_index], call, call_context, call_handler);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDense(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesForwardingDense(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingUnifiedDense(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingUnifiedDenseWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingUnifiedDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesDispatch(state, request_messages);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesForwardingDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        {},
        ignoreInitializedMessage,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesForwardingDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

fn appliedRpcTurnPlan(state: *const State, dispatch: WireDispatchStats, handoff_returns: StateHandoffReturnStats) RpcTurnPlan {
    return .{
        .dispatch = dispatch,
        .handoff_returns = handoff_returns,
        // Dispatch can apply Accept or Disembargo messages before ready handoff
        // returns are materialized.  Report the pending queue after those state
        // transitions so the caller can immediately size or drain the follow-up
        // Disembargo output without recomputing a separate turn plan.
        .pending_disembargos = state.pendingAcceptEmbargoCount(),
    };
}

fn dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
    comptime method_dispatch: bool,
    comptime observe_apply: bool,
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_dispatch: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const ForwardedCall = struct {
        request_index: usize,
        target: CallTarget,
    };

    if (method_dispatch) try validateCallMethodEntries(call_dispatch);

    var dispatch_stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forwarded_calls = std.ArrayList(ForwardedCall).empty;
    defer forwarded_calls.deinit(allocator);

    for (request_messages, 0..) |request_message, request_index| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= output_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, output_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                response_index += 1;
                dispatch_stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if (try state.wireCallTargetTransitiveForwardTarget(call)) |target| {
                    try state.applyWireCall(allocator, call);
                    try forwarded_calls.append(allocator, .{ .request_index = request_index, .target = target });
                    dispatch_stats.recordForwardRequired();
                } else {
                    if (response_index >= output_messages.len) return error.InvalidTransition;
                    if (method_dispatch) {
                        try dispatchCallMethods(state, allocator, output_messages[response_index], call, call_context, call_dispatch);
                    } else {
                        try dispatchCall(state, allocator, output_messages[response_index], call, call_context, call_dispatch);
                    }
                    response_index += 1;
                    dispatch_stats.recordResponseInitialized();
                }
            },
            else => {
                if (observe_apply) {
                    try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                } else {
                    try state.applyWireMessage(allocator, request_message);
                }
                dispatch_stats.recordStateApplied();
            },
        }
    }

    const ready_handoffs = state.readyHandoffReturnStats();
    if (output_messages.len < response_index + ready_handoffs.total() + forwarded_calls.items.len) return error.InvalidTransition;
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        output_messages[response_index..][0..ready_handoffs.total()],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );

    var forward_index = response_index + handoff_stats.total();
    for (forwarded_calls.items) |forwarded_call| {
        try initForwardedWireCallMessage(
            output_messages[forward_index],
            try request_messages[forwarded_call.request_index].call(),
            forwarded_call.target,
        );
        forward_index += 1;
    }

    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingToDenseSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingToDenseSinks(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        false,
        false,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchRpcTurnForwardingUnifiedDenseToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        false,
        true,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchRpcTurnForwardingUnifiedDenseToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnForwardingDenseToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    call_handler: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_handler,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingToDenseSinks(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        true,
        false,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    return dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
        true,
        true,
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..turn_plan.totalOutputMessages()]) |message| {
        try queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    turn_plan.pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo);
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        try turn_plan.disembargoMessageRange().slice(output_messages),
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan, output_messages, sink_context, sink_handler);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToTaggedQueue(allocator, turn_plan, output_messages, queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    _ = try appendRpcTurnUnifiedOutputsToQueues(allocator, turn_plan, output_messages, response_queue, forward_queue, disembargo_queue);
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    try sendRpcTurnUnifiedOutputsToSinks(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlers(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        response_context,
        response_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const dispatch_stats = try dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    const handoff_stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        response_messages[dispatch_stats.response_initialized..],
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
    return appliedRpcTurnPlan(state, dispatch_stats, handoff_stats);
}

pub fn dispatchRpcTurnMethodsForwardingDenseToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessages(
        disembargo_messages,
        disembargo_target,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargo(
        disembargo_messages,
        disembargo_target,
        embargo,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    const turn_plan = try dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        disembargo_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        disembargo_target,
        embargo,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..turn_plan.responseMessages()]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..turn_plan.forwardedMessages()]) |message| {
        try forward_queue.append(allocator, message);
    }
    for (disembargo_messages[0..turn_plan.disembargoMessages()]) |message| {
        try disembargo_queue.append(allocator, message);
    }
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    try turn_plan.validateDisembargoCapacity(disembargo_messages.len);
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesToSink(
        disembargo_messages,
        disembargo_target,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    disembargo_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
    disembargo_target: CallTarget,
    embargo: []const u8,
    disembargo_context: anytype,
    disembargo_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !RpcTurnPlan {
    var turn_plan = try dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
        apply_context,
        apply_handler,
    );
    const pending_matches = state.pendingAcceptEmbargoMatchCount(embargo);
    if (disembargo_messages.len < pending_matches) return error.InvalidTransition;
    turn_plan.pending_disembargos = try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(
        disembargo_messages,
        disembargo_target,
        embargo,
        disembargo_context,
        disembargo_handler,
    );
    return turn_plan;
}

pub fn dispatchRpcTurnPendingAcceptDisembargosToSink(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
    sink_context: anytype,
    sink_handler: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoCount() };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesToSink(message_builders, target, sink_context, sink_handler);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosToQueue(
    state: *const State,
    allocator: std.mem.Allocator,
    message_builders: anytype,
    target: CallTarget,
    queue: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoCount() };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesToQueue(allocator, message_builders, target, queue);
}

pub fn dispatchRpcTurnPendingAcceptDisembargos(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoCount() };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessages(message_builders, target);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosForEmbargoToSink(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
    embargo: []const u8,
    sink_context: anytype,
    sink_handler: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo) };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesForEmbargoToSink(message_builders, target, embargo, sink_context, sink_handler);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosForEmbargoToQueue(
    state: *const State,
    allocator: std.mem.Allocator,
    message_builders: anytype,
    target: CallTarget,
    embargo: []const u8,
    queue: anytype,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo) };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesForEmbargoToQueue(allocator, message_builders, target, embargo, queue);
}

pub fn dispatchRpcTurnPendingAcceptDisembargosForEmbargo(
    state: *const State,
    message_builders: anytype,
    target: CallTarget,
    embargo: []const u8,
) !usize {
    const plan: RpcTurnPlan = .{ .pending_disembargos = state.pendingAcceptEmbargoMatchCount(embargo) };
    try plan.validateDisembargoCapacity(message_builders.len);
    return state.initPendingAcceptDisembargoMessagesForEmbargo(message_builders, target, embargo);
}

pub fn dispatchWireMessagesMethods(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcome(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try queue.append(allocator, response_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToDenseSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsToDenseSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    try state.applyWireCall(allocator, call);
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesMethodsToDenseSink(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        {},
        ignoreInitializedMessage,
    );
}

pub fn dispatchWireMessagesMethodsDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsDense(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesMethodsToDenseSinkWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesMethodsDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinksOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToDenseSinks(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                try response_handler(response_context, response_messages[response_index]);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    try forward_handler(forward_context, forward_messages[forward_index]);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    try response_handler(response_context, response_messages[response_index]);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try applyStateWireMessageWithHandler(state, allocator, request_message, apply_context, apply_handler);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingDense(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    try validateCallMethodEntries(call_entries);
    var stats: WireDispatchStats = .{};
    var response_index: usize = 0;
    var forward_index: usize = 0;
    for (request_messages) |request_message| {
        switch (try eventFromWireMessage(request_message)) {
            .bootstrap => {
                if (response_index >= response_messages.len) return error.InvalidTransition;
                try dispatchBootstrap(state, response_messages[response_index], try request_message.bootstrap(), bootstrap_context, bootstrap_handler);
                response_index += 1;
                stats.recordResponseInitialized();
            },
            .call => {
                const call = try request_message.call();
                try state.validateWireCallTarget(call);
                if ((try state.wireCallTargetTransitiveForwardTarget(call)) != null) {
                    if (forward_index >= forward_messages.len) return error.InvalidTransition;
                    try state.applyWireCall(allocator, call);
                    _ = try initForwardedWireCallMessageToResolvedTarget(state, forward_messages[forward_index], call);
                    forward_index += 1;
                    stats.recordForwardRequired();
                } else {
                    if (response_index >= response_messages.len) return error.InvalidTransition;
                    try dispatchCallMethods(state, allocator, response_messages[response_index], call, call_context, call_entries);
                    response_index += 1;
                    stats.recordResponseInitialized();
                }
            },
            else => {
                try state.applyWireMessage(allocator, request_message);
                stats.recordStateApplied();
            },
        }
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDense(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingUnifiedDense(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesMethodsForwardingDense(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    return dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        try planned.denseResponseRange().slice(output_messages),
        try planned.denseForwardRange().slice(output_messages),
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingUnifiedDenseWithApplyHandler(
        state,
        allocator,
        output_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (output_messages[0..stats.denseOutputSlots()]) |message| {
        try queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingUnifiedDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    output_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const planned = try planWireMessagesMethodsDispatch(state, request_messages, call_entries);
    try planned.validateUnifiedDenseOutputBuilders(output_messages);
    const response_messages = try planned.denseResponseRange().slice(output_messages);
    const forward_messages = try planned.denseForwardRange().slice(output_messages);
    const stats = try dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    return dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        {},
        ignoreInitializedMessage,
        {},
        ignoreInitializedMessage,
        apply_context,
        apply_handler,
    );
}

pub fn dispatchWireMessagesMethodsForwardingDenseToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    const stats = try dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        state,
        allocator,
        response_messages,
        forward_messages,
        request_messages,
        bootstrap_context,
        bootstrap_handler,
        call_context,
        call_entries,
        apply_context,
        apply_handler,
    );
    for (response_messages[0..stats.response_initialized]) |message| {
        try response_queue.append(allocator, message);
    }
    for (forward_messages[0..stats.forward_required]) |message| {
        try forward_queue.append(allocator, message);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwarding(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingWithOutcomeHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSink(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinkOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            forward_context,
            forward_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueue(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueues(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcome(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSinkWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinkOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueueWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        if (outcome == .forward_required) {
            try queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingWithOutcomeHandlerAndApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    outcome_context: anytype,
    outcome_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        try outcome_handler(outcome_context, index, outcome);
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToQueuesWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            apply_context,
            apply_handler,
        );
        if (outcome == .response_initialized) {
            try response_queue.append(allocator, response_messages[index]);
        } else if (outcome == .forward_required) {
            try forward_queue.append(allocator, forward_messages[index]);
        }
        stats.record(outcome);
    }
    return stats;
}

pub fn dispatchWireMessagesMethodsForwardingToSinksWithApplyHandler(
    state: *State,
    allocator: std.mem.Allocator,
    response_messages: anytype,
    forward_messages: anytype,
    request_messages: anytype,
    bootstrap_context: anytype,
    bootstrap_handler: anytype,
    call_context: anytype,
    comptime call_entries: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    apply_context: anytype,
    apply_handler: anytype,
) !WireDispatchStats {
    if (response_messages.len < request_messages.len or forward_messages.len < request_messages.len) return error.InvalidTransition;
    var stats: WireDispatchStats = .{};
    for (request_messages, 0..) |request_message, index| {
        const outcome = try dispatchWireMessageMethodsForwardingToSinksOutcomeWithApplyHandler(
            state,
            allocator,
            response_messages[index],
            forward_messages[index],
            request_message,
            bootstrap_context,
            bootstrap_handler,
            call_context,
            call_entries,
            response_context,
            response_handler,
            forward_context,
            forward_handler,
            apply_context,
            apply_handler,
        );
        stats.record(outcome);
    }
    return stats;
}

pub fn initWireHandoffReturnMessage(message: anytype, completion: HandoffReturn) !void {
    switch (completion) {
        .provide => |value| try initCapabilityReturnMessage(message, value.question_id, value.export_id),
        .accept => |value| try initCapabilityReturnMessage(message, value.question_id, value.export_id),
        .join => |value| try initWireJoinResultReturnMessage(message, value.question_id, true, 0, &.{.{ .sender_hosted = value.export_id }}),
    }
}

pub fn initWireHandoffReturnMessages(response_messages: anytype, completions: []const HandoffReturn) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToSink(
    response_messages: anytype,
    completions: []const HandoffReturn,
    sink_context: anytype,
    sink_handler: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try sink_handler(sink_context, response_messages[index]);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToTaggedSink(
    response_messages: anytype,
    completions: []const HandoffReturn,
    sink_context: anytype,
    sink_handler: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        const position = stats.nextPosition(completion);
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try sink_handler(sink_context, position, response_messages[index]);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToQueue(
    allocator: std.mem.Allocator,
    response_messages: anytype,
    completions: []const HandoffReturn,
    queue: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try queue.append(allocator, response_messages[index]);
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToTaggedQueue(
    allocator: std.mem.Allocator,
    response_messages: anytype,
    completions: []const HandoffReturn,
    queue: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        const position = stats.nextPosition(completion);
        try initWireHandoffReturnMessage(response_messages[index], completion);
        try queue.append(allocator, .{ .position = position, .message = response_messages[index] });
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToSinks(
    response_messages: anytype,
    completions: []const HandoffReturn,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        switch (completion) {
            .provide => try provide_handler(provide_context, response_messages[index]),
            .accept => try accept_handler(accept_context, response_messages[index]),
            .join => try join_handler(join_context, response_messages[index]),
        }
        stats.record(completion);
    }
    return stats;
}

pub fn initWireHandoffReturnMessagesToQueues(
    allocator: std.mem.Allocator,
    response_messages: anytype,
    completions: []const HandoffReturn,
    provide_queue: anytype,
    accept_queue: anytype,
    join_queue: anytype,
) !StateHandoffReturnStats {
    if (response_messages.len < completions.len) return error.InvalidTransition;
    var stats: StateHandoffReturnStats = .{};
    for (completions, 0..) |completion, index| {
        try initWireHandoffReturnMessage(response_messages[index], completion);
        switch (completion) {
            .provide => try provide_queue.append(allocator, response_messages[index]),
            .accept => try accept_queue.append(allocator, response_messages[index]),
            .join => try join_queue.append(allocator, response_messages[index]),
        }
        stats.record(completion);
    }
    return stats;
}

pub fn initWireFinish(finish: anytype, value: Finish) !void {
    try finish.set_questionId(value.question_id);
    try finish.set_releaseResultCaps(value.release_result_caps);
}

pub fn initWireFinishMessage(message: anytype, value: Finish) !void {
    try initWireFinish(try message.init_finish(), value);
}

pub fn initWireRelease(release: anytype, value: CapabilityRelease) !void {
    try release.set_id(value.id);
    try release.set_referenceCount(value.reference_count);
}

pub fn initWireReleaseMessage(message: anytype, value: CapabilityRelease) !void {
    try initWireRelease(try message.init_release(), value);
}

pub fn initWireCallParamsCapTable(call: anytype, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapTable(try call.init_params(), descriptors);
}

pub fn initWireCallParamsCapTableInfo(call: anytype, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapTableInfo(try call.init_params(), infos);
}

pub fn initWireCallParamsCapability(call: anytype, capability_index: u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapability(try call.init_params(), capability_index, descriptors);
}

pub fn initWireCallParamsCapabilityInfo(call: anytype, capability_index: u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapabilityInfo(try call.init_params(), capability_index, infos);
}

pub fn initWireCallParamsCapabilityFromRegistry(allocator: std.mem.Allocator, call: anytype, capability_index: u32, registry: anytype) !void {
    try initWirePayloadCapabilityFromRegistry(allocator, try call.init_params(), capability_index, registry);
}

pub fn initWireCallParamsStructWith(
    call: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructWith(try call.init_params(), struct_size, descriptors, context, fill);
}

pub fn initWireCallParamsStructInfoWith(
    call: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructInfoWith(try call.init_params(), struct_size, infos, context, fill);
}

pub fn initWireCallParamsStructFromRegistry(
    allocator: std.mem.Allocator,
    call: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructFromRegistry(allocator, try call.init_params(), struct_size, registry, context, fill);
}

pub fn initWireCallParamsText(call: anytype, text: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadText(try call.init_params(), text, descriptors);
}

pub fn initWireCallParamsData(call: anytype, data: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadData(try call.init_params(), data, descriptors);
}

pub fn initWireCallParamsUInt32List(call: anytype, values: []const u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadUInt32List(try call.init_params(), values, descriptors);
}

pub fn initWireCallParamsTextInfo(call: anytype, text: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadTextInfo(try call.init_params(), text, infos);
}

pub fn initWireCallParamsDataInfo(call: anytype, data: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadDataInfo(try call.init_params(), data, infos);
}

pub fn initWireCallParamsUInt32ListInfo(call: anytype, values: []const u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadUInt32ListInfo(try call.init_params(), values, infos);
}

pub fn initWireCallParamsTextFromRegistry(allocator: std.mem.Allocator, call: anytype, text: []const u8, registry: anytype) !void {
    try initWirePayloadTextFromRegistry(allocator, try call.init_params(), text, registry);
}

pub fn initWireCallParamsDataFromRegistry(allocator: std.mem.Allocator, call: anytype, data: []const u8, registry: anytype) !void {
    try initWirePayloadDataFromRegistry(allocator, try call.init_params(), data, registry);
}

pub fn initWireCallParamsUInt32ListFromRegistry(allocator: std.mem.Allocator, call: anytype, values: []const u32, registry: anytype) !void {
    try initWirePayloadUInt32ListFromRegistry(allocator, try call.init_params(), values, registry);
}

pub fn initWireReturnResultsCapTable(return_: anytype, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapTable(try return_.init_results(), descriptors);
}

pub fn initWireReturnResultsCapTableInfo(return_: anytype, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapTableInfo(try return_.init_results(), infos);
}

pub fn initWireReturnResultsCapability(return_: anytype, capability_index: u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadCapability(try return_.init_results(), capability_index, descriptors);
}

pub fn initWireReturnResultsCapabilityInfo(return_: anytype, capability_index: u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadCapabilityInfo(try return_.init_results(), capability_index, infos);
}

pub fn initWireReturnResultsCapabilityFromRegistry(allocator: std.mem.Allocator, return_: anytype, capability_index: u32, registry: anytype) !void {
    try initWirePayloadCapabilityFromRegistry(allocator, try return_.init_results(), capability_index, registry);
}

pub fn initWireReturnResultsStructWith(
    return_: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructWith(try return_.init_results(), struct_size, descriptors, context, fill);
}

pub fn initWireReturnResultsStructInfoWith(
    return_: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructInfoWith(try return_.init_results(), struct_size, infos, context, fill);
}

pub fn initWireReturnResultsStructFromRegistry(
    allocator: std.mem.Allocator,
    return_: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    try initWirePayloadStructFromRegistry(allocator, try return_.init_results(), struct_size, registry, context, fill);
}

pub fn initWireReturnResultsText(return_: anytype, text: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadText(try return_.init_results(), text, descriptors);
}

pub fn initWireReturnResultsData(return_: anytype, data: []const u8, descriptors: []const CapDescriptor) !void {
    try initWirePayloadData(try return_.init_results(), data, descriptors);
}

pub fn initWireReturnResultsUInt32List(return_: anytype, values: []const u32, descriptors: []const CapDescriptor) !void {
    try initWirePayloadUInt32List(try return_.init_results(), values, descriptors);
}

pub fn initWireReturnResultsTextInfo(return_: anytype, text: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadTextInfo(try return_.init_results(), text, infos);
}

pub fn initWireReturnResultsDataInfo(return_: anytype, data: []const u8, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadDataInfo(try return_.init_results(), data, infos);
}

pub fn initWireReturnResultsUInt32ListInfo(return_: anytype, values: []const u32, infos: []const CapDescriptorInfo) !void {
    try initWirePayloadUInt32ListInfo(try return_.init_results(), values, infos);
}

pub fn initWireReturnResultsTextFromRegistry(allocator: std.mem.Allocator, return_: anytype, text: []const u8, registry: anytype) !void {
    try initWirePayloadTextFromRegistry(allocator, try return_.init_results(), text, registry);
}

pub fn initWireReturnResultsDataFromRegistry(allocator: std.mem.Allocator, return_: anytype, data: []const u8, registry: anytype) !void {
    try initWirePayloadDataFromRegistry(allocator, try return_.init_results(), data, registry);
}

pub fn initWireReturnResultsUInt32ListFromRegistry(allocator: std.mem.Allocator, return_: anytype, values: []const u32, registry: anytype) !void {
    try initWirePayloadUInt32ListFromRegistry(allocator, try return_.init_results(), values, registry);
}

pub fn capTableFromWirePayload(allocator: std.mem.Allocator, payload: anytype) ![]CapDescriptor {
    const cap_table = payload.capTable() catch |err| switch (err) {
        error.NullPointer => return allocator.alloc(CapDescriptor, 0),
        else => return err,
    };
    const descriptors = try allocator.alloc(CapDescriptor, cap_table.len());
    errdefer allocator.free(descriptors);
    for (descriptors, 0..) |*descriptor, index| {
        descriptor.* = try capDescriptorFromWire(try cap_table.get(index));
    }
    return descriptors;
}

pub fn capTableInfoFromWirePayload(allocator: std.mem.Allocator, payload: anytype) ![]CapDescriptorInfo {
    const cap_table = payload.capTable() catch |err| switch (err) {
        error.NullPointer => return allocator.alloc(CapDescriptorInfo, 0),
        else => return err,
    };
    const infos = try allocator.alloc(CapDescriptorInfo, cap_table.len());
    errdefer allocator.free(infos);
    for (infos, 0..) |*info, index| {
        info.* = try capDescriptorInfoFromWire(try cap_table.get(index));
    }
    return infos;
}

pub fn capTableFromWireCallParams(allocator: std.mem.Allocator, call: anytype) ![]CapDescriptor {
    return capTableFromWirePayload(allocator, try call.params());
}

pub fn capTableInfoFromWireCallParams(allocator: std.mem.Allocator, call: anytype) ![]CapDescriptorInfo {
    return capTableInfoFromWirePayload(allocator, try call.params());
}

pub fn capTableFromWireReturnResults(allocator: std.mem.Allocator, return_: anytype) ![]CapDescriptor {
    return capTableFromWirePayload(allocator, try return_.results());
}

pub fn capTableInfoFromWireReturnResults(allocator: std.mem.Allocator, return_: anytype) ![]CapDescriptorInfo {
    return capTableInfoFromWirePayload(allocator, try return_.results());
}

pub fn payloadContentCapabilityIndex(payload: anytype) !?u32 {
    return (try payload.content()).getCapabilityIndex() catch |err| switch (err) {
        error.InvalidPointerKind, error.NullPointer => null,
        else => return err,
    };
}

pub fn writeAbortInfoToWire(info: ExceptionInfo, abort: anytype) !void {
    try writeExceptionInfoToWire(info, abort);
}

pub fn initWireAbortMessage(message: anytype, info: ExceptionInfo) !void {
    try writeAbortInfoToWire(info, try message.init_abort());
}

pub fn initWireUnimplementedMessage(message: anytype) !void {
    _ = try message.init_unimplemented();
}

pub fn initWireUnimplementedMessageFrom(message: anytype, original: anytype) !void {
    try message.set_unimplemented_from(original);
}

pub fn initWireUnimplementedMessageFromBuilder(message: anytype, original: anytype) !void {
    try message.set_unimplemented_fromBuilder(original);
}

pub fn initWireObsoleteSaveMessage(message: anytype) !void {
    try message.set_obsoleteSave();
}

pub fn initWireObsoleteDeleteMessage(message: anytype) !void {
    try message.set_obsoleteDelete();
}

pub fn returnOutcomeFromWireReturn(return_: anytype) !ReturnOutcome {
    return switch (return_.which() orelse return error.InvalidTransition) {
        .results => .results,
        .exception => .{ .exception = try exceptionInfoFromWireException(try return_.exception()) },
        .canceled => .canceled,
        .resultsSentElsewhere => .results_sent_elsewhere,
        .takeFromOtherQuestion => .{ .take_from_other_question = try return_.takeFromOtherQuestion() },
        .awaitFromThirdParty => .{ .await_from_third_party = try anyPointerUsageFromWire(try return_.awaitFromThirdPartyAsPointer()) },
    };
}

pub fn capDescriptorImportIdsAlloc(allocator: std.mem.Allocator, descriptors: []const CapDescriptor) std.mem.Allocator.Error![]ImportId {
    var count: usize = 0;
    for (descriptors) |descriptor| switch (descriptor) {
        .sender_hosted, .sender_promise, .third_party_hosted => count += 1,
        else => {},
    };

    const ids = try allocator.alloc(ImportId, count);
    var index: usize = 0;
    for (descriptors) |descriptor| switch (descriptor) {
        .sender_hosted, .sender_promise, .third_party_hosted => |id| {
            ids[index] = id;
            index += 1;
        },
        else => {},
    };
    return ids;
}

pub fn validateWirePayloadContent(payload: anytype, cap_count: usize) !void {
    const content = try payload.content();
    _ = try content.validateWithOptions(.{ .capability_count_limit = cap_count });
}

pub fn validateWirePayload(allocator: std.mem.Allocator, payload: anytype) !void {
    const descriptors = try capTableFromWirePayload(allocator, payload);
    defer allocator.free(descriptors);
    try validateWirePayloadContent(payload, descriptors.len);
}

pub fn unimplementedMessageTag(message: anytype) !?WireMessageTag {
    if ((try wireMessageTag(message)) != .unimplemented) return null;
    return try wireMessageTag(try message.unimplemented());
}

pub fn eventFromWireUnimplementedMessage(message: anytype) !?WireEvent {
    if ((try wireMessageTag(message)) != .unimplemented) return null;
    return try eventFromWireMessage(try message.unimplemented());
}

pub fn eventFromWireMessage(message: anytype) !WireEvent {
    return switch (try wireMessageTag(message)) {
        .unimplemented => .{ .unimplemented = try wireMessageTag(try message.unimplemented()) },
        .abort => .{ .abort = try exceptionInfoFromWireException(try message.abort()) },
        .bootstrap => .{ .bootstrap = (try message.bootstrap()).questionId() },
        .call => .{ .call = (try message.call()).questionId() },
        .return_ => blk: {
            const return_ = try message.return_();
            break :blk .{ .return_ = .{
                .answer_id = return_.answerId(),
                .release_param_caps = return_.releaseParamCaps(),
                .no_finish_needed = return_.noFinishNeeded(),
            } };
        },
        .finish => blk: {
            const finish = try message.finish();
            break :blk .{ .finish = .{ .question_id = finish.questionId(), .release_result_caps = finish.releaseResultCaps() } };
        },
        .resolve => .{ .resolve = (try message.resolve()).promiseId() },
        .release => blk: {
            const release = try message.release();
            break :blk .{ .release = .{ .id = release.id(), .reference_count = release.referenceCount() } };
        },
        .disembargo => .{ .disembargo = try disembargoInfoFromWireDisembargo(try message.disembargo()) },
        .obsolete_save => .{ .obsolete_save = {} },
        .obsolete_delete => .{ .obsolete_delete = {} },
        .provide => .{ .provide = (try message.provide()).questionId() },
        .accept => .{ .accept = (try message.accept()).questionId() },
        .third_party_answer => .{ .third_party_answer = (try message.thirdPartyAnswer()).answerId() },
        .join => .{ .join = (try message.join()).questionId() },
    };
}

test "rpc message kind predicates describe state-machine roles" {
    const testing = std.testing;
    try testing.expect(MessageKind.bootstrap.isQuestionOpening());
    try testing.expect(MessageKind.call.isQuestionOpening());
    try testing.expect(MessageKind.finish.isQuestionClosing());
    try testing.expect(MessageKind.return_.isAnswerResolving());
    try testing.expect(MessageKind.resolve.isAnswerResolving());
    try testing.expect(MessageKind.release.isCapabilityTableMutation());
    try testing.expect(!MessageKind.disembargo.isQuestionOpening());

    const call_event = Event{ .call = 12 };
    try testing.expectEqual(MessageKind.call, call_event.kind());
    try testing.expectEqual(@as(?QuestionId, 12), call_event.questionId());
    try testing.expectEqual(@as(?AnswerId, null), call_event.answerId());
    try testing.expect(call_event.isQuestionOpening());
    try testing.expect(!call_event.isAnswerResolving());
    const return_event = Event{ .return_ = 12 };
    try testing.expectEqual(MessageKind.return_, return_event.kind());
    try testing.expectEqual(@as(?AnswerId, 12), return_event.answerId());
    try testing.expect(return_event.isAnswerResolving());
    try testing.expect(!return_event.isQuestionClosing());

    const provide_event = Event{ .provide = 5 };
    try testing.expectEqual(MessageKind.provide, provide_event.kind());
    const provide_ref = provide_event.capabilityRef().?;
    try testing.expectEqual(CapabilityRef{ .export_id = 5 }, provide_ref);
    try testing.expect(provide_ref.isExport());
    try testing.expect(!provide_ref.isImport());
    try testing.expectEqual(@as(?ExportId, 5), provide_ref.exportId());
    try testing.expectEqual(@as(?ImportId, null), provide_ref.importId());
    try testing.expect(provide_ref.matchesExport(5));
    try testing.expect(!provide_ref.matchesImport(5));
    try testing.expect(provide_event.isCapabilityTableMutation());
    const accept_event = Event{ .accept = 6 };
    const accept_ref = accept_event.capabilityRef().?;
    try testing.expectEqual(CapabilityRef{ .import_id = 6 }, accept_ref);
    try testing.expect(accept_ref.isImport());
    try testing.expect(!accept_ref.isExport());
    try testing.expectEqual(@as(?ImportId, 6), accept_ref.importId());
    try testing.expectEqual(@as(?ExportId, null), accept_ref.exportId());
    try testing.expect(accept_ref.matchesImport(6));
    try testing.expect(!accept_ref.matchesExport(6));

    var stats: WireDispatchStats = .{};
    stats.recordResponseInitialized();
    stats.recordForwardRequired();
    stats.recordStateApplied();
    try testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try testing.expectEqual(@as(usize, 1), stats.forward_required);
    try testing.expectEqual(@as(usize, 1), stats.state_applied);
    try testing.expectEqual(@as(usize, 3), stats.total());
    try testing.expect(stats.initializedAnyResponse());
    try testing.expect(stats.requiredAnyForward());
    try testing.expect(stats.appliedAnyState());
    try testing.expect(stats.hasDenseResponses());
    try testing.expect(stats.hasDenseForwards());
    try testing.expect(stats.hasDenseOutputs());

    const forward_range = OutputRange{ .start = 2, .end = 5 };
    try testing.expectEqual(@as(usize, 3), forward_range.len());
    try testing.expectEqual(@as(?usize, 0), forward_range.localIndex(2));
    try testing.expectEqual(@as(?usize, 2), forward_range.localIndex(4));
    try testing.expect(forward_range.localIndex(5) == null);
}

test "rpc wire events expose classification and id helpers" {
    const testing = std.testing;

    const bootstrap = WireEvent{ .bootstrap = 12 };
    try testing.expectEqual(WireMessageTag.bootstrap, bootstrap.tag());
    try testing.expect(bootstrap.isStateApplicable());
    try testing.expect(bootstrap.isQuestionOpening());
    try testing.expect(!bootstrap.isQuestionClosing());
    try testing.expectEqual(@as(?QuestionId, 12), bootstrap.questionId());

    const return_event = WireEvent{ .return_ = .{ .answer_id = 13, .release_param_caps = true, .no_finish_needed = false } };
    try testing.expect(return_event.isAnswerResolving());
    try testing.expectEqual(@as(?AnswerId, 13), return_event.answerId());
    try testing.expect(return_event.return_.releasesParamCaps());
    try testing.expect(return_event.return_.needsFinish());

    const exception = ExceptionInfo{ .reason = "failed", .type_raw = @intFromEnum(ExceptionType.failed), .trace = "" };
    try testing.expectEqual(ExceptionType.failed, exception.exceptionType().?);
    try testing.expect(exception.isFailed());
    try testing.expect(exception.matchesType(.failed));
    try testing.expect(!exception.isOverloaded());
    try testing.expect((ExceptionInfo{ .reason = null, .type_raw = 999 }).exceptionType() == null);

    const third_party_answer = WireEvent{ .third_party_answer = 18 };
    try testing.expect(third_party_answer.isStateApplicable());
    try testing.expect(third_party_answer.isAnswerResolving());
    try testing.expect(third_party_answer.toStateEvent() == null);
    try testing.expectEqual(@as(?AnswerId, 18), third_party_answer.answerId());

    const release_event = WireEvent{ .release = .{ .id = 14, .reference_count = 3 } };
    try testing.expect(release_event.isCapabilityRelease());
    try testing.expectEqual(@as(?ImportId, 14), release_event.importId());
    try testing.expectEqual(@as(?u32, 3), release_event.releaseReferenceCount());
    try testing.expect(release_event.release.hasReferences());
    try testing.expect(!release_event.release.isSingleReference());
    try testing.expectEqual(@as(?ExportId, null), release_event.exportId());

    const resolve_event = WireEvent{ .resolve = 15 };
    try testing.expect(resolve_event.isStateApplicable());
    try testing.expect(resolve_event.toStateEvent() == null);
    try testing.expectEqual(@as(?ExportId, 15), resolve_event.exportId());

    const provide_event = WireEvent{ .provide = 16 };
    try testing.expect(provide_event.isStateApplicable());
    try testing.expect(provide_event.isQuestionOpening());
    try testing.expect(provide_event.toStateEvent() == null);
    try testing.expectEqual(@as(?QuestionId, 16), provide_event.questionId());

    const join_event = WireEvent{ .join = 17 };
    try testing.expect(join_event.isStateApplicable());
    try testing.expect(join_event.isQuestionOpening());
    try testing.expect(join_event.toStateEvent() == null);
    try testing.expectEqual(@as(?QuestionId, 17), join_event.questionId());

    const disembargo_event = WireEvent{ .disembargo = .{
        .target = .{ .imported_cap = 19 },
        .context = .{ .sender_loopback = 20 },
    } };
    try testing.expect(disembargo_event.isStateApplicable());
    try testing.expect(!disembargo_event.isQuestionOpening());
    try testing.expect(disembargo_event.toStateEvent() == null);
    try testing.expectEqual(DisembargoContext{ .sender_loopback = 20 }, disembargo_event.disembargo.context);
}

test "rpc question and answer trackers reject invalid transitions" {
    const testing = std.testing;

    var question = QuestionTracker{ .id = 7 };
    try testing.expect(question.state.isIdle());
    try testing.expect(question.isIdle());
    try testing.expect(question.canSend(.call));
    try question.open(.call);
    try testing.expect(question.state.isOpen());
    try testing.expect(question.isOpen());
    try testing.expect(!question.canSend(.bootstrap));
    try testing.expectError(error.QuestionAlreadyOpen, question.open(.bootstrap));
    try question.finish();
    try testing.expect(question.state.isFinished());
    try testing.expect(question.isFinished());
    try testing.expectError(error.QuestionNotOpen, question.finish());

    var answer = AnswerTracker{ .id = 9 };
    try testing.expect(answer.state.isUnresolved());
    try testing.expect(answer.isUnresolved());
    try answer.resolve(.return_);
    try testing.expect(answer.state.isResolved());
    try testing.expect(answer.isResolved());
    try testing.expectError(error.AnswerAlreadyResolved, answer.resolve(.resolve));
    try testing.expectError(error.InvalidTransition, answer.resolve(.call));

    var accept = AcceptTracker{
        .question_id = 10,
        .has_provision = true,
        .provision = .{ .max_capability_count = 3, .capability = 2 },
        .embargo = "embargo-10",
    };
    try testing.expect(accept.hasProvisionUsage());
    try testing.expect(accept.provisionMatchesCapability(2));
    try testing.expect(!accept.provisionMatchesCapability(1));
    try testing.expect(accept.hasEmbargo());
    try testing.expect(accept.matchesEmbargo("embargo-10"));
    try testing.expect(!accept.ready());
    accept.embargo_released = true;
    try testing.expect(accept.ready());

    const provide = ProvideTracker{
        .question_id = 11,
        .target = .{ .imported_cap = 12 },
        .has_recipient = true,
        .recipient = .{ .max_capability_count = 2, .capability = 1 },
    };
    try testing.expect(provide.hasRecipientUsage());
    try testing.expect(provide.recipientMatchesCapability(1));
    try testing.expect(!provide.recipientMatchesCapability(0));
    try testing.expect(provide.targetsImport(12));

    const join = JoinTracker{
        .question_id = 13,
        .target = .{ .promised_answer = .{ .question_id = 14 } },
        .has_key_part = true,
        .key_part = .{ .max_capability_count = 5, .capability = 4 },
    };
    try testing.expect(join.hasKeyPartUsage());
    try testing.expect(join.keyPartMatchesCapability(4));
    try testing.expect(!join.keyPartMatchesCapability(3));
    try testing.expect(join.targetsPromisedQuestion(14));
}

test "rpc capability trackers reject double release" {
    const testing = std.testing;

    var export_tracker = ExportTracker{ .id = 1 };
    try testing.expect(export_tracker.isLive());
    try testing.expect(!export_tracker.isResolved());
    try export_tracker.resolveTo(.{ .sender_hosted = 99 });
    try testing.expect(export_tracker.isResolved());
    try testing.expect(export_tracker.hasResolution());
    try export_tracker.release();
    try testing.expect(!export_tracker.isLive());
    try testing.expect(export_tracker.state.isReleased());
    try testing.expect(export_tracker.isReleased());
    try testing.expectError(error.ExportAlreadyReleased, export_tracker.release());

    var import_tracker = ImportTracker{ .id = 2 };
    try testing.expect(import_tracker.state.isLive());
    try import_tracker.release();
    try testing.expect(import_tracker.state.isReleased());
    try testing.expect(import_tracker.isReleased());
    try testing.expectError(error.ImportAlreadyReleased, import_tracker.release());
}

test "rpc state tracks in-flight questions and answers" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectEqual(@as(usize, 0), state.questionCount());
    try state.openQuestion(1, .call);
    try testing.expect(state.hasQuestion(1));
    try testing.expect(state.hasAnswer(1));
    try testing.expectEqual(@as(usize, 1), state.questionCount());
    try testing.expectEqual(@as(usize, 1), state.answerCount());
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(1));
    try testing.expectEqual(@as(?MessageKind, .call), state.questionKind(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));
    try testing.expectEqual(StateQuestionStats{
        .questions = 1,
        .open_questions = 1,
        .answers = 1,
        .unresolved_answers = 1,
    }, state.questionStats());
    try testing.expectEqual(@as(usize, 2), state.questionStats().active());
    try testing.expectEqual(@as(usize, 2), state.questionStats().total());
    try testing.expect(state.questionStats().hasEntries());
    try testing.expect(!state.questionStats().isEmpty());
    try testing.expect((StateQuestionStats{}).isEmpty());
    try testing.expect(!(StateQuestionStats{}).hasEntries());
    try testing.expect(state.questionStats().hasQuestions());
    try testing.expect(state.questionStats().hasAnswers());
    try testing.expect(state.questionStats().hasOpenQuestions());
    try testing.expect(state.questionStats().hasUnresolvedAnswers());
    try testing.expect(state.questionStats().hasActive());
    try testing.expect(!state.questionStats().hasCompleteQuestions());

    try testing.expectError(error.QuestionAlreadyOpen, state.openQuestion(1, .bootstrap));
    try testing.expectError(error.InvalidTransition, state.openQuestion(2, .finish));
    try state.finishQuestion(1);
    try testing.expectEqual(@as(?QuestionState, .finished), state.questionState(1));
    try testing.expectError(error.QuestionNotOpen, state.finishQuestion(99));
    try testing.expect(!state.questionComplete(1));
    try testing.expect(!state.canReuseQuestionId(1));
    try testing.expectError(error.AnswerAlreadyResolved, state.openQuestion(1, .call));

    try state.resolveAnswer(1, .return_);
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(1));
    try testing.expectEqual(@as(?MessageKind, .return_), state.answerKind(1));
    try testing.expect(state.answerComplete(1));
    try testing.expectError(error.AnswerAlreadyResolved, state.resolveAnswer(1, .resolve));
    try testing.expectError(error.QuestionNotOpen, state.resolveAnswer(99, .return_));

    try testing.expect(state.questionComplete(1));
    try testing.expect(state.questionReadyToForget(1));
    try testing.expect(state.canReuseQuestionId(1));
    try testing.expectEqual(StateQuestionStats{
        .questions = 1,
        .finished_questions = 1,
        .answers = 1,
        .resolved_answers = 1,
        .complete_questions = 1,
    }, state.questionStats());
    try testing.expect(!state.questionStats().hasActive());
    try testing.expect(state.questionStats().hasFinishedQuestions());
    try testing.expect(state.questionStats().hasResolvedAnswers());
    try testing.expect(state.questionStats().hasCompleteQuestions());
    try state.forgetQuestion(1);
    try testing.expect(!state.hasQuestion(1));
    try testing.expect(!state.hasAnswer(1));
    try testing.expectEqual(@as(usize, 0), state.questionCount());
    try testing.expectEqual(@as(usize, 0), state.answerCount());
    try testing.expectError(error.QuestionNotOpen, state.forgetQuestion(1));
    try state.openQuestion(1, .bootstrap);
    try testing.expectEqual(@as(usize, 1), state.questionCount());
    try testing.expectEqual(@as(usize, 1), state.answerCount());
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(1));
    try testing.expectEqual(@as(?MessageKind, .bootstrap), state.questionKind(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));
    try testing.expectEqual(@as(?MessageKind, null), state.answerKind(1));
    try testing.expect(!state.answerComplete(1));
    try testing.expect(!state.questionReadyToForget(1));
    try testing.expect(!state.canReuseQuestionId(1));

    try state.openQuestion(2, .call);
    try state.finishQuestion(2);
    try state.resolveAnswer(2, .return_);
    try state.openQuestion(3, .call);
    try state.finishQuestion(3);
    try state.resolveAnswer(3, .return_);
    try state.openQuestion(4, .call);
    try testing.expectEqual(@as(usize, 2), state.forgetCompletedQuestions());
    try testing.expect(!state.hasQuestion(2));
    try testing.expect(!state.hasAnswer(2));
    try testing.expect(!state.hasQuestion(3));
    try testing.expect(!state.hasAnswer(3));
    try testing.expect(state.hasQuestion(1));
    try testing.expect(state.hasQuestion(4));
    try testing.expectEqual(@as(usize, 0), state.forgetCompletedQuestions());
}

test "rpc state tracks import and export lifetimes" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectEqual(@as(usize, 0), state.exportCount());
    try testing.expectEqual(@as(usize, 0), state.importCount());

    try state.addExport(10);
    try state.addImport(20);
    try testing.expect(state.hasExport(10));
    try testing.expect(state.hasImport(20));
    try testing.expectEqual(@as(usize, 1), state.exportCount());
    try testing.expectEqual(@as(usize, 1), state.importCount());
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(10));
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(20));
    try testing.expectEqual(StateCapabilityStats{
        .exports = 1,
        .live_exports = 1,
        .imports = 1,
        .live_imports = 1,
        .import_references = 1,
    }, state.capabilityStats());
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().live());
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().total());
    try testing.expect(state.capabilityStats().hasCapabilities());
    try testing.expect(!state.capabilityStats().isEmpty());
    try testing.expect((StateCapabilityStats{}).isEmpty());
    try testing.expect(!(StateCapabilityStats{}).hasCapabilities());
    try testing.expect(state.capabilityStats().hasExports());
    try testing.expect(state.capabilityStats().hasImports());
    try testing.expect(state.capabilityStats().hasLive());
    try testing.expect(state.capabilityStats().hasImportReferences());
    try testing.expect(!state.capabilityStats().hasReleased());

    try testing.expectError(error.InvalidTransition, state.addExport(10));
    try testing.expectError(error.InvalidTransition, state.addImport(20));
    try testing.expectError(error.InvalidTransition, state.releaseExport(99));
    try testing.expectError(error.InvalidTransition, state.releaseImport(99));

    try state.releaseExport(10);
    try state.releaseImport(20);
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.exportState(10));
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(20));
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().released());
    try testing.expect(state.capabilityStats().hasReleased());
    try testing.expectError(error.ExportAlreadyReleased, state.releaseExport(10));
    try testing.expectError(error.ImportAlreadyReleased, state.releaseImport(20));
    try state.forgetReleasedExport(10);
    try state.forgetReleasedImport(20);
    try testing.expect(!state.hasExport(10));
    try testing.expect(!state.hasImport(20));
    try testing.expectError(error.InvalidTransition, state.forgetReleasedExport(10));
    try testing.expectError(error.InvalidTransition, state.forgetReleasedImport(20));

    try state.addExport(11);
    try state.addExport(12);
    try state.addImport(21);
    try state.addImport(22);
    try state.releaseExport(11);
    try state.releaseImport(21);
    try state.resolveExportTo(12, null);
    try state.resolveImportTo(22, null);
    try testing.expectEqual(@as(usize, 2), state.capabilityStats().resolved());
    try testing.expect(state.capabilityStats().hasResolved());
    const removed = state.forgetReleasedCapabilities();
    try testing.expectEqual(@as(usize, 1), removed.exports);
    try testing.expectEqual(@as(usize, 1), removed.imports);
    try testing.expect(!state.hasExport(11));
    try testing.expect(state.hasExport(12));
    try testing.expect(!state.hasImport(21));
    try testing.expect(state.hasImport(22));
    try testing.expectEqual(@as(usize, 0), state.forgetReleasedExports());
    try testing.expectEqual(@as(usize, 0), state.forgetReleasedImports());
}

test "rpc state cleanup forgets completed and released entries" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.openQuestion(100, .call);
    try state.finishQuestion(100);
    try state.resolveAnswer(100, .return_);
    try state.openQuestion(101, .call);
    try state.addExport(200);
    try state.addImport(300);
    try state.releaseExport(200);
    try state.releaseImport(300);

    const cleaned = state.cleanup();
    try testing.expectEqual(@as(usize, 1), cleaned.questions);
    try testing.expectEqual(@as(usize, 1), cleaned.exports);
    try testing.expectEqual(@as(usize, 1), cleaned.imports);
    try testing.expectEqual(@as(usize, 3), cleaned.total());
    try testing.expect(cleaned.hasWork());
    try testing.expect(!cleaned.isEmpty());
    try testing.expect(cleaned.hasQuestionWork());
    try testing.expect(cleaned.hasExportWork());
    try testing.expect(cleaned.hasImportWork());
    try testing.expect(cleaned.hasCapabilityWork());
    try testing.expect(!state.hasQuestion(100));
    try testing.expect(state.hasQuestion(101));
    try testing.expect(!state.hasExport(200));
    try testing.expect(!state.hasImport(300));
    const clean_again = state.cleanup();
    try testing.expectEqual(@as(usize, 0), clean_again.total());
    try testing.expect(!clean_again.hasWork());
    try testing.expect(clean_again.isEmpty());
    try testing.expect(!clean_again.hasQuestionWork());
    try testing.expect(!clean_again.hasExportWork());
    try testing.expect(!clean_again.hasImportWork());
    try testing.expect(!clean_again.hasCapabilityWork());
}

test "rpc state applies capability descriptors to table lifetimes" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    const none_descriptor: CapDescriptor = .none;
    try testing.expect(none_descriptor.isNone());
    try testing.expect(!none_descriptor.isForwardableToCallTarget());
    try testing.expectEqual(@as(?ExportId, null), none_descriptor.exportedId());
    try testing.expectEqual(@as(?ImportId, null), none_descriptor.importedId());

    const sender_descriptor = CapDescriptor{ .sender_hosted = 30 };
    try testing.expect(sender_descriptor.isSenderHosted());
    try testing.expect(!sender_descriptor.isReceiverHosted());
    try testing.expectEqual(@as(?ExportId, 30), sender_descriptor.exportedId());
    try testing.expectEqual(@as(?ImportId, null), sender_descriptor.importedId());
    try testing.expect(sender_descriptor.isForwardableToCallTarget());
    try testing.expectEqual(CallTarget{ .imported_cap = 30 }, sender_descriptor.forwardableCallTarget().?);

    const receiver_descriptor = CapDescriptor{ .receiver_hosted = 31 };
    try testing.expect(receiver_descriptor.isReceiverHosted());
    try testing.expectEqual(@as(?ImportId, 31), receiver_descriptor.importedId());
    try testing.expect(!receiver_descriptor.isForwardableToCallTarget());

    const answer_descriptor = CapDescriptor{ .receiver_answer = .{ .question_id = 32 } };
    try testing.expect(answer_descriptor.isReceiverAnswer());
    try testing.expectEqual(PromisedAnswerTarget{ .question_id = 32 }, answer_descriptor.promisedAnswer().?);
    try testing.expectEqual(CallTarget{ .promised_answer = .{ .question_id = 32 } }, answer_descriptor.forwardableCallTarget().?);

    const sender_promise_descriptor = CapDescriptor{ .sender_promise = 33 };
    try testing.expect(sender_promise_descriptor.isSenderPromise());
    try testing.expectEqual(@as(?ExportId, 33), sender_promise_descriptor.exportedId());

    const third_party_descriptor = CapDescriptor{ .third_party_hosted = 34 };
    try testing.expect(third_party_descriptor.isThirdPartyHosted());
    try testing.expectEqual(@as(?ExportId, 34), third_party_descriptor.exportedId());

    try state.applyCapDescriptor(.{ .sender_hosted = 30 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(30));
    try testing.expectEqual(@as(?u32, 1), state.importReferenceCount(30));
    try state.applyCapDescriptor(.{ .sender_promise = 30 });
    try testing.expectEqual(@as(?u32, 2), state.importReferenceCount(30));
    try state.applyCapDescriptor(.{ .third_party_hosted = 30 });
    try testing.expectEqual(@as(?u32, 3), state.importReferenceCount(30));

    try state.addExport(31);
    try state.applyCapDescriptor(.{ .receiver_hosted = 31 });
    try state.openQuestion(32, .call);
    try state.applyCapDescriptor(.{ .receiver_answer = .{ .question_id = 32 } });
    try state.applyCapDescriptor(.none);

    try testing.expectError(error.InvalidTransition, state.applyCapDescriptor(.{ .receiver_hosted = 99 }));
    try testing.expectError(error.QuestionNotOpen, state.applyCapDescriptor(.{ .receiver_answer = .{ .question_id = 99 } }));

    try state.releaseExport(31);
    try testing.expectError(error.ExportAlreadyReleased, state.applyCapDescriptor(.{ .receiver_hosted = 31 }));
}

test "rpc state validates capability tables before mutating them" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectError(error.InvalidTransition, state.applyCapTable(&.{
        .{ .sender_hosted = 40 },
        .{ .receiver_hosted = 404 },
    }));
    try testing.expectEqual(@as(?CapabilityLifetime, null), state.importState(40));

    try state.addExport(41);
    try state.applyCapTable(&.{
        .{ .sender_hosted = 40 },
        .{ .receiver_hosted = 41 },
    });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(40));
}

test "rpc state validates call targets against imports and answers" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectError(error.InvalidTransition, state.validateCallTarget(.{ .imported_cap = 60 }));
    try state.addImport(60);
    try state.validateCallTarget(.{ .imported_cap = 60 });
    try state.releaseImport(60);
    try testing.expectError(error.ImportAlreadyReleased, state.validateCallTarget(.{ .imported_cap = 60 }));

    try testing.expectError(error.QuestionNotOpen, state.validateCallTarget(.{ .promised_answer = .{ .question_id = 61 } }));
    try state.openQuestion(61, .bootstrap);
    try state.validateCallTarget(.{ .promised_answer = .{ .question_id = 61 } });
}

test "rpc state applies transport-independent events" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.apply(.{ .bootstrap = 3 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(3));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(3));
    try testing.expectError(error.QuestionAlreadyOpen, state.apply(.{ .call = 3 }));

    try state.apply(.{ .finish = 3 });
    try testing.expectEqual(@as(?QuestionState, .finished), state.questionState(3));
    try state.apply(.{ .resolve = 3 });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(3));
    try testing.expectError(error.AnswerAlreadyResolved, state.apply(.{ .return_ = 3 }));

    try state.apply(.{ .provide = 7 });
    try state.apply(.{ .accept = 8 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(7));
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(8));
    try state.apply(.{ .release = .{ .export_id = 7 } });
    try state.apply(.{ .release = .{ .import_id = 8 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.exportState(7));
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(8));
    try testing.expectError(error.ExportAlreadyReleased, state.apply(.{ .release = .{ .export_id = 7 } }));
    try testing.expectError(error.InvalidTransition, state.apply(.{ .join = {} }));
}

test "rpc state applies only the semantically aligned wire event subset" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.applyWireEvent(.{ .bootstrap = 41 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(41));
    try state.applyWireEvent(.{ .finish = .{ .question_id = 41, .release_result_caps = true } });
    try state.applyWireEvent(.{ .return_ = .{ .answer_id = 41, .release_param_caps = true, .no_finish_needed = false } });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(41));

    try state.openQuestion(102, .call);
    try state.applyWireEvent(.{ .third_party_answer = 102 });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(102));

    try state.addImport(42);
    try state.applyWireEvent(.{ .release = .{ .id = 42, .reference_count = 1 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(42));

    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .disembargo = .{
        .target = .{ .imported_cap = 43 },
        .context = .{ .sender_loopback = 44 },
    } }));
    try state.addImport(43);
    try state.applyWireEvent(.{ .disembargo = .{
        .target = .{ .imported_cap = 43 },
        .context = .{ .sender_loopback = 44 },
    } });

    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 99 }));
    try state.applyWireEvent(.{ .provide = 99 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(99));
    try state.applyWireEvent(.{ .accept = 100 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(100));
    try state.applyWireEvent(.{ .join = 101 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(101));
}

test "rpc wire provide accept and join open questions without projecting to capability events" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    const provide = WireEvent{ .provide = 71 };
    try testing.expect(provide.toStateEvent() == null);
    try state.applyWireEvent(provide);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(71));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(71));
    try testing.expectEqual(@as(usize, 0), state.provideCount());

    const accept = WireEvent{ .accept = 72 };
    try testing.expect(accept.toStateEvent() == null);
    try state.applyWireEvent(accept);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(72));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(72));
    try testing.expectEqual(@as(usize, 0), state.acceptCount());

    const join = WireEvent{ .join = 73 };
    try testing.expect(join.toStateEvent() == null);
    try state.applyWireEvent(join);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(73));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(73));
    try testing.expectEqual(@as(usize, 0), state.joinCount());

    try testing.expectError(error.QuestionAlreadyOpen, state.applyWireEvent(.{ .provide = 71 }));
}

test "rpc wire third-party answers resolve existing answers without projecting to returns" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    const answer = WireEvent{ .third_party_answer = 81 };
    try testing.expect(answer.toStateEvent() == null);
    try testing.expectError(error.QuestionNotOpen, state.applyWireEvent(answer));

    try state.openQuestion(81, .call);
    try state.applyWireEvent(answer);
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(81));
    try testing.expectError(error.AnswerAlreadyResolved, state.applyWireEvent(answer));
}

test "rpc wire resolve marks existing exports resolved" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.addExport(48);
    try testing.expectEqual(@as(?bool, false), state.exportResolved(48));
    try testing.expect(state.exportResolution(48) == null);
    try state.applyWireEvent(.{ .resolve = 48 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(48));
    try testing.expectEqual(@as(?bool, true), state.exportResolved(48));
    try testing.expect(state.exportResolution(48) == null);
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 48 }));

    try state.addExport(49);
    try state.releaseExport(49);
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 49 }));
}

test "rpc wire release counts decrement import references" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.imports.put(50, .{ .id = 50, .reference_count = 3 });
    try state.applyWireEvent(.{ .release = .{ .id = 50, .reference_count = 2 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(50));
    try testing.expectEqual(@as(?u32, 1), state.importReferenceCount(50));

    try state.applyWireEvent(.{ .release = .{ .id = 50, .reference_count = 1 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(50));
    try testing.expectEqual(@as(?u32, 0), state.importReferenceCount(50));
    try testing.expectError(error.ImportAlreadyReleased, state.applyWireEvent(.{ .release = .{ .id = 50, .reference_count = 1 } }));

    try state.imports.put(51, .{ .id = 51, .reference_count = 1 });
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .release = .{ .id = 51, .reference_count = 0 } }));
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .release = .{ .id = 51, .reference_count = 2 } }));
}
