const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");

fn decode(builder: *cpz.MessageBuilder) !cpz.rpc.WireEvent {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    return cpz.rpc.eventFromWireMessage(message);
}

test "rpc wire events decode generated message union tags and ids" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_bootstrap();
        try payload.set_questionId(11);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .bootstrap = 11 }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .bootstrap = 11 }, event.toStateEvent().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_call();
        try payload.set_questionId(12);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .call = 12 }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .call = 12 }, event.toStateEvent().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_return_();
        try payload.set_answerId(13);
        try payload.set_releaseParamCaps(false);
        try payload.set_noFinishNeeded(true);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .return_ = .{ .answer_id = 13, .release_param_caps = false, .no_finish_needed = true } }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .return_ = 13 }, event.toStateEvent().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_finish();
        try payload.set_questionId(14);
        try payload.set_releaseResultCaps(false);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .finish = .{ .question_id = 14, .release_result_caps = false } }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .finish = 14 }, event.toStateEvent().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_release();
        try payload.set_id(15);
        try payload.set_referenceCount(1);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .release = .{ .id = 15, .reference_count = 1 } }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .release = .{ .import_id = 15 } }, event.toStateEvent().?);
    }
}

test "rpc top-level bootstrap helpers initialize messages" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireBootstrapMessage(root, 10);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .bootstrap = 10 }, try cpz.rpc.eventFromWireMessage(message));

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(10));
}

test "rpc bootstrap return helpers initialize capability results" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireEvent(.{ .bootstrap = 11 });

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initBootstrapReturnMessage(root, 11, 100);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const return_ = try message.return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(u32, 0), try (try results.content()).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 100 }, descriptors[0]);

    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(11));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(100));
}

test "rpc bootstrap helper responds to request readers" {
    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireBootstrapMessage(request_root, 13);

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, request);

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    try cpz.rpc.initBootstrapReturnForRequest(response_root, try request.bootstrap(), 102);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(13));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(102));
}

test "rpc bootstrap dispatcher applies requests and builds responses" {
    const Handler = struct {
        fn handle(seen_question: *u32, bootstrap: anytype) !u32 {
            seen_question.* = bootstrap.questionId();
            return 103;
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    try cpz.rpc.initWireBootstrapMessage(request_root, 14);

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());

    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try cpz.rpc.dispatchBootstrap(&state, response_root, try request.bootstrap(), &seen_question, Handler.handle);
    try std.testing.expectEqual(@as(u32, 14), seen_question);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(14));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(14));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(103));
}

test "rpc generic capability return helper initializes results" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initCapabilityReturnMessage(root, 12, 101);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(u32, 0), try (try results.content()).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 101 }, descriptors[0]);
}

test "rpc call target helpers decode imported caps and promised answers" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(40);
        const target = try call.init_target();
        try target.set_importedCap(7);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const decoded = try cpz.rpc.callTargetFromWireCall(try message.call());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 7 }, decoded);
        try std.testing.expectEqual(@as(?u32, 7), decoded.importId());
        try std.testing.expectEqual(@as(?u32, null), decoded.promisedQuestionId());

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.InvalidTransition, state.validateWireCallTarget(try message.call()));
        try state.addImport(7);
        try state.validateWireCallTarget(try message.call());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(41);
        const target = try call.init_target();
        const promised = try target.init_promisedAnswer();
        try promised.set_questionId(99);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const decoded = try cpz.rpc.callTargetFromWireCall(try message.call());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 99 } }, decoded);
        try std.testing.expectEqual(@as(?u32, null), decoded.importId());
        try std.testing.expectEqual(@as(?u32, 99), decoded.promisedQuestionId());

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.QuestionNotOpen, state.validateWireCallTarget(try message.call()));
        try state.openQuestion(99, .bootstrap);
        try state.validateWireCallTarget(try message.call());
    }
}

test "rpc call helpers decode and write send-results-to targets" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try cpz.rpc.writeSendResultsToToWire(.yourself, call);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call_reader = generated.Call.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call_reader));
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try cpz.rpc.initWireCall(std.testing.allocator, call, 43, .{ .imported_cap = 1 }, &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call_reader = generated.Call.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.caller, try cpz.rpc.sendResultsToFromWireCall(call_reader));
    }
}

