const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");

fn decode(builder: *cpz.MessageBuilder) !cpz.rpc.WireEvent {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    return cpz.rpc.eventFromWireMessage(message);
}

fn expectPayloadUInt32List(payload: anytype, expected: []const u32) !void {
    const list = try (try payload.content()).getList(.four_bytes);
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| {
        try std.testing.expectEqual(value, list.getUInt32(index));
    }
    try std.testing.expect((try cpz.rpc.payloadContentCapabilityIndex(payload)) == null);
    try cpz.rpc.validateWirePayload(std.testing.allocator, payload);
}

fn expectReturnCapabilityResult(message: anytype, expected_export_id: cpz.rpc.ExportId) !void {
    const return_ = try message.return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(u32, 0), try (try results.content()).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = expected_export_id }, descriptors[0]);
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
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try cpz.rpc.writeSendResultsToThirdPartyToWire(call, .{ .max_capability_count = 4, .capability = 3 });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call_reader = generated.Call.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, try cpz.rpc.sendResultsToFromWireCall(call_reader));
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, (try cpz.rpc.sendResultsToThirdPartyUsageFromWireCall(call_reader)).?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeSendResultsToThirdPartyToWire(call, .{ .max_capability_count = 4, .capability = 4 }));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try cpz.rpc.writeSendResultsToToWire(.third_party, call);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call_reader = generated.Call.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, try cpz.rpc.sendResultsToFromWireCall(call_reader));
        try std.testing.expectEqual(
            cpz.rpc.AnyPointerUsage{ .max_capability_count = 0, .capability = null },
            (try cpz.rpc.sendResultsToThirdPartyUsageFromWireCall(call_reader)).?,
        );
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

test "rpc call helpers decode and write method ids" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const call = try generated.Call.initRootTyped(&builder);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xfeed_beef, .method_id = 42 }, call);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call_reader = generated.Call.fromReader(try reader.getRoot());
    const method = cpz.rpc.callMethodFromWireCall(call_reader);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0xfeed_beef, .method_id = 42 }, method);
    try std.testing.expect(!method.isDefault());
    try std.testing.expect(method.matches(0xfeed_beef, 42));
    try std.testing.expect(!method.matches(0xfeed_beef, 41));
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

fn decodeCapDescriptorInfo(builder: *cpz.MessageBuilder) !cpz.rpc.CapDescriptorInfo {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const descriptor = generated.CapDescriptor.fromReader(try reader.getRoot());
    return cpz.rpc.capDescriptorInfoFromWire(descriptor);
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
        (try third_party.get_idAsPointer()).setCapability(3);
        try third_party.set_vineId(12);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 12 }, try decodeCapDescriptor(&builder));
        const info = try decodeCapDescriptorInfo(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 12 }, info.descriptor);
        try std.testing.expectEqual(@as(u8, 0xff), info.attached_fd);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, info.third_party_contact.?);
    }
}

test "rpc cap descriptor info helpers preserve attached fd indexes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_senderHosted(13);
        try descriptor.set_attachedFd(4);
        try std.testing.expectEqual(
            cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 13 }, .attached_fd = 4 },
            try decodeCapDescriptorInfo(&builder),
        );
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try cpz.rpc.writeCapDescriptorInfoToWire(.{ .descriptor = .{ .sender_promise = 14 }, .attached_fd = 2 }, descriptor);
        try std.testing.expectEqual(
            cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 14 }, .attached_fd = 2 },
            try decodeCapDescriptorInfo(&builder),
        );
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try cpz.rpc.writeCapDescriptorInfoToWire(.{
            .descriptor = .{ .third_party_hosted = 15 },
            .third_party_contact = .{ .max_capability_count = 6, .capability = 5 },
        }, descriptor);
        const info = try decodeCapDescriptorInfo(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 15 }, info.descriptor);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 6, .capability = 5 }, info.third_party_contact.?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeCapDescriptorInfoToWire(.{
            .descriptor = .{ .third_party_hosted = 16 },
            .third_party_contact = .{ .max_capability_count = 6, .capability = 6 },
        }, descriptor));
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

test "rpc payload info helpers decode attached fd metadata" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    const cap_table = try payload.init_capTable(2);
    const first = try cap_table.get(0);
    try first.set_senderHosted(15);
    try first.set_attachedFd(1);
    const second = try cap_table.get(1);
    try second.set_senderPromise(16);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(infos);

    try std.testing.expectEqual(@as(usize, 2), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 15 }, .attached_fd = 1 }, infos[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 16 }, .attached_fd = 0xff }, infos[1]);
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

test "rpc payload info helpers write attached fd metadata" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadCapTableInfo(payload, &.{
        .{ .descriptor = .{ .sender_hosted = 21 }, .attached_fd = 3 },
        .{ .descriptor = .{ .third_party_hosted = 22 }, .attached_fd = 0xff, .third_party_contact = .{ .max_capability_count = 3, .capability = 2 } },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 2), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 21 }, .attached_fd = 3 }, infos[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 22 }, infos[1].descriptor);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, infos[1].third_party_contact.?);
}

test "rpc payload helpers initialize content capability with descriptor tables" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadCapability(payload, 1, &.{
        .{ .sender_hosted = 23 },
        .{ .sender_promise = 24 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(?u32, 1), try cpz.rpc.payloadContentCapabilityIndex(payload_reader));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 2), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 23 }, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 24 }, descriptors[1]);
    try cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader);
}

test "rpc payload info helpers initialize content capability with descriptor metadata" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadCapabilityInfo(payload, 0, &.{
        .{ .descriptor = .{ .sender_hosted = 25 }, .attached_fd = 5 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(payload_reader));
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 25 }, .attached_fd = 5 }, infos[0]);
    try cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader);
}

test "rpc payload helpers initialize struct content with descriptor tables" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0xabcddcba;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadStructWith(
        payload,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .sender_hosted = 26 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const content = try (try payload_reader.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0xabcddcba), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 26 }, descriptors[0]);
}

test "rpc payload helpers initialize struct content from registries" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "alpha");

    var value: u32 = 0x10203040;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadStructFromRegistry(
        std.testing.allocator,
        payload,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &registry,
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const content = try (try payload_reader.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x10203040), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc payload helpers initialize text and data content" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        try cpz.rpc.initWirePayloadText(payload, "hello payload", &.{.{ .sender_hosted = 27 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        try std.testing.expectEqualStrings("hello payload", try (try payload_reader.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 27 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        try cpz.rpc.initWirePayloadData(payload, "bytes", &.{.{ .sender_promise = 28 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        try std.testing.expectEqualSlices(u8, "bytes", try (try payload_reader.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 28 }, descriptors[0]);
    }
}

test "rpc payload helpers initialize text and data content from registries" {
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "text-cap");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        try cpz.rpc.initWirePayloadTextFromRegistry(std.testing.allocator, payload, "registry text", &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        try std.testing.expectEqualStrings("registry text", try (try payload_reader.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "data-cap");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        try cpz.rpc.initWirePayloadDataFromRegistry(std.testing.allocator, payload, "registry bytes", &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        try std.testing.expectEqualSlices(u8, "registry bytes", try (try payload_reader.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc payload helpers initialize UInt32 list content" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        try cpz.rpc.initWirePayloadUInt32List(payload, &.{ 10, 20, 30 }, &.{.{ .sender_hosted = 29 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        const content = try payload_reader.content();
        const list = try content.getList(.four_bytes);
        try std.testing.expectEqual(@as(usize, 3), list.len());
        try std.testing.expectEqual(@as(u32, 10), list.getUInt32(0));
        try std.testing.expectEqual(@as(u32, 20), list.getUInt32(1));
        try std.testing.expectEqual(@as(u32, 30), list.getUInt32(2));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 29 }, descriptors[0]);
        try std.testing.expect((try cpz.rpc.payloadContentCapabilityIndex(payload_reader)) == null);
        try cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const payload = try generated.Payload.initRootTyped(&builder);
        try cpz.rpc.initWirePayloadUInt32ListInfo(
            payload,
            &.{ 100, 200 },
            &.{.{ .descriptor = .{ .sender_promise = 30 }, .attached_fd = 7 }},
        );

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const payload_reader = generated.Payload.fromReader(try reader.getRoot());
        const list = try (try payload_reader.content()).getList(.four_bytes);
        try std.testing.expectEqual(@as(usize, 2), list.len());
        try std.testing.expectEqual(@as(u32, 100), list.getUInt32(0));
        try std.testing.expectEqual(@as(u32, 200), list.getUInt32(1));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, payload_reader);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 30 }, .attached_fd = 7 }, infos[0]);
        try cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader);
    }
}

test "rpc payload helpers initialize UInt32 list content from registries" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "list-cap");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const payload = try generated.Payload.initRootTyped(&builder);
    try cpz.rpc.initWirePayloadUInt32ListFromRegistry(std.testing.allocator, payload, &.{ 0, 1, 0xffffffff }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const list = try (try payload_reader.content()).getList(.four_bytes);
    try std.testing.expectEqual(@as(usize, 3), list.len());
    try std.testing.expectEqual(@as(u32, 0), list.getUInt32(0));
    try std.testing.expectEqual(@as(u32, 1), list.getUInt32(1));
    try std.testing.expectEqual(@as(u32, 0xffffffff), list.getUInt32(2));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    try cpz.rpc.validateWirePayload(std.testing.allocator, payload_reader);
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
    try std.testing.expect((try cpz.rpc.payloadContentCapabilityIndex(payload_reader)) == null);
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

test "rpc direct payload application validates content capability indexes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(90);
        const params = try call.init_params();
        (try params.get_contentAsPointer()).setCapability(1);
        const cap_table = try params.init_capTable(1);
        try (try cap_table.get(0)).set_senderHosted(91);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.InvalidCapabilityPointer, state.applyWireCallPayload(std.testing.allocator, try message.call()));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, null), state.importState(91));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(91);
        const results = try return_.init_results();
        (try results.get_contentAsPointer()).setCapability(2);
        const cap_table = try results.init_capTable(2);
        try (try cap_table.get(0)).set_senderHosted(92);
        try (try cap_table.get(1)).set_senderHosted(93);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.InvalidCapabilityPointer, state.applyWireReturnPayload(std.testing.allocator, try message.return_()));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, null), state.importState(92));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, null), state.importState(93));
    }
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

test "rpc call params cap table info can be written directly" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(70);
    try cpz.rpc.initWireCallParamsCapTableInfo(call, &.{
        .{ .descriptor = .{ .sender_hosted = 71 }, .attached_fd = 9 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const infos = try cpz.rpc.capTableInfoFromWireCallParams(std.testing.allocator, try message.call());
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 71 }, .attached_fd = 9 }, infos[0]);
}

