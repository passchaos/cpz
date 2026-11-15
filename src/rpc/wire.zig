const std = @import("std");
const types = @import("types.zig");
const state_mod = @import("state.zig");

const mod_call = @import("call.zig");
const mod_dispatch_wire = @import("dispatch_wire.zig");
const mod_event = @import("event.zig");
const mod_output = @import("output.zig");

const State = state_mod.State;
const AnswerId = types.AnswerId;
const CallOptions = types.CallOptions;
const CallTarget = types.CallTarget;
const CapDescriptor = types.CapDescriptor;
const CapDescriptorInfo = types.CapDescriptorInfo;
const CapabilityRelease = types.CapabilityRelease;
const DispatchResult = types.DispatchResult;
const Error = types.Error;
const ExceptionInfo = types.ExceptionInfo;
const ExportId = types.ExportId;
const Finish = types.Finish;
const HandoffReturn = types.HandoffReturn;
const QuestionId = types.QuestionId;
const StateHandoffReturnStats = types.StateHandoffReturnStats;
const TrackedCallServiceActionPlan = types.TrackedCallServiceActionPlan;
const TrackedCallServiceActionStats = types.TrackedCallServiceActionStats;
const callMethodEntryIndex = types.callMethodEntryIndex;
const callMethodFromWireCall = types.callMethodFromWireCall;
const callMethodFromWireMessage = types.callMethodFromWireMessage;
const capDescriptorFromWire = types.capDescriptorFromWire;
const capDescriptorInfoFromWire = types.capDescriptorInfoFromWire;
const capDescriptorsFromInfosAlloc = types.capDescriptorsFromInfosAlloc;
const initForwardedWireCall = types.initForwardedWireCall;
const initForwardedWireCallMessage = types.initForwardedWireCallMessage;
const initWirePayloadCapTable = types.initWirePayloadCapTable;
const initWirePayloadCapTableInfo = types.initWirePayloadCapTableInfo;
const initWirePayloadCapability = types.initWirePayloadCapability;
const initWirePayloadCapabilityFromRegistry = types.initWirePayloadCapabilityFromRegistry;
const initWirePayloadCapabilityInfo = types.initWirePayloadCapabilityInfo;
const initWirePayloadData = types.initWirePayloadData;
const initWirePayloadDataFromRegistry = types.initWirePayloadDataFromRegistry;
const initWirePayloadDataInfo = types.initWirePayloadDataInfo;
const initWirePayloadStructFromRegistry = types.initWirePayloadStructFromRegistry;
const initWirePayloadStructInfoWith = types.initWirePayloadStructInfoWith;
const initWirePayloadStructWith = types.initWirePayloadStructWith;
const initWirePayloadText = types.initWirePayloadText;
const initWirePayloadTextFromRegistry = types.initWirePayloadTextFromRegistry;
const initWirePayloadTextInfo = types.initWirePayloadTextInfo;
const initWirePayloadUInt32List = types.initWirePayloadUInt32List;
const initWirePayloadUInt32ListFromRegistry = types.initWirePayloadUInt32ListFromRegistry;
const initWirePayloadUInt32ListInfo = types.initWirePayloadUInt32ListInfo;
const initWireReturnException = types.initWireReturnException;
const senderHostedDescriptorsFromRegistryAlloc = types.senderHostedDescriptorsFromRegistryAlloc;
const writeCallOptionsToWire = types.writeCallOptionsToWire;
const writeCallTargetToWire = types.writeCallTargetToWire;
const writeExceptionInfoToWire = types.writeExceptionInfoToWire;
const dispatchCallMethod = mod_call.dispatchCallMethod;
const validateWireCallServiceActionPlans = mod_dispatch_wire.validateWireCallServiceActionPlans;
const validateWireMessageServiceActionPlans = mod_dispatch_wire.validateWireMessageServiceActionPlans;
const payloadContentCapabilityIndex = mod_event.payloadContentCapabilityIndex;
const returnOutcomeFromWireReturn = mod_event.returnOutcomeFromWireReturn;
const appendRpcServiceActionUnifiedOutputPlansToQueue = mod_output.appendRpcServiceActionUnifiedOutputPlansToQueue;
const appendRpcServiceActionUnifiedOutputPlansToQueues = mod_output.appendRpcServiceActionUnifiedOutputPlansToQueues;
const appendRpcServiceActionUnifiedOutputPlansToTaggedQueue = mod_output.appendRpcServiceActionUnifiedOutputPlansToTaggedQueue;
const appendRpcServiceActionUnifiedOutputsToQueue = mod_output.appendRpcServiceActionUnifiedOutputsToQueue;
const appendRpcServiceActionUnifiedOutputsToQueues = mod_output.appendRpcServiceActionUnifiedOutputsToQueues;
const appendRpcServiceActionUnifiedOutputsToTaggedQueue = mod_output.appendRpcServiceActionUnifiedOutputsToTaggedQueue;
const sendRpcServiceActionUnifiedOutputPlansToSink = mod_output.sendRpcServiceActionUnifiedOutputPlansToSink;
const sendRpcServiceActionUnifiedOutputPlansToSinks = mod_output.sendRpcServiceActionUnifiedOutputPlansToSinks;
const sendRpcServiceActionUnifiedOutputPlansToTaggedSink = mod_output.sendRpcServiceActionUnifiedOutputPlansToTaggedSink;
const sendRpcServiceActionUnifiedOutputsToSink = mod_output.sendRpcServiceActionUnifiedOutputsToSink;
const sendRpcServiceActionUnifiedOutputsToSinks = mod_output.sendRpcServiceActionUnifiedOutputsToSinks;
const sendRpcServiceActionUnifiedOutputsToTaggedSink = mod_output.sendRpcServiceActionUnifiedOutputsToTaggedSink;

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

pub fn initWireCallHeaderWithOptions(
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

pub fn applyInitializedNonResultReturnState(
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

pub fn wireCallMethodEntryIndex(call: anytype, comptime entries: anytype) Error!?usize {
    return callMethodEntryIndex(callMethodFromWireCall(call), entries);
}

pub fn wireMessageMethodEntryIndex(message: anytype, comptime entries: anytype) !?usize {
    const method = (try callMethodFromWireMessage(message)) orelse return null;
    return try callMethodEntryIndex(method, entries);
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

pub fn validateWirePayloadContent(payload: anytype, cap_count: usize) !void {
    const content = try payload.content();
    _ = try content.validateWithOptions(.{ .capability_count_limit = cap_count });
}

pub fn validateWirePayload(allocator: std.mem.Allocator, payload: anytype) !void {
    const descriptors = try capTableFromWirePayload(allocator, payload);
    defer allocator.free(descriptors);
    try validateWirePayloadContent(payload, descriptors.len);
}
