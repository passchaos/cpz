const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc method turn dispatcher filters pending accept disembargos into unified outputs with apply details" {
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xddde, .method_id = 14 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 162,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-unified-release-162",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
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
            .embargo = "method-apply-filter-unified-pending-163",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireDisembargoMessage(request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-filter-unified-release-162" },
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
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlersWithApplyHandler(
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
        "method-apply-filter-unified-pending-163",
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
    try std.testing.expectEqual(@as(u32, 162), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 162), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response_message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 162), (try response_message.return_()).answerId());
        try support.expectReturnCapabilityResult(response_message, 1152);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-apply-filter-unified-pending-163", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 164,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-queue-release-164",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
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
            .embargo = "method-apply-filter-queue-pending-165",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_request_builder.deinit();
    const queue_request_root = try generated.Message.initRootTyped(&queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-filter-queue-release-164" },
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
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    const queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlersWithApplyHandler(
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
        "method-apply-filter-queue-pending-165",
        &output_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 164);
    try support.expectQueuedDisembargoBuilder(output_queue.items[1], .{ .imported_cap = 5 }, "method-apply-filter-queue-pending-165");
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 164), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 164), queue_accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);

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
            .question_id = 166,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-tagged-queue-release-166",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
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
            .embargo = "method-apply-filter-tagged-queue-pending-167",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try tagged_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var tagged_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_request_builder.deinit();
    const tagged_queue_request_root = try generated.Message.initRootTyped(&tagged_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(tagged_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-filter-tagged-queue-release-166" },
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
    var tagged_queue_provide_context: HandoffHandler = .{};
    var tagged_queue_accept_context: HandoffHandler = .{};
    var tagged_queue_join_context: HandoffHandler = .{};
    var tagged_queue_apply_context: ApplyContext = .{};
    var tagged_output_queue = std.ArrayList(TaggedQueueItem).empty;
    defer tagged_output_queue.deinit(std.testing.allocator);
    const tagged_queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlersWithApplyHandler(
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
        "method-apply-filter-tagged-queue-pending-167",
        &tagged_output_queue,
        &tagged_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 1 }, tagged_queued.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, tagged_queued.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), tagged_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 2), tagged_output_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, tagged_output_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_output_queue.items[0].message, 166);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_output_queue.items[1].position);
    try support.expectQueuedDisembargoBuilder(tagged_output_queue.items[1].message, .{ .imported_cap = 5 }, "method-apply-filter-tagged-queue-pending-167");
    try std.testing.expectEqual(@as(u32, 0), tagged_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 166), tagged_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 166), tagged_queue_accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_queue_join_context.seen);

    var split_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer split_queue_state.deinit();
    try split_queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 168,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-split-queue-release-168",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 169,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-apply-filter-split-queue-pending-169",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try split_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var split_queue_request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_queue_request_builder.deinit();
    const split_queue_request_root = try generated.Message.initRootTyped(&split_queue_request_builder);
    try cpz.rpc.initWireDisembargoMessage(split_queue_request_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-apply-filter-split-queue-release-168" },
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
    var split_queue_provide_context: HandoffHandler = .{};
    var split_queue_accept_context: HandoffHandler = .{};
    var split_queue_join_context: HandoffHandler = .{};
    var split_queue_apply_context: ApplyContext = .{};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    const split_queued = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlersWithApplyHandler(
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
        "method-apply-filter-split-queue-pending-169",
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
    try support.expectQueuedReturnAnswer(response_queue.items[0], 168);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-apply-filter-split-queue-pending-169");
    try std.testing.expectEqual(@as(u32, 0), split_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), split_queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), split_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 168), split_queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), split_queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), split_queue_accept_context.seen);
    try std.testing.expectEqual(@as(u32, 168), split_queue_accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), split_queue_join_context.seen);
}

test "rpc tracked handoff batches preserve readiness gates" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireAcceptMessage(root, .{
        .question_id = 93,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "still-embargoed",
    });
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    var ready_ids = try state.readyHandoffIdsAlloc(std.testing.allocator);
    defer ready_ids.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), ready_ids.total());
    try std.testing.expect(!ready_ids.hasReturns());
    const blocked_accepts = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 93, .export_id = 393 }};
    try std.testing.expectError(error.InvalidTransition, state.readyHandoffReturnsAlloc(std.testing.allocator, .{ .accepts = blocked_accepts[0..] }));

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    const responses = [_]generated.Message.Builder{response_root};
    const completions = [_]cpz.rpc.HandoffReturn{
        .{ .accept = .{ .question_id = 93, .export_id = 393 } },
    };
    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessages(responses[0..], completions[0..]));
}

