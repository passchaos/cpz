const std = @import("std");
const types = @import("types.zig");

const RpcOutputStats = types.RpcOutputStats;
const TrackedCallServiceActionOutputPosition = types.TrackedCallServiceActionOutputPosition;
const TrackedCallServiceActionPlan = types.TrackedCallServiceActionPlan;
const TrackedCallServiceActionStats = types.TrackedCallServiceActionStats;
const trackedCallServiceActionUnifiedOutputPosition = types.trackedCallServiceActionUnifiedOutputPosition;

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
