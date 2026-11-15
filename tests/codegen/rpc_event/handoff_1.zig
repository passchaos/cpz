const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc call and return payload helpers accept absent capability tables" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(52);
        const target = try call.init_target();
        try target.set_importedCap(9);
        _ = try call.init_params();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireCallParams(std.testing.allocator, try message.call());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 0), descriptors.len);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(53);
        _ = try return_.init_results();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try message.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 0), descriptors.len);
    }
}

test "rpc join result helpers initialize return payloads" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireJoinResultReturnMessage(root, 82, true, 0, &.{.{ .sender_hosted = 83 }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const return_ = try message.return_();
    try std.testing.expectEqual(@as(u32, 82), return_.answerId());
    try std.testing.expect(return_.releaseParamCaps());
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(return_));
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 83 }, descriptors[0]);
}

test "rpc top-level provide and join messages validate targets" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const provide = try root.init_provide();
        try provide.set_questionId(61);
        const target = try provide.init_target();
        try target.set_importedCap(70);
        (try provide.get_recipientAsPointer()).setCapability(2);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.provideInfoFromWireProvide(try message.provide());
        try std.testing.expectEqual(@as(u32, 61), info.question_id);
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 70 }, info.target);
        try std.testing.expect(info.has_recipient);
        try std.testing.expectEqual(@as(usize, 3), info.recipient_max_capability_count);
        try std.testing.expectEqual(@as(?u32, 2), info.recipient_capability);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, info.recipientUsage().?);
        try info.validate();
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.InvalidTransition, state.applyWireMessage(std.testing.allocator, message));
        try state.addImport(70);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(61));
        const tracked = state.provideInfo(61).?;
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 70 }, tracked.target);
        try std.testing.expectEqual(@as(?u32, 2), tracked.recipient_capability);
        try std.testing.expect(tracked.hasRecipientUsage());
        try std.testing.expect(tracked.recipientMatchesCapability(2));
        try std.testing.expect(!tracked.recipientMatchesCapability(1));
        try std.testing.expect(tracked.targetsImport(70));
        try std.testing.expectEqual(@as(?bool, true), state.provideHasRecipientUsage(61));
        try std.testing.expectEqual(@as(?bool, true), state.provideRecipientMatchesCapability(61, 2));
        try std.testing.expectEqual(@as(?bool, false), state.provideRecipientMatchesCapability(61, 1));
        try std.testing.expectEqual(@as(?bool, true), state.provideTargetsImport(61, 70));
        try std.testing.expectEqual(@as(?bool, false), state.provideTargetsPromisedQuestion(61, 70));
        try std.testing.expectEqual(@as(?bool, null), state.provideHasRecipientUsage(999));
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, state.provideRecipient(61).?);
        try std.testing.expectEqual(@as(usize, 1), state.provideRecipientCount());
        try std.testing.expectEqual(cpz.rpc.StateHandoffStats{ .provides = 1, .provide_recipients = 1 }, state.handoffStats());
        try std.testing.expectEqual(@as(usize, 1), state.handoffStats().tracked());
        try std.testing.expectEqual(@as(usize, 1), state.handoffStats().ready());
        try std.testing.expect(state.handoffStats().hasTracked());
        try std.testing.expect(state.handoffStats().hasReady());
        try std.testing.expect(!state.handoffStats().hasBlocked());
        try std.testing.expect(state.handoffStats().hasWork());
        try std.testing.expect(!state.handoffStats().isEmpty());
        try std.testing.expect((cpz.rpc.StateHandoffStats{}).isEmpty());
        try std.testing.expect(!(cpz.rpc.StateHandoffStats{}).hasWork());
        try std.testing.expect(state.handoffStats().hasProvides());
        try std.testing.expect(!state.handoffStats().hasAccepts());
        try std.testing.expect(!state.handoffStats().hasJoins());
        try std.testing.expect(state.handoffStats().hasProvideRecipients());
        try std.testing.expect(!state.handoffStats().hasPendingAcceptEmbargos());
        try std.testing.expect(!state.handoffStats().hasReadyAcceptProvisions());
        try std.testing.expect(!state.handoffStats().hasJoinKeyParts());
        {
            var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer response_builder.deinit();
            const response_root = try generated.Message.initRootTyped(&response_builder);
            try state.initTrackedProvideReturnMessage(response_root, 61, 86);

            var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
            const response = generated.Message.fromReader(try response_reader.getRoot());
            const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
            defer std.testing.allocator.free(descriptors);
            try std.testing.expectEqual(@as(usize, 1), descriptors.len);
            try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 86 }, descriptors[0]);
        }
        {
            const Context = struct {
                seen: usize = 0,
                capability_sum: u32 = 0,

                fn handle(context: *@This(), question_id: u32, recipient: cpz.rpc.AnyPointerUsage) !u32 {
                    context.seen += 1;
                    context.capability_sum += recipient.capability orelse 0;
                    return question_id + 40;
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

            var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer response_builder.deinit();
            const response_root = try generated.Message.initRootTyped(&response_builder);
            var context: Context = .{};
            var sink: Sink = .{};
            try state.initTrackedProvideReturnMessageFromHandlerToSink(response_root, 61, &context, Context.handle, &sink, Sink.handle);
            try std.testing.expectEqual(@as(usize, 1), context.seen);
            try std.testing.expectEqual(@as(u32, 2), context.capability_sum);
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
            try std.testing.expectEqual(@as(u32, 61), sink.last_answer);

            var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
            const response = generated.Message.fromReader(try response_reader.getRoot());
            const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
            defer std.testing.allocator.free(descriptors);
            try std.testing.expectEqual(@as(usize, 1), descriptors.len);
            try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 101 }, descriptors[0]);

            var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer queue_builder.deinit();
            const queue_response = try generated.Message.initRootTyped(&queue_builder);
            var queue_context: Context = .{};
            var queue = std.ArrayList(generated.Message.Builder).empty;
            defer queue.deinit(std.testing.allocator);
            try state.initTrackedProvideReturnMessageFromHandlerToQueue(
                std.testing.allocator,
                queue_response,
                61,
                &queue_context,
                Context.handle,
                &queue,
            );
            try std.testing.expectEqual(@as(usize, 1), queue_context.seen);
            try std.testing.expectEqual(@as(u32, 2), queue_context.capability_sum);
            try std.testing.expectEqual(@as(usize, 1), queue.items.len);
            try support.expectQueuedReturnAnswer(queue.items[0], 61);
            var queue_reader = cpz.MessageReader.init(try queue_builder.segmentsConst(), .{});
            try support.expectReturnCapabilityResult(generated.Message.fromReader(try queue_reader.getRoot()), 101);
        }
        try state.finishQuestion(61);
        try std.testing.expect(state.provideInfo(61) == null);
        try std.testing.expect(state.provideRecipient(61) == null);
        try std.testing.expectEqual(@as(usize, 0), state.provideRecipientCount());
        try std.testing.expectEqual(@as(usize, 0), state.handoffStats().tracked());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const join = try root.init_join();
        try join.set_questionId(62);
        const target = try join.init_target();
        const promised = try target.init_promisedAnswer();
        try promised.set_questionId(63);
        (try join.get_keyPartAsPointer()).setCapability(4);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.joinInfoFromWireJoin(try message.join());
        try std.testing.expectEqual(@as(u32, 62), info.question_id);
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 63 } }, info.target);
        try std.testing.expect(info.has_key_part);
        try std.testing.expectEqual(@as(usize, 5), info.key_part_max_capability_count);
        try std.testing.expectEqual(@as(?u32, 4), info.key_part_capability);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 5, .capability = 4 }, info.keyPartUsage().?);
        try info.validate();
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.QuestionNotOpen, state.applyWireMessage(std.testing.allocator, message));
        try state.openQuestion(63, .bootstrap);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(62));
        const tracked = state.joinInfo(62).?;
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 63 } }, tracked.target);
        try std.testing.expectEqual(@as(?u32, 4), tracked.key_part_capability);
        try std.testing.expect(tracked.hasKeyPartUsage());
        try std.testing.expect(tracked.keyPartMatchesCapability(4));
        try std.testing.expect(!tracked.keyPartMatchesCapability(3));
        try std.testing.expect(tracked.targetsPromisedQuestion(63));
        try std.testing.expectEqual(@as(?bool, true), state.joinHasKeyPartUsage(62));
        try std.testing.expectEqual(@as(?bool, true), state.joinKeyPartMatchesCapability(62, 4));
        try std.testing.expectEqual(@as(?bool, false), state.joinKeyPartMatchesCapability(62, 3));
        try std.testing.expectEqual(@as(?bool, true), state.joinTargetsPromisedQuestion(62, 63));
        try std.testing.expectEqual(@as(?bool, false), state.joinTargetsImport(62, 63));
        try std.testing.expectEqual(@as(?bool, null), state.joinHasKeyPartUsage(999));
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 5, .capability = 4 }, state.joinKeyPart(62).?);
        try std.testing.expectEqual(@as(usize, 1), state.joinKeyPartCount());
        try std.testing.expectEqual(cpz.rpc.StateHandoffStats{ .joins = 1, .join_key_parts = 1 }, state.handoffStats());
        {
            var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer response_builder.deinit();
            const response_root = try generated.Message.initRootTyped(&response_builder);
            try state.initTrackedJoinResultReturnMessage(response_root, 62, 84);

            var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
            const response = generated.Message.fromReader(try response_reader.getRoot());
            try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
            const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
            defer std.testing.allocator.free(descriptors);
            try std.testing.expectEqual(@as(usize, 1), descriptors.len);
            try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 84 }, descriptors[0]);
        }
        {
            const Context = struct {
                seen: usize = 0,
                capability_sum: u32 = 0,

                fn handle(context: *@This(), question_id: u32, key_part: cpz.rpc.AnyPointerUsage) !u32 {
                    context.seen += 1;
                    context.capability_sum += key_part.capability orelse 0;
                    return question_id + 50;
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

            var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer response_builder.deinit();
            const response_root = try generated.Message.initRootTyped(&response_builder);
            var context: Context = .{};
            var sink: Sink = .{};
            try state.initTrackedJoinResultReturnMessageFromHandlerToSink(response_root, 62, &context, Context.handle, &sink, Sink.handle);
            try std.testing.expectEqual(@as(usize, 1), context.seen);
            try std.testing.expectEqual(@as(u32, 4), context.capability_sum);
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
            try std.testing.expectEqual(@as(u32, 62), sink.last_answer);

            var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
            const response = generated.Message.fromReader(try response_reader.getRoot());
            try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
            const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
            defer std.testing.allocator.free(descriptors);
            try std.testing.expectEqual(@as(usize, 1), descriptors.len);
            try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 112 }, descriptors[0]);

            var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer queue_builder.deinit();
            const queue_response = try generated.Message.initRootTyped(&queue_builder);
            var queue_context: Context = .{};
            var queue = std.ArrayList(generated.Message.Builder).empty;
            defer queue.deinit(std.testing.allocator);
            try state.initTrackedJoinResultReturnMessageFromHandlerToQueue(
                std.testing.allocator,
                queue_response,
                62,
                &queue_context,
                Context.handle,
                &queue,
            );
            try std.testing.expectEqual(@as(usize, 1), queue_context.seen);
            try std.testing.expectEqual(@as(u32, 4), queue_context.capability_sum);
            try std.testing.expectEqual(@as(usize, 1), queue.items.len);
            try support.expectQueuedReturnAnswer(queue.items[0], 62);
            var queue_reader = cpz.MessageReader.init(try queue_builder.segmentsConst(), .{});
            const queued_response = generated.Message.fromReader(try queue_reader.getRoot());
            try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try queued_response.return_()));
            try support.expectReturnCapabilityResult(queued_response, 112);
        }
        try state.finishQuestion(62);
        try std.testing.expect(state.joinInfo(62) == null);
        try std.testing.expect(state.joinKeyPart(62) == null);
        try std.testing.expectEqual(@as(usize, 0), state.joinKeyPartCount());
    }
}

test "rpc tracked provide returns require recipients" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireProvideMessage(root, .{
        .question_id = 69,
        .target = .{ .imported_cap = 70 },
        .has_recipient = false,
        .recipient_max_capability_count = 0,
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(70);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expect(state.provideRecipient(69) == null);
    try std.testing.expectEqual(@as(usize, 0), state.provideRecipientCount());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    try std.testing.expectError(error.InvalidTransition, state.initTrackedProvideReturnMessage(response_root, 69, 87));
}

test "rpc provide info helpers write targets and recipients" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const provide = try generated.Provide.initRootTyped(&builder);
    try cpz.rpc.writeProvideInfoToWire(.{
        .question_id = 69,
        .target = .{ .imported_cap = 70 },
        .has_recipient = true,
        .recipient_max_capability_count = 3,
        .recipient_capability = 2,
    }, provide);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const provide_reader = generated.Provide.fromReader(try reader.getRoot());
    const info = try cpz.rpc.provideInfoFromWireProvide(provide_reader);
    try std.testing.expectEqual(@as(u32, 69), info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 70 }, info.target);
    try std.testing.expect(info.has_recipient);
    try std.testing.expectEqual(@as(usize, 3), info.recipient_max_capability_count);
    try std.testing.expectEqual(@as(?u32, 2), info.recipient_capability);
    try std.testing.expect(info.hasRecipientUsage());
    try std.testing.expect(info.recipientMatchesCapability(2));
    try std.testing.expect(!info.recipientMatchesCapability(1));
    try std.testing.expect(info.targetsImport(70));
    try std.testing.expect(!info.targetsImport(71));
}

test "rpc handoff info writers reject inconsistent capability flags" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const provide = try generated.Provide.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeProvideInfoToWire(.{
            .question_id = 1,
            .target = .{ .imported_cap = 2 },
            .has_recipient = false,
            .recipient_max_capability_count = 0,
            .recipient_capability = 0,
        }, provide));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeProvideInfoToWire(.{
            .question_id = 1,
            .target = .{ .imported_cap = 2 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = null,
        }, provide));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeProvideInfoToWire(.{
            .question_id = 1,
            .target = .{ .imported_cap = 2 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 1,
        }, provide));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const accept = try generated.Accept.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeAcceptInfoToWire(.{
            .question_id = 1,
            .has_provision = false,
            .provision_max_capability_count = 0,
            .provision_capability = 0,
            .embargo = null,
        }, accept));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeAcceptInfoToWire(.{
            .question_id = 1,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = null,
            .embargo = null,
        }, accept));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeAcceptInfoToWire(.{
            .question_id = 1,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 1,
            .embargo = null,
        }, accept));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const join = try generated.Join.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeJoinInfoToWire(.{
            .question_id = 1,
            .target = .{ .imported_cap = 2 },
            .has_key_part = false,
            .key_part_max_capability_count = 0,
            .key_part_capability = 0,
        }, join));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeJoinInfoToWire(.{
            .question_id = 1,
            .target = .{ .imported_cap = 2 },
            .has_key_part = true,
            .key_part_max_capability_count = 1,
            .key_part_capability = null,
        }, join));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeJoinInfoToWire(.{
            .question_id = 1,
            .target = .{ .imported_cap = 2 },
            .has_key_part = true,
            .key_part_max_capability_count = 1,
            .key_part_capability = 1,
        }, join));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const third_party_answer = try generated.ThirdPartyAnswer.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeThirdPartyAnswerInfoToWire(.{
            .answer_id = 1,
            .has_completion = false,
            .completion = .{ .max_capability_count = 1, .capability = 0 },
        }, third_party_answer));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeThirdPartyAnswerInfoToWire(.{
            .answer_id = 1,
            .has_completion = true,
            .completion = .{ .max_capability_count = 1, .capability = null },
        }, third_party_answer));
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeThirdPartyAnswerInfoToWire(.{
            .answer_id = 1,
            .has_completion = true,
            .completion = .{ .max_capability_count = 1, .capability = 1 },
        }, third_party_answer));
    }
}