test "rpc handoff return batches send initialized messages to sinks" {
    const Sink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var response_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder2.deinit();
    const response2 = try generated.Message.initRootTyped(&response_builder2);

    const responses = [_]generated.Message.Builder{ response0, response1, response2 };
    const completions = [_]cpz.rpc.HandoffReturn{
        .{ .provide = .{ .question_id = 94, .export_id = 394 } },
        .{ .accept = .{ .question_id = 95, .export_id = 395 } },
        .{ .join = .{ .question_id = 96, .export_id = 396 } },
    };
    var sink: Sink = .{};
    const stats = try cpz.rpc.initWireHandoffReturnMessagesToSink(responses[0..], completions[0..], &sink, Sink.handle);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 3), sink.sent);
    try std.testing.expectEqual(@as(u32, 94 + 95 + 96), sink.answer_sum);

    {
        var response_reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
        try support.expectReturnCapabilityResult(response, 396);
    }

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToSink(responses[0..2], completions[0..], &sink, Sink.handle));

    var tagged_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder0.deinit();
    const tagged_response0 = try generated.Message.initRootTyped(&tagged_builder0);
    var tagged_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder1.deinit();
    const tagged_response1 = try generated.Message.initRootTyped(&tagged_builder1);
    var tagged_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder2.deinit();
    const tagged_response2 = try generated.Message.initRootTyped(&tagged_builder2);
    var tagged_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder3.deinit();
    const tagged_response3 = try generated.Message.initRootTyped(&tagged_builder3);
    const tagged_responses = [_]generated.Message.Builder{ tagged_response0, tagged_response1, tagged_response2, tagged_response3 };
    const mixed_completions = [_]cpz.rpc.HandoffReturn{
        .{ .provide = .{ .question_id = 94, .export_id = 394 } },
        .{ .join = .{ .question_id = 96, .export_id = 396 } },
        .{ .provide = .{ .question_id = 94, .export_id = 394 } },
        .{ .accept = .{ .question_id = 95, .export_id = 395 } },
    };
    const TaggedWireSink = struct {
        sent: usize = 0,
        positions: [4]cpz.rpc.HandoffReturnOutputPosition = undefined,
        answer_ids: [4]u32 = undefined,

        fn handle(context: *@This(), position: cpz.rpc.HandoffReturnOutputPosition, message: anytype) !void {
            context.positions[context.sent] = position;
            context.answer_ids[context.sent] = try (try message.get_return_()).get_answerId();
            context.sent += 1;
        }
    };
    var tagged_wire_sink: TaggedWireSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToTaggedSink(
        tagged_responses[0..3],
        mixed_completions[0..],
        &tagged_wire_sink,
        TaggedWireSink.handle,
    ));
    const tagged_stats = try cpz.rpc.initWireHandoffReturnMessagesToTaggedSink(
        tagged_responses[0..],
        mixed_completions[0..],
        &tagged_wire_sink,
        TaggedWireSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, tagged_stats);
    try std.testing.expectEqual(@as(usize, 4), tagged_wire_sink.sent);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, tagged_wire_sink.positions[0]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, tagged_wire_sink.positions[1]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 1 }, tagged_wire_sink.positions[2]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, tagged_wire_sink.positions[3]);
    try std.testing.expectEqual(@as(u32, 94), tagged_wire_sink.answer_ids[0]);
    try std.testing.expectEqual(@as(u32, 96), tagged_wire_sink.answer_ids[1]);
    try std.testing.expectEqual(@as(u32, 94), tagged_wire_sink.answer_ids[2]);
    try std.testing.expectEqual(@as(u32, 95), tagged_wire_sink.answer_ids[3]);

    var tagged_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder0.deinit();
    const tagged_queue_response0 = try generated.Message.initRootTyped(&tagged_queue_builder0);
    var tagged_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder1.deinit();
    const tagged_queue_response1 = try generated.Message.initRootTyped(&tagged_queue_builder1);
    var tagged_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder2.deinit();
    const tagged_queue_response2 = try generated.Message.initRootTyped(&tagged_queue_builder2);
    var tagged_queue_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder3.deinit();
    const tagged_queue_response3 = try generated.Message.initRootTyped(&tagged_queue_builder3);
    const tagged_queue_responses = [_]generated.Message.Builder{ tagged_queue_response0, tagged_queue_response1, tagged_queue_response2, tagged_queue_response3 };
    const TaggedWireQueueItem = struct {
        position: cpz.rpc.HandoffReturnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_wire_queue = std.ArrayList(TaggedWireQueueItem).empty;
    defer tagged_wire_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..3],
        mixed_completions[0..],
        &tagged_wire_queue,
    ));
    const tagged_queue_stats = try cpz.rpc.initWireHandoffReturnMessagesToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..],
        mixed_completions[0..],
        &tagged_wire_queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, tagged_queue_stats);
    try std.testing.expectEqual(@as(usize, 4), tagged_wire_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, tagged_wire_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_wire_queue.items[0].message, 94);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, tagged_wire_queue.items[1].position);
    try support.expectQueuedReturnAnswer(tagged_wire_queue.items[1].message, 96);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 1 }, tagged_wire_queue.items[2].position);
    try support.expectQueuedReturnAnswer(tagged_wire_queue.items[2].message, 94);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, tagged_wire_queue.items[3].position);
    try support.expectQueuedReturnAnswer(tagged_wire_queue.items[3].message, 95);

    var role_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder0.deinit();
    const role_sink_response0 = try generated.Message.initRootTyped(&role_sink_builder0);
    var role_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder1.deinit();
    const role_sink_response1 = try generated.Message.initRootTyped(&role_sink_builder1);
    var role_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder2.deinit();
    const role_sink_response2 = try generated.Message.initRootTyped(&role_sink_builder2);
    var role_sink_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder3.deinit();
    const role_sink_response3 = try generated.Message.initRootTyped(&role_sink_builder3);
    const role_sink_responses = [_]generated.Message.Builder{ role_sink_response0, role_sink_response1, role_sink_response2, role_sink_response3 };
    const RoleWireSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    var provide_role_sink: RoleWireSink = .{};
    var accept_role_sink: RoleWireSink = .{};
    var join_role_sink: RoleWireSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToSinks(
        role_sink_responses[0..3],
        mixed_completions[0..],
        &provide_role_sink,
        RoleWireSink.handle,
        &accept_role_sink,
        RoleWireSink.handle,
        &join_role_sink,
        RoleWireSink.handle,
    ));
    const role_sink_stats = try cpz.rpc.initWireHandoffReturnMessagesToSinks(
        role_sink_responses[0..],
        mixed_completions[0..],
        &provide_role_sink,
        RoleWireSink.handle,
        &accept_role_sink,
        RoleWireSink.handle,
        &join_role_sink,
        RoleWireSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, role_sink_stats);
    try std.testing.expectEqual(@as(usize, 2), provide_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 94 + 94), provide_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 95), accept_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), join_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 96), join_role_sink.answer_sum);

    var role_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder0.deinit();
    const role_queue_response0 = try generated.Message.initRootTyped(&role_queue_builder0);
    var role_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder1.deinit();
    const role_queue_response1 = try generated.Message.initRootTyped(&role_queue_builder1);
    var role_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder2.deinit();
    const role_queue_response2 = try generated.Message.initRootTyped(&role_queue_builder2);
    var role_queue_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder3.deinit();
    const role_queue_response3 = try generated.Message.initRootTyped(&role_queue_builder3);
    const role_queue_responses = [_]generated.Message.Builder{ role_queue_response0, role_queue_response1, role_queue_response2, role_queue_response3 };
    var provide_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer provide_role_queue.deinit(std.testing.allocator);
    var accept_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer accept_role_queue.deinit(std.testing.allocator);
    var join_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer join_role_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToQueues(
        std.testing.allocator,
        role_queue_responses[0..3],
        mixed_completions[0..],
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    ));
    const role_queue_stats = try cpz.rpc.initWireHandoffReturnMessagesToQueues(
        std.testing.allocator,
        role_queue_responses[0..],
        mixed_completions[0..],
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, role_queue_stats);
    try std.testing.expectEqual(@as(usize, 2), provide_role_queue.items.len);
    try support.expectQueuedReturnAnswer(provide_role_queue.items[0], 94);
    try support.expectQueuedReturnAnswer(provide_role_queue.items[1], 94);
    try std.testing.expectEqual(@as(usize, 1), accept_role_queue.items.len);
    try support.expectQueuedReturnAnswer(accept_role_queue.items[0], 95);
    try std.testing.expectEqual(@as(usize, 1), join_role_queue.items.len);
    try support.expectQueuedReturnAnswer(join_role_queue.items[0], 96);

    var queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_builder0);
    var queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_builder1);
    var queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder2.deinit();
    const queue_response2 = try generated.Message.initRootTyped(&queue_builder2);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1, queue_response2 };
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    const queue_stats = try cpz.rpc.initWireHandoffReturnMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..],
        completions[0..],
        &queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, queue_stats);
    try std.testing.expectEqual(@as(usize, 3), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 94);
    try support.expectQueuedReturnAnswer(queue.items[1], 95);
    try support.expectQueuedReturnAnswer(queue.items[2], 96);
    {
        var reader = cpz.MessageReader.init(try queue_builder0.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try reader.getRoot()), 394);
    }
    {
        var reader = cpz.MessageReader.init(try queue_builder1.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try reader.getRoot()), 395);
    }
    {
        var reader = cpz.MessageReader.init(try queue_builder2.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try reader.getRoot()), 396);
    }
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..2],
        completions[0..],
        &queue,
    ));
}

