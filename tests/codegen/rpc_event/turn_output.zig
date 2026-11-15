const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc single-message dispatcher queues responses while reporting apply details" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 4100;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
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

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 240,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "single-queue-apply-240",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 241);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var apply_context: ApplyContext = .{};
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, try cpz.rpc.dispatchWireMessageToQueueOutcomeWithApplyHandler(
        &state,
        std.testing.allocator,
        response,
        bootstrap_message,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &queue,
        &apply_context,
        ApplyContext.handle,
    ));
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 241);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 0), apply_context.calls);

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "single-queue-apply-240" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());
    var unused_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer unused_response_builder.deinit();
    const unused_response = try generated.Message.initRootTyped(&unused_response_builder);
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.state_applied, try cpz.rpc.dispatchWireMessageToQueueOutcomeWithApplyHandler(
        &state,
        std.testing.allocator,
        unused_response,
        disembargo_message,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &queue,
        &apply_context,
        ApplyContext.handle,
    ));
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 240), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(240));
}

test "rpc single-message method dispatcher queues responses while reporting apply details" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 4400;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x4400, .method_id = 4 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 260,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "single-method-queue-apply-260",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(261);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x4400, .method_id = 4 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var apply_context: ApplyContext = .{};
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, try cpz.rpc.dispatchWireMessageMethodsToQueueOutcomeWithApplyHandler(
        &state,
        std.testing.allocator,
        response,
        call_message,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &queue,
        &apply_context,
        ApplyContext.handle,
    ));
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 261), context.selected);
    try std.testing.expectEqual(@as(usize, 0), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 261);

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "single-method-queue-apply-260" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());
    var unused_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer unused_response_builder.deinit();
    const unused_response = try generated.Message.initRootTyped(&unused_response_builder);
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.state_applied, try cpz.rpc.dispatchWireMessageMethodsToQueueOutcomeWithApplyHandler(
        &state,
        std.testing.allocator,
        unused_response,
        disembargo_message,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &queue,
        &apply_context,
        ApplyContext.handle,
    ));
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 260), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(260));
}

test "rpc single-message forwarding dispatcher queues forwards while reporting apply details" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 4300;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
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
    try state.applyCapDescriptor(.{ .sender_promise = 250 });
    try state.resolveImportTo(250, .{ .sender_hosted = 251 });
    try state.applyCapDescriptor(.{ .sender_hosted = 251 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 252,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "single-forward-queue-apply-252",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(250);
    const target = try call.init_target();
    try target.set_importedCap(250);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var apply_context: ApplyContext = .{};
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, try cpz.rpc.dispatchWireMessageForwardingToQueueOutcomeWithApplyHandler(
        &state,
        std.testing.allocator,
        response,
        forward,
        call_message,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &forward_queue,
        &apply_context,
        ApplyContext.handle,
    ));
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 0), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 250, .{ .imported_cap = 251 });

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "single-forward-queue-apply-252" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());
    var unused_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer unused_response_builder.deinit();
    const unused_response = try generated.Message.initRootTyped(&unused_response_builder);
    var unused_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer unused_forward_builder.deinit();
    const unused_forward = try generated.Message.initRootTyped(&unused_forward_builder);
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.state_applied, try cpz.rpc.dispatchWireMessageForwardingToQueueOutcomeWithApplyHandler(
        &state,
        std.testing.allocator,
        unused_response,
        unused_forward,
        disembargo_message,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &forward_queue,
        &apply_context,
        ApplyContext.handle,
    ));
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 252), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(252));
}

test "rpc batch dispatcher reports apply results while sending responses to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 3300;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };
    const Sink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
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

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 45,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "sink-45",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 46);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "sink-45" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ bootstrap_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var sink: Sink = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesToSinkWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &sink,
        Sink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 46), sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 45), apply_context.released_question_sum);

    var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 3346 }, descriptors[0]);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(45));

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);

    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 47,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "queue-47",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));

    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "queue-47" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());

    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_requests = [_]generated.Message{ bootstrap_message, queue_disembargo_message };
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_apply_context: ApplyContext = .{};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    const queue_stats = try cpz.rpc.dispatchWireMessagesToQueueWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .state_applied = 1 }, queue_stats);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 46);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 47), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), queue_state.acceptEmbargoReleased(47));
}

test "rpc batch dispatcher sends initialized responses to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 3000;
        }
    };
    const CallHandler = struct {
        fn handle(_: *u32, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
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
    try state.openQuestion(37, .call);

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 36);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(37);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ bootstrap_message, return_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var sink: Sink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesToSink(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &sink,
        Sink.handle,
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 36), sink.last_answer);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expect(state.questionComplete(37));

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.openQuestion(37, .call);
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_stats = try cpz.rpc.dispatchWireMessagesToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 36);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expect(queue_state.questionComplete(37));

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesToSink(
        &state,
        std.testing.allocator,
        responses[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &sink,
        Sink.handle,
    ));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..1],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
    ));
}

test "rpc dense response dispatcher initializes compact output slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 3200;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .{ .text = "dense response" };
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.openQuestion(41, .call);

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(41);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(40);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);

    const responses = [_]generated.Message.Builder{response};
    const requests = [_]generated.Message{ return_message, call_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    const stats = try cpz.rpc.dispatchWireMessagesDense(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 40), call_seen);
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expect(state.questionComplete(41));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response_message = generated.Message.fromReader(try response_reader.getRoot());
    const response_return = try response_message.return_();
    try std.testing.expectEqual(@as(u32, 40), response_return.answerId());
    try std.testing.expectEqualStrings("dense response", try (try (try response_return.results()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.openQuestion(41, .call);
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_stats = try cpz.rpc.dispatchWireMessagesDenseToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 40), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 40);

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesDense(
        &state,
        std.testing.allocator,
        responses[0..0],
        requests[1..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    ));
}

