const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc turn dispatcher sends unified outputs to a single sink" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 500;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            return question_id + 900;
        }
    };
    const UnifiedSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            // The single-sink helper is a transport boundary: preserve the same
            // unified order that no-sink callers inspect in-place so an
            // embedder can enqueue responses, forwards, and Disembargos without
            // re-slicing the builder array itself.
            switch (context.sent) {
                0 => try support.expectQueuedReturnAnswer(message, 160),
                1 => try support.expectQueuedReturnAnswer(message, 161),
                2 => try support.expectQueuedForwardedCallBuilder(message, 805, .{ .imported_cap = 806 }),
                3 => try support.expectQueuedDisembargoBuilder(message, .{ .imported_cap = 5 }, "sink-unified-162"),
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 805 });
    try state.resolveImportTo(805, .{ .sender_hosted = 806 });
    try state.applyCapDescriptor(.{ .sender_hosted = 806 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 161,
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
            .question_id = 162,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "sink-unified-162",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 160);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(805);
    const target = try call.init_target();
    try target.set_importedCap(805);
    try cpz.rpc.initWireCallParamsText(call, "sink unified forward", &.{.{ .sender_hosted = 807 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const planned = try cpz.rpc.planRpcTurn(&state, requests[0..]);

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
    var unused_output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer unused_output_builder.deinit();
    const unused_output = try generated.Message.initRootTyped(&unused_output_builder);
    const outputs = [_]generated.Message.Builder{ output0, output1, output2, output3, unused_output };

    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var sink: UnifiedSink = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &sink,
        UnifiedSink.handle,
    );
    try std.testing.expectEqual(planned, applied);
    try std.testing.expectEqual(@as(usize, 4), sink.sent);
    try std.testing.expectEqual(@as(u32, 160), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqualStrings("sink unified forward", try (try (try forwarded.params()).content()).getText());
    }
    try std.testing.expectEqual(generated.Message.Union0.unimplemented, (try unused_output.which()).?);
}

test "rpc turn dispatcher appends unified outputs to a caller queue" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 500;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            return question_id + 900;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 825 });
    try state.resolveImportTo(825, .{ .sender_hosted = 826 });
    try state.applyCapDescriptor(.{ .sender_hosted = 826 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 181,
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
            .question_id = 182,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "queue-unified-182",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 180);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(825);
    const target = try call.init_target();
    try target.set_importedCap(825);
    try cpz.rpc.initWireCallParamsText(call, "queued unified forward", &.{.{ .sender_hosted = 827 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const planned = try cpz.rpc.planRpcTurn(&state, requests[0..]);
    try std.testing.expectEqual(@as(usize, 4), planned.totalOutputMessages());

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
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &queue,
    );
    try std.testing.expectEqual(planned, applied);
    try std.testing.expectEqual(@as(usize, 4), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 180);
    try support.expectQueuedReturnAnswer(queue.items[1], 181);
    try support.expectQueuedForwardedCallBuilder(queue.items[2], 825, .{ .imported_cap = 826 });
    try support.expectQueuedDisembargoBuilder(queue.items[3], .{ .imported_cap = 5 }, "queue-unified-182");
    try std.testing.expectEqual(@as(u32, 180), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    const MethodEntries = .{};
    var method_state = cpz.rpc.State.init(std.testing.allocator);
    defer method_state.deinit();
    try method_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 183,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-queue-unified-183",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try method_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    const empty_requests = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(empty_requests);
    var method_output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer method_output_builder.deinit();
    const method_output = try generated.Message.initRootTyped(&method_output_builder);
    const method_outputs = [_]generated.Message.Builder{method_output};
    var method_queue = std.ArrayList(generated.Message.Builder).empty;
    defer method_queue.deinit(std.testing.allocator);
    var method_bootstrap_seen: u32 = 0;
    const method_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueueFromHandlers(
        &method_state,
        std.testing.allocator,
        method_outputs[0..],
        empty_requests,
        &method_bootstrap_seen,
        BootstrapHandler.handle,
        {},
        MethodEntries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &method_queue,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, method_applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, method_applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), method_applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), method_queue.items.len);
    try support.expectQueuedDisembargoBuilder(method_queue.items[0], .{ .imported_cap = 5 }, "method-queue-unified-183");
    try std.testing.expectEqual(@as(u32, 0), method_bootstrap_seen);
}

test "rpc turn dispatchers send unified outputs to tagged sinks" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 500;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        fn handle(_: void, _: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            return 0;
        }
    };

    {
        const TaggedSink = struct {
            sent: usize = 0,

            fn handle(context: *@This(), position: cpz.rpc.RpcTurnOutputPosition, message: anytype) !void {
                switch (context.sent) {
                    0 => {
                        try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, position);
                        try support.expectQueuedReturnAnswer(message, 170);
                    },
                    1 => {
                        try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, position);
                        try support.expectQueuedForwardedCallBuilder(message, 815, .{ .imported_cap = 816 });
                    },
                    2 => {
                        try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, position);
                        try support.expectQueuedDisembargoBuilder(message, .{ .imported_cap = 5 }, "tagged-turn-172");
                    },
                    else => return error.TestUnexpectedResult,
                }
                context.sent += 1;
            }
        };

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        try state.applyCapDescriptor(.{ .sender_promise = 815 });
        try state.resolveImportTo(815, .{ .sender_hosted = 816 });
        try state.applyCapDescriptor(.{ .sender_hosted = 816 });

        {
            var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer builder.deinit();
            const root = try generated.Message.initRootTyped(&builder);
            try cpz.rpc.initWireAcceptMessage(root, .{
                .question_id = 172,
                .has_provision = true,
                .provision_max_capability_count = 1,
                .provision_capability = 0,
                .embargo = "tagged-turn-172",
            });
            var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
            try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
        }

        var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer bootstrap_builder.deinit();
        const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
        try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 170);
        var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
        const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

        var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer call_builder.deinit();
        const call_root = try generated.Message.initRootTyped(&call_builder);
        const call = try call_root.init_call();
        try call.set_questionId(815);
        const target = try call.init_target();
        try target.set_importedCap(815);
        try cpz.rpc.initWireCallParamsText(call, "tagged turn forward", &.{});
        var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
        const call_message = generated.Message.fromReader(try call_reader.getRoot());

        var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer output_builder0.deinit();
        const output0 = try generated.Message.initRootTyped(&output_builder0);
        var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer output_builder1.deinit();
        const output1 = try generated.Message.initRootTyped(&output_builder1);
        var output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer output_builder2.deinit();
        const output2 = try generated.Message.initRootTyped(&output_builder2);

        const requests = [_]generated.Message{ bootstrap_message, call_message };
        const outputs = [_]generated.Message.Builder{ output0, output1, output2 };
        const planned = try cpz.rpc.planRpcTurn(&state, requests[0..]);
        var bootstrap_seen: u32 = 0;
        var call_seen: u32 = 0;
        var sink: TaggedSink = .{};
        const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
            &state,
            std.testing.allocator,
            outputs[0..],
            requests[0..],
            &bootstrap_seen,
            BootstrapHandler.handle,
            &call_seen,
            CallHandler.handle,
            {},
            HandoffHandler.handle,
            {},
            HandoffHandler.handle,
            {},
            HandoffHandler.handle,
            .{ .imported_cap = 5 },
            &sink,
            TaggedSink.handle,
        );
        try std.testing.expectEqual(planned, applied);
        try std.testing.expectEqual(@as(usize, 3), sink.sent);
        try std.testing.expectEqual(@as(u32, 170), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), call_seen);

        var forward_reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        try support.expectQueuedForwardedCallText(generated.Message.fromReader(try forward_reader.getRoot()), 815, .{ .imported_cap = 816 }, "tagged turn forward");
    }

    {
        const TaggedSink = struct {
            sent: usize = 0,

            fn handle(context: *@This(), position: cpz.rpc.RpcTurnOutputPosition, message: anytype) !void {
                try std.testing.expectEqual(@as(usize, 0), context.sent);
                try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, position);
                try support.expectQueuedDisembargoBuilder(message, .{ .imported_cap = 5 }, "method-tagged-turn-173");
                context.sent += 1;
            }
        };
        const entries = .{};

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);

        {
            var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer builder.deinit();
            const root = try generated.Message.initRootTyped(&builder);
            try cpz.rpc.initWireAcceptMessage(root, .{
                .question_id = 173,
                .has_provision = true,
                .provision_max_capability_count = 1,
                .provision_capability = 0,
                .embargo = "method-tagged-turn-173",
            });
            var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
            try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
        }

        const requests = try std.testing.allocator.alloc(generated.Message, 0);
        defer std.testing.allocator.free(requests);
        var output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer output_builder.deinit();
        const output = try generated.Message.initRootTyped(&output_builder);
        const outputs = [_]generated.Message.Builder{output};

        var sink: TaggedSink = .{};
        var bootstrap_seen: u32 = 0;
        const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
            &state,
            std.testing.allocator,
            outputs[0..],
            requests,
            &bootstrap_seen,
            BootstrapHandler.handle,
            {},
            entries,
            {},
            HandoffHandler.handle,
            {},
            HandoffHandler.handle,
            {},
            HandoffHandler.handle,
            .{ .imported_cap = 5 },
            &sink,
            TaggedSink.handle,
        );
        try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
        try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
        try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
        try std.testing.expectEqual(@as(usize, 1), sink.sent);
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    }
}

