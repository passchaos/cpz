const std = @import("std");
const types = @import("types.zig");
const state_mod = @import("state.zig");

const mod_call = @import("call.zig");
const mod_event = @import("event.zig");
const mod_wire = @import("wire.zig");

const State = state_mod.State;
const Error = types.Error;
const TrackedCallServiceActionPlan = types.TrackedCallServiceActionPlan;
const TrackedCallServiceActionStats = types.TrackedCallServiceActionStats;
const WireDispatchOutcome = types.WireDispatchOutcome;
const WireDispatchStats = types.WireDispatchStats;
const WireMessageApplyResult = types.WireMessageApplyResult;
const validateCallMethodEntries = types.validateCallMethodEntries;
const dispatchBootstrap = mod_call.dispatchBootstrap;
const dispatchCall = mod_call.dispatchCall;
const dispatchCallForwardingOutcome = mod_call.dispatchCallForwardingOutcome;
const dispatchCallMethod = mod_call.dispatchCallMethod;
const dispatchCallMethods = mod_call.dispatchCallMethods;
const dispatchCallMethodsForwardingOutcome = mod_call.dispatchCallMethodsForwardingOutcome;
const dispatchCallMethodsOutcome = mod_call.dispatchCallMethodsOutcome;
const dispatchCallOutcome = mod_call.dispatchCallOutcome;
const planWireMessagesDispatch = mod_call.planWireMessagesDispatch;
const planWireMessagesMethodsDispatch = mod_call.planWireMessagesMethodsDispatch;
const eventFromWireMessage = mod_event.eventFromWireMessage;
const initForwardedWireCallMessageToResolvedTarget = mod_wire.initForwardedWireCallMessageToResolvedTarget;

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

pub fn validateWireCallServiceActionPlans(calls: anytype, plans: []const TrackedCallServiceActionPlan, comptime entries: anytype) Error!TrackedCallServiceActionStats {
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

pub fn validateWireMessageServiceActionPlans(messages: anytype, plans: []const TrackedCallServiceActionPlan, comptime entries: anytype) !TrackedCallServiceActionStats {
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

pub fn applyStateWireMessageWithHandler(
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

pub fn sendResponseMessageIfNeeded(outcome: WireDispatchOutcome, response_context: anytype, response_handler: anytype, response_message: anytype) !void {
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

pub fn sendForwardedMessageIfNeeded(outcome: WireDispatchOutcome, forward_context: anytype, forward_handler: anytype, forward_message: anytype) !void {
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