test "rpc forwarding dispatcher reports apply results while sending forwarded calls to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7200;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
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
    const ApplyContext = struct {
        calls: usize = 0,
        released_accepts: usize = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .disembargo => |info| context.released_accepts += info.released_accepts,
                .state_applied => {},
            }
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 310 });
    try state.resolveImportTo(310, .{ .sender_hosted = 311 });
    try state.applyCapDescriptor(.{ .sender_hosted = 311 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 52,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "forward-sink-52",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(310);
    const target = try call.init_target();
    try target.set_importedCap(310);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "forward-sink-52" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder0.deinit();
    const forward0 = try generated.Message.initRootTyped(&forward_builder0);
    var forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer forward_builder1.deinit();
    const forward1 = try generated.Message.initRootTyped(&forward_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{ forward0, forward1 };
    const requests = [_]generated.Message{ call_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var forward_sink: ForwardSink = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingToSinkWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &forward_sink,
        ForwardSink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .forward_required = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 310), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 310 });
    try queue_state.resolveImportTo(310, .{ .sender_hosted = 311 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 311 });
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 520,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "forward-queue-520",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "forward-queue-520" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    var queue_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_forward_builder0.deinit();
    const queue_forward0 = try generated.Message.initRootTyped(&queue_forward_builder0);
    var queue_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_forward_builder1.deinit();
    const queue_forward1 = try generated.Message.initRootTyped(&queue_forward_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{ queue_forward0, queue_forward1 };
    const queue_requests = [_]generated.Message{ call_message, queue_disembargo_message };
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_apply_context: ApplyContext = .{};
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingToQueueWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        queue_requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &forward_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 310, .{ .imported_cap = 311 });

    const OutcomeObserver = struct {
        calls: usize = 0,
        index_sum: usize = 0,
        observed: cpz.rpc.WireDispatchStats = .{},

        fn handle(observer_context: *@This(), index: usize, outcome: cpz.rpc.WireDispatchOutcome) !void {
            observer_context.calls += 1;
            observer_context.index_sum += index;
            observer_context.observed.record(outcome);
        }
    };
    var observed_state = cpz.rpc.State.init(std.testing.allocator);
    defer observed_state.deinit();
    try observed_state.addImport(5);
    try observed_state.applyCapDescriptor(.{ .sender_promise = 310 });
    try observed_state.resolveImportTo(310, .{ .sender_hosted = 311 });
    try observed_state.applyCapDescriptor(.{ .sender_hosted = 311 });
    var observed_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_accept_builder.deinit();
    const observed_accept_root = try generated.Message.initRootTyped(&observed_accept_builder);
    try cpz.rpc.initWireAcceptMessage(observed_accept_root, .{
        .question_id = 521,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "forward-observe-521",
    });
    var observed_accept_reader = cpz.MessageReader.init(try observed_accept_builder.segmentsConst(), .{});
    try observed_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try observed_accept_reader.getRoot()));
    var observed_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_disembargo_builder.deinit();
    const observed_disembargo_root = try generated.Message.initRootTyped(&observed_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(observed_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "forward-observe-521" },
    });
    var observed_disembargo_reader = cpz.MessageReader.init(try observed_disembargo_builder.segmentsConst(), .{});
    const observed_disembargo_message = generated.Message.fromReader(try observed_disembargo_reader.getRoot());
    var observed_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder0.deinit();
    const observed_response0 = try generated.Message.initRootTyped(&observed_response_builder0);
    var observed_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer observed_response_builder1.deinit();
    const observed_response1 = try generated.Message.initRootTyped(&observed_response_builder1);
    var observed_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_forward_builder0.deinit();
    const observed_forward0 = try generated.Message.initRootTyped(&observed_forward_builder0);
    var observed_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer observed_forward_builder1.deinit();
    const observed_forward1 = try generated.Message.initRootTyped(&observed_forward_builder1);
    const observed_responses = [_]generated.Message.Builder{ observed_response0, observed_response1 };
    const observed_forwards = [_]generated.Message.Builder{ observed_forward0, observed_forward1 };
    const observed_requests = [_]generated.Message{ call_message, observed_disembargo_message };
    var observed_bootstrap_seen: u32 = 0;
    var observed_call_seen: u32 = 0;
    var observed_apply_context: ApplyContext = .{};
    var observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesForwardingWithOutcomeHandlerAndApplyHandler(
        &observed_state,
        std.testing.allocator,
        observed_responses[0..],
        observed_forwards[0..],
        observed_requests[0..],
        &observed_bootstrap_seen,
        BootstrapHandler.handle,
        &observed_call_seen,
        CallHandler.handle,
        &observer,
        OutcomeObserver.handle,
        &observed_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, observed_stats);
    try std.testing.expectEqual(stats, observer.observed);
    try std.testing.expectEqual(@as(usize, 2), observer.calls);
    try std.testing.expectEqual(@as(usize, 1), observer.index_sum);
    try std.testing.expectEqual(@as(usize, 1), observed_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), observed_apply_context.released_accepts);
}

test "rpc forwarding dispatcher reports apply results while sending responses and forwards to sinks" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7300;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
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
    try state.applyCapDescriptor(.{ .sender_promise = 320 });
    try state.resolveImportTo(320, .{ .sender_hosted = 321 });
    try state.applyCapDescriptor(.{ .sender_hosted = 321 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 53,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "forward-dual-53",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 54);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(320);
    const target = try call.init_target();
    try target.set_importedCap(320);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "forward-dual-53" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var response_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder2.deinit();
    const response2 = try generated.Message.initRootTyped(&response_builder2);
    var forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer forward_builder0.deinit();
    const forward0 = try generated.Message.initRootTyped(&forward_builder0);
    var forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder1.deinit();
    const forward1 = try generated.Message.initRootTyped(&forward_builder1);
    var forward_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer forward_builder2.deinit();
    const forward2 = try generated.Message.initRootTyped(&forward_builder2);

    const responses = [_]generated.Message.Builder{ response0, response1, response2 };
    const forwards = [_]generated.Message.Builder{ forward0, forward1, forward2 };
    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingToSinksWithApplyHandler(
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
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 54), response_sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 320), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 53), apply_context.released_question_sum);

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 320 });
    try queue_state.resolveImportTo(320, .{ .sender_hosted = 321 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 321 });
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 530,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "forward-dual-queue-530",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "forward-dual-queue-530" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    var queue_response_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder2.deinit();
    const queue_response2 = try generated.Message.initRootTyped(&queue_response_builder2);
    var queue_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_forward_builder0.deinit();
    const queue_forward0 = try generated.Message.initRootTyped(&queue_forward_builder0);
    var queue_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_forward_builder1.deinit();
    const queue_forward1 = try generated.Message.initRootTyped(&queue_forward_builder1);
    var queue_forward_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_forward_builder2.deinit();
    const queue_forward2 = try generated.Message.initRootTyped(&queue_forward_builder2);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1, queue_response2 };
    const queue_forwards = [_]generated.Message.Builder{ queue_forward0, queue_forward1, queue_forward2 };
    const queue_requests = [_]generated.Message{ bootstrap_message, call_message, queue_disembargo_message };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingToQueuesWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        queue_requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
        &forward_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 54);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 320, .{ .imported_cap = 321 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 530), queue_apply_context.released_question_sum);
}

test "rpc batch forwarding dispatcher sends forwarded calls to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7000;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };
    const Sink = struct {
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
    try state.applyCapDescriptor(.{ .sender_promise = 220 });
    try state.resolveImportTo(220, .{ .sender_hosted = 221 });
    try state.applyCapDescriptor(.{ .sender_hosted = 221 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 36);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(220);
    const target = try call.init_target();
    try target.set_importedCap(220);
    try cpz.rpc.initWireCallParamsText(call, "sink forward", &.{.{ .sender_hosted = 222 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder0.deinit();
    const forward0 = try generated.Message.initRootTyped(&forward_builder0);
    var forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder1.deinit();
    const forward1 = try generated.Message.initRootTyped(&forward_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{ forward0, forward1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var sink: Sink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingToSink(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &sink,
        Sink.handle,
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 0), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 220), sink.last_question);

    var forward_reader = cpz.MessageReader.init(try forward_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 221 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("sink forward", try (try (try forwarded.params()).content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, try forwarded.params());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 222 }, descriptors[0]);

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 220 });
    try queue_state.resolveImportTo(220, .{ .sender_hosted = 221 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 221 });
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    var queue_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_forward_builder0.deinit();
    const queue_forward0 = try generated.Message.initRootTyped(&queue_forward_builder0);
    var queue_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder1.deinit();
    const queue_forward1 = try generated.Message.initRootTyped(&queue_forward_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{ queue_forward0, queue_forward1 };
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 220, .{ .imported_cap = 221 });

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesForwardingToSink(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &sink,
        Sink.handle,
    ));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesForwardingToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..1],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &forward_queue,
    ));
}