test "rpc top-level handoff helpers initialize messages" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 90,
            .target = .{ .imported_cap = 91 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.provideInfoFromWireProvide(try message.provide());
        try std.testing.expectEqual(@as(u32, 90), info.question_id);
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 91 }, info.target);
        try std.testing.expectEqual(@as(?u32, 0), info.recipient_capability);
        try std.testing.expect(info.hasRecipientUsage());
        try std.testing.expect(info.recipientMatchesCapability(0));
        try std.testing.expect(info.targetsImport(91));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 92,
            .has_provision = true,
            .provision_max_capability_count = 2,
            .provision_capability = 1,
            .embargo = "accept-92",
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.acceptInfoFromWireAccept(try message.accept());
        try std.testing.expectEqual(@as(u32, 92), info.question_id);
        try std.testing.expect(info.has_provision);
        try std.testing.expectEqual(@as(usize, 2), info.provision_max_capability_count);
        try std.testing.expectEqual(@as(?u32, 1), info.provision_capability);
        try std.testing.expectEqualStrings("accept-92", info.embargo.?);
        try std.testing.expect(info.hasProvisionUsage());
        try std.testing.expect(info.provisionMatchesCapability(1));
        try std.testing.expect(!info.provisionMatchesCapability(0));
        try std.testing.expect(info.hasEmbargo());
        try std.testing.expect(info.matchesEmbargo("accept-92"));
        try std.testing.expect(!info.matchesEmbargo("missing"));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireJoinMessage(root, .{
            .question_id = 93,
            .target = .{ .imported_cap = 94 },
            .has_key_part = true,
            .key_part_max_capability_count = 2,
            .key_part_capability = 1,
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.joinInfoFromWireJoin(try message.join());
        try std.testing.expectEqual(@as(u32, 93), info.question_id);
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 94 }, info.target);
        try std.testing.expectEqual(@as(?u32, 1), info.key_part_capability);
        try std.testing.expect(info.hasKeyPartUsage());
        try std.testing.expect(info.keyPartMatchesCapability(1));
        try std.testing.expect(!info.keyPartMatchesCapability(0));
        try std.testing.expect(info.targetsImport(94));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireDisembargoMessage(root, .{
            .target = .{ .imported_cap = 95 },
            .context = .{ .sender_loopback = 96 },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try message.disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 95 }, info.target);
        try std.testing.expectEqual(cpz.rpc.DisembargoContext{ .sender_loopback = 96 }, info.context);
        try std.testing.expect(info.context.isSenderLoopback());
        try std.testing.expect(!info.context.isReceiverLoopback());
        try std.testing.expect(!info.context.isAccept());
        try std.testing.expectEqual(@as(?u32, 96), info.context.senderLoopbackId());
        try std.testing.expectEqual(@as(?u32, null), info.context.receiverLoopbackId());
        try std.testing.expect(info.context.acceptEmbargo() == null);
        try std.testing.expect(info.targetsImport(95));
        try std.testing.expect(!info.targetsImport(94));
        try std.testing.expect(!info.isAcceptEmbargo());
    }
}

test "rpc tracked join results require key parts" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireJoinMessage(root, .{
        .question_id = 70,
        .target = .{ .imported_cap = 71 },
        .has_key_part = false,
        .key_part_max_capability_count = 0,
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(71);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expect(state.joinKeyPart(70) == null);
    try std.testing.expectEqual(@as(usize, 0), state.joinKeyPartCount());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    try std.testing.expectError(error.InvalidTransition, state.initTrackedJoinResultReturnMessage(response_root, 70, 85));
}

test "rpc join info helpers write targets and key parts" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const join = try generated.Join.initRootTyped(&builder);
    try cpz.rpc.writeJoinInfoToWire(.{
        .question_id = 71,
        .target = .{ .imported_cap = 72 },
        .has_key_part = true,
        .key_part_max_capability_count = 6,
        .key_part_capability = 5,
    }, join);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const join_reader = generated.Join.fromReader(try reader.getRoot());
    const info = try cpz.rpc.joinInfoFromWireJoin(join_reader);
    try std.testing.expectEqual(@as(u32, 71), info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 72 }, info.target);
    try std.testing.expect(info.has_key_part);
    try std.testing.expectEqual(@as(usize, 6), info.key_part_max_capability_count);
    try std.testing.expectEqual(@as(?u32, 5), info.key_part_capability);
    try std.testing.expect(info.hasKeyPartUsage());
    try std.testing.expect(info.keyPartMatchesCapability(5));
    try std.testing.expect(info.targetsImport(72));
}

