const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc turn dispatcher filters pending accept disembargos without sinks" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        fn handle(_: void, _: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            return 0;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 150,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-no-sink-150",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 151,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-no-sink-151",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    const request_messages = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(request_messages);
    const response_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(response_messages);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    const disembargo_messages = [_]generated.Message.Builder{disembargo_root};

    const applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        &state,
        std.testing.allocator,
        response_messages,
        forward_messages,
        disembargo_messages[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "filter-no-sink-151",
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 2), state.pendingAcceptEmbargoCount());

    var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
    try std.testing.expectEqualStrings("filter-no-sink-151", info.context.accept);
}

test "rpc turn dispatcher reports apply details before ready handoff outputs" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 500;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,
        capability_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, usage: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            context.capability_sum += usage.capability orelse 0;
            return question_id + 900;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        sent: usize = 0,
        last_question: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const call = try message.get_call();
            context.sent += 1;
            context.last_question = try call.get_questionId();
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 400 });
    try state.resolveImportTo(400, .{ .sender_hosted = 401 });
    try state.applyCapDescriptor(.{ .sender_hosted = 401 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 71,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 72,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "turn-accept-72",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 70);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(400);
    const target = try call.init_target();
    try target.set_importedCap(400);
    try cpz.rpc.initWireCallParamsText(call, "turn apply forward", &.{.{ .sender_hosted = 402 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "turn-accept-72" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };
    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var response_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder2.deinit();
    const response2 = try generated.Message.initRootTyped(&response_builder2);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{ response0, response1, response2 };
    const forwards = [_]generated.Message.Builder{forward};
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 3), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 70 + 71 + 72), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 400), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 72), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 72), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 972);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 401 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("turn apply forward", try (try (try forwarded.params()).content()).getText());
    }
}