test "rpc call helpers decode and write boolean flags" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const call = try generated.Call.initRootTyped(&builder);
    try cpz.rpc.writeCallFlagsToWire(.{
        .allow_third_party_tail_call = true,
        .no_promise_pipelining = true,
        .only_promise_pipeline = true,
    }, call);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call_reader = generated.Call.fromReader(try reader.getRoot());
    try std.testing.expectEqual(cpz.rpc.CallFlags{
        .allow_third_party_tail_call = true,
        .no_promise_pipelining = true,
        .only_promise_pipeline = true,
    }, cpz.rpc.callFlagsFromWireCall(call_reader));
}

test "rpc allocating call target helpers decode promised-answer transforms" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(42);
    const target = try call.init_target();
    const promised = try target.init_promisedAnswer();
    try promised.set_questionId(99);
    try cpz.rpc.initWirePromisedAnswerTransform(promised, &.{
        .{ .get_pointer_field = 1 },
        .{ .get_pointer_field = 2 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var decoded = try cpz.rpc.callTargetFromWireCallAlloc(std.testing.allocator, try message.call());
    defer decoded.deinit(std.testing.allocator);

    const promised_decoded = switch (decoded) {
        .promised_answer => |answer| answer,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(@as(u32, 99), promised_decoded.question_id);
    try std.testing.expectEqual(@as(usize, 2), promised_decoded.transform.len);
    try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp{ .get_pointer_field = 1 }, promised_decoded.transform[0]);
    try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp{ .get_pointer_field = 2 }, promised_decoded.transform[1]);
}

test "rpc call target helpers write message targets" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const target = try generated.MessageTarget.initRootTyped(&builder);
        try cpz.rpc.writeCallTargetToWire(.{ .imported_cap = 44 }, target);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const target_reader = generated.MessageTarget.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 44 }, try cpz.rpc.targetFromWireMessageTarget(target_reader));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const target = try generated.MessageTarget.initRootTyped(&builder);
        var ops = [_]cpz.rpc.PromisedAnswerOp{.{ .get_pointer_field = 6 }};
        const owned = cpz.rpc.CallTargetOwned{
            .promised_answer = .{
                .question_id = 45,
                .transform = ops[0..],
            },
        };
        try cpz.rpc.writeCallTargetOwnedToWire(owned, target);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const target_reader = generated.MessageTarget.fromReader(try reader.getRoot());
        var decoded = try cpz.rpc.targetFromWireMessageTargetAlloc(std.testing.allocator, target_reader);
        defer decoded.deinit(std.testing.allocator);
        const promised = switch (decoded) {
            .promised_answer => |answer| answer,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(@as(u32, 45), promised.question_id);
        try std.testing.expectEqual(@as(usize, 1), promised.transform.len);
        try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp{ .get_pointer_field = 6 }, promised.transform[0]);
    }
}

test "rpc promised answer helpers decode transform paths" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const promised = try generated.PromisedAnswer.initRootTyped(&builder);
        try promised.set_questionId(80);
        const transform = try promised.init_transform(2);
        try (try transform.get(0)).set_noop();
        try (try transform.get(1)).set_getPointerField(3);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const promised_reader = generated.PromisedAnswer.fromReader(try reader.getRoot());
        const ops = try cpz.rpc.promisedAnswerTransformFromWireAlloc(std.testing.allocator, promised_reader);
        defer std.testing.allocator.free(ops);
        try std.testing.expectEqual(@as(usize, 2), ops.len);
        try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp.noop, ops[0]);
        try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp{ .get_pointer_field = 3 }, ops[1]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const promised = try generated.PromisedAnswer.initRootTyped(&builder);
        try promised.set_questionId(81);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const promised_reader = generated.PromisedAnswer.fromReader(try reader.getRoot());
        const ops = try cpz.rpc.promisedAnswerTransformFromWireAlloc(std.testing.allocator, promised_reader);
        defer std.testing.allocator.free(ops);
        try std.testing.expectEqual(@as(usize, 0), ops.len);
    }
}