test "rpc top-level accept messages open questions" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const accept = try root.init_accept();
    try accept.set_questionId(64);
    (try accept.get_provisionAsPointer()).setCapability(2);
    try accept.set_embargo("embargo-64");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.acceptInfoFromWireAccept(try message.accept());
    try std.testing.expectEqual(@as(u32, 64), info.question_id);
    try std.testing.expect(info.has_provision);
    try std.testing.expectEqual(@as(usize, 3), info.provision_max_capability_count);
    try std.testing.expectEqual(@as(?u32, 2), info.provision_capability);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, info.provisionUsage().?);
    try info.validate();
    try std.testing.expectEqualStrings("embargo-64", info.embargo.?);
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(64));
    const tracked = state.acceptInfo(64).?;
    try std.testing.expect(tracked.has_provision);
    try std.testing.expectEqual(@as(?u32, 2), tracked.provision_capability);
    try std.testing.expectEqualStrings("embargo-64", tracked.embargo.?);
    try std.testing.expect(tracked.hasProvisionUsage());
    try std.testing.expect(tracked.provisionMatchesCapability(2));
    try std.testing.expect(!tracked.provisionMatchesCapability(1));
    try std.testing.expect(tracked.hasEmbargo());
    try std.testing.expect(tracked.matchesEmbargo("embargo-64"));
    try std.testing.expectEqual(@as(?bool, true), state.acceptHasProvisionUsage(64));
    try std.testing.expectEqual(@as(?bool, true), state.acceptProvisionMatchesCapability(64, 2));
    try std.testing.expectEqual(@as(?bool, false), state.acceptProvisionMatchesCapability(64, 1));
    try std.testing.expectEqual(@as(?bool, true), state.acceptHasEmbargo(64));
    try std.testing.expectEqual(@as(?bool, true), state.acceptMatchesEmbargo(64, "embargo-64"));
    try std.testing.expectEqual(@as(?bool, false), state.acceptMatchesEmbargo(64, "missing"));
    try std.testing.expectEqual(@as(?bool, null), state.acceptHasProvisionUsage(999));
    try std.testing.expectEqual(@as(?bool, false), state.acceptEmbargoReleased(64));
    try std.testing.expectEqual(@as(?bool, false), state.acceptReady(64));
    try std.testing.expectEqualStrings("embargo-64", state.acceptPendingEmbargo(64).?);
    try std.testing.expectEqual(@as(usize, 1), state.pendingAcceptEmbargoCount());
    try std.testing.expectEqual(@as(usize, 1), state.pendingAcceptEmbargoMatchCount("embargo-64"));
    try std.testing.expectEqual(@as(usize, 0), state.pendingAcceptEmbargoMatchCount("missing"));
    const blocked_stats = state.handoffStats();
    try std.testing.expectEqual(cpz.rpc.StateHandoffStats{ .accepts = 1, .pending_accept_embargos = 1 }, blocked_stats);
    try std.testing.expectEqual(@as(usize, 1), blocked_stats.blocked());
    try std.testing.expectEqual(@as(usize, 0), blocked_stats.ready());
    try std.testing.expect(blocked_stats.hasTracked());
    try std.testing.expect(!blocked_stats.hasReady());
    try std.testing.expect(blocked_stats.hasBlocked());
    try std.testing.expect(!blocked_stats.hasProvides());
    try std.testing.expect(blocked_stats.hasAccepts());
    try std.testing.expect(!blocked_stats.hasJoins());
    try std.testing.expect(!blocked_stats.hasProvideRecipients());
    try std.testing.expect(blocked_stats.hasPendingAcceptEmbargos());
    try std.testing.expect(!blocked_stats.hasReadyAcceptProvisions());
    try std.testing.expect(!blocked_stats.hasJoinKeyParts());
    {
        const pending_ids = try state.pendingAcceptEmbargoIdsAlloc(std.testing.allocator);
        defer std.testing.allocator.free(pending_ids);
        try std.testing.expectEqualSlices(u32, &.{64}, pending_ids);
    }
    {
        const matching_ids = try state.pendingAcceptEmbargoMatchingIdsAlloc(std.testing.allocator, "embargo-64");
        defer std.testing.allocator.free(matching_ids);
        try std.testing.expectEqualSlices(u32, &.{64}, matching_ids);
    }
    {
        var pending = try state.pendingAcceptEmbargosAlloc(std.testing.allocator);
        defer pending.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), pending.len());
        try std.testing.expect(pending.hasItems());
        try std.testing.expect(pending.containsQuestion(64));
        try std.testing.expect(!pending.containsQuestion(65));
        try std.testing.expectEqualStrings("embargo-64", pending.embargoForQuestion(64).?);
        try std.testing.expect(pending.embargoForQuestion(65) == null);
        try std.testing.expect(pending.containsQuestionEmbargo(64, "embargo-64"));
        try std.testing.expect(!pending.containsQuestionEmbargo(64, "missing"));
        try std.testing.expect(!pending.containsQuestionEmbargo(65, "embargo-64"));
        try std.testing.expectEqual(@as(usize, 1), pending.matchCount("embargo-64"));
        try std.testing.expect(pending.containsEmbargo("embargo-64"));
        try std.testing.expect(!pending.containsEmbargo("missing"));
        try pending.validateCapacity(1);
        try pending.validateMatchCapacity("embargo-64", 1);
        try pending.validateMatchCapacity("missing", 0);
        try std.testing.expectError(error.InvalidTransition, pending.validateCapacity(0));
        try std.testing.expectError(error.InvalidTransition, pending.validateMatchCapacity("embargo-64", 0));
        {
            var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer disembargo_builder.deinit();
            const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
            const messages = [_]generated.Message.Builder{disembargo_root};
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoMessages(messages[0..], .{ .imported_cap = 5 }));
            var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
            const disembargo_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try disembargo_reader.getRoot()).disembargo());
            try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, disembargo_info.target);
            try std.testing.expectEqualStrings("embargo-64", disembargo_info.context.accept);
        }
        {
            var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer disembargo_builder.deinit();
            const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
            const messages = [_]generated.Message.Builder{disembargo_root};
            var queue = std.ArrayList(generated.Message.Builder).empty;
            defer queue.deinit(std.testing.allocator);
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoMessagesToQueue(std.testing.allocator, messages[0..], .{ .imported_cap = 5 }, &queue));
            try std.testing.expectEqual(@as(usize, 1), queue.items.len);
            try support.expectQueuedDisembargoBuilder(queue.items[0], .{ .imported_cap = 5 }, "embargo-64");
        }
        {
            const Sink = struct {
                sent: usize = 0,
                fn handle(context: *@This(), queued_message: anytype) !void {
                    _ = try queued_message.get_disembargo();
                    context.sent += 1;
                }
            };
            var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer disembargo_builder.deinit();
            const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
            const messages = [_]generated.Message.Builder{disembargo_root};
            var sink: Sink = .{};
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoMessagesToSink(messages[0..], .{ .imported_cap = 5 }, &sink, Sink.handle));
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
        }
        {
            var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer disembargo_builder.deinit();
            const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
            const messages = [_]generated.Message.Builder{disembargo_root};
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoMessagesForEmbargo(messages[0..], .{ .imported_cap = 5 }, "embargo-64"));
            var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
            const disembargo_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try disembargo_reader.getRoot()).disembargo());
            try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, disembargo_info.target);
            try std.testing.expectEqualStrings("embargo-64", disembargo_info.context.accept);
            const empty_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
            defer std.testing.allocator.free(empty_messages);
            try std.testing.expectError(error.InvalidTransition, pending.initDisembargoMessagesForEmbargo(empty_messages, .{ .imported_cap = 5 }, "embargo-64"));
        }
        {
            var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer disembargo_builder.deinit();
            const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
            const messages = [_]generated.Message.Builder{disembargo_root};
            var queue = std.ArrayList(generated.Message.Builder).empty;
            defer queue.deinit(std.testing.allocator);
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoMessagesForEmbargoToQueue(std.testing.allocator, messages[0..], .{ .imported_cap = 5 }, "embargo-64", &queue));
            try std.testing.expectEqual(@as(usize, 1), queue.items.len);
            try support.expectQueuedDisembargoBuilder(queue.items[0], .{ .imported_cap = 5 }, "embargo-64");
        }
        {
            const Sink = struct {
                sent: usize = 0,
                fn handle(context: *@This(), queued_message: anytype) !void {
                    _ = try queued_message.get_disembargo();
                    context.sent += 1;
                }
            };
            var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
            defer disembargo_builder.deinit();
            const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
            const messages = [_]generated.Message.Builder{disembargo_root};
            var sink: Sink = .{};
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoMessagesForEmbargoToSink(messages[0..], .{ .imported_cap = 5 }, "embargo-64", &sink, Sink.handle));
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
            const empty_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
            defer std.testing.allocator.free(empty_messages);
            try std.testing.expectEqual(@as(usize, 0), try pending.initDisembargoMessagesForEmbargoToSink(empty_messages, .{ .imported_cap = 5 }, "missing", &sink, Sink.handle));
        }
        {
            var infos: [1]cpz.rpc.DisembargoInfo = undefined;
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoInfos(infos[0..], .{ .imported_cap = 5 }));
            try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, infos[0].target);
            try std.testing.expectEqualStrings("embargo-64", infos[0].context.accept);
            const empty_infos = try std.testing.allocator.alloc(cpz.rpc.DisembargoInfo, 0);
            defer std.testing.allocator.free(empty_infos);
            try std.testing.expectError(error.InvalidTransition, pending.initDisembargoInfos(empty_infos, .{ .imported_cap = 5 }));
        }
        {
            var info_queue = std.ArrayList(cpz.rpc.DisembargoInfo).empty;
            defer info_queue.deinit(std.testing.allocator);
            try std.testing.expectEqual(@as(usize, 1), try pending.appendDisembargoInfosToQueue(std.testing.allocator, .{ .imported_cap = 5 }, &info_queue));
            try std.testing.expectEqual(@as(usize, 1), info_queue.items.len);
            try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info_queue.items[0].target);
            try std.testing.expectEqualStrings("embargo-64", info_queue.items[0].context.accept);
        }
        {
            const InfoSink = struct {
                sent: usize = 0,
                last_target: cpz.rpc.CallTarget = .{ .imported_cap = 0 },

                fn handle(context: *@This(), disembargo_info: cpz.rpc.DisembargoInfo) !void {
                    context.sent += 1;
                    context.last_target = disembargo_info.target;
                    try std.testing.expectEqualStrings("embargo-64", disembargo_info.context.accept);
                }
            };
            var sink: InfoSink = .{};
            try std.testing.expectEqual(@as(usize, 1), try pending.appendDisembargoInfosToSink(.{ .imported_cap = 5 }, &sink, InfoSink.handle));
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
            try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, sink.last_target);
        }
        {
            var infos: [1]cpz.rpc.DisembargoInfo = undefined;
            try std.testing.expectEqual(@as(usize, 1), try pending.initDisembargoInfosForEmbargo(infos[0..], .{ .imported_cap = 5 }, "embargo-64"));
            try std.testing.expectEqualStrings("embargo-64", infos[0].context.accept);
            try std.testing.expectEqual(@as(usize, 0), try pending.initDisembargoInfosForEmbargo(infos[0..0], .{ .imported_cap = 5 }, "missing"));
            const empty_infos = try std.testing.allocator.alloc(cpz.rpc.DisembargoInfo, 0);
            defer std.testing.allocator.free(empty_infos);
            try std.testing.expectError(error.InvalidTransition, pending.initDisembargoInfosForEmbargo(empty_infos, .{ .imported_cap = 5 }, "embargo-64"));
        }
        {
            var info_queue = std.ArrayList(cpz.rpc.DisembargoInfo).empty;
            defer info_queue.deinit(std.testing.allocator);
            try std.testing.expectEqual(@as(usize, 1), try pending.appendDisembargoInfosForEmbargoToQueue(std.testing.allocator, .{ .imported_cap = 5 }, "embargo-64", &info_queue));
            try std.testing.expectEqual(@as(usize, 1), info_queue.items.len);
            try std.testing.expectEqualStrings("embargo-64", info_queue.items[0].context.accept);
            try std.testing.expectEqual(@as(usize, 0), try pending.appendDisembargoInfosForEmbargoToQueue(std.testing.allocator, .{ .imported_cap = 5 }, "missing", &info_queue));
            try std.testing.expectEqual(@as(usize, 1), info_queue.items.len);
        }
        {
            const InfoSink = struct {
                sent: usize = 0,

                fn handle(context: *@This(), disembargo_info: cpz.rpc.DisembargoInfo) !void {
                    context.sent += 1;
                    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, disembargo_info.target);
                    try std.testing.expectEqualStrings("embargo-64", disembargo_info.context.accept);
                }
            };
            var sink: InfoSink = .{};
            try std.testing.expectEqual(@as(usize, 1), try pending.appendDisembargoInfosForEmbargoToSink(.{ .imported_cap = 5 }, "embargo-64", &sink, InfoSink.handle));
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
            try std.testing.expectEqual(@as(usize, 0), try pending.appendDisembargoInfosForEmbargoToSink(.{ .imported_cap = 5 }, "missing", &sink, InfoSink.handle));
            try std.testing.expectEqual(@as(usize, 1), sink.sent);
        }
        try std.testing.expectEqual(@as(u32, 64), pending.items[0].question_id);
        try std.testing.expectEqualStrings("embargo-64", pending.items[0].embargo);
        try std.testing.expect(pending.items[0].matchesEmbargo("embargo-64"));
        try std.testing.expect(!pending.items[0].matchesEmbargo("missing"));
    }
    {
        var matching = try state.pendingAcceptEmbargosMatchingAlloc(std.testing.allocator, "embargo-64");
        defer matching.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), matching.len());
        try std.testing.expect(matching.containsQuestionEmbargo(64, "embargo-64"));
        try std.testing.expectEqualStrings("embargo-64", matching.items[0].embargo);
    }
    {
        var missing = try state.pendingAcceptEmbargosMatchingAlloc(std.testing.allocator, "missing");
        defer missing.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), missing.len());
        try std.testing.expect(!missing.hasItems());
    }
    try std.testing.expect(state.readyAcceptProvision(64) == null);
    try std.testing.expectEqual(@as(usize, 0), state.readyAcceptProvisionCount());
    {
        var premature_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer premature_builder.deinit();
        const premature_root = try generated.Message.initRootTyped(&premature_builder);
        try std.testing.expectError(error.InvalidTransition, state.initReadyAcceptReturnMessage(premature_root, 64, 90));
    }

    {
        var pending_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer pending_builder.deinit();
        const pending_root = try generated.Message.initRootTyped(&pending_builder);
        const messages = [_]generated.Message.Builder{pending_root};
        try std.testing.expectError(error.InvalidTransition, state.initPendingAcceptDisembargoMessages(messages[0..], .{ .imported_cap = 5 }));
    }
    try state.addImport(5);
    {
        var pending_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer pending_builder.deinit();
        const pending_root = try generated.Message.initRootTyped(&pending_builder);
        const messages = [_]generated.Message.Builder{pending_root};
        try std.testing.expectEqual(@as(usize, 1), try state.initPendingAcceptDisembargoMessages(messages[0..], .{ .imported_cap = 5 }));

        var pending_reader = cpz.MessageReader.init(try pending_builder.segmentsConst(), .{});
        const pending_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try pending_reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, pending_info.target);
        try std.testing.expectEqualStrings("embargo-64", pending_info.context.accept);
    }
    {
        const Sink = struct {
            sent: usize = 0,
            accept_contexts: usize = 0,

            fn handle(context: *@This(), queued_message: anytype) !void {
                const disembargo = try queued_message.get_disembargo();
                context.sent += 1;
                if ((try disembargo.which()) == .accept) context.accept_contexts += 1;
            }
        };

        var pending_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer pending_builder.deinit();
        const pending_root = try generated.Message.initRootTyped(&pending_builder);
        const messages = [_]generated.Message.Builder{pending_root};
        var sink: Sink = .{};
        try std.testing.expectEqual(
            @as(usize, 1),
            try state.initPendingAcceptDisembargoMessagesToSink(messages[0..], .{ .imported_cap = 5 }, &sink, Sink.handle),
        );
        try std.testing.expectEqual(@as(usize, 1), sink.sent);
        try std.testing.expectEqual(@as(usize, 1), sink.accept_contexts);

        var pending_reader = cpz.MessageReader.init(try pending_builder.segmentsConst(), .{});
        const pending_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try pending_reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, pending_info.target);
        try std.testing.expectEqualStrings("embargo-64", pending_info.context.accept);
    }
    {
        var pending_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer pending_builder.deinit();
        const pending_root = try generated.Message.initRootTyped(&pending_builder);
        const messages = [_]generated.Message.Builder{pending_root};
        var queue = std.ArrayList(generated.Message.Builder).empty;
        defer queue.deinit(std.testing.allocator);
        try std.testing.expectEqual(
            @as(usize, 1),
            try state.initPendingAcceptDisembargoMessagesToQueue(std.testing.allocator, messages[0..], .{ .imported_cap = 5 }, &queue),
        );
        try std.testing.expectEqual(@as(usize, 1), queue.items.len);

        var pending_reader = cpz.MessageReader.init(try pending_builder.segmentsConst(), .{});
        const pending_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try pending_reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, pending_info.target);
        try std.testing.expectEqualStrings("embargo-64", pending_info.context.accept);
    }
    {
        const Sink = struct {
            sent: usize = 0,

            fn handle(context: *@This(), queued_message: anytype) !void {
                _ = try queued_message.get_disembargo();
                context.sent += 1;
            }
        };

        var pending_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer pending_builder.deinit();
        const pending_root = try generated.Message.initRootTyped(&pending_builder);
        const messages = [_]generated.Message.Builder{pending_root};
        var sink: Sink = .{};
        try std.testing.expectEqual(
            @as(usize, 1),
            try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(messages[0..], .{ .imported_cap = 5 }, "embargo-64", &sink, Sink.handle),
        );
        try std.testing.expectEqual(@as(usize, 1), sink.sent);

        var pending_reader = cpz.MessageReader.init(try pending_builder.segmentsConst(), .{});
        const pending_info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try pending_reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, pending_info.target);
        try std.testing.expectEqualStrings("embargo-64", pending_info.context.accept);
        try std.testing.expectEqual(
            @as(usize, 0),
            try state.initPendingAcceptDisembargoMessagesForEmbargoToSink(messages[0..], .{ .imported_cap = 5 }, "missing", &sink, Sink.handle),
        );
    }
    {
        var pending_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer pending_builder.deinit();
        const pending_root = try generated.Message.initRootTyped(&pending_builder);
        const messages = [_]generated.Message.Builder{pending_root};
        var queue = std.ArrayList(generated.Message.Builder).empty;
        defer queue.deinit(std.testing.allocator);
        try std.testing.expectEqual(
            @as(usize, 1),
            try state.initPendingAcceptDisembargoMessagesForEmbargoToQueue(std.testing.allocator, messages[0..], .{ .imported_cap = 5 }, "embargo-64", &queue),
        );
        try std.testing.expectEqual(@as(usize, 1), queue.items.len);
        try std.testing.expectEqual(
            @as(usize, 0),
            try state.initPendingAcceptDisembargoMessagesForEmbargoToQueue(std.testing.allocator, messages[0..], .{ .imported_cap = 5 }, "missing", &queue),
        );
        try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    }

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    const disembargo = try disembargo_root.init_disembargo();
    const target = try disembargo.init_target();
    try target.set_importedCap(5);
    try disembargo.set_accept("embargo-64");

    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());
    var released = try state.applyWireDisembargoAlloc(std.testing.allocator, try disembargo_message.disembargo());
    defer released.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), released.released_accepts);
    try std.testing.expectEqualSlices(u32, &.{64}, released.released_accept_ids);
    try std.testing.expect(released.releasedAnyAccept());
    try std.testing.expectEqual(@as(usize, 0), (try state.applyWireDisembargo(try disembargo_message.disembargo())).released_accepts);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(64));
    try std.testing.expectEqual(@as(?bool, true), state.acceptReady(64));
    try std.testing.expect(state.acceptPendingEmbargo(64) == null);
    try std.testing.expectEqual(@as(usize, 0), state.pendingAcceptEmbargoCount());
    try std.testing.expectEqual(@as(usize, 0), state.pendingAcceptEmbargoMatchCount("embargo-64"));
    {
        var pending = try state.pendingAcceptEmbargosAlloc(std.testing.allocator);
        defer pending.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), pending.len());
        try std.testing.expect(!pending.hasItems());
        try std.testing.expect(!pending.containsQuestion(64));
        try std.testing.expectEqual(@as(usize, 0), pending.matchCount("embargo-64"));
    }
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, state.readyAcceptProvision(64).?);
    try std.testing.expectEqual(@as(usize, 1), state.readyAcceptProvisionCount());
    try std.testing.expectEqual(cpz.rpc.StateHandoffStats{ .accepts = 1, .ready_accept_provisions = 1 }, state.handoffStats());
    {
        const HandlerContext = struct {
            seen: usize = 0,
            question_sum: u32 = 0,
            capability_sum: u32 = 0,

            fn handle(context: *@This(), question_id: u32, provision: cpz.rpc.AnyPointerUsage) !u32 {
                context.seen += 1;
                context.question_sum += question_id;
                context.capability_sum += provision.capability orelse 0;
                return question_id + 30;
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

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        const responses = [_]generated.Message.Builder{response_root};
        var handler_context: HandlerContext = .{};
        var sink: Sink = .{};
        try std.testing.expectEqual(
            @as(usize, 1),
            try state.initReleasedAcceptReturnMessagesFromHandlerToSink(
                responses[0..],
                released.released_accept_ids,
                &handler_context,
                HandlerContext.handle,
                &sink,
                Sink.handle,
            ),
        );
        try std.testing.expectEqual(@as(usize, 1), handler_context.seen);
        try std.testing.expectEqual(@as(u32, 64), handler_context.question_sum);
        try std.testing.expectEqual(@as(u32, 2), handler_context.capability_sum);
        try std.testing.expectEqual(@as(usize, 1), sink.sent);
        try std.testing.expectEqual(@as(u32, 64), sink.last_answer);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 94 }, descriptors[0]);
    }
    {
        const HandlerContext = struct {
            seen: usize = 0,
            capability_sum: u32 = 0,

            fn handle(context: *@This(), question_id: u32, provision: cpz.rpc.AnyPointerUsage) !u32 {
                context.seen += 1;
                context.capability_sum += provision.capability orelse 0;
                return question_id + 32;
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

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var handler_context: HandlerContext = .{};
        var sink: Sink = .{};
        try state.initReadyAcceptReturnMessageFromHandlerToSink(response_root, 64, &handler_context, HandlerContext.handle, &sink, Sink.handle);
        try std.testing.expectEqual(@as(usize, 1), handler_context.seen);
        try std.testing.expectEqual(@as(u32, 2), handler_context.capability_sum);
        try std.testing.expectEqual(@as(usize, 1), sink.sent);
        try std.testing.expectEqual(@as(u32, 64), sink.last_answer);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 96 }, descriptors[0]);

        var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_builder.deinit();
        const queue_response = try generated.Message.initRootTyped(&queue_builder);
        var queue_context: HandlerContext = .{};
        var queue = std.ArrayList(generated.Message.Builder).empty;
        defer queue.deinit(std.testing.allocator);
        try state.initReadyAcceptReturnMessageFromHandlerToQueue(
            std.testing.allocator,
            queue_response,
            64,
            &queue_context,
            HandlerContext.handle,
            &queue,
        );
        try std.testing.expectEqual(@as(usize, 1), queue_context.seen);
        try std.testing.expectEqual(@as(u32, 2), queue_context.capability_sum);
        try std.testing.expectEqual(@as(usize, 1), queue.items.len);
        try support.expectQueuedReturnAnswer(queue.items[0], 64);
        var queue_reader = cpz.MessageReader.init(try queue_builder.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try queue_reader.getRoot()), 96);
    }
    try state.finishQuestion(64);
    try std.testing.expect(state.acceptInfo(64) == null);
    try std.testing.expectEqual(@as(usize, 0), state.readyAcceptProvisionCount());
}

test "rpc ready accept returns require provision capabilities" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireAcceptMessage(root, .{
        .question_id = 65,
        .has_provision = false,
        .provision_max_capability_count = 0,
        .embargo = null,
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.acceptReady(65));
    try std.testing.expect(state.readyAcceptProvision(65) == null);
    try std.testing.expectEqual(@as(usize, 0), state.readyAcceptProvisionCount());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    try std.testing.expectError(error.InvalidTransition, state.initReadyAcceptReturnMessage(response_root, 65, 91));
}