test "rpc call params helpers initialize content capabilities" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(68);
        try cpz.rpc.initWireCallParamsCapability(call, 0, &.{.{ .sender_hosted = 70 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const params = try (try message.call()).params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 70 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(69);
        try cpz.rpc.initWireCallParamsCapabilityInfo(call, 0, &.{.{ .descriptor = .{ .sender_promise = 71 }, .attached_fd = 6 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const params = try (try message.call()).params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 71 }, .attached_fd = 6 }, infos[0]);
    }
}

test "rpc call params helpers initialize text payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(72);
        try cpz.rpc.initWireCallParamsText(call, "call text", &.{.{ .sender_hosted = 73 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try std.testing.expectEqualStrings("call text", try (try params.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 73 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(73);
        try cpz.rpc.initWireCallParamsTextInfo(call, "call info text", &.{.{
            .descriptor = .{ .sender_promise = 74 },
            .attached_fd = 9,
        }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try std.testing.expectEqualStrings("call info text", try (try params.content()).getText());
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 74 }, .attached_fd = 9 }, infos[0]);
    }
}

test "rpc call params helpers initialize text payloads from registries" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "call-param-text");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(74);
    try cpz.rpc.initWireCallParamsTextFromRegistry(std.testing.allocator, call, "registry call text", &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualStrings("registry call text", try (try params.content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call params helpers initialize data payload descriptor info" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(75);
    try cpz.rpc.initWireCallParamsDataInfo(call, "call info bytes", &.{.{
        .descriptor = .{ .sender_promise = 76 },
        .attached_fd = 10,
    }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualSlices(u8, "call info bytes", try (try params.content()).getData());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 76 }, .attached_fd = 10 }, infos[0]);
}

test "rpc call params helpers initialize data payload descriptors" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(76);
        try cpz.rpc.initWireCallParamsData(call, "call bytes", &.{.{ .sender_hosted = 77 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try std.testing.expectEqualSlices(u8, "call bytes", try (try params.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 77 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "call-param-data");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(77);
        try cpz.rpc.initWireCallParamsDataFromRegistry(std.testing.allocator, call, "registry call bytes", &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try std.testing.expectEqualSlices(u8, "registry call bytes", try (try params.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc call params helpers initialize UInt32 list payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(73);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 2, 4, 8 }, &.{.{ .sender_hosted = 74 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try expectPayloadUInt32List(params, &.{ 2, 4, 8 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 74 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const call = try root.init_call();
        try call.set_questionId(74);
        try cpz.rpc.initWireCallParamsUInt32ListInfo(call, &.{ 16, 32 }, &.{.{
            .descriptor = .{ .sender_promise = 75 },
            .attached_fd = 15,
        }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try expectPayloadUInt32List(params, &.{ 16, 32 });
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 75 }, .attached_fd = 15 }, infos[0]);
    }
}

test "rpc call params helpers initialize UInt32 list payloads from registries" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "call-list-cap");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(75);
    try cpz.rpc.initWireCallParamsUInt32ListFromRegistry(std.testing.allocator, call, &.{ 64, 128 }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try expectPayloadUInt32List(params, &.{ 64, 128 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call params helpers initialize struct payloads from registries" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "call-cap");

    var value: u32 = 0x55667788;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(74);
    try cpz.rpc.initWireCallParamsStructFromRegistry(
        std.testing.allocator,
        call,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &registry,
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x55667788), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call params helpers initialize struct payload descriptor info" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0x66778899;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(76);
    try cpz.rpc.initWireCallParamsStructInfoWith(
        call,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .descriptor = .{ .sender_promise = 79 }, .attached_fd = 18 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x66778899), content.getUInt32(0, 0));
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 79 }, .attached_fd = 18 }, infos[0]);
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
        .method = .{ .interface_id = 0x1234, .method_id = 7 },
        .send_results_to = .yourself,
        .flags = .{
            .allow_third_party_tail_call = true,
            .no_promise_pipelining = true,
            .only_promise_pipeline = true,
        },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x1234, .method_id = 7 }, cpz.rpc.callMethodFromWireCall(call));
    try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
    try std.testing.expectEqual(cpz.rpc.CallFlags{
        .allow_third_party_tail_call = true,
        .no_promise_pipelining = true,
        .only_promise_pipeline = true,
    }, cpz.rpc.callFlagsFromWireCall(call));
}

test "rpc call options initialize third-party result routing" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageWithOptions(std.testing.allocator, root, 79, .{ .imported_cap = 5 }, &registry, .{
        .send_results_to = .third_party,
        .send_results_to_third_party = .{ .max_capability_count = 4, .capability = 3 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, try cpz.rpc.sendResultsToFromWireCall(call));
    try std.testing.expectEqual(
        cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 },
        (try cpz.rpc.sendResultsToThirdPartyUsageFromWireCall(call)).?,
    );
}

test "rpc top-level call helpers initialize content capabilities" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessagePayloadCapability(root, 77, .{ .imported_cap = 5 }, 0, &.{.{ .sender_hosted = 78 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(@as(u32, 77), call.questionId());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 78 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessagePayloadCapabilityInfo(root, 78, .{ .imported_cap = 5 }, 0, &.{.{ .descriptor = .{ .sender_promise = 79 }, .attached_fd = 7 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        const params = try call.params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 79 }, .attached_fd = 7 }, infos[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "call-capability-result");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessagePayloadCapabilityFromRegistry(std.testing.allocator, root, 79, .{ .imported_cap = 5 }, 0, &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        const params = try call.params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessagePayloadCapabilityWithOptions(root, 80, .{ .imported_cap = 5 }, 0, &.{.{ .sender_hosted = 81 }}, .{
            .method = .{ .interface_id = 0x9040, .method_id = 21 },
            .send_results_to = .yourself,
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9040, .method_id = 21 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 81 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "call-capability-options");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessagePayloadCapabilityFromRegistryWithOptions(std.testing.allocator, root, 82, .{ .imported_cap = 5 }, 0, &registry, .{
            .method = .{ .interface_id = 0x9042, .method_id = 23 },
            .flags = .{ .only_promise_pipeline = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9042, .method_id = 23 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .only_promise_pipeline = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessagePayloadCapabilityInfoWithOptions(root, 81, .{ .imported_cap = 5 }, 0, &.{.{
            .descriptor = .{ .sender_promise = 82 },
            .attached_fd = 8,
        }}, .{
            .method = .{ .interface_id = 0x9041, .method_id = 22 },
            .flags = .{ .no_promise_pipelining = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9041, .method_id = 22 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .no_promise_pipelining = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 82 }, .attached_fd = 8 }, infos[0]);
    }
}

test "rpc top-level call helpers initialize struct payloads" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0x11112222;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageStructWith(
        root,
        80,
        .{ .imported_cap = 5 },
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .sender_hosted = 82 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 80), call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call));
    const params = try call.params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x11112222), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 82 }, descriptors[0]);
}

test "rpc top-level call helpers initialize registry-backed struct payloads" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "top-call-struct");

    var value: u32 = 0x13572468;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageStructFromRegistry(
        std.testing.allocator,
        root,
        81,
        .{ .imported_cap = 5 },
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &registry,
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 81), call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call));
    const params = try call.params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x13572468), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc top-level call struct helpers support routing options" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    {
        var value: u32 = 0x01020304;
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageStructWithOptions(
            root,
            82,
            .{ .imported_cap = 5 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &.{.{ .sender_hosted = 83 }},
            &value,
            Fill.write,
            .{
                .method = .{ .interface_id = 0x9020, .method_id = 15 },
                .send_results_to = .yourself,
            },
        );

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9020, .method_id = 15 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
        const params = try call.params();
        const content = try (try params.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x01020304), content.getUInt32(0, 0));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 83 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "option-registry-struct");

        var value: u32 = 0x05060708;
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageStructFromRegistryWithOptions(
            std.testing.allocator,
            root,
            83,
            .{ .imported_cap = 5 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &registry,
            &value,
            Fill.write,
            .{
                .method = .{ .interface_id = 0x9021, .method_id = 16 },
                .flags = .{ .only_promise_pipeline = true },
            },
        );

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9021, .method_id = 16 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .only_promise_pipeline = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        const content = try (try params.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x05060708), content.getUInt32(0, 0));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc top-level call info helpers support routing options" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    {
        var value: u32 = 0x0a0b0c0d;
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageStructInfoWithOptions(
            root,
            96,
            .{ .imported_cap = 5 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &.{.{ .descriptor = .{ .sender_hosted = 99 }, .attached_fd = 19 }},
            &value,
            Fill.write,
            .{ .method = .{ .interface_id = 0x9030, .method_id = 17 } },
        );

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9030, .method_id = 17 }, cpz.rpc.callMethodFromWireCall(call));
        const params = try call.params();
        const content = try (try params.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x0a0b0c0d), content.getUInt32(0, 0));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 99 }, .attached_fd = 19 }, infos[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageTextInfoWithOptions(root, 97, .{ .imported_cap = 5 }, "info option text", &.{.{
            .descriptor = .{ .sender_promise = 100 },
            .attached_fd = 20,
        }}, .{ .method = .{ .interface_id = 0x9031, .method_id = 18 }, .send_results_to = .yourself });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9031, .method_id = 18 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualStrings("info option text", try (try params.content()).getText());
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 100 }, .attached_fd = 20 }, infos[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageDataInfoWithOptions(root, 98, .{ .imported_cap = 5 }, "info option bytes", &.{.{
            .descriptor = .{ .sender_hosted = 101 },
            .attached_fd = 21,
        }}, .{ .method = .{ .interface_id = 0x9032, .method_id = 19 }, .flags = .{ .no_promise_pipelining = true } });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .no_promise_pipelining = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualSlices(u8, "info option bytes", try (try params.content()).getData());
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 101 }, .attached_fd = 21 }, infos[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageUInt32ListInfoWithOptions(root, 99, .{ .imported_cap = 5 }, &.{ 11, 22 }, &.{.{
            .descriptor = .{ .sender_hosted = 102 },
            .attached_fd = 22,
        }}, .{ .method = .{ .interface_id = 0x9033, .method_id = 20 }, .flags = .{ .only_promise_pipeline = true } });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .only_promise_pipeline = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try expectPayloadUInt32List(params, &.{ 11, 22 });
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 102 }, .attached_fd = 22 }, infos[0]);
    }
}

test "rpc top-level call helpers initialize struct payload descriptor info" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0x55556666;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageStructInfoWith(
        root,
        81,
        .{ .imported_cap = 5 },
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .descriptor = .{ .sender_hosted = 85 }, .attached_fd = 11 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    const params = try call.params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x55556666), content.getUInt32(0, 0));
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 85 }, .attached_fd = 11 }, infos[0]);
}

test "rpc top-level call helpers initialize text payload descriptor info" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageTextInfo(root, 82, .{ .imported_cap = 5 }, "call info text", &.{.{
        .descriptor = .{ .sender_hosted = 88 },
        .attached_fd = 13,
    }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    const params = try call.params();
    try std.testing.expectEqualStrings("call info text", try (try params.content()).getText());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 88 }, .attached_fd = 13 }, infos[0]);
}

test "rpc top-level call helpers initialize data payload descriptor info" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageDataInfo(root, 83, .{ .imported_cap = 5 }, "call info bytes", &.{.{
        .descriptor = .{ .sender_hosted = 89 },
        .attached_fd = 14,
    }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    const params = try call.params();
    try std.testing.expectEqualSlices(u8, "call info bytes", try (try params.content()).getData());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 89 }, .attached_fd = 14 }, infos[0]);
}