test "rpc tracked handoff return sink preserves readiness gates" {
    const Sink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(400);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 97,
            .target = .{ .imported_cap = 400 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response = try generated.Message.initRootTyped(&response_builder);
        const responses = [_]generated.Message.Builder{response};
        const completions = [_]cpz.rpc.HandoffReturn{
            .{ .provide = .{ .question_id = 97, .export_id = 397 } },
        };
        var sink: Sink = .{};
        const stats = try state.initTrackedHandoffReturnMessagesToSink(responses[0..], completions[0..], &sink, Sink.handle);
        try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, stats);
        try std.testing.expectEqual(@as(usize, 1), sink.sent);
        try std.testing.expectEqual(@as(u32, 97), sink.last_answer);
    }
    {
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response = try generated.Message.initRootTyped(&response_builder);
        const responses = [_]generated.Message.Builder{response};
        const completions = [_]cpz.rpc.HandoffReturn{
            .{ .provide = .{ .question_id = 97, .export_id = 397 } },
        };
        var queue = std.ArrayList(generated.Message.Builder).empty;
        defer queue.deinit(std.testing.allocator);
        const stats = try state.initTrackedHandoffReturnMessagesToQueue(
            std.testing.allocator,
            responses[0..],
            completions[0..],
            &queue,
        );
        try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, stats);
        try std.testing.expectEqual(@as(usize, 1), queue.items.len);
        try support.expectQueuedReturnAnswer(queue.items[0], 97);
        var reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try reader.getRoot()), 397);
    }

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 98,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "blocked-sink",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response = try generated.Message.initRootTyped(&response_builder);
        const responses = [_]generated.Message.Builder{response};
        const completions = [_]cpz.rpc.HandoffReturn{
            .{ .accept = .{ .question_id = 98, .export_id = 398 } },
        };
        var sink: Sink = .{};
        try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessagesToSink(responses[0..], completions[0..], &sink, Sink.handle));
        try std.testing.expectEqual(@as(usize, 0), sink.sent);

        var queue = std.ArrayList(generated.Message.Builder).empty;
        defer queue.deinit(std.testing.allocator);
        try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessagesToQueue(
            std.testing.allocator,
            responses[0..],
            completions[0..],
            &queue,
        ));
        try std.testing.expectEqual(@as(usize, 0), queue.items.len);
    }
}