test "rpc promised answer helpers write transform paths" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const promised = try generated.PromisedAnswer.initRootTyped(&builder);
    try promised.set_questionId(82);
    try cpz.rpc.initWirePromisedAnswerTransform(promised, &.{
        .noop,
        .{ .get_pointer_field = 4 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const promised_reader = generated.PromisedAnswer.fromReader(try reader.getRoot());
    const ops = try cpz.rpc.promisedAnswerTransformFromWireAlloc(std.testing.allocator, promised_reader);
    defer std.testing.allocator.free(ops);
    try std.testing.expectEqual(@as(usize, 2), ops.len);
    try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp.noop, ops[0]);
    try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp{ .get_pointer_field = 4 }, ops[1]);
}

fn decodeCapDescriptor(builder: *cpz.MessageBuilder) !cpz.rpc.CapDescriptor {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const descriptor = generated.CapDescriptor.fromReader(try reader.getRoot());
    return cpz.rpc.capDescriptorFromWire(descriptor);
}

test "rpc cap descriptor helpers decode common capability table entries" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        _ = try generated.CapDescriptor.initRootTyped(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor.none, try decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_senderHosted(8);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 8 }, try decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_senderPromise(9);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 9 }, try decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_receiverHosted(10);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 10 }, try decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        const answer = try descriptor.init_receiverAnswer();
        try answer.set_questionId(11);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_answer = .{ .question_id = 11 } }, try decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        const third_party = try descriptor.init_thirdPartyHosted();
        try third_party.set_vineId(12);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 12 }, try decodeCapDescriptor(&builder));
    }
}

test "rpc payload helpers decode capability descriptor tables" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    const cap_table = try payload.init_capTable(3);
    try (try cap_table.get(0)).set_senderHosted(12);
    try (try cap_table.get(1)).set_receiverHosted(13);
    const receiver_answer = try (try cap_table.get(2)).init_receiverAnswer();
    try receiver_answer.set_questionId(14);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);

    try std.testing.expectEqual(@as(usize, 3), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 12 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 13 }, descriptors[1]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_answer = .{ .question_id = 14 } }, descriptors[2]);
}

test "rpc payload helpers write capability descriptor tables" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadCapTable(payload, &.{
        .none,
        .{ .sender_hosted = 16 },
        .{ .sender_promise = 17 },
        .{ .receiver_hosted = 18 },
        .{ .receiver_answer = .{ .question_id = 19 } },
        .{ .third_party_hosted = 20 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 6), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor.none, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 16 }, descriptors[1]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 17 }, descriptors[2]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 18 }, descriptors[3]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_answer = .{ .question_id = 19 } }, descriptors[4]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 20 }, descriptors[5]);
}

test "rpc payload helpers build sender-hosted descriptors from registries" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 0), try registry.register(std.testing.allocator, "alpha"));
    try std.testing.expectEqual(@as(u32, 1), try registry.register(std.testing.allocator, "beta"));

    const generated_descriptors = try cpz.rpc.senderHostedDescriptorsFromRegistryAlloc(std.testing.allocator, &registry);
    defer std.testing.allocator.free(generated_descriptors);
    try std.testing.expectEqual(@as(usize, 2), generated_descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, generated_descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 1 }, generated_descriptors[1]);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadCapTable(payload, generated_descriptors);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const decoded = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(generated_descriptors.len, decoded.len);
    try std.testing.expectEqual(generated_descriptors[0], decoded[0]);
    try std.testing.expectEqual(generated_descriptors[1], decoded[1]);
}

test "rpc payload helpers treat absent capability tables as empty" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    _ = try generated.Payload.initRootTyped(&builder);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 0), descriptors.len);
}

test "rpc payload validation bounds content capabilities by cap table length" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        (try payload.get_contentAsPointer()).setCapability(0);
        const cap_table = try payload.init_capTable(1);
        try (try cap_table.get(0)).set_senderHosted(15);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        try cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        (try payload.get_contentAsPointer()).setCapability(1);
        const cap_table = try payload.init_capTable(1);
        try (try cap_table.get(0)).set_senderHosted(15);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        try std.testing.expectError(error.InvalidCapabilityPointer, cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader));
    }
}

