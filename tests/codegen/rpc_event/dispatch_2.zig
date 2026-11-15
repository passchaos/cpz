const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc batch dispatcher routes messages and aggregates outcomes" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 2000;
        }
    };
    const CallHandler = struct {
        fn handle(_: *u32, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(31, .call);

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 30);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(31);
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

    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ bootstrap_message, return_message };
    const stats = try cpz.rpc.dispatchWireMessages(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    );
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(usize, 2), stats.total());
    try std.testing.expect(state.questionComplete(31));

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
    var outcome_state = cpz.rpc.State.init(std.testing.allocator);
    defer outcome_state.deinit();
    try outcome_state.openQuestion(31, .call);
    var outcome_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer outcome_response_builder0.deinit();
    const outcome_response0 = try generated.Message.initRootTyped(&outcome_response_builder0);
    var outcome_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer outcome_response_builder1.deinit();
    const outcome_response1 = try generated.Message.initRootTyped(&outcome_response_builder1);
    const outcome_responses = [_]generated.Message.Builder{ outcome_response0, outcome_response1 };
    var outcome_bootstrap_seen: u32 = 0;
    var outcome_call_seen: u32 = 0;
    var observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesWithOutcomeHandler(
        &outcome_state,
        std.testing.allocator,
        outcome_responses[0..],
        requests[0..],
        &outcome_bootstrap_seen,
        BootstrapHandler.handle,
        &outcome_call_seen,
        CallHandler.handle,
        &observer,
        OutcomeObserver.handle,
    );
    try std.testing.expectEqual(stats, observed_stats);
    try std.testing.expectEqual(stats, observer.observed);
    try std.testing.expectEqual(@as(usize, 2), observer.calls);
    try std.testing.expectEqual(@as(usize, 1), observer.index_sum);
    try std.testing.expect(outcome_state.questionComplete(31));

    var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 2030 }, descriptors[0]);

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessages(
        &state,
        std.testing.allocator,
        responses[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    ));
}

test "rpc batch dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 2100;
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
        state_applied: usize = 0,
        disembargos: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .state_applied => context.state_applied += 1,
                .disembargo => |info| {
                    context.disembargos += 1;
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
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
        .question_id = 44,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dispatch-44",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    const accept_message = generated.Message.fromReader(try accept_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "dispatch-44" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder0.deinit();
    const response0 = try generated.Message.initRootTyped(&response_builder0);
    var response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer response_builder1.deinit();
    const response1 = try generated.Message.initRootTyped(&response_builder1);

    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ accept_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
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
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .state_applied = 2 }, stats);
    try std.testing.expectEqual(@as(usize, 2), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.state_applied);
    try std.testing.expectEqual(@as(usize, 1), apply_context.disembargos);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 44), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(44));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 1, .capability = 0 }, state.readyAcceptProvision(44).?);

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
    var observed_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_accept_builder.deinit();
    const observed_accept_root = try generated.Message.initRootTyped(&observed_accept_builder);
    try cpz.rpc.initWireAcceptMessage(observed_accept_root, .{
        .question_id = 44,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dispatch-44",
    });
    var observed_accept_reader = cpz.MessageReader.init(try observed_accept_builder.segmentsConst(), .{});
    const observed_accept_message = generated.Message.fromReader(try observed_accept_reader.getRoot());
    var observed_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer observed_response_builder0.deinit();
    const observed_response0 = try generated.Message.initRootTyped(&observed_response_builder0);
    var observed_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer observed_response_builder1.deinit();
    const observed_response1 = try generated.Message.initRootTyped(&observed_response_builder1);
    const observed_responses = [_]generated.Message.Builder{ observed_response0, observed_response1 };
    const observed_requests = [_]generated.Message{ observed_accept_message, disembargo_message };
    var observed_bootstrap_seen: u32 = 0;
    var observed_call_seen: u32 = 0;
    var observed_apply_context: ApplyContext = .{};
    var outcome_observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesWithOutcomeHandlerAndApplyHandler(
        &observed_state,
        std.testing.allocator,
        observed_responses[0..],
        observed_requests[0..],
        &observed_bootstrap_seen,
        BootstrapHandler.handle,
        &observed_call_seen,
        CallHandler.handle,
        &outcome_observer,
        OutcomeObserver.handle,
        &observed_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, observed_stats);
    try std.testing.expectEqual(stats, outcome_observer.observed);
    try std.testing.expectEqual(@as(usize, 2), outcome_observer.calls);
    try std.testing.expectEqual(@as(usize, 1), outcome_observer.index_sum);
    try std.testing.expectEqual(@as(usize, 2), observed_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), observed_apply_context.released_accepts);
}