test "rpc top-level call helpers initialize text payload descriptors" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageText(root, 83, .{ .imported_cap = 5 }, "call text", &.{.{ .sender_hosted = 90 }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    const params = try call.params();
    try std.testing.expectEqualStrings("call text", try (try params.content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 90 }, descriptors[0]);
}

test "rpc top-level call helpers initialize registry-backed text payloads" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "top-call-text");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageTextFromRegistry(std.testing.allocator, root, 84, .{ .imported_cap = 5 }, "top call registry text", &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualStrings("top call registry text", try (try params.content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc top-level call helpers initialize data payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageData(root, 88, .{ .imported_cap = 5 }, "call bytes", &.{.{ .sender_hosted = 94 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(@as(u32, 88), call.questionId());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualSlices(u8, "call bytes", try (try params.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 94 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "top-call-data");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageDataFromRegistry(std.testing.allocator, root, 89, .{ .imported_cap = 5 }, "top call registry bytes", &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try std.testing.expectEqualSlices(u8, "top call registry bytes", try (try params.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc top-level call payload helpers support routing options" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageTextWithOptions(root, 90, .{ .imported_cap = 5 }, "option text", &.{.{ .sender_hosted = 96 }}, .{
            .method = .{ .interface_id = 0x9000, .method_id = 9 },
            .send_results_to = .yourself,
            .flags = .{ .no_promise_pipelining = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(@as(u32, 90), call.questionId());
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9000, .method_id = 9 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .no_promise_pipelining = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualStrings("option text", try (try params.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 96 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageDataWithOptions(root, 91, .{ .imported_cap = 5 }, "option bytes", &.{.{ .sender_hosted = 97 }}, .{
            .method = .{ .interface_id = 0x9001, .method_id = 10 },
            .flags = .{ .only_promise_pipeline = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9001, .method_id = 10 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .only_promise_pipeline = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualSlices(u8, "option bytes", try (try params.content()).getData());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageUInt32ListWithOptions(root, 92, .{ .imported_cap = 5 }, &.{ 1, 3, 5 }, &.{.{ .sender_hosted = 98 }}, .{
            .method = .{ .interface_id = 0x9002, .method_id = 11 },
            .send_results_to = .third_party,
            .send_results_to_third_party = .{ .max_capability_count = 4, .capability = 3 },
            .flags = .{ .allow_third_party_tail_call = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9002, .method_id = 11 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, try cpz.rpc.sendResultsToFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, (try cpz.rpc.sendResultsToThirdPartyUsageFromWireCall(call)).?);
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .allow_third_party_tail_call = true }, cpz.rpc.callFlagsFromWireCall(call));
        try expectPayloadUInt32List(try call.params(), &.{ 1, 3, 5 });
    }
}

test "rpc registry-backed call payload helpers support routing options" {
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "option-registry-text");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageTextFromRegistryWithOptions(std.testing.allocator, root, 93, .{ .imported_cap = 5 }, "registry option text", &registry, .{
            .method = .{ .interface_id = 0x9010, .method_id = 12 },
            .send_results_to = .yourself,
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9010, .method_id = 12 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualStrings("registry option text", try (try params.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "option-registry-data");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageDataFromRegistryWithOptions(std.testing.allocator, root, 94, .{ .imported_cap = 5 }, "registry option bytes", &registry, .{
            .method = .{ .interface_id = 0x9011, .method_id = 13 },
            .flags = .{ .no_promise_pipelining = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9011, .method_id = 13 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .no_promise_pipelining = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try std.testing.expectEqualSlices(u8, "registry option bytes", try (try params.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "option-registry-list");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageUInt32ListFromRegistryWithOptions(std.testing.allocator, root, 95, .{ .imported_cap = 5 }, &.{ 9, 18 }, &registry, .{
            .method = .{ .interface_id = 0x9012, .method_id = 14 },
            .flags = .{ .only_promise_pipeline = true },
        });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9012, .method_id = 14 }, cpz.rpc.callMethodFromWireCall(call));
        try std.testing.expectEqual(cpz.rpc.CallFlags{ .only_promise_pipeline = true }, cpz.rpc.callFlagsFromWireCall(call));
        const params = try call.params();
        try expectPayloadUInt32List(params, &.{ 9, 18 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc top-level call helpers initialize UInt32 list payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageUInt32List(root, 85, .{ .imported_cap = 5 }, &.{ 3, 6, 9 }, &.{.{ .sender_hosted = 92 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(@as(u32, 85), call.questionId());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, try cpz.rpc.callTargetFromWireCall(call));
        const params = try call.params();
        try expectPayloadUInt32List(params, &.{ 3, 6, 9 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 92 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireCallMessageUInt32ListInfo(root, 86, .{ .imported_cap = 5 }, &.{ 12, 24 }, &.{.{
            .descriptor = .{ .sender_promise = 93 },
            .attached_fd = 16,
        }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
        try expectPayloadUInt32List(params, &.{ 12, 24 });
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 93 }, .attached_fd = 16 }, infos[0]);
    }
}

test "rpc top-level call helpers initialize registry-backed UInt32 list payloads" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "top-call-list");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageUInt32ListFromRegistry(std.testing.allocator, root, 87, .{ .imported_cap = 5 }, &.{ 48, 96 }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try expectPayloadUInt32List(params, &.{ 48, 96 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc wire calls apply target and params state together" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(50);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x50, .method_id = 5 }, call);
    try cpz.rpc.writeCallFlagsToWire(.{ .no_promise_pipelining = true }, call);
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
    const tracked = state.callInfo(50).?;
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, tracked.target);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x50, .method_id = 5 }, tracked.method);
    try std.testing.expectEqual(@as(?bool, true), state.callMatchesMethod(50, 0x50, 5));
    try std.testing.expectEqual(@as(?bool, false), state.callMatchesMethod(50, 0x50, 6));
    try std.testing.expect(tracked.flags.no_promise_pipelining);
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

test "rpc return result cap table info can be written directly" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(73);
    try cpz.rpc.initWireReturnResultsCapTableInfo(return_, &.{
        .{ .descriptor = .{ .sender_promise = 74 }, .attached_fd = 10 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const infos = try cpz.rpc.capTableInfoFromWireReturnResults(std.testing.allocator, try message.return_());
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 74 }, .attached_fd = 10 }, infos[0]);
}

test "rpc return result helpers initialize content capabilities" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(71);
        try cpz.rpc.initWireReturnResultsCapability(return_, 0, &.{.{ .sender_hosted = 73 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const results = try (try message.return_()).results();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 73 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(72);
        try cpz.rpc.initWireReturnResultsCapabilityInfo(return_, 0, &.{.{ .descriptor = .{ .third_party_hosted = 74 }, .attached_fd = 0xff }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const results = try (try message.return_()).results();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .third_party_hosted = 74 }, .attached_fd = 0xff }, infos[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "return-capability-result");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessagePayloadCapabilityFromRegistry(std.testing.allocator, root, 73, true, false, 0, &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc return result helpers initialize struct payload descriptor info" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0x778899aa;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(75);
    try cpz.rpc.initWireReturnResultsStructInfoWith(
        return_,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .descriptor = .{ .sender_promise = 79 }, .attached_fd = 18 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x778899aa), content.getUInt32(0, 0));
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 79 }, .attached_fd = 18 }, infos[0]);
}

test "rpc return result helpers initialize data payloads" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(75);
    try cpz.rpc.initWireReturnResultsData(return_, "result bytes", &.{.{ .sender_promise = 76 }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    try std.testing.expectEqualSlices(u8, "result bytes", try (try results.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 76 }, descriptors[0]);
}

test "rpc return result helpers initialize data payloads from registries" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "return-result-data");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(76);
    try cpz.rpc.initWireReturnResultsDataFromRegistry(std.testing.allocator, return_, "registry result bytes", &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    try std.testing.expectEqualSlices(u8, "registry result bytes", try (try results.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc return result helpers initialize text payload descriptor info" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(76);
    try cpz.rpc.initWireReturnResultsTextInfo(return_, "result info text", &.{.{
        .descriptor = .{ .sender_promise = 77 },
        .attached_fd = 16,
    }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    try std.testing.expectEqualStrings("result info text", try (try results.content()).getText());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 77 }, .attached_fd = 16 }, infos[0]);
}

test "rpc return result helpers initialize text payload descriptors" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(77);
        try cpz.rpc.initWireReturnResultsText(return_, "result text", &.{.{ .sender_hosted = 78 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try std.testing.expectEqualStrings("result text", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 78 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "return-result-text");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(78);
        try cpz.rpc.initWireReturnResultsTextFromRegistry(std.testing.allocator, return_, "registry result text", &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try std.testing.expectEqualStrings("registry result text", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc return result helpers initialize UInt32 list payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(76);
        try cpz.rpc.initWireReturnResultsUInt32List(return_, &.{ 5, 10, 15 }, &.{.{ .sender_hosted = 77 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 5, 10, 15 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 77 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const return_ = try root.init_return_();
        try return_.set_answerId(77);
        try cpz.rpc.initWireReturnResultsUInt32ListInfo(return_, &.{ 20, 40 }, &.{.{
            .descriptor = .{ .sender_promise = 78 },
            .attached_fd = 17,
        }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 20, 40 });
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 78 }, .attached_fd = 17 }, infos[0]);
    }
}

test "rpc return result helpers initialize UInt32 list payloads from registries" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "return-list-cap");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const return_ = try root.init_return_();
    try return_.set_answerId(78);
    try cpz.rpc.initWireReturnResultsUInt32ListFromRegistry(std.testing.allocator, return_, &.{ 80, 160 }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    try expectPayloadUInt32List(results, &.{ 80, 160 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
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

test "rpc top-level return helpers initialize content capabilities" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessagePayloadCapability(root, 77, false, true, 0, &.{.{ .sender_hosted = 80 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expectEqual(@as(u32, 77), return_.answerId());
        try std.testing.expect(!return_.releaseParamCaps());
        try std.testing.expect(return_.noFinishNeeded());
        const results = try return_.results();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 80 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessagePayloadCapabilityInfo(root, 78, true, false, 0, &.{.{ .descriptor = .{ .sender_promise = 81 }, .attached_fd = 8 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expect(!return_.noFinishNeeded());
        const results = try return_.results();
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 81 }, .attached_fd = 8 }, infos[0]);
    }
}

test "rpc top-level return helpers initialize struct payloads" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0x33334444;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageStructWith(
        root,
        83,
        true,
        false,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .sender_hosted = 84 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 83), return_.answerId());
    try std.testing.expect(return_.releaseParamCaps());
    try std.testing.expect(!return_.noFinishNeeded());
    const results = try return_.results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x33334444), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 84 }, descriptors[0]);
}

test "rpc top-level return helpers initialize registry-backed struct payloads" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "top-return-struct");

    var value: u32 = 0x24681357;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageStructFromRegistry(
        std.testing.allocator,
        root,
        84,
        true,
        false,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &registry,
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 84), return_.answerId());
    try std.testing.expect(return_.releaseParamCaps());
    try std.testing.expect(!return_.noFinishNeeded());
    const results = try return_.results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x24681357), content.getUInt32(0, 0));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc top-level return helpers initialize struct payload descriptor info" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
        }
    };

    var value: u32 = 0x77778888;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageStructInfoWith(
        root,
        86,
        true,
        false,
        cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
        &.{.{ .descriptor = .{ .sender_promise = 87 }, .attached_fd = 12 }},
        &value,
        Fill.write,
    );

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x77778888), content.getUInt32(0, 0));
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 87 }, .attached_fd = 12 }, infos[0]);
}

test "rpc top-level return helpers initialize data payload descriptor info" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageDataInfo(root, 88, true, false, "return info bytes", &.{.{
        .descriptor = .{ .sender_promise = 89 },
        .attached_fd = 14,
    }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualSlices(u8, "return info bytes", try (try results.content()).getData());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 89 }, .attached_fd = 14 }, infos[0]);
}

test "rpc top-level return helpers initialize text payload descriptor info" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageTextInfo(root, 89, true, false, "return info text", &.{.{
        .descriptor = .{ .sender_promise = 90 },
        .attached_fd = 15,
    }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualStrings("return info text", try (try results.content()).getText());
    const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(infos);
    try std.testing.expectEqual(@as(usize, 1), infos.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 90 }, .attached_fd = 15 }, infos[0]);
}

test "rpc top-level return helpers initialize data payload descriptors" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageData(root, 89, true, false, "return bytes", &.{.{ .sender_promise = 91 }});

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualSlices(u8, "return bytes", try (try results.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 91 }, descriptors[0]);
}

test "rpc top-level return helpers initialize text payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessageText(root, 90, true, false, "return text", &.{.{ .sender_hosted = 95 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expectEqual(@as(u32, 90), return_.answerId());
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expect(!return_.noFinishNeeded());
        const results = try return_.results();
        try std.testing.expectEqualStrings("return text", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 95 }, descriptors[0]);
    }
    {
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "top-return-text");

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessageTextFromRegistry(std.testing.allocator, root, 91, true, false, "top return registry text", &registry);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try std.testing.expectEqualStrings("top return registry text", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc top-level return helpers initialize registry-backed data payloads" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "top-return-data");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageDataFromRegistry(std.testing.allocator, root, 90, true, false, "top return registry bytes", &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    try std.testing.expectEqualSlices(u8, "top return registry bytes", try (try results.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc top-level return helpers initialize UInt32 list payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessageUInt32List(root, 91, true, false, &.{ 7, 14, 21 }, &.{.{ .sender_hosted = 92 }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expectEqual(@as(u32, 91), return_.answerId());
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expect(!return_.noFinishNeeded());
        const results = try return_.results();
        try expectPayloadUInt32List(results, &.{ 7, 14, 21 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 92 }, descriptors[0]);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnMessageUInt32ListInfo(root, 92, false, true, &.{ 28, 56 }, &.{.{
            .descriptor = .{ .sender_promise = 93 },
            .attached_fd = 18,
        }});

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expect(!return_.releaseParamCaps());
        try std.testing.expect(return_.noFinishNeeded());
        const results = try return_.results();
        try expectPayloadUInt32List(results, &.{ 28, 56 });
        const infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(infos);
        try std.testing.expectEqual(@as(usize, 1), infos.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 93 }, .attached_fd = 18 }, infos[0]);
    }
}

