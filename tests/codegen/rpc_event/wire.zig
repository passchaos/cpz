const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc wire events decode generated message union tags and ids" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireUnimplementedMessage(root);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.unimplemented, event.tag());
        try std.testing.expect(event.isUnimplemented());
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.unimplemented, event.unimplementedOriginalTag().?);
        try std.testing.expect(event.isUnimplementedOf(.unimplemented));
        try std.testing.expect(!event.isUnimplementedOf(.bootstrap));
        try std.testing.expect(!event.isStateApplicable());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const original = try root.init_unimplemented();
        const bootstrap = try original.init_bootstrap();
        try bootstrap.set_questionId(10);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.unimplemented, event.tag());
        try std.testing.expect(event.isUnimplemented());
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.bootstrap, event.unimplementedOriginalTag().?);
        try std.testing.expect(event.isUnimplementedOf(.bootstrap));
        try std.testing.expect(!event.isUnimplementedOf(.call));
        try std.testing.expect(!event.isStateApplicable());
        try std.testing.expect(event.toStateEvent() == null);
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.bootstrap, (try cpz.rpc.unimplementedMessageTag(message)).?);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .bootstrap = 10 }, (try cpz.rpc.eventFromWireUnimplementedMessage(message)).?);
    }
    {
        var original_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer original_builder.deinit();
        const original_root = try generated.Message.initRootTyped(&original_builder);
        const original_call = try original_root.init_call();
        try original_call.set_questionId(15);

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireUnimplementedMessageFromBuilder(root, original_root);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.call, (try cpz.rpc.unimplementedMessageTag(message)).?);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .call = 15 }, (try cpz.rpc.eventFromWireUnimplementedMessage(message)).?);
    }
    {
        var original_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer original_builder.deinit();
        const original_root = try generated.Message.initRootTyped(&original_builder);
        const original_finish = try original_root.init_finish();
        try original_finish.set_questionId(16);
        try original_finish.set_releaseResultCaps(false);
        var original_reader = cpz.MessageReader.init(try original_builder.segmentsConst(), .{});
        const original_message = generated.Message.fromReader(try original_reader.getRoot());

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireUnimplementedMessageFrom(root, original_message);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.finish, (try cpz.rpc.unimplementedMessageTag(message)).?);
        try std.testing.expectEqual(
            cpz.rpc.WireEvent{ .finish = .{ .question_id = 16, .release_result_caps = false } },
            (try cpz.rpc.eventFromWireUnimplementedMessage(message)).?,
        );
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireAbortMessage(root, .{
            .reason = "fatal rpc abort",
            .type_raw = @intFromEnum(cpz.rpc.ExceptionType.failed),
            .trace = "abort trace",
        });
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.abort, event.tag());
        try std.testing.expect(event.isAbort());
        try std.testing.expect(!event.isStateApplicable());
        const exception = event.abortException().?;
        try std.testing.expectEqual(cpz.rpc.ExceptionType.failed, exception.exceptionType().?);
        try std.testing.expectEqualStrings("fatal rpc abort", exception.reason.?);
        try std.testing.expectEqualStrings("abort trace", exception.trace.?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireObsoleteSaveMessage(root);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.obsolete_save, event.tag());
        try std.testing.expect(event.isObsolete());
        try std.testing.expect(event.isObsoleteSave());
        try std.testing.expect(!event.isObsoleteDelete());
        try std.testing.expect(!event.isStateApplicable());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireObsoleteDeleteMessage(root);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireMessageTag.obsolete_delete, event.tag());
        try std.testing.expect(event.isObsolete());
        try std.testing.expect(event.isObsoleteDelete());
        try std.testing.expect(!event.isObsoleteSave());
        try std.testing.expect(!event.isStateApplicable());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_bootstrap();
        try payload.set_questionId(11);
        const event = try support.decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .bootstrap = 11 }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .bootstrap = 11 }, event.toStateEvent().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_call();
        try payload.set_questionId(12);
        const event = try support.decode(&builder);
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
        const event = try support.decode(&builder);
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
        const event = try support.decode(&builder);
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
        const event = try support.decode(&builder);
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
        try std.testing.expect(decoded.isImportedCap());
        try std.testing.expect(!decoded.isPromisedAnswer());
        try std.testing.expectEqual(@as(?u32, 7), decoded.importId());
        try std.testing.expect(decoded.matchesImport(7));
        try std.testing.expect(!decoded.matchesImport(8));
        try std.testing.expectEqual(@as(?u32, null), decoded.promisedQuestionId());
        try std.testing.expect(!decoded.matchesPromisedQuestion(99));

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
        try std.testing.expect(!decoded.isImportedCap());
        try std.testing.expect(decoded.isPromisedAnswer());
        try std.testing.expectEqual(@as(?u32, null), decoded.importId());
        try std.testing.expect(!decoded.matchesImport(7));
        try std.testing.expectEqual(@as(?u32, 99), decoded.promisedQuestionId());
        try std.testing.expect(decoded.matchesPromisedQuestion(99));
        try std.testing.expect(!decoded.matchesPromisedQuestion(100));

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try std.testing.expectError(error.QuestionNotOpen, state.validateWireCallTarget(try message.call()));
        try state.openQuestion(99, .bootstrap);
        try state.validateWireCallTarget(try message.call());
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
    const flags = cpz.rpc.callFlagsFromWireCall(call_reader);
    try std.testing.expect(!flags.isDefault());
    try std.testing.expect(flags.allowsThirdPartyTailCall());
    try std.testing.expect(flags.forbidsPromisePipelining());
    try std.testing.expect(flags.onlyAllowsPromisePipeline());
    try std.testing.expect((cpz.rpc.CallFlags{}).isDefault());
    const fluent_flags = (cpz.rpc.CallFlags{})
        .withAllowThirdPartyTailCall(true)
        .withNoPromisePipelining(true)
        .withOnlyPromisePipeline(true);
    try std.testing.expect(fluent_flags.allowsThirdPartyTailCall());
    try std.testing.expect(fluent_flags.forbidsPromisePipelining());
    try std.testing.expect(fluent_flags.onlyAllowsPromisePipeline());
    try std.testing.expect(!fluent_flags.withOnlyPromisePipeline(false).onlyAllowsPromisePipeline());
}