test "rpc dense response dispatcher skips response slots for state-only messages" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 3100;
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

        fn handle(context: *@This(), queued_message: anytype) !void {
            const return_ = try queued_message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(39, .call);

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 38);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    const return_ = try return_root.init_return_();
    try return_.set_answerId(39);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);

    const responses = [_]generated.Message.Builder{response};
    const requests = [_]generated.Message{ bootstrap_message, return_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var sink: Sink = .{};
    const stats = try cpz.rpc.dispatchWireMessagesToDenseSink(
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
    try std.testing.expectEqual(@as(u32, 38), sink.last_answer);
    try std.testing.expect(state.questionComplete(39));
}

test "rpc dense dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 3200;
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
        state_applied: usize = 0,
        disembargos: usize = 0,
        released_accepts: usize = 0,
        released_question_sum: u32 = 0,

        fn handle(context: *@This(), result: cpz.rpc.WireMessageApplyResult) !void {
            context.calls += 1;
            switch (result) {
                .state_applied => context.state_applied += 1,
                .disembargo => |info| {
                    context.disembargos += 1;
                    context.released_accepts += info.released_accepts;
                    for (info.released_accept_ids) |id| context.released_question_sum += id;
                },
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
        .question_id = 59,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dense-59",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    const accept_message = generated.Message.fromReader(try accept_reader.getRoot());

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 60);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "dense-59" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);

    const responses = [_]generated.Message.Builder{response};
    const requests = [_]generated.Message{ accept_message, bootstrap_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesDenseWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
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
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .state_applied = 2 }, stats);
    try std.testing.expectEqual(@as(usize, 2), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.state_applied);
    try std.testing.expectEqual(@as(usize, 1), apply_context.disembargos);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 59), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(59));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response_message = generated.Message.fromReader(try response_reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response_message.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 3260 }, descriptors[0]);

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesDenseToQueueWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 60);
    try std.testing.expectEqual(@as(usize, 2), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.state_applied);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.disembargos);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 59), queue_apply_context.released_question_sum);
}

test "rpc forwarding dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7100;
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
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 300 });
    try state.resolveImportTo(300, .{ .sender_hosted = 301 });
    try state.applyCapDescriptor(.{ .sender_hosted = 301 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 51,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "forward-51",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(300);
    const target = try call.init_target();
    try target.set_importedCap(300);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "forward-51" },
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
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
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
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .forward_required = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 51), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(51));

    var forward_reader = cpz.MessageReader.init(try forward_builder0.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 301 }, try cpz.rpc.callTargetFromWireCall(forwarded));
}

test "rpc batch forwarding dispatcher aggregates forwarded calls" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 5000;
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
    try state.applyCapDescriptor(.{ .sender_promise = 200 });
    try state.resolveImportTo(200, .{ .sender_hosted = 201 });
    try state.applyCapDescriptor(.{ .sender_hosted = 201 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 34);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(200);
    const target = try call.init_target();
    try target.set_importedCap(200);
    try cpz.rpc.initWireCallParamsText(call, "batch forward", &.{.{ .sender_hosted = 202 }});
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
    const stats = try cpz.rpc.dispatchWireMessagesForwarding(
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
    try std.testing.expectEqual(@as(usize, 0), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), call_seen);

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
    try observed_state.applyCapDescriptor(.{ .sender_promise = 200 });
    try observed_state.resolveImportTo(200, .{ .sender_hosted = 201 });
    try observed_state.applyCapDescriptor(.{ .sender_hosted = 201 });
    var observed_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder0.deinit();
    const observed_response0 = try generated.Message.initRootTyped(&observed_response_builder0);
    var observed_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder1.deinit();
    const observed_response1 = try generated.Message.initRootTyped(&observed_response_builder1);
    var observed_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_forward_builder0.deinit();
    const observed_forward0 = try generated.Message.initRootTyped(&observed_forward_builder0);
    var observed_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer observed_forward_builder1.deinit();
    const observed_forward1 = try generated.Message.initRootTyped(&observed_forward_builder1);
    const observed_responses = [_]generated.Message.Builder{ observed_response0, observed_response1 };
    const observed_forwards = [_]generated.Message.Builder{ observed_forward0, observed_forward1 };
    var observed_bootstrap_seen: u32 = 0;
    var observed_call_seen: u32 = 0;
    var observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesForwardingWithOutcomeHandler(
        &observed_state,
        std.testing.allocator,
        observed_responses[0..],
        observed_forwards[0..],
        requests[0..],
        &observed_bootstrap_seen,
        BootstrapHandler.handle,
        &observed_call_seen,
        CallHandler.handle,
        &observer,
        OutcomeObserver.handle,
    );
    try std.testing.expectEqual(stats, observed_stats);
    try std.testing.expectEqual(stats, observer.observed);
    try std.testing.expectEqual(@as(usize, 2), observer.calls);
    try std.testing.expectEqual(@as(usize, 1), observer.index_sum);

    var forward_reader = cpz.MessageReader.init(try forward_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 201 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("batch forward", try (try (try forwarded.params()).content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, try forwarded.params());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 202 }, descriptors[0]);

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesForwarding(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    ));
}