test "rpc decoded capability descriptor tables apply to state" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    const cap_table = try payload.init_capTable(2);
    try (try cap_table.get(0)).set_senderHosted(20);
    try (try cap_table.get(1)).set_receiverHosted(21);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(21);
    try state.applyCapTable(descriptors);
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(20));
    try std.testing.expectEqual(@as(?u32, 1), state.importReferenceCount(20));
}

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

test "rpc call params expose capability descriptor tables" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(26);
    const params = try call.init_params();
    const cap_table = try params.init_capTable(2);
    try (try cap_table.get(0)).set_senderPromise(30);
    try (try cap_table.get(1)).set_receiverHosted(31);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireCallParams(std.testing.allocator, try message.call());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 30 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 31 }, descriptors[1]);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(31);
    try state.applyCapTable(descriptors);
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(30));

    var direct_state = cpz.rpc.State.init(std.testing.allocator);
    defer direct_state.deinit();
    try direct_state.addExport(31);
    try direct_state.applyWireCallPayload(std.testing.allocator, try message.call());
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), direct_state.importState(30));
}

test "rpc call params cap tables can be written directly" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(67);
    try cpz.rpc.initWireCallParamsCapTable(call, &.{
        .{ .sender_hosted = 68 },
        .{ .receiver_hosted = 69 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireCallParams(std.testing.allocator, try message.call());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 68 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 69 }, descriptors[1]);
}

test "rpc call helpers initialize targets and registry-backed cap tables" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "first");
    _ = try registry.register(std.testing.allocator, "second");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try cpz.rpc.initWireCall(std.testing.allocator, call, 73, .{ .imported_cap = 5 }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const call_reader = try message.call();
    try std.testing.expectEqual(@as(u32, 73), call_reader.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call_reader));

    const descriptors = try cpz.rpc.capTableFromWireCallParams(std.testing.allocator, call_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 1 }, descriptors[1]);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(73));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(1));
}

test "rpc top-level call helpers initialize messages" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "out");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessage(std.testing.allocator, root, 75, .{ .imported_cap = 5 }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const call = try message.call();
    try std.testing.expectEqual(@as(u32, 75), call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call));
    const descriptors = try cpz.rpc.capTableFromWireCallParams(std.testing.allocator, call);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc top-level call helpers initialize routing options and flags" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageWithOptions(std.testing.allocator, root, 76, .{ .imported_cap = 5 }, &registry, .{
        .send_results_to = .yourself,
        .flags = .{
            .allow_third_party_tail_call = true,
            .no_promise_pipelining = true,
            .only_promise_pipeline = true,
        },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
    try std.testing.expectEqual(cpz.rpc.CallFlags{
        .allow_third_party_tail_call = true,
        .no_promise_pipelining = true,
        .only_promise_pipeline = true,
    }, cpz.rpc.callFlagsFromWireCall(call));
}

test "rpc wire calls apply target and params state together" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(50);
    const target = try call.init_target();
    try target.set_importedCap(5);
    const params = try call.init_params();
    const cap_table = try params.init_capTable(2);
    try (try cap_table.get(0)).set_senderHosted(6);
    try (try cap_table.get(1)).set_receiverHosted(7);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.addExport(7);
    try state.applyWireCall(std.testing.allocator, try message.call());
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(50));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(6));
}

test "rpc return results expose capability descriptor tables" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(27);
    const results = try return_.init_results();
    const cap_table = try results.init_capTable(2);
    try (try cap_table.get(0)).set_senderHosted(32);
    try (try cap_table.get(1)).set_receiverHosted(33);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try message.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 32 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 33 }, descriptors[1]);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(33);
    try state.applyCapTable(descriptors);
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(32));

    var direct_state = cpz.rpc.State.init(std.testing.allocator);
    defer direct_state.deinit();
    try direct_state.addExport(33);
    try direct_state.applyWireReturnPayload(std.testing.allocator, try message.return_());
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), direct_state.importState(32));
}