test "rpc turn dispatcher fills pending disembargos with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 970;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 146,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-apply-release-146",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 147,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-apply-pending-147",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "no-sink-apply-release-146" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 146), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 146), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 146), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1116);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("no-sink-apply-pending-147", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 146,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-apply-release-146",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 147,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-apply-pending-147",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(queue_forward_messages);
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo = try generated.Message.initRootTyped(&queue_disembargo_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_disembargos = [_]generated.Message.Builder{queue_disembargo};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forward_messages,
        queue_disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 146);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "no-sink-apply-pending-147");
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 146), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc turn dispatcher fills unified outputs with pending disembargos and apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 970;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 152,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-apply-release-152",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 153,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-apply-pending-153",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "unified-apply-release-152" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };

    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 2), applied.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, applied.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, applied.disembargoMessageRange());
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 152), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 152), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 152), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1122);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("unified-apply-pending-153", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 154,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-queue-apply-release-154",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 155,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-queue-apply-pending-155",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_request_builder.deinit();
    const queue_request_root = try generated.Message.initRootTyped(&queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "unified-queue-apply-release-154" },
    });
    var queue_request_reader = cpz.MessageReader.init(try queue_request_builder.segmentsConst(), .{});
    const queue_requests = [_]generated.Message{generated.Message.fromReader(try queue_request_reader.getRoot())};
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    var queue_apply_context: ApplyContext = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    const queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        queue_requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &output_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 154);
    try support.expectQueuedDisembargoBuilder(output_queue.items[1], .{ .imported_cap = 5 }, "unified-queue-apply-pending-155");
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 154), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);

    const TaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer tagged_queue_state.deinit();
    try tagged_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 156,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-tagged-queue-apply-release-156",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 157,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-tagged-queue-apply-pending-157",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var tagged_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_request_builder.deinit();
    const tagged_queue_request_root = try generated.Message.initRootTyped(&tagged_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(tagged_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "unified-tagged-queue-apply-release-156" },
    });
    var tagged_queue_request_reader = cpz.MessageReader.init(try tagged_queue_request_builder.segmentsConst(), .{});
    const tagged_queue_requests = [_]generated.Message{generated.Message.fromReader(try tagged_queue_request_reader.getRoot())};
    var tagged_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_output_builder0.deinit();
    const tagged_queue_output0 = try generated.Message.initRootTyped(&tagged_queue_output_builder0);
    var tagged_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_output_builder1.deinit();
    const tagged_queue_output1 = try generated.Message.initRootTyped(&tagged_queue_output_builder1);
    const tagged_queue_outputs = [_]generated.Message.Builder{ tagged_queue_output0, tagged_queue_output1 };
    var tagged_queue_apply_context: ApplyContext = .{};
    var tagged_queue_provide_context: HandoffHandler = .{};
    var tagged_queue_accept_context: HandoffHandler = .{};
    var tagged_queue_join_context: HandoffHandler = .{};
    var tagged_output_queue = std.ArrayList(TaggedQueueItem).empty;
    defer tagged_output_queue.deinit(std.testing.allocator);
    const tagged_queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlersWithApplyHandler(
        &tagged_queue_state,
        std.testing.allocator,
        tagged_queue_outputs[0..],
        tagged_queue_requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &tagged_queue_provide_context,
        HandoffHandler.handle,
        &tagged_queue_accept_context,
        HandoffHandler.handle,
        &tagged_queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &tagged_output_queue,
        &tagged_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, tagged_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, tagged_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), tagged_output_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, tagged_output_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_output_queue.items[0].message, 156);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_output_queue.items[1].position);
    try support.expectQueuedDisembargoBuilder(tagged_output_queue.items[1].message, .{ .imported_cap = 5 }, "unified-tagged-queue-apply-pending-157");
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 156), tagged_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_accept_context.seen);

    var split_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer split_queue_state.deinit();
    try split_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 158,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-split-queue-apply-release-158",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 159,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-split-queue-apply-pending-159",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var split_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_request_builder.deinit();
    const split_queue_request_root = try generated.Message.initRootTyped(&split_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(split_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "unified-split-queue-apply-release-158" },
    });
    var split_queue_request_reader = cpz.MessageReader.init(try split_queue_request_builder.segmentsConst(), .{});
    const split_queue_requests = [_]generated.Message{generated.Message.fromReader(try split_queue_request_reader.getRoot())};
    var split_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_output_builder0.deinit();
    const split_queue_output0 = try generated.Message.initRootTyped(&split_queue_output_builder0);
    var split_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_output_builder1.deinit();
    const split_queue_output1 = try generated.Message.initRootTyped(&split_queue_output_builder1);
    const split_queue_outputs = [_]generated.Message.Builder{ split_queue_output0, split_queue_output1 };
    var split_queue_apply_context: ApplyContext = .{};
    var split_queue_provide_context: HandoffHandler = .{};
    var split_queue_accept_context: HandoffHandler = .{};
    var split_queue_join_context: HandoffHandler = .{};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    const split_queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
        &split_queue_state,
        std.testing.allocator,
        split_queue_outputs[0..],
        split_queue_requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &split_queue_provide_context,
        HandoffHandler.handle,
        &split_queue_accept_context,
        HandoffHandler.handle,
        &split_queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &split_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, split_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, split_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 158);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "unified-split-queue-apply-pending-159");
    try std.testing.expectEqual(@as(usize, 1), split_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 158), split_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), split_queue_accept_context.seen);
}

test "rpc turn dispatcher sends pending accept disembargos with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 950;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const DisembargoSink = struct {
        sent: usize = 0,
        accept_contexts: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const disembargo = try message.get_disembargo();
            context.sent += 1;
            if ((try disembargo.which()) == .accept) context.accept_contexts += 1;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 96,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-combined-release-96",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 97,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-combined-pending-97",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-combined-release-96" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var response_sink: ResponseSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &response_sink,
        ResponseSink.handle,
        {},
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &disembargo_sink,
        DisembargoSink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 96), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.accept_contexts);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 96), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 96), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 96), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1046);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("apply-combined-pending-97", info.context.accept);
    }
}

test "rpc turn dispatcher filters pending accept disembargos with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 970;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const DisembargoSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            _ = try message.get_disembargo();
            context.sent += 1;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 110,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-release-110",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 111,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-pending-111",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-filter-release-110" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var response_sink: ResponseSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &response_sink,
        ResponseSink.handle,
        {},
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-pending-111",
        &disembargo_sink,
        DisembargoSink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 110), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 110), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 110), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 110), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1080);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("apply-filter-pending-111", info.context.accept);
    }
}

