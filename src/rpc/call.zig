const std = @import("std");
const types = @import("types.zig");
const state_mod = @import("state.zig");

const mod_wire = @import("wire.zig");

const State = state_mod.State;
const CallMethod = types.CallMethod;
const CapDescriptor = types.CapDescriptor;
const CapDescriptorInfo = types.CapDescriptorInfo;
const WireDispatchOutcome = types.WireDispatchOutcome;
const WireDispatchStats = types.WireDispatchStats;
const callMethodFromWireCall = types.callMethodFromWireCall;
const initWirePayloadCapTable = types.initWirePayloadCapTable;
const initWirePayloadCapTableInfo = types.initWirePayloadCapTableInfo;
const initWireReturnException = types.initWireReturnException;
const senderHostedDescriptorsFromRegistryAlloc = types.senderHostedDescriptorsFromRegistryAlloc;
const validateCallMethodEntries = types.validateCallMethodEntries;
const wireMessageTag = types.wireMessageTag;
const initBootstrapReturnForRequest = mod_wire.initBootstrapReturnForRequest;
const initCapabilityReturnMessage = mod_wire.initCapabilityReturnMessage;
const initDispatchReturnMessage = mod_wire.initDispatchReturnMessage;
const initEmptyReturnMessage = mod_wire.initEmptyReturnMessage;
const initForwardedWireCallMessageToResolvedTarget = mod_wire.initForwardedWireCallMessageToResolvedTarget;
const initWireReturnMessageData = mod_wire.initWireReturnMessageData;
const initWireReturnMessageDataFromRegistry = mod_wire.initWireReturnMessageDataFromRegistry;
const initWireReturnMessageDataInfo = mod_wire.initWireReturnMessageDataInfo;
const initWireReturnMessageText = mod_wire.initWireReturnMessageText;
const initWireReturnMessageTextFromRegistry = mod_wire.initWireReturnMessageTextFromRegistry;
const initWireReturnMessageTextInfo = mod_wire.initWireReturnMessageTextInfo;
const initWireReturnMessageUInt32List = mod_wire.initWireReturnMessageUInt32List;
const initWireReturnMessageUInt32ListFromRegistry = mod_wire.initWireReturnMessageUInt32ListFromRegistry;
const initWireReturnMessageUInt32ListInfo = mod_wire.initWireReturnMessageUInt32ListInfo;

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