test "rpc top-level apply reports disembargo releases" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 68,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "apply-68",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    var accept_result = try state.applyWireMessageAlloc(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    defer accept_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(cpz.rpc.WireMessageApplyResult.state_applied, accept_result);
    try std.testing.expect(accept_result.isStateApplied());
    try std.testing.expect(!accept_result.isDisembargo());

    try state.addImport(5);
    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "apply-68" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    var disembargo_result = try state.applyWireMessageAlloc(std.testing.allocator, generated.Message.fromReader(try disembargo_reader.getRoot()));
    defer disembargo_result.deinit(std.testing.allocator);
    try std.testing.expect(disembargo_result.isDisembargo());
    try std.testing.expect(disembargo_result.releasedAnyAccept());
    const released = switch (disembargo_result) {
        .disembargo => |info| info,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(@as(usize, 1), released.released_accepts);
    try std.testing.expectEqual(@as(usize, 1), released.releasedAcceptCount());
    try std.testing.expect(released.containsReleasedAccept(68));
    try std.testing.expect(!released.containsReleasedAccept(69));
    try std.testing.expectEqualSlices(u32, &.{68}, released.released_accept_ids);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(68));
}

test "rpc batch apply aggregates detailed disembargo results" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 69,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "batch-69",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    const accept_message = generated.Message.fromReader(try accept_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "batch-69" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    const messages = [_]generated.Message{ accept_message, disembargo_message };
    {
        var simple_state = cpz.rpc.State.init(std.testing.allocator);
        defer simple_state.deinit();
        try simple_state.addImport(5);
        try std.testing.expectEqual(@as(usize, 2), try simple_state.applyWireMessages(std.testing.allocator, messages[0..]));
        try std.testing.expectEqual(@as(?bool, true), simple_state.acceptEmbargoReleased(69));
    }
    {
        const Context = struct {
            seen: usize = 0,
            disembargos: usize = 0,

            fn handle(context: *@This(), message: generated.Message) !void {
                context.seen += 1;
                if ((try cpz.rpc.wireMessageTag(message)) == .disembargo) context.disembargos += 1;
            }
        };
        var simple_state = cpz.rpc.State.init(std.testing.allocator);
        defer simple_state.deinit();
        try simple_state.addImport(5);
        var context: Context = .{};
        try std.testing.expectEqual(@as(usize, 2), try simple_state.applyWireMessagesWithHandler(std.testing.allocator, messages[0..], &context, Context.handle));
        try std.testing.expectEqual(@as(usize, 2), context.seen);
        try std.testing.expectEqual(@as(usize, 1), context.disembargos);
    }

    const stats = try state.applyWireMessagesAlloc(std.testing.allocator, messages[0..]);
    try std.testing.expectEqual(cpz.rpc.WireMessageApplyStats{
        .state_applied = 1,
        .disembargos = 1,
        .released_accepts = 1,
    }, stats);
    try std.testing.expectEqual(@as(usize, 2), stats.total());
    try std.testing.expect(stats.hasWork());
    try std.testing.expect(stats.appliedAnyState());
    try std.testing.expect(stats.appliedAnyDisembargo());
    try std.testing.expect(stats.releasedAnyAccept());
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(69));
}

test "rpc batch apply handler observes detailed disembargo results" {
    const Context = struct {
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
                else => {},
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
        .question_id = 70,
        .has_provision = true,
        .provision_max_capability_count = 1,
        .provision_capability = 0,
        .embargo = "handler-70",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    const accept_message = generated.Message.fromReader(try accept_reader.getRoot());

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "handler-70" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    const messages = [_]generated.Message{ accept_message, disembargo_message };
    var context: Context = .{};
    const stats = try state.applyWireMessagesAllocWithHandler(std.testing.allocator, messages[0..], &context, Context.handle);
    try std.testing.expectEqual(cpz.rpc.WireMessageApplyStats{
        .state_applied = 1,
        .disembargos = 1,
        .released_accepts = 1,
    }, stats);
    try std.testing.expectEqual(@as(usize, 2), context.calls);
    try std.testing.expectEqual(@as(usize, 1), context.released_accepts);
    try std.testing.expectEqual(@as(u32, 70), context.released_question_sum);
}

test "rpc disembargo helper initializes released accept returns from handlers" {
    const HandlerContext = struct {
        seen: usize = 0,
        question_sum: u32 = 0,
        capability_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, provision: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            context.capability_sum += provision.capability orelse 0;
            return question_id + 700;
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
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 66,
        .has_provision = true,
        .provision_max_capability_count = 2,
        .provision_capability = 1,
        .embargo = "combo-66",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "combo-66" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    const responses = [_]generated.Message.Builder{response_root};
    var short_context: HandlerContext = .{};
    var short_sink: Sink = .{};
    const no_response_slots = state.pendingAcceptEmbargoMatchCount("not-present");
    try std.testing.expectError(error.InvalidTransition, state.applyWireDisembargoAndInitAcceptReturnsFromHandlerToSink(
        std.testing.allocator,
        try disembargo_message.disembargo(),
        responses[0..no_response_slots],
        &short_context,
        HandlerContext.handle,
        &short_sink,
        Sink.handle,
    ));
    try std.testing.expectEqual(@as(usize, 0), short_context.seen);
    try std.testing.expectEqual(@as(usize, 0), short_sink.sent);
    try std.testing.expectEqual(@as(?bool, false), state.acceptEmbargoReleased(66));

    var handler_context: HandlerContext = .{};
    var sink: Sink = .{};
    const released = try state.applyWireDisembargoAndInitAcceptReturnsFromHandlerToSink(
        std.testing.allocator,
        try disembargo_message.disembargo(),
        responses[0..],
        &handler_context,
        HandlerContext.handle,
        &sink,
        Sink.handle,
    );
    defer std.testing.allocator.free(released.released_accept_ids);
    try std.testing.expectEqual(@as(usize, 1), released.released_accepts);
    try std.testing.expectEqualSlices(u32, &.{66}, released.released_accept_ids);
    try std.testing.expectEqual(@as(usize, 1), handler_context.seen);
    try std.testing.expectEqual(@as(u32, 66), handler_context.question_sum);
    try std.testing.expectEqual(@as(u32, 1), handler_context.capability_sum);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 66), sink.last_answer);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 766 }, descriptors[0]);

    var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    var queue_context: HandlerContext = .{};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), try state.initReleasedAcceptReturnMessagesFromHandlerToQueue(
        std.testing.allocator,
        queue_responses[0..],
        released.released_accept_ids,
        &queue_context,
        HandlerContext.handle,
        &queue,
    ));
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 66);
    try std.testing.expectEqual(@as(usize, 1), queue_context.seen);
    try std.testing.expectEqual(@as(u32, 66), queue_context.question_sum);
    var queue_reader = cpz.MessageReader.init(try queue_builder.segmentsConst(), .{});
    try support.expectReturnCapabilityResult(generated.Message.fromReader(try queue_reader.getRoot()), 766);

    {
        var queue_state = cpz.rpc.State.init(std.testing.allocator);
        defer queue_state.deinit();
        try queue_state.addImport(5);

        var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_accept_builder.deinit();
        const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
        try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
            .question_id = 660,
            .has_provision = true,
            .provision_max_capability_count = 2,
            .provision_capability = 1,
            .embargo = "handler-queue-660",
        });
        var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));

        var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_disembargo_builder.deinit();
        const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "handler-queue-660" },
        });
        var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
        const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());

        var queue_apply_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_apply_builder.deinit();
        const queue_apply_response = try generated.Message.initRootTyped(&queue_apply_builder);
        const queue_apply_responses = [_]generated.Message.Builder{queue_apply_response};
        var queue_apply_context: HandlerContext = .{};
        var apply_queue = std.ArrayList(generated.Message.Builder).empty;
        defer apply_queue.deinit(std.testing.allocator);
        const queue_released = try queue_state.applyWireDisembargoAndInitAcceptReturnsFromHandlerToQueue(
            std.testing.allocator,
            try queue_disembargo_message.disembargo(),
            queue_apply_responses[0..],
            &queue_apply_context,
            HandlerContext.handle,
            &apply_queue,
        );
        defer std.testing.allocator.free(queue_released.released_accept_ids);
        try std.testing.expectEqual(@as(usize, 1), queue_released.released_accepts);
        try std.testing.expectEqualSlices(u32, &.{660}, queue_released.released_accept_ids);
        try std.testing.expectEqual(@as(usize, 1), queue_apply_context.seen);
        try std.testing.expectEqual(@as(u32, 660), queue_apply_context.question_sum);
        try std.testing.expectEqual(@as(usize, 1), apply_queue.items.len);
        try support.expectQueuedReturnAnswer(apply_queue.items[0], 660);
        var queue_apply_reader = cpz.MessageReader.init(try queue_apply_builder.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try queue_apply_reader.getRoot()), 1360);
    }
}

test "rpc disembargo helper initializes released accept returns from explicit exports" {
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
    try state.addImport(5);

    var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer accept_builder.deinit();
    const accept_root = try generated.Message.initRootTyped(&accept_builder);
    try cpz.rpc.initWireAcceptMessage(accept_root, .{
        .question_id = 67,
        .has_provision = true,
        .provision_max_capability_count = 2,
        .provision_capability = 1,
        .embargo = "explicit-67",
    });
    var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

    var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer disembargo_builder.deinit();
    const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
    try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
        .target = .{ .imported_cap = 5 },
        .context = .{ .accept = "explicit-67" },
    });
    var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    const responses = [_]generated.Message.Builder{response_root};
    const empty_exports = [_]cpz.rpc.ExportId{};
    var short_sink: Sink = .{};
    try std.testing.expectError(error.InvalidTransition, state.applyWireDisembargoAndInitAcceptReturnsToSink(
        std.testing.allocator,
        try disembargo_message.disembargo(),
        responses[0..],
        empty_exports[0..],
        &short_sink,
        Sink.handle,
    ));
    try std.testing.expectEqual(@as(usize, 0), short_sink.sent);
    try std.testing.expectEqual(@as(?bool, false), state.acceptEmbargoReleased(67));

    const export_ids = [_]cpz.rpc.ExportId{777};
    var sink: Sink = .{};
    const released = try state.applyWireDisembargoAndInitAcceptReturnsToSink(
        std.testing.allocator,
        try disembargo_message.disembargo(),
        responses[0..],
        export_ids[0..],
        &sink,
        Sink.handle,
    );
    defer std.testing.allocator.free(released.released_accept_ids);
    try std.testing.expectEqual(@as(usize, 1), released.released_accepts);
    try std.testing.expectEqualSlices(u32, &.{67}, released.released_accept_ids);
    try std.testing.expectEqual(@as(usize, 1), sink.sent);
    try std.testing.expectEqual(@as(u32, 67), sink.last_answer);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 777 }, descriptors[0]);

    var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_builder);
    const queue_responses = [_]generated.Message.Builder{queue_response};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), try state.initReleasedAcceptReturnMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..],
        released.released_accept_ids,
        export_ids[0..],
        &queue,
    ));
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 67);
    var queue_reader = cpz.MessageReader.init(try queue_builder.segmentsConst(), .{});
    try support.expectReturnCapabilityResult(generated.Message.fromReader(try queue_reader.getRoot()), 777);
    const short_response_len = queue.items.len - queue.items.len;
    try std.testing.expectError(error.InvalidTransition, state.initReleasedAcceptReturnMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..short_response_len],
        released.released_accept_ids,
        export_ids[0..],
        &queue,
    ));

    {
        var queue_state = cpz.rpc.State.init(std.testing.allocator);
        defer queue_state.deinit();
        try queue_state.addImport(5);

        var queue_accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_accept_builder.deinit();
        const queue_accept_root = try generated.Message.initRootTyped(&queue_accept_builder);
        try cpz.rpc.initWireAcceptMessage(queue_accept_root, .{
            .question_id = 670,
            .has_provision = true,
            .provision_max_capability_count = 2,
            .provision_capability = 1,
            .embargo = "explicit-queue-670",
        });
        var queue_accept_reader = cpz.MessageReader.init(try queue_accept_builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try queue_accept_reader.getRoot()));

        var queue_disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_disembargo_builder.deinit();
        const queue_disembargo_root = try generated.Message.initRootTyped(&queue_disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(queue_disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "explicit-queue-670" },
        });
        var queue_disembargo_reader = cpz.MessageReader.init(try queue_disembargo_builder.segmentsConst(), .{});
        const queue_disembargo_message = generated.Message.fromReader(try queue_disembargo_reader.getRoot());

        var queue_apply_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer queue_apply_builder.deinit();
        const queue_apply_response = try generated.Message.initRootTyped(&queue_apply_builder);
        const queue_apply_responses = [_]generated.Message.Builder{queue_apply_response};
        const queue_export_ids = [_]cpz.rpc.ExportId{778};
        var apply_queue = std.ArrayList(generated.Message.Builder).empty;
        defer apply_queue.deinit(std.testing.allocator);
        const queue_released = try queue_state.applyWireDisembargoAndInitAcceptReturnsToQueue(
            std.testing.allocator,
            try queue_disembargo_message.disembargo(),
            queue_apply_responses[0..],
            queue_export_ids[0..],
            &apply_queue,
        );
        defer std.testing.allocator.free(queue_released.released_accept_ids);
        try std.testing.expectEqual(@as(usize, 1), queue_released.released_accepts);
        try std.testing.expectEqualSlices(u32, &.{670}, queue_released.released_accept_ids);
        try std.testing.expectEqual(@as(usize, 1), apply_queue.items.len);
        try support.expectQueuedReturnAnswer(apply_queue.items[0], 670);
        var queue_apply_reader = cpz.MessageReader.init(try queue_apply_builder.segmentsConst(), .{});
        try support.expectReturnCapabilityResult(generated.Message.fromReader(try queue_apply_reader.getRoot()), 778);
    }
}

test "rpc disembargo helper initializes released accept returns without sinks" {
    const HandlerContext = struct {
        seen: usize = 0,
        capability_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, provision: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.capability_sum += provision.capability orelse 0;
            return question_id + 800;
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);

        var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer accept_builder.deinit();
        const accept_root = try generated.Message.initRootTyped(&accept_builder);
        try cpz.rpc.initWireAcceptMessage(accept_root, .{
            .question_id = 68,
            .has_provision = true,
            .provision_max_capability_count = 2,
            .provision_capability = 1,
            .embargo = "handler-68",
        });
        var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

        var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer disembargo_builder.deinit();
        const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "handler-68" },
        });
        var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        const responses = [_]generated.Message.Builder{response_root};
        var context: HandlerContext = .{};
        const released = try state.applyWireDisembargoAndInitAcceptReturnsFromHandler(
            std.testing.allocator,
            try disembargo_message.disembargo(),
            responses[0..],
            &context,
            HandlerContext.handle,
        );
        defer std.testing.allocator.free(released.released_accept_ids);
        try std.testing.expectEqualSlices(u32, &.{68}, released.released_accept_ids);
        try std.testing.expectEqual(@as(usize, 1), context.seen);
        try std.testing.expectEqual(@as(u32, 1), context.capability_sum);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 868 }, descriptors[0]);
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);

        var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer accept_builder.deinit();
        const accept_root = try generated.Message.initRootTyped(&accept_builder);
        try cpz.rpc.initWireAcceptMessage(accept_root, .{
            .question_id = 69,
            .has_provision = true,
            .provision_max_capability_count = 2,
            .provision_capability = 1,
            .embargo = "explicit-69",
        });
        var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

        var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer disembargo_builder.deinit();
        const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
        try cpz.rpc.initWireDisembargoMessage(disembargo_root, .{
            .target = .{ .imported_cap = 5 },
            .context = .{ .accept = "explicit-69" },
        });
        var disembargo_reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const disembargo_message = generated.Message.fromReader(try disembargo_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        const responses = [_]generated.Message.Builder{response_root};
        const export_ids = [_]cpz.rpc.ExportId{869};
        const released = try state.applyWireDisembargoAndInitAcceptReturns(
            std.testing.allocator,
            try disembargo_message.disembargo(),
            responses[0..],
            export_ids[0..],
        );
        defer std.testing.allocator.free(released.released_accept_ids);
        try std.testing.expectEqualSlices(u32, &.{69}, released.released_accept_ids);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 869 }, descriptors[0]);
    }
}