test "rpc return result cap tables can be written directly" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(70);
    try cpz.rpc.initWireReturnResultsCapTable(return_, &.{
        .{ .sender_promise = 71 },
        .{ .receiver_hosted = 72 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try message.return_());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 71 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 72 }, descriptors[1]);
}

test "rpc return helpers initialize flags and registry-backed cap tables" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "result-a");
    _ = try registry.register(std.testing.allocator, "result-b");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try cpz.rpc.initWireReturn(std.testing.allocator, return_, 74, true, false, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const return_reader = try message.return_();
    try std.testing.expectEqual(@as(u32, 74), return_reader.answerId());
    try std.testing.expect(return_reader.releaseParamCaps());
    try std.testing.expect(!return_reader.noFinishNeeded());

    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 1 }, descriptors[1]);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(74, .call);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(74));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(1));
}

test "rpc top-level return helpers initialize messages" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "result");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessage(std.testing.allocator, root, 76, false, true, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const return_ = try message.return_();
    try std.testing.expectEqual(@as(u32, 76), return_.answerId());
    try std.testing.expect(!return_.releaseParamCaps());
    try std.testing.expect(return_.noFinishNeeded());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc return outcomes without result payloads resolve answers" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(79);
        const exception = try return_.init_exception();
        try exception.set_reason("network down");
        try exception.set_type__raw(2);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        const info = switch (outcome) {
            .exception => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqualStrings("network down", info.reason.?);
        try std.testing.expectEqual(@as(u16, 2), info.type_raw);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(79, .call);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(79));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(80);
        try return_.set_canceled();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.canceled, try cpz.rpc.returnOutcomeFromWireReturn(try message.return_()));

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(80, .call);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(80));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(81);
        try return_.set_resultsSentElsewhere();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results_sent_elsewhere, try cpz.rpc.returnOutcomeFromWireReturn(try message.return_()));

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(81, .call);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(81));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(82);
        try return_.set_takeFromOtherQuestion(83);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(
            cpz.rpc.ReturnOutcome{ .take_from_other_question = 83 },
            try cpz.rpc.returnOutcomeFromWireReturn(try message.return_()),
        );

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(82, .call);
        try std.testing.expectError(error.QuestionNotOpen, state.applyWireMessage(std.testing.allocator, message));
        try state.openQuestion(83, .call);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(82));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(84);
        try return_.set_awaitFromThirdParty_capability(4);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        const usage = switch (outcome) {
            .await_from_third_party => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(@as(?u32, 4), usage.capability);
        try std.testing.expectEqual(@as(usize, 5), usage.max_capability_count);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(84, .call);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(84));
    }
}

test "rpc top-level finish and release helpers initialize messages" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireFinishMessage(root, .{ .question_id = 77, .release_result_caps = false });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(
            cpz.rpc.WireEvent{ .finish = .{ .question_id = 77, .release_result_caps = false } },
            try cpz.rpc.eventFromWireMessage(message),
        );
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReleaseMessage(root, .{ .id = 78, .reference_count = 3 });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(
            cpz.rpc.WireEvent{ .release = .{ .id = 78, .reference_count = 3 } },
            try cpz.rpc.eventFromWireMessage(message),
        );
    }
}

test "rpc return exception helpers write outcomes" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try cpz.rpc.initWireReturnException(return_, 86, true, false, .{
        .reason = "temporary overload",
        .type_raw = 1,
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
    const info = switch (outcome) {
        .exception => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqualStrings("temporary overload", info.reason.?);
    try std.testing.expectEqual(@as(u16, 1), info.type_raw);
}

test "rpc non-result return helpers write outcomes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try cpz.rpc.initWireReturnCanceled(return_, 86, true);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.canceled, try cpz.rpc.returnOutcomeFromWireReturn(try message.return_()));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try cpz.rpc.initWireReturnResultsSentElsewhere(return_, 87, false);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const return_reader = try message.return_();
        try std.testing.expect(!return_reader.releaseParamCaps());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results_sent_elsewhere, try cpz.rpc.returnOutcomeFromWireReturn(return_reader));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try cpz.rpc.initWireReturnTakeFromOtherQuestion(return_, 88, true, 89);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(
            cpz.rpc.ReturnOutcome{ .take_from_other_question = 89 },
            try cpz.rpc.returnOutcomeFromWireReturn(try message.return_()),
        );
    }
}