test "rpc turn dispatcher appends tagged unified outputs to a caller queue" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 500;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };
    const HandoffHandler = struct {
        seen: usize = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            return question_id + 900;
        }
    };
    const TaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnOutputPosition,
        message: generated.Message.Builder,
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 835 });
    try state.resolveImportTo(835, .{ .sender_hosted = 836 });
    try state.applyCapDescriptor(.{ .sender_hosted = 836 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 191,
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
            .question_id = 192,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "tagged-queue-192",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 190);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(835);
    const target = try call.init_target();
    try target.set_importedCap(835);
    try cpz.rpc.initWireCallParamsText(call, "tagged queued forward", &.{.{ .sender_hosted = 837 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const planned = try cpz.rpc.planRpcTurn(&state, requests[0..]);

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
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var queue = std.ArrayList(TaggedQueueItem).empty;
    defer queue.deinit(std.testing.allocator);
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &queue,
    );
    try std.testing.expectEqual(planned, applied);
    try std.testing.expectEqual(@as(usize, 4), queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, queue.items[0].position);
    try support.expectQueuedReturnAnswer(queue.items[0].message, 190);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 1 }, queue.items[1].position);
    try support.expectQueuedReturnAnswer(queue.items[1].message, 191);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, queue.items[2].position);
    try support.expectQueuedForwardedCallBuilder(queue.items[2].message, 835, .{ .imported_cap = 836 });
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, queue.items[3].position);
    try support.expectQueuedDisembargoBuilder(queue.items[3].message, .{ .imported_cap = 5 }, "tagged-queue-192");
    try std.testing.expectEqual(@as(u32, 190), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    const MethodEntries = .{};
    var method_state = cpz.rpc.State.init(std.testing.allocator);
    defer method_state.deinit();
    try method_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 193,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-tagged-queue-193",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try method_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    const empty_requests = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(empty_requests);
    var method_output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer method_output_builder.deinit();
    const method_output = try generated.Message.initRootTyped(&method_output_builder);
    const method_outputs = [_]generated.Message.Builder{method_output};
    var method_queue = std.ArrayList(TaggedQueueItem).empty;
    defer method_queue.deinit(std.testing.allocator);
    var method_bootstrap_seen: u32 = 0;
    const method_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedQueueFromHandlers(
        &method_state,
        std.testing.allocator,
        method_outputs[0..],
        empty_requests,
        &method_bootstrap_seen,
        BootstrapHandler.handle,
        &provide_context,
        MethodEntries,
        &provide_context,
        HandoffHandler.handle,
        &accept_context,
        HandoffHandler.handle,
        &join_context,
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &method_queue,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, method_applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, method_applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), method_applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), method_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, method_queue.items[0].position);
    try support.expectQueuedDisembargoBuilder(method_queue.items[0].message, .{ .imported_cap = 5 }, "method-tagged-queue-193");
    try std.testing.expectEqual(@as(u32, 0), method_bootstrap_seen);
}