test "rpc top-level return helpers initialize registry-backed UInt32 list payloads" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "top-return-list");

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageUInt32ListFromRegistry(std.testing.allocator, root, 93, true, false, &.{ 112, 224 }, &registry);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
    try expectPayloadUInt32List(results, &.{ 112, 224 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
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
        try exception.set_trace("stack line 1\nstack line 2");

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        const info = switch (outcome) {
            .exception => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqualStrings("network down", info.reason.?);
        try std.testing.expectEqual(@as(u16, 2), info.type_raw);
        try std.testing.expectEqualStrings("stack line 1\nstack line 2", info.trace.?);

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
        .trace = "retry later",
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
    try std.testing.expectEqualStrings("retry later", info.trace.?);
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

test "rpc typed call dispatchers forward resolved capability and empty returns" {
    const CapabilityHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !u32 {
            seen_question.* = call.questionId();
            return 0xffff_ffff;
        }
    };
    const EmptyHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !void {
            seen_question.* = call.questionId();
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 620 });
        try state.resolveImportTo(620, .{ .sender_hosted = 621 });
        try state.applyCapDescriptor(.{ .sender_hosted = 621 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(620);
        const target = try call.init_target();
        try target.set_importedCap(620);
        try cpz.rpc.initWireCallParamsText(call, "capability forward", &.{.{ .sender_hosted = 622 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningCapabilityForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &seen_question,
                CapabilityHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 621 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("capability forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 630 });
        try state.resolveImportTo(630, .{ .sender_hosted = 631 });
        try state.applyCapDescriptor(.{ .sender_hosted = 631 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(630);
        const target = try call.init_target();
        try target.set_importedCap(630);
        try cpz.rpc.initWireCallParamsText(call, "empty forward", &.{.{ .sender_hosted = 632 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningEmptyForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &seen_question,
                EmptyHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 631 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("empty forward", try (try (try forwarded.params()).content()).getText());
    }
}

test "rpc typed call dispatchers build non-capability payload returns" {
    const TextHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return if (call.questionId() == 40) "typed text" else error.TestUnexpectedResult;
        }
    };
    const ListHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u32 {
            return if (call.questionId() == 41) &.{ 7, 8, 9 } else error.TestUnexpectedResult;
        }
    };
    const DataHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return if (call.questionId() == 42) "typed data" else error.TestUnexpectedResult;
        }
    };

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(40);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningText(&state, std.testing.allocator, response_root, try request.call(), &ignored, TextHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try response_reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqualStrings("typed text", try (try (try return_.results()).content()).getText());
    }
    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(42);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningData(&state, std.testing.allocator, response_root, try request.call(), &ignored, DataHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try response_reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqualSlices(u8, "typed data", try (try (try return_.results()).content()).getData());
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(41);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningUInt32List(&state, std.testing.allocator, response_root, try request.call(), &ignored, ListHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 7, 8, 9 });
    }
}

test "rpc typed call dispatchers build registry-backed payload returns" {
    const TextHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return if (call.questionId() == 46) "registry typed text" else error.TestUnexpectedResult;
        }
    };
    const DataHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return if (call.questionId() == 47) "registry typed data" else error.TestUnexpectedResult;
        }
    };
    const ListHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u32 {
            return if (call.questionId() == 48) &.{ 10, 20, 30 } else error.TestUnexpectedResult;
        }
    };

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(46);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "typed-text-result");

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningTextFromRegistry(&state, std.testing.allocator, response_root, try request.call(), &registry, &ignored, TextHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const results = try (try response.return_()).results();
        try std.testing.expectEqualStrings("registry typed text", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
        try state.applyWireMessage(std.testing.allocator, response);
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(47);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "typed-data-result");

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningDataFromRegistry(&state, std.testing.allocator, response_root, try request.call(), &registry, &ignored, DataHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const results = try (try response.return_()).results();
        try std.testing.expectEqualSlices(u8, "registry typed data", try (try results.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(48);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "typed-list-result");

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningUInt32ListFromRegistry(&state, std.testing.allocator, response_root, try request.call(), &registry, &ignored, ListHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const results = try (try response.return_()).results();
        try expectPayloadUInt32List(results, &.{ 10, 20, 30 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc typed call dispatchers build descriptor-info payload returns" {
    const TextHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return if (call.questionId() == 49) "info typed text" else error.TestUnexpectedResult;
        }
    };
    const DataHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return if (call.questionId() == 50) "info typed data" else error.TestUnexpectedResult;
        }
    };
    const ListHandler = struct {
        fn handle(_: *u32, call: anytype) ![]const u32 {
            return if (call.questionId() == 51) &.{ 1, 3, 5 } else error.TestUnexpectedResult;
        }
    };

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(49);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 108 }, .attached_fd = 10 }};
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningTextInfo(&state, std.testing.allocator, response_root, try request.call(), infos[0..], &ignored, TextHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try std.testing.expectEqualStrings("info typed text", try (try results.content()).getText());
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(50);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_hosted = 109 }, .attached_fd = 11 }};
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningDataInfo(&state, std.testing.allocator, response_root, try request.call(), infos[0..], &ignored, DataHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try std.testing.expectEqualSlices(u8, "info typed data", try (try results.content()).getData());
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(51);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 110 }, .attached_fd = 12 }};
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallReturningUInt32ListInfo(&state, std.testing.allocator, response_root, try request.call(), infos[0..], &ignored, ListHandler.handle);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 1, 3, 5 });
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }
}

test "rpc typed call dispatchers build struct payload returns" {
    const Fill = struct {
        fn write(context: *const u32, call: anytype, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, context.* + call.questionId(), 0);
        }
    };

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(43);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var value: u32 = 0x1000;
        try cpz.rpc.dispatchCallReturningStructWith(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &.{.{ .sender_hosted = 106 }},
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expect(!return_.noFinishNeeded());
        const results = try return_.results();
        const content = try (try results.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x1000 + 43), content.getUInt32(0, 0));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 106 }, descriptors[0]);
        try state.applyWireMessage(std.testing.allocator, response);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(43));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(106));
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(44);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var value: u32 = 0x2000;
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 107 }, .attached_fd = 9 }};
        try cpz.rpc.dispatchCallReturningStructInfoWith(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            infos[0..],
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        const results = try return_.results();
        const content = try (try results.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x2000 + 44), content.getUInt32(0, 0));
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(45);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "typed-struct-result");

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);
        var value: u32 = 0x3000;
        try cpz.rpc.dispatchCallReturningStructFromRegistry(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &registry,
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        const results = try return_.results();
        const content = try (try results.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x3000 + 45), content.getUInt32(0, 0));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
        try state.applyWireMessage(std.testing.allocator, response);
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    }
}

test "rpc typed call dispatchers forward resolved text returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) ![]const u8 {
            seen_question.* = call.questionId();
            return "should not run";
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 500 });
        try state.resolveImportTo(500, .{ .sender_hosted = 501 });
        try state.applyCapDescriptor(.{ .sender_hosted = 501 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(500);
        const target = try call.init_target();
        try target.set_importedCap(500);
        try cpz.rpc.initWireCallParamsText(call, "typed text forward", &.{.{ .sender_hosted = 502 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningTextForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &.{.{ .sender_hosted = 503 }},
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 501 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("typed text forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 510 });
        try state.resolveImportTo(510, .{ .sender_hosted = 511 });
        try state.applyCapDescriptor(.{ .sender_hosted = 511 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(510);
        const target = try call.init_target();
        try target.set_importedCap(510);
        try cpz.rpc.initWireCallParamsText(call, "typed text info forward", &.{.{ .sender_hosted = 512 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 513 }, .attached_fd = 29 }};
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningTextInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                infos[0..],
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 511 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("typed text info forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 520 });
        try state.resolveImportTo(520, .{ .sender_hosted = 521 });
        try state.applyCapDescriptor(.{ .sender_hosted = 521 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(520);
        const target = try call.init_target();
        try target.set_importedCap(520);
        try cpz.rpc.initWireCallParamsText(call, "typed text registry forward", &.{.{ .sender_hosted = 522 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-typed-text-forward-registry");
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningTextFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &registry,
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 521 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("typed text registry forward", try (try (try forwarded.params()).content()).getText());
    }
}

test "rpc typed call dispatchers forward resolved data returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) ![]const u8 {
            seen_question.* = call.questionId();
            return "should not run";
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 530 });
        try state.resolveImportTo(530, .{ .sender_hosted = 531 });
        try state.applyCapDescriptor(.{ .sender_hosted = 531 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(530);
        const target = try call.init_target();
        try target.set_importedCap(530);
        try cpz.rpc.initWireCallParamsData(call, "typed data forward", &.{.{ .sender_hosted = 532 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningDataForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &.{.{ .sender_hosted = 533 }},
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 531 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualSlices(u8, "typed data forward", try (try (try forwarded.params()).content()).getData());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 540 });
        try state.resolveImportTo(540, .{ .sender_hosted = 541 });
        try state.applyCapDescriptor(.{ .sender_hosted = 541 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(540);
        const target = try call.init_target();
        try target.set_importedCap(540);
        try cpz.rpc.initWireCallParamsData(call, "typed data info forward", &.{.{ .sender_hosted = 542 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 543 }, .attached_fd = 30 }};
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningDataInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                infos[0..],
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 541 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualSlices(u8, "typed data info forward", try (try (try forwarded.params()).content()).getData());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 550 });
        try state.resolveImportTo(550, .{ .sender_hosted = 551 });
        try state.applyCapDescriptor(.{ .sender_hosted = 551 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(550);
        const target = try call.init_target();
        try target.set_importedCap(550);
        try cpz.rpc.initWireCallParamsData(call, "typed data registry forward", &.{.{ .sender_hosted = 552 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-typed-data-forward-registry");
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningDataFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &registry,
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 551 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualSlices(u8, "typed data registry forward", try (try (try forwarded.params()).content()).getData());
    }
}

test "rpc typed call dispatchers forward resolved uint32-list returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) ![]const u32 {
            seen_question.* = call.questionId();
            return &.{999};
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 560 });
        try state.resolveImportTo(560, .{ .sender_hosted = 561 });
        try state.applyCapDescriptor(.{ .sender_hosted = 561 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(560);
        const target = try call.init_target();
        try target.set_importedCap(560);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 56, 60 }, &.{.{ .sender_hosted = 562 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningUInt32ListForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &.{.{ .sender_hosted = 563 }},
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 561 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 56, 60 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 570 });
        try state.resolveImportTo(570, .{ .sender_hosted = 571 });
        try state.applyCapDescriptor(.{ .sender_hosted = 571 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(570);
        const target = try call.init_target();
        try target.set_importedCap(570);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 57, 70 }, &.{.{ .sender_hosted = 572 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 573 }, .attached_fd = 31 }};
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningUInt32ListInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                infos[0..],
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 571 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 57, 70 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 580 });
        try state.resolveImportTo(580, .{ .sender_hosted = 581 });
        try state.applyCapDescriptor(.{ .sender_hosted = 581 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(580);
        const target = try call.init_target();
        try target.set_importedCap(580);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 58, 80 }, &.{.{ .sender_hosted = 582 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-typed-list-forward-registry");
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningUInt32ListFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                &registry,
                &seen_question,
                Handler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 581 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 58, 80 });
    }
}

test "rpc typed call dispatchers forward resolved struct returns" {
    const Handler = struct {
        fn write(value: *u32, call: anytype, builder: cpz.StructBuilder) !void {
            value.* = call.questionId();
            try builder.setUInt32(0, value.*, 0);
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 590 });
        try state.resolveImportTo(590, .{ .sender_hosted = 591 });
        try state.applyCapDescriptor(.{ .sender_hosted = 591 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(590);
        const target = try call.init_target();
        try target.set_importedCap(590);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 59, 90 }, &.{.{ .sender_hosted = 592 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var value: u32 = 0x9000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningStructForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                &.{.{ .sender_hosted = 593 }},
                &value,
                Handler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0x9000), value);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 591 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 59, 90 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 600 });
        try state.resolveImportTo(600, .{ .sender_hosted = 601 });
        try state.applyCapDescriptor(.{ .sender_hosted = 601 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(600);
        const target = try call.init_target();
        try target.set_importedCap(600);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 60, 100 }, &.{.{ .sender_hosted = 602 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 603 }, .attached_fd = 32 }};
        var value: u32 = 0xa000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningStructInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                infos[0..],
                &value,
                Handler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0xa000), value);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 601 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 60, 100 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 610 });
        try state.resolveImportTo(610, .{ .sender_hosted = 611 });
        try state.applyCapDescriptor(.{ .sender_hosted = 611 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(610);
        const target = try call.init_target();
        try target.set_importedCap(610);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 61, 110 }, &.{.{ .sender_hosted = 612 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-typed-struct-forward-registry");
        var value: u32 = 0xb000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallReturningStructFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                &registry,
                &value,
                Handler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0xb000), value);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 611 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 61, 110 });
    }
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

test "rpc generic call dispatcher builds non-capability payload returns" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .{ .text = "handler text" };
        }
    };

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(39);
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
    try std.testing.expectEqual(@as(u32, 39), seen_question);

    var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const return_ = try response.return_();
    try std.testing.expect(return_.releaseParamCaps());
    try std.testing.expect(!return_.noFinishNeeded());
    try std.testing.expectEqualStrings("handler text", try (try (try return_.results()).content()).getText());
    try state.applyWireMessage(std.testing.allocator, response);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(39));
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

test "rpc method-aware call dispatcher filters methods" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(27);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 1 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try cpz.rpc.dispatchCallMethod(&state, std.testing.allocator, response_root, try request.call(), .{ .interface_id = 0xabc, .method_id = 1 }, &seen_question, Handler.handle);
        try std.testing.expectEqual(@as(u32, 27), seen_question);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results, try cpz.rpc.returnOutcomeFromWireReturn(try response.return_()));
    }
    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(28);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 2 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try cpz.rpc.dispatchCallMethod(&state, std.testing.allocator, response_root, try request.call(), .{ .interface_id = 0xabc, .method_id = 1 }, &seen_question, Handler.handle);
        try std.testing.expectEqual(@as(u32, 0), seen_question);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try response.return_());
        const exception = switch (outcome) {
            .exception => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(@as(u16, 3), exception.type_raw);
    }
}