test "rpc tracked handoff batches initialize ready return messages" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(300);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 90,
            .target = .{ .imported_cap = 300 },
            .has_recipient = true,
            .recipient_max_capability_count = 2,
            .recipient_capability = 1,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 91,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = null,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireJoinMessage(root, .{
            .question_id = 92,
            .target = .{ .imported_cap = 300 },
            .has_key_part = true,
            .key_part_max_capability_count = 3,
            .key_part_capability = 2,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    try std.testing.expectEqual(cpz.rpc.StateHandoffStats{
        .provides = 1,
        .provide_recipients = 1,
        .accepts = 1,
        .ready_accept_provisions = 1,
        .joins = 1,
        .join_key_parts = 1,
    }, state.handoffStats());
    const ready_stats = state.handoffStats();
    try std.testing.expect(ready_stats.hasProvides());
    try std.testing.expect(ready_stats.hasAccepts());
    try std.testing.expect(ready_stats.hasJoins());
    try std.testing.expect(ready_stats.hasProvideRecipients());
    try std.testing.expect(!ready_stats.hasPendingAcceptEmbargos());
    try std.testing.expect(ready_stats.hasReadyAcceptProvisions());
    try std.testing.expect(ready_stats.hasJoinKeyParts());
    var ready_ids = try state.readyHandoffIdsAlloc(std.testing.allocator);
    defer ready_ids.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), ready_ids.total());
    try std.testing.expect(ready_ids.hasReturns());
    try std.testing.expect(ready_ids.hasProvides());
    try std.testing.expect(ready_ids.hasAccepts());
    try std.testing.expect(ready_ids.hasJoins());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, ready_ids.provideRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, ready_ids.acceptRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, ready_ids.joinRange());
    try std.testing.expectEqual(@as(?usize, 0), ready_ids.provideLocalIndex(0));
    try std.testing.expectEqual(@as(?usize, null), ready_ids.provideLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, 0), ready_ids.acceptLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, null), ready_ids.acceptLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 0), ready_ids.joinLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), ready_ids.joinLocalIndex(3));
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, ready_ids.unifiedOutputPosition(0).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, ready_ids.unifiedOutputPosition(1).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, ready_ids.unifiedOutputPosition(2).?);
    try std.testing.expect(ready_ids.unifiedOutputPosition(3) == null);
    try std.testing.expectEqual(@as(?u32, 90), ready_ids.questionIdAt(0));
    try std.testing.expectEqual(@as(?u32, 91), ready_ids.questionIdAt(1));
    try std.testing.expectEqual(@as(?u32, 92), ready_ids.questionIdAt(2));
    try std.testing.expectEqual(@as(?u32, null), ready_ids.questionIdAt(3));
    try std.testing.expectEqual(@as(?u32, 90), ready_ids.questionIdAtPosition(.{ .role = .provide, .local_index = 0 }));
    try std.testing.expectEqual(@as(?u32, 91), ready_ids.questionIdAtPosition(.{ .role = .accept, .local_index = 0 }));
    try std.testing.expectEqual(@as(?u32, 92), ready_ids.questionIdAtPosition(.{ .role = .join, .local_index = 0 }));
    try std.testing.expectEqual(@as(?u32, null), ready_ids.questionIdAtPosition(.{ .role = .provide, .local_index = 1 }));
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, ready_ids.stats());
    try std.testing.expect(ready_ids.stats().matchesReadyIds(ready_ids));
    try ready_ids.stats().validateAgainstReadyIds(ready_ids);
    try std.testing.expect(!(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }).matchesReadyIds(ready_ids));
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.StateHandoffReturnStats{ .provides = 1 }).validateAgainstReadyIds(ready_ids));
    try ready_ids.validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, ready_ids.validateCapacity(2));
    try std.testing.expectEqualSlices(u32, &.{90}, ready_ids.provides);
    try std.testing.expectEqualSlices(u32, &.{91}, ready_ids.accepts);
    try std.testing.expectEqualSlices(u32, &.{92}, ready_ids.joins);

    const planned_provides = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 90, .export_id = 390 }};
    const planned_accepts = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 91, .export_id = 391 }};
    const planned_joins = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 92, .export_id = 392 }};
    const planned = try state.readyHandoffReturnsAlloc(std.testing.allocator, .{
        .provides = planned_provides[0..],
        .accepts = planned_accepts[0..],
        .joins = planned_joins[0..],
    });
    defer std.testing.allocator.free(planned);
    try std.testing.expectEqual(@as(usize, 3), planned.len);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .provide = planned_provides[0] }, planned[0]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .accept = planned_accepts[0] }, planned[1]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .join = planned_joins[0] }, planned[2]);

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
        .{ .provide = .{ .question_id = 90, .export_id = 390 } },
        .{ .accept = .{ .question_id = 91, .export_id = 391 } },
        .{ .join = .{ .question_id = 92, .export_id = 392 } },
    };
    try std.testing.expect(completions[0].isProvide());
    try std.testing.expect(completions[1].isAccept());
    try std.testing.expect(completions[2].isJoin());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputRole.provide, completions[0].outputRole());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputRole.accept, completions[1].outputRole());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputRole.join, completions[2].outputRole());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnCapability{ .question_id = 90, .export_id = 390 }, completions[0].capability());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnCapability{ .question_id = 91, .export_id = 391 }, completions[1].capability());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnCapability{ .question_id = 92, .export_id = 392 }, completions[2].capability());
    var next_position_stats: cpz.rpc.StateHandoffReturnStats = .{};
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, next_position_stats.nextPosition(completions[0]));
    next_position_stats.record(completions[0]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 1 }, next_position_stats.nextPosition(completions[0]));
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, next_position_stats.nextPosition(completions[1]));
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, next_position_stats.nextPosition(completions[2]));
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 1 }, next_position_stats.nextRolePosition(.provide));
    next_position_stats.recordRole(.accept);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 1 }, next_position_stats.nextRolePosition(.accept));
    try std.testing.expectEqual(@as(u32, 90), completions[0].questionId());
    try std.testing.expectEqual(@as(u32, 392), completions[2].exportId());
    try state.validateTrackedHandoffReturn(completions[0]);
    try state.validateTrackedHandoffReturns(completions[0..]);
    const stats = try state.initTrackedHandoffReturnMessages(responses[0..], completions[0..]);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 3), stats.total());

    {
        var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(@as(u32, 90), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 390);
    }
    {
        var response_reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(@as(u32, 91), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 391);
    }
    {
        var response_reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        try std.testing.expectEqual(@as(u32, 92), return_.answerId());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(return_));
        try support.expectReturnCapabilityResult(response, 392);
    }

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
        .{ .provide = .{ .question_id = 90, .export_id = 390 } },
        .{ .join = .{ .question_id = 92, .export_id = 392 } },
        .{ .provide = .{ .question_id = 90, .export_id = 390 } },
        .{ .accept = .{ .question_id = 91, .export_id = 391 } },
    };
    const TaggedTrackedSink = struct {
        sent: usize = 0,
        positions: [4]cpz.rpc.HandoffReturnOutputPosition = undefined,
        answer_ids: [4]u32 = undefined,

        fn handle(context: *@This(), position: cpz.rpc.HandoffReturnOutputPosition, message: anytype) !void {
            context.positions[context.sent] = position;
            context.answer_ids[context.sent] = try (try message.get_return_()).get_answerId();
            context.sent += 1;
        }
    };
    var tagged_tracked_sink: TaggedTrackedSink = .{};
    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessagesToTaggedSink(
        tagged_responses[0..3],
        mixed_completions[0..],
        &tagged_tracked_sink,
        TaggedTrackedSink.handle,
    ));
    const tagged_stats = try state.initTrackedHandoffReturnMessagesToTaggedSink(
        tagged_responses[0..],
        mixed_completions[0..],
        &tagged_tracked_sink,
        TaggedTrackedSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, tagged_stats);
    try std.testing.expectEqual(@as(usize, 4), tagged_tracked_sink.sent);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, tagged_tracked_sink.positions[0]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, tagged_tracked_sink.positions[1]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 1 }, tagged_tracked_sink.positions[2]);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, tagged_tracked_sink.positions[3]);
    try std.testing.expectEqual(@as(u32, 90), tagged_tracked_sink.answer_ids[0]);
    try std.testing.expectEqual(@as(u32, 92), tagged_tracked_sink.answer_ids[1]);
    try std.testing.expectEqual(@as(u32, 90), tagged_tracked_sink.answer_ids[2]);
    try std.testing.expectEqual(@as(u32, 91), tagged_tracked_sink.answer_ids[3]);

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
    const TaggedTrackedQueueItem = struct {
        position: cpz.rpc.HandoffReturnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_tracked_queue = std.ArrayList(TaggedTrackedQueueItem).empty;
    defer tagged_tracked_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessagesToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..3],
        mixed_completions[0..],
        &tagged_tracked_queue,
    ));
    const tagged_queue_stats = try state.initTrackedHandoffReturnMessagesToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..],
        mixed_completions[0..],
        &tagged_tracked_queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, tagged_queue_stats);
    try std.testing.expectEqual(@as(usize, 4), tagged_tracked_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, tagged_tracked_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_tracked_queue.items[0].message, 90);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, tagged_tracked_queue.items[1].position);
    try support.expectQueuedReturnAnswer(tagged_tracked_queue.items[1].message, 92);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 1 }, tagged_tracked_queue.items[2].position);
    try support.expectQueuedReturnAnswer(tagged_tracked_queue.items[2].message, 90);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, tagged_tracked_queue.items[3].position);
    try support.expectQueuedReturnAnswer(tagged_tracked_queue.items[3].message, 91);

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
    const RoleTrackedSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    var provide_role_sink: RoleTrackedSink = .{};
    var accept_role_sink: RoleTrackedSink = .{};
    var join_role_sink: RoleTrackedSink = .{};
    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessagesToSinks(
        role_sink_responses[0..3],
        mixed_completions[0..],
        &provide_role_sink,
        RoleTrackedSink.handle,
        &accept_role_sink,
        RoleTrackedSink.handle,
        &join_role_sink,
        RoleTrackedSink.handle,
    ));
    const role_sink_stats = try state.initTrackedHandoffReturnMessagesToSinks(
        role_sink_responses[0..],
        mixed_completions[0..],
        &provide_role_sink,
        RoleTrackedSink.handle,
        &accept_role_sink,
        RoleTrackedSink.handle,
        &join_role_sink,
        RoleTrackedSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, role_sink_stats);
    try std.testing.expectEqual(@as(usize, 2), provide_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 90 + 90), provide_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 91), accept_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), join_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 92), join_role_sink.answer_sum);

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
    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessagesToQueues(
        std.testing.allocator,
        role_queue_responses[0..3],
        mixed_completions[0..],
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    ));
    const role_queue_stats = try state.initTrackedHandoffReturnMessagesToQueues(
        std.testing.allocator,
        role_queue_responses[0..],
        mixed_completions[0..],
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 2, .accepts = 1, .joins = 1 }, role_queue_stats);
    try std.testing.expectEqual(@as(usize, 2), provide_role_queue.items.len);
    try support.expectQueuedReturnAnswer(provide_role_queue.items[0], 90);
    try support.expectQueuedReturnAnswer(provide_role_queue.items[1], 90);
    try std.testing.expectEqual(@as(usize, 1), accept_role_queue.items.len);
    try support.expectQueuedReturnAnswer(accept_role_queue.items[0], 91);
    try std.testing.expectEqual(@as(usize, 1), join_role_queue.items.len);
    try support.expectQueuedReturnAnswer(join_role_queue.items[0], 92);

    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessages(responses[0..2], completions[0..]));
    const invalid_completions = [_]cpz.rpc.HandoffReturn{.{ .join = .{ .question_id = 999, .export_id = 999 } }};
    try std.testing.expectError(error.InvalidTransition, state.validateTrackedHandoffReturn(invalid_completions[0]));
    try std.testing.expectError(error.InvalidTransition, state.validateTrackedHandoffReturns(invalid_completions[0..]));
    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessages(responses[0..], invalid_completions[0..]));
}