test "rpc disembargo helpers decode targets and loopback contexts" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const disembargo = try root.init_disembargo();
        const target = try disembargo.init_target();
        try target.set_importedCap(74);
        try disembargo.set_senderLoopback(75);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try message.disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 74 }, info.target);
        try std.testing.expectEqual(cpz.rpc.DisembargoContext{ .sender_loopback = 75 }, info.context);
        const event = try cpz.rpc.eventFromWireMessage(message);
        try std.testing.expectEqual(
            cpz.rpc.WireEvent{ .disembargo = .{ .target = .{ .imported_cap = 74 }, .context = .{ .sender_loopback = 75 } } },
            event,
        );

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.InvalidTransition, state.validateWireDisembargo(try message.disembargo()));
        try std.testing.expectError(error.InvalidTransition, state.applyWireMessage(std.testing.allocator, message));
        try state.addImport(74);
        try state.applyWireMessage(std.testing.allocator, message);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const disembargo = try root.init_disembargo();
        const target = try disembargo.init_target();
        const promised = try target.init_promisedAnswer();
        try promised.set_questionId(76);
        try disembargo.set_receiverLoopback(77);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try message.disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 76 } }, info.target);
        try std.testing.expectEqual(cpz.rpc.DisembargoContext{ .receiver_loopback = 77 }, info.context);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const disembargo = try root.init_disembargo();
        const target = try disembargo.init_target();
        try target.set_importedCap(80);
        try disembargo.set_accept("accept-embargo");

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try message.disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 80 }, info.target);
        try std.testing.expectEqualStrings("accept-embargo", info.context.accept);
        const event = try cpz.rpc.eventFromWireMessage(message);
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 80 }, event.disembargo.target);
        try std.testing.expectEqualStrings("accept-embargo", event.disembargo.context.accept);
    }
}