test "rpc dense forwarding dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 7400;
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
    try state.applyCapDescriptor(.{ .sender_promise = 360 });
    try state.resolveImportTo(360, .{ .sender_hosted = 361 });
    try state.applyCapDescriptor(.{ .sender_hosted = 361 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 63,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dense-forward-63",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 64);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(360);
    const target = try call.init_target();
    try target.set_importedCap(360);
    try cpz.rpc.initWireCallParamsText(call, "dense forward apply", &.{.{ .sender_hosted = 362 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "dense-forward-63" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{response};
    const forwards = [_]generated.Message.Builder{forward};
    const requests = [_]generated.Message{ bootstrap_message, call_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesForwardingToDenseSinksWithApplyHandler(
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
    try std.testing.expectEqual(@as(u32, 64), response_sink.last_answer);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 360), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 63), apply_context.released_question_sum);

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 361 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqualStrings("dense forward apply", try (try (try forwarded.params()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 360 });
    try queue_state.resolveImportTo(360, .{ .sender_hosted = 361 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 361 });
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 630,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dense-forward-queue-630",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "dense-forward-queue-630" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    const queue_requests = [_]generated.Message{ bootstrap_message, call_message, queue_disembargo_message };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesForwardingDenseToQueuesWithApplyHandler(
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
    try support.expectQueuedReturnAnswer(response_queue.items[0], 64);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 360, .{ .imported_cap = 361 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 630), queue_apply_context.released_question_sum);
}

test "rpc batch method-table forwarding dispatcher aggregates forwarded calls" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 6000;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x6666, .method_id = 6 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 210 });
    try state.resolveImportTo(210, .{ .sender_hosted = 211 });
    try state.applyCapDescriptor(.{ .sender_hosted = 211 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 35);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(210);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x6666, .method_id = 6 }, call);
    const target = try call.init_target();
    try target.set_importedCap(210);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 6, 12 }, &.{.{ .sender_hosted = 212 }});
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
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwarding(
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
    try std.testing.expectEqual(@as(usize, 0), stats.state_applied);
    try std.testing.expectEqual(@as(u32, 0), context.selected);

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
    try observed_state.applyCapDescriptor(.{ .sender_promise = 210 });
    try observed_state.resolveImportTo(210, .{ .sender_hosted = 211 });
    try observed_state.applyCapDescriptor(.{ .sender_hosted = 211 });
    var observed_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder0.deinit();
    const observed_response0 = try generated.Message.initRootTyped(&observed_response_builder0);
    var observed_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder1.deinit();
    const observed_response1 = try generated.Message.initRootTyped(&observed_response_builder1);
    var observed_forward_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_forward_builder0.deinit();
    const observed_forward0 = try generated.Message.initRootTyped(&observed_forward_builder0);
    var observed_forward_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer observed_forward_builder1.deinit();
    const observed_forward1 = try generated.Message.initRootTyped(&observed_forward_builder1);
    const observed_responses = [_]generated.Message.Builder{ observed_response0, observed_response1 };
    const observed_forwards = [_]generated.Message.Builder{ observed_forward0, observed_forward1 };
    var observed_bootstrap_seen: u32 = 0;
    var observed_context: Context = .{};
    var observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingWithOutcomeHandler(
        &observed_state,
        std.testing.allocator,
        observed_responses[0..],
        observed_forwards[0..],
        requests[0..],
        &observed_bootstrap_seen,
        BootstrapHandler.handle,
        &observed_context,
        entries,
        &observer,
        OutcomeObserver.handle,
    );
    try std.testing.expectEqual(stats, observed_stats);
    try std.testing.expectEqual(stats, observer.observed);
    try std.testing.expectEqual(@as(usize, 2), observer.calls);
    try std.testing.expectEqual(@as(usize, 1), observer.index_sum);
    try std.testing.expectEqual(@as(u32, 0), observed_context.selected);

    var forward_reader = cpz.MessageReader.init(try forward_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 211 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x6666, .method_id = 6 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 6, 12 });

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireMessagesMethodsForwarding(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..1],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
    ));
}