test "rpc call helpers round-trip call options" {
    const options = (cpz.rpc.CallOptions{})
        .withMethod(.{ .interface_id = 0x1234_5678_9abc_def0, .method_id = 31 })
        .withThirdPartyResults(.{ .max_capability_count = 3, .capability = 2 })
        .withFlags(.{
        .allow_third_party_tail_call = true,
        .only_promise_pipeline = true,
    });

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const call = try generated.Call.initRootTyped(&builder);
    try cpz.rpc.writeCallOptionsToWire(options, call);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call_reader = generated.Call.fromReader(try reader.getRoot());
    const decoded = try cpz.rpc.callOptionsFromWireCall(call_reader);
    try std.testing.expectEqual(options, decoded);
    try std.testing.expect(decoded.matchesMethod(.{ .interface_id = 0x1234_5678_9abc_def0, .method_id = 31 }));
    try std.testing.expect(decoded.matchesWireCall(call_reader));
    try std.testing.expect(decoded.sendsResultsTo(.third_party));
    try std.testing.expect(decoded.allowsThirdPartyTailCall());
    try std.testing.expect(!decoded.forbidsPromisePipelining());
    try std.testing.expect(decoded.onlyAllowsPromisePipeline());

    try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeCallOptionsToWire(.{
        .send_results_to = .third_party,
        .send_results_to_third_party = .{ .max_capability_count = 1, .capability = 1 },
    }, call));
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
    try std.testing.expect(!decoded.isImportedCap());
    try std.testing.expect(decoded.isPromisedAnswer());
    try std.testing.expect(decoded.importId() == null);
    try std.testing.expectEqual(@as(?u32, 99), decoded.promisedQuestionId());
    try std.testing.expect(decoded.matchesPromisedQuestion(99));
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 99 } }, decoded.asCallTarget());

    const promised_decoded = switch (decoded) {
        .promised_answer => |answer| answer,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(@as(u32, 99), promised_decoded.question_id);
    try std.testing.expect(promised_decoded.matchesQuestion(99));
    try std.testing.expect(!promised_decoded.matchesQuestion(100));
    try std.testing.expectEqual(@as(usize, 2), promised_decoded.transform.len);
    try std.testing.expectEqual(@as(usize, 2), promised_decoded.transformLen());
    try std.testing.expect(promised_decoded.hasTransform());
    try std.testing.expectEqual(cpz.rpc.PromisedAnswerOp{ .get_pointer_field = 1 }, promised_decoded.transform[0]);
    try std.testing.expect(promised_decoded.transform[0].isGetPointerField());
    try std.testing.expectEqual(@as(?u16, 1), promised_decoded.transform[0].pointerFieldIndex());
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
        const owned_import = cpz.rpc.CallTargetOwned{ .imported_cap = 44 };
        try std.testing.expect(owned_import.isImportedCap());
        try std.testing.expect(!owned_import.isPromisedAnswer());
        try std.testing.expectEqual(@as(?u32, 44), owned_import.importId());
        try std.testing.expect(owned_import.matchesImport(44));
        try std.testing.expect(owned_import.promisedQuestionId() == null);
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 44 }, owned_import.asCallTarget());
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
        try std.testing.expect(decoded.isPromisedAnswer());
        try std.testing.expect(!decoded.matchesImport(44));
        try std.testing.expect(decoded.matchesPromisedQuestion(45));
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 45 } }, decoded.asCallTarget());
        const promised = switch (decoded) {
            .promised_answer => |answer| answer,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(@as(u32, 45), promised.question_id);
        try std.testing.expect(promised.matchesQuestion(45));
        try std.testing.expectEqual(@as(usize, 1), promised.transform.len);
        try std.testing.expectEqual(@as(usize, 1), promised.transformLen());
        try std.testing.expect(promised.hasTransform());
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
        try std.testing.expect(ops[0].isNoop());
        try std.testing.expect(ops[0].pointerFieldIndex() == null);
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

test "rpc cap descriptor helpers decode common capability table entries" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        _ = try generated.CapDescriptor.initRootTyped(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor.none, try support.decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_senderHosted(8);
        const decoded = try support.decodeCapDescriptor(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 8 }, decoded);
        try std.testing.expect(decoded.isForwardableToCallTarget());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 8 }, decoded.forwardableCallTarget().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_senderPromise(9);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 9 }, try support.decodeCapDescriptor(&builder));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_receiverHosted(10);
        const decoded = try support.decodeCapDescriptor(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_hosted = 10 }, decoded);
        try std.testing.expect(!decoded.isForwardableToCallTarget());
        try std.testing.expect(decoded.forwardableCallTarget() == null);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        const answer = try descriptor.init_receiverAnswer();
        try answer.set_questionId(11);
        const decoded = try support.decodeCapDescriptor(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .receiver_answer = .{ .question_id = 11 } }, decoded);
        try std.testing.expect(decoded.isForwardableToCallTarget());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .promised_answer = .{ .question_id = 11 } }, decoded.forwardableCallTarget().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        const third_party = try descriptor.init_thirdPartyHosted();
        (try third_party.get_idAsPointer()).setCapability(3);
        try third_party.set_vineId(12);
        const decoded = try support.decodeCapDescriptor(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 12 }, decoded);
        try std.testing.expect(decoded.isForwardableToCallTarget());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 12 }, decoded.forwardableCallTarget().?);
        const info = try support.decodeCapDescriptorInfo(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 12 }, info.descriptor);
        try std.testing.expectEqual(cpz.rpc.CapDescriptorInfo.no_attached_fd, info.attached_fd);
        try std.testing.expect(!info.hasAttachedFd());
        try std.testing.expect(info.attachedFd() == null);
        try std.testing.expect(info.isForwardableToCallTarget());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 12 }, info.forwardableCallTarget().?);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, info.third_party_contact.?);
        try std.testing.expect(info.hasThirdPartyContactUsage());
        try std.testing.expect(info.thirdPartyContactMatchesCapability(3));
        try std.testing.expect(!info.thirdPartyContactMatchesCapability(2));
    }
}