test "rpc disembargo helpers write targets and loopback contexts" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const disembargo = try generated.Disembargo.initRootTyped(&builder);
    try cpz.rpc.writeDisembargoInfoToWire(.{
        .target = .{ .imported_cap = 78 },
        .context = .{ .receiver_loopback = 79 },
    }, disembargo);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const disembargo_reader = generated.Disembargo.fromReader(try reader.getRoot());
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(disembargo_reader);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 78 }, info.target);
    try std.testing.expectEqual(cpz.rpc.DisembargoContext{ .receiver_loopback = 79 }, info.context);
    try std.testing.expect(info.context.isReceiverLoopback());
    try std.testing.expectEqual(@as(?u32, 79), info.context.receiverLoopbackId());
    try std.testing.expectEqual(@as(?u32, null), info.context.senderLoopbackId());
}

test "rpc disembargo helpers write accept contexts" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const disembargo = try generated.Disembargo.initRootTyped(&builder);
    try cpz.rpc.writeDisembargoInfoToWire(.{
        .target = .{ .imported_cap = 81 },
        .context = .{ .accept = "accept-write" },
    }, disembargo);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const disembargo_reader = generated.Disembargo.fromReader(try reader.getRoot());
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(disembargo_reader);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 81 }, info.target);
    try std.testing.expectEqualStrings("accept-write", info.context.accept);
    try std.testing.expect(info.context.isAccept());
    try std.testing.expect(info.isAcceptEmbargo());
    try std.testing.expectEqualStrings("accept-write", info.context.acceptEmbargo().?);
    try std.testing.expect(info.context.matchesAcceptEmbargo("accept-write"));
    try std.testing.expect(info.matchesAcceptEmbargo("accept-write"));
    try std.testing.expect(!info.matchesAcceptEmbargo("missing"));
}