test "rpc turn dispatcher appends unified outputs to role queues" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 500;
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
            .question_id = 194,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "split-queue-194",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    const empty_requests = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(empty_requests);
    var output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder.deinit();
    const output = try generated.Message.initRootTyped(&output_builder);
    const outputs = [_]generated.Message.Builder{output};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    var bootstrap_seen: u32 = 0;
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
        empty_requests,
        &bootstrap_seen,
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
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 0), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "split-queue-194");
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);

    const method_entries = .{};
    var method_state = cpz.rpc.State.init(std.testing.allocator);
    defer method_state.deinit();
    try method_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 195,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-split-queue-195",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try method_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var method_output_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer method_output_builder.deinit();
    const method_output = try generated.Message.initRootTyped(&method_output_builder);
    const method_outputs = [_]generated.Message.Builder{method_output};
    var method_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer method_response_queue.deinit(std.testing.allocator);
    var method_forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer method_forward_queue.deinit(std.testing.allocator);
    var method_disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer method_disembargo_queue.deinit(std.testing.allocator);
    var method_bootstrap_seen: u32 = 0;
    const method_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
        &method_state,
        std.testing.allocator,
        method_outputs[0..],
        empty_requests,
        &method_bootstrap_seen,
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 5 },
        &method_response_queue,
        &method_forward_queue,
        &method_disembargo_queue,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, method_applied.dispatch);
    try std.testing.expectEqual(@as(usize, 1), method_applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 0), method_response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), method_forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), method_disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(method_disembargo_queue.items[0], .{ .imported_cap = 5 }, "method-split-queue-195");
    try std.testing.expectEqual(@as(u32, 0), method_bootstrap_seen);
}