test "rpc tracked handoff plans initialize ready return messages" {
    const Sink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(301);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 100,
            .target = .{ .imported_cap = 301 },
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
            .question_id = 101,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = null,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireJoinMessage(root, .{
            .question_id = 102,
            .target = .{ .imported_cap = 301 },
            .has_key_part = true,
            .key_part_max_capability_count = 1,
            .key_part_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    const planned_provides = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 100, .export_id = 500 }};
    const planned_accepts = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 101, .export_id = 501 }};
    const planned_joins = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 102, .export_id = 502 }};
    const plan = cpz.rpc.HandoffReturnPlan{
        .provides = planned_provides[0..],
        .accepts = planned_accepts[0..],
        .joins = planned_joins[0..],
    };
    try std.testing.expect(plan.hasReturns());
    try std.testing.expect(plan.hasProvides());
    try std.testing.expect(plan.hasAccepts());
    try std.testing.expect(plan.hasJoins());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, plan.provideRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, plan.acceptRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, plan.joinRange());
    try std.testing.expectEqual(@as(?usize, 0), plan.provideLocalIndex(0));
    try std.testing.expectEqual(@as(?usize, null), plan.provideLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, 0), plan.acceptLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, null), plan.acceptLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 0), plan.joinLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), plan.joinLocalIndex(3));
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, plan.unifiedOutputPosition(0).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, plan.unifiedOutputPosition(1).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, plan.unifiedOutputPosition(2).?);
    try std.testing.expect(plan.unifiedOutputPosition(3) == null);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .provide = planned_provides[0] }, plan.completionAt(0).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .accept = planned_accepts[0] }, plan.completionAt(1).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .join = planned_joins[0] }, plan.completionAt(2).?);
    try std.testing.expect(plan.completionAt(3) == null);
    try std.testing.expectEqual(planned_provides[0], plan.capabilityAt(0).?);
    try std.testing.expectEqual(planned_accepts[0], plan.capabilityAt(1).?);
    try std.testing.expectEqual(planned_joins[0], plan.capabilityAt(2).?);
    try std.testing.expect(plan.capabilityAt(3) == null);
    try std.testing.expectEqual(@as(?u32, 100), plan.questionIdAt(0));
    try std.testing.expectEqual(@as(?u32, 101), plan.questionIdAt(1));
    try std.testing.expectEqual(@as(?u32, 102), plan.questionIdAt(2));
    try std.testing.expectEqual(@as(?u32, null), plan.questionIdAt(3));
    try std.testing.expectEqual(@as(?u32, 500), plan.exportIdAt(0));
    try std.testing.expectEqual(@as(?u32, 501), plan.exportIdAt(1));
    try std.testing.expectEqual(@as(?u32, 502), plan.exportIdAt(2));
    try std.testing.expectEqual(@as(?u32, null), plan.exportIdAt(3));
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .provide = planned_provides[0] }, plan.completionAtPosition(.{ .role = .provide, .local_index = 0 }).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .accept = planned_accepts[0] }, plan.completionAtPosition(.{ .role = .accept, .local_index = 0 }).?);
    try std.testing.expectEqual(cpz.rpc.HandoffReturn{ .join = planned_joins[0] }, plan.completionAtPosition(.{ .role = .join, .local_index = 0 }).?);
    try std.testing.expect(plan.completionAtPosition(.{ .role = .provide, .local_index = 1 }) == null);
    try std.testing.expectEqual(planned_provides[0], plan.capabilityAtPosition(.{ .role = .provide, .local_index = 0 }).?);
    try std.testing.expectEqual(planned_accepts[0], plan.capabilityAtPosition(.{ .role = .accept, .local_index = 0 }).?);
    try std.testing.expectEqual(planned_joins[0], plan.capabilityAtPosition(.{ .role = .join, .local_index = 0 }).?);
    try std.testing.expect(plan.capabilityAtPosition(.{ .role = .provide, .local_index = 1 }) == null);
    try std.testing.expectEqual(@as(?u32, 100), plan.questionIdAtPosition(.{ .role = .provide, .local_index = 0 }));
    try std.testing.expectEqual(@as(?u32, 501), plan.exportIdAtPosition(.{ .role = .accept, .local_index = 0 }));
    try std.testing.expectEqual(@as(?u32, null), plan.questionIdAtPosition(.{ .role = .join, .local_index = 1 }));
    try plan.joinRange().validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, plan.joinRange().validateCapacity(2));
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, plan.stats());
    try std.testing.expect(plan.stats().matchesPlan(plan));
    try plan.stats().validateAgainstPlan(plan);
    try std.testing.expect(plan.stats().matchesStats(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }));
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.StateHandoffReturnStats{ .provides = 1 }).validateAgainstPlan(plan));
    try plan.validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, plan.validateCapacity(2));
    try state.validateReadyHandoffReturnPlan(plan);

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
    var sink: Sink = .{};
    const stats = try state.initReadyHandoffReturnPlanMessagesToSink(responses[0..], plan, &sink, Sink.handle);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 3), sink.sent);
    try std.testing.expectEqual(@as(u32, 100 + 101 + 102), sink.answer_sum);

    {
        var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        try std.testing.expectEqual(@as(u32, 100), (try generated.Message.fromReader(try response_reader.getRoot()).return_()).answerId());
    }
    {
        var response_reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
        try support.expectReturnCapabilityResult(response, 502);
    }

    var role_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_builder0.deinit();
    const role_response0 = try generated.Message.initRootTyped(&role_builder0);
    var role_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_builder1.deinit();
    const role_response1 = try generated.Message.initRootTyped(&role_builder1);
    var role_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_builder2.deinit();
    const role_response2 = try generated.Message.initRootTyped(&role_builder2);
    const role_responses = [_]generated.Message.Builder{ role_response0, role_response1, role_response2 };
    var provide_role_sink: Sink = .{};
    var accept_role_sink: Sink = .{};
    var join_role_sink: Sink = .{};
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessagesToSinks(
        role_responses[0..2],
        plan,
        &provide_role_sink,
        Sink.handle,
        &accept_role_sink,
        Sink.handle,
        &join_role_sink,
        Sink.handle,
    ));
    try std.testing.expectEqual(stats, try state.initReadyHandoffReturnPlanMessagesToSinks(
        role_responses[0..],
        plan,
        &provide_role_sink,
        Sink.handle,
        &accept_role_sink,
        Sink.handle,
        &join_role_sink,
        Sink.handle,
    ));
    try std.testing.expectEqual(@as(usize, 1), provide_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 100), provide_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 101), accept_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), join_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 102), join_role_sink.answer_sum);
    {
        var reader = cpz.MessageReader.init(try role_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
        try support.expectReturnCapabilityResult(response, 502);
    }

    const TaggedPlanSink = struct {
        sent: usize = 0,
        provide_answer_sum: u32 = 0,
        accept_answer_sum: u32 = 0,
        join_answer_sum: u32 = 0,

        fn handle(context: *@This(), position: cpz.rpc.HandoffReturnOutputPosition, message: anytype) !void {
            const answer_id = try (try message.get_return_()).get_answerId();
            switch (position.role) {
                .provide => context.provide_answer_sum += answer_id,
                .accept => context.accept_answer_sum += answer_id,
                .join => context.join_answer_sum += answer_id,
            }
            context.sent += 1;
        }
    };
    var tagged_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder0.deinit();
    const tagged_response0 = try generated.Message.initRootTyped(&tagged_builder0);
    var tagged_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder1.deinit();
    const tagged_response1 = try generated.Message.initRootTyped(&tagged_builder1);
    var tagged_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_builder2.deinit();
    const tagged_response2 = try generated.Message.initRootTyped(&tagged_builder2);
    const tagged_responses = [_]generated.Message.Builder{ tagged_response0, tagged_response1, tagged_response2 };
    var tagged_plan_sink: TaggedPlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessagesToTaggedSink(
        tagged_responses[0..2],
        plan,
        &tagged_plan_sink,
        TaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(stats, try state.initReadyHandoffReturnPlanMessagesToTaggedSink(
        tagged_responses[0..],
        plan,
        &tagged_plan_sink,
        TaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(@as(usize, 3), tagged_plan_sink.sent);
    try std.testing.expectEqual(@as(u32, 100), tagged_plan_sink.provide_answer_sum);
    try std.testing.expectEqual(@as(u32, 101), tagged_plan_sink.accept_answer_sum);
    try std.testing.expectEqual(@as(u32, 102), tagged_plan_sink.join_answer_sum);

    const TaggedPlanQueueItem = struct {
        position: cpz.rpc.HandoffReturnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder0.deinit();
    const tagged_queue_response0 = try generated.Message.initRootTyped(&tagged_queue_builder0);
    var tagged_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder1.deinit();
    const tagged_queue_response1 = try generated.Message.initRootTyped(&tagged_queue_builder1);
    var tagged_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder2.deinit();
    const tagged_queue_response2 = try generated.Message.initRootTyped(&tagged_queue_builder2);
    const tagged_queue_responses = [_]generated.Message.Builder{ tagged_queue_response0, tagged_queue_response1, tagged_queue_response2 };
    var tagged_plan_queue = std.ArrayList(TaggedPlanQueueItem).empty;
    defer tagged_plan_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessagesToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..2],
        plan,
        &tagged_plan_queue,
    ));
    try std.testing.expectEqual(stats, try state.initReadyHandoffReturnPlanMessagesToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..],
        plan,
        &tagged_plan_queue,
    ));
    try std.testing.expectEqual(@as(usize, 3), tagged_plan_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, tagged_plan_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_plan_queue.items[0].message, 100);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, tagged_plan_queue.items[1].position);
    try support.expectQueuedReturnAnswer(tagged_plan_queue.items[1].message, 101);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, tagged_plan_queue.items[2].position);
    try support.expectQueuedReturnAnswer(tagged_plan_queue.items[2].message, 102);

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
    const queue_stats = try state.initReadyHandoffReturnPlanMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..],
        plan,
        &queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, queue_stats);
    try std.testing.expectEqual(@as(usize, 3), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 100);
    try support.expectQueuedReturnAnswer(queue.items[1], 101);
    try support.expectQueuedReturnAnswer(queue.items[2], 102);
    {
        var reader = cpz.MessageReader.init(try queue_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
        try support.expectReturnCapabilityResult(response, 502);
    }

    var role_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder0.deinit();
    const role_queue_response0 = try generated.Message.initRootTyped(&role_queue_builder0);
    var role_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder1.deinit();
    const role_queue_response1 = try generated.Message.initRootTyped(&role_queue_builder1);
    var role_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder2.deinit();
    const role_queue_response2 = try generated.Message.initRootTyped(&role_queue_builder2);
    const role_queue_responses = [_]generated.Message.Builder{ role_queue_response0, role_queue_response1, role_queue_response2 };
    var provide_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer provide_role_queue.deinit(std.testing.allocator);
    var accept_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer accept_role_queue.deinit(std.testing.allocator);
    var join_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer join_role_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessagesToQueues(
        std.testing.allocator,
        role_queue_responses[0..2],
        plan,
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    ));
    try std.testing.expectEqual(stats, try state.initReadyHandoffReturnPlanMessagesToQueues(
        std.testing.allocator,
        role_queue_responses[0..],
        plan,
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    ));
    try std.testing.expectEqual(@as(usize, 1), provide_role_queue.items.len);
    try support.expectQueuedReturnAnswer(provide_role_queue.items[0], 100);
    try std.testing.expectEqual(@as(usize, 1), accept_role_queue.items.len);
    try support.expectQueuedReturnAnswer(accept_role_queue.items[0], 101);
    try std.testing.expectEqual(@as(usize, 1), join_role_queue.items.len);
    try support.expectQueuedReturnAnswer(join_role_queue.items[0], 102);
    {
        var reader = cpz.MessageReader.init(try role_queue_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(try response.return_()));
        try support.expectReturnCapabilityResult(response, 502);
    }

    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessages(responses[0..2], plan));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..2],
        plan,
        &queue,
    ));
    const invalid_accepts = [_]cpz.rpc.HandoffReturnCapability{.{ .question_id = 999, .export_id = 599 }};
    const invalid_plan = cpz.rpc.HandoffReturnPlan{ .accepts = invalid_accepts[0..] };
    try std.testing.expectError(error.InvalidTransition, state.validateReadyHandoffReturnPlan(invalid_plan));
    try std.testing.expectError(error.InvalidTransition, state.readyHandoffReturnsAlloc(std.testing.allocator, invalid_plan));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessages(responses[0..], invalid_plan));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessagesToQueue(
        std.testing.allocator,
        queue_responses[0..],
        invalid_plan,
        &queue,
    ));
}