test "rpc method-table forwarding dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9500;
        }
    };
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
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
    const ResponseSink = struct {
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

    {
        const entries = .{
            .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5560, .method_id = 10 }, .handler = Handler.handle },
        };
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        try state.applyCapDescriptor(.{ .sender_promise = 330 });
        try state.resolveImportTo(330, .{ .sender_hosted = 331 });
        try state.applyCapDescriptor(.{ .sender_hosted = 331 });

        var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer accept_builder.deinit();
        const accept_root = try generated.Message.initRootTyped(&accept_builder);
        try cpz.rpc.initWireAcceptMessage(accept_root, .{
            .question_id = 55,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-55",
        });
        var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

        var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer call_builder.deinit();
        const call_root = try generated.Message.initRootTyped(&call_builder);
        const call = try call_root.init_call();
        try call.set_questionId(330);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5560, .method_id = 10 }, call);
        const target = try call.init_target();
        try target.set_importedCap(330);
        _ = try call.init_params();
        var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
        const call_message = generated.Message.fromReader(try call_reader.getRoot());

        var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer disembargo_builder.deinit();
        const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "method-forward-55" },
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
        var context: Context = .{};
        var apply_context: ApplyContext = .{};
        const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingWithApplyHandler(
            &state,
            std.testing.allocator,
            responses[0..],
            forwards[0..],
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
        try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .forward_required = 1, .state_applied = 1 }, stats);
        try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
        try std.testing.expectEqual(@as(u32, 55), apply_context.released_question_sum);
        try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(55));

        var forward_reader = cpz.MessageReader.init(try forward_builder0.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 331 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x5560, .method_id = 10 }, cpz.rpc.callMethodFromWireCall(forwarded));

        var queue_state = cpz.rpc.State.init(std.testing.allocator);
        defer queue_state.deinit();
        try queue_state.addImport(5);
        try queue_state.applyCapDescriptor(.{ .sender_promise = 330 });
        try queue_state.resolveImportTo(330, .{ .sender_hosted = 331 });
        try queue_state.applyCapDescriptor(.{ .sender_hosted = 331 });
        var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_accept_builder.deinit();
        const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
        try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
            .question_id = 550,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-55",
        });
        var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
        var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer queue_response_builder.deinit();
        const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
        var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_forward_builder.deinit();
        const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
        var forward_queue = std.ArrayList(generated.Message.Builder).empty;
        defer forward_queue.deinit(std.testing.allocator);
        var queue_bootstrap_seen: u32 = 0;
        var queue_context: Context = .{};
        var queue_apply_context: ApplyContext = .{};
        try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, try cpz.rpc.dispatchWireMessageMethodsForwardingToQueueOutcomeWithApplyHandler(
            &queue_state,
            std.testing.allocator,
            queue_response,
            queue_forward,
            call_message,
            &queue_bootstrap_seen,
            BootstrapHandler.handle,
            &queue_context,
            entries,
            &forward_queue,
            &queue_apply_context,
            ApplyContext.handle,
        ));
        try std.testing.expectEqual(@as(u32, 0), queue_bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
        try std.testing.expectEqual(@as(usize, 0), queue_apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
        try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 330, .{ .imported_cap = 331 });

        var unused_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer unused_response_builder.deinit();
        const unused_response = try generated.Message.initRootTyped(&unused_response_builder);
        var unused_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer unused_forward_builder.deinit();
        const unused_forward = try generated.Message.initRootTyped(&unused_forward_builder);
        try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.state_applied, try cpz.rpc.dispatchWireMessageMethodsForwardingToQueueOutcomeWithApplyHandler(
            &queue_state,
            std.testing.allocator,
            unused_response,
            unused_forward,
            disembargo_message,
            &queue_bootstrap_seen,
            BootstrapHandler.handle,
            &queue_context,
            entries,
            &forward_queue,
            &queue_apply_context,
            ApplyContext.handle,
        ));
        try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
        try std.testing.expectEqual(@as(u32, 550), queue_apply_context.released_question_sum);
        try std.testing.expectEqual(@as(?bool, true), queue_state.acceptEmbargoReleased(550));
    }

    {
        const entries = .{
            .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5561, .method_id = 11 }, .handler = Handler.handle },
        };
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        try state.applyCapDescriptor(.{ .sender_promise = 340 });
        try state.resolveImportTo(340, .{ .sender_hosted = 341 });
        try state.applyCapDescriptor(.{ .sender_hosted = 341 });

        var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer accept_builder.deinit();
        const accept_root = try generated.Message.initRootTyped(&accept_builder);
        try cpz.rpc.initWireAcceptMessage(accept_root, .{
            .question_id = 56,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-sink-56",
        });
        var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

        var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer call_builder.deinit();
        const call_root = try generated.Message.initRootTyped(&call_builder);
        const call = try call_root.init_call();
        try call.set_questionId(340);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5561, .method_id = 11 }, call);
        const target = try call.init_target();
        try target.set_importedCap(340);
        _ = try call.init_params();
        var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
        const call_message = generated.Message.fromReader(try call_reader.getRoot());

        var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer disembargo_builder.deinit();
        const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "method-forward-sink-56" },
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
        var context: Context = .{};
        var forward_sink: ForwardSink = .{};
        var apply_context: ApplyContext = .{};
        const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToSinkWithApplyHandler(
            &state,
            std.testing.allocator,
            responses[0..],
            forwards[0..],
            requests[0..],
            &bootstrap_seen,
            BootstrapHandler.handle,
            &context,
            entries,
            &forward_sink,
            ForwardSink.handle,
            &apply_context,
            ApplyContext.handle,
        );
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), context.selected);
        try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .forward_required = 1, .state_applied = 1 }, stats);
        try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
        try std.testing.expectEqual(@as(u32, 340), forward_sink.last_question);
        try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
        try std.testing.expectEqual(@as(u32, 56), apply_context.released_question_sum);

        var queue_state = cpz.rpc.State.init(std.testing.allocator);
        defer queue_state.deinit();
        try queue_state.addImport(5);
        try queue_state.applyCapDescriptor(.{ .sender_promise = 340 });
        try queue_state.resolveImportTo(340, .{ .sender_hosted = 341 });
        try queue_state.applyCapDescriptor(.{ .sender_hosted = 341 });
        var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_accept_builder.deinit();
        const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
        try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
            .question_id = 560,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-queue-560",
        });
        var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
        var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_disembargo_builder.deinit();
        const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "method-forward-queue-560" },
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
        var queue_context: Context = .{};
        var queue_apply_context: ApplyContext = .{};
        var forward_queue = std.ArrayList(generated.Message.Builder).empty;
        defer forward_queue.deinit(std.testing.allocator);
        const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToQueueWithApplyHandler(
            &queue_state,
            std.testing.allocator,
            queue_responses[0..],
            queue_forwards[0..],
            queue_requests[0..],
            &queue_bootstrap_seen,
            BootstrapHandler.handle,
            &queue_context,
            entries,
            &forward_queue,
            &queue_apply_context,
            ApplyContext.handle,
        );
        try std.testing.expectEqual(stats, queue_stats);
        try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
        try std.testing.expectEqual(@as(u32, 560), queue_apply_context.released_question_sum);
        try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
        try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 340, .{ .imported_cap = 341 });

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
        try observed_state.applyCapDescriptor(.{ .sender_promise = 340 });
        try observed_state.resolveImportTo(340, .{ .sender_hosted = 341 });
        try observed_state.applyCapDescriptor(.{ .sender_hosted = 341 });
        var observed_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer observed_accept_builder.deinit();
        const observed_accept_root = try generated.Message.initRootTyped(&observed_accept_builder);
        try cpz.rpc.initWireAcceptMessage(observed_accept_root, .{
            .question_id = 561,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-observe-561",
        });
        var observed_accept_reader = cpz.MessageReader.init(try observed_accept_builder.segmentsConst(), .{});
        try observed_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try observed_accept_reader.getRoot()));
        var observed_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer observed_disembargo_builder.deinit();
        const observed_disembargo_root = try generated.Message.initRootTyped(&observed_disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(observed_disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "method-forward-observe-561" },
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
        var observed_context: Context = .{};
        var observed_apply_context: ApplyContext = .{};
        var observer: OutcomeObserver = .{};
        const observed_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingWithOutcomeHandlerAndApplyHandler(
            &observed_state,
            std.testing.allocator,
            observed_responses[0..],
            observed_forwards[0..],
            observed_requests[0..],
            &observed_bootstrap_seen,
            BootstrapHandler.handle,
            &observed_context,
            entries,
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

    {
        const entries = .{
            .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5562, .method_id = 12 }, .handler = Handler.handle },
        };
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        try state.applyCapDescriptor(.{ .sender_promise = 350 });
        try state.resolveImportTo(350, .{ .sender_hosted = 351 });
        try state.applyCapDescriptor(.{ .sender_hosted = 351 });

        var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer accept_builder.deinit();
        const accept_root = try generated.Message.initRootTyped(&accept_builder);
        try cpz.rpc.initWireAcceptMessage(accept_root, .{
            .question_id = 57,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-dual-57",
        });
        var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

        var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer bootstrap_builder.deinit();
        const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
        try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 58);
        var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
        const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

        var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer call_builder.deinit();
        const call_root = try generated.Message.initRootTyped(&call_builder);
        const call = try call_root.init_call();
        try call.set_questionId(350);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5562, .method_id = 12 }, call);
        const target = try call.init_target();
        try target.set_importedCap(350);
        _ = try call.init_params();
        var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
        const call_message = generated.Message.fromReader(try call_reader.getRoot());

        var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer disembargo_builder.deinit();
        const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "method-forward-dual-57" },
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
        var context: Context = .{};
        var response_sink: ResponseSink = .{};
        var forward_sink: ForwardSink = .{};
        var apply_context: ApplyContext = .{};
        const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToSinksWithApplyHandler(
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
            &apply_context,
            ApplyContext.handle,
        );
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), context.selected);
        try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1, .state_applied = 1 }, stats);
        try std.testing.expectEqual(@as(usize, 1), response_sink.sent);
        try std.testing.expectEqual(@as(u32, 58), response_sink.last_answer);
        try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
        try std.testing.expectEqual(@as(u32, 350), forward_sink.last_question);
        try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
        try std.testing.expectEqual(@as(u32, 57), apply_context.released_question_sum);

        var queue_state = cpz.rpc.State.init(std.testing.allocator);
        defer queue_state.deinit();
        try queue_state.addImport(5);
        try queue_state.applyCapDescriptor(.{ .sender_promise = 350 });
        try queue_state.resolveImportTo(350, .{ .sender_hosted = 351 });
        try queue_state.applyCapDescriptor(.{ .sender_hosted = 351 });
        var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_accept_builder.deinit();
        const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
        try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
            .question_id = 570,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "method-forward-dual-queue-570",
        });
        var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
        var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_disembargo_builder.deinit();
        const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "method-forward-dual-queue-570" },
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
        var queue_context: Context = .{};
        var queue_apply_context: ApplyContext = .{};
        const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingToQueuesWithApplyHandler(
            &queue_state,
            std.testing.allocator,
            queue_responses[0..],
            queue_forwards[0..],
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
        try support.expectQueuedReturnAnswer(response_queue.items[0], 58);
        try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 350, .{ .imported_cap = 351 });
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
        try std.testing.expectEqual(@as(u32, 570), queue_apply_context.released_question_sum);
    }
}