test "rpc method-aware call dispatcher builds capability and empty returns" {
    const CapabilityHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !u32 {
            seen_question.* = call.questionId();
            return call.questionId() + 120;
        }
    };
    const EmptyHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !void {
            seen_question.* = call.questionId();
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(65);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 9 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningCapability(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 9 },
            &seen_question,
            CapabilityHandler.handle,
        );
        try std.testing.expectEqual(@as(u32, 65), seen_question);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try expectReturnCapabilityResult(response, 185);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(66);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 10 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningEmpty(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 10 },
            &seen_question,
            EmptyHandler.handle,
        );
        try std.testing.expectEqual(@as(u32, 66), seen_question);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try response_reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expect(return_.noFinishNeeded());
    }
}

test "rpc method-aware typed dispatch outcomes flag resolved targets" {
    const CapabilityHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !u32 {
            seen_question.* = call.questionId();
            return call.questionId() + 120;
        }
    };
    const EmptyHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !void {
            seen_question.* = call.questionId();
        }
    };
    const TextOutcomeHandler = struct {
        fn handle(seen_question: *u32, call: anytype) ![]const u8 {
            seen_question.* = call.questionId();
            return "should not run";
        }
    };
    const DataOutcomeHandler = struct {
        fn handle(seen_question: *u32, call: anytype) ![]const u8 {
            seen_question.* = call.questionId();
            return "should not run";
        }
    };
    const ListOutcomeHandler = struct {
        fn handle(seen_question: *u32, call: anytype) ![]const u32 {
            seen_question.* = call.questionId();
            return &.{99};
        }
    };
    const StructOutcomeHandler = struct {
        fn write(value: *u32, _: anytype, _: cpz.StructBuilder) !void {
            value.* = 0xffff_ffff;
        }
    };

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 420 });
        try state.resolveImportTo(420, .{ .sender_hosted = 421 });
        try state.applyCapDescriptor(.{ .sender_hosted = 421 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(420);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 9 }, call);
        const target = try call.init_target();
        try target.set_importedCap(420);
        _ = try call.init_params();
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningCapabilityOutcome(
                &state,
                std.testing.allocator,
                response_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 9 },
                &seen_question,
                CapabilityHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(420));
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 425 });
        try state.resolveImportTo(425, .{ .sender_hosted = 426 });
        try state.applyCapDescriptor(.{ .sender_hosted = 426 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(425);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(425);
        _ = try call.init_params();
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningTextOutcome(
                &state,
                std.testing.allocator,
                response_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 6 },
                &.{.{ .sender_hosted = 427 }},
                &seen_question,
                TextOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 428 });
        try state.resolveImportTo(428, .{ .sender_hosted = 429 });
        try state.applyCapDescriptor(.{ .sender_hosted = 429 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(428);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(428);
        _ = try call.init_params();
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningDataOutcome(
                &state,
                std.testing.allocator,
                response_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 7 },
                &.{.{ .sender_hosted = 430 }},
                &seen_question,
                DataOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 432 });
        try state.resolveImportTo(432, .{ .sender_hosted = 433 });
        try state.applyCapDescriptor(.{ .sender_hosted = 433 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(432);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(432);
        _ = try call.init_params();
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningUInt32ListOutcome(
                &state,
                std.testing.allocator,
                response_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 8 },
                &.{.{ .sender_hosted = 434 }},
                &seen_question,
                ListOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 446 });
        try state.resolveImportTo(446, .{ .sender_hosted = 447 });
        try state.applyCapDescriptor(.{ .sender_hosted = 447 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(446);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(446);
        _ = try call.init_params();
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var value: u32 = 0x8000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningStructOutcome(
                &state,
                std.testing.allocator,
                response_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 4 },
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                &.{.{ .sender_hosted = 448 }},
                &value,
                StructOutcomeHandler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0x8000), value);
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 430 });
        try state.resolveImportTo(430, .{ .sender_hosted = 431 });
        try state.applyCapDescriptor(.{ .sender_hosted = 431 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(430);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 10 }, call);
        const target = try call.init_target();
        try target.set_importedCap(430);
        try cpz.rpc.initWireCallParamsText(call, "empty forward", &.{.{ .sender_hosted = 432 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningEmptyForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 10 },
                &seen_question,
                EmptyHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 431 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("empty forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 435 });
        try state.resolveImportTo(435, .{ .sender_hosted = 436 });
        try state.applyCapDescriptor(.{ .sender_hosted = 436 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(435);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(435);
        try cpz.rpc.initWireCallParamsText(call, "text forward", &.{.{ .sender_hosted = 437 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningTextForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 6 },
                &.{.{ .sender_hosted = 438 }},
                &seen_question,
                TextOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 436 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("text forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 437 });
        try state.resolveImportTo(437, .{ .sender_hosted = 438 });
        try state.applyCapDescriptor(.{ .sender_hosted = 438 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(437);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(437);
        try cpz.rpc.initWireCallParamsText(call, "text info forward", &.{.{ .sender_hosted = 439 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 440 }, .attached_fd = 25 }};
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningTextInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 6 },
                infos[0..],
                &seen_question,
                TextOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 438 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("text info forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 438 });
        try state.resolveImportTo(438, .{ .sender_hosted = 439 });
        try state.applyCapDescriptor(.{ .sender_hosted = 439 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(438);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(438);
        try cpz.rpc.initWireCallParamsData(call, "data forward", &.{.{ .sender_hosted = 440 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningDataForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 7 },
                &.{.{ .sender_hosted = 441 }},
                &seen_question,
                DataOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 439 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualSlices(u8, "data forward", try (try (try forwarded.params()).content()).getData());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 444 });
        try state.resolveImportTo(444, .{ .sender_hosted = 445 });
        try state.applyCapDescriptor(.{ .sender_hosted = 445 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(444);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(444);
        try cpz.rpc.initWireCallParamsData(call, "data info forward", &.{.{ .sender_hosted = 446 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 447 }, .attached_fd = 26 }};
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningDataInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 7 },
                infos[0..],
                &seen_question,
                DataOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 445 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualSlices(u8, "data info forward", try (try (try forwarded.params()).content()).getData());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 441 });
        try state.resolveImportTo(441, .{ .sender_hosted = 442 });
        try state.applyCapDescriptor(.{ .sender_hosted = 442 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(441);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(441);
        try cpz.rpc.initWireCallParamsText(call, "text registry forward", &.{.{ .sender_hosted = 443 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-text-forward-registry");
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningTextFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 6 },
                &registry,
                &seen_question,
                TextOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 442 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("text registry forward", try (try (try forwarded.params()).content()).getText());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 448 });
        try state.resolveImportTo(448, .{ .sender_hosted = 449 });
        try state.applyCapDescriptor(.{ .sender_hosted = 449 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(448);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(448);
        try cpz.rpc.initWireCallParamsData(call, "data registry forward", &.{.{ .sender_hosted = 450 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-data-forward-registry");
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningDataFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 7 },
                &registry,
                &seen_question,
                DataOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 449 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualSlices(u8, "data registry forward", try (try (try forwarded.params()).content()).getData());
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 442 });
        try state.resolveImportTo(442, .{ .sender_hosted = 443 });
        try state.applyCapDescriptor(.{ .sender_hosted = 443 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(442);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(442);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 42, 24 }, &.{.{ .sender_hosted = 444 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningUInt32ListForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 8 },
                &.{.{ .sender_hosted = 445 }},
                &seen_question,
                ListOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 443 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 42, 24 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 446 });
        try state.resolveImportTo(446, .{ .sender_hosted = 447 });
        try state.applyCapDescriptor(.{ .sender_hosted = 447 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(446);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(446);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 44, 66 }, &.{.{ .sender_hosted = 448 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 449 }, .attached_fd = 27 }};
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningUInt32ListInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 8 },
                infos[0..],
                &seen_question,
                ListOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 447 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 44, 66 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 450 });
        try state.resolveImportTo(450, .{ .sender_hosted = 451 });
        try state.applyCapDescriptor(.{ .sender_hosted = 451 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(450);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(450);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 4, 50 }, &.{.{ .sender_hosted = 452 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var value: u32 = 0x9000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningStructForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 4 },
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                &.{.{ .sender_hosted = 453 }},
                &value,
                StructOutcomeHandler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0x9000), value);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 451 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 4, 50 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 458 });
        try state.resolveImportTo(458, .{ .sender_hosted = 459 });
        try state.applyCapDescriptor(.{ .sender_hosted = 459 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(458);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(458);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 4, 58 }, &.{.{ .sender_hosted = 460 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 461 }, .attached_fd = 28 }};
        var value: u32 = 0xa000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningStructInfoForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 4 },
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                infos[0..],
                &value,
                StructOutcomeHandler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0xa000), value);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 459 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 4, 58 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 454 });
        try state.resolveImportTo(454, .{ .sender_hosted = 455 });
        try state.applyCapDescriptor(.{ .sender_hosted = 455 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(454);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(454);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 45, 54 }, &.{.{ .sender_hosted = 456 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-list-forward-registry");
        var seen_question: u32 = 0;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningUInt32ListFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 8 },
                &registry,
                &seen_question,
                ListOutcomeHandler.handle,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0), seen_question);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 455 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 45, 54 });
    }

    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.applyCapDescriptor(.{ .sender_promise = 462 });
        try state.resolveImportTo(462, .{ .sender_hosted = 463 });
        try state.applyCapDescriptor(.{ .sender_hosted = 463 });

        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(462);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(462);
        try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 4, 62 }, &.{.{ .sender_hosted = 464 }});
        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());

        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer forward_builder.deinit();
        const forward_root = try generated.Message.initRootTyped(&forward_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "unused-struct-forward-registry");
        var value: u32 = 0xb000;
        try std.testing.expectEqual(
            cpz.rpc.WireDispatchOutcome.forward_required,
            try cpz.rpc.dispatchCallMethodReturningStructFromRegistryForwardingOutcome(
                &state,
                std.testing.allocator,
                response_root,
                forward_root,
                try request.call(),
                .{ .interface_id = 0xabc, .method_id = 4 },
                cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
                &registry,
                &value,
                StructOutcomeHandler.write,
            ),
        );
        try std.testing.expectEqual(@as(u32, 0xb000), value);
        var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 463 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 4, 62 });
    }
}

test "rpc method-aware call dispatcher builds text payload returns" {
    const Handler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return switch (call.questionId()) {
                56 => "method text",
                57 => "method text info",
                58 => "method text registry",
                else => error.TestUnexpectedResult,
            };
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(56);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningText(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 6 },
            &.{.{ .sender_hosted = 114 }},
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try response_reader.getRoot()).return_();
        const results = try return_.results();
        try std.testing.expectEqualStrings("method text", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 114 }, descriptors[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(57);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 115 }, .attached_fd = 22 }};
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningTextInfo(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 6 },
            infos[0..],
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try std.testing.expectEqualStrings("method text info", try (try results.content()).getText());
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(58);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 6 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "method-text-registry");
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningTextFromRegistry(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 6 },
            &registry,
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try std.testing.expectEqualStrings("method text registry", try (try results.content()).getText());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc method-aware call dispatcher builds data payload returns" {
    const Handler = struct {
        fn handle(_: *u32, call: anytype) ![]const u8 {
            return switch (call.questionId()) {
                59 => "method data",
                60 => "method data info",
                61 => "method data registry",
                else => error.TestUnexpectedResult,
            };
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(59);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningData(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 7 },
            &.{.{ .sender_hosted = 116 }},
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try response_reader.getRoot()).return_();
        const results = try return_.results();
        try std.testing.expectEqualSlices(u8, "method data", try (try results.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 116 }, descriptors[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(60);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 117 }, .attached_fd = 23 }};
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningDataInfo(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 7 },
            infos[0..],
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try std.testing.expectEqualSlices(u8, "method data info", try (try results.content()).getData());
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(61);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 7 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "method-data-registry");
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningDataFromRegistry(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 7 },
            &registry,
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try std.testing.expectEqualSlices(u8, "method data registry", try (try results.content()).getData());
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc method-aware call dispatcher builds list payload returns" {
    const Handler = struct {
        fn handle(_: *u32, call: anytype) ![]const u32 {
            return switch (call.questionId()) {
                62 => &.{ 6, 2 },
                63 => &.{ 6, 3 },
                64 => &.{ 6, 4 },
                else => error.TestUnexpectedResult,
            };
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(62);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningUInt32List(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 8 },
            &.{.{ .sender_hosted = 118 }},
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 6, 2 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 118 }, descriptors[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(63);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 119 }, .attached_fd = 24 }};
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningUInt32ListInfo(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 8 },
            infos[0..],
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 6, 3 });
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(64);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 8 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "method-list-registry");
        var ignored: u32 = 0;
        try cpz.rpc.dispatchCallMethodReturningUInt32ListFromRegistry(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 8 },
            &registry,
            &ignored,
            Handler.handle,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try response_reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 6, 4 });
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }
}