test "rpc await-from-third-party return helpers write outcomes" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try cpz.rpc.initWireReturnAwaitFromThirdParty(return_, 85, false, true, 6);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const return_reader = try message.return_();
    try std.testing.expectEqual(@as(u32, 85), return_reader.answerId());
    try std.testing.expect(!return_reader.releaseParamCaps());
    try std.testing.expect(return_reader.noFinishNeeded());
    const outcome = try cpz.rpc.returnOutcomeFromWireReturn(return_reader);
    const usage = switch (outcome) {
        .await_from_third_party => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(@as(?u32, 6), usage.capability);
    try std.testing.expectEqual(@as(usize, 7), usage.max_capability_count);
}

test "rpc wire returns resolve answers and apply result cap tables" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(51);
    const results = try return_.init_results();
    const cap_table = try results.init_capTable(2);
    try (try cap_table.get(0)).set_senderHosted(34);
    try (try cap_table.get(1)).set_receiverHosted(35);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(51, .call);
    try state.addExport(35);
    try state.applyWireReturn(std.testing.allocator, try message.return_());
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(51));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(34));
}

test "rpc no-finish-needed returns complete questions without result caps" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(54);
    try return_.set_noFinishNeeded(true);
    _ = try return_.init_results();

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(54, .call);
    try state.applyWireReturn(std.testing.allocator, try message.return_());
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(54));
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(54));
    try std.testing.expect(state.canReuseQuestionId(54));
}

test "rpc top-level no-finish flow permits question id reuse" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(55);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(55));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(55);
        try return_.set_noFinishNeeded(true);
        _ = try return_.init_results();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expect(state.questionComplete(55));
        try std.testing.expect(state.canReuseQuestionId(55));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(55);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(55));
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .unresolved), state.answerState(55));
    }
}

test "rpc top-level wire messages apply calls and returns" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.addExport(7);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(60);
        const target = try call.init_target();
        try target.set_importedCap(5);
        const params = try call.init_params();
        const cap_table = try params.init_capTable(2);
        try (try cap_table.get(0)).set_senderHosted(6);
        try (try cap_table.get(1)).set_receiverHosted(7);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(60));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(6));
        try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(60));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(60);
        const results = try return_.init_results();
        const cap_table = try results.init_capTable(2);
        try (try cap_table.get(0)).set_senderHosted(8);
        try (try cap_table.get(1)).set_receiverHosted(7);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(60));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(6));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(8));
        try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(60));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const finish = try root.init_finish();
        try finish.set_questionId(60);
        try finish.set_releaseResultCaps(true);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(60));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(8));
        try std.testing.expectEqual(@as(usize, 0), state.resultImportCount(60));
    }
}

test "rpc returns can retain parameter capabilities when requested" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(65);
        const target = try call.init_target();
        try target.set_importedCap(5);
        const params = try call.init_params();
        const cap_table = try params.init_capTable(1);
        try (try cap_table.get(0)).set_senderHosted(36);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(36));
        try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(65));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(65);
        try return_.set_releaseParamCaps(false);
        _ = try return_.init_results();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(36));
        try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(65));
    }
}

test "rpc finish releaseResultCaps validates before closing questions" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.addExport(7);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(67);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(67);
        const results = try return_.init_results();
        const cap_table = try results.init_capTable(1);
        try (try cap_table.get(0)).set_senderHosted(38);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try state.releaseImport(38);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const finish = try root.init_finish();
        try finish.set_questionId(67);
        try finish.set_releaseResultCaps(true);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectError(error.ImportAlreadyReleased, state.applyWireMessage(std.testing.allocator, message));
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(67));
    }
}

test "rpc return releaseParamCaps validates before resolving answers" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(66);
        const target = try call.init_target();
        try target.set_importedCap(5);
        const params = try call.init_params();
        const cap_table = try params.init_capTable(1);
        try (try cap_table.get(0)).set_senderHosted(37);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, message);
        try state.releaseImport(37);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(66);
        _ = try return_.init_results();

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectError(error.ImportAlreadyReleased, state.applyWireMessage(std.testing.allocator, message));
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .unresolved), state.answerState(66));
    }
}