test "rpc dense method-table forwarding dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9700;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5564, .method_id = 14 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 370 });
    try state.resolveImportTo(370, .{ .sender_hosted = 371 });
    try state.applyCapDescriptor(.{ .sender_hosted = 371 });

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 65,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dense-method-forward-65",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(370);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5564, .method_id = 14 }, call);
    const target = try call.init_target();
    try target.set_importedCap(370);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 14, 28 }, &.{.{ .sender_hosted = 372 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "dense-method-forward-65" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward = try generated.Message.initRootTyped(&forward_builder);

    const responses = [_]generated.Message.Builder{response};
    const forwards = [_]generated.Message.Builder{forward};
    const requests = [_]generated.Message{ call_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingDenseWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
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
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .forward_required = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 65), apply_context.released_question_sum);

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 371 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x5564, .method_id = 14 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 14, 28 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 370 });
    try queue_state.resolveImportTo(370, .{ .sender_hosted = 371 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 371 });
    var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_accept_builder.deinit();
    const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
    try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
        .question_id = 650,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dense-method-forward-queue-650",
    });
    var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
    try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));
    var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_disembargo_builder.deinit();
    const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "dense-method-forward-queue-650" },
    });
    var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
    const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    const queue_requests = [_]generated.Message{ call_message, queue_disembargo_message };
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsForwardingDenseToQueuesWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
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
    try std.testing.expectEqual(@as(usize, 0), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 370, .{ .imported_cap = 371 });
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 650), queue_apply_context.released_question_sum);
}