test "rpc turn dispatcher filters pending accept disembargos without sinks with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 970;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 154,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-no-sink-release-154",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 155,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-no-sink-pending-155",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-filter-no-sink-release-154" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-no-sink-pending-155",
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 154), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 154), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 154), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1124);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("apply-filter-no-sink-pending-155", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 154,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-no-sink-release-154",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 155,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-no-sink-pending-155",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(queue_forward_messages);
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo = try generated.Message.initRootTyped(&queue_disembargo_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_disembargos = [_]generated.Message.Builder{queue_disembargo};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forward_messages,
        queue_disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-no-sink-pending-155",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 154);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "apply-filter-no-sink-pending-155");
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 154), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc turn dispatcher filters pending accept disembargos into unified outputs with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 970;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 160,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-unified-release-160",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 161,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-unified-pending-161",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-filter-unified-release-160" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };

    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-unified-pending-161",
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 2), applied.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, applied.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, applied.disembargoMessageRange());
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 160), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 160), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 160), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1130);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("apply-filter-unified-pending-161", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 162,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-queue-release-162",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 163,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-queue-pending-163",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_request_builder.deinit();
    const queue_request_root = try generated.Message.initRootTyped(&queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-filter-queue-release-162" },
    });
    var queue_request_reader = cpz.MessageReader.init(try queue_request_builder.segmentsConst(), .{});
    const queue_requests = [_]generated.Message{generated.Message.fromReader(try queue_request_reader.getRoot())};
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    var queue_apply_context: ApplyContext = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    const queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        queue_requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-queue-pending-163",
        &output_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 162);
    try support.expectQueuedDisembargoBuilder(output_queue.items[1], .{ .imported_cap = 5 }, "apply-filter-queue-pending-163");
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 162), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);

    const TaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer tagged_queue_state.deinit();
    try tagged_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 164,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-tagged-queue-release-164",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 165,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-tagged-queue-pending-165",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var tagged_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_request_builder.deinit();
    const tagged_queue_request_root = try generated.Message.initRootTyped(&tagged_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(tagged_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-filter-tagged-queue-release-164" },
    });
    var tagged_queue_request_reader = cpz.MessageReader.init(try tagged_queue_request_builder.segmentsConst(), .{});
    const tagged_queue_requests = [_]generated.Message{generated.Message.fromReader(try tagged_queue_request_reader.getRoot())};
    var tagged_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_output_builder0.deinit();
    const tagged_queue_output0 = try generated.Message.initRootTyped(&tagged_queue_output_builder0);
    var tagged_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_output_builder1.deinit();
    const tagged_queue_output1 = try generated.Message.initRootTyped(&tagged_queue_output_builder1);
    const tagged_queue_outputs = [_]generated.Message.Builder{ tagged_queue_output0, tagged_queue_output1 };
    var tagged_queue_apply_context: ApplyContext = .{};
    var tagged_queue_provide_context: HandoffHandler = .{};
    var tagged_queue_accept_context: HandoffHandler = .{};
    var tagged_queue_join_context: HandoffHandler = .{};
    var tagged_output_queue = std.ArrayList(TaggedQueueItem).empty;
    defer tagged_output_queue.deinit(std.testing.allocator);
    const tagged_queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlersWithApplyHandler(
        &tagged_queue_state,
        std.testing.allocator,
        tagged_queue_outputs[0..],
        tagged_queue_requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &tagged_queue_provide_context,
        HandoffHandler.handle,
        &tagged_queue_accept_context,
        HandoffHandler.handle,
        &tagged_queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-tagged-queue-pending-165",
        &tagged_output_queue,
        &tagged_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, tagged_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, tagged_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), tagged_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 2), tagged_output_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, tagged_output_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_output_queue.items[0].message, 164);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_output_queue.items[1].position);
    try support.expectQueuedDisembargoBuilder(tagged_output_queue.items[1].message, .{ .imported_cap = 5 }, "apply-filter-tagged-queue-pending-165");
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 164), tagged_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 164), tagged_queue_accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_queue_join_context.seen);

    var split_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer split_queue_state.deinit();
    try split_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 166,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-split-queue-release-166",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 167,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "apply-filter-split-queue-pending-167",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var split_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_request_builder.deinit();
    const split_queue_request_root = try generated.Message.initRootTyped(&split_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(split_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-filter-split-queue-release-166" },
    });
    var split_queue_request_reader = cpz.MessageReader.init(try split_queue_request_builder.segmentsConst(), .{});
    const split_queue_requests = [_]generated.Message{generated.Message.fromReader(try split_queue_request_reader.getRoot())};
    var split_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_output_builder0.deinit();
    const split_queue_output0 = try generated.Message.initRootTyped(&split_queue_output_builder0);
    var split_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_output_builder1.deinit();
    const split_queue_output1 = try generated.Message.initRootTyped(&split_queue_output_builder1);
    const split_queue_outputs = [_]generated.Message.Builder{ split_queue_output0, split_queue_output1 };
    var split_queue_apply_context: ApplyContext = .{};
    var split_queue_provide_context: HandoffHandler = .{};
    var split_queue_accept_context: HandoffHandler = .{};
    var split_queue_join_context: HandoffHandler = .{};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    const split_queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
        &split_queue_state,
        std.testing.allocator,
        split_queue_outputs[0..],
        split_queue_requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        &split_queue_provide_context,
        HandoffHandler.handle,
        &split_queue_accept_context,
        HandoffHandler.handle,
        &split_queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "apply-filter-split-queue-pending-167",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &split_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, split_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, split_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), split_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 166);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "apply-filter-split-queue-pending-167");
    try std.testing.expectEqual(@as(usize, 1), split_queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), split_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 166), split_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), split_queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), split_queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 166), split_queue_accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), split_queue_join_context.seen);
}