test "rpc method-aware call dispatcher builds struct payload returns" {
    const Fill = struct {
        fn write(context: *const u32, call: anytype, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, context.* + call.questionId(), 0);
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(52);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var value: u32 = 0x4000;
        try cpz.rpc.dispatchCallMethodReturningStructWith(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 4 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &.{.{ .sender_hosted = 111 }},
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        const results = try return_.results();
        const content = try (try results.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x4000 + 52), content.getUInt32(0, 0));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 111 }, descriptors[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(54);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var value: u32 = 0x6000;
        const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 113 }, .attached_fd = 21 }};
        try cpz.rpc.dispatchCallMethodReturningStructInfoWith(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 4 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            infos[0..],
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        const results = try return_.results();
        const content = try (try results.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x6000 + 54), content.getUInt32(0, 0));
        const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(decoded_infos);
        try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
        try std.testing.expectEqual(infos[0], decoded_infos[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(55);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 4 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var registry: cpz.CapabilityRegistry([]const u8) = .{};
        defer registry.deinit(std.testing.allocator);
        _ = try registry.register(std.testing.allocator, "method-struct-registry");
        var value: u32 = 0x7000;
        try cpz.rpc.dispatchCallMethodReturningStructFromRegistry(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 4 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &registry,
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const results = try (try response.return_()).results();
        const content = try (try results.content()).getStruct(null);
        try std.testing.expectEqual(@as(u32, 0x7000 + 55), content.getUInt32(0, 0));
        const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
    }

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(53);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 5 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var value: u32 = 0x5000;
        try cpz.rpc.dispatchCallMethodReturningStructWith(
            &state,
            std.testing.allocator,
            response_root,
            try request.call(),
            .{ .interface_id = 0xabc, .method_id = 4 },
            cpz.StructSize{ .data_words = 1, .pointer_count = 0 },
            &.{.{ .sender_hosted = 112 }},
            &value,
            Fill.write,
        );

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try response.return_());
        const exception = switch (outcome) {
            .exception => |value_exception| value_exception,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqualStrings("unimplemented method", exception.reason.?);
    }
}

test "rpc method table dispatcher selects matching handlers" {
    const Context = struct {
        selected: u32 = 0,
    };
    const Handlers = struct {
        fn first(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId() + 100;
            return .empty;
        }

        fn second(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId() + 200;
            return .{ .capability = 106 };
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 1 }, .handler = Handlers.first },
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 2 }, .handler = Handlers.second },
    };
    const duplicate_entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 1 }, .handler = Handlers.first },
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 1 }, .handler = Handlers.second },
    };
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.validateCallMethodEntries(duplicate_entries));

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(29);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 2 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var context: Context = .{};
        try cpz.rpc.dispatchCallMethods(&state, std.testing.allocator, response_root, try request.call(), &context, entries);
        try std.testing.expectEqual(@as(u32, 229), context.selected);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 106 }, descriptors[0]);
    }
    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(30);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xabc, .method_id = 3 }, call);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        var context: Context = .{};
        try cpz.rpc.dispatchCallMethods(&state, std.testing.allocator, response_root, try request.call(), &context, entries);
        try std.testing.expectEqual(@as(u32, 0), context.selected);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try response.return_());
        const exception = switch (outcome) {
            .exception => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(@as(u16, 3), exception.type_raw);
    }
}

test "rpc call dispatch outcomes flag resolved targets for forwarding" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 140 });
    try state.resolveImportTo(140, .{ .sender_hosted = 141 });
    try state.applyCapDescriptor(.{ .sender_hosted = 141 });

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(140);
    const target = try call.init_target();
    try target.set_importedCap(140);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var seen_question: u32 = 0;
    try std.testing.expectEqual(
        cpz.rpc.WireDispatchOutcome.forward_required,
        try cpz.rpc.dispatchCallOutcome(&state, std.testing.allocator, response_root, try request.call(), &seen_question, Handler.handle),
    );
    try std.testing.expectEqual(@as(u32, 0), seen_question);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(140));
    try std.testing.expectEqual(@as(usize, 1), state.callInfoCount());
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 141 },
        (try state.wireCallTargetTransitiveForwardTarget(try request.call())).?,
    );
}

test "rpc method dispatch outcomes flag resolved targets for forwarding" {
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x5555, .method_id = 5 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 150 });
    try state.resolveImportTo(150, .{ .sender_hosted = 151 });
    try state.applyCapDescriptor(.{ .sender_hosted = 151 });

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(150);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x5555, .method_id = 5 }, call);
    const target = try call.init_target();
    try target.set_importedCap(150);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var context: Context = .{};
    try std.testing.expectEqual(
        cpz.rpc.WireDispatchOutcome.forward_required,
        try cpz.rpc.dispatchCallMethodsOutcome(&state, std.testing.allocator, response_root, try request.call(), &context, entries),
    );
    try std.testing.expectEqual(@as(u32, 0), context.selected);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(150));
    try std.testing.expectEqual(@as(usize, 1), state.callInfoCount());
}

test "rpc single-message dispatcher supports method tables" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 3000;
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
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xdef, .method_id = 1 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(32);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0xdef, .method_id = 1 }, call);
    const target = try call.init_target();
    try target.set_importedCap(5);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, try cpz.rpc.dispatchWireMessageMethodsOutcome(
        &state,
        std.testing.allocator,
        response_root,
        request,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &context,
        entries,
    ));
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 32), context.selected);
}

test "rpc single-message dispatcher reports resolved call forwarding" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId();
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 160 });
    try state.resolveImportTo(160, .{ .sender_hosted = 161 });
    try state.applyCapDescriptor(.{ .sender_hosted = 161 });

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(160);
    const target = try call.init_target();
    try target.set_importedCap(160);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);

    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    const outcome = try cpz.rpc.dispatchWireMessageOutcome(
        &state,
        std.testing.allocator,
        response_root,
        request,
        &bootstrap_seen,
        BootstrapHandler.handle,
        &call_seen,
        CallHandler.handle,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, outcome);
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(160));
    try std.testing.expectEqual(@as(usize, 1), state.callInfoCount());
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 161 },
        (try state.wireCallTargetTransitiveForwardTarget(try request.call())).?,
    );
}

test "rpc dispatch planner previews dense output slots without mutating state" {
    const Handler = struct {
        fn handle(_: *u32, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x1234, .method_id = 1 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 600 });
    try state.resolveImportTo(600, .{ .sender_hosted = 601 });
    try state.applyCapDescriptor(.{ .sender_hosted = 601 });

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 70);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var local_call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer local_call_builder.deinit();
    const local_call_root = try generated.Message.initRootTyped(&local_call_builder);
    const local_call = try local_call_root.init_call();
    try local_call.set_questionId(71);
    const local_target = try local_call.init_target();
    try local_target.set_importedCap(5);
    _ = try local_call.init_params();
    var local_call_reader = cpz.MessageReader.init(try local_call_builder.segmentsConst(), .{});
    const local_call_message = generated.Message.fromReader(try local_call_reader.getRoot());

    var forward_call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_call_builder.deinit();
    const forward_call_root = try generated.Message.initRootTyped(&forward_call_builder);
    const forward_call = try forward_call_root.init_call();
    try forward_call.set_questionId(72);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x1234, .method_id = 1 }, forward_call);
    const forward_target = try forward_call.init_target();
    try forward_target.set_importedCap(600);
    _ = try forward_call.init_params();
    var forward_call_reader = cpz.MessageReader.init(try forward_call_builder.segmentsConst(), .{});
    const forward_call_message = generated.Message.fromReader(try forward_call_reader.getRoot());

    var finish_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer finish_builder.deinit();
    const finish_root = try generated.Message.initRootTyped(&finish_builder);
    try cpz.rpc.initWireFinishMessage(finish_root, .{ .question_id = 73, .release_result_caps = false });
    var finish_reader = cpz.MessageReader.init(try finish_builder.segmentsConst(), .{});
    const finish_message = generated.Message.fromReader(try finish_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, local_call_message, forward_call_message, finish_message };
    const stats = try cpz.rpc.planWireMessagesDispatch(&state, requests[0..]);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{
        .response_initialized = 2,
        .forward_required = 1,
        .state_applied = 1,
    }, stats);
    try std.testing.expectEqual(@as(usize, 2), stats.denseResponseSlots());
    try std.testing.expectEqual(@as(usize, 1), stats.denseForwardSlots());
    try std.testing.expectEqual(@as(usize, 3), stats.denseOutputSlots());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, stats.denseResponseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, stats.denseForwardRange());
    try std.testing.expectEqual(@as(usize, 2), stats.denseResponseRange().len());
    try std.testing.expectEqual(@as(usize, 1), stats.denseForwardRange().len());
    try stats.denseForwardRange().validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, stats.denseForwardRange().validateCapacity(2));
    try stats.validateDenseResponseCapacity(2);
    try stats.validateDenseForwardCapacity(1);
    try stats.validateDenseOutputCapacity(2, 1);
    try stats.validateDenseOutputBuilders(requests[0..2], requests[0..1]);
    try stats.validateUnifiedDenseOutputCapacity(3);
    try stats.validateUnifiedDenseOutputBuilders(requests[0..3]);
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseResponseCapacity(1));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseForwardCapacity(0));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseOutputCapacity(2, 0));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseOutputBuilders(requests[0..1], requests[0..1]));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseOutputBuilders(requests[0..2], requests[0..0]));
    try std.testing.expectError(error.InvalidTransition, stats.validateUnifiedDenseOutputCapacity(2));
    try std.testing.expectError(error.InvalidTransition, stats.validateUnifiedDenseOutputBuilders(requests[0..2]));
    try std.testing.expect(stats.initializedAnyResponse());
    try std.testing.expect(stats.requiredAnyForward());
    try std.testing.expect(stats.appliedAnyState());

    const method_stats = try cpz.rpc.planWireMessagesMethodsDispatch(&state, requests[0..], entries);
    try std.testing.expectEqual(stats, method_stats);

    const turn_plan = try cpz.rpc.planRpcTurn(&state, requests[0..]);
    try std.testing.expectEqual(stats, turn_plan.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, turn_plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), turn_plan.responseMessages());
    try std.testing.expectEqual(@as(usize, 1), turn_plan.forwardedMessages());
    try std.testing.expectEqual(@as(usize, 1), turn_plan.stateOnlyMessages());
    try std.testing.expectEqual(@as(usize, 3), turn_plan.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 0), turn_plan.disembargoMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, turn_plan.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, turn_plan.forwardedMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 3, .end = 3 }, turn_plan.disembargoMessageRange());
    try turn_plan.validateOutputCapacity(2, 1);
    try turn_plan.validateUnifiedOutputCapacity(3);
    try turn_plan.validateUnifiedOutputBuilders(requests[0..3]);
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateOutputCapacity(1, 1));
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateOutputCapacity(2, 0));
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateUnifiedOutputCapacity(2));
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateUnifiedOutputBuilders(requests[0..2]));
    try std.testing.expectEqual(turn_plan, try cpz.rpc.planRpcTurnMethods(&state, requests[0..], entries));

    try std.testing.expect(state.questionState(70) == null);
    try std.testing.expect(state.questionState(71) == null);
    try std.testing.expectEqual(@as(usize, 0), state.callInfoCount());

    {
        var embargo_state = cpz.rpc.State.init(std.testing.allocator);
        defer embargo_state.deinit();
        var accept_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer accept_builder.deinit();
        const accept_root = try generated.Message.initRootTyped(&accept_builder);
        try cpz.rpc.initWireAcceptMessage(accept_root, .{
            .question_id = 75,
            .has_provision = true,
            .provision_max_capability_count = 1,
            .provision_capability = 0,
            .embargo = "turn-plan-75",
        });
        var accept_reader = cpz.MessageReader.init(try accept_builder.segmentsConst(), .{});
        try embargo_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try accept_reader.getRoot()));

        const no_messages = [_]generated.Message{};
        const embargo_plan = try cpz.rpc.planRpcTurn(&embargo_state, no_messages[0..]);
        try std.testing.expectEqual(@as(usize, 1), embargo_plan.disembargoMessages());
        try std.testing.expectEqual(@as(usize, 1), embargo_plan.totalOutputMessages());
        try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 0 }, embargo_plan.responseMessageRange());
        try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 0 }, embargo_plan.forwardedMessageRange());
        try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, embargo_plan.disembargoMessageRange());
        try embargo_plan.validateDisembargoCapacity(1);
        try std.testing.expectError(error.InvalidTransition, embargo_plan.validateDisembargoCapacity(0));
        try embargo_plan.validateUnifiedOutputCapacity(1);
        const filtered_plan = try cpz.rpc.planRpcTurnForAcceptEmbargo(&embargo_state, no_messages[0..], "turn-plan-75");
        try std.testing.expectEqual(@as(usize, 1), filtered_plan.disembargoMessages());
        const missing_plan = try cpz.rpc.planRpcTurnForAcceptEmbargo(&embargo_state, no_messages[0..], "missing");
        try std.testing.expectEqual(@as(usize, 0), missing_plan.disembargoMessages());
        const method_entries = .{};
        try std.testing.expectEqual(filtered_plan, try cpz.rpc.planRpcTurnMethodsForAcceptEmbargo(&embargo_state, no_messages[0..], method_entries, "turn-plan-75"));
        var disembargo_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer disembargo_builder.deinit();
        const disembargo_root = try generated.Message.initRootTyped(&disembargo_builder);
        const disembargo_builders = [_]generated.Message.Builder{disembargo_root};
        try embargo_plan.validateUnifiedOutputBuilders(disembargo_builders[0..]);
        try std.testing.expectError(error.InvalidTransition, embargo_plan.validateUnifiedOutputBuilders(disembargo_builders[0..0]));
        try std.testing.expectEqual(@as(usize, 1), (try embargo_plan.disembargoMessageRange().slice(disembargo_builders[0..])).len);
        try std.testing.expectError(error.InvalidTransition, embargo_plan.disembargoMessageRange().slice(disembargo_builders[0..0]));
        try embargo_plan.validateOutputBuilderSets(no_messages[0..], no_messages[0..], disembargo_builders[0..]);
        try std.testing.expectError(error.InvalidTransition, embargo_plan.validateOutputBuilderSets(no_messages[0..], no_messages[0..], disembargo_builders[0..0]));
    }

    var bad_call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer bad_call_builder.deinit();
    const bad_call_root = try generated.Message.initRootTyped(&bad_call_builder);
    const bad_call = try bad_call_root.init_call();
    try bad_call.set_questionId(74);
    const bad_target = try bad_call.init_target();
    try bad_target.set_importedCap(999);
    _ = try bad_call.init_params();
    var bad_call_reader = cpz.MessageReader.init(try bad_call_builder.segmentsConst(), .{});
    const bad_message = generated.Message.fromReader(try bad_call_reader.getRoot());
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.planWireMessageDispatch(&state, bad_message));
}