test "rpc batch forwarding dispatcher sends responses and forwarded calls to sinks" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7000;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
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
    try state.applyCapDescriptor(.{ .sender_promise = 240 });
    try state.resolveImportTo(240, .{ .sender_hosted = 241 });
    try state.applyCapDescriptor(.{ .sender_hosted = 241 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 39);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(240);
    const target = try call.init_target();
    try target.set_importedCap(240);
    try cpz.rpc.initWireCallParamsText(call, "dual sink forward", &.{.{ .sender_hosted = 242 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder0.deinit();
    const forward0 = try generated.Message.initRootTyped(&forward_builder0);
    var forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder1.deinit();
    const forward1 = try generated.Message.initRootTyped(&forward_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{ forward0, forward1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingToSinks(
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
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 0), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 39), response_sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 240), forward_sink.last_question);

    var forward_reader = cpz.MessageReader.init(try forward_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 241 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("dual sink forward", try (try (try forwarded.params()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 240 });
    try queue_state.resolveImportTo(240, .{ .sender_hosted = 241 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 241 });
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    var queue_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_forward_builder0.deinit();
    const queue_forward0 = try generated.Message.initRootTyped(&queue_forward_builder0);
    var queue_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder1.deinit();
    const queue_forward1 = try generated.Message.initRootTyped(&queue_forward_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{ queue_forward0, queue_forward1 };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingToQueues(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 39);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 240, .{ .imported_cap = 241 });

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesForwardingToSinks(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
    ));
}

test "rpc dense forwarding sink dispatcher only requires emitted message slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7000;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
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
    try state.openQuestion(41, .call);
    try state.applyCapDescriptor(.{ .sender_promise = 260 });
    try state.resolveImportTo(260, .{ .sender_hosted = 261 });
    try state.applyCapDescriptor(.{ .sender_hosted = 261 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 42);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(260);
    const target = try call.init_target();
    try target.set_importedCap(260);
    try cpz.rpc.initWireCallParamsText(call, "dense forward", &.{.{ .sender_hosted = 262 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(41);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{response};
    const forwards = [_]generated.Message.Builder{forward};
    const requests = [_]generated.Message{ bootstrap_message, call_message, return_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingToDenseSinks(
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
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 42), response_sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 260), forward_sink.last_question);
    try std.testing.expect(state.questionComplete(41));

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 261 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("dense forward", try (try (try forwarded.params()).content()).getText());
}

test "rpc dense forwarding dispatcher initializes compact output slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7200;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(43, .call);
    try state.applyCapDescriptor(.{ .sender_promise = 270 });
    try state.resolveImportTo(270, .{ .sender_hosted = 271 });
    try state.applyCapDescriptor(.{ .sender_hosted = 271 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 44);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(270);
    const target = try call.init_target();
    try target.set_importedCap(270);
    try cpz.rpc.initWireCallParamsText(call, "dense no sink forward", &.{.{ .sender_hosted = 272 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(43);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{response};
    const forwards = [_]generated.Message.Builder{forward};
    const requests = [_]generated.Message{ bootstrap_message, call_message, return_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    const stats = try cpz.rpc.dispatchWireMessagesForwardingDense(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expect(state.questionComplete(43));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response_return = try generated.Message.fromReader(try response_reader.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 44), response_return.answerId());

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 271 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("dense no sink forward", try (try (try forwarded.params()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.openQuestion(43, .call);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 270 });
    try queue_state.resolveImportTo(270, .{ .sender_hosted = 271 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 271 });
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingDenseToQueues(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 44);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 270, .{ .imported_cap = 271 });
}

test "rpc dense forwarding dispatcher fills unified output slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7300;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 280 });
    try state.resolveImportTo(280, .{ .sender_hosted = 281 });
    try state.applyCapDescriptor(.{ .sender_hosted = 281 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 45);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(280);
    const target = try call.init_target();
    try target.set_importedCap(280);
    try cpz.rpc.initWireCallParamsText(call, "unified dense forward", &.{.{ .sender_hosted = 282 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message };

    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    const stats = try cpz.rpc.dispatchWireMessagesForwardingUnifiedDense(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, stats);
    try std.testing.expectEqual(@as(u32, 0), call_seen);

    var response_reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 45), (try generated.Message.fromReader(try response_reader.getRoot()).return_()).answerId());
    var forward_reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 281 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("unified dense forward", try (try (try forwarded.params()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 280 });
    try queue_state.resolveImportTo(280, .{ .sender_hosted = 281 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 281 });
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingUnifiedDenseToQueues(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 45);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 280, .{ .imported_cap = 281 });

    var unified_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer unified_queue_state.deinit();
    try unified_queue_state.applyCapDescriptor(.{ .sender_promise = 280 });
    try unified_queue_state.resolveImportTo(280, .{ .sender_hosted = 281 });
    try unified_queue_state.applyCapDescriptor(.{ .sender_hosted = 281 });
    var unified_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_output_builder0.deinit();
    const unified_queue_output0 = try generated.Message.initRootTyped(&unified_queue_output_builder0);
    var unified_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer unified_queue_output_builder1.deinit();
    const unified_queue_output1 = try generated.Message.initRootTyped(&unified_queue_output_builder1);
    const unified_queue_outputs = [_]generated.Message.Builder{ unified_queue_output0, unified_queue_output1 };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var unified_queue_bootstrap_seen: u32 = 0;
    var unified_queue_call_seen: u32 = 0;
    const unified_queue_stats = try cpz.rpc.dispatchWireMessagesForwardingUnifiedDenseToQueue(
        &unified_queue_state,
        std.testing.allocator,
        unified_queue_outputs[0..],
        requests[0..],
        &unified_queue_bootstrap_seen,
        BootstrapHandler.handle,
        &unified_queue_call_seen,
        CallHandler.handle,
        &output_queue,
    );
    try std.testing.expectEqual(stats, unified_queue_stats);
    try std.testing.expectEqual(@as(u32, 0), unified_queue_call_seen);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 45);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[1], 280, .{ .imported_cap = 281 });
}

test "rpc dense forwarding dispatcher fills unified output slots and reports apply details" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7500;
        }
    };
    const CallHandler = struct {
        fn handle(context: *u32, call: anytype) !cpz.rpc.DispatchResult {
            context.* = call.questionId();
            return .empty;
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
    try state.addImport(6);
    try state.applyCapDescriptor(.{ .sender_promise = 290 });
    try state.resolveImportTo(290, .{ .sender_hosted = 291 });
    try state.applyCapDescriptor(.{ .sender_hosted = 291 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 65,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "unified-dense-forward-65",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 66);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(290);
    const target = try call.init_target();
    try target.set_importedCap(290);
    try cpz.rpc.initWireCallParamsText(call, "unified dense forward apply", &.{.{ .sender_hosted = 292 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 6 },
        .context = .{ .accept = "unified-dense-forward-65" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };

    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingUnifiedDenseWithApplyHandler(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 65), apply_context.released_question_sum);

    var response_reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 66), (try generated.Message.fromReader(try response_reader.getRoot()).return_()).answerId());
    var forward_reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 291 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("unified dense forward apply", try (try (try forwarded.params()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(6);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 290 });
    try queue_state.resolveImportTo(290, .{ .sender_hosted = 291 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 291 });
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 650,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "unified-dense-forward-queue-650",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 6 },
        .context = .{ .accept = "unified-dense-forward-queue-650" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    const queue_requests = [_]generated.Message{ bootstrap_message, call_message, queue_disembargo_message };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingUnifiedDenseToQueuesWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        queue_requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &response_queue,
        &forward_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 66);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 290, .{ .imported_cap = 291 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 650), queue_apply_context.released_question_sum);

    var unified_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer unified_queue_state.deinit();
    try unified_queue_state.addImport(6);
    try unified_queue_state.applyCapDescriptor(.{ .sender_promise = 290 });
    try unified_queue_state.resolveImportTo(290, .{ .sender_hosted = 291 });
    try unified_queue_state.applyCapDescriptor(.{ .sender_hosted = 291 });
    var unified_queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_accept_builder.deinit();
    const unified_queue_accept_root = try generated.Message.initRootTyped(&unified_queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(unified_queue_accept_root, .{
        .question_id = 651,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "unified-dense-forward-output-queue-651",
    });
    var unified_queue_accept_reader = cpz.MessageReader.init(try unified_queue_accept_builder.segmentsConst(), .{});
    try unified_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try unified_queue_accept_reader.getRoot()));
    var unified_queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_disembargo_builder.deinit();
    const unified_queue_disembargo_root = try generated.Message.initRootTyped(&unified_queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(unified_queue_disembargo_root, .{
        .target = .{ .imported_cap = 6 },
        .context = .{ .accept = "unified-dense-forward-output-queue-651" },
    });
    var unified_queue_disembargo_reader = cpz.MessageReader.init(try unified_queue_disembargo_builder.segmentsConst(), .{});
    const unified_queue_disembargo_message = generated.Message.fromReader(try unified_queue_disembargo_reader.getRoot());
    var unified_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_output_builder0.deinit();
    const unified_queue_output0 = try generated.Message.initRootTyped(&unified_queue_output_builder0);
    var unified_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer unified_queue_output_builder1.deinit();
    const unified_queue_output1 = try generated.Message.initRootTyped(&unified_queue_output_builder1);
    const unified_queue_outputs = [_]generated.Message.Builder{ unified_queue_output0, unified_queue_output1 };
    const unified_queue_requests = [_]generated.Message{ bootstrap_message, call_message, unified_queue_disembargo_message };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var unified_queue_bootstrap_seen: u32 = 0;
    var unified_queue_call_seen: u32 = 0;
    var unified_queue_apply_context: ApplyContext = .{};
    const unified_queue_stats = try cpz.rpc.dispatchWireMessagesForwardingUnifiedDenseToQueueWithApplyHandler(
        &unified_queue_state,
        std.testing.allocator,
        unified_queue_outputs[0..],
        unified_queue_requests[0..],
        &unified_queue_bootstrap_seen,
        BootstrapHandler.handle,
        &unified_queue_call_seen,
        CallHandler.handle,
        &output_queue,
        &unified_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, unified_queue_stats);
    try std.testing.expectEqual(@as(u32, 0), unified_queue_call_seen);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 66);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[1], 290, .{ .imported_cap = 291 });
    try std.testing.expectEqual(@as(usize, 1), unified_queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), unified_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 651), unified_queue_apply_context.released_question_sum);
}

test "rpc batch method-table forwarding dispatcher sends forwarded calls to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 8000;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const Sink = struct {
        sent: usize = 0,
        last_question: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const call = try message.get_call();
            context.sent += 1;
            context.last_question = try call.get_questionId();
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x7777, .method_id = 7 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 230 });
    try state.resolveImportTo(230, .{ .sender_hosted = 231 });
    try state.applyCapDescriptor(.{ .sender_hosted = 231 });

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(230);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x7777, .method_id = 7 }, call);
    const target = try call.init_target();
    try target.set_importedCap(230);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 7, 14 }, &.{.{ .sender_hosted = 232 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{response};
    const forwards = [_]generated.Message.Builder{forward};
    const requests = [_]generated.Message{call_message};
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var sink: Sink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToSink(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &sink,
        Sink.handle,
    );
    try std.testing.expectEqual(@as(usize, 0), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 0), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 230), sink.last_question);

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 231 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x7777, .method_id = 7 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 7, 14 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 230 });
    try queue_state.resolveImportTo(230, .{ .sender_hosted = 231 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 231 });
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 230, .{ .imported_cap = 231 });
}