test "rpc turn dispatcher reports pending accept disembargos after dispatch" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const MessageSink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const HandoffHandler = struct {
        fn handle(_: void, _: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            return 0;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 81,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "turn-applied-pending-81",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    const accept_message = generated.Message.fromReader(try accept_reader.getRoot());
    const requests = [_]generated.Message{accept_message};

    const response_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(response_messages);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);

    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksFromHandlers(
        &state,
        std.testing.allocator,
        response_messages,
        forward_messages,
        requests[0..],
        {},
        BootstrapHandler.handle,
        {},
        CallHandler.handle,
        {},
        MessageSink.handle,
        {},
        MessageSink.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 1), state.pendingAcceptEmbargoCount());
}

test "rpc method turn dispatcher sends dense dispatch and ready handoff outputs" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 520;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 920;
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        sent: usize = 0,
        last_question: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const call = try message.get_call();
            context.sent += 1;
            context.last_question = try call.get_questionId();
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x2222, .method_id = 2 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 390 });
    try state.resolveImportTo(390, .{ .sender_hosted = 391 });
    try state.applyCapDescriptor(.{ .sender_hosted = 391 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 70,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = null,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 69);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(390);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x2222, .method_id = 2 }, call);
    const target = try call.init_target();
    try target.set_importedCap(390);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 2, 4 }, &.{.{ .sender_hosted = 392 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurnMethods(&state, requests[0..], entries);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, plan.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), plan.responseMessages());
    try std.testing.expectEqual(@as(usize, 1), plan.forwardedMessages());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{forward};
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlers(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 69), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 69 + 70), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 390), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 70), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 990);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 391 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 2, 4 });
    }
}