test "rpc disembargo batches initialize and send messages to sinks" {
    const Sink = struct {
        sent: usize = 0,
        accept_contexts: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const disembargo = try message.get_disembargo();
            context.sent += 1;
            if ((try disembargo.which()) == .accept) context.accept_contexts += 1;
        }
    };

    var builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder0.deinit();
    const root0 = try generated.Message.initRootTyped(&builder0);
    var builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder1.deinit();
    const root1 = try generated.Message.initRootTyped(&builder1);

    const messages = [_]generated.Message.Builder{ root0, root1 };
    const infos = [_]cpz.rpc.DisembargoInfo{
        .{ .target = .{ .imported_cap = 82 }, .context = .{ .sender_loopback = 83 } },
        .{ .target = .{ .imported_cap = 84 }, .context = .{ .accept = "accept-batch" } },
    };
    try std.testing.expectEqual(@as(usize, 2), try cpz.rpc.initWireDisembargoMessages(messages[0..], infos[0..]));

    {
        var reader = cpz.MessageReader.init(try builder0.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 82 }, info.target);
        try std.testing.expectEqual(cpz.rpc.DisembargoContext{ .sender_loopback = 83 }, info.context);
    }
    {
        var reader = cpz.MessageReader.init(try builder1.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 84 }, info.target);
        try std.testing.expectEqualStrings("accept-batch", info.context.accept);
    }

    var sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_builder0.deinit();
    const sink_root0 = try generated.Message.initRootTyped(&sink_builder0);
    var sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_builder1.deinit();
    const sink_root1 = try generated.Message.initRootTyped(&sink_builder1);
    const sink_messages = [_]generated.Message.Builder{ sink_root0, sink_root1 };

    var sink: Sink = .{};
    try std.testing.expectEqual(@as(usize, 2), try cpz.rpc.initWireDisembargoMessagesToSink(sink_messages[0..], infos[0..], &sink, Sink.handle));
    try std.testing.expectEqual(@as(usize, 2), sink.sent);
    try std.testing.expectEqual(@as(usize, 1), sink.accept_contexts);

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireDisembargoMessagesToSink(sink_messages[0..1], infos[0..], &sink, Sink.handle));

    var queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder0.deinit();
    const queue_root0 = try generated.Message.initRootTyped(&queue_builder0);
    var queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder1.deinit();
    const queue_root1 = try generated.Message.initRootTyped(&queue_builder1);
    const queue_messages = [_]generated.Message.Builder{ queue_root0, queue_root1 };
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        @as(usize, 2),
        try cpz.rpc.initWireDisembargoMessagesToQueue(std.testing.allocator, queue_messages[0..], infos[0..], &queue),
    );
    try std.testing.expectEqual(@as(usize, 2), queue.items.len);
    {
        const disembargo = try queue.items[0].get_disembargo();
        const target = try disembargo.get_target();
        try std.testing.expectEqual(generated.MessageTarget.Union0.importedCap, (try target.which()).?);
        try std.testing.expectEqual(@as(u32, 82), try target.get_importedCap());
        try std.testing.expectEqual(@as(u32, 83), try disembargo.get_senderLoopback());
    }
    try support.expectQueuedDisembargoBuilder(queue.items[1], .{ .imported_cap = 84 }, "accept-batch");
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireDisembargoMessagesToQueue(
        std.testing.allocator,
        queue_messages[0..1],
        infos[0..],
        &queue,
    ));
}