test "rpc batch dispatcher supports method tables" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 4000;
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
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x4444, .method_id = 4 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(33);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x4444, .method_id = 4 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var finish_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer finish_builder.deinit();
    const finish_root = try generated.Message.initRootTyped(&finish_builder);
    try cpz.rpc.initWireFinishMessage(finish_root, .{ .question_id = 33, .release_result_caps = false });
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
    const responses = [_]generated.Message.Builder{ response0, response1 };
    const requests = [_]generated.Message{ call_message, finish_message };
    const stats = try cpz.rpc.dispatchWireMessagesMethods(
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
    try std.testing.expectEqual(@as(u32, 33), context.selected);
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(33));

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
    var observed_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder0.deinit();
    const observed_response0 = try generated.Message.initRootTyped(&observed_response_builder0);
    var observed_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer observed_response_builder1.deinit();
    const observed_response1 = try generated.Message.initRootTyped(&observed_response_builder1);
    const observed_responses = [_]generated.Message.Builder{ observed_response0, observed_response1 };
    var observed_bootstrap_seen: u32 = 0;
    var observed_context: Context = .{};
    var observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesMethodsWithOutcomeHandler(
        &observed_state,
        std.testing.allocator,
        observed_responses[0..],
        requests[0..],
        &observed_bootstrap_seen,
        BootstrapHandler.handle,
        &observed_context,
        entries,
        &observer,
        OutcomeObserver.handle,
    );
    try std.testing.expectEqual(stats, observed_stats);
    try std.testing.expectEqual(stats, observer.observed);
    try std.testing.expectEqual(@as(usize, 2), observer.calls);
    try std.testing.expectEqual(@as(usize, 1), observer.index_sum);
    try std.testing.expectEqual(@as(u32, 33), observed_context.selected);
}