test "rpc method turn dispatcher fills pending disembargos with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 990;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xbbbb, .method_id = 11 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 148,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-apply-release-148",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 149,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-apply-pending-149",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-no-sink-apply-release-148" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 148), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 148), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 148), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1138);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-no-sink-apply-pending-149", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 148,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-apply-release-148",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 149,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-apply-pending-149",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(queue_forward_messages);
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo = try generated.Message.initRootTyped(&queue_disembargo_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_disembargos = [_]generated.Message.Builder{queue_disembargo};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forward_messages,
        queue_disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 148);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-no-sink-apply-pending-149");
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 148), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc method turn dispatcher fills pending disembargos without sinks" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 540;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 960;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xaaaa, .method_id = 10 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 710 });
    try state.resolveImportTo(710, .{ .sender_hosted = 711 });
    try state.applyCapDescriptor(.{ .sender_hosted = 711 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 143,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 144,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-disembargo-144",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 142);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(710);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xaaaa, .method_id = 10 }, call);
    const target = try call.init_target();
    try target.set_importedCap(710);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 10, 20 }, &.{.{ .sender_hosted = 712 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{forward};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosFromHandlers(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        disembargos[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(u32, 142), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 143), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 142), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 682);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 143), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1103);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 711 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 10, 20 });
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-no-sink-disembargo-144", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 710 });
    try queue_state.resolveImportTo(710, .{ .sender_hosted = 711 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 711 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 143,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 144,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-disembargo-144",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo = try generated.Message.initRootTyped(&queue_disembargo_builder);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    const queue_disembargos = [_]generated.Message.Builder{queue_disembargo};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        queue_disembargos[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 142), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 142);
    try support.expectQueuedReturnAnswer(response_queue.items[1], 143);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 710, .{ .imported_cap = 711 });
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-no-sink-disembargo-144");
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc method turn dispatcher fills unified outputs with pending disembargos" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 540;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 960;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xaaab, .method_id = 11 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 715 });
    try state.resolveImportTo(715, .{ .sender_hosted = 716 });
    try state.applyCapDescriptor(.{ .sender_hosted = 716 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 145,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 146,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-disembargo-146",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 144);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(715);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xaaab, .method_id = 11 }, call);
    const target = try call.init_target();
    try target.set_importedCap(715);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 11, 22 }, &.{.{ .sender_hosted = 717 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurnMethods(&state, requests[0..], entries);
    try std.testing.expectEqual(@as(usize, 4), plan.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, plan.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, plan.forwardedMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 3, .end = 4 }, plan.disembargoMessageRange());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    var output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder2.deinit();
    const output2 = try generated.Message.initRootTyped(&output_builder2);
    var output_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder3.deinit();
    const output3 = try generated.Message.initRootTyped(&output_builder3);
    const outputs = [_]generated.Message.Builder{ output0, output1, output2, output3 };

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 144), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 145), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 144), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 684);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 145), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1105);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 716 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 11, 22 });
    }
    {
        var reader = cpz.MessageReader.init(try output_builder3.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-unified-disembargo-146", info.context.accept);
    }
}