test "rpc turn helper sends pending accept disembargos to a sink" {
    const Sink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), _: anytype) !void {
            context.sent += 1;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 76,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "turn-disembargo-76",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var accept_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder2.deinit();
    const accept_root2 = try generated.Message.initRootTyped(&accept_builder2);
    try cpz.rpc.initWireAcceptMessage(accept_root2, .{
        .question_id = 77,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "turn-disembargo-77",
    });
    var accept_reader2 = cpz.MessageReader.init(try accept_builder2.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader2.getRoot()));

    const no_turn_messages = [_]generated.Message{};
    const plan = try cpz.rpc.planRpcTurn(&state, no_turn_messages[0..]);
    try std.testing.expectEqual(@as(usize, 2), plan.disembargoMessages());

    var short_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer short_builder.deinit();
    const short_root = try generated.Message.initRootTyped(&short_builder);
    const short_messages = [_]generated.Message.Builder{short_root};
    var short_sink: Sink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosToSink(
        &state,
        short_messages[0..],
        .{ .imported_cap = 5 },
        &short_sink,
        Sink.handle,
    ));
    try std.testing.expectEqual(@as(usize, 0), short_sink.sent);

    var disembargo_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder0.deinit();
    const disembargo_root0 = try generated.Message.initRootTyped(&disembargo_builder0);
    var disembargo_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder1.deinit();
    const disembargo_root1 = try generated.Message.initRootTyped(&disembargo_builder1);
    const disembargo_messages = [_]generated.Message.Builder{ disembargo_root0, disembargo_root1 };
    var sink: Sink = .{};
    try std.testing.expectEqual(
        @as(usize, 2),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosToSink(
            &state,
            disembargo_messages[0..],
            .{ .imported_cap = 5 },
            &sink,
            Sink.handle,
        ),
    );
    try std.testing.expectEqual(@as(usize, 2), sink.sent);

    var seen_76 = false;
    var seen_77 = false;
    {
        var reader = cpz.MessageReader.init(try disembargo_builder0.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        if (std.mem.eql(u8, info.context.accept, "turn-disembargo-76")) seen_76 = true;
        if (std.mem.eql(u8, info.context.accept, "turn-disembargo-77")) seen_77 = true;
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder1.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        if (std.mem.eql(u8, info.context.accept, "turn-disembargo-76")) seen_76 = true;
        if (std.mem.eql(u8, info.context.accept, "turn-disembargo-77")) seen_77 = true;
    }
    try std.testing.expect(seen_76);
    try std.testing.expect(seen_77);

    var no_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer no_sink_builder0.deinit();
    const no_sink_root0 = try generated.Message.initRootTyped(&no_sink_builder0);
    var no_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer no_sink_builder1.deinit();
    const no_sink_root1 = try generated.Message.initRootTyped(&no_sink_builder1);
    const no_sink_messages = [_]generated.Message.Builder{ no_sink_root0, no_sink_root1 };
    try std.testing.expectEqual(
        @as(usize, 2),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargos(
            &state,
            no_sink_messages[0..],
            .{ .imported_cap = 5 },
        ),
    );

    var queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder0.deinit();
    const queue_root0 = try generated.Message.initRootTyped(&queue_builder0);
    var queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder1.deinit();
    const queue_root1 = try generated.Message.initRootTyped(&queue_builder1);
    const queue_messages = [_]generated.Message.Builder{ queue_root0, queue_root1 };
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        @as(usize, 2),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosToQueue(
            &state,
            std.testing.allocator,
            queue_messages[0..],
            .{ .imported_cap = 5 },
            &queue,
        ),
    );
    try std.testing.expectEqual(@as(usize, 2), queue.items.len);
    var queued_seen_76 = false;
    var queued_seen_77 = false;
    for (queue.items) |queued_message| {
        const disembargo = try queued_message.get_disembargo();
        const target = try disembargo.get_target();
        try std.testing.expectEqual(generated.MessageTarget.Union0.importedCap, (try target.which()).?);
        try std.testing.expectEqual(@as(u32, 5), try target.get_importedCap());
        const token = (try disembargo.get_acceptOrNull()) orelse "";
        if (std.mem.eql(u8, token, "turn-disembargo-76")) queued_seen_76 = true;
        if (std.mem.eql(u8, token, "turn-disembargo-77")) queued_seen_77 = true;
    }
    try std.testing.expect(queued_seen_76);
    try std.testing.expect(queued_seen_77);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosToQueue(
        &state,
        std.testing.allocator,
        short_messages[0..],
        .{ .imported_cap = 5 },
        &queue,
    ));

    var filtered_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer filtered_builder.deinit();
    const filtered_root = try generated.Message.initRootTyped(&filtered_builder);
    const filtered_messages = [_]generated.Message.Builder{filtered_root};
    var filtered_sink: Sink = .{};
    try std.testing.expectEqual(
        @as(usize, 1),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosForEmbargoToSink(
            &state,
            filtered_messages[0..],
            .{ .imported_cap = 5 },
            "turn-disembargo-76",
            &filtered_sink,
            Sink.handle,
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), filtered_sink.sent);
    var filtered_reader = cpz.MessageReader.init(try filtered_builder.segmentsConst(), .{});
    const filtered_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try filtered_reader.getRoot()).disembargo());
    try std.testing.expectEqualStrings("turn-disembargo-76", filtered_info.context.accept);

    var filtered_no_sink_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer filtered_no_sink_builder.deinit();
    const filtered_no_sink_root = try generated.Message.initRootTyped(&filtered_no_sink_builder);
    const filtered_no_sink_messages = [_]generated.Message.Builder{filtered_no_sink_root};
    try std.testing.expectEqual(
        @as(usize, 1),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosForEmbargo(
            &state,
            filtered_no_sink_messages[0..],
            .{ .imported_cap = 5 },
            "turn-disembargo-77",
        ),
    );
    var filtered_no_sink_reader = cpz.MessageReader.init(try filtered_no_sink_builder.segmentsConst(), .{});
    const filtered_no_sink_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try filtered_no_sink_reader.getRoot()).disembargo());
    try std.testing.expectEqualStrings("turn-disembargo-77", filtered_no_sink_info.context.accept);

    var filtered_queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer filtered_queue_builder.deinit();
    const filtered_queue_root = try generated.Message.initRootTyped(&filtered_queue_builder);
    const filtered_queue_messages = [_]generated.Message.Builder{filtered_queue_root};
    var filtered_queue = std.ArrayList(generated.Message.Builder).empty;
    defer filtered_queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        @as(usize, 1),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosForEmbargoToQueue(
            &state,
            std.testing.allocator,
            filtered_queue_messages[0..],
            .{ .imported_cap = 5 },
            "turn-disembargo-76",
            &filtered_queue,
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), filtered_queue.items.len);
    try support.expectQueuedDisembargoBuilder(filtered_queue.items[0], .{ .imported_cap = 5 }, "turn-disembargo-76");
    try std.testing.expectEqual(
        @as(usize, 0),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosForEmbargoToQueue(
            &state,
            std.testing.allocator,
            filtered_queue_messages[0..],
            .{ .imported_cap = 5 },
            "missing",
            &filtered_queue,
        ),
    );

    var missing_sink: Sink = .{};
    try std.testing.expectEqual(
        @as(usize, 0),
        try cpz.rpc.dispatchRpcTurnPendingAcceptDisembargosForEmbargoToSink(
            &state,
            filtered_messages[0..],
            .{ .imported_cap = 5 },
            "missing",
            &missing_sink,
            Sink.handle,
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), missing_sink.sent);
}

