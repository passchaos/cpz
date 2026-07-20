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
    try std.testing.expect(state.readyAcceptProvision(64) == null);
    try std.testing.expectEqual(@as(usize, 0), state.readyAcceptProvisionCount());
    {
        var premature_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer premature_builder.deinit();
        const premature_root = try generated.Message.initRootTyped(&premature_builder);
        try std.testing.expectError(error.InvalidTransition, state.initReadyAcceptReturnMessage(premature_root, 64, 90));
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
    try std.testing.expectError(error.InvalidTransition, state.applyWireDisembargo(try disembargo_message.disembargo()));
    try state.addImport(5);
    const released = try state.applyWireDisembargo(try disembargo_message.disembargo());
    try std.testing.expectEqual(@as(usize, 1), released.released_accepts);
    try std.testing.expect(released.releasedAnyAccept());
    try std.testing.expectEqual(@as(usize, 0), (try state.applyWireDisembargo(try disembargo_message.disembargo())).released_accepts);
    try std.testing.expectEqual(@as(?bool, true), state.acceptEmbargoReleased(64));
    try std.testing.expectEqual(@as(?bool, true), state.acceptReady(64));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, state.readyAcceptProvision(64).?);
    try std.testing.expectEqual(@as(usize, 1), state.readyAcceptProvisionCount());
    try std.testing.expectEqual(cpz.rpc.StateHandoffStats{ .accepts = 1, .ready_accept_provisions = 1 }, state.handoffStats());
    {
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);
        try state.initReadyAcceptReturnMessage(response_root, 64, 90);

        var response_reader = cpz.MessageReader.init(try response_builder.segmentsConst(), .{});
        const response = generated.Message.fromReader(try response_reader.getRoot());
        const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, try response.return_());
        defer std.testing.allocator.free(descriptors);
        try std.testing.expectEqual(@as(usize, 1), descriptors.len);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 90 }, descriptors[0]);
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