test "rpc method turn dispatcher filters pending accept disembargos into unified outputs" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        fn handle(_: void, _: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            return 0;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xaaad, .method_id = 13 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 158,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-filter-unified-158",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 159,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-filter-unified-159",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    const request_messages = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(request_messages);
    var output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder.deinit();
    const output = try generated.Message.initRootTyped(&output_builder);
    const outputs = [_]generated.Message.Builder{output};

    var context: Context = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-filter-unified-159",
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 2), state.pendingAcceptEmbargoCount());

    var reader = cpz.MessageReader.init(try output_builder.segmentsConst(), .{});
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
    try std.testing.expectEqualStrings("method-filter-unified-159", info.context.accept);

    var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder.deinit();
    const queue_output = try generated.Message.initRootTyped(&queue_builder);
    const queue_outputs = [_]generated.Message.Builder{queue_output};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    const queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlers(
        &state,
        std.testing.allocator,
        queue_outputs[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-filter-unified-158",
        &queue,
    );
    try std.testing.expectEqual(@as(usize, 1), queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedDisembargoBuilder(queue.items[0], .{ .imported_cap = 5 }, "method-filter-unified-158");

    const TaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder.deinit();
    const tagged_queue_output = try generated.Message.initRootTyped(&tagged_queue_builder);
    const tagged_queue_outputs = [_]generated.Message.Builder{tagged_queue_output};
    var tagged_queue = std.ArrayList(TaggedQueueItem).empty;
    defer tagged_queue.deinit(std.testing.allocator);
    const tagged_queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlers(
        &state,
        std.testing.allocator,
        tagged_queue_outputs[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-filter-unified-159",
        &tagged_queue,
    );
    try std.testing.expectEqual(@as(usize, 1), tagged_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), tagged_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_queue.items[0].position);
    try support.expectQueuedDisembargoBuilder(tagged_queue.items[0].message, .{ .imported_cap = 5 }, "method-filter-unified-159");

    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var split_queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_builder.deinit();
    const split_queue_output = try generated.Message.initRootTyped(&split_queue_builder);
    const split_queue_outputs = [_]generated.Message.Builder{split_queue_output};
    const split_queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
        &state,
        std.testing.allocator,
        split_queue_outputs[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-filter-unified-158",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(@as(usize, 1), split_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 0), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-filter-unified-158");
}

test "rpc method turn dispatcher fills unified outputs with pending disembargos and apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 980;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xaaac, .method_id = 12 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 154,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-apply-release-154",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 155,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-apply-pending-155",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-unified-apply-release-154" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };

    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 2), applied.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, applied.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, applied.disembargoMessageRange());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 154), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 154), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 154), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1134);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-unified-apply-pending-155", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 156,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-queue-apply-release-156",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 157,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-queue-apply-pending-157",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_request_builder.deinit();
    const queue_request_root = try generated.Message.initRootTyped(&queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-unified-queue-apply-release-156" },
    });
    var queue_request_reader = cpz.MessageReader.init(try queue_request_builder.segmentsConst(), .{});
    const queue_requests = [_]generated.Message{generated.Message.fromReader(try queue_request_reader.getRoot())};
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    var queue_context: Context = .{};
    var queue_apply_context: ApplyContext = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    const queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        queue_requests[0..],
        {},
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &output_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 156);
    try support.expectQueuedDisembargoBuilder(output_queue.items[1], .{ .imported_cap = 5 }, "method-unified-queue-apply-pending-157");
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 156), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);

    const TaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer tagged_queue_state.deinit();
    try tagged_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 158,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-tagged-queue-apply-release-158",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 159,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-tagged-queue-apply-pending-159",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var tagged_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_request_builder.deinit();
    const tagged_queue_request_root = try generated.Message.initRootTyped(&tagged_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(tagged_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-tagged-queue-apply-release-158" },
    });
    var tagged_queue_request_reader = cpz.MessageReader.init(try tagged_queue_request_builder.segmentsConst(), .{});
    const tagged_queue_requests = [_]generated.Message{generated.Message.fromReader(try tagged_queue_request_reader.getRoot())};
    var tagged_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_output_builder0.deinit();
    const tagged_queue_output0 = try generated.Message.initRootTyped(&tagged_queue_output_builder0);
    var tagged_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_output_builder1.deinit();
    const tagged_queue_output1 = try generated.Message.initRootTyped(&tagged_queue_output_builder1);
    const tagged_queue_outputs = [_]generated.Message.Builder{ tagged_queue_output0, tagged_queue_output1 };
    var tagged_queue_context: Context = .{};
    var tagged_queue_apply_context: ApplyContext = .{};
    var tagged_queue_provide_context: HandoffHandler = .{};
    var tagged_queue_accept_context: HandoffHandler = .{};
    var tagged_queue_join_context: HandoffHandler = .{};
    var tagged_output_queue = std.ArrayList(TaggedQueueItem).empty;
    defer tagged_output_queue.deinit(std.testing.allocator);
    const tagged_queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlersWithApplyHandler(
        &tagged_queue_state,
        std.testing.allocator,
        tagged_queue_outputs[0..],
        tagged_queue_requests[0..],
        {},
        BootstrapHandler.handle,
        &tagged_queue_context,
        entries,
        &tagged_queue_provide_context,
        HandoffHandler.handle,
        &tagged_queue_accept_context,
        HandoffHandler.handle,
        &tagged_queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &tagged_output_queue,
        &tagged_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, tagged_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, tagged_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), tagged_output_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, tagged_output_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_output_queue.items[0].message, 158);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_output_queue.items[1].position);
    try support.expectQueuedDisembargoBuilder(tagged_output_queue.items[1].message, .{ .imported_cap = 5 }, "method-tagged-queue-apply-pending-159");
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 158), tagged_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 0), tagged_queue_context.selected);

    var split_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer split_queue_state.deinit();
    try split_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 160,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-split-queue-apply-release-160",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 161,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-split-queue-apply-pending-161",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var split_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_request_builder.deinit();
    const split_queue_request_root = try generated.Message.initRootTyped(&split_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(split_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-split-queue-apply-release-160" },
    });
    var split_queue_request_reader = cpz.MessageReader.init(try split_queue_request_builder.segmentsConst(), .{});
    const split_queue_requests = [_]generated.Message{generated.Message.fromReader(try split_queue_request_reader.getRoot())};
    var split_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_output_builder0.deinit();
    const split_queue_output0 = try generated.Message.initRootTyped(&split_queue_output_builder0);
    var split_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_output_builder1.deinit();
    const split_queue_output1 = try generated.Message.initRootTyped(&split_queue_output_builder1);
    const split_queue_outputs = [_]generated.Message.Builder{ split_queue_output0, split_queue_output1 };
    var split_queue_context: Context = .{};
    var split_queue_apply_context: ApplyContext = .{};
    var split_queue_provide_context: HandoffHandler = .{};
    var split_queue_accept_context: HandoffHandler = .{};
    var split_queue_join_context: HandoffHandler = .{};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    const split_queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlersWithApplyHandler(
        &split_queue_state,
        std.testing.allocator,
        split_queue_outputs[0..],
        split_queue_requests[0..],
        {},
        BootstrapHandler.handle,
        &split_queue_context,
        entries,
        &split_queue_provide_context,
        HandoffHandler.handle,
        &split_queue_accept_context,
        HandoffHandler.handle,
        &split_queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &split_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, split_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, split_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 160);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-split-queue-apply-pending-161");
    try std.testing.expectEqual(@as(usize, 1), split_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 160), split_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), split_queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 0), split_queue_context.selected);
}