test "rpc accept info helpers write question ids and embargoes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const accept = try generated.Accept.initRootTyped(&builder);
        try cpz.rpc.writeAcceptInfoToWire(.{ .question_id = 66, .has_provision = false, .provision_max_capability_count = 0, .embargo = "embargo-66" }, accept);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const accept_reader = generated.Accept.fromReader(try reader.getRoot());
        const info = try cpz.rpc.acceptInfoFromWireAccept(accept_reader);
        try std.testing.expectEqual(@as(u32, 66), info.question_id);
        try std.testing.expectEqualStrings("embargo-66", info.embargo.?);
        try std.testing.expect(!info.hasProvisionUsage());
        try std.testing.expect(info.hasEmbargo());
        try std.testing.expect(info.matchesEmbargo("embargo-66"));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const accept = try generated.Accept.initRootTyped(&builder);
        try cpz.rpc.writeAcceptInfoToWire(.{ .question_id = 67, .has_provision = false, .provision_max_capability_count = 0, .embargo = null }, accept);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const accept_reader = generated.Accept.fromReader(try reader.getRoot());
        const info = try cpz.rpc.acceptInfoFromWireAccept(accept_reader);
        try std.testing.expectEqual(@as(u32, 67), info.question_id);
        try std.testing.expect(info.embargo == null);
        try std.testing.expect(!info.hasEmbargo());
        try std.testing.expect(!info.matchesEmbargo("embargo-67"));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const accept = try generated.Accept.initRootTyped(&builder);
        try cpz.rpc.writeAcceptInfoToWire(.{
            .question_id = 68,
            .has_provision = true,
            .provision_max_capability_count = 4,
            .provision_capability = 3,
            .embargo = "embargo-68",
        }, accept);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const accept_reader = generated.Accept.fromReader(try reader.getRoot());
        const info = try cpz.rpc.acceptInfoFromWireAccept(accept_reader);
        try std.testing.expectEqual(@as(u32, 68), info.question_id);
        try std.testing.expect(info.has_provision);
        try std.testing.expectEqual(@as(usize, 4), info.provision_max_capability_count);
        try std.testing.expectEqual(@as(?u32, 3), info.provision_capability);
        try std.testing.expectEqualStrings("embargo-68", info.embargo.?);
        try std.testing.expect(info.hasProvisionUsage());
        try std.testing.expect(info.provisionMatchesCapability(3));
    }
}

test "rpc accept info reports provision capability usage" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const accept = try generated.Accept.initRootTyped(&builder);
    try accept.set_questionId(68);
    (try accept.get_provisionAsPointer()).setCapability(2);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const accept_reader = generated.Accept.fromReader(try reader.getRoot());
    const info = try cpz.rpc.acceptInfoFromWireAccept(accept_reader);
    try std.testing.expectEqual(@as(u32, 68), info.question_id);
    try std.testing.expect(info.has_provision);
    try std.testing.expectEqual(@as(usize, 3), info.provision_max_capability_count);
    try std.testing.expectEqual(@as(?u32, 2), info.provision_capability);
    try std.testing.expect(info.hasProvisionUsage());
    try std.testing.expect(info.provisionMatchesCapability(2));
}

test "rpc provide accept and join wire events open questions" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_provide();
        try payload.set_questionId(22);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .provide = 22 }, event);
        try std.testing.expect(event.toStateEvent() == null);
        try state.applyWireEvent(event);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(22));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_accept();
        try payload.set_questionId(23);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .accept = 23 }, event);
        try std.testing.expect(event.toStateEvent() == null);
        try state.applyWireEvent(event);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(23));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_join();
        try payload.set_questionId(25);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .join = 25 }, event);
        try std.testing.expect(event.toStateEvent() == null);
        try state.applyWireEvent(event);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(25));
    }
}