test "rpc turn dispatcher fills dense outputs with apply details" {
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

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 680 });
    try state.resolveImportTo(680, .{ .sender_hosted = 681 });
    try state.applyCapDescriptor(.{ .sender_hosted = 681 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 131,
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
            .question_id = 132,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-apply-132",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 130);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(680);
    const target = try call.init_target();
    try target.set_importedCap(680);
    try cpz.rpc.initWireCallParamsText(call, "no-sink apply forward", &.{.{ .sender_hosted = 682 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "no-sink-apply-132" },
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
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingDenseFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
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
    try std.testing.expectEqual(@as(u32, 130), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 132), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 131), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 132), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 132), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1032);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 681 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("no-sink apply forward", try (try (try forwarded.params()).content()).getText());
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 680 });
    try queue_state.resolveImportTo(680, .{ .sender_hosted = 681 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 681 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 131,
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
            .question_id = 132,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-apply-132",
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
    var queue_response_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder2.deinit();
    const queue_response2 = try generated.Message.initRootTyped(&queue_response_builder2);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1, queue_response2 };
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingDenseToQueuesFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        &response_queue,
        &forward_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 130), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 3), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 130);
    try support.expectQueuedReturnAnswer(response_queue.items[1], 131);
    try support.expectQueuedReturnAnswer(response_queue.items[2], 132);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 680, .{ .imported_cap = 681 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 132), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc turn dispatcher fills unified dense outputs with apply details" {
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

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 690 });
    try state.resolveImportTo(690, .{ .sender_hosted = 691 });
    try state.applyCapDescriptor(.{ .sender_hosted = 691 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 133,
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
            .question_id = 134,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-no-sink-apply-134",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 132);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(690);
    const target = try call.init_target();
    try target.set_importedCap(690);
    try cpz.rpc.initWireCallParamsText(call, "unified no-sink apply forward", &.{.{ .sender_hosted = 692 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "unified-no-sink-apply-134" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    var output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder2.deinit();
    const output2 = try generated.Message.initRootTyped(&output_builder2);
    var output_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder3.deinit();
    const output3 = try generated.Message.initRootTyped(&output_builder3);
    const outputs = [_]generated.Message.Builder{ output0, output1, output2, output3 };

    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
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
    try std.testing.expectEqual(@as(usize, 0), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 4), applied.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 3 }, applied.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 3, .end = 4 }, applied.forwardedMessageRange());
    try std.testing.expectEqual(@as(u32, 132), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 134), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 133), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 134), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 132), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 632);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 133), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1033);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 134), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1034);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder3.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 691 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("unified no-sink apply forward", try (try (try forwarded.params()).content()).getText());
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 690 });
    try queue_state.resolveImportTo(690, .{ .sender_hosted = 691 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 691 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 133,
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
            .question_id = 134,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "unified-no-sink-apply-134",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    var queue_output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder2.deinit();
    const queue_output2 = try generated.Message.initRootTyped(&queue_output_builder2);
    var queue_output_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder3.deinit();
    const queue_output3 = try generated.Message.initRootTyped(&queue_output_builder3);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1, queue_output2, queue_output3 };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseToQueueFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &queue_provide_context,
        HandoffHandler.handle,
        &queue_accept_context,
        HandoffHandler.handle,
        &queue_join_context,
        HandoffHandler.handle,
        &output_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 132), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 4), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 132);
    try support.expectQueuedReturnAnswer(output_queue.items[1], 133);
    try support.expectQueuedReturnAnswer(output_queue.items[2], 134);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[3], 690, .{ .imported_cap = 691 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 134), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc method turn dispatcher fills dense outputs without sinks" {
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x8888, .method_id = 8 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 670 });
    try state.resolveImportTo(670, .{ .sender_hosted = 671 });
    try state.applyCapDescriptor(.{ .sender_hosted = 671 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 123,
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
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 122);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(670);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x8888, .method_id = 8 }, call);
    const target = try call.init_target();
    try target.set_importedCap(670);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 8, 16 }, &.{.{ .sender_hosted = 672 }});
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

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{forward};
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseFromHandlers(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
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
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(u32, 122), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 123), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 122), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 662);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 123), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1083);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 671 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 8, 16 });
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 670 });
    try queue_state.resolveImportTo(670, .{ .sender_hosted = 671 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 671 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 123,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = null,
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
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseToQueuesFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
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
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 122), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 122);
    try support.expectQueuedReturnAnswer(response_queue.items[1], 123);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 670, .{ .imported_cap = 671 });
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc method turn dispatcher fills unified dense outputs without sinks" {
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x8889, .method_id = 9 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 675 });
    try state.resolveImportTo(675, .{ .sender_hosted = 676 });
    try state.applyCapDescriptor(.{ .sender_hosted = 676 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 125,
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
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 124);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(675);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x8889, .method_id = 9 }, call);
    const target = try call.init_target();
    try target.set_importedCap(675);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 9, 18 }, &.{.{ .sender_hosted = 677 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurnMethods(&state, requests[0..], entries);
    try std.testing.expectEqual(@as(usize, 3), plan.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, plan.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, plan.forwardedMessageRange());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    var output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder2.deinit();
    const output2 = try generated.Message.initRootTyped(&output_builder2);

    const outputs = [_]generated.Message.Builder{ output0, output1, output2 };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlers(
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
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 124), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 125), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 124), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 664);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 125), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1085);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 676 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 9, 18 });
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 675 });
    try queue_state.resolveImportTo(675, .{ .sender_hosted = 676 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 676 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 125,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = null,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    var queue_output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder2.deinit();
    const queue_output2 = try generated.Message.initRootTyped(&queue_output_builder2);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1, queue_output2 };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseToQueueFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
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
        &output_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 124), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 3), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 124);
    try support.expectQueuedReturnAnswer(output_queue.items[1], 125);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[2], 675, .{ .imported_cap = 676 });
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc method turn dispatcher fills unified dense outputs with apply details" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 550;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x999a, .method_id = 10 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 695 });
    try state.resolveImportTo(695, .{ .sender_hosted = 696 });
    try state.applyCapDescriptor(.{ .sender_hosted = 696 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 127,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-apply-127",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 126);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(695);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x999a, .method_id = 10 }, call);
    const target = try call.init_target();
    try target.set_importedCap(695);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 10, 20 }, &.{.{ .sender_hosted = 697 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-unified-apply-127" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };
    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    var output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder2.deinit();
    const output2 = try generated.Message.initRootTyped(&output_builder2);

    const outputs = [_]generated.Message.Builder{ output0, output1, output2 };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseFromHandlersWithApplyHandler(
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
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 3), applied.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, applied.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, applied.forwardedMessageRange());
    try std.testing.expectEqual(@as(u32, 126), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 127), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 127), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 126), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 676);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 127), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1107);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 696 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 10, 20 });
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 695 });
    try queue_state.resolveImportTo(695, .{ .sender_hosted = 696 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 696 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 127,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-unified-apply-127",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    var queue_output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder2.deinit();
    const queue_output2 = try generated.Message.initRootTyped(&queue_output_builder2);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1, queue_output2 };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseToQueueFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
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
        &output_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 126), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 3), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 126);
    try support.expectQueuedReturnAnswer(output_queue.items[1], 127);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[2], 695, .{ .imported_cap = 696 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 127), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc method turn dispatcher fills dense outputs with apply details" {
    const BootstrapHandler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return bootstrap.questionId() + 550;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x9999, .method_id = 9 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 690 });
    try state.resolveImportTo(690, .{ .sender_hosted = 691 });
    try state.applyCapDescriptor(.{ .sender_hosted = 691 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 125,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-apply-125",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 124);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(690);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x9999, .method_id = 9 }, call);
    const target = try call.init_target();
    try target.set_importedCap(690);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 9, 18 }, &.{.{ .sender_hosted = 692 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-no-sink-apply-125" },
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
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    var apply_context: ApplyContext = .{};
    const applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
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
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .accepts = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(u32, 124), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 125), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 125), accept_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 124), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 674);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 125), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1105);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 691 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 9, 18 });
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 690 });
    try queue_state.resolveImportTo(690, .{ .sender_hosted = 691 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 691 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 125,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-no-sink-apply-125",
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
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnMethodsForwardingDenseToQueuesFromHandlersWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
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
        &response_queue,
        &forward_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 124), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 124);
    try support.expectQueuedReturnAnswer(response_queue.items[1], 125);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 690, .{ .imported_cap = 691 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 125), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(usize, 0), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}