test "rpc batch method-table forwarding dispatcher sends responses and forwarded calls to sinks" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 8100;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const ResponseSink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x8888, .method_id = 8 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 250 });
    try state.resolveImportTo(250, .{ .sender_hosted = 251 });
    try state.applyCapDescriptor(.{ .sender_hosted = 251 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 40);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(250);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x8888, .method_id = 8 }, call);
    const target = try call.init_target();
    try target.set_importedCap(250);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 8, 16 }, &.{.{ .sender_hosted = 252 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);
    var forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder0.deinit();
    const forward0 = try generated.Message.initRootTyped(&forward_builder0);
    var forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder1.deinit();
    const forward1 = try generated.Message.initRootTyped(&forward_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const forwards = [_]generated.Message.Builder{ forward0, forward1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToSinks(
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
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 0), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 40), response_sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 250), forward_sink.last_question);

    var forward_reader = cpz.MessageReader.init(try forward_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 251 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x8888, .method_id = 8 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 8, 16 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 250 });
    try queue_state.resolveImportTo(250, .{ .sender_hosted = 251 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 251 });
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    var queue_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_forward_builder0.deinit();
    const queue_forward0 = try generated.Message.initRootTyped(&queue_forward_builder0);
    var queue_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder1.deinit();
    const queue_forward1 = try generated.Message.initRootTyped(&queue_forward_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{ queue_forward0, queue_forward1 };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToQueues(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 40);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 250, .{ .imported_cap = 251 });
}

test "rpc dense method-table forwarding dispatcher initializes compact output slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 8200;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x9999, .method_id = 9 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(45, .call);
    try state.applyCapDescriptor(.{ .sender_promise = 280 });
    try state.resolveImportTo(280, .{ .sender_hosted = 281 });
    try state.applyCapDescriptor(.{ .sender_hosted = 281 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 46);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(280);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x9999, .method_id = 9 }, call);
    const target = try call.init_target();
    try target.set_importedCap(280);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 9, 18 }, &.{.{ .sender_hosted = 282 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(45);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{response};
    const forwards = [_]generated.Message.Builder{forward};
    const requests = [_]generated.Message{ bootstrap_message, call_message, return_message };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingDense(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 1), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expect(state.questionComplete(45));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response_return = try generated.Message.fromReader(try response_reader.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 46), response_return.answerId());

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 281 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9999, .method_id = 9 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 9, 18 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.openQuestion(45, .call);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 280 });
    try queue_state.resolveImportTo(280, .{ .sender_hosted = 281 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 281 });
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingDenseToQueues(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 46);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 280, .{ .imported_cap = 281 });
}

test "rpc dense method-table forwarding dispatcher fills unified output slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 8300;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xaaaa, .method_id = 10 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 285 });
    try state.resolveImportTo(285, .{ .sender_hosted = 286 });
    try state.applyCapDescriptor(.{ .sender_hosted = 286 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 47);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(285);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xaaaa, .method_id = 10 }, call);
    const target = try call.init_target();
    try target.set_importedCap(285);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 10, 20 }, &.{.{ .sender_hosted = 287 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message };

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingUnifiedDense(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, stats);
    try std.testing.expectEqual(@as(u32, 0), context.selected);

    var response_reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 47), (try generated.Message.fromReader(try response_reader.getRoot()).return_()).answerId());
    var forward_reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 286 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0xaaaa, .method_id = 10 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 10, 20 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 285 });
    try queue_state.resolveImportTo(285, .{ .sender_hosted = 286 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 286 });
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingUnifiedDenseToQueues(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 47);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 285, .{ .imported_cap = 286 });

    var unified_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer unified_queue_state.deinit();
    try unified_queue_state.applyCapDescriptor(.{ .sender_promise = 285 });
    try unified_queue_state.resolveImportTo(285, .{ .sender_hosted = 286 });
    try unified_queue_state.applyCapDescriptor(.{ .sender_hosted = 286 });
    var unified_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_output_builder0.deinit();
    const unified_queue_output0 = try generated.Message.initRootTyped(&unified_queue_output_builder0);
    var unified_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer unified_queue_output_builder1.deinit();
    const unified_queue_output1 = try generated.Message.initRootTyped(&unified_queue_output_builder1);
    const unified_queue_outputs = [_]generated.Message.Builder{ unified_queue_output0, unified_queue_output1 };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var unified_queue_bootstrap_seen: u32 = 0;
    var unified_queue_context: Context = .{};
    const unified_queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingUnifiedDenseToQueue(
        &unified_queue_state,
        std.testing.allocator,
        unified_queue_outputs[0..],
        requests[0..],
        &unified_queue_bootstrap_seen,
        BootstrapHandler.handle,
        &unified_queue_context,
        entries,
        &output_queue,
    );
    try std.testing.expectEqual(stats, unified_queue_stats);
    try std.testing.expectEqual(@as(u32, 0), unified_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 47);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[1], 285, .{ .imported_cap = 286 });
}