test "rpc ready handoff handlers initialize return messages" {
    const Context = struct {
        seen: usize = 0,
        question_sum: u32 = 0,
        capability_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, usage: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            context.capability_sum += usage.capability orelse 0;
            return question_id + 600;
        }
    };
    const Sink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            const return_ = try message.get_return_();
            context.sent += 1;
            context.answer_sum += try return_.get_answerId();
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(302);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 103,
            .target = .{ .imported_cap = 302 },
            .has_recipient = true,
            .recipient_max_capability_count = 2,
            .recipient_capability = 1,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 104,
            .has_provision = true,
            .provision_max_capability_count = 3,
            .provision_capability = 2,
            .embargo = null,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireJoinMessage(root, .{
            .question_id = 105,
            .target = .{ .imported_cap = 302 },
            .has_key_part = true,
            .key_part_max_capability_count = 4,
            .key_part_capability = 3,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

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

    var provide_context: Context = .{};
    var accept_context: Context = .{};
    var join_context: Context = .{};
    const stats = try state.initReadyHandoffReturnMessagesFromHandlers(
        responses[0..],
        &provide_context,
        Context.handle,
        &accept_context,
        Context.handle,
        &join_context,
        Context.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 103), provide_context.question_sum);
    try std.testing.expectEqual(@as(u32, 1), provide_context.capability_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_context.seen);
    try std.testing.expectEqual(@as(u32, 104), accept_context.question_sum);
    try std.testing.expectEqual(@as(u32, 2), accept_context.capability_sum);
    try std.testing.expectEqual(@as(usize, 1), join_context.seen);
    try std.testing.expectEqual(@as(u32, 105), join_context.question_sum);
    try std.testing.expectEqual(@as(u32, 3), join_context.capability_sum);

    var answer_sum: u32 = 0;
    var export_sum: u32 = 0;
    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        const return_ = try response.return_();
        answer_sum += return_.answerId();
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
        defer std.testing.allocator.free(descriptors);
        export_sum += switch (descriptors[0]) {
            .sender_hosted => |id| id,
            else => return error.TestUnexpectedResult,
        };
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        const return_ = try response.return_();
        answer_sum += return_.answerId();
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
        defer std.testing.allocator.free(descriptors);
        export_sum += switch (descriptors[0]) {
            .sender_hosted => |id| id,
            else => return error.TestUnexpectedResult,
        };
    }
    {
        var reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        const return_ = try response.return_();
        answer_sum += return_.answerId();
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
        defer std.testing.allocator.free(descriptors);
        export_sum += switch (descriptors[0]) {
            .sender_hosted => |id| id,
            else => return error.TestUnexpectedResult,
        };
    }
    try std.testing.expectEqual(@as(u32, 103 + 104 + 105), answer_sum);
    try std.testing.expectEqual(@as(u32, 703 + 704 + 705), export_sum);

    const ready_return_stats = state.readyHandoffReturnStats();
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, ready_return_stats);
    try std.testing.expect(ready_return_stats.hasReturns());
    try std.testing.expect(ready_return_stats.hasProvides());
    try std.testing.expect(ready_return_stats.hasAccepts());
    try std.testing.expect(ready_return_stats.hasJoins());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, ready_return_stats.provideRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, ready_return_stats.acceptRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, ready_return_stats.joinRange());
    try std.testing.expectEqual(@as(?usize, 0), ready_return_stats.provideLocalIndex(0));
    try std.testing.expectEqual(@as(?usize, null), ready_return_stats.provideLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, 0), ready_return_stats.acceptLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, null), ready_return_stats.acceptLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 0), ready_return_stats.joinLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), ready_return_stats.joinLocalIndex(3));
    const provide_return_position = ready_return_stats.unifiedOutputPosition(0).?;
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, provide_return_position);
    try std.testing.expect(provide_return_position.isProvide());
    try std.testing.expect(!provide_return_position.isAccept());
    const accept_return_position = cpz.rpc.handoffReturnUnifiedOutputPosition(ready_return_stats, 1).?;
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, accept_return_position);
    try std.testing.expect(accept_return_position.isAccept());
    try std.testing.expect(!accept_return_position.isJoin());
    const join_return_position = ready_return_stats.unifiedOutputPosition(2).?;
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, join_return_position);
    try std.testing.expect(join_return_position.isJoin());
    try std.testing.expect(!join_return_position.isProvide());
    try std.testing.expect(ready_return_stats.unifiedOutputPosition(3) == null);
    var handoff_position_stats: cpz.rpc.StateHandoffReturnStats = .{};
    handoff_position_stats.recordPosition(provide_return_position);
    handoff_position_stats.recordPosition(accept_return_position);
    handoff_position_stats.recordPosition(join_return_position);
    try std.testing.expectEqual(ready_return_stats, handoff_position_stats);
    var handoff_index_stats: cpz.rpc.StateHandoffReturnStats = .{};
    try handoff_index_stats.recordOutputIndex(ready_return_stats, 0);
    try handoff_index_stats.recordOutputIndex(ready_return_stats, 1);
    try handoff_index_stats.recordOutputIndex(ready_return_stats, 2);
    try std.testing.expectEqual(ready_return_stats, handoff_index_stats);
    try std.testing.expectError(error.InvalidTransition, handoff_index_stats.recordOutputIndex(ready_return_stats, 3));
    const TaggedHandoffSink = struct {
        sent: usize = 0,
        provide_answer_sum: u32 = 0,
        accept_answer_sum: u32 = 0,
        join_answer_sum: u32 = 0,

        fn handle(context: *@This(), position: cpz.rpc.HandoffReturnOutputPosition, message: anytype) !void {
            const answer_id = try (try message.get_return_()).get_answerId();
            switch (position.role) {
                .provide => {
                    try std.testing.expectEqual(@as(usize, 0), position.local_index);
                    context.provide_answer_sum += answer_id;
                },
                .accept => {
                    try std.testing.expectEqual(@as(usize, 0), position.local_index);
                    context.accept_answer_sum += answer_id;
                },
                .join => {
                    try std.testing.expectEqual(@as(usize, 0), position.local_index);
                    context.join_answer_sum += answer_id;
                },
            }
            context.sent += 1;
        }
    };
    var handoff_tagged_sink: TaggedHandoffSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendHandoffReturnOutputsToTaggedSink(
        ready_return_stats,
        responses[0..2],
        &handoff_tagged_sink,
        TaggedHandoffSink.handle,
    ));
    const handoff_tagged_stats = try cpz.rpc.sendHandoffReturnOutputsToTaggedSinkStats(
        ready_return_stats,
        responses[0..],
        &handoff_tagged_sink,
        TaggedHandoffSink.handle,
    );
    try std.testing.expectEqual(ready_return_stats, handoff_tagged_stats);
    try std.testing.expectEqual(@as(usize, 3), handoff_tagged_sink.sent);
    try std.testing.expectEqual(@as(u32, 103), handoff_tagged_sink.provide_answer_sum);
    try std.testing.expectEqual(@as(u32, 104), handoff_tagged_sink.accept_answer_sum);
    try std.testing.expectEqual(@as(u32, 105), handoff_tagged_sink.join_answer_sum);
    const TaggedHandoffQueueItem = struct {
        position: cpz.rpc.HandoffReturnOutputPosition,
        message: generated.Message.Builder,
    };
    var handoff_tagged_queue = std.ArrayList(TaggedHandoffQueueItem).empty;
    defer handoff_tagged_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendHandoffReturnOutputsToTaggedQueue(
        std.testing.allocator,
        ready_return_stats,
        responses[0..2],
        &handoff_tagged_queue,
    ));
    try std.testing.expectEqual(ready_return_stats, try cpz.rpc.appendHandoffReturnOutputsToTaggedQueue(
        std.testing.allocator,
        ready_return_stats,
        responses[0..],
        &handoff_tagged_queue,
    ));
    try std.testing.expectEqual(@as(usize, 3), handoff_tagged_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, handoff_tagged_queue.items[0].position);
    try std.testing.expectEqual(@as(u32, 103), try (try handoff_tagged_queue.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, handoff_tagged_queue.items[1].position);
    try std.testing.expectEqual(@as(u32, 104), try (try handoff_tagged_queue.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, handoff_tagged_queue.items[2].position);
    try std.testing.expectEqual(@as(u32, 105), try (try handoff_tagged_queue.items[2].message.get_return_()).get_answerId());
    const RoleHandoffSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    var provide_handoff_sink: RoleHandoffSink = .{};
    var accept_handoff_sink: RoleHandoffSink = .{};
    var join_handoff_sink: RoleHandoffSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendHandoffReturnOutputsToSinks(
        ready_return_stats,
        responses[0..2],
        &provide_handoff_sink,
        RoleHandoffSink.handle,
        &accept_handoff_sink,
        RoleHandoffSink.handle,
        &join_handoff_sink,
        RoleHandoffSink.handle,
    ));
    try std.testing.expectEqual(ready_return_stats, try cpz.rpc.sendHandoffReturnOutputsToSinksStats(
        ready_return_stats,
        responses[0..],
        &provide_handoff_sink,
        RoleHandoffSink.handle,
        &accept_handoff_sink,
        RoleHandoffSink.handle,
        &join_handoff_sink,
        RoleHandoffSink.handle,
    ));
    try std.testing.expectEqual(@as(usize, 1), provide_handoff_sink.sent);
    try std.testing.expectEqual(@as(u32, 103), provide_handoff_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_handoff_sink.sent);
    try std.testing.expectEqual(@as(u32, 104), accept_handoff_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), join_handoff_sink.sent);
    try std.testing.expectEqual(@as(u32, 105), join_handoff_sink.answer_sum);
    var provide_handoff_queue = std.ArrayList(generated.Message.Builder).empty;
    defer provide_handoff_queue.deinit(std.testing.allocator);
    var accept_handoff_queue = std.ArrayList(generated.Message.Builder).empty;
    defer accept_handoff_queue.deinit(std.testing.allocator);
    var join_handoff_queue = std.ArrayList(generated.Message.Builder).empty;
    defer join_handoff_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendHandoffReturnOutputsToQueues(
        std.testing.allocator,
        ready_return_stats,
        responses[0..2],
        &provide_handoff_queue,
        &accept_handoff_queue,
        &join_handoff_queue,
    ));
    try std.testing.expectEqual(ready_return_stats, try cpz.rpc.appendHandoffReturnOutputsToQueues(
        std.testing.allocator,
        ready_return_stats,
        responses[0..],
        &provide_handoff_queue,
        &accept_handoff_queue,
        &join_handoff_queue,
    ));
    try std.testing.expectEqual(@as(usize, 1), provide_handoff_queue.items.len);
    try std.testing.expectEqual(@as(u32, 103), try (try provide_handoff_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(usize, 1), accept_handoff_queue.items.len);
    try std.testing.expectEqual(@as(u32, 104), try (try accept_handoff_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(usize, 1), join_handoff_queue.items.len);
    try std.testing.expectEqual(@as(u32, 105), try (try join_handoff_queue.items[0].get_return_()).get_answerId());
    try ready_return_stats.joinRange().validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, ready_return_stats.joinRange().validateCapacity(2));
    try ready_return_stats.validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, ready_return_stats.validateCapacity(2));

    const no_turn_messages = [_]generated.Message{};
    const handoff_turn_plan = try cpz.rpc.planRpcTurn(&state, no_turn_messages[0..]);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, handoff_turn_plan.dispatch);
    try std.testing.expectEqual(ready_return_stats, handoff_turn_plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 0), handoff_turn_plan.dispatchResponseMessages());
    try std.testing.expect(!handoff_turn_plan.hasDispatchResponses());
    try std.testing.expectEqual(@as(usize, 3), handoff_turn_plan.handoffReturnMessages());
    try std.testing.expect(handoff_turn_plan.hasHandoffReturns());
    try std.testing.expectEqual(@as(usize, 3), handoff_turn_plan.responseMessages());
    try std.testing.expectEqual(@as(usize, 0), handoff_turn_plan.forwardedMessages());
    try std.testing.expectEqual(@as(usize, 3), handoff_turn_plan.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 0), handoff_turn_plan.disembargoMessages());
    try std.testing.expect(handoff_turn_plan.hasResponses());
    try std.testing.expect(!handoff_turn_plan.hasForwards());
    try std.testing.expect(handoff_turn_plan.hasOutputs());
    try handoff_turn_plan.validateOutputCapacity(3, 0);
    try handoff_turn_plan.validateDisembargoCapacity(0);
    try handoff_turn_plan.validateUnifiedOutputCapacity(3);

    var planned_provide_context: Context = .{};
    var planned_accept_context: Context = .{};
    var planned_join_context: Context = .{};
    const planned = try state.readyHandoffReturnsFromHandlersAlloc(
        std.testing.allocator,
        &planned_provide_context,
        Context.handle,
        &planned_accept_context,
        Context.handle,
        &planned_join_context,
        Context.handle,
    );
    defer std.testing.allocator.free(planned);
    try std.testing.expectEqual(@as(usize, 3), planned.len);

    var planned_stats: cpz.rpc.StateHandoffReturnStats = .{};
    var planned_question_sum: u32 = 0;
    var planned_export_sum: u32 = 0;
    for (planned) |completion| {
        planned_stats.record(completion);
        switch (completion) {
            .provide => |value| {
                planned_question_sum += value.question_id;
                planned_export_sum += value.export_id;
            },
            .accept => |value| {
                planned_question_sum += value.question_id;
                planned_export_sum += value.export_id;
            },
            .join => |value| {
                planned_question_sum += value.question_id;
                planned_export_sum += value.export_id;
            },
        }
    }
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, planned_stats);
    try std.testing.expect(planned_stats.hasProvides());
    try std.testing.expect(planned_stats.hasAccepts());
    try std.testing.expect(planned_stats.hasJoins());
    try planned_stats.validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, planned_stats.validateCapacity(2));
    try std.testing.expectEqual(@as(u32, 103 + 104 + 105), planned_question_sum);
    try std.testing.expectEqual(@as(u32, 703 + 704 + 705), planned_export_sum);
    try std.testing.expectEqual(@as(usize, 1), planned_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), planned_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), planned_join_context.seen);

    var sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_builder0.deinit();
    const sink_response0 = try generated.Message.initRootTyped(&sink_builder0);
    var sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_builder1.deinit();
    const sink_response1 = try generated.Message.initRootTyped(&sink_builder1);
    var sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_builder2.deinit();
    const sink_response2 = try generated.Message.initRootTyped(&sink_builder2);
    const sink_responses = [_]generated.Message.Builder{ sink_response0, sink_response1, sink_response2 };
    var sink_provide_context: Context = .{};
    var sink_accept_context: Context = .{};
    var sink_join_context: Context = .{};
    var sink: Sink = .{};
    const sink_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSink(
        sink_responses[0..],
        &sink_provide_context,
        Context.handle,
        &sink_accept_context,
        Context.handle,
        &sink_join_context,
        Context.handle,
        &sink,
        Sink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, sink_stats);
    try std.testing.expectEqual(@as(usize, 3), sink.sent);
    try std.testing.expectEqual(@as(u32, 103 + 104 + 105), sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), sink_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), sink_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), sink_join_context.seen);

    const TaggedHandlerSink = struct {
        sent: usize = 0,
        provide_answer_sum: u32 = 0,
        accept_answer_sum: u32 = 0,
        join_answer_sum: u32 = 0,

        fn handle(context: *@This(), position: cpz.rpc.HandoffReturnOutputPosition, message: anytype) !void {
            const answer_id = try (try message.get_return_()).get_answerId();
            switch (position.role) {
                .provide => context.provide_answer_sum += answer_id,
                .accept => context.accept_answer_sum += answer_id,
                .join => context.join_answer_sum += answer_id,
            }
            context.sent += 1;
        }
    };
    var tagged_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_sink_builder0.deinit();
    const tagged_sink_response0 = try generated.Message.initRootTyped(&tagged_sink_builder0);
    var tagged_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_sink_builder1.deinit();
    const tagged_sink_response1 = try generated.Message.initRootTyped(&tagged_sink_builder1);
    var tagged_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_sink_builder2.deinit();
    const tagged_sink_response2 = try generated.Message.initRootTyped(&tagged_sink_builder2);
    const tagged_sink_responses = [_]generated.Message.Builder{ tagged_sink_response0, tagged_sink_response1, tagged_sink_response2 };
    var tagged_sink_provide_context: Context = .{};
    var tagged_sink_accept_context: Context = .{};
    var tagged_sink_join_context: Context = .{};
    var tagged_handler_sink: TaggedHandlerSink = .{};
    const tagged_sink_stats = try state.initReadyHandoffReturnMessagesFromHandlersToTaggedSink(
        tagged_sink_responses[0..],
        &tagged_sink_provide_context,
        Context.handle,
        &tagged_sink_accept_context,
        Context.handle,
        &tagged_sink_join_context,
        Context.handle,
        &tagged_handler_sink,
        TaggedHandlerSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, tagged_sink_stats);
    try std.testing.expectEqual(@as(usize, 3), tagged_handler_sink.sent);
    try std.testing.expectEqual(@as(u32, 103), tagged_handler_sink.provide_answer_sum);
    try std.testing.expectEqual(@as(u32, 104), tagged_handler_sink.accept_answer_sum);
    try std.testing.expectEqual(@as(u32, 105), tagged_handler_sink.join_answer_sum);
    try std.testing.expectEqual(@as(usize, 1), tagged_sink_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), tagged_sink_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), tagged_sink_join_context.seen);

    const TaggedHandlerQueueItem = struct {
        position: cpz.rpc.HandoffReturnOutputPosition,
        message: generated.Message.Builder,
    };
    var tagged_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder0.deinit();
    const tagged_queue_response0 = try generated.Message.initRootTyped(&tagged_queue_builder0);
    var tagged_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder1.deinit();
    const tagged_queue_response1 = try generated.Message.initRootTyped(&tagged_queue_builder1);
    var tagged_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_queue_builder2.deinit();
    const tagged_queue_response2 = try generated.Message.initRootTyped(&tagged_queue_builder2);
    const tagged_queue_responses = [_]generated.Message.Builder{ tagged_queue_response0, tagged_queue_response1, tagged_queue_response2 };
    var tagged_queue_provide_context: Context = .{};
    var tagged_queue_accept_context: Context = .{};
    var tagged_queue_join_context: Context = .{};
    var tagged_handler_queue = std.ArrayList(TaggedHandlerQueueItem).empty;
    defer tagged_handler_queue.deinit(std.testing.allocator);
    const tagged_queue_stats = try state.initReadyHandoffReturnMessagesFromHandlersToTaggedQueue(
        std.testing.allocator,
        tagged_queue_responses[0..],
        &tagged_queue_provide_context,
        Context.handle,
        &tagged_queue_accept_context,
        Context.handle,
        &tagged_queue_join_context,
        Context.handle,
        &tagged_handler_queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, tagged_queue_stats);
    try std.testing.expectEqual(@as(usize, 3), tagged_handler_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .provide, .local_index = 0 }, tagged_handler_queue.items[0].position);
    try support.expectQueuedReturnAnswer(tagged_handler_queue.items[0].message, 103);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .accept, .local_index = 0 }, tagged_handler_queue.items[1].position);
    try support.expectQueuedReturnAnswer(tagged_handler_queue.items[1].message, 104);
    try std.testing.expectEqual(cpz.rpc.HandoffReturnOutputPosition{ .role = .join, .local_index = 0 }, tagged_handler_queue.items[2].position);
    try support.expectQueuedReturnAnswer(tagged_handler_queue.items[2].message, 105);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), tagged_queue_join_context.seen);

    const RoleHandlerSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    var role_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder0.deinit();
    const role_sink_response0 = try generated.Message.initRootTyped(&role_sink_builder0);
    var role_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder1.deinit();
    const role_sink_response1 = try generated.Message.initRootTyped(&role_sink_builder1);
    var role_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_sink_builder2.deinit();
    const role_sink_response2 = try generated.Message.initRootTyped(&role_sink_builder2);
    const role_sink_responses = [_]generated.Message.Builder{ role_sink_response0, role_sink_response1, role_sink_response2 };
    var role_sink_provide_context: Context = .{};
    var role_sink_accept_context: Context = .{};
    var role_sink_join_context: Context = .{};
    var provide_role_sink: RoleHandlerSink = .{};
    var accept_role_sink: RoleHandlerSink = .{};
    var join_role_sink: RoleHandlerSink = .{};
    const role_sink_stats = try state.initReadyHandoffReturnMessagesFromHandlersToSinks(
        role_sink_responses[0..],
        &role_sink_provide_context,
        Context.handle,
        &role_sink_accept_context,
        Context.handle,
        &role_sink_join_context,
        Context.handle,
        &provide_role_sink,
        RoleHandlerSink.handle,
        &accept_role_sink,
        RoleHandlerSink.handle,
        &join_role_sink,
        RoleHandlerSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, role_sink_stats);
    try std.testing.expectEqual(@as(usize, 1), provide_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 103), provide_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), accept_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 104), accept_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), join_role_sink.sent);
    try std.testing.expectEqual(@as(u32, 105), join_role_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), role_sink_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), role_sink_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), role_sink_join_context.seen);

    var role_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder0.deinit();
    const role_queue_response0 = try generated.Message.initRootTyped(&role_queue_builder0);
    var role_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder1.deinit();
    const role_queue_response1 = try generated.Message.initRootTyped(&role_queue_builder1);
    var role_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_queue_builder2.deinit();
    const role_queue_response2 = try generated.Message.initRootTyped(&role_queue_builder2);
    const role_queue_responses = [_]generated.Message.Builder{ role_queue_response0, role_queue_response1, role_queue_response2 };
    var role_queue_provide_context: Context = .{};
    var role_queue_accept_context: Context = .{};
    var role_queue_join_context: Context = .{};
    var provide_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer provide_role_queue.deinit(std.testing.allocator);
    var accept_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer accept_role_queue.deinit(std.testing.allocator);
    var join_role_queue = std.ArrayList(generated.Message.Builder).empty;
    defer join_role_queue.deinit(std.testing.allocator);
    const role_queue_stats = try state.initReadyHandoffReturnMessagesFromHandlersToQueues(
        std.testing.allocator,
        role_queue_responses[0..],
        &role_queue_provide_context,
        Context.handle,
        &role_queue_accept_context,
        Context.handle,
        &role_queue_join_context,
        Context.handle,
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, role_queue_stats);
    try std.testing.expectEqual(@as(usize, 1), provide_role_queue.items.len);
    try support.expectQueuedReturnAnswer(provide_role_queue.items[0], 103);
    try std.testing.expectEqual(@as(usize, 1), accept_role_queue.items.len);
    try support.expectQueuedReturnAnswer(accept_role_queue.items[0], 104);
    try std.testing.expectEqual(@as(usize, 1), join_role_queue.items.len);
    try support.expectQueuedReturnAnswer(join_role_queue.items[0], 105);
    try std.testing.expectEqual(@as(usize, 1), role_queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), role_queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), role_queue_join_context.seen);

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
    var queue_provide_context: Context = .{};
    var queue_accept_context: Context = .{};
    var queue_join_context: Context = .{};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    const queue_stats = try state.initReadyHandoffReturnMessagesFromHandlersToQueue(
        std.testing.allocator,
        queue_responses[0..],
        &queue_provide_context,
        Context.handle,
        &queue_accept_context,
        Context.handle,
        &queue_join_context,
        Context.handle,
        &queue,
    );
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, queue_stats);
    try std.testing.expectEqual(@as(usize, 3), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 103);
    try support.expectQueuedReturnAnswer(queue.items[1], 104);
    try support.expectQueuedReturnAnswer(queue.items[2], 105);
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 1), queue_join_context.seen);

    var short_context: Context = .{};
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnMessagesFromHandlers(
        responses[0..2],
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
    ));
    try std.testing.expectEqual(@as(usize, 0), short_context.seen);
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnMessagesFromHandlersToTaggedSink(
        responses[0..2],
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &tagged_handler_sink,
        TaggedHandlerSink.handle,
    ));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnMessagesFromHandlersToTaggedQueue(
        std.testing.allocator,
        responses[0..2],
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &tagged_handler_queue,
    ));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnMessagesFromHandlersToSinks(
        responses[0..2],
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &provide_role_sink,
        RoleHandlerSink.handle,
        &accept_role_sink,
        RoleHandlerSink.handle,
        &join_role_sink,
        RoleHandlerSink.handle,
    ));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnMessagesFromHandlersToQueues(
        std.testing.allocator,
        responses[0..2],
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &provide_role_queue,
        &accept_role_queue,
        &join_role_queue,
    ));
    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnMessagesFromHandlersToQueue(
        std.testing.allocator,
        responses[0..2],
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &short_context,
        Context.handle,
        &queue,
    ));
    try std.testing.expectEqual(@as(usize, 0), short_context.seen);
}