test "rpc method-table dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9300;
        }
    };
    const Context = struct {
        selected: u32 = 0,
    };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .{ .text = "method apply" };
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5558, .method_id = 8 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 47,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "method-47",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(48);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5558, .method_id = 8 }, call);
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
        .context = .{ .accept = "method-47" },
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
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 48), context.selected);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .state_applied = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 47), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(47));

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
    var observed_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_accept_builder.deinit();
    const observed_accept_root = try generated.Message.initRootTyped(&observed_accept_builder);
    try cpz.rpc.initWireAcceptMessage(observed_accept_root, .{
        .question_id = 47,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "method-47",
    });
    var observed_accept_reader = cpz.MessageReader.init(try observed_accept_builder.segmentsConst(), .{});
    try observed_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try observed_accept_reader.getRoot()));
    var observed_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer observed_response_builder0.deinit();
    const observed_response0 = try generated.Message.initRootTyped(&observed_response_builder0);
    var observed_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer observed_response_builder1.deinit();
    const observed_response1 = try generated.Message.initRootTyped(&observed_response_builder1);
    const observed_responses = [_]generated.Message.Builder{ observed_response0, observed_response1 };
    var observed_bootstrap_seen: u32 = 0;
    var observed_context: Context = .{};
    var observed_apply_context: ApplyContext = .{};
    var observer: OutcomeObserver = .{};
    const observed_stats = try cpz.rpc.dispatchWireMessagesMethodsWithOutcomeHandlerAndApplyHandler(
        &observed_state,
        std.testing.allocator,
        observed_responses[0..],
        requests[0..],
        &observed_bootstrap_seen,
        BootstrapHandler.handle,
        &observed_context,
        entries,
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

    var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const return_ = try response.return_();
    try std.testing.expectEqual(@as(u32, 48), return_.answerId());
    try std.testing.expectEqualStrings("method apply", try (try (try return_.results()).content()).getText());
}