test "rpc call forwarding dispatch initializes forwarded calls" {
    const Handler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 180 });
    try state.resolveImportTo(180, .{ .sender_hosted = 181 });
    try state.applyCapDescriptor(.{ .sender_hosted = 181 });

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(180);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x888, .method_id = 8 }, call);
    const target = try call.init_target();
    try target.set_importedCap(180);
    try cpz.rpc.initWireCallParamsText(call, "forward me", &.{.{ .sender_hosted = 182 }});

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward_root = try generated.Message.initRootTyped(&forward_builder);

    var seen_question: u32 = 0;
    try std.testing.expectEqual(
        cpz.rpc.WireDispatchOutcome.forward_required,
        try cpz.rpc.dispatchCallForwardingOutcome(&state, std.testing.allocator, response_root, forward_root, try request.call(), &seen_question, Handler.handle),
    );
    try std.testing.expectEqual(@as(u32, 0), seen_question);

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 180), forwarded.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 181 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x888, .method_id = 8 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try std.testing.expectEqualStrings("forward me", try (try (try forwarded.params()).content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, try forwarded.params());
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 182 }, descriptors[0]);
}

test "rpc forward helpers copy calls and rewrite targets" {
    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(170);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x777, .method_id = 7 }, call);
    try cpz.rpc.writeSendResultsToToWire(.yourself, call);
    try cpz.rpc.writeCallFlagsToWire(.{
        .no_promise_pipelining = true,
        .only_promise_pipeline = true,
    }, call);
    const target = try call.init_target();
    try target.set_importedCap(170);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 1, 2, 3 }, &.{.{ .sender_hosted = 172 }});

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    const source_call = try request.call();

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 170 });
    try state.resolveImportTo(170, .{ .sender_hosted = 171 });
    try state.applyCapDescriptor(.{ .sender_hosted = 171 });

    var forwarded_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forwarded_builder.deinit();
    const forwarded_root = try generated.Message.initRootTyped(&forwarded_builder);
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 171 },
        try cpz.rpc.initForwardedWireCallMessageToResolvedTarget(&state, forwarded_root, source_call),
    );

    var forwarded_reader = cpz.MessageReader.init(try forwarded_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forwarded_reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 170), forwarded.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 171 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x777, .method_id = 7 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, try cpz.rpc.sendResultsToFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallFlags{
        .no_promise_pipelining = true,
        .only_promise_pipeline = true,
    }, cpz.rpc.callFlagsFromWireCall(forwarded));
    const params = try forwarded.params();
    try expectPayloadUInt32List(params, &.{ 1, 2, 3 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 172 }, descriptors[0]);
}

test "rpc forward helpers reject unresolved calls" {
    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(171);
    const target = try call.init_target();
    try target.set_importedCap(171);
    _ = try call.init_params();

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const source_call = try generated.Message.fromReader(try request_reader.getRoot()).call();
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(171);

    var forwarded_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forwarded_builder.deinit();
    const forwarded_root = try generated.Message.initRootTyped(&forwarded_builder);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initForwardedWireCallMessageToResolvedTarget(&state, forwarded_root, source_call));
}

test "rpc generic dispatch return helper builds non-capability payloads" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 36, .{ .text = "text result" });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expect(!return_.noFinishNeeded());
        try std.testing.expectEqualStrings("text result", try (try (try return_.results()).content()).getText());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 37, .{ .data = "data result" });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqualSlices(u8, "data result", try (try (try return_.results()).content()).getData());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 38, .{ .uint32_list = &.{ 4, 5, 6 } });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try expectPayloadUInt32List(results, &.{ 4, 5, 6 });
    }
}

test "rpc generic dispatch return helper builds non-result outcomes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 22, .canceled);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const return_ = try message.return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.canceled, try cpz.rpc.returnOutcomeFromWireReturn(return_));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 23, .results_sent_elsewhere);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const return_ = try message.return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results_sent_elsewhere, try cpz.rpc.returnOutcomeFromWireReturn(return_));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 24, .{ .take_from_other_question = 25 });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const return_ = try message.return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome{ .take_from_other_question = 25 }, try cpz.rpc.returnOutcomeFromWireReturn(return_));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initDispatchReturnMessage(root, 26, .{ .await_from_third_party = 4 });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const return_ = try message.return_();
        try std.testing.expect(return_.releaseParamCaps());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(return_);
        const usage = switch (outcome) {
            .await_from_third_party => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 5, .capability = 4 }, usage);
    }
}

test "rpc single-message forwarding dispatcher initializes forwarded calls" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
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
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x999, .method_id = 9 }, .handler = Handler.handle },
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 190 });
    try state.resolveImportTo(190, .{ .sender_hosted = 191 });
    try state.applyCapDescriptor(.{ .sender_hosted = 191 });

    var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer request_builder.deinit();
    const request_root = try generated.Message.initRootTyped(&request_builder);
    const call = try request_root.init_call();
    try call.set_questionId(190);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x999, .method_id = 9 }, call);
    const target = try call.init_target();
    try target.set_importedCap(190);
    try cpz.rpc.initWireCallParamsUInt32List(call, &.{ 9, 19 }, &.{.{ .sender_hosted = 192 }});

    var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
    const request = generated.Message.fromReader(try request_reader.getRoot());
    var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer response_builder.deinit();
    const response_root = try generated.Message.initRootTyped(&response_builder);
    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer forward_builder.deinit();
    const forward_root = try generated.Message.initRootTyped(&forward_builder);

    var bootstrap_seen: u32 = 0;
    var context: Context = .{};
    try std.testing.expectEqual(
        cpz.rpc.WireDispatchOutcome.forward_required,
        try cpz.rpc.dispatchWireMessageMethodsForwardingOutcome(
            &state,
            std.testing.allocator,
            response_root,
            forward_root,
            request,
            &bootstrap_seen,
            BootstrapHandler.handle,
            &context,
            entries,
        ),
    );
    try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), context.selected);

    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 191 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x999, .method_id = 9 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try expectPayloadUInt32List(try forwarded.params(), &.{ 9, 19 });
}

test "rpc single-message dispatcher routes calls and applies returns" {
    const BootstrapHandler = struct {
        fn handle(_: *u32, bootstrap: anytype) !u32 {
            return bootstrap.questionId() + 1000;
        }
    };
    const CallHandler = struct {
        fn handle(seen_question: *u32, call: anytype) !cpz.rpc.DispatchResult {
            seen_question.* = call.questionId();
            return .empty;
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    var stats: cpz.rpc.WireDispatchStats = .{};

    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        try cpz.rpc.initWireBootstrapMessage(request_root, 22);

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var bootstrap_seen: u32 = 0;
        var call_seen: u32 = 0;
        const outcome = try cpz.rpc.dispatchWireMessageOutcome(
            &state,
            std.testing.allocator,
            response_root,
            request,
            &bootstrap_seen,
            BootstrapHandler.handle,
            &call_seen,
            CallHandler.handle,
        );
        stats.record(outcome);
        try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, outcome);
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), call_seen);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 1022 }, descriptors[0]);
        try state.applyWireMessage(std.testing.allocator, response);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(22));
    }
    {
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        const call = try request_root.init_call();
        try call.set_questionId(20);
        const target = try call.init_target();
        try target.set_importedCap(5);
        _ = try call.init_params();

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var bootstrap_seen: u32 = 0;
        var call_seen: u32 = 0;
        try std.testing.expect(try cpz.rpc.dispatchWireMessage(
            &state,
            std.testing.allocator,
            response_root,
            request,
            &bootstrap_seen,
            BootstrapHandler.handle,
            &call_seen,
            CallHandler.handle,
        ));
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 20), call_seen);
        stats.record(.response_initialized);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try state.applyWireMessage(std.testing.allocator, response);
        try std.testing.expect(state.questionComplete(20));
    }
    {
        try state.openQuestion(21, .call);
        var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer return_builder.deinit();
        const return_root = try generated.Message.initRootTyped(&return_builder);
        const return_ = try return_root.init_return_();
        try return_.set_answerId(21);
        try return_.set_noFinishNeeded(true);
        _ = try return_.init_results();

        var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try return_reader.getRoot());
        var unused_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer unused_response_builder.deinit();
        const unused_response = try generated.Message.initRootTyped(&unused_response_builder);
        var bootstrap_seen: u32 = 0;
        var call_seen: u32 = 0;
        const outcome = try cpz.rpc.dispatchWireMessageOutcome(
            &state,
            std.testing.allocator,
            unused_response,
            message,
            &bootstrap_seen,
            BootstrapHandler.handle,
            &call_seen,
            CallHandler.handle,
        );
        stats.record(outcome);
        try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.state_applied, outcome);
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), call_seen);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(21));
        try std.testing.expect(state.questionComplete(21));
    }
    try std.testing.expectEqual(@as(usize, 2), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(usize, 3), stats.total());
}

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

    var forward_reader = cpz.MessageReader.init(try forward_builder1.segmentsConst(), .{});
    const forwarded = try generated.Message.fromReader(try forward_reader.getRoot()).call();
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 211 }, try cpz.rpc.callTargetFromWireCall(forwarded));
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x6666, .method_id = 6 }, cpz.rpc.callMethodFromWireCall(forwarded));
    try expectPayloadUInt32List(try forwarded.params(), &.{ 6, 12 });

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
    try expectPayloadUInt32List(try forwarded.params(), &.{ 7, 14 });
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
    try expectPayloadUInt32List(try forwarded.params(), &.{ 8, 16 });
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
    }
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
    try expectPayloadUInt32List(try forwarded.params(), &.{ 9, 18 });
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
    try expectPayloadUInt32List(try forwarded.params(), &.{ 14, 28 });
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

    var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
    const response = generated.Message.fromReader(try response_reader.getRoot());
    const return_ = try response.return_();
    try std.testing.expectEqual(@as(u32, 48), return_.answerId());
    try std.testing.expectEqualStrings("method apply", try (try (try return_.results()).content()).getText());
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
        const tracked = state.provideInfo(61).?;
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 70 }, tracked.target);
        try std.testing.expectEqual(@as(?u32, 2), tracked.recipient_capability);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, state.provideRecipient(61).?);
        try std.testing.expectEqual(@as(usize, 1), state.provideRecipientCount());
        try std.testing.expectEqual(cpz.rpc.StateHandoffStats{ .provides = 1, .provide_recipients = 1 }, state.handoffStats());
        try std.testing.expectEqual(@as(usize, 1), state.handoffStats().tracked());
        try std.testing.expectEqual(@as(usize, 1), state.handoffStats().ready());
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
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.QuestionNotOpen, state.applyWireMessage(std.testing.allocator, message));
        try state.openQuestion(63, .bootstrap);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(62));
        const tracked = state.joinInfo(62).?;
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 63 } }, tracked.target);
        try std.testing.expectEqual(@as(?u32, 4), tracked.key_part_capability);
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
    try std.testing.expectEqualStrings("embargo-64", info.embargo.?);
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(64));
    const tracked = state.acceptInfo(64).?;
    try std.testing.expect(tracked.has_provision);
    try std.testing.expectEqual(@as(?u32, 2), tracked.provision_capability);
    try std.testing.expectEqualStrings("embargo-64", tracked.embargo.?);
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
        try std.testing.expectEqual(@as(u32, 64), pending.items[0].question_id);
        try std.testing.expectEqualStrings("embargo-64", pending.items[0].embargo);
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
    const released = switch (disembargo_result) {
        .disembargo => |info| info,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(@as(usize, 1), released.released_accepts);
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
    const stats = try state.applyWireMessagesAlloc(std.testing.allocator, messages[0..]);
    try std.testing.expectEqual(cpz.rpc.WireMessageApplyStats{
        .state_applied = 1,
        .disembargos = 1,
        .released_accepts = 1,
    }, stats);
    try std.testing.expectEqual(@as(usize, 2), stats.total());
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
    var ready_ids = try state.readyHandoffIdsAlloc(std.testing.allocator);
    defer ready_ids.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), ready_ids.total());
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
    const stats = try state.initTrackedHandoffReturnMessages(responses[0..], completions[0..]);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1, .accepts = 1, .joins = 1 }, stats);
    try std.testing.expectEqual(@as(usize, 3), stats.total());

    {
        var response_reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(@as(u32, 90), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 390);
    }
    {
        var response_reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        try std.testing.expectEqual(@as(u32, 91), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 391);
    }
    {
        var response_reader = cpz.MessageReader.init(try response_builder2.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const return_ = try response.return_();
        try std.testing.expectEqual(@as(u32, 92), return_.answerId());
        try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.joinResultCapabilityFromWireReturn(return_));
        try expectReturnCapabilityResult(response, 392);
    }

    try std.testing.expectError(error.InvalidTransition, state.initTrackedHandoffReturnMessages(responses[0..2], completions[0..]));
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
        try expectReturnCapabilityResult(response, 502);
    }

    try std.testing.expectError(error.InvalidTransition, state.initReadyHandoffReturnPlanMessages(responses[0..2], plan));
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
    try ready_return_stats.validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, ready_return_stats.validateCapacity(2));

    const no_turn_messages = [_]generated.Message{};
    const handoff_turn_plan = try cpz.rpc.planRpcTurn(&state, no_turn_messages[0..]);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{}, handoff_turn_plan.dispatch);
    try std.testing.expectEqual(ready_return_stats, handoff_turn_plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 3), handoff_turn_plan.responseMessages());
    try std.testing.expectEqual(@as(usize, 0), handoff_turn_plan.forwardedMessages());
    try std.testing.expectEqual(@as(usize, 3), handoff_turn_plan.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 0), handoff_turn_plan.disembargoMessages());
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
        try expectReturnCapabilityResult(response, 566);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 67), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 967);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 381 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("turn forward", try (try (try forwarded.params()).content()).getText());
    }
}