test "rpc call dispatcher applies requests and builds capability returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !u32 {
            seen_question.* = call.questionId();
            return 104;
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(15);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try cpz.rpc.dispatchCallReturningCapability(&state, std.testing.allocator, response_root, try request.call(), &seen_question, Handler.handle);
    try std.testing.expectEqual(@as(u32, 15), seen_question);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(15));

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(15));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(104));
}

test "rpc call dispatcher builds empty no-finish returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !void {
            seen_question.* = call.questionId();
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(16);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try cpz.rpc.dispatchCallReturningEmpty(&state, std.testing.allocator, response_root, try request.call(), &seen_question, Handler.handle);
    try std.testing.expectEqual(@as(u32, 16), seen_question);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expect(state.questionComplete(16));
    try std.testing.expect(state.canReuseQuestionId(16));
}

test "rpc generic call dispatcher builds exception returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .{ .exception = .{ .reason = "handler failed", .type_raw = 3 } };
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(17);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try cpz.rpc.dispatchCall(&state, std.testing.allocator, response_root, try request.call(), &seen_question, Handler.handle);
    try std.testing.expectEqual(@as(u32, 17), seen_question);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try response.return_());
    const exception = switch (outcome) {
        .exception => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqualStrings("handler failed", exception.reason.?);
    try std.testing.expectEqual(@as(u16, 3), exception.type_raw);
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(17));
}

test "rpc generic call dispatcher builds empty no-finish returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(18);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try cpz.rpc.dispatchCall(&state, std.testing.allocator, response_root, try request.call(), &seen_question, Handler.handle);
    try std.testing.expectEqual(@as(u32, 18), seen_question);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const return_ = try response.return_();
    try std.testing.expect(return_.releaseParamCaps());
    try std.testing.expect(return_.noFinishNeeded());
    try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results, try cpz.rpc.returnOutcomeFromWireReturn(return_));
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expect(state.questionComplete(18));
    try std.testing.expect(state.canReuseQuestionId(18));
}

test "rpc generic call dispatcher builds capability returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .{ .capability = 105 };
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(19);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try cpz.rpc.dispatchCall(&state, std.testing.allocator, response_root, try request.call(), &seen_question, Handler.handle);
    try std.testing.expectEqual(@as(u32, 19), seen_question);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const return_ = try response.return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(u32, 0), try (try results.content()).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 105 }, descriptors[0]);
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(19));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(105));
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
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.InvalidTransition, state.applyWireMessage(std.testing.allocator, message));
        try state.addImport(70);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(61));
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
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.QuestionNotOpen, state.applyWireMessage(std.testing.allocator, message));
        try state.openQuestion(63, .bootstrap);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(62));
    }
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
    }
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
}

test "rpc top-level accept messages open questions" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const accept = try root.init_accept();
    try accept.set_questionId(64);
    try accept.set_embargo("embargo-64");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.acceptInfoFromWireAccept(try message.accept());
    try std.testing.expectEqual(@as(u32, 64), info.question_id);
    try std.testing.expect(!info.has_provision);
    try std.testing.expectEqual(@as(usize, 0), info.provision_max_capability_count);
    try std.testing.expectEqualStrings("embargo-64", info.embargo.?);
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(64));
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
        const event = try decode(&builder);
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
        const event = try decode(&builder);
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
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .join = 25 }, event);
        try std.testing.expect(event.toStateEvent() == null);
        try state.applyWireEvent(event);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(25));
    }
}

test "rpc third-party answer wire events resolve answers" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(24, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const payload = try root.init_thirdPartyAnswer();
    try payload.set_answerId(24);
    const event = try decode(&builder);
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .third_party_answer = 24 }, event);
    try std.testing.expect(event.toStateEvent() == null);
    try state.applyWireEvent(event);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(24));
}