test "rpc cap descriptor info helpers preserve attached fd indexes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try descriptor.set_senderHosted(13);
        try descriptor.set_attachedFd(4);
        const info = try support.decodeCapDescriptorInfo(&builder);
        try std.testing.expectEqual(
            cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_hosted = 13 }, .attached_fd = 4 },
            info,
        );
        try std.testing.expect(info.hasAttachedFd());
        try std.testing.expectEqual(@as(?u8, 4), info.attachedFd());
        try std.testing.expect(info.isForwardableToCallTarget());
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 13 }, info.forwardableCallTarget().?);
        try std.testing.expect(!info.hasThirdPartyContactUsage());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try cpz.rpc.writeCapDescriptorInfoToWire(.{ .descriptor = .{ .sender_promise = 14 }, .attached_fd = 2 }, descriptor);
        const info = try support.decodeCapDescriptorInfo(&builder);
        try std.testing.expectEqual(
            cpz.rpc.CapDescriptorInfo{ .descriptor = .{ .sender_promise = 14 }, .attached_fd = 2 },
            info,
        );
        try std.testing.expect(info.hasAttachedFd());
        try std.testing.expectEqual(@as(?u8, 2), info.attachedFd());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try cpz.rpc.writeCapDescriptorInfoToWire(.{
            .descriptor = .{ .third_party_hosted = 15 },
            .third_party_contact = .{ .max_capability_count = 6, .capability = 5 },
        }, descriptor);
        const info = try support.decodeCapDescriptorInfo(&builder);
        try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .third_party_hosted = 15 }, info.descriptor);
        try std.testing.expect(!info.hasAttachedFd());
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 6, .capability = 5 }, info.third_party_contact.?);
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 6, .capability = 5 }, info.thirdPartyContactUsage().?);
        try std.testing.expect(info.hasThirdPartyContactUsage());
        try std.testing.expect(info.thirdPartyContactMatchesCapability(5));
        try std.testing.expect(!info.thirdPartyContactMatchesCapability(4));
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 15 }, info.forwardableCallTarget().?);
        try info.validate();
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const descriptor = try generated.CapDescriptor.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeCapDescriptorInfoToWire(.{
            .descriptor = .{ .third_party_hosted = 16 },
            .third_party_contact = .{ .max_capability_count = 6, .capability = 6 },
        }, descriptor));
        try std.testing.expectError(error.InvalidTransition, (cpz.rpc.CapDescriptorInfo{
            .descriptor = .{ .sender_hosted = 16 },
            .third_party_contact = .{ .max_capability_count = 6, .capability = 5 },
        }).validate());
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
        try support.expectPayloadUInt32List(params, &.{ 2, 4, 8 });
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
        try support.expectPayloadUInt32List(params, &.{ 16, 32 });
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
    try support.expectPayloadUInt32List(params, &.{ 64, 128 });
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
        try support.expectPayloadUInt32List(params, &.{ 11, 22 });
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
    const OptionHandler = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const fluent_options = (cpz.rpc.CallOptions{})
        .withMethod(.{ .interface_id = 0x9000, .method_id = 9 })
        .withSendResultsTo(.yourself)
        .withFlags(.{ .no_promise_pipelining = true });
    try fluent_options.validate();
    try std.testing.expect((cpz.rpc.CallOptions{}).isDefault());
    try std.testing.expect(!fluent_options.isDefault());
    try std.testing.expect(fluent_options.hasMethod());
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9000, .method_id = 9 }, fluent_options.method);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x9000, .method_id = 9 }, fluent_options.callMethod());
    try std.testing.expect(fluent_options.sendsResultsTo(.yourself));
    try std.testing.expect(fluent_options.forbidsPromisePipelining());
    try std.testing.expect(fluent_options.thirdPartyResultsUsage() == null);
    try std.testing.expect(!fluent_options.hasThirdPartyResultsUsage());
    const fluent_flag_options = (cpz.rpc.CallOptions{})
        .withAllowThirdPartyTailCall(true)
        .withNoPromisePipelining(true)
        .withOnlyPromisePipeline(true);
    try std.testing.expect(fluent_flag_options.allowsThirdPartyTailCall());
    try std.testing.expect(fluent_flag_options.forbidsPromisePipelining());
    try std.testing.expect(fluent_flag_options.onlyAllowsPromisePipeline());
    try std.testing.expect(!fluent_flag_options.withNoPromisePipelining(false).forbidsPromisePipelining());
    const fluent_call_info = fluent_options.callInfo(900, .{ .imported_cap = 7 });
    try std.testing.expectEqual(@as(cpz.rpc.QuestionId, 900), fluent_call_info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 7 }, fluent_call_info.target);
    try std.testing.expectEqual(fluent_options.callMethod(), fluent_call_info.callMethod());
    try std.testing.expectEqual(fluent_options, fluent_call_info.callOptions());

    const third_party_options = (cpz.rpc.CallOptions{})
        .withMethod(.{ .interface_id = 0x9002, .method_id = 11 })
        .withThirdPartyResults(.{ .max_capability_count = 4, .capability = 3 })
        .withFlags(.{ .allow_third_party_tail_call = true });
    try third_party_options.validate();
    try std.testing.expect(third_party_options.sendsResultsTo(.third_party));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, third_party_options.thirdPartyResultsUsage().?);
    try std.testing.expect(third_party_options.hasThirdPartyResultsUsage());
    try std.testing.expect(third_party_options.allowsThirdPartyTailCall());
    try std.testing.expect(third_party_options.withSendResultsTo(.caller).thirdPartyResultsUsage() == null);
    const option_entry = comptime ((cpz.rpc.CallOptions{})
        .withMethod(.{ .interface_id = 0x9002, .method_id = 11 })
        .withThirdPartyResults(.{ .max_capability_count = 4, .capability = 3 })
        .withFlags(.{ .allow_third_party_tail_call = true })).methodEntry(OptionHandler.handle);
    try std.testing.expectEqual(third_party_options.method, option_entry.method);
    try std.testing.expectEqual(@as(?usize, 0), try third_party_options.entryIndex(.{option_entry}));

    try (cpz.rpc.CallOptions{
        .method = .{ .interface_id = 0x9000, .method_id = 9 },
        .send_results_to = .yourself,
        .flags = .{ .no_promise_pipelining = true },
    }).validate();
    try (cpz.rpc.CallOptions{
        .method = .{ .interface_id = 0x9002, .method_id = 11 },
        .send_results_to = .third_party,
        .send_results_to_third_party = .{ .max_capability_count = 4, .capability = 3 },
        .flags = .{ .allow_third_party_tail_call = true },
    }).validate();
    try (cpz.rpc.CallOptions{
        .send_results_to = .third_party,
    }).validate();
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.CallOptions{
        .send_results_to_third_party = .{ .max_capability_count = 4, .capability = 3 },
    }).validate());
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.CallOptions{
        .send_results_to = .third_party,
        .send_results_to_third_party = .{ .max_capability_count = 4, .capability = 4 },
    }).validate());

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
        try support.expectPayloadUInt32List(try call.params(), &.{ 1, 3, 5 });
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
        try support.expectPayloadUInt32List(params, &.{ 9, 18 });
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
        try support.expectPayloadUInt32List(params, &.{ 3, 6, 9 });
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
        try support.expectPayloadUInt32List(params, &.{ 12, 24 });
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
    try support.expectPayloadUInt32List(params, &.{ 48, 96 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
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
    const event = try support.decode(&builder);
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .third_party_answer = 24 }, event);

    var info_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const info_message = generated.Message.fromReader(try info_reader.getRoot());
    const info = try cpz.rpc.thirdPartyAnswerInfoFromWireThirdPartyAnswer(try info_message.thirdPartyAnswer());
    try std.testing.expectEqual(@as(u32, 24), info.answer_id);
    try std.testing.expect(info.has_completion);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 5, .capability = 4 }, info.completion.?);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 5, .capability = 4 }, info.completionUsage().?);
    try std.testing.expect(info.matchesAnswer(24));
    try std.testing.expect(!info.matchesAnswer(25));
    try std.testing.expect(info.hasCompletionUsage());
    try std.testing.expect(info.completionMatchesCapability(4));
    try std.testing.expect(!info.completionMatchesCapability(3));
    try info.validate();

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
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 3, .capability = 2 }, info.completionUsage().?);
    try std.testing.expect(info.hasCompletionUsage());
    try std.testing.expect(info.completionMatchesCapability(2));
    try info.validate();
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

    const event = try support.decode(&builder);
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
    try std.testing.expect(info.matchesPromise(92));
    try std.testing.expect(!info.matchesPromise(91));
    try std.testing.expect(info.hasCap());
    try std.testing.expect(!info.hasException());
    try std.testing.expect(!info.isBroken());
    try std.testing.expect(info.isForwardableToCallTarget());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 93 }, info.forwardableCallTarget().?);
    try info.validate();
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_promise = 93 }, info.cap.?);
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