test "rpc dense method-table forwarding dispatcher fills unified output slots and reports apply details" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 8400;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xaaab, .method_id = 11 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(7);
    try state.applyCapDescriptor(.{ .sender_promise = 295 });
    try state.resolveImportTo(295, .{ .sender_hosted = 296 });
    try state.applyCapDescriptor(.{ .sender_hosted = 296 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 67,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "unified-method-forward-67",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 68);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(295);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xaaab, .method_id = 11 }, call);
    const target = try call.init_target();
    try target.set_importedCap(295);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 11, 22 }, &.{.{ .sender_hosted = 297 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 7 },
        .context = .{ .accept = "unified-method-forward-67" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    const outputs = [_]generated.Message.Builder{ output0, output1 };
    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingUnifiedDenseWithApplyHandler(
        &state,
        std.testing.allocator,
        outputs[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 67), apply_context.released_question_sum);

    var response_reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 68), (try generated.Message.fromReader(try response_reader.getRoot()).return_()).answerId());
    var forward_reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 296 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0xaaab, .method_id = 11 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 11, 22 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(7);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 295 });
    try queue_state.resolveImportTo(295, .{ .sender_hosted = 296 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 296 });
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 670,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "unified-method-forward-queue-670",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 7 },
        .context = .{ .accept = "unified-method-forward-queue-670" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1 };
    const queue_requests = [_]generated.Message{ bootstrap_message, call_message, queue_disembargo_message };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingUnifiedDenseToQueuesWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
        queue_requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
        &forward_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 68);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 295, .{ .imported_cap = 296 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 670), queue_apply_context.released_question_sum);

    var unified_queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer unified_queue_state.deinit();
    try unified_queue_state.addImport(7);
    try unified_queue_state.applyCapDescriptor(.{ .sender_promise = 295 });
    try unified_queue_state.resolveImportTo(295, .{ .sender_hosted = 296 });
    try unified_queue_state.applyCapDescriptor(.{ .sender_hosted = 296 });
    var unified_queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_accept_builder.deinit();
    const unified_queue_accept_root = try generated.Message.initRootTyped(&unified_queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(unified_queue_accept_root, .{
        .question_id = 671,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "unified-method-forward-output-queue-671",
    });
    var unified_queue_accept_reader = cpz.MessageReader.init(try unified_queue_accept_builder.segmentsConst(), .{});
    try unified_queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try unified_queue_accept_reader.getRoot()));
    var unified_queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_disembargo_builder.deinit();
    const unified_queue_disembargo_root = try generated.Message.initRootTyped(&unified_queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(unified_queue_disembargo_root, .{
        .target = .{ .imported_cap = 7 },
        .context = .{ .accept = "unified-method-forward-output-queue-671" },
    });
    var unified_queue_disembargo_reader = cpz.MessageReader.init(try unified_queue_disembargo_builder.segmentsConst(), .{});
    const unified_queue_disembargo_message = generated.Message.fromReader(try unified_queue_disembargo_reader.getRoot());
    var unified_queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_queue_output_builder0.deinit();
    const unified_queue_output0 = try generated.Message.initRootTyped(&unified_queue_output_builder0);
    var unified_queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer unified_queue_output_builder1.deinit();
    const unified_queue_output1 = try generated.Message.initRootTyped(&unified_queue_output_builder1);
    const unified_queue_outputs = [_]generated.Message.Builder{ unified_queue_output0, unified_queue_output1 };
    const unified_queue_requests = [_]generated.Message{ bootstrap_message, call_message, unified_queue_disembargo_message };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var unified_queue_bootstrap_seen: u32 = 0;
    var unified_queue_context: Context = .{};
    var unified_queue_apply_context: ApplyContext = .{};
    const unified_queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingUnifiedDenseToQueueWithApplyHandler(
        &unified_queue_state,
        std.testing.allocator,
        unified_queue_outputs[0..],
        unified_queue_requests[0..],
        &unified_queue_bootstrap_seen,
        BootstrapHandler.handle,
        &unified_queue_context,
        entries,
        &output_queue,
        &unified_queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, unified_queue_stats);
    try std.testing.expectEqual(@as(u32, 0), unified_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 68);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[1], 295, .{ .imported_cap = 296 });
    try std.testing.expectEqual(@as(usize, 1), unified_queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), unified_queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 671), unified_queue_apply_context.released_question_sum);
}

test "rpc method-table dispatcher reports apply results while sending responses to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9400;
        }
    };
    const Context = struct {
        selected: u32 = 0,
    };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const Sink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5559, .method_id = 9 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 49,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "method-sink-49",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(50);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5559, .method_id = 9 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-sink-49" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ call_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var sink: Sink = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsToSinkWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &sink,
        Sink.handle,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 50), context.selected);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 50), sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 49), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(49));

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 490,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "method-queue-490",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "method-queue-490" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_requests = [_]generated.Message{ call_message, queue_disembargo_message };
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_apply_context: ApplyContext = .{};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsToQueueWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 50), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 50);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 490), queue_apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), queue_state.acceptEmbargoReleased(490));
}

test "rpc batch method-table dispatcher sends initialized responses to a sink" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9000;
        }
    };
    const Context = struct {
        selected: u32 = 0,
    };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const Sink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5555, .method_id = 5 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(38);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5555, .method_id = 5 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var finish_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer finish_builder.deinit();
    const finish_root = try generated.Message.initRootTyped(&finish_builder);
    try cpz.rpc.initWireFinishMessage(finish_root, .{ .question_id = 38, .release_result_caps = false });
    var finish_reader = cpz.MessageReader.init(try finish_builder.segmentsConst(), .{});
    const finish_message = generated.Message.fromReader(try finish_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var sink: Sink = .{};
    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ call_message, finish_message };
    const stats = try cpz.rpc.dispatchWireMessagesMethodsToSink(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &sink,
        Sink.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 38), context.selected);
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 38), sink.last_answer);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(38));

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    var queue_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder0.deinit();
    const queue_response0 = try generated.Message.initRootTyped(&queue_response_builder0);
    var queue_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer queue_response_builder1.deinit();
    const queue_response1 = try generated.Message.initRootTyped(&queue_response_builder1);
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 38), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 38);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), queue_state.questionState(38));

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesMethodsToSink(
        &state,
        std.testing.allocator,
        responses[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &sink,
        Sink.handle,
    ));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesMethodsToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..1],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &response_queue,
    ));
}