test "rpc turn dispatcher fills dense outputs without sinks" {
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

        fn handle(context: *@This(), question_id: u32, usage: cpz.rpc.AnyPointerUsage) !u32 {
            context.seen += 1;
            context.question_sum += question_id;
            return question_id + 900 + (usage.capability orelse 0);
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 660 });
    try state.resolveImportTo(660, .{ .sender_hosted = 661 });
    try state.applyCapDescriptor(.{ .sender_hosted = 661 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 121,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 120);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(660);
    const target = try call.init_target();
    try target.set_importedCap(660);
    try cpz.rpc.initWireCallParamsText(call, "no-sink turn forward", &.{.{ .sender_hosted = 662 }});
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
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingDenseFromHandlers(
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
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 1, .forward_required = 1 }, applied.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{ .provides = 1 }, applied.handoff_returns);
    try std.testing.expectEqual(@as(u32, 120), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 121), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try response_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 120), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 620);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 121), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 1021);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 661 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("no-sink turn forward", try (try (try forwarded.params()).content()).getText());
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
        try expectReturnCapabilityResult(response, 640);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 141), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 1041);
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
        try expectReturnCapabilityResult(response, 590);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 91), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 991);
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
}

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
        try expectReturnCapabilityResult(response, 972);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 401 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("turn apply forward", try (try (try forwarded.params()).content()).getText());
    }
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
        try expectReturnCapabilityResult(response, 1032);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 681 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("no-sink apply forward", try (try (try forwarded.params()).content()).getText());
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
        try expectReturnCapabilityResult(response_message, 1116);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("no-sink-apply-pending-147", info.context.accept);
    }
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
        try expectReturnCapabilityResult(response_message, 1046);
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
        try expectReturnCapabilityResult(response_message, 1080);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("apply-filter-pending-111", info.context.accept);
    }
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
        try expectReturnCapabilityResult(response, 990);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 391 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 2, 4 });
    }
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
        try expectReturnCapabilityResult(response, 662);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 123), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 1083);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 671 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 8, 16 });
    }
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
        try expectReturnCapabilityResult(response, 674);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 125), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 1105);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 691 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 9, 18 });
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
        try expectReturnCapabilityResult(response_message, 1138);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-no-sink-apply-pending-149", info.context.accept);
    }
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
        try expectReturnCapabilityResult(response, 682);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 143), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 1103);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 711 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 10, 20 });
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-no-sink-disembargo-144", info.context.accept);
    }
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
        try expectReturnCapabilityResult(response, 632);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 93), (try response.return_()).answerId());
        try expectReturnCapabilityResult(response, 1033);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 651 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 4, 8 });
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
        try expectReturnCapabilityResult(response, 1003);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 411 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try expectPayloadUInt32List(try forwarded.params(), &.{ 3, 6 });
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
        try expectReturnCapabilityResult(response_message, 1066);
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
        try expectReturnCapabilityResult(response_message, 1092);
    }
    {
        var reader = cpz.MessageReader.init(try disembargo_builder.segmentsConst(), .{});
        const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try generated.Message.fromReader(try reader.getRoot()).disembargo());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, info.target);
        try std.testing.expectEqualStrings("method-apply-filter-pending-113", info.context.accept);
    }
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
        try expectReturnCapabilityResult(response, 396);
    }

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireHandoffReturnMessagesToSink(responses[0..2], completions[0..], &sink, Sink.handle));
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
    (try payload.get_completionAsPointer()).setCapability(4);
    try payload.set_answerId(24);
    const event = try decode(&builder);
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .third_party_answer = 24 }, event);

    var info_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const info_message = generated.Message.fromReader(try info_reader.getRoot());
    const info = try cpz.rpc.thirdPartyAnswerInfoFromWireThirdPartyAnswer(try info_message.thirdPartyAnswer());
    try std.testing.expectEqual(@as(u32, 24), info.answer_id);
    try std.testing.expect(info.has_completion);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 5, .capability = 4 }, info.completion.?);

    try std.testing.expect(event.toStateEvent() == null);
    try state.applyWireEvent(event);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(24));
}

test "rpc third-party answer info helpers write completions" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireThirdPartyAnswerMessage(root, .{
        .answer_id = 26,
        .has_completion = true,
        .completion = .{ .max_capability_count = 3, .capability = 2 },
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.thirdPartyAnswerInfoFromWireThirdPartyAnswer(try message.thirdPartyAnswer());
    try std.testing.expectEqual(@as(u32, 26), info.answer_id);
    try std.testing.expect(info.has_completion);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, info.completion.?);
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
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 91 }, state.exportResolution(90).?);
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(91));
}

test "rpc resolve cap descriptors replace imported promises" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const resolve = try root.init_resolve();
    try resolve.set_promiseId(99);
    const cap = try resolve.init_cap();
    try cap.set_senderHosted(100);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 99 });
    try std.testing.expectEqual(@as(?bool, false), state.importResolved(99));
    try std.testing.expect(!state.callTargetResolved(.{ .imported_cap = 99 }));
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 99 },
        state.effectiveCallTarget(.{ .imported_cap = 99 }),
    );
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.importResolved(99));
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 100 }, state.importResolution(99).?);
    try std.testing.expect(state.callTargetResolved(.{ .imported_cap = 99 }));
    try std.testing.expectEqual(
        cpz.rpc.CapDescriptor{ .sender_hosted = 100 },
        state.callTargetResolution(.{ .imported_cap = 99 }).?,
    );
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 100 },
        state.callTargetForwardTarget(.{ .imported_cap = 99 }).?,
    );
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 100 },
        state.effectiveCallTarget(.{ .imported_cap = 99 }),
    );
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(100));
}

test "rpc resolved call targets follow transitive import chains" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 110 });
    try state.resolveImportTo(110, .{ .sender_promise = 111 });
    try state.applyCapDescriptor(.{ .sender_promise = 111 });
    try state.resolveImportTo(111, .{ .sender_hosted = 112 });
    try state.applyCapDescriptor(.{ .sender_hosted = 112 });

    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 111 },
        state.callTargetForwardTarget(.{ .imported_cap = 110 }).?,
    );
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 112 },
        (try state.callTargetTransitiveForwardTarget(.{ .imported_cap = 110 })).?,
    );
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 112 },
        try state.transitiveEffectiveCallTarget(.{ .imported_cap = 110 }),
    );
    try std.testing.expectEqual(
        cpz.rpc.CapDescriptor{ .sender_hosted = 112 },
        (try state.callTargetFinalResolution(.{ .imported_cap = 110 })).?,
    );

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(110);
    const target = try call.init_target();
    try target.set_importedCap(110);
    _ = try call.init_params();

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 112 },
        (try state.wireCallTargetTransitiveForwardTarget(try message.call())).?,
    );
    try std.testing.expectEqual(
        cpz.rpc.CallTarget{ .imported_cap = 112 },
        try state.transitiveEffectiveWireCallTarget(try message.call()),
    );
    try std.testing.expectEqual(
        cpz.rpc.CapDescriptor{ .sender_hosted = 112 },
        (try state.wireCallTargetFinalResolution(try message.call())).?,
    );
}

test "rpc resolved call targets detect import resolution cycles" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyCapDescriptor(.{ .sender_promise = 120 });
    try state.applyCapDescriptor(.{ .sender_promise = 121 });
    try state.resolveImportTo(120, .{ .sender_promise = 121 });
    try state.resolveImportTo(121, .{ .sender_promise = 120 });

    try std.testing.expectError(error.InvalidTransition, state.callTargetFinalResolution(.{ .imported_cap = 120 }));
    try std.testing.expectError(error.InvalidTransition, state.callTargetTransitiveForwardTarget(.{ .imported_cap = 120 }));
    try std.testing.expectError(error.InvalidTransition, state.transitiveEffectiveCallTarget(.{ .imported_cap = 120 }));
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

test "rpc resolve exceptions mark promise exports resolved" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const resolve = try root.init_resolve();
    try resolve.set_promiseId(96);
    const exception = try resolve.init_exception();
    try exception.set_reason("promise broken");
    try exception.set_type__raw(2);
    try exception.set_trace("promise trace");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(try message.resolve());
    try std.testing.expectEqual(@as(u32, 96), info.promise_id);
    try std.testing.expect(info.cap == null);
    const decoded_exception = info.exception orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("promise broken", decoded_exception.reason.?);
    try std.testing.expectEqual(@as(u16, 2), decoded_exception.type_raw);
    try std.testing.expectEqualStrings("promise trace", decoded_exception.trace.?);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(96);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(96));
    try std.testing.expect(state.exportResolution(96) == null);
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
        .exception = .{ .reason = "resolve failed", .type_raw = 3, .trace = "resolve trace" },
    }, resolve);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const resolve_reader = generated.Resolve.fromReader(try reader.getRoot());
    const info = try cpz.rpc.resolveInfoFromWireResolve(resolve_reader);
    try std.testing.expectEqual(@as(u32, 97), info.promise_id);
    try std.testing.expect(info.cap == null);
    const exception = info.exception orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("resolve failed", exception.reason.?);
    try std.testing.expectEqual(@as(u16, 3), exception.type_raw);
    try std.testing.expectEqualStrings("resolve trace", exception.trace.?);
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
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 95 }, state.exportResolution(94).?);
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
    try std.testing.expect(state.exportResolution(98) == null);
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
