const std = @import("std");
const types = @import("types.zig");
const state_mod = @import("state.zig");

const mod_call = @import("call.zig");
const mod_dispatch_wire = @import("dispatch_wire.zig");
const mod_event = @import("event.zig");

const State = state_mod.State;
const CallTarget = types.CallTarget;
const RpcTurnPlan = types.RpcTurnPlan;
const StateHandoffReturnStats = types.StateHandoffReturnStats;
const WireDispatchStats = types.WireDispatchStats;
const appendRpcTurnUnifiedOutputsToQueue = types.appendRpcTurnUnifiedOutputsToQueue;
const appendRpcTurnUnifiedOutputsToQueues = types.appendRpcTurnUnifiedOutputsToQueues;
const appendRpcTurnUnifiedOutputsToTaggedQueue = types.appendRpcTurnUnifiedOutputsToTaggedQueue;
const initForwardedWireCallMessage = types.initForwardedWireCallMessage;
const sendRpcTurnUnifiedOutputsToSink = types.sendRpcTurnUnifiedOutputsToSink;
const sendRpcTurnUnifiedOutputsToSinks = types.sendRpcTurnUnifiedOutputsToSinks;
const sendRpcTurnUnifiedOutputsToTaggedSink = types.sendRpcTurnUnifiedOutputsToTaggedSink;
const validateCallMethodEntries = types.validateCallMethodEntries;
const dispatchBootstrap = mod_call.dispatchBootstrap;
const dispatchCall = mod_call.dispatchCall;
const dispatchCallMethods = mod_call.dispatchCallMethods;
const planWireMessagesDispatch = mod_call.planWireMessagesDispatch;
const planWireMessagesMethodsDispatch = mod_call.planWireMessagesMethodsDispatch;
const applyStateWireMessageWithHandler = mod_dispatch_wire.applyStateWireMessageWithHandler;
const dispatchWireMessagesForwardingDense = mod_dispatch_wire.dispatchWireMessagesForwardingDense;
const dispatchWireMessagesForwardingDenseWithApplyHandler = mod_dispatch_wire.dispatchWireMessagesForwardingDenseWithApplyHandler;
const dispatchWireMessagesForwardingToDenseSinks = mod_dispatch_wire.dispatchWireMessagesForwardingToDenseSinks;
const dispatchWireMessagesForwardingToDenseSinksWithApplyHandler = mod_dispatch_wire.dispatchWireMessagesForwardingToDenseSinksWithApplyHandler;
const dispatchWireMessagesMethodsForwardingDense = mod_dispatch_wire.dispatchWireMessagesMethodsForwardingDense;
const dispatchWireMessagesMethodsForwardingDenseWithApplyHandler = mod_dispatch_wire.dispatchWireMessagesMethodsForwardingDenseWithApplyHandler;
const dispatchWireMessagesMethodsForwardingToDenseSinks = mod_dispatch_wire.dispatchWireMessagesMethodsForwardingToDenseSinks;
const dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler = mod_dispatch_wire.dispatchWireMessagesMethodsForwardingToDenseSinksWithApplyHandler;
const ignoreInitializedMessage = mod_dispatch_wire.ignoreInitializedMessage;
const eventFromWireMessage = mod_event.eventFromWireMessage;

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

pub fn appliedRpcTurnPlan(state: *const State, dispatch: WireDispatchStats, handoff_returns: StateHandoffReturnStats) RpcTurnPlan {
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

pub fn dispatchRpcTurnForwardingUnifiedDenseFromHandlersImpl(
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