test "rpc turn dispatcher sends dense dispatch and ready handoff outputs" {
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
    try state.applyCapDescriptor(.{ .sender_promise = 380 });
    try state.resolveImportTo(380, .{ .sender_hosted = 381 });
    try state.applyCapDescriptor(.{ .sender_hosted = 381 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 67,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 2,
            .recipient_capability = 1,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

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
    try call.set_questionId(380);
    const target = try call.init_target();
    try target.set_importedCap(380);
    try cpz.rpc.initWireCallParamsText(call, "turn forward", &.{.{ .sender_hosted = 382 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurn(&state, requests[0..]);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, plan.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), plan.responseMessages());
    try std.testing.expectEqual(@as(usize, 1), plan.forwardedMessages());
    try plan.validateOutputCapacity(2, 1);

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
    try plan.validateOutputBuilders(responses[0..], forwards[0..]);
    try std.testing.expectError(error.InvalidTransition, plan.validateOutputBuilders(responses[0..1], forwards[0..]));
    try std.testing.expectError(error.InvalidTransition, plan.validateOutputBuilders(responses[0..], forwards[0..0]));
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksFromHandlers(
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
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 66), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 2), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 66 + 67), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 380), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 67), provide_context.question_sum);
    try std.testing.expectEqual(@as(u32, 1), provide_context.capability_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 66), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 566);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 67), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 967);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 381 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("turn forward", try (try (try forwarded.params()).content()).getText());
    }
}

test "rpc turn dispatcher fills pending disembargos without sinks" {
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
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 900;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 700 });
    try state.resolveImportTo(700, .{ .sender_hosted = 701 });
    try state.applyCapDescriptor(.{ .sender_hosted = 701 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 141,
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
            .question_id = 142,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-disembargo-142",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 140);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(700);
    const target = try call.init_target();
    try target.set_importedCap(700);
    try cpz.rpc.initWireCallParamsText(call, "combined no-sink forward", &.{.{ .sender_hosted = 702 }});
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
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosFromHandlers(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        disembargos[0..],
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
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(u32, 140), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 141), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 140), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 640);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 141), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1041);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 701 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("combined no-sink forward", try (try (try forwarded.params()).content()).getText());
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("no-sink-disembargo-142", info.context.accept);
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 700 });
    try queue_state.resolveImportTo(700, .{ .sender_hosted = 701 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 701 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 141,
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
            .question_id = 142,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "no-sink-disembargo-142",
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
    var queue_call_seen: u32 = 0;
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosToQueuesFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
        queue_disembargos[0..],
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
        .{ .imported_cap = 5 },
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 140), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 2), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 140);
    try support.expectQueuedReturnAnswer(response_queue.items[1], 141);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 700, .{ .imported_cap = 701 });
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "no-sink-disembargo-142");
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc turn dispatcher fills unified outputs with pending disembargos" {
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
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 900;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 705 });
    try state.resolveImportTo(705, .{ .sender_hosted = 706 });
    try state.applyCapDescriptor(.{ .sender_hosted = 706 });

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
            .embargo = "unified-disembargo-144",
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
    try call.set_questionId(705);
    const target = try call.init_target();
    try target.set_importedCap(705);
    try cpz.rpc.initWireCallParamsText(call, "unified turn pending forward", &.{.{ .sender_hosted = 707 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurn(&state, requests[0..]);
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
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosFromHandlers(
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
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 142), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 143), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 142), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 642);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 143), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1043);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        try support.expectQueuedForwardedCallText(generated.Message.fromReader(try reader.getRoot()), 705, .{ .imported_cap = 706 }, "unified turn pending forward");
    }
    {
        var reader = cpz.MessageReader.init(try output_builder3.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("unified-disembargo-144", info.context.accept);
    }
}

test "rpc unified sink helper variants accept empty turns" {
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
    const ApplyHandler = struct {
        fn handle(_: void, _: cpz.rpc.WireMessageApplyResult) !void {}
    };
    const Sink = struct {
        fn handle(_: void, _: anytype) !void {}
    };
    const TaggedSink = struct {
        fn handle(_: void, _: cpz.rpc.RpcTurnOutputPosition, _: anytype) !void {}
    };
    const method_entries = .{};

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(0);
    const output_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(output_messages);
    const request_messages = try std.testing.allocator.alloc(generated.Message, 0);
    defer std.testing.allocator.free(request_messages);

    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        {},
        TaggedSink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        {},
        TaggedSink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        "missing",
        {},
        TaggedSink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        "missing",
        {},
        TaggedSink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
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
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        {},
        TaggedSink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToTaggedSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        {},
        TaggedSink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosToSinksFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        "missing",
        {},
        TaggedSink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedSinkFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        "missing",
        {},
        TaggedSink.handle,
        {},
        ApplyHandler.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlers(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
    ));
    try std.testing.expectEqual(cpz.rpc.RpcTurnPlan{}, try cpz.rpc.dispatchRpcTurnMethodsForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToSinksFromHandlersWithApplyHandler(
        &state,
        std.testing.allocator,
        output_messages,
        request_messages,
        {},
        BootstrapHandler.handle,
        {},
        method_entries,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        {},
        HandoffHandler.handle,
        .{ .imported_cap = 0 },
        "missing",
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        Sink.handle,
        {},
        ApplyHandler.handle,
    ));
}

test "rpc turn dispatcher filters pending accept disembargos into unified outputs" {
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
            .question_id = 156,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-unified-156",
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
            .embargo = "filter-unified-157",
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

    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoFromHandlers(
        &state,
        std.testing.allocator,
        outputs[0..],
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
        "filter-unified-157",
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 2), state.pendingAcceptEmbargoCount());

    var reader = cpz.MessageReader.init(try output_builder.segmentsConst(), .{});
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
    try std.testing.expectEqualStrings("filter-unified-157", info.context.accept);

    var queue_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_builder.deinit();
    const queue_output = try generated.Message.initRootTyped(&queue_builder);
    const queue_outputs = [_]generated.Message.Builder{queue_output};
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    const queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueueFromHandlers(
        &state,
        std.testing.allocator,
        queue_outputs[0..],
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
        "filter-unified-156",
        &queue,
    );
    try std.testing.expectEqual(@as(usize, 1), queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedDisembargoBuilder(queue.items[0], .{ .imported_cap = 5 }, "filter-unified-156");

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
    const tagged_queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToTaggedQueueFromHandlers(
        &state,
        std.testing.allocator,
        tagged_queue_outputs[0..],
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
        "filter-unified-157",
        &tagged_queue,
    );
    try std.testing.expectEqual(@as(usize, 1), tagged_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), tagged_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.RpcTurnOutputPosition{ .role = .disembargo, .local_index = 0 }, tagged_queue.items[0].position);
    try support.expectQueuedDisembargoBuilder(tagged_queue.items[0].message, .{ .imported_cap = 5 }, "filter-unified-157");

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
    const split_queued = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
        &state,
        std.testing.allocator,
        split_queue_outputs[0..],
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
        "filter-unified-156",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(@as(usize, 1), split_queued.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 0), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "filter-unified-156");
}

test "rpc turn dispatcher sends pending accept disembargos with dense outputs" {
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
        question_sum: u32 = 0,

        fn handle(context: *@This(), question_id: u32, _: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 900;
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

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 640 });
    try state.resolveImportTo(640, .{ .sender_hosted = 641 });
    try state.applyCapDescriptor(.{ .sender_hosted = 641 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 91,
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
            .question_id = 92,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "combined-turn-92",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 90);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(640);
    const target = try call.init_target();
    try target.set_importedCap(640);
    try cpz.rpc.initWireCallParamsText(call, "combined turn forward", &.{.{ .sender_hosted = 642 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurn(&state, requests[0..]);
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
    var call_seen: u32 = 0;
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    var disembargo_sink: DisembargoSink = .{};
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosFromHandlers(
        &state,
        std.testing.allocator,
        responses[0..],
        forwards[0..],
        disembargos[0..],
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
        .{ .imported_cap = 5 },
        &disembargo_sink,
        DisembargoSink.handle,
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 90), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 2), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 90 + 91), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 640), forward_sink.last_question);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.accept_contexts);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 91), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 90), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 590);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 91), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 991);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 641 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("combined turn forward", try (try (try forwarded.params()).content()).getText());
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("combined-turn-92", info.context.accept);
    }
}

test "rpc turn dispatcher filters pending accept disembargos with dense outputs" {
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
            .question_id = 98,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-turn-98",
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 99,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-turn-99",
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

    var disembargo_sink: DisembargoSink = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingToDenseSinksAndPendingAcceptDisembargosForEmbargoFromHandlers(
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
        "filter-turn-99",
        &disembargo_sink,
        DisembargoSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, applied.handoff_returns);
    try std.testing.expectEqual(@as(usize, 1), applied.disembargoMessages());
    try std.testing.expectEqual(@as(usize, 1), applied.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 1), disembargo_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), state.pendingAcceptEmbargoCount());

    var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
    try std.testing.expectEqualStrings("filter-turn-99", info.context.accept);

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 98,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-turn-98",
        });
        var accept_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAcceptMessage(root, .{
            .question_id = 99,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "filter-turn-99",
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
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingDenseAndPendingAcceptDisembargosForEmbargoToQueuesFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_response_messages,
        queue_forward_messages,
        queue_disembargo_messages[0..],
        queue_request_messages,
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
        "filter-turn-99",
        &response_queue,
        &forward_queue,
        &disembargo_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(usize, 0), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 0), forward_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), disembargo_queue.items.len);
    try support.expectQueuedDisembargoBuilder(disembargo_queue.items[0], .{ .imported_cap = 5 }, "filter-turn-99");
    try std.testing.expectEqual(@as(usize, 2), queue_state.pendingAcceptEmbargoCount());
}