test "rpc dense method-table dispatcher initializes compact output slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9200;
        }
    };
    const Context = struct {
        selected: u32 = 0,
    };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .{ .text = "method dense" };
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5557, .method_id = 7 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.openQuestion(43, .call);

    var finish_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer finish_builder.deinit();
    const finish_root = try generated.Message.initRootTyped(&finish_builder);
    try cpz.rpc.initWireFinishMessage(finish_root, .{ .question_id = 43, .release_result_caps = false });
    var finish_reader = cpz.MessageReader.init(try finish_builder.segmentsConst(), .{});
    const finish_message = generated.Message.fromReader(try finish_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(42);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5557, .method_id = 7 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    const responses = [_]generated.Message.Builder{response};
    const requests = [_]generated.Message{ finish_message, call_message };
    const stats = try cpz.rpc.dispatchWireMessagesMethodsDense(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 42), context.selected);
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(43));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response_message = generated.Message.fromReader(try response_reader.getRoot());
    const response_return = try response_message.return_();
    try std.testing.expectEqual(@as(u32, 42), response_return.answerId());
    try std.testing.expectEqualStrings("method dense", try (try (try response_return.results()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.openQuestion(43, .call);
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsDenseToQueue(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 42), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 42);

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesMethodsDense(
        &state,
        std.testing.allocator,
        responses[0..0],
        requests[1..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
    ));
}

test "rpc unified output helper sends role ranges to separate sinks" {
    const ResponseSink = struct {
        sent: usize = 0,
        last_answer: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
        }
    };
    const ForwardSink = struct {
        sent: usize = 0,
        last_question: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            try support.expectQueuedForwardedCallBuilder(message, 302, .{ .imported_cap = 3 });
            context.sent += 1;
            context.last_question = 302;
        }
    };
    const DisembargoSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            try support.expectQueuedDisembargoBuilder(message, .{ .imported_cap = 4 }, "role-disembargo");
            context.sent += 1;
        }
    };
    const UnifiedSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            _ = try message.which();
            context.sent += 1;
        }
    };

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    try cpz.rpc.initEmptyReturnMessage(response, 301, true, true);

    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);
    try cpz.rpc.initWireCallMessageText(forward, 302, .{ .imported_cap = 3 }, "role forward", &.{});

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo, .{
        .target = .{ .imported_cap = 4 },
        .context = .{ .accept = "role-disembargo" },
    });

    var unused_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer unused_builder.deinit();
    const unused = try generated.Message.initRootTyped(&unused_builder);
    const outputs = [_]generated.Message.Builder{ response, forward, disembargo, unused };
    const plan: cpz.rpc.RpcTurnPlan = .{
        .dispatch = .{ .response_initialized = 1, .forward_required = 1 },
        .pending_disembargos = 1,
    };
    try std.testing.expectEqual(
        cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 },
        cpz.rpc.RpcOutputStats.fromTurnPlan(plan),
    );
    const plan_output_stats = cpz.rpc.RpcOutputStats.fromTurnPlan(plan);
    try plan_output_stats.validateResponseCapacity(1);
    try plan_output_stats.validateForwardCapacity(1);
    try plan_output_stats.validateDisembargoCapacity(1);
    try plan_output_stats.validateSplitCapacity(1, 1, 1);
    try plan_output_stats.validateUnifiedOutputCapacity(3);
    try plan_output_stats.validateResponseBuilders(outputs[0..1]);
    try plan_output_stats.validateForwardBuilders(outputs[1..2]);
    try plan_output_stats.validateDisembargoBuilders(outputs[2..3]);
    try plan_output_stats.validateSplitBuilders(outputs[0..1], outputs[1..2], outputs[2..3]);
    try plan_output_stats.validateUnifiedOutputBuilders(outputs[0..3]);
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, plan_output_stats.responseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, plan_output_stats.forwardRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, plan_output_stats.disembargoRange());
    try std.testing.expectEqual(@as(?usize, 0), plan_output_stats.responseLocalIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan_output_stats.responseLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, 0), plan_output_stats.forwardLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, 0), plan_output_stats.disembargoLocalIndex(2));
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, plan_output_stats.unifiedOutputPosition(0).?);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, plan_output_stats.unifiedOutputPosition(1).?);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, plan_output_stats.unifiedOutputPosition(2).?);
    try std.testing.expect(plan_output_stats.unifiedOutputPosition(3) == null);
    try std.testing.expectEqual(@as(?usize, 0), plan_output_stats.outputIndex(.{ .role = .response, .local_index = 0 }));
    try std.testing.expectEqual(@as(?usize, 1), plan_output_stats.outputIndex(.{ .role = .forward, .local_index = 0 }));
    try std.testing.expectEqual(@as(?usize, 2), plan_output_stats.outputIndex(.{ .role = .disembargo, .local_index = 0 }));
    try std.testing.expectEqual(@as(?usize, null), plan_output_stats.outputIndex(.{ .role = .response, .local_index = 1 }));
    try std.testing.expectEqual(@as(?usize, 0), plan_output_stats.responseOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan_output_stats.responseOutputIndex(1));
    try std.testing.expectEqual(@as(?usize, 1), plan_output_stats.forwardOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan_output_stats.forwardOutputIndex(1));
    try std.testing.expectEqual(@as(?usize, 2), plan_output_stats.disembargoOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan_output_stats.disembargoOutputIndex(1));
    var output_index_stats: cpz.rpc.RpcOutputStats = .{};
    try output_index_stats.recordOutputIndex(plan_output_stats, 0);
    try output_index_stats.recordOutputIndex(plan_output_stats, 1);
    try output_index_stats.recordOutputIndex(plan_output_stats, 2);
    try std.testing.expectEqual(plan_output_stats, output_index_stats);
    try std.testing.expectError(error.InvalidTransition, output_index_stats.recordOutputIndex(plan_output_stats, 3));
    try std.testing.expect(plan_output_stats.matchesStats(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }));
    try plan_output_stats.validateAgainstStats(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 });
    try std.testing.expectError(error.InvalidTransition, plan_output_stats.validateAgainstStats(cpz.rpc.RpcOutputStats{ .responses = 1 }));
    var next_output_stats: cpz.rpc.RpcOutputStats = .{};
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, next_output_stats.nextPosition(.response));
    next_output_stats.recordRole(.response);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 1 }, next_output_stats.nextPosition(.response));
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, next_output_stats.nextPosition(.forward));
    next_output_stats.recordRole(.disembargo);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 1 }, next_output_stats.nextPosition(.disembargo));
    try std.testing.expectError(error.InvalidTransition, plan_output_stats.validateResponseCapacity(0));
    try std.testing.expectError(error.InvalidTransition, plan_output_stats.validateForwardCapacity(0));
    try std.testing.expectError(error.InvalidTransition, plan_output_stats.validateDisembargoCapacity(0));
    try std.testing.expectError(error.InvalidTransition, plan_output_stats.validateUnifiedOutputCapacity(2));
    try std.testing.expect((cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }).matchesTurnPlan(plan));
    try (cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }).validateAgainstTurnPlan(plan);
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1 }).validateAgainstTurnPlan(plan));
    const mixed_response_plan: cpz.rpc.RpcTurnPlan = .{
        .dispatch = .{ .response_initialized = 2 },
        .handoff_returns = .{ .provides = 1, .accepts = 1 },
    };
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, mixed_response_plan.dispatchResponseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 4 }, mixed_response_plan.handoffReturnRange());
    try std.testing.expectEqual(@as(?usize, 1), mixed_response_plan.dispatchResponseLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, null), mixed_response_plan.dispatchResponseLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 0), mixed_response_plan.handoffReturnLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), mixed_response_plan.handoffReturnLocalIndex(4));
    const dispatch_source_position = mixed_response_plan.responseSourcePosition(1).?;
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .dispatch, .local_index = 1 }, dispatch_source_position);
    try std.testing.expect(dispatch_source_position.isDispatch());
    try std.testing.expect(!dispatch_source_position.isHandoffReturn());
    const handoff_source_position = cpz.rpc.rpcTurnResponseSourcePosition(mixed_response_plan, 2).?;
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .handoff_return, .local_index = 0 }, handoff_source_position);
    try std.testing.expect(handoff_source_position.isHandoffReturn());
    try std.testing.expect(!handoff_source_position.isDispatch());
    try std.testing.expect(mixed_response_plan.responseSourcePosition(4) == null);
    try std.testing.expectEqual(@as(?usize, 1), mixed_response_plan.responseSourceOutputIndex(dispatch_source_position));
    try std.testing.expectEqual(@as(?usize, 2), cpz.rpc.rpcTurnResponseSourceOutputIndex(mixed_response_plan, handoff_source_position));
    try std.testing.expectEqual(@as(?usize, null), mixed_response_plan.responseSourceOutputIndex(.{ .role = .dispatch, .local_index = 2 }));
    try std.testing.expectEqual(@as(?usize, null), mixed_response_plan.responseSourceOutputIndex(.{ .role = .handoff_return, .local_index = 2 }));
    try std.testing.expectEqual(@as(?usize, 1), mixed_response_plan.dispatchResponseOutputIndex(1));
    try std.testing.expectEqual(@as(?usize, null), mixed_response_plan.dispatchResponseOutputIndex(2));
    try std.testing.expectEqual(@as(?usize, 2), mixed_response_plan.handoffReturnOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), mixed_response_plan.handoffReturnOutputIndex(2));
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2, .handoff_returns = 2 }, cpz.rpc.RpcTurnResponseSourceStats.fromTurnPlan(mixed_response_plan));
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2, .handoff_returns = 2 }, mixed_response_plan.responseSourceStats());
    var response_source_stats: cpz.rpc.RpcTurnResponseSourceStats = .{};
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .dispatch, .local_index = 0 }, response_source_stats.nextPosition(.dispatch));
    response_source_stats.recordPosition(dispatch_source_position);
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .dispatch, .local_index = 1 }, response_source_stats.nextPosition(.dispatch));
    try response_source_stats.recordOutputIndex(mixed_response_plan, 0);
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .handoff_return, .local_index = 0 }, response_source_stats.nextPosition(.handoff_return));
    response_source_stats.recordPosition(handoff_source_position);
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .handoff_return, .local_index = 1 }, response_source_stats.nextPosition(.handoff_return));
    try response_source_stats.recordOutputIndex(mixed_response_plan, 3);
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2, .handoff_returns = 2 }, response_source_stats);
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, response_source_stats.dispatchRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 4 }, response_source_stats.handoffReturnRange());
    try std.testing.expectEqual(@as(?usize, 1), response_source_stats.dispatchLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, null), response_source_stats.dispatchLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 0), response_source_stats.handoffReturnLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), response_source_stats.handoffReturnLocalIndex(4));
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .dispatch, .local_index = 1 }, response_source_stats.sourcePosition(1).?);
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .handoff_return, .local_index = 0 }, response_source_stats.sourcePosition(2).?);
    try std.testing.expect(response_source_stats.sourcePosition(4) == null);
    try std.testing.expectEqual(@as(?usize, 1), response_source_stats.sourceOutputIndex(.{ .role = .dispatch, .local_index = 1 }));
    try std.testing.expectEqual(@as(?usize, 2), response_source_stats.sourceOutputIndex(.{ .role = .handoff_return, .local_index = 0 }));
    try std.testing.expectEqual(@as(?usize, null), response_source_stats.sourceOutputIndex(.{ .role = .handoff_return, .local_index = 2 }));
    try std.testing.expect(response_source_stats.hasResponses());
    try std.testing.expect(!response_source_stats.isEmpty());
    try std.testing.expect(response_source_stats.hasDispatchResponses());
    try std.testing.expect(response_source_stats.hasHandoffReturns());
    try std.testing.expect((cpz.rpc.RpcTurnResponseSourceStats{}).isEmpty());
    try std.testing.expect(!(cpz.rpc.RpcTurnResponseSourceStats{}).hasResponses());
    try std.testing.expect(response_source_stats.matchesStats(cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2, .handoff_returns = 2 }));
    try response_source_stats.validateAgainstStats(cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2, .handoff_returns = 2 });
    try std.testing.expectError(error.InvalidTransition, response_source_stats.validateAgainstStats(cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2 }));
    try std.testing.expect(response_source_stats.matchesTurnPlan(mixed_response_plan));
    try response_source_stats.validateAgainstTurnPlan(mixed_response_plan);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 4 }, cpz.rpc.RpcOutputStats.fromResponseSourceStats(response_source_stats));
    try std.testing.expect((cpz.rpc.RpcOutputStats{ .responses = 4 }).matchesResponseSourceStats(response_source_stats));
    try (cpz.rpc.RpcOutputStats{ .responses = 4 }).validateAgainstResponseSourceStats(response_source_stats);
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.RpcOutputStats{ .responses = 3 }).validateAgainstResponseSourceStats(response_source_stats));
    try response_source_stats.validateResponseCapacity(4);
    try std.testing.expectError(error.InvalidTransition, response_source_stats.validateResponseCapacity(3));
    try std.testing.expectError(error.InvalidTransition, response_source_stats.recordOutputIndex(mixed_response_plan, 4));
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2 }).validateAgainstTurnPlan(mixed_response_plan));
    var source_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer source_response_builder0.deinit();
    const source_response0 = try generated.Message.initRootTyped(&source_response_builder0);
    try cpz.rpc.initEmptyReturnMessage(source_response0, 501, true, true);
    var source_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer source_response_builder1.deinit();
    const source_response1 = try generated.Message.initRootTyped(&source_response_builder1);
    try cpz.rpc.initEmptyReturnMessage(source_response1, 502, true, true);
    var source_response_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer source_response_builder2.deinit();
    const source_response2 = try generated.Message.initRootTyped(&source_response_builder2);
    try cpz.rpc.initEmptyReturnMessage(source_response2, 503, true, true);
    var source_response_builder3 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer source_response_builder3.deinit();
    const source_response3 = try generated.Message.initRootTyped(&source_response_builder3);
    try cpz.rpc.initEmptyReturnMessage(source_response3, 504, true, true);
    const source_responses = [_]generated.Message.Builder{ source_response0, source_response1, source_response2, source_response3 };
    try response_source_stats.validateResponseBuilders(source_responses[0..]);
    try std.testing.expectError(error.InvalidTransition, response_source_stats.validateResponseBuilders(source_responses[0..3]));
    const ResponseSourceSink = struct {
        sent: usize = 0,
        dispatch_answer_sum: u32 = 0,
        handoff_answer_sum: u32 = 0,

        fn handle(context: *@This(), position: cpz.rpc.RpcTurnResponseSourcePosition, message: anytype) !void {
            const answer_id = try (try message.get_return_()).get_answerId();
            switch (position.role) {
                .dispatch => context.dispatch_answer_sum += answer_id,
                .handoff_return => context.handoff_answer_sum += answer_id,
            }
            context.sent += 1;
        }
    };
    var response_source_sink: ResponseSourceSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcTurnResponsesToSourceTaggedSink(
        mixed_response_plan,
        source_responses[0..3],
        &response_source_sink,
        ResponseSourceSink.handle,
    ));
    const sent_response_source_stats = try cpz.rpc.sendRpcTurnResponsesToSourceTaggedSinkStats(
        mixed_response_plan,
        source_responses[0..],
        &response_source_sink,
        ResponseSourceSink.handle,
    );
    try std.testing.expectEqual(mixed_response_plan.responseSourceStats(), sent_response_source_stats);
    try std.testing.expectEqual(@as(usize, 4), response_source_sink.sent);
    try std.testing.expectEqual(@as(u32, 501 + 502), response_source_sink.dispatch_answer_sum);
    try std.testing.expectEqual(@as(u32, 503 + 504), response_source_sink.handoff_answer_sum);
    const SourceTaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnResponseSourcePosition,
        message: generated.Message.Builder,
    };
    var response_source_queue = std.ArrayList(SourceTaggedQueueItem).empty;
    defer response_source_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcTurnResponsesToSourceTaggedQueue(
        std.testing.allocator,
        mixed_response_plan,
        source_responses[0..3],
        &response_source_queue,
    ));
    const queued_response_source_stats = try cpz.rpc.appendRpcTurnResponsesToSourceTaggedQueue(
        std.testing.allocator,
        mixed_response_plan,
        source_responses[0..],
        &response_source_queue,
    );
    try std.testing.expectEqual(mixed_response_plan.responseSourceStats(), queued_response_source_stats);
    try std.testing.expectEqual(@as(usize, 4), response_source_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .dispatch, .local_index = 0 }, response_source_queue.items[0].position);
    try std.testing.expectEqual(@as(u32, 501), try (try response_source_queue.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .dispatch, .local_index = 1 }, response_source_queue.items[1].position);
    try std.testing.expectEqual(@as(u32, 502), try (try response_source_queue.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .handoff_return, .local_index = 0 }, response_source_queue.items[2].position);
    try std.testing.expectEqual(@as(u32, 503), try (try response_source_queue.items[2].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.RpcTurnResponseSourcePosition{ .role = .handoff_return, .local_index = 1 }, response_source_queue.items[3].position);
    try std.testing.expectEqual(@as(u32, 504), try (try response_source_queue.items[3].message.get_return_()).get_answerId());
    const ResponseSourceRoleSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    var dispatch_response_sink: ResponseSourceRoleSink = .{};
    var handoff_response_sink: ResponseSourceRoleSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcTurnResponsesToSourceSinks(
        mixed_response_plan,
        source_responses[0..3],
        &dispatch_response_sink,
        ResponseSourceRoleSink.handle,
        &handoff_response_sink,
        ResponseSourceRoleSink.handle,
    ));
    const split_response_source_stats = try cpz.rpc.sendRpcTurnResponsesToSourceSinksStats(
        mixed_response_plan,
        source_responses[0..],
        &dispatch_response_sink,
        ResponseSourceRoleSink.handle,
        &handoff_response_sink,
        ResponseSourceRoleSink.handle,
    );
    try std.testing.expectEqual(mixed_response_plan.responseSourceStats(), split_response_source_stats);
    try std.testing.expectEqual(@as(usize, 2), dispatch_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 501 + 502), dispatch_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 2), handoff_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 503 + 504), handoff_response_sink.answer_sum);
    var dispatch_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer dispatch_response_queue.deinit(std.testing.allocator);
    var handoff_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer handoff_response_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcTurnResponsesToSourceQueues(
        std.testing.allocator,
        mixed_response_plan,
        source_responses[0..3],
        &dispatch_response_queue,
        &handoff_response_queue,
    ));
    const queued_split_response_source_stats = try cpz.rpc.appendRpcTurnResponsesToSourceQueues(
        std.testing.allocator,
        mixed_response_plan,
        source_responses[0..],
        &dispatch_response_queue,
        &handoff_response_queue,
    );
    try std.testing.expectEqual(mixed_response_plan.responseSourceStats(), queued_split_response_source_stats);
    try std.testing.expectEqual(@as(usize, 2), dispatch_response_queue.items.len);
    try std.testing.expectEqual(@as(u32, 501), try (try dispatch_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 502), try (try dispatch_response_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(usize, 2), handoff_response_queue.items.len);
    try std.testing.expectEqual(@as(u32, 503), try (try handoff_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 504), try (try handoff_response_queue.items[1].get_return_()).get_answerId());

    var unified_sink: UnifiedSink = .{};
    try std.testing.expectEqual(
        cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 },
        try cpz.rpc.sendRpcTurnUnifiedOutputsToSinkStats(plan, outputs[0..], &unified_sink, UnifiedSink.handle),
    );
    try std.testing.expectEqual(@as(usize, 3), unified_sink.sent);

    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 },
        try cpz.rpc.appendRpcTurnUnifiedOutputsToQueue(std.testing.allocator, plan, outputs[0..], &output_queue),
    );
    try std.testing.expectEqual(@as(usize, 3), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 301);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[1], 302, .{ .imported_cap = 3 });
    try support.expectQueuedDisembargoBuilder(output_queue.items[2], .{ .imported_cap = 4 }, "role-disembargo");

    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var disembargo_queue = std.ArrayList(generated.Message.Builder).empty;
    defer disembargo_queue.deinit(std.testing.allocator);
    const queued_split_stats = try cpz.rpc.appendRpcTurnUnifiedOutputsToQueues(
        std.testing.allocator,
        plan,
        outputs[0..],
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }, queued_split_stats);
    try queued_split_stats.validateAgainstTurnPlan(plan);
    try std.testing.expectEqual(@as(usize, 1), response_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 301);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 302, .{ .imported_cap = 3 });
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 4 }, "role-disembargo");
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcTurnUnifiedOutputsToQueues(
        std.testing.allocator,
        plan,
        outputs[0..2],
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    ));

    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    const sent_stats = try cpz.rpc.sendRpcTurnUnifiedOutputsToSinksStats(
        plan,
        outputs[0..],
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
        &disembargo_sink,
        DisembargoSink.handle,
    );
    try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 301), response_sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 302), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }, sent_stats);
    try std.testing.expectEqual(generated.Message.Union0.unimplemented, (try unused.which()).?);
}

