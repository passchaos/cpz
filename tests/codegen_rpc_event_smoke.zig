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
    });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const payload_reader = generated.Payload.fromReader(try reader.getRoot());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, payload_reader);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 5), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor.none, descriptors[0]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 16 }, descriptors[1]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 17 }, descriptors[2]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 18 }, descriptors[3]);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_answer = .{ .question_id = 19 } }, descriptors[4]);
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

test "rpc top-level provide and join messages validate targets" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const provide = try root.init_provide();
        try provide.set_questionId(61);
        const target = try provide.init_target();
        try target.set_importedCap(70);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
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

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.QuestionNotOpen, state.applyWireMessage(std.testing.allocator, message));
        try state.openQuestion(63, .bootstrap);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(62));
    }
}

test "rpc top-level accept messages open questions" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const accept = try root.init_accept();
    try accept.set_questionId(64);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(64));
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