test "rpc resolve wire events mark exports without projecting to Event.resolve" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(21);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const payload = try root.init_resolve();
    try payload.set_promiseId(21);

    const event = try decode(&builder);
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .resolve = 21 }, event);
    try std.testing.expect(event.toStateEvent() == null);
    try state.applyWireEvent(event);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(21));
}

test "rpc resolve cap descriptors replace promise exports" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const resolve = try root.init_resolve();
    try resolve.set_promiseId(90);
    const cap = try resolve.init_cap();
    try cap.set_senderHosted(91);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(try message.resolve());
    try std.testing.expectEqual(@as(u32, 90), info.promise_id);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 91 }, info.cap.?);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(90);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(90));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(91));
}

test "rpc resolve exceptions mark promise exports resolved" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const resolve = try root.init_resolve();
    try resolve.set_promiseId(96);
    const exception = try resolve.init_exception();
    try exception.set_reason("promise broken");
    try exception.set_type__raw(2);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(try message.resolve());
    try std.testing.expectEqual(@as(u32, 96), info.promise_id);
    try std.testing.expect(info.cap == null);
    const decoded_exception = info.exception orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("promise broken", decoded_exception.reason.?);
    try std.testing.expectEqual(@as(u16, 2), decoded_exception.type_raw);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(96);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(96));
}

test "rpc resolve info helpers write cap descriptors" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const resolve = try generated.Resolve.initRootTyped(&builder);
    try cpz.rpc.writeResolveInfoToWire(.{
        .promise_id = 92,
        .cap = .{ .sender_promise = 93 },
    }, resolve);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const resolve_reader = generated.Resolve.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(resolve_reader);
    try std.testing.expectEqual(@as(u32, 92), info.promise_id);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 93 }, info.cap.?);
}

test "rpc resolve info helpers write exceptions" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const resolve = try generated.Resolve.initRootTyped(&builder);
    try cpz.rpc.writeResolveInfoToWire(.{
        .promise_id = 97,
        .exception = .{ .reason = "resolve failed", .type_raw = 3 },
    }, resolve);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const resolve_reader = generated.Resolve.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(resolve_reader);
    try std.testing.expectEqual(@as(u32, 97), info.promise_id);
    try std.testing.expect(info.cap == null);
    const exception = info.exception orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("resolve failed", exception.reason.?);
    try std.testing.expectEqual(@as(u16, 3), exception.type_raw);
}

test "rpc top-level resolve helpers initialize messages" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireResolveMessage(root, .{
        .promise_id = 94,
        .cap = .{ .sender_hosted = 95 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(try message.resolve());
    try std.testing.expectEqual(@as(u32, 94), info.promise_id);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 95 }, info.cap.?);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(94);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(94));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(95));
}

test "rpc top-level resolve helpers initialize exceptions" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireResolveMessage(root, .{
        .promise_id = 98,
        .exception = .{ .reason = null, .type_raw = 1 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(try message.resolve());
    try std.testing.expectEqual(@as(u32, 98), info.promise_id);
    const exception = info.exception orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("", exception.reason.?);
    try std.testing.expectEqual(@as(u16, 1), exception.type_raw);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(98);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(98));
}

test "decoded wire events can drive the supported state subset" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_bootstrap();
        try payload.set_questionId(31);
        try state.applyWireEvent(try decode(&builder));
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(31));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_finish();
        try payload.set_questionId(31);
        try state.applyWireEvent(try decode(&builder));
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(31));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_return_();
        try payload.set_answerId(31);
        try state.applyWireEvent(try decode(&builder));
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(31));
    }

    try state.addImport(32);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_release();
        try payload.set_id(32);
        try payload.set_referenceCount(1);
        try state.applyWireEvent(try decode(&builder));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(32));
    }
}

test "rpc release wire events preserve reference counts" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.imports.put(41, .{ .id = 41, .reference_count = 3 });

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const payload = try root.init_release();
    try payload.set_id(41);
    try payload.set_referenceCount(2);

    const event = try decode(&builder);
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .release = .{ .id = 41, .reference_count = 2 } }, event);
    try std.testing.expect(event.toStateEvent() == null);
    try state.applyWireEvent(event);
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(41));
    try std.testing.expectEqual(@as(?u32, 1), state.importReferenceCount(41));
}