test "rpc dense method-table response dispatcher skips state-only slots" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9100;
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

        fn handle(context: *@This(), queued_message: anytype) !void {
            const return_ = try queued_message.get_return_();
            context.sent += 1;
            context.last_answer = try return_.get_answerId();
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5556, .method_id = 6 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(39);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5556, .method_id = 6 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    var finish_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer finish_builder.deinit();
    const finish_root = try generated.Message.initRootTyped(&finish_builder);
    try cpz.rpc.initWireFinishMessage(finish_root, .{ .question_id = 39, .release_result_caps = false });
    var finish_reader = cpz.MessageReader.init(try finish_builder.segmentsConst(), .{});
    const finish_message = generated.Message.fromReader(try finish_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var sink: Sink = .{};
    const responses = [_]generated.Message.Builder{response};
    const requests = [_]generated.Message{ call_message, finish_message };
    const stats = try cpz.rpc.dispatchWireMessagesMethodsToDenseSink(
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
    try std.testing.expectEqual(@as(u32, 39), context.selected);
    try std.testing.expectEqual(@as(usize, 1), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 39), sink.last_answer);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(39));
}

test "rpc dense method-table dispatcher reports detailed state apply results" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 9600;
        }
    };
    const Context = struct {
        selected: u32 = 0,
    };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .{ .text = "dense method apply" };
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5563, .method_id = 13 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 61,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "dense-method-61",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    const accept_message = generated.Message.fromReader(try accept_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(62);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5563, .method_id = 13 }, call);
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
        .context = .{ .accept = "dense-method-61" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response = try generated.Message.initRootTyped(&response_builder);

    const responses = [_]generated.Message.Builder{response};
    const requests = [_]generated.Message{ accept_message, call_message, disembargo_message };
    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    var apply_context: ApplyContext = .{};
    const stats = try cpz.rpc.dispatchWireMessagesMethodsDenseWithApplyHandler(
        &state,
        std.testing.allocator,
        responses[0..],
        requests[0..],
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
        &apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 62), context.selected);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .state_applied = 2 }, stats);
    try std.testing.expectEqual(@as(usize, 2), apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 61), apply_context.released_question_sum);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(61));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response_message = generated.Message.fromReader(try response_reader.getRoot());
    const return_ = try response_message.return_();
    try std.testing.expectEqual(@as(u32, 62), return_.answerId());
    try std.testing.expectEqualStrings("dense method apply", try (try (try return_.results()).content()).getText());

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    var queue_apply_context: ApplyContext = .{};
    const queue_stats = try cpz.rpc.dispatchWireMessagesMethodsDenseToQueueWithApplyHandler(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        requests[0..],
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue,
        &queue_apply_context,
        ApplyContext.handle,
    );
    try std.testing.expectEqual(stats, queue_stats);
    try std.testing.expectEqual(@as(u32, 62), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 62);
    try std.testing.expectEqual(@as(usize, 2), queue_apply_context.calls);
    try std.testing.expectEqual(@as(usize, 1), queue_apply_context.released_accepts);
    try std.testing.expectEqual(@as(u32, 61), queue_apply_context.released_question_sum);
}

test "rpc resolved call targets preserve receiver-answer forwards" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(130, .call);
    try state.applyCapDescriptor(.{ .sender_promise = 131 });
    try state.resolveImportTo(131, .{ .receiver_answer = .{ .question_id = 130 } });

    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 130 } },
        (try state.callTargetTransitiveForwardTarget(.{ .imported_cap = 131 })).?,
    );
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 130 } },
        try state.transitiveEffectiveCallTarget(.{ .imported_cap = 131 }),
    );
}