test "rpc unified output helper sends tagged output roles" {
    const TaggedSink = struct {
        sent: usize = 0,
        response_local: usize = 999,
        forward_local: usize = 999,
        disembargo_local: usize = 999,
        stats: cpz.rpc.RpcOutputStats = .{},

        fn handle(context: *@This(), position: cpz.rpc.RpcTurnOutputPosition, message: anytype) !void {
            context.stats.recordPosition(position);
            switch (context.sent) {
                0 => {
                    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, position);
                    try support.expectQueuedReturnAnswer(message, 401);
                    context.response_local = position.local_index;
                },
                1 => {
                    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, position);
                    try support.expectQueuedForwardedCallBuilder(message, 402, .{ .imported_cap = 6 });
                    context.forward_local = position.local_index;
                },
                2 => {
                    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, position);
                    try support.expectQueuedDisembargoBuilder(message, .{ .imported_cap = 7 }, "tagged-disembargo");
                    context.disembargo_local = position.local_index;
                },
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };

    const plan: cpz.rpc.RpcTurnPlan = .{
        .dispatch = .{ .response_initialized = 1, .forward_required = 1, .state_applied = 2 },
        .pending_disembargos = 1,
    };
    try std.testing.expect(plan.hasWork());
    try std.testing.expect(!plan.isEmpty());
    try std.testing.expect((cpz.rpc.RpcTurnPlan{ .dispatch = .{ .state_applied = 1 } }).hasWork());
    try std.testing.expect(!(cpz.rpc.RpcTurnPlan{ .dispatch = .{ .state_applied = 1 } }).hasOutputs());
    try std.testing.expect((cpz.rpc.RpcTurnPlan{}).isEmpty());
    try std.testing.expect(!(cpz.rpc.RpcTurnPlan{}).hasWork());
    const response_position = cpz.rpc.rpcTurnUnifiedOutputPosition(plan, 0).?;
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, response_position);
    try std.testing.expectEqual(response_position, plan.unifiedOutputPosition(0).?);
    try std.testing.expectEqual(@as(?usize, 0), plan.responseLocalIndex(0));
    try std.testing.expectEqual(@as(?usize, 0), plan.outputIndex(response_position));
    try std.testing.expectEqual(@as(?usize, 0), plan.responseOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan.responseOutputIndex(1));
    try std.testing.expect(response_position.isResponse());
    try std.testing.expect(!response_position.isForward());
    try std.testing.expect(!response_position.isDisembargo());
    const forward_position = cpz.rpc.rpcTurnUnifiedOutputPosition(plan, 1).?;
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, forward_position);
    try std.testing.expectEqual(forward_position, plan.unifiedOutputPosition(1).?);
    try std.testing.expectEqual(@as(?usize, 0), plan.forwardLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, 1), plan.outputIndex(forward_position));
    try std.testing.expectEqual(@as(?usize, 1), plan.forwardOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan.forwardOutputIndex(1));
    try std.testing.expect(plan.responseLocalIndex(1) == null);
    try std.testing.expect(forward_position.isForward());
    try std.testing.expect(!forward_position.isResponse());
    const disembargo_position = cpz.rpc.rpcTurnUnifiedOutputPosition(plan, 2).?;
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, disembargo_position);
    try std.testing.expectEqual(disembargo_position, plan.unifiedOutputPosition(2).?);
    try std.testing.expectEqual(@as(?usize, 0), plan.disembargoLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 2), plan.outputIndex(disembargo_position));
    try std.testing.expectEqual(@as(?usize, 2), plan.disembargoOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan.disembargoOutputIndex(1));
    try std.testing.expect(plan.forwardLocalIndex(2) == null);
    try std.testing.expect(disembargo_position.isDisembargo());
    try std.testing.expect(!disembargo_position.isResponse());
    try std.testing.expect(cpz.rpc.rpcTurnUnifiedOutputPosition(plan, 3) == null);
    try std.testing.expect(plan.unifiedOutputPosition(3) == null);
    var indexed_stats: cpz.rpc.RpcOutputStats = .{};
    try indexed_stats.recordTurnOutputIndex(plan, 0);
    try indexed_stats.recordTurnOutputIndex(plan, 1);
    try indexed_stats.recordTurnOutputIndex(plan, 2);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }, indexed_stats);
    try std.testing.expectError(error.InvalidTransition, indexed_stats.recordTurnOutputIndex(plan, 3));

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    try cpz.rpc.initEmptyReturnMessage(response, 401, true, true);

    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);
    try cpz.rpc.initWireCallMessageText(forward, 402, .{ .imported_cap = 6 }, "tagged forward", &.{});

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo, .{
        .target = .{ .imported_cap = 7 },
        .context = .{ .accept = "tagged-disembargo" },
    });

    const outputs = [_]generated.Message.Builder{ response, forward, disembargo };
    var sink: TaggedSink = .{};
    const sent_stats = try cpz.rpc.sendRpcTurnUnifiedOutputsToTaggedSinkStats(plan, outputs[0..], &sink, TaggedSink.handle);
    try std.testing.expectEqual(@as(usize, 3), sink.sent);
    try std.testing.expectEqual(@as(usize, 0), sink.response_local);
    try std.testing.expectEqual(@as(usize, 0), sink.forward_local);
    try std.testing.expectEqual(@as(usize, 0), sink.disembargo_local);
    try std.testing.expectEqual(sent_stats, sink.stats);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }, sink.stats);
    try std.testing.expectEqual(@as(usize, 3), sink.stats.total());
    try std.testing.expect(sink.stats.hasOutputs());
    try std.testing.expect(sink.stats.hasResponses());
    try std.testing.expect(sink.stats.hasForwards());
    try std.testing.expect(sink.stats.hasDisembargos());

    const TaggedQueueItem = struct {
        position: cpz.rpc.RpcTurnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue = std.ArrayList(TaggedQueueItem).empty;
    defer tagged_queue.deinit(std.testing.allocator);
    const queued_stats = try cpz.rpc.appendRpcTurnUnifiedOutputsToTaggedQueue(std.testing.allocator, plan, outputs[0..], &tagged_queue);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1, .disembargos = 1 }, queued_stats);
    try queued_stats.validateAgainstTurnPlan(plan);
    try std.testing.expectEqual(@as(usize, 3), tagged_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .response, .local_index = 0 }, tagged_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_queue.items[0].message, 401);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .forward, .local_index = 0 }, tagged_queue.items[1].position);
    try support.expectQueuedForwardedCallBuilder(tagged_queue.items[1].message, 402, .{ .imported_cap = 6 });
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_queue.items[2].position);
    try support.expectQueuedDisembargoBuilder(tagged_queue.items[2].message, .{ .imported_cap = 7 }, "tagged-disembargo");
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcTurnUnifiedOutputsToTaggedQueue(std.testing.allocator, plan, outputs[0..2], &tagged_queue));
}