test "rpc method turn dispatcher sends pending accept disembargos with dense outputs" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 540;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 940;
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        sent: usize = 0,
        last_question: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const call = try message.get_call();
            context.sent += 1;
            context.last_question = try call.get_questionId();
        }
    };
    const DisembargoSink = struct {
        sent: usize = 0,
        accept_contexts: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const disembargo = try message.get_disembargo();
            context.sent += 1;
            if ((try disembargo.which()) == .accept) context.accept_contexts += 1;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x4444, .method_id = 4 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 650 });
    try state.resolveImportTo(650, .{ .sender_hosted = 651 });
    try state.applyCapDescriptor(.{ .sender_hosted = 651 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 93,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 94,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "combined-method-turn-94",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 92);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(650);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x4444, .method_id = 4 }, call);
    const target = try call.init_target();
    try target.set_importedCap(650);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 4, 8 }, &.{.{ .sender_hosted = 652 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurnMethods(&state, requests[0..], entries);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, plan.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), plan.disembargoMessages());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{forward};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlers(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        disembargos[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &disembargo_sink,
        DisembargoSink.handle,
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 92), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 92 + 93), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 650), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.accept_contexts);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 93), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 92), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 632);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 93), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1033);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 651 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 4, 8 });
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("combined-method-turn-94", info.context.accept);
    }
}

test "rpc method turn dispatcher filters pending accept disembargos with dense outputs" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const MessageSink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const HandoffHandler = struct {
        fn handle(_: void, _: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            return 0;
        }
    };
    const DisembargoSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            _ = try message.get_disembargo();
            context.sent += 1;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x6666, .method_id = 6 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 108,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-method-turn-108",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 109,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-method-turn-109",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    const request_messages = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(request_messages);
    const response_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(response_messages);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    const disembargo_messages = [_]generated.Message.Builder{disembargo_root};

    var context: Context = .{};
    var disembargo_sink: DisembargoSink = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlers(
        &state,
        std.testing.allocator,
        response_messages,
        forward_messages,
        disembargo_messages[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        {},
        MessageSink.handle,
        {},
        MessageSink.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "filter-method-turn-109",
        &disembargo_sink,
        DisembargoSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), state.pendingAcceptEmbargoCount());

    var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
    try std.testing.expectEqualStrings("filter-method-turn-109", info.context.accept);

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 108,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-method-turn-108",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 109,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-method-turn-109",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    const queue_request_messages = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(queue_request_messages);
    const queue_response_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(queue_response_messages);
    const queue_forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(queue_forward_messages);
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    const queue_disembargo_messages = [_]generated.Message.Builder{queue_disembargo_root};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var queue_context: Context = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_response_messages,
        queue_forward_messages,
        queue_disembargo_messages[0..],
        queue_request_messages,
        {},
        BootstrapHandler.handle,
        &queue_context,
        entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "filter-method-turn-109",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(usize, 0), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "filter-method-turn-109");
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), queue_state.pendingAcceptEmbargoCount());
}

test "rpc method turn dispatcher filters pending accept disembargos without sinks" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        fn handle(_: void, _: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            return 0;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xcccc, .method_id = 12 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 152,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-method-no-sink-152",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 153,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-method-no-sink-153",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    const request_messages = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(request_messages);
    const response_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(response_messages);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    const disembargo_messages = [_]generated.Message.Builder{disembargo_root};

    var context: Context = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        &state,
        std.testing.allocator,
        response_messages,
        forward_messages,
        disembargo_messages[0..],
        request_messages,
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "filter-method-no-sink-153",
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 2), state.pendingAcceptEmbargoCount());

    var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
    try std.testing.expectEqualStrings("filter-method-no-sink-153", info.context.accept);
}

test "rpc method turn dispatcher reports apply details before handoff outputs" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 530;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            return question_id + 930;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        sent: usize = 0,
        last_question: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const call = try message.get_call();
            context.sent += 1;
            context.last_question = try call.get_questionId();
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x3333, .method_id = 3 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 410 });
    try state.resolveImportTo(410, .{ .sender_hosted = 411 });
    try state.applyCapDescriptor(.{ .sender_hosted = 411 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 73,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "turn-method-73",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 74);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(410);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x3333, .method_id = 3 }, call);
    const target = try call.init_target();
    try target.set_importedCap(410);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 3, 6 }, &.{.{ .sender_hosted = 412 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "turn-method-73" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };
    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{forward};
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingToDenseSinksFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(u32, 74), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 74 + 73), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 410), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 73), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 73), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1003);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 411 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 3, 6 });
    }
}

test "rpc method turn dispatcher sends pending accept disembargos with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 960;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const DisembargoSink = struct {
        sent: usize = 0,
        accept_contexts: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const disembargo = try message.get_disembargo();
            context.sent += 1;
            if ((try disembargo.which()) == .accept) context.accept_contexts += 1;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5555, .method_id = 5 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 106,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-release-106",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 107,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-pending-107",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-release-106" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var context: Context = .{};
    var response_sink: ResponseSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        &response_sink,
        ResponseSink.handle,
        {},
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &disembargo_sink,
        DisembargoSink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 106), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.accept_contexts);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 106), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 106), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 106), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1066);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-apply-pending-107", info.context.accept);
    }
}

test "rpc method turn dispatcher filters pending accept disembargos with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 980;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const DisembargoSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            _ = try message.get_disembargo();
            context.sent += 1;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x7777, .method_id = 7 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 112,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-release-112",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 113,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-pending-113",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-filter-release-112" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var context: Context = .{};
    var response_sink: ResponseSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        &response_sink,
        ResponseSink.handle,
        {},
        ForwardSink.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-apply-filter-pending-113",
        &disembargo_sink,
        DisembargoSink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 112), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 112), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 112), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 112), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1092);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-apply-filter-pending-113", info.context.accept);
    }
}

test "rpc method turn dispatcher filters pending accept disembargos without sinks with apply details" {
    const BootstrapHandler = struct {
        fn handle(_: void, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 990;
        }
    };
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| {
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
                .state_applied => {},
            }
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xdddd, .method_id = 13 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 156,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-no-sink-release-156",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 157,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-no-sink-pending-157",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-filter-no-sink-release-156" },
    });
    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request_message = generated.Message.fromReader(try request_reader.getRoot());
    const requests = [_]generated.Message{request_message};

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    const forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(forward_messages);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);

    const responses = [_]generated.Message.Builder{response};
    const disembargos = [_]generated.Message.Builder{disembargo};
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forward_messages,
        disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &context,
        entries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-apply-filter-no-sink-pending-157",
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 156), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 156), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 156), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1146);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-apply-filter-no-sink-pending-157", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 156,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-no-sink-release-156",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 157,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-no-sink-pending-157",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(queue_forward_messages);
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo = try generated.Message.initRootTyped(&queue_disembargo_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_disembargos = [_]generated.Message.Builder{queue_disembargo};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forward_messages,
        queue_disembargos[0..],
        requests[0..],
        {},
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        "method-apply-filter-no-sink-pending-157",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 156);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-apply-filter-no-sink-pending-157");
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 156), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}
