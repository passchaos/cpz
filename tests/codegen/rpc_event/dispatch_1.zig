const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

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

test "rpc message helpers expose call method options only for calls" {
    const options = (cpz.rpc.CallOptions{})
        .withMethod(.{ .interface_id = 0x2468, .method_id = 12 })
        .withFlags(.{ .no_promise_pipelining = true });

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(88);
    try (try call.init_target()).set_importedCap(5);
    _ = try call.init_params();
    try cpz.rpc.writeCallOptionsToWire(options, call);

    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());
    try std.testing.expectEqual(cpz.rpc.WireMessageTag.call, try cpz.rpc.wireMessageTag(call_message));
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, (try cpz.rpc.callTargetFromWireMessage(call_message)).?);
    var owned_target = (try cpz.rpc.callTargetFromWireMessageAlloc(std.testing.allocator, call_message)).?;
    defer owned_target.deinit(std.testing.allocator);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, owned_target.asCallTarget());
    try std.testing.expectEqual(options.method, (try cpz.rpc.callMethodFromWireMessage(call_message)).?);
    try std.testing.expectEqual(options, (try cpz.rpc.callOptionsFromWireMessage(call_message)).?);
    try std.testing.expect(try options.method.matchesWireMessage(call_message));
    try std.testing.expect(try options.matchesWireMessage(call_message));
    const call_info = (try cpz.rpc.callInfoFromWireMessage(call_message)).?;
    try std.testing.expectEqual(@as(cpz.rpc.QuestionId, 88), call_info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, call_info.target);
    try std.testing.expectEqual(options, call_info.callOptions());
    try std.testing.expect(try call_info.matchesWireMessage(call_message));
    try std.testing.expectEqual(call_info, try cpz.rpc.callInfoFromWireCall(try call_message.call()));

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 89);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());
    try std.testing.expectEqual(cpz.rpc.WireMessageTag.bootstrap, try cpz.rpc.wireMessageTag(bootstrap_message));
    try std.testing.expect((try cpz.rpc.callTargetFromWireMessage(bootstrap_message)) == null);
    try std.testing.expect((try cpz.rpc.callTargetFromWireMessageAlloc(std.testing.allocator, bootstrap_message)) == null);
    try std.testing.expect((try cpz.rpc.callMethodFromWireMessage(bootstrap_message)) == null);
    try std.testing.expect((try cpz.rpc.callOptionsFromWireMessage(bootstrap_message)) == null);
    try std.testing.expect((try cpz.rpc.callInfoFromWireMessage(bootstrap_message)) == null);
    try std.testing.expect(!(try options.method.matchesWireMessage(bootstrap_message)));
    try std.testing.expect(!(try options.matchesWireMessage(bootstrap_message)));
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
    try std.testing.expect(method.matchesCallMethod(.{ .interface_id = 0xfeed_beef, .method_id = 42 }));
    try std.testing.expect(!method.matchesCallMethod(.{ .interface_id = 0xfeed_beef, .method_id = 41 }));
    try std.testing.expect(method.matchesWireCall(call_reader));
    try std.testing.expect(!(cpz.rpc.CallMethod{ .interface_id = 0xfeed_beef, .method_id = 41 }).matchesWireCall(call_reader));
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 42, 24 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 44, 66 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 4, 50 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 4, 58 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 45, 54 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 4, 62 });
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
    const first_method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 1 };
    const second_method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 2 };
    const entries = .{
        first_method.methodEntry(Handlers.first),
        second_method.methodEntry(Handlers.second),
    };
    const duplicate_entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 1 }, .handler = Handlers.first },
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0xabc, .method_id = 1 }, .handler = Handlers.second },
    };
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.validateCallMethodEntries(duplicate_entries));
    try std.testing.expectEqual(@as(?usize, 1), try entries[1].method.entryIndex(entries));
    try std.testing.expectEqual(entries[1].method, entries[1].callMethod());
    try std.testing.expect(entries[1].matches(0xabc, 2));
    try std.testing.expect(!entries[1].matches(0xabc, 3));
    try std.testing.expect(entries[1].matchesCallMethod(second_method));
    try std.testing.expect(!entries[1].matchesCallMethod(first_method));
    try std.testing.expectEqual(entries[1].method, entries[1].callOptions().method);
    const entry_call_info = entries[1].callInfo(211, .{ .imported_cap = 5 });
    try std.testing.expectEqual(@as(cpz.rpc.QuestionId, 211), entry_call_info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, entry_call_info.target);
    try std.testing.expectEqual(entries[1].method, entry_call_info.callMethod());
    try std.testing.expectEqual(entries[1].callOptions(), entry_call_info.callOptions());
    try std.testing.expectEqual(@as(?usize, 1), try entries[1].entryIndex(entries));
    try std.testing.expectEqual(@as(?usize, 0), try cpz.rpc.callMethodEntryIndex(entries[0].method, entries));
    try std.testing.expectEqual(@as(?usize, null), try cpz.rpc.callMethodEntryIndex(.{ .interface_id = 0xabc, .method_id = 3 }, entries));

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
        try std.testing.expectEqual(@as(?usize, 1), try cpz.rpc.callMethodFromWireCall(try request.call()).entryIndex(entries));
        try std.testing.expectEqual(@as(?usize, 1), try cpz.rpc.wireCallMethodEntryIndex(try request.call(), entries));
        try std.testing.expectEqual(@as(?usize, 1), try cpz.rpc.wireMessageMethodEntryIndex(request, entries));
        try std.testing.expect(entries[1].matchesWireCall(try request.call()));
        try std.testing.expect(!entries[0].matchesWireCall(try request.call()));
        try std.testing.expect(try entries[1].matchesWireMessage(request));
        try std.testing.expect(!(try entries[0].matchesWireMessage(request)));
        const preview_action = try state.wireCallServiceAction(try request.call(), entries);
        try std.testing.expect(preview_action.isDispatch());
        try std.testing.expect(preview_action.needsResponse());
        try std.testing.expect(!preview_action.needsForward());
        try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputRole.response, preview_action.outputRole());
        try std.testing.expectEqual(@as(usize, 1), preview_action.dispatch);
        var context: Context = .{};
        try cpz.rpc.dispatchCallMethods(&state, std.testing.allocator, response_root, try request.call(), &context, entries);
        try std.testing.expectEqual(@as(u32, 229), context.selected);
        try std.testing.expectEqual(@as(?usize, 1), try state.trackedCallMethodEntryIndex(29, entries));
        const action = (try state.trackedCallServiceAction(29, entries)).?;
        try std.testing.expect(action.isDispatch());
        try std.testing.expect(action.needsResponse());
        try std.testing.expectEqual(@as(usize, 1), action.dispatch);

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
        try std.testing.expectEqual(@as(?usize, null), try cpz.rpc.callMethodFromWireCall(try request.call()).entryIndex(entries));
        try std.testing.expectEqual(@as(?usize, null), try cpz.rpc.wireCallMethodEntryIndex(try request.call(), entries));
        try std.testing.expectEqual(@as(?usize, null), try cpz.rpc.wireMessageMethodEntryIndex(request, entries));
        const preview_action = try state.wireCallServiceAction(try request.call(), entries);
        try std.testing.expect(preview_action.isUnimplemented());
        try std.testing.expect(preview_action.needsResponse());
        try std.testing.expect(!preview_action.needsForward());
        try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputRole.response, preview_action.outputRole());
        var context: Context = .{};
        try cpz.rpc.dispatchCallMethods(&state, std.testing.allocator, response_root, try request.call(), &context, entries);
        try std.testing.expectEqual(@as(u32, 0), context.selected);
        try std.testing.expectEqual(@as(?usize, null), try state.trackedCallMethodEntryIndex(30, entries));
        try std.testing.expectEqual(@as(?usize, null), try state.trackedCallMethodEntryIndex(31, entries));
        const action = (try state.trackedCallServiceAction(30, entries)).?;
        try std.testing.expect(action.isUnimplemented());
        try std.testing.expect((try state.trackedCallServiceAction(31, entries)) == null);

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

test "rpc service action stats aggregate wire and tracked calls" {
    const Context = struct { selected: u32 = 0 };
    const Handler = struct {
        fn handle(context: *Context, call: anytype) !cpz.rpc.DispatchResult {
            context.selected = call.questionId();
            return .empty;
        }
    };
    const entries = .{
        .{ .method = cpz.rpc.CallMethod{ .interface_id = 0x4242, .method_id = 1 }, .handler = Handler.handle },
    };
    const PlanQueueItem = struct {
        plan: cpz.rpc.TrackedCallServiceActionPlan,
        message: generated.Message.Builder,
    };
    const PlanTaggedQueueItem = struct {
        plan: cpz.rpc.TrackedCallServiceActionPlan,
        position: cpz.rpc.TrackedCallServiceActionOutputPosition,
        message: generated.Message.Builder,
    };
    const Seed = struct {
        fn state() !cpz.rpc.State {
            var seeded = cpz.rpc.State.init(std.testing.allocator);
            errdefer seeded.deinit();
            try seeded.addImport(5);
            try seeded.applyCapDescriptor(.{ .sender_promise = 8 });
            try seeded.resolveImportTo(8, .{ .sender_hosted = 9 });
            try seeded.applyCapDescriptor(.{ .sender_hosted = 9 });
            return seeded;
        }
    };
    const QueueChecks = struct {
        fn expectPlanQueue(queue: []const PlanQueueItem, expected_sources: [3]usize) !void {
            try std.testing.expectEqual(@as(usize, 3), queue.len);
            try std.testing.expect(queue[0].plan.action.isDispatch());
            try std.testing.expectEqual(expected_sources[0], queue[0].plan.source_index);
            try std.testing.expectEqual(@as(u32, 71), try (try queue[0].message.get_return_()).get_answerId());
            try std.testing.expect(queue[1].plan.action.isUnimplemented());
            try std.testing.expectEqual(expected_sources[1], queue[1].plan.source_index);
            try std.testing.expectEqual(@as(u32, 72), try (try queue[1].message.get_return_()).get_answerId());
            try std.testing.expect(queue[2].plan.action.isForward());
            try std.testing.expectEqual(expected_sources[2], queue[2].plan.source_index);
            try std.testing.expectEqual(@as(u32, 73), try (try queue[2].message.get_call()).get_questionId());
        }

        fn expectSplitPlanQueues(response_queue: []const PlanQueueItem, forward_queue: []const PlanQueueItem, expected_response_sources: [2]usize, expected_forward_source: usize) !void {
            try std.testing.expectEqual(@as(usize, 2), response_queue.len);
            try std.testing.expect(response_queue[0].plan.action.isDispatch());
            try std.testing.expectEqual(expected_response_sources[0], response_queue[0].plan.source_index);
            try std.testing.expectEqual(@as(u32, 71), try (try response_queue[0].message.get_return_()).get_answerId());
            try std.testing.expect(response_queue[1].plan.action.isUnimplemented());
            try std.testing.expectEqual(expected_response_sources[1], response_queue[1].plan.source_index);
            try std.testing.expectEqual(@as(u32, 72), try (try response_queue[1].message.get_return_()).get_answerId());
            try std.testing.expectEqual(@as(usize, 1), forward_queue.len);
            try std.testing.expect(forward_queue[0].plan.action.isForward());
            try std.testing.expectEqual(expected_forward_source, forward_queue[0].plan.source_index);
            try std.testing.expectEqual(@as(u32, 73), try (try forward_queue[0].message.get_call()).get_questionId());
        }

        fn expectTaggedPlanQueue(queue: []const PlanTaggedQueueItem, expected_sources: [3]usize) !void {
            try std.testing.expectEqual(@as(usize, 3), queue.len);
            try std.testing.expect(queue[0].plan.action.isDispatch());
            try std.testing.expectEqual(expected_sources[0], queue[0].plan.source_index);
            try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, queue[0].position);
            try std.testing.expectEqual(@as(u32, 71), try (try queue[0].message.get_return_()).get_answerId());
            try std.testing.expect(queue[1].plan.action.isUnimplemented());
            try std.testing.expectEqual(expected_sources[1], queue[1].plan.source_index);
            try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, queue[1].position);
            try std.testing.expectEqual(@as(u32, 72), try (try queue[1].message.get_return_()).get_answerId());
            try std.testing.expect(queue[2].plan.action.isForward());
            try std.testing.expectEqual(expected_sources[2], queue[2].plan.source_index);
            try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, queue[2].position);
            try std.testing.expectEqual(@as(u32, 73), try (try queue[2].message.get_call()).get_questionId());
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);
    try state.applyCapDescriptor(.{ .sender_promise = 8 });
    try state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try state.applyCapDescriptor(.{ .sender_hosted = 9 });

    var dispatch_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer dispatch_builder.deinit();
    const dispatch_root = try generated.Message.initRootTyped(&dispatch_builder);
    {
        const call = try dispatch_root.init_call();
        try call.set_questionId(71);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x4242, .method_id = 1 }, call);
        try (try call.init_target()).set_importedCap(5);
        _ = try call.init_params();
    }
    var dispatch_reader = cpz.MessageReader.init(try dispatch_builder.segmentsConst(), .{});
    const dispatch_message = generated.Message.fromReader(try dispatch_reader.getRoot());
    const dispatch_call = try dispatch_message.call();

    var unimplemented_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unimplemented_builder.deinit();
    const unimplemented_root = try generated.Message.initRootTyped(&unimplemented_builder);
    {
        const call = try unimplemented_root.init_call();
        try call.set_questionId(72);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x4242, .method_id = 2 }, call);
        try (try call.init_target()).set_importedCap(5);
        _ = try call.init_params();
    }
    var unimplemented_reader = cpz.MessageReader.init(try unimplemented_builder.segmentsConst(), .{});
    const unimplemented_message = generated.Message.fromReader(try unimplemented_reader.getRoot());
    const unimplemented_call = try unimplemented_message.call();

    var forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forward_builder.deinit();
    const forward_root = try generated.Message.initRootTyped(&forward_builder);
    {
        const call = try forward_root.init_call();
        try call.set_questionId(73);
        try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x4242, .method_id = 1 }, call);
        try (try call.init_target()).set_importedCap(8);
        _ = try call.init_params();
    }
    var forward_reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
    const forward_message = generated.Message.fromReader(try forward_reader.getRoot());
    const forward_call = try forward_message.call();

    const calls = [_]@TypeOf(dispatch_call){ dispatch_call, unimplemented_call, forward_call };

    var bootstrap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer bootstrap_builder.deinit();
    const bootstrap_root = try generated.Message.initRootTyped(&bootstrap_builder);
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 74);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    try cpz.rpc.initEmptyReturnMessage(return_root, 75, false, true);
    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_message = generated.Message.fromReader(try return_reader.getRoot());

    const messages = [_]generated.Message{ dispatch_message, bootstrap_message, unimplemented_message, forward_message, return_message };
    const dispatch_message_info = (try state.wireMessageDispatchInfo(messages[0])).?;
    try std.testing.expectEqual(@as(cpz.rpc.QuestionId, 71), dispatch_message_info.info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x4242, .method_id = 1 }, dispatch_message_info.info.callMethod());
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, (try state.wireMessageDispatchOutcome(messages[0])).?);
    const dispatch_message_action = (try state.wireMessageServiceAction(messages[0], entries)).?;
    try std.testing.expect(dispatch_message_action.isDispatch());
    try std.testing.expectEqual(@as(usize, 0), dispatch_message_action.dispatch);
    try std.testing.expect((try state.wireMessageDispatchInfo(messages[1])) == null);
    try std.testing.expect((try state.wireMessageDispatchOutcome(messages[1])) == null);
    try std.testing.expect((try state.wireMessageServiceAction(messages[1], entries)) == null);
    try std.testing.expect((try cpz.rpc.wireMessageMethodEntryIndex(messages[1], entries)) == null);
    const message_stats = try state.wireMessageServiceActionStats(messages[0..], entries);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionStats{
        .dispatch = 1,
        .forward = 1,
        .unimplemented = 1,
        .skipped = 2,
    }, message_stats);
    try std.testing.expectEqual(@as(usize, 3), message_stats.actions());
    try std.testing.expectEqual(@as(usize, 5), message_stats.total());
    try std.testing.expect(message_stats.hasActions());
    try std.testing.expect(message_stats.hasResponses());
    try std.testing.expect(message_stats.hasForwards());
    try std.testing.expect(message_stats.hasGaps());
    const message_action_stats = cpz.rpc.TrackedCallServiceActionStats{
        .dispatch = 1,
        .forward = 1,
        .unimplemented = 1,
    };
    try std.testing.expect(message_action_stats.hasActions());
    try std.testing.expect(!message_action_stats.hasGaps());
    var message_plans: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectEqual(message_stats, try state.initWireMessageServiceActionPlans(messages[0..], entries, message_plans[0..]));
    try std.testing.expectEqual(@as(usize, 0), message_plans[0].source_index);
    try std.testing.expectEqual(@as(u32, 71), message_plans[0].question_id);
    try std.testing.expect(message_plans[0].matchesSource(0, 71));
    try std.testing.expect(message_plans[0].needsResponse());
    try std.testing.expect(!message_plans[0].needsForward());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputRole.response, message_plans[0].outputRole());
    try std.testing.expectEqual(@as(usize, 3), message_plans[1].source_index);
    try std.testing.expectEqual(@as(u32, 73), message_plans[1].question_id);
    try std.testing.expect(message_plans[1].matchesSource(3, 73));
    try std.testing.expect(!message_plans[1].needsResponse());
    try std.testing.expect(message_plans[1].needsForward());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputRole.forward, message_plans[1].outputRole());
    try std.testing.expectEqual(@as(usize, 2), message_plans[2].source_index);
    try std.testing.expectEqual(@as(u32, 72), message_plans[2].question_id);
    try std.testing.expect(message_plans[2].matchesSource(2, 72));
    try std.testing.expect(message_plans[2].needsResponse());
    var message_actions: [3]cpz.rpc.TrackedCallServiceAction = undefined;
    try std.testing.expectEqual(message_stats, try state.initWireMessageServiceActions(messages[0..], entries, message_actions[0..]));
    try std.testing.expectEqual(@as(usize, 0), message_actions[0].dispatch);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, message_actions[1].forward);
    try std.testing.expect(message_actions[2].isUnimplemented());
    var short_message_plans: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, state.initWireMessageServiceActionPlans(messages[0..], entries, short_message_plans[0..]));
    var short_message_actions: [2]cpz.rpc.TrackedCallServiceAction = undefined;
    try std.testing.expectError(error.InvalidTransition, state.initWireMessageServiceActions(messages[0..], entries, short_message_actions[0..]));

    var message_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_wrapper_state.deinit();
    try message_wrapper_state.addImport(5);
    try message_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_output_builder0.deinit();
    const message_output0 = try generated.Message.initRootTyped(&message_output_builder0);
    var message_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_output_builder1.deinit();
    const message_output1 = try generated.Message.initRootTyped(&message_output_builder1);
    var message_output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_output_builder2.deinit();
    const message_output2 = try generated.Message.initRootTyped(&message_output_builder2);
    const message_outputs = [_]generated.Message.Builder{ message_output0, message_output1, message_output2 };
    var message_context: Context = .{};
    try std.testing.expectError(error.InvalidTransition, message_wrapper_state.dispatchWireMessageServiceActionsUnified(std.testing.allocator, messages[0..], entries, short_message_plans[0..], message_outputs[0..], &message_context));
    try std.testing.expectEqual(
        message_stats,
        try message_wrapper_state.dispatchWireMessageServiceActionsUnified(std.testing.allocator, messages[0..], entries, message_plan_buffer[0..], message_outputs[0..], &message_context),
    );
    try std.testing.expectEqual(@as(u32, 71), message_context.selected);
    var message_output_reader0 = cpz.MessageReader.init(try message_output_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 71), (try generated.Message.fromReader(try message_output_reader0.getRoot()).return_()).answerId());
    var message_output_reader1 = cpz.MessageReader.init(try message_output_builder1.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 72), (try generated.Message.fromReader(try message_output_reader1.getRoot()).return_()).answerId());
    var message_output_reader2 = cpz.MessageReader.init(try message_output_builder2.segmentsConst(), .{});
    const message_forward_call = try generated.Message.fromReader(try message_output_reader2.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 73), message_forward_call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, try cpz.rpc.callTargetFromWireCall(message_forward_call));

    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, cpz.rpc.trackedCallServiceActionUnifiedOutputPosition(message_stats, 0).?);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, cpz.rpc.trackedCallServiceActionUnifiedOutputPosition(message_stats, 1).?);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, cpz.rpc.trackedCallServiceActionUnifiedOutputPosition(message_stats, 2).?);
    try std.testing.expect(cpz.rpc.trackedCallServiceActionUnifiedOutputPosition(message_stats, 3) == null);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, message_stats.unifiedOutputPosition(0).?);
    try std.testing.expectEqual(@as(?usize, 1), message_stats.responseLocalIndex(1));
    try std.testing.expectEqual(@as(?usize, null), message_stats.responseLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, 0), message_stats.forwardLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), message_stats.forwardLocalIndex(3));
    const message_response_position = message_stats.unifiedOutputPosition(0).?;
    try std.testing.expect(message_response_position.isResponse());
    try std.testing.expect(!message_response_position.isForward());
    const message_forward_position = message_stats.unifiedOutputPosition(2).?;
    try std.testing.expect(message_forward_position.isForward());
    try std.testing.expect(!message_forward_position.isResponse());
    try std.testing.expectEqual(@as(?usize, 0), message_stats.outputIndex(message_response_position));
    try std.testing.expectEqual(@as(?usize, 2), message_stats.outputIndex(message_forward_position));
    try std.testing.expectEqual(@as(?usize, 1), message_stats.responseOutputIndex(1));
    try std.testing.expectEqual(@as(?usize, null), message_stats.responseOutputIndex(2));
    try std.testing.expectEqual(@as(?usize, 2), message_stats.forwardOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), message_stats.forwardOutputIndex(1));
    var message_indexed_output_stats: cpz.rpc.RpcOutputStats = .{};
    try message_indexed_output_stats.recordServiceActionOutputIndex(message_stats, 0);
    try message_indexed_output_stats.recordServiceActionOutputIndex(message_stats, 1);
    try message_indexed_output_stats.recordServiceActionOutputIndex(message_stats, 2);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, message_indexed_output_stats);
    try std.testing.expectError(error.InvalidTransition, message_indexed_output_stats.recordServiceActionOutputIndex(message_stats, 3));
    const MessageTaggedSink = struct {
        sent: usize = 0,
        response_local_sum: usize = 0,
        forward_local_sum: usize = 0,
        stats: cpz.rpc.RpcOutputStats = .{},

        fn handle(context: *@This(), position: cpz.rpc.TrackedCallServiceActionOutputPosition, message: anytype) !void {
            context.stats.recordServiceActionPosition(position);
            switch (context.sent) {
                0 => {
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, position);
                    try std.testing.expectEqual(@as(u32, 71), try (try message.get_return_()).get_answerId());
                    context.response_local_sum += position.local_index;
                },
                1 => {
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, position);
                    try std.testing.expectEqual(@as(u32, 72), try (try message.get_return_()).get_answerId());
                    context.response_local_sum += position.local_index;
                },
                2 => {
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, position);
                    try std.testing.expectEqual(@as(u32, 73), try (try message.get_call()).get_questionId());
                    context.forward_local_sum += position.local_index;
                },
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };
    var message_tagged_sink: MessageTaggedSink = .{};
    const message_tagged_stats = try cpz.rpc.sendRpcServiceActionUnifiedOutputsToTaggedSinkStats(message_stats, message_outputs[0..], &message_tagged_sink, MessageTaggedSink.handle);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, message_tagged_stats);
    try std.testing.expectEqual(message_tagged_stats, cpz.rpc.RpcOutputStats.fromServiceActionStats(message_stats));
    try std.testing.expect(message_tagged_stats.matchesServiceActionStats(message_stats));
    try message_tagged_stats.validateAgainstServiceActionStats(message_stats);
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1 }).validateAgainstServiceActionStats(message_stats));
    try std.testing.expectEqual(@as(usize, 3), message_tagged_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1), message_tagged_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), message_tagged_sink.forward_local_sum);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, message_tagged_sink.stats);

    const ServiceTaggedQueueItem = struct {
        position: cpz.rpc.TrackedCallServiceActionOutputPosition,
        message: generated.Message.Builder,
    };
    var service_tagged_queue = std.ArrayList(ServiceTaggedQueueItem).empty;
    defer service_tagged_queue.deinit(std.testing.allocator);
    const service_tagged_queue_stats = try cpz.rpc.appendRpcServiceActionUnifiedOutputsToTaggedQueue(std.testing.allocator, message_stats, message_outputs[0..], &service_tagged_queue);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, service_tagged_queue_stats);
    try service_tagged_queue_stats.validateAgainstServiceActionStats(message_stats);
    try std.testing.expectEqual(@as(usize, 3), service_tagged_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, service_tagged_queue.items[0].position);
    try std.testing.expectEqual(@as(u32, 71), try (try service_tagged_queue.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, service_tagged_queue.items[1].position);
    try std.testing.expectEqual(@as(u32, 72), try (try service_tagged_queue.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, service_tagged_queue.items[2].position);
    try std.testing.expectEqual(@as(u32, 73), try (try service_tagged_queue.items[2].message.get_call()).get_questionId());
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcServiceActionUnifiedOutputsToTaggedQueue(std.testing.allocator, message_stats, message_outputs[0..2], &service_tagged_queue));

    const MessageBasicUnifiedSink = struct {
        sent: usize = 0,

        fn handle(context: *@This(), message: anytype) !void {
            _ = try message.which();
            context.sent += 1;
        }
    };
    var message_basic_unified_sink: MessageBasicUnifiedSink = .{};
    try std.testing.expectEqual(
        cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 },
        try cpz.rpc.sendRpcServiceActionUnifiedOutputsToSinkStats(message_stats, message_outputs[0..], &message_basic_unified_sink, MessageBasicUnifiedSink.handle),
    );
    try std.testing.expectEqual(@as(usize, 3), message_basic_unified_sink.sent);

    var service_output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer service_output_queue.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 },
        try cpz.rpc.appendRpcServiceActionUnifiedOutputsToQueue(std.testing.allocator, message_stats, message_outputs[0..], &service_output_queue),
    );
    try std.testing.expectEqual(@as(usize, 3), service_output_queue.items.len);

    var service_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer service_response_queue.deinit(std.testing.allocator);
    var service_forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer service_forward_queue.deinit(std.testing.allocator);
    const service_split_queue_stats = try cpz.rpc.appendRpcServiceActionUnifiedOutputsToQueues(
        std.testing.allocator,
        message_stats,
        message_outputs[0..],
        &service_response_queue,
        &service_forward_queue,
    );
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, service_split_queue_stats);
    try service_split_queue_stats.validateAgainstServiceActionStats(message_stats);
    try std.testing.expectEqual(@as(usize, 2), service_response_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try service_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try service_response_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(usize, 1), service_forward_queue.items.len);
    try std.testing.expectEqual(@as(u32, 73), try (try service_forward_queue.items[0].get_call()).get_questionId());
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcServiceActionUnifiedOutputsToQueues(
        std.testing.allocator,
        message_stats,
        message_outputs[0..2],
        &service_response_queue,
        &service_forward_queue,
    ));

    const MessageRoleResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    const MessageRoleForwardSink = struct {
        sent: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.question_sum += try (try message.get_call()).get_questionId();
        }
    };
    var message_role_response_sink: MessageRoleResponseSink = .{};
    var message_role_forward_sink: MessageRoleForwardSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcServiceActionUnifiedOutputsToSinks(
        message_stats,
        message_outputs[0..2],
        &message_role_response_sink,
        MessageRoleResponseSink.handle,
        &message_role_forward_sink,
        MessageRoleForwardSink.handle,
    ));
    const message_split_stats = try cpz.rpc.sendRpcServiceActionUnifiedOutputsToSinksStats(
        message_stats,
        message_outputs[0..],
        &message_role_response_sink,
        MessageRoleResponseSink.handle,
        &message_role_forward_sink,
        MessageRoleForwardSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, message_split_stats);
    try std.testing.expectEqual(@as(usize, 2), message_role_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_role_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), message_role_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), message_role_forward_sink.question_sum);

    var message_role_plan_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_role_plan_state.deinit();
    try message_role_plan_state.addImport(5);
    try message_role_plan_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_role_plan_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_role_plan_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_role_plan_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_role_plan_builder0.deinit();
    const message_role_plan_output0 = try generated.Message.initRootTyped(&message_role_plan_builder0);
    var message_role_plan_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_role_plan_builder1.deinit();
    const message_role_plan_output1 = try generated.Message.initRootTyped(&message_role_plan_builder1);
    var message_role_plan_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_role_plan_builder2.deinit();
    const message_role_plan_output2 = try generated.Message.initRootTyped(&message_role_plan_builder2);
    const message_role_plan_outputs = [_]generated.Message.Builder{ message_role_plan_output0, message_role_plan_output1, message_role_plan_output2 };
    var message_role_plan_context: Context = .{};
    var message_role_plan_response_sink: MessageRoleResponseSink = .{};
    var message_role_plan_forward_sink: MessageRoleForwardSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToSinks(
        &message_role_plan_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_role_plan_outputs[0..2],
        &message_role_plan_context,
        entries,
        &message_role_plan_response_sink,
        MessageRoleResponseSink.handle,
        &message_role_plan_forward_sink,
        MessageRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToSinks(
        &message_role_plan_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_role_plan_outputs[0..],
        &message_role_plan_context,
        entries,
        &message_role_plan_response_sink,
        MessageRoleResponseSink.handle,
        &message_role_plan_forward_sink,
        MessageRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_role_plan_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_role_plan_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_role_plan_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), message_role_plan_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), message_role_plan_forward_sink.question_sum);

    var message_direct_output_queue_state = try Seed.state();
    defer message_direct_output_queue_state.deinit();
    var message_direct_output_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_output_queue_builder0.deinit();
    const message_direct_output_queue_output0 = try generated.Message.initRootTyped(&message_direct_output_queue_builder0);
    var message_direct_output_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_output_queue_builder1.deinit();
    const message_direct_output_queue_output1 = try generated.Message.initRootTyped(&message_direct_output_queue_builder1);
    var message_direct_output_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_output_queue_builder2.deinit();
    const message_direct_output_queue_output2 = try generated.Message.initRootTyped(&message_direct_output_queue_builder2);
    const message_direct_output_queue_outputs = [_]generated.Message.Builder{ message_direct_output_queue_output0, message_direct_output_queue_output1, message_direct_output_queue_output2 };
    var message_direct_output_queue_context: Context = .{};
    var message_direct_output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer message_direct_output_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToQueue(
        &message_direct_output_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_output_queue_outputs[0..2],
        &message_direct_output_queue_context,
        entries,
        &message_direct_output_queue,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToQueue(
        &message_direct_output_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_output_queue_outputs[0..],
        &message_direct_output_queue_context,
        entries,
        &message_direct_output_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_output_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_direct_output_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try message_direct_output_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try message_direct_output_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try message_direct_output_queue.items[2].get_call()).get_questionId());

    var message_direct_output_split_queue_state = try Seed.state();
    defer message_direct_output_split_queue_state.deinit();
    var message_direct_output_split_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_output_split_queue_builder0.deinit();
    const message_direct_output_split_queue_output0 = try generated.Message.initRootTyped(&message_direct_output_split_queue_builder0);
    var message_direct_output_split_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_output_split_queue_builder1.deinit();
    const message_direct_output_split_queue_output1 = try generated.Message.initRootTyped(&message_direct_output_split_queue_builder1);
    var message_direct_output_split_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_output_split_queue_builder2.deinit();
    const message_direct_output_split_queue_output2 = try generated.Message.initRootTyped(&message_direct_output_split_queue_builder2);
    const message_direct_output_split_queue_outputs = [_]generated.Message.Builder{ message_direct_output_split_queue_output0, message_direct_output_split_queue_output1, message_direct_output_split_queue_output2 };
    var message_direct_output_split_queue_context: Context = .{};
    var message_direct_output_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer message_direct_output_response_queue.deinit(std.testing.allocator);
    var message_direct_output_forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer message_direct_output_forward_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToQueues(
        &message_direct_output_split_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_output_split_queue_outputs[0..2],
        &message_direct_output_split_queue_context,
        entries,
        &message_direct_output_response_queue,
        &message_direct_output_forward_queue,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToQueues(
        &message_direct_output_split_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_output_split_queue_outputs[0..],
        &message_direct_output_split_queue_context,
        entries,
        &message_direct_output_response_queue,
        &message_direct_output_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_output_split_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_direct_output_response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), message_direct_output_forward_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try message_direct_output_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try message_direct_output_response_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try message_direct_output_forward_queue.items[0].get_call()).get_questionId());

    var message_role_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_role_wrapper_state.deinit();
    try message_role_wrapper_state.addImport(5);
    try message_role_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_role_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_role_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_role_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_role_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_role_wrapper_builder0.deinit();
    const message_role_wrapper_output0 = try generated.Message.initRootTyped(&message_role_wrapper_builder0);
    var message_role_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_role_wrapper_builder1.deinit();
    const message_role_wrapper_output1 = try generated.Message.initRootTyped(&message_role_wrapper_builder1);
    var message_role_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_role_wrapper_builder2.deinit();
    const message_role_wrapper_output2 = try generated.Message.initRootTyped(&message_role_wrapper_builder2);
    const message_role_wrapper_outputs = [_]generated.Message.Builder{ message_role_wrapper_output0, message_role_wrapper_output1, message_role_wrapper_output2 };
    var message_role_wrapper_context: Context = .{};
    var message_role_wrapper_response_sink: MessageRoleResponseSink = .{};
    var message_role_wrapper_forward_sink: MessageRoleForwardSink = .{};
    var message_role_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_role_wrapper_state.dispatchWireMessageServiceActionsUnifiedToSinks(
        std.testing.allocator,
        messages[0..],
        entries,
        message_role_wrapper_short_plan_buffer[0..],
        message_role_wrapper_outputs[0..],
        &message_role_wrapper_context,
        &message_role_wrapper_response_sink,
        MessageRoleResponseSink.handle,
        &message_role_wrapper_forward_sink,
        MessageRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_role_wrapper_state.dispatchWireMessageServiceActionsUnifiedToSinks(
        std.testing.allocator,
        messages[0..],
        entries,
        message_role_wrapper_plan_buffer[0..],
        message_role_wrapper_outputs[0..],
        &message_role_wrapper_context,
        &message_role_wrapper_response_sink,
        MessageRoleResponseSink.handle,
        &message_role_wrapper_forward_sink,
        MessageRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_role_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_role_wrapper_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_role_wrapper_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), message_role_wrapper_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), message_role_wrapper_forward_sink.question_sum);

    var message_tagged_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_tagged_state.deinit();
    try message_tagged_state.addImport(5);
    try message_tagged_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_tagged_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_tagged_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_tagged_plan_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_tagged_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_builder0.deinit();
    const message_tagged_output0 = try generated.Message.initRootTyped(&message_tagged_builder0);
    var message_tagged_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_builder1.deinit();
    const message_tagged_output1 = try generated.Message.initRootTyped(&message_tagged_builder1);
    var message_tagged_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_builder2.deinit();
    const message_tagged_output2 = try generated.Message.initRootTyped(&message_tagged_builder2);
    const message_tagged_outputs = [_]generated.Message.Builder{ message_tagged_output0, message_tagged_output1, message_tagged_output2 };
    var message_tagged_context: Context = .{};
    var message_tagged_wrapper_sink: MessageTaggedSink = .{};
    try std.testing.expectError(error.InvalidTransition, message_tagged_state.dispatchWireMessageServiceActionsUnifiedToTaggedSink(
        std.testing.allocator,
        messages[0..],
        entries,
        short_message_plans[0..],
        message_tagged_outputs[0..],
        &message_tagged_context,
        &message_tagged_wrapper_sink,
        MessageTaggedSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_tagged_state.dispatchWireMessageServiceActionsUnifiedToTaggedSink(
        std.testing.allocator,
        messages[0..],
        entries,
        message_tagged_plan_plan_buffer[0..],
        message_tagged_outputs[0..],
        &message_tagged_context,
        &message_tagged_wrapper_sink,
        MessageTaggedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_tagged_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_tagged_wrapper_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1), message_tagged_wrapper_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), message_tagged_wrapper_sink.forward_local_sum);

    var message_direct_tagged_output_queue_state = try Seed.state();
    defer message_direct_tagged_output_queue_state.deinit();
    var message_direct_tagged_output_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_output_queue_builder0.deinit();
    const message_direct_tagged_output_queue_output0 = try generated.Message.initRootTyped(&message_direct_tagged_output_queue_builder0);
    var message_direct_tagged_output_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_output_queue_builder1.deinit();
    const message_direct_tagged_output_queue_output1 = try generated.Message.initRootTyped(&message_direct_tagged_output_queue_builder1);
    var message_direct_tagged_output_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_output_queue_builder2.deinit();
    const message_direct_tagged_output_queue_output2 = try generated.Message.initRootTyped(&message_direct_tagged_output_queue_builder2);
    const message_direct_tagged_output_queue_outputs = [_]generated.Message.Builder{ message_direct_tagged_output_queue_output0, message_direct_tagged_output_queue_output1, message_direct_tagged_output_queue_output2 };
    var message_direct_tagged_output_queue_context: Context = .{};
    var message_direct_tagged_output_queue = std.ArrayList(ServiceTaggedQueueItem).empty;
    defer message_direct_tagged_output_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToTaggedQueue(
        &message_direct_tagged_output_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_tagged_output_queue_outputs[0..2],
        &message_direct_tagged_output_queue_context,
        entries,
        &message_direct_tagged_output_queue,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToTaggedQueue(
        &message_direct_tagged_output_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_tagged_output_queue_outputs[0..],
        &message_direct_tagged_output_queue_context,
        entries,
        &message_direct_tagged_output_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_tagged_output_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_direct_tagged_output_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, message_direct_tagged_output_queue.items[0].position);
    try std.testing.expectEqual(@as(u32, 71), try (try message_direct_tagged_output_queue.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, message_direct_tagged_output_queue.items[1].position);
    try std.testing.expectEqual(@as(u32, 72), try (try message_direct_tagged_output_queue.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, message_direct_tagged_output_queue.items[2].position);
    try std.testing.expectEqual(@as(u32, 73), try (try message_direct_tagged_output_queue.items[2].message.get_call()).get_questionId());

    const MessageUnifiedSink = struct {
        sent: usize = 0,
        responses: usize = 0,
        forwards: usize = 0,
        answer_sum: u32 = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            switch ((try message.which()).?) {
                .return_ => {
                    context.responses += 1;
                    context.answer_sum += try (try message.get_return_()).get_answerId();
                },
                .call => {
                    context.forwards += 1;
                    context.question_sum += try (try message.get_call()).get_questionId();
                },
                else => return error.TestUnexpectedResult,
            }
        }
    };
    var message_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_sink_state.deinit();
    try message_sink_state.addImport(5);
    try message_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_sink_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_sink_builder0.deinit();
    const message_sink_output0 = try generated.Message.initRootTyped(&message_sink_builder0);
    var message_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_sink_builder1.deinit();
    const message_sink_output1 = try generated.Message.initRootTyped(&message_sink_builder1);
    var message_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_sink_builder2.deinit();
    const message_sink_output2 = try generated.Message.initRootTyped(&message_sink_builder2);
    const message_sink_outputs = [_]generated.Message.Builder{ message_sink_output0, message_sink_output1, message_sink_output2 };
    var message_sink_context: Context = .{};
    var message_unified_sink: MessageUnifiedSink = .{};
    try std.testing.expectError(error.InvalidTransition, message_sink_state.dispatchWireMessageServiceActionsUnifiedToSink(
        std.testing.allocator,
        messages[0..],
        entries,
        short_message_plans[0..],
        message_sink_outputs[0..],
        &message_sink_context,
        &message_unified_sink,
        MessageUnifiedSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_sink_state.dispatchWireMessageServiceActionsUnifiedToSink(
        std.testing.allocator,
        messages[0..],
        entries,
        message_sink_plan_buffer[0..],
        message_sink_outputs[0..],
        &message_sink_context,
        &message_unified_sink,
        MessageUnifiedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_unified_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), message_unified_sink.responses);
    try std.testing.expectEqual(@as(usize, 1), message_unified_sink.forwards);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_unified_sink.answer_sum);
    try std.testing.expectEqual(@as(u32, 73), message_unified_sink.question_sum);

    var message_output_queue_wrapper_state = try Seed.state();
    defer message_output_queue_wrapper_state.deinit();
    var message_output_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_output_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_output_queue_wrapper_builder0.deinit();
    const message_output_queue_wrapper_output0 = try generated.Message.initRootTyped(&message_output_queue_wrapper_builder0);
    var message_output_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_output_queue_wrapper_builder1.deinit();
    const message_output_queue_wrapper_output1 = try generated.Message.initRootTyped(&message_output_queue_wrapper_builder1);
    var message_output_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_output_queue_wrapper_builder2.deinit();
    const message_output_queue_wrapper_output2 = try generated.Message.initRootTyped(&message_output_queue_wrapper_builder2);
    const message_output_queue_wrapper_outputs = [_]generated.Message.Builder{ message_output_queue_wrapper_output0, message_output_queue_wrapper_output1, message_output_queue_wrapper_output2 };
    var message_output_queue_wrapper_context: Context = .{};
    var message_output_queue_wrapper = std.ArrayList(generated.Message.Builder).empty;
    defer message_output_queue_wrapper.deinit(std.testing.allocator);
    var message_output_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_output_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedToQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_output_queue_wrapper_short_plan_buffer[0..],
        message_output_queue_wrapper_outputs[0..],
        &message_output_queue_wrapper_context,
        &message_output_queue_wrapper,
    ));
    try std.testing.expectEqual(message_stats, try message_output_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedToQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_output_queue_wrapper_plan_buffer[0..],
        message_output_queue_wrapper_outputs[0..],
        &message_output_queue_wrapper_context,
        &message_output_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_output_queue_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_output_queue_wrapper.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try message_output_queue_wrapper.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try message_output_queue_wrapper.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try message_output_queue_wrapper.items[2].get_call()).get_questionId());

    var message_split_output_queue_wrapper_state = try Seed.state();
    defer message_split_output_queue_wrapper_state.deinit();
    var message_split_output_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_split_output_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_output_queue_wrapper_builder0.deinit();
    const message_split_output_queue_wrapper_output0 = try generated.Message.initRootTyped(&message_split_output_queue_wrapper_builder0);
    var message_split_output_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_output_queue_wrapper_builder1.deinit();
    const message_split_output_queue_wrapper_output1 = try generated.Message.initRootTyped(&message_split_output_queue_wrapper_builder1);
    var message_split_output_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_output_queue_wrapper_builder2.deinit();
    const message_split_output_queue_wrapper_output2 = try generated.Message.initRootTyped(&message_split_output_queue_wrapper_builder2);
    const message_split_output_queue_wrapper_outputs = [_]generated.Message.Builder{ message_split_output_queue_wrapper_output0, message_split_output_queue_wrapper_output1, message_split_output_queue_wrapper_output2 };
    var message_split_output_queue_wrapper_context: Context = .{};
    var message_output_wrapper_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer message_output_wrapper_response_queue.deinit(std.testing.allocator);
    var message_output_wrapper_forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer message_output_wrapper_forward_queue.deinit(std.testing.allocator);
    var message_split_output_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_split_output_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedToQueues(
        std.testing.allocator,
        messages[0..],
        entries,
        message_split_output_queue_wrapper_short_plan_buffer[0..],
        message_split_output_queue_wrapper_outputs[0..],
        &message_split_output_queue_wrapper_context,
        &message_output_wrapper_response_queue,
        &message_output_wrapper_forward_queue,
    ));
    try std.testing.expectEqual(message_stats, try message_split_output_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedToQueues(
        std.testing.allocator,
        messages[0..],
        entries,
        message_split_output_queue_wrapper_plan_buffer[0..],
        message_split_output_queue_wrapper_outputs[0..],
        &message_split_output_queue_wrapper_context,
        &message_output_wrapper_response_queue,
        &message_output_wrapper_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_split_output_queue_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_output_wrapper_response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), message_output_wrapper_forward_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try message_output_wrapper_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try message_output_wrapper_response_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try message_output_wrapper_forward_queue.items[0].get_call()).get_questionId());

    var message_tagged_output_queue_wrapper_state = try Seed.state();
    defer message_tagged_output_queue_wrapper_state.deinit();
    var message_tagged_output_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_tagged_output_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_output_queue_wrapper_builder0.deinit();
    const message_tagged_output_queue_wrapper_output0 = try generated.Message.initRootTyped(&message_tagged_output_queue_wrapper_builder0);
    var message_tagged_output_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_output_queue_wrapper_builder1.deinit();
    const message_tagged_output_queue_wrapper_output1 = try generated.Message.initRootTyped(&message_tagged_output_queue_wrapper_builder1);
    var message_tagged_output_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_output_queue_wrapper_builder2.deinit();
    const message_tagged_output_queue_wrapper_output2 = try generated.Message.initRootTyped(&message_tagged_output_queue_wrapper_builder2);
    const message_tagged_output_queue_wrapper_outputs = [_]generated.Message.Builder{ message_tagged_output_queue_wrapper_output0, message_tagged_output_queue_wrapper_output1, message_tagged_output_queue_wrapper_output2 };
    var message_tagged_output_queue_wrapper_context: Context = .{};
    var message_tagged_output_queue_wrapper = std.ArrayList(ServiceTaggedQueueItem).empty;
    defer message_tagged_output_queue_wrapper.deinit(std.testing.allocator);
    var message_tagged_output_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_tagged_output_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedToTaggedQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_tagged_output_queue_wrapper_short_plan_buffer[0..],
        message_tagged_output_queue_wrapper_outputs[0..],
        &message_tagged_output_queue_wrapper_context,
        &message_tagged_output_queue_wrapper,
    ));
    try std.testing.expectEqual(message_stats, try message_tagged_output_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedToTaggedQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_tagged_output_queue_wrapper_plan_buffer[0..],
        message_tagged_output_queue_wrapper_outputs[0..],
        &message_tagged_output_queue_wrapper_context,
        &message_tagged_output_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_tagged_output_queue_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_tagged_output_queue_wrapper.items.len);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, message_tagged_output_queue_wrapper.items[0].position);
    try std.testing.expectEqual(@as(u32, 71), try (try message_tagged_output_queue_wrapper.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, message_tagged_output_queue_wrapper.items[1].position);
    try std.testing.expectEqual(@as(u32, 72), try (try message_tagged_output_queue_wrapper.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, message_tagged_output_queue_wrapper.items[2].position);
    try std.testing.expectEqual(@as(u32, 73), try (try message_tagged_output_queue_wrapper.items[2].message.get_call()).get_questionId());

    const MessagePlanSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, message: anytype) !void {
            context.source_sum += plan.source_index;
            context.question_sum += plan.question_id;
            switch (context.sent) {
                0 => {
                    try std.testing.expect(plan.action.isDispatch());
                    try std.testing.expectEqual(@as(usize, 0), plan.source_index);
                    try std.testing.expectEqual(@as(u32, 71), try (try message.get_return_()).get_answerId());
                },
                1 => {
                    try std.testing.expect(plan.action.isUnimplemented());
                    try std.testing.expectEqual(@as(usize, 2), plan.source_index);
                    try std.testing.expectEqual(@as(u32, 72), try (try message.get_return_()).get_answerId());
                },
                2 => {
                    try std.testing.expect(plan.action.isForward());
                    try std.testing.expectEqual(@as(usize, 3), plan.source_index);
                    try std.testing.expectEqual(@as(u32, 73), try (try message.get_call()).get_questionId());
                },
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };
    var message_plan_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_plan_sink_state.deinit();
    try message_plan_sink_state.addImport(5);
    try message_plan_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_plan_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_plan_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_plan_sink_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_plan_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_sink_builder0.deinit();
    const message_plan_sink_output0 = try generated.Message.initRootTyped(&message_plan_sink_builder0);
    var message_plan_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_sink_builder1.deinit();
    const message_plan_sink_output1 = try generated.Message.initRootTyped(&message_plan_sink_builder1);
    var message_plan_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_sink_builder2.deinit();
    const message_plan_sink_output2 = try generated.Message.initRootTyped(&message_plan_sink_builder2);
    const message_plan_sink_outputs = [_]generated.Message.Builder{ message_plan_sink_output0, message_plan_sink_output1, message_plan_sink_output2 };
    var message_plan_sink_context: Context = .{};
    var message_plan_sink: MessagePlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, message_plan_sink_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToSink(
        std.testing.allocator,
        messages[0..],
        entries,
        short_message_plans[0..],
        message_plan_sink_outputs[0..],
        &message_plan_sink_context,
        &message_plan_sink,
        MessagePlanSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_plan_sink_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToSink(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_sink_plan_buffer[0..],
        message_plan_sink_outputs[0..],
        &message_plan_sink_context,
        &message_plan_sink,
        MessagePlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_plan_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 2 + 3), message_plan_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72 + 73), message_plan_sink.question_sum);

    var message_plan_queue_wrapper_state = try Seed.state();
    defer message_plan_queue_wrapper_state.deinit();
    var message_plan_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_plan_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_queue_wrapper_builder0.deinit();
    const message_plan_queue_wrapper_output0 = try generated.Message.initRootTyped(&message_plan_queue_wrapper_builder0);
    var message_plan_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_queue_wrapper_builder1.deinit();
    const message_plan_queue_wrapper_output1 = try generated.Message.initRootTyped(&message_plan_queue_wrapper_builder1);
    var message_plan_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_queue_wrapper_builder2.deinit();
    const message_plan_queue_wrapper_output2 = try generated.Message.initRootTyped(&message_plan_queue_wrapper_builder2);
    const message_plan_queue_wrapper_outputs = [_]generated.Message.Builder{ message_plan_queue_wrapper_output0, message_plan_queue_wrapper_output1, message_plan_queue_wrapper_output2 };
    var message_plan_queue_wrapper_context: Context = .{};
    var message_plan_queue_wrapper = std.ArrayList(PlanQueueItem).empty;
    defer message_plan_queue_wrapper.deinit(std.testing.allocator);
    var message_plan_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_plan_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_queue_wrapper_short_plan_buffer[0..],
        message_plan_queue_wrapper_outputs[0..],
        &message_plan_queue_wrapper_context,
        &message_plan_queue_wrapper,
    ));
    try std.testing.expectEqual(message_stats, try message_plan_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_queue_wrapper_plan_buffer[0..],
        message_plan_queue_wrapper_outputs[0..],
        &message_plan_queue_wrapper_context,
        &message_plan_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_plan_queue_wrapper_context.selected);
    try QueueChecks.expectPlanQueue(message_plan_queue_wrapper.items, .{ 0, 2, 3 });

    var message_plan_split_queue_wrapper_state = try Seed.state();
    defer message_plan_split_queue_wrapper_state.deinit();
    var message_plan_split_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_plan_split_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_split_queue_wrapper_builder0.deinit();
    const message_plan_split_queue_wrapper_output0 = try generated.Message.initRootTyped(&message_plan_split_queue_wrapper_builder0);
    var message_plan_split_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_split_queue_wrapper_builder1.deinit();
    const message_plan_split_queue_wrapper_output1 = try generated.Message.initRootTyped(&message_plan_split_queue_wrapper_builder1);
    var message_plan_split_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_split_queue_wrapper_builder2.deinit();
    const message_plan_split_queue_wrapper_output2 = try generated.Message.initRootTyped(&message_plan_split_queue_wrapper_builder2);
    const message_plan_split_queue_wrapper_outputs = [_]generated.Message.Builder{ message_plan_split_queue_wrapper_output0, message_plan_split_queue_wrapper_output1, message_plan_split_queue_wrapper_output2 };
    var message_plan_split_queue_wrapper_context: Context = .{};
    var message_plan_split_response_queue = std.ArrayList(PlanQueueItem).empty;
    defer message_plan_split_response_queue.deinit(std.testing.allocator);
    var message_plan_split_forward_queue = std.ArrayList(PlanQueueItem).empty;
    defer message_plan_split_forward_queue.deinit(std.testing.allocator);
    var message_plan_split_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_plan_split_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToQueues(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_split_queue_wrapper_short_plan_buffer[0..],
        message_plan_split_queue_wrapper_outputs[0..],
        &message_plan_split_queue_wrapper_context,
        &message_plan_split_response_queue,
        &message_plan_split_forward_queue,
    ));
    try std.testing.expectEqual(message_stats, try message_plan_split_queue_wrapper_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToQueues(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_split_queue_wrapper_plan_buffer[0..],
        message_plan_split_queue_wrapper_outputs[0..],
        &message_plan_split_queue_wrapper_context,
        &message_plan_split_response_queue,
        &message_plan_split_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_plan_split_queue_wrapper_context.selected);
    try QueueChecks.expectSplitPlanQueues(message_plan_split_response_queue.items, message_plan_split_forward_queue.items, .{ 0, 2 }, 3);

    const PlanRoleResponseSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, message: anytype) !void {
            try std.testing.expect(plan.action.isDispatch() or plan.action.isUnimplemented());
            context.sent += 1;
            context.source_sum += plan.source_index;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    const PlanRoleForwardSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, message: anytype) !void {
            try std.testing.expect(plan.action.isForward());
            context.sent += 1;
            context.source_sum += plan.source_index;
            context.question_sum += try (try message.get_call()).get_questionId();
        }
    };
    var message_plan_role_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_plan_role_state.deinit();
    try message_plan_role_state.addImport(5);
    try message_plan_role_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_plan_role_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_plan_role_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_plan_role_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_role_builder0.deinit();
    const message_plan_role_output0 = try generated.Message.initRootTyped(&message_plan_role_builder0);
    var message_plan_role_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_role_builder1.deinit();
    const message_plan_role_output1 = try generated.Message.initRootTyped(&message_plan_role_builder1);
    var message_plan_role_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_role_builder2.deinit();
    const message_plan_role_output2 = try generated.Message.initRootTyped(&message_plan_role_builder2);
    const message_plan_role_outputs = [_]generated.Message.Builder{ message_plan_role_output0, message_plan_role_output1, message_plan_role_output2 };
    var message_plan_role_context: Context = .{};
    var message_plan_role_response_sink: PlanRoleResponseSink = .{};
    var message_plan_role_forward_sink: PlanRoleForwardSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToSinks(
        &message_plan_role_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_plan_role_outputs[0..2],
        &message_plan_role_context,
        entries,
        &message_plan_role_response_sink,
        PlanRoleResponseSink.handle,
        &message_plan_role_forward_sink,
        PlanRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToSinks(
        &message_plan_role_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_plan_role_outputs[0..],
        &message_plan_role_context,
        entries,
        &message_plan_role_response_sink,
        PlanRoleResponseSink.handle,
        &message_plan_role_forward_sink,
        PlanRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_plan_role_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_plan_role_response_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 2), message_plan_role_response_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_plan_role_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), message_plan_role_forward_sink.sent);
    try std.testing.expectEqual(@as(usize, 3), message_plan_role_forward_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 73), message_plan_role_forward_sink.question_sum);

    var message_plan_role_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_plan_role_wrapper_state.deinit();
    try message_plan_role_wrapper_state.addImport(5);
    try message_plan_role_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_plan_role_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_plan_role_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_plan_role_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_plan_role_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_role_wrapper_builder0.deinit();
    const message_plan_role_wrapper_output0 = try generated.Message.initRootTyped(&message_plan_role_wrapper_builder0);
    var message_plan_role_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_role_wrapper_builder1.deinit();
    const message_plan_role_wrapper_output1 = try generated.Message.initRootTyped(&message_plan_role_wrapper_builder1);
    var message_plan_role_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_plan_role_wrapper_builder2.deinit();
    const message_plan_role_wrapper_output2 = try generated.Message.initRootTyped(&message_plan_role_wrapper_builder2);
    const message_plan_role_wrapper_outputs = [_]generated.Message.Builder{ message_plan_role_wrapper_output0, message_plan_role_wrapper_output1, message_plan_role_wrapper_output2 };
    var message_plan_role_wrapper_context: Context = .{};
    var message_plan_role_wrapper_response_sink: PlanRoleResponseSink = .{};
    var message_plan_role_wrapper_forward_sink: PlanRoleForwardSink = .{};
    var message_plan_role_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_plan_role_wrapper_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToSinks(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_role_wrapper_short_plan_buffer[0..],
        message_plan_role_wrapper_outputs[0..],
        &message_plan_role_wrapper_context,
        &message_plan_role_wrapper_response_sink,
        PlanRoleResponseSink.handle,
        &message_plan_role_wrapper_forward_sink,
        PlanRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_plan_role_wrapper_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToSinks(
        std.testing.allocator,
        messages[0..],
        entries,
        message_plan_role_wrapper_plan_buffer[0..],
        message_plan_role_wrapper_outputs[0..],
        &message_plan_role_wrapper_context,
        &message_plan_role_wrapper_response_sink,
        PlanRoleResponseSink.handle,
        &message_plan_role_wrapper_forward_sink,
        PlanRoleForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_plan_role_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_plan_role_wrapper_response_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 2), message_plan_role_wrapper_response_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_plan_role_wrapper_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), message_plan_role_wrapper_forward_sink.sent);
    try std.testing.expectEqual(@as(usize, 3), message_plan_role_wrapper_forward_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 73), message_plan_role_wrapper_forward_sink.question_sum);

    const MessageTaggedPlanSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        response_local_sum: usize = 0,
        forward_local_sum: usize = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, position: cpz.rpc.TrackedCallServiceActionOutputPosition, message: anytype) !void {
            context.source_sum += plan.source_index;
            switch (context.sent) {
                0 => {
                    try std.testing.expect(plan.action.isDispatch());
                    try std.testing.expectEqual(@as(usize, 0), plan.source_index);
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, position);
                    try std.testing.expectEqual(@as(u32, 71), try (try message.get_return_()).get_answerId());
                    context.response_local_sum += position.local_index;
                },
                1 => {
                    try std.testing.expect(plan.action.isUnimplemented());
                    try std.testing.expectEqual(@as(usize, 2), plan.source_index);
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, position);
                    try std.testing.expectEqual(@as(u32, 72), try (try message.get_return_()).get_answerId());
                    context.response_local_sum += position.local_index;
                },
                2 => {
                    try std.testing.expect(plan.action.isForward());
                    try std.testing.expectEqual(@as(usize, 3), plan.source_index);
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, position);
                    try std.testing.expectEqual(@as(u32, 73), try (try message.get_call()).get_questionId());
                    context.forward_local_sum += position.local_index;
                },
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };
    var message_tagged_plan_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_tagged_plan_state.deinit();
    try message_tagged_plan_state.addImport(5);
    try message_tagged_plan_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_tagged_plan_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_tagged_plan_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_tagged_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_tagged_plan_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_plan_builder0.deinit();
    const message_tagged_plan_output0 = try generated.Message.initRootTyped(&message_tagged_plan_builder0);
    var message_tagged_plan_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_plan_builder1.deinit();
    const message_tagged_plan_output1 = try generated.Message.initRootTyped(&message_tagged_plan_builder1);
    var message_tagged_plan_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_plan_builder2.deinit();
    const message_tagged_plan_output2 = try generated.Message.initRootTyped(&message_tagged_plan_builder2);
    const message_tagged_plan_outputs = [_]generated.Message.Builder{ message_tagged_plan_output0, message_tagged_plan_output1, message_tagged_plan_output2 };
    var message_tagged_plan_context: Context = .{};
    var message_tagged_plan_sink: MessageTaggedPlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, message_tagged_plan_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToTaggedSink(
        std.testing.allocator,
        messages[0..],
        entries,
        short_message_plans[0..],
        message_tagged_plan_outputs[0..],
        &message_tagged_plan_context,
        &message_tagged_plan_sink,
        MessageTaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_tagged_plan_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToTaggedSink(
        std.testing.allocator,
        messages[0..],
        entries,
        message_tagged_plan_buffer[0..],
        message_tagged_plan_outputs[0..],
        &message_tagged_plan_context,
        &message_tagged_plan_sink,
        MessageTaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_tagged_plan_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_tagged_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 2 + 3), message_tagged_plan_sink.source_sum);
    try std.testing.expectEqual(@as(usize, 0 + 1), message_tagged_plan_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), message_tagged_plan_sink.forward_local_sum);

    var message_tagged_plan_queue_state = try Seed.state();
    defer message_tagged_plan_queue_state.deinit();
    var message_tagged_plan_queue_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_tagged_plan_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_plan_queue_builder0.deinit();
    const message_tagged_plan_queue_output0 = try generated.Message.initRootTyped(&message_tagged_plan_queue_builder0);
    var message_tagged_plan_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_plan_queue_builder1.deinit();
    const message_tagged_plan_queue_output1 = try generated.Message.initRootTyped(&message_tagged_plan_queue_builder1);
    var message_tagged_plan_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_tagged_plan_queue_builder2.deinit();
    const message_tagged_plan_queue_output2 = try generated.Message.initRootTyped(&message_tagged_plan_queue_builder2);
    const message_tagged_plan_queue_outputs = [_]generated.Message.Builder{ message_tagged_plan_queue_output0, message_tagged_plan_queue_output1, message_tagged_plan_queue_output2 };
    var message_tagged_plan_queue_context: Context = .{};
    var message_tagged_plan_queue = std.ArrayList(PlanTaggedQueueItem).empty;
    defer message_tagged_plan_queue.deinit(std.testing.allocator);
    var message_tagged_plan_queue_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_tagged_plan_queue_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToTaggedQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_tagged_plan_queue_short_plan_buffer[0..],
        message_tagged_plan_queue_outputs[0..],
        &message_tagged_plan_queue_context,
        &message_tagged_plan_queue,
    ));
    try std.testing.expectEqual(message_stats, try message_tagged_plan_queue_state.dispatchWireMessageServiceActionsUnifiedOutputPlansToTaggedQueue(
        std.testing.allocator,
        messages[0..],
        entries,
        message_tagged_plan_queue_plan_buffer[0..],
        message_tagged_plan_queue_outputs[0..],
        &message_tagged_plan_queue_context,
        &message_tagged_plan_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_tagged_plan_queue_context.selected);
    try QueueChecks.expectTaggedPlanQueue(message_tagged_plan_queue.items, .{ 0, 2, 3 });

    var message_direct_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_direct_sink_state.deinit();
    try message_direct_sink_state.addImport(5);
    try message_direct_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_direct_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_direct_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_direct_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_sink_builder0.deinit();
    const message_direct_sink_output0 = try generated.Message.initRootTyped(&message_direct_sink_builder0);
    var message_direct_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_sink_builder1.deinit();
    const message_direct_sink_output1 = try generated.Message.initRootTyped(&message_direct_sink_builder1);
    var message_direct_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_sink_builder2.deinit();
    const message_direct_sink_output2 = try generated.Message.initRootTyped(&message_direct_sink_builder2);
    const message_direct_sink_outputs = [_]generated.Message.Builder{ message_direct_sink_output0, message_direct_sink_output1, message_direct_sink_output2 };
    var message_direct_sink_context: Context = .{};
    var message_direct_sink: MessageUnifiedSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToSink(
        &message_direct_sink_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_sink_outputs[0..2],
        &message_direct_sink_context,
        entries,
        &message_direct_sink,
        MessageUnifiedSink.handle,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputsToSink(
        &message_direct_sink_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_sink_outputs[0..],
        &message_direct_sink_context,
        entries,
        &message_direct_sink,
        MessageUnifiedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_direct_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), message_direct_sink.responses);
    try std.testing.expectEqual(@as(usize, 1), message_direct_sink.forwards);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_direct_sink.answer_sum);
    try std.testing.expectEqual(@as(u32, 73), message_direct_sink.question_sum);

    var message_direct_plan_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_direct_plan_sink_state.deinit();
    try message_direct_plan_sink_state.addImport(5);
    try message_direct_plan_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_direct_plan_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_direct_plan_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_direct_plan_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_sink_builder0.deinit();
    const message_direct_plan_sink_output0 = try generated.Message.initRootTyped(&message_direct_plan_sink_builder0);
    var message_direct_plan_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_sink_builder1.deinit();
    const message_direct_plan_sink_output1 = try generated.Message.initRootTyped(&message_direct_plan_sink_builder1);
    var message_direct_plan_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_sink_builder2.deinit();
    const message_direct_plan_sink_output2 = try generated.Message.initRootTyped(&message_direct_plan_sink_builder2);
    const message_direct_plan_sink_outputs = [_]generated.Message.Builder{ message_direct_plan_sink_output0, message_direct_plan_sink_output1, message_direct_plan_sink_output2 };
    var message_direct_plan_sink_context: Context = .{};
    var message_direct_plan_sink: MessagePlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToSink(
        &message_direct_plan_sink_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_plan_sink_outputs[0..2],
        &message_direct_plan_sink_context,
        entries,
        &message_direct_plan_sink,
        MessagePlanSink.handle,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToSink(
        &message_direct_plan_sink_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_plan_sink_outputs[0..],
        &message_direct_plan_sink_context,
        entries,
        &message_direct_plan_sink,
        MessagePlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_plan_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_direct_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 2 + 3), message_direct_plan_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72 + 73), message_direct_plan_sink.question_sum);

    var message_direct_plan_queue_state = try Seed.state();
    defer message_direct_plan_queue_state.deinit();
    var message_direct_plan_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_queue_builder0.deinit();
    const message_direct_plan_queue_output0 = try generated.Message.initRootTyped(&message_direct_plan_queue_builder0);
    var message_direct_plan_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_queue_builder1.deinit();
    const message_direct_plan_queue_output1 = try generated.Message.initRootTyped(&message_direct_plan_queue_builder1);
    var message_direct_plan_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_queue_builder2.deinit();
    const message_direct_plan_queue_output2 = try generated.Message.initRootTyped(&message_direct_plan_queue_builder2);
    const message_direct_plan_queue_outputs = [_]generated.Message.Builder{ message_direct_plan_queue_output0, message_direct_plan_queue_output1, message_direct_plan_queue_output2 };
    var message_direct_plan_queue_context: Context = .{};
    var message_direct_plan_queue = std.ArrayList(PlanQueueItem).empty;
    defer message_direct_plan_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToQueue(
        &message_direct_plan_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_plan_queue_outputs[0..2],
        &message_direct_plan_queue_context,
        entries,
        &message_direct_plan_queue,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToQueue(
        &message_direct_plan_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_plan_queue_outputs[0..],
        &message_direct_plan_queue_context,
        entries,
        &message_direct_plan_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_plan_queue_context.selected);
    try QueueChecks.expectPlanQueue(message_direct_plan_queue.items, .{ 0, 2, 3 });

    var message_direct_plan_split_queue_state = try Seed.state();
    defer message_direct_plan_split_queue_state.deinit();
    var message_direct_plan_split_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_split_queue_builder0.deinit();
    const message_direct_plan_split_queue_output0 = try generated.Message.initRootTyped(&message_direct_plan_split_queue_builder0);
    var message_direct_plan_split_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_split_queue_builder1.deinit();
    const message_direct_plan_split_queue_output1 = try generated.Message.initRootTyped(&message_direct_plan_split_queue_builder1);
    var message_direct_plan_split_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_plan_split_queue_builder2.deinit();
    const message_direct_plan_split_queue_output2 = try generated.Message.initRootTyped(&message_direct_plan_split_queue_builder2);
    const message_direct_plan_split_queue_outputs = [_]generated.Message.Builder{ message_direct_plan_split_queue_output0, message_direct_plan_split_queue_output1, message_direct_plan_split_queue_output2 };
    var message_direct_plan_split_queue_context: Context = .{};
    var message_direct_plan_split_response_queue = std.ArrayList(PlanQueueItem).empty;
    defer message_direct_plan_split_response_queue.deinit(std.testing.allocator);
    var message_direct_plan_split_forward_queue = std.ArrayList(PlanQueueItem).empty;
    defer message_direct_plan_split_forward_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToQueues(
        &message_direct_plan_split_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_plan_split_queue_outputs[0..2],
        &message_direct_plan_split_queue_context,
        entries,
        &message_direct_plan_split_response_queue,
        &message_direct_plan_split_forward_queue,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToQueues(
        &message_direct_plan_split_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_plan_split_queue_outputs[0..],
        &message_direct_plan_split_queue_context,
        entries,
        &message_direct_plan_split_response_queue,
        &message_direct_plan_split_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_plan_split_queue_context.selected);
    try QueueChecks.expectSplitPlanQueues(message_direct_plan_split_response_queue.items, message_direct_plan_split_forward_queue.items, .{ 0, 2 }, 3);

    var message_direct_tagged_plan_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_direct_tagged_plan_state.deinit();
    try message_direct_tagged_plan_state.addImport(5);
    try message_direct_tagged_plan_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_direct_tagged_plan_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_direct_tagged_plan_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_direct_tagged_plan_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_plan_builder0.deinit();
    const message_direct_tagged_plan_output0 = try generated.Message.initRootTyped(&message_direct_tagged_plan_builder0);
    var message_direct_tagged_plan_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_plan_builder1.deinit();
    const message_direct_tagged_plan_output1 = try generated.Message.initRootTyped(&message_direct_tagged_plan_builder1);
    var message_direct_tagged_plan_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_plan_builder2.deinit();
    const message_direct_tagged_plan_output2 = try generated.Message.initRootTyped(&message_direct_tagged_plan_builder2);
    const message_direct_tagged_plan_outputs = [_]generated.Message.Builder{ message_direct_tagged_plan_output0, message_direct_tagged_plan_output1, message_direct_tagged_plan_output2 };
    var message_direct_tagged_plan_context: Context = .{};
    var message_direct_tagged_plan_sink: MessageTaggedPlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedSink(
        &message_direct_tagged_plan_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_tagged_plan_outputs[0..2],
        &message_direct_tagged_plan_context,
        entries,
        &message_direct_tagged_plan_sink,
        MessageTaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedSink(
        &message_direct_tagged_plan_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_tagged_plan_outputs[0..],
        &message_direct_tagged_plan_context,
        entries,
        &message_direct_tagged_plan_sink,
        MessageTaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_tagged_plan_context.selected);
    try std.testing.expectEqual(@as(usize, 3), message_direct_tagged_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 2 + 3), message_direct_tagged_plan_sink.source_sum);
    try std.testing.expectEqual(@as(usize, 0 + 1), message_direct_tagged_plan_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), message_direct_tagged_plan_sink.forward_local_sum);

    var message_direct_tagged_plan_queue_state = try Seed.state();
    defer message_direct_tagged_plan_queue_state.deinit();
    var message_direct_tagged_plan_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_plan_queue_builder0.deinit();
    const message_direct_tagged_plan_queue_output0 = try generated.Message.initRootTyped(&message_direct_tagged_plan_queue_builder0);
    var message_direct_tagged_plan_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_plan_queue_builder1.deinit();
    const message_direct_tagged_plan_queue_output1 = try generated.Message.initRootTyped(&message_direct_tagged_plan_queue_builder1);
    var message_direct_tagged_plan_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_direct_tagged_plan_queue_builder2.deinit();
    const message_direct_tagged_plan_queue_output2 = try generated.Message.initRootTyped(&message_direct_tagged_plan_queue_builder2);
    const message_direct_tagged_plan_queue_outputs = [_]generated.Message.Builder{ message_direct_tagged_plan_queue_output0, message_direct_tagged_plan_queue_output1, message_direct_tagged_plan_queue_output2 };
    var message_direct_tagged_plan_queue_context: Context = .{};
    var message_direct_tagged_plan_queue = std.ArrayList(PlanTaggedQueueItem).empty;
    defer message_direct_tagged_plan_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedQueue(
        &message_direct_tagged_plan_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_tagged_plan_queue_outputs[0..2],
        &message_direct_tagged_plan_queue_context,
        entries,
        &message_direct_tagged_plan_queue,
    ));
    try std.testing.expectEqual(message_action_stats, try cpz.rpc.initWireMessageServiceActionPlanUnifiedOutputPlansToTaggedQueue(
        &message_direct_tagged_plan_queue_state,
        std.testing.allocator,
        messages[0..],
        message_plans[0..],
        message_direct_tagged_plan_queue_outputs[0..],
        &message_direct_tagged_plan_queue_context,
        entries,
        &message_direct_tagged_plan_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_direct_tagged_plan_queue_context.selected);
    try QueueChecks.expectTaggedPlanQueue(message_direct_tagged_plan_queue.items, .{ 0, 2, 3 });

    var message_split_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_split_state.deinit();
    try message_split_state.addImport(5);
    try message_split_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_split_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_split_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_split_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_split_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_response_builder0.deinit();
    const message_split_response0 = try generated.Message.initRootTyped(&message_split_response_builder0);
    var message_split_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_response_builder1.deinit();
    const message_split_response1 = try generated.Message.initRootTyped(&message_split_response_builder1);
    var message_split_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_forward_builder.deinit();
    const message_split_forward = try generated.Message.initRootTyped(&message_split_forward_builder);
    const message_split_responses = [_]generated.Message.Builder{ message_split_response0, message_split_response1 };
    const message_split_forwards = [_]generated.Message.Builder{message_split_forward};
    var message_split_context: Context = .{};
    var message_split_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_split_state.dispatchWireMessageServiceActions(
        std.testing.allocator,
        messages[0..],
        entries,
        message_split_short_plan_buffer[0..],
        message_split_responses[0..],
        message_split_forwards[0..],
        &message_split_context,
    ));
    try std.testing.expectEqual(message_stats, try message_split_state.dispatchWireMessageServiceActions(
        std.testing.allocator,
        messages[0..],
        entries,
        message_split_plan_buffer[0..],
        message_split_responses[0..],
        message_split_forwards[0..],
        &message_split_context,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_split_context.selected);
    var message_split_response_reader0 = cpz.MessageReader.init(try message_split_response_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 71), (try generated.Message.fromReader(try message_split_response_reader0.getRoot()).return_()).answerId());
    var message_split_response_reader1 = cpz.MessageReader.init(try message_split_response_builder1.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 72), (try generated.Message.fromReader(try message_split_response_reader1.getRoot()).return_()).answerId());
    var message_split_forward_reader = cpz.MessageReader.init(try message_split_forward_builder.segmentsConst(), .{});
    const message_split_forward_call = try generated.Message.fromReader(try message_split_forward_reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 73), message_split_forward_call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, try cpz.rpc.callTargetFromWireCall(message_split_forward_call));

    const MessageResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    const MessageForwardSink = struct {
        sent: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.question_sum += try (try message.get_call()).get_questionId();
        }
    };
    var message_split_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer message_split_sink_state.deinit();
    try message_split_sink_state.addImport(5);
    try message_split_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try message_split_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try message_split_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var message_split_sink_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var message_split_sink_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_sink_response_builder0.deinit();
    const message_split_sink_response0 = try generated.Message.initRootTyped(&message_split_sink_response_builder0);
    var message_split_sink_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_sink_response_builder1.deinit();
    const message_split_sink_response1 = try generated.Message.initRootTyped(&message_split_sink_response_builder1);
    var message_split_sink_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer message_split_sink_forward_builder.deinit();
    const message_split_sink_forward = try generated.Message.initRootTyped(&message_split_sink_forward_builder);
    const message_split_sink_responses = [_]generated.Message.Builder{ message_split_sink_response0, message_split_sink_response1 };
    const message_split_sink_forwards = [_]generated.Message.Builder{message_split_sink_forward};
    var message_split_sink_context: Context = .{};
    var message_response_sink: MessageResponseSink = .{};
    var message_forward_sink: MessageForwardSink = .{};
    var message_split_sink_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, message_split_sink_state.dispatchWireMessageServiceActionsToSinks(
        std.testing.allocator,
        messages[0..],
        entries,
        message_split_sink_short_plan_buffer[0..],
        message_split_sink_responses[0..],
        message_split_sink_forwards[0..],
        &message_split_sink_context,
        &message_response_sink,
        MessageResponseSink.handle,
        &message_forward_sink,
        MessageForwardSink.handle,
    ));
    try std.testing.expectEqual(message_stats, try message_split_sink_state.dispatchWireMessageServiceActionsToSinks(
        std.testing.allocator,
        messages[0..],
        entries,
        message_split_sink_plan_buffer[0..],
        message_split_sink_responses[0..],
        message_split_sink_forwards[0..],
        &message_split_sink_context,
        &message_response_sink,
        MessageResponseSink.handle,
        &message_forward_sink,
        MessageForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), message_split_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 2), message_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), message_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), message_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), message_forward_sink.question_sum);

    const wire_stats = try state.wireCallServiceActionStats(calls[0..], entries);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionStats{
        .dispatch = 1,
        .forward = 1,
        .unimplemented = 1,
    }, wire_stats);
    try std.testing.expectEqual(@as(usize, 3), wire_stats.actions());
    try std.testing.expectEqual(@as(usize, 3), wire_stats.total());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, wire_stats.dispatchRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, wire_stats.forwardRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, wire_stats.unimplementedRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, wire_stats.responseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, wire_stats.outputResponseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, wire_stats.outputForwardRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 1 }, wire_stats.dispatchResponseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 1, .end = 2 }, wire_stats.unimplementedResponseRange());
    try wire_stats.validateSplitCapacity(1, 1, 1);
    try wire_stats.validateOutputCapacity(2, 1);
    const response_capacity_probe = [_]u8{ 0, 0 };
    const forward_capacity_probe = [_]u8{0};
    try wire_stats.validateOutputBuilders(response_capacity_probe[0..], forward_capacity_probe[0..]);
    try wire_stats.validateActionCapacity(3);
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateDispatchCapacity(0));
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateForwardCapacity(0));
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateUnimplementedCapacity(0));
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateResponseCapacity(1));
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateOutputCapacity(1, 1));
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateOutputCapacity(2, 0));
    try std.testing.expectError(error.InvalidTransition, wire_stats.validateActionCapacity(2));
    var wire_actions: [3]cpz.rpc.TrackedCallServiceAction = undefined;
    try std.testing.expectEqual(wire_stats, try state.initWireCallServiceActions(calls[0..], entries, wire_actions[0..]));
    try std.testing.expectEqual(@as(usize, 0), wire_actions[0].dispatch);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, wire_actions[1].forward);
    try std.testing.expect(wire_actions[2].isUnimplemented());
    var wire_plans: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectEqual(wire_stats, try state.initWireCallServiceActionPlans(calls[0..], entries, wire_plans[0..]));
    try std.testing.expectEqual(@as(usize, 0), wire_plans[0].source_index);
    try std.testing.expectEqual(@as(u32, 71), wire_plans[0].question_id);
    try std.testing.expectEqual(@as(usize, 0), wire_plans[0].action.dispatch);
    try std.testing.expectEqual(@as(usize, 2), wire_plans[1].source_index);
    try std.testing.expectEqual(@as(u32, 73), wire_plans[1].question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, wire_plans[1].action.forward);
    try std.testing.expectEqual(@as(usize, 1), wire_plans[2].source_index);
    try std.testing.expectEqual(@as(u32, 72), wire_plans[2].question_id);
    try std.testing.expect(wire_plans[2].action.isUnimplemented());
    var mismatched_question_plans = wire_plans;
    mismatched_question_plans[0].question_id = 999;
    var mismatched_forward_plans = wire_plans;
    mismatched_forward_plans[1].question_id = 999;
    var mismatched_unimplemented_plans = wire_plans;
    mismatched_unimplemented_plans[2].question_id = 999;
    var mismatched_question_state = cpz.rpc.State.init(std.testing.allocator);
    defer mismatched_question_state.deinit();
    try mismatched_question_state.addImport(5);
    try mismatched_question_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try mismatched_question_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try mismatched_question_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var mismatched_response_outputs: [2]generated.Message.Builder = undefined;
    var mismatched_forward_outputs: [1]generated.Message.Builder = undefined;
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanOutputs(
        &mismatched_question_state,
        std.testing.allocator,
        calls[0..],
        mismatched_question_plans[0..],
        mismatched_response_outputs[0..],
        mismatched_forward_outputs[0..],
        @as(*Context, undefined),
        entries,
    ));

    var forwarded_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer forwarded_builder.deinit();
    const forwarded_root = try generated.Message.initRootTyped(&forwarded_builder);
    const forwarded_messages = [_]generated.Message.Builder{forwarded_root};
    try std.testing.expectEqual(
        @as(usize, 1),
        try cpz.rpc.initForwardedWireCallMessagesFromServiceActionPlans(calls[0..], wire_plans[0..], forwarded_messages[0..]),
    );
    var forwarded_reader = cpz.MessageReader.init(try forwarded_builder.segmentsConst(), .{});
    const forwarded_call = try generated.Message.fromReader(try forwarded_reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 73), forwarded_call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, try cpz.rpc.callTargetFromWireCall(forwarded_call));
    const no_forward_messages = try std.testing.allocator.alloc(generated.Message.Builder, 0);
    defer std.testing.allocator.free(no_forward_messages);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initForwardedWireCallMessagesFromServiceActionPlans(calls[0..], wire_plans[0..], no_forward_messages));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initForwardedWireCallMessagesFromServiceActionPlans(calls[0..], mismatched_forward_plans[0..], forwarded_messages[0..]));

    var dispatch_state = cpz.rpc.State.init(std.testing.allocator);
    defer dispatch_state.deinit();
    try dispatch_state.addImport(5);
    try dispatch_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try dispatch_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try dispatch_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireCallServiceActionPlans(
        &dispatch_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        no_forward_messages,
        @as(*Context, undefined),
        entries,
    ));
    var dispatch_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer dispatch_response_builder.deinit();
    const dispatch_response_root = try generated.Message.initRootTyped(&dispatch_response_builder);
    const dispatch_responses = [_]generated.Message.Builder{dispatch_response_root};
    var dispatch_context: Context = .{};
    try std.testing.expectEqual(
        @as(usize, 1),
        try cpz.rpc.dispatchWireCallServiceActionPlans(&dispatch_state, std.testing.allocator, calls[0..], wire_plans[0..], dispatch_responses[0..], &dispatch_context, entries),
    );
    try std.testing.expectEqual(@as(u32, 71), dispatch_context.selected);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), dispatch_state.questionState(71));
    var dispatch_response_reader = cpz.MessageReader.init(try dispatch_response_builder.segmentsConst(), .{});
    const dispatch_return = try generated.Message.fromReader(try dispatch_response_reader.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 71), dispatch_return.answerId());
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.dispatchWireCallServiceActionPlans(
        &dispatch_state,
        std.testing.allocator,
        calls[0..],
        mismatched_question_plans[0..],
        dispatch_responses[0..],
        &dispatch_context,
        entries,
    ));

    var unimplemented_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unimplemented_response_builder.deinit();
    const unimplemented_response_root = try generated.Message.initRootTyped(&unimplemented_response_builder);
    const unimplemented_responses = [_]generated.Message.Builder{unimplemented_response_root};
    try std.testing.expectEqual(
        @as(usize, 1),
        try cpz.rpc.initUnimplementedReturnMessagesFromServiceActionPlans(calls[0..], wire_plans[0..], unimplemented_responses[0..]),
    );
    var unimplemented_response_reader = cpz.MessageReader.init(try unimplemented_response_builder.segmentsConst(), .{});
    const unimplemented_return = try generated.Message.fromReader(try unimplemented_response_reader.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 72), unimplemented_return.answerId());
    const unimplemented_outcome = try cpz.rpc.returnOutcomeFromWireReturn(unimplemented_return);
    const exception = switch (unimplemented_outcome) {
        .exception => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqualStrings("unimplemented method", exception.reason.?);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initUnimplementedReturnMessagesFromServiceActionPlans(calls[0..], wire_plans[0..], no_forward_messages));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initUnimplementedReturnMessagesFromServiceActionPlans(calls[0..], mismatched_unimplemented_plans[0..], unimplemented_responses[0..]));

    var combined_state = cpz.rpc.State.init(std.testing.allocator);
    defer combined_state.deinit();
    try combined_state.addImport(5);
    try combined_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try combined_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try combined_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var combined_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer combined_response_builder0.deinit();
    const combined_response0 = try generated.Message.initRootTyped(&combined_response_builder0);
    var combined_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer combined_response_builder1.deinit();
    const combined_response1 = try generated.Message.initRootTyped(&combined_response_builder1);
    var combined_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer combined_forward_builder.deinit();
    const combined_forward = try generated.Message.initRootTyped(&combined_forward_builder);
    const combined_responses = [_]generated.Message.Builder{ combined_response0, combined_response1 };
    const combined_forwards = [_]generated.Message.Builder{combined_forward};
    var combined_context: Context = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanOutputs(
        &combined_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        combined_responses[0..],
        no_forward_messages,
        &combined_context,
        entries,
    ));
    try std.testing.expectEqual(
        wire_stats,
        try cpz.rpc.initWireCallServiceActionPlanOutputs(&combined_state, std.testing.allocator, calls[0..], wire_plans[0..], combined_responses[0..], combined_forwards[0..], &combined_context, entries),
    );
    try std.testing.expectEqual(@as(u32, 71), combined_context.selected);
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), combined_state.questionState(71));
    var combined_response_reader0 = cpz.MessageReader.init(try combined_response_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 71), (try generated.Message.fromReader(try combined_response_reader0.getRoot()).return_()).answerId());
    var combined_response_reader1 = cpz.MessageReader.init(try combined_response_builder1.segmentsConst(), .{});
    const combined_unimplemented = try generated.Message.fromReader(try combined_response_reader1.getRoot()).return_();
    try std.testing.expectEqual(@as(u32, 72), combined_unimplemented.answerId());
    const combined_exception = switch (try cpz.rpc.returnOutcomeFromWireReturn(combined_unimplemented)) {
        .exception => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqualStrings("unimplemented method", combined_exception.reason.?);
    var combined_forward_reader = cpz.MessageReader.init(try combined_forward_builder.segmentsConst(), .{});
    const combined_forward_call = try generated.Message.fromReader(try combined_forward_reader.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 73), combined_forward_call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, try cpz.rpc.callTargetFromWireCall(combined_forward_call));

    const ResponseSink = struct {
        sent: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    const ForwardSink = struct {
        sent: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            context.question_sum += try (try message.get_call()).get_questionId();
        }
    };
    var sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer sink_state.deinit();
    try sink_state.addImport(5);
    try sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var sink_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_response_builder0.deinit();
    const sink_response0 = try generated.Message.initRootTyped(&sink_response_builder0);
    var sink_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_response_builder1.deinit();
    const sink_response1 = try generated.Message.initRootTyped(&sink_response_builder1);
    var sink_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer sink_forward_builder.deinit();
    const sink_forward = try generated.Message.initRootTyped(&sink_forward_builder);
    const sink_responses = [_]generated.Message.Builder{ sink_response0, sink_response1 };
    const sink_forwards = [_]generated.Message.Builder{sink_forward};
    var sink_context: Context = .{};
    var response_sink: ResponseSink = .{};
    var forward_sink: ForwardSink = .{};
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanOutputsToSinks(
        &sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        sink_responses[0..],
        sink_forwards[0..],
        &sink_context,
        entries,
        &response_sink,
        ResponseSink.handle,
        &forward_sink,
        ForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), sink_context.selected);
    try std.testing.expectEqual(@as(usize, 2), response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), forward_sink.question_sum);

    var split_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer split_wrapper_state.deinit();
    try split_wrapper_state.addImport(5);
    try split_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try split_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try split_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var split_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var split_response_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_response_builder0.deinit();
    const split_response0 = try generated.Message.initRootTyped(&split_response_builder0);
    var split_response_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_response_builder1.deinit();
    const split_response1 = try generated.Message.initRootTyped(&split_response_builder1);
    var split_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_forward_builder.deinit();
    const split_forward = try generated.Message.initRootTyped(&split_forward_builder);
    const split_responses = [_]generated.Message.Builder{ split_response0, split_response1 };
    const split_forwards = [_]generated.Message.Builder{split_forward};
    var split_context: Context = .{};
    var split_response_sink: ResponseSink = .{};
    var split_forward_sink: ForwardSink = .{};
    var split_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, split_wrapper_state.dispatchWireCallServiceActions(
        std.testing.allocator,
        calls[0..],
        entries,
        split_short_plan_buffer[0..],
        split_responses[0..],
        split_forwards[0..],
        &split_context,
    ));
    try std.testing.expectEqual(wire_stats, try split_wrapper_state.dispatchWireCallServiceActionsToSinks(
        std.testing.allocator,
        calls[0..],
        entries,
        split_plan_buffer[0..],
        split_responses[0..],
        split_forwards[0..],
        &split_context,
        &split_response_sink,
        ResponseSink.handle,
        &split_forward_sink,
        ForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), split_context.selected);
    try std.testing.expectEqual(@as(usize, 2), split_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), split_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), split_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), split_forward_sink.question_sum);

    var unified_state = cpz.rpc.State.init(std.testing.allocator);
    defer unified_state.deinit();
    try unified_state.addImport(5);
    try unified_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try unified_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try unified_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var unified_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_builder0.deinit();
    const unified0 = try generated.Message.initRootTyped(&unified_builder0);
    var unified_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_builder1.deinit();
    const unified1 = try generated.Message.initRootTyped(&unified_builder1);
    var unified_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_builder2.deinit();
    const unified2 = try generated.Message.initRootTyped(&unified_builder2);
    const unified_outputs = [_]generated.Message.Builder{ unified0, unified1, unified2 };
    var unified_context: Context = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputs(&unified_state, std.testing.allocator, calls[0..], wire_plans[0..], unified_outputs[0..2], &unified_context, entries));
    try std.testing.expectEqual(
        wire_stats,
        try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputs(&unified_state, std.testing.allocator, calls[0..], wire_plans[0..], unified_outputs[0..], &unified_context, entries),
    );
    try std.testing.expectEqual(@as(u32, 71), unified_context.selected);
    var unified_reader0 = cpz.MessageReader.init(try unified_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 71), (try generated.Message.fromReader(try unified_reader0.getRoot()).return_()).answerId());
    var unified_reader1 = cpz.MessageReader.init(try unified_builder1.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 72), (try generated.Message.fromReader(try unified_reader1.getRoot()).return_()).answerId());
    var unified_reader2 = cpz.MessageReader.init(try unified_builder2.segmentsConst(), .{});
    const unified_forward_call = try generated.Message.fromReader(try unified_reader2.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 73), unified_forward_call.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, try cpz.rpc.callTargetFromWireCall(unified_forward_call));

    var direct_output_queue_state = try Seed.state();
    defer direct_output_queue_state.deinit();
    var direct_output_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_output_queue_builder0.deinit();
    const direct_output_queue_output0 = try generated.Message.initRootTyped(&direct_output_queue_builder0);
    var direct_output_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_output_queue_builder1.deinit();
    const direct_output_queue_output1 = try generated.Message.initRootTyped(&direct_output_queue_builder1);
    var direct_output_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_output_queue_builder2.deinit();
    const direct_output_queue_output2 = try generated.Message.initRootTyped(&direct_output_queue_builder2);
    const direct_output_queue_outputs = [_]generated.Message.Builder{ direct_output_queue_output0, direct_output_queue_output1, direct_output_queue_output2 };
    var direct_output_queue_context: Context = .{};
    var direct_output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer direct_output_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToQueue(
        &direct_output_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_output_queue_outputs[0..2],
        &direct_output_queue_context,
        entries,
        &direct_output_queue,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToQueue(
        &direct_output_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_output_queue_outputs[0..],
        &direct_output_queue_context,
        entries,
        &direct_output_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_output_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 3), direct_output_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try direct_output_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try direct_output_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try direct_output_queue.items[2].get_call()).get_questionId());

    var direct_output_split_queue_state = try Seed.state();
    defer direct_output_split_queue_state.deinit();
    var direct_output_split_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_output_split_queue_builder0.deinit();
    const direct_output_split_queue_output0 = try generated.Message.initRootTyped(&direct_output_split_queue_builder0);
    var direct_output_split_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_output_split_queue_builder1.deinit();
    const direct_output_split_queue_output1 = try generated.Message.initRootTyped(&direct_output_split_queue_builder1);
    var direct_output_split_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_output_split_queue_builder2.deinit();
    const direct_output_split_queue_output2 = try generated.Message.initRootTyped(&direct_output_split_queue_builder2);
    const direct_output_split_queue_outputs = [_]generated.Message.Builder{ direct_output_split_queue_output0, direct_output_split_queue_output1, direct_output_split_queue_output2 };
    var direct_output_split_queue_context: Context = .{};
    var direct_output_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer direct_output_response_queue.deinit(std.testing.allocator);
    var direct_output_forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer direct_output_forward_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToQueues(
        &direct_output_split_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_output_split_queue_outputs[0..2],
        &direct_output_split_queue_context,
        entries,
        &direct_output_response_queue,
        &direct_output_forward_queue,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToQueues(
        &direct_output_split_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_output_split_queue_outputs[0..],
        &direct_output_split_queue_context,
        entries,
        &direct_output_response_queue,
        &direct_output_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_output_split_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 2), direct_output_response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), direct_output_forward_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try direct_output_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try direct_output_response_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try direct_output_forward_queue.items[0].get_call()).get_questionId());

    const PlanSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, message: anytype) !void {
            context.source_sum += plan.source_index;
            context.question_sum += plan.question_id;
            switch (context.sent) {
                0 => {
                    try std.testing.expect(plan.action.isDispatch());
                    _ = try message.get_return_();
                },
                1 => {
                    try std.testing.expect(plan.action.isUnimplemented());
                    _ = try message.get_return_();
                },
                2 => {
                    try std.testing.expect(plan.action.isForward());
                    _ = try message.get_call();
                },
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };
    var plan_sink: PlanSink = .{};
    try cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToSink(wire_stats, wire_plans[0..], unified_outputs[0..], &plan_sink, PlanSink.handle);
    try std.testing.expectEqual(@as(usize, 3), plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1 + 2), plan_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72 + 73), plan_sink.question_sum);
    var plan_stats_sink: PlanSink = .{};
    const plan_output_stats = try cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToSinkStats(wire_stats, wire_plans[0..], unified_outputs[0..], &plan_stats_sink, PlanSink.handle);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, plan_output_stats);
    try plan_output_stats.validateAgainstServiceActionStats(wire_stats);
    try std.testing.expectEqual(@as(usize, 3), plan_stats_sink.sent);
    var plan_queue = std.ArrayList(PlanQueueItem).empty;
    defer plan_queue.deinit(std.testing.allocator);
    const plan_queue_stats = try cpz.rpc.appendRpcServiceActionUnifiedOutputPlansToQueue(std.testing.allocator, wire_stats, wire_plans[0..], unified_outputs[0..], &plan_queue);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, plan_queue_stats);
    try plan_queue_stats.validateAgainstServiceActionStats(wire_stats);
    try QueueChecks.expectPlanQueue(plan_queue.items, .{ 0, 1, 2 });
    var split_plan_response_queue = std.ArrayList(PlanQueueItem).empty;
    defer split_plan_response_queue.deinit(std.testing.allocator);
    var split_plan_forward_queue = std.ArrayList(PlanQueueItem).empty;
    defer split_plan_forward_queue.deinit(std.testing.allocator);
    const split_plan_queue_stats = try cpz.rpc.appendRpcServiceActionUnifiedOutputPlansToQueues(
        std.testing.allocator,
        wire_stats,
        wire_plans[0..],
        unified_outputs[0..],
        &split_plan_response_queue,
        &split_plan_forward_queue,
    );
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, split_plan_queue_stats);
    try split_plan_queue_stats.validateAgainstServiceActionStats(wire_stats);
    try QueueChecks.expectSplitPlanQueues(split_plan_response_queue.items, split_plan_forward_queue.items, .{ 0, 1 }, 2);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToSink(wire_stats, wire_plans[0..2], unified_outputs[0..], &plan_sink, PlanSink.handle));
    const overlong_wire_plans = [_]cpz.rpc.TrackedCallServiceActionPlan{ wire_plans[0], wire_plans[1], wire_plans[2], wire_plans[0] };
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToSink(wire_stats, overlong_wire_plans[0..], unified_outputs[0..], &plan_sink, PlanSink.handle));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcServiceActionUnifiedOutputPlansToQueue(std.testing.allocator, wire_stats, wire_plans[0..2], unified_outputs[0..], &plan_queue));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcServiceActionUnifiedOutputPlansToQueues(
        std.testing.allocator,
        wire_stats,
        wire_plans[0..2],
        unified_outputs[0..],
        &split_plan_response_queue,
        &split_plan_forward_queue,
    ));

    const WirePlanResponseSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        answer_sum: u32 = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, message: anytype) !void {
            try std.testing.expect(plan.action.isDispatch() or plan.action.isUnimplemented());
            context.sent += 1;
            context.source_sum += plan.source_index;
            context.answer_sum += try (try message.get_return_()).get_answerId();
        }
    };
    const WirePlanForwardSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, message: anytype) !void {
            try std.testing.expect(plan.action.isForward());
            context.sent += 1;
            context.source_sum += plan.source_index;
            context.question_sum += try (try message.get_call()).get_questionId();
        }
    };
    var wire_plan_response_sink: WirePlanResponseSink = .{};
    var wire_plan_forward_sink: WirePlanForwardSink = .{};
    const wire_plan_split_stats = try cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToSinksStats(
        wire_stats,
        wire_plans[0..],
        unified_outputs[0..],
        &wire_plan_response_sink,
        WirePlanResponseSink.handle,
        &wire_plan_forward_sink,
        WirePlanForwardSink.handle,
    );
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, wire_plan_split_stats);
    try wire_plan_split_stats.validateAgainstServiceActionStats(wire_stats);
    try std.testing.expectEqual(@as(usize, 2), wire_plan_response_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1), wire_plan_response_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72), wire_plan_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), wire_plan_forward_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), wire_plan_forward_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 73), wire_plan_forward_sink.question_sum);

    const TaggedPlanSink = struct {
        sent: usize = 0,
        source_sum: usize = 0,
        response_local_sum: usize = 0,
        forward_local_sum: usize = 0,

        fn handle(context: *@This(), plan: cpz.rpc.TrackedCallServiceActionPlan, position: cpz.rpc.TrackedCallServiceActionOutputPosition, message: anytype) !void {
            context.source_sum += plan.source_index;
            switch (context.sent) {
                0 => {
                    try std.testing.expect(plan.action.isDispatch());
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, position);
                    _ = try message.get_return_();
                    context.response_local_sum += position.local_index;
                },
                1 => {
                    try std.testing.expect(plan.action.isUnimplemented());
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, position);
                    _ = try message.get_return_();
                    context.response_local_sum += position.local_index;
                },
                2 => {
                    try std.testing.expect(plan.action.isForward());
                    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, position);
                    _ = try message.get_call();
                    context.forward_local_sum += position.local_index;
                },
                else => return error.TestUnexpectedResult,
            }
            context.sent += 1;
        }
    };
    var tagged_plan_sink: TaggedPlanSink = .{};
    try cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToTaggedSink(wire_stats, wire_plans[0..], unified_outputs[0..], &tagged_plan_sink, TaggedPlanSink.handle);
    try std.testing.expectEqual(@as(usize, 3), tagged_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1 + 2), tagged_plan_sink.source_sum);
    try std.testing.expectEqual(@as(usize, 0 + 1), tagged_plan_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_plan_sink.forward_local_sum);
    var tagged_plan_queue = std.ArrayList(PlanTaggedQueueItem).empty;
    defer tagged_plan_queue.deinit(std.testing.allocator);
    const tagged_plan_queue_stats = try cpz.rpc.appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(std.testing.allocator, wire_stats, wire_plans[0..], unified_outputs[0..], &tagged_plan_queue);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, tagged_plan_queue_stats);
    try tagged_plan_queue_stats.validateAgainstServiceActionStats(wire_stats);
    try QueueChecks.expectTaggedPlanQueue(tagged_plan_queue.items, .{ 0, 1, 2 });
    var tagged_plan_stats_sink: TaggedPlanSink = .{};
    const tagged_plan_output_stats = try cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToTaggedSinkStats(wire_stats, wire_plans[0..], unified_outputs[0..], &tagged_plan_stats_sink, TaggedPlanSink.handle);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, tagged_plan_output_stats);
    try tagged_plan_output_stats.validateAgainstServiceActionStats(wire_stats);
    try std.testing.expectEqual(@as(usize, 3), tagged_plan_stats_sink.sent);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToTaggedSink(wire_stats, wire_plans[0..2], unified_outputs[0..], &tagged_plan_sink, TaggedPlanSink.handle));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.sendRpcServiceActionUnifiedOutputPlansToTaggedSink(wire_stats, overlong_wire_plans[0..], unified_outputs[0..], &tagged_plan_sink, TaggedPlanSink.handle));
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.appendRpcServiceActionUnifiedOutputPlansToTaggedQueue(std.testing.allocator, wire_stats, wire_plans[0..2], unified_outputs[0..], &tagged_plan_queue));

    var direct_tagged_plan_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer direct_tagged_plan_sink_state.deinit();
    try direct_tagged_plan_sink_state.addImport(5);
    try direct_tagged_plan_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try direct_tagged_plan_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try direct_tagged_plan_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var direct_tagged_plan_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_plan_sink_builder0.deinit();
    const direct_tagged_plan_sink_output0 = try generated.Message.initRootTyped(&direct_tagged_plan_sink_builder0);
    var direct_tagged_plan_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_plan_sink_builder1.deinit();
    const direct_tagged_plan_sink_output1 = try generated.Message.initRootTyped(&direct_tagged_plan_sink_builder1);
    var direct_tagged_plan_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_plan_sink_builder2.deinit();
    const direct_tagged_plan_sink_output2 = try generated.Message.initRootTyped(&direct_tagged_plan_sink_builder2);
    const direct_tagged_plan_sink_outputs = [_]generated.Message.Builder{ direct_tagged_plan_sink_output0, direct_tagged_plan_sink_output1, direct_tagged_plan_sink_output2 };
    var direct_tagged_plan_sink_context: Context = .{};
    var direct_tagged_plan_sink: TaggedPlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToTaggedSink(
        &direct_tagged_plan_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_plan_sink_outputs[0..2],
        &direct_tagged_plan_sink_context,
        entries,
        &direct_tagged_plan_sink,
        TaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToTaggedSink(
        &direct_tagged_plan_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_plan_sink_outputs[0..],
        &direct_tagged_plan_sink_context,
        entries,
        &direct_tagged_plan_sink,
        TaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_tagged_plan_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), direct_tagged_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1 + 2), direct_tagged_plan_sink.source_sum);
    try std.testing.expectEqual(@as(usize, 0 + 1), direct_tagged_plan_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), direct_tagged_plan_sink.forward_local_sum);

    var direct_tagged_plan_queue_state = try Seed.state();
    defer direct_tagged_plan_queue_state.deinit();
    var direct_tagged_plan_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_plan_queue_builder0.deinit();
    const direct_tagged_plan_queue_output0 = try generated.Message.initRootTyped(&direct_tagged_plan_queue_builder0);
    var direct_tagged_plan_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_plan_queue_builder1.deinit();
    const direct_tagged_plan_queue_output1 = try generated.Message.initRootTyped(&direct_tagged_plan_queue_builder1);
    var direct_tagged_plan_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_plan_queue_builder2.deinit();
    const direct_tagged_plan_queue_output2 = try generated.Message.initRootTyped(&direct_tagged_plan_queue_builder2);
    const direct_tagged_plan_queue_outputs = [_]generated.Message.Builder{ direct_tagged_plan_queue_output0, direct_tagged_plan_queue_output1, direct_tagged_plan_queue_output2 };
    var direct_tagged_plan_queue_context: Context = .{};
    var direct_tagged_plan_queue = std.ArrayList(PlanTaggedQueueItem).empty;
    defer direct_tagged_plan_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToTaggedQueue(
        &direct_tagged_plan_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_plan_queue_outputs[0..2],
        &direct_tagged_plan_queue_context,
        entries,
        &direct_tagged_plan_queue,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToTaggedQueue(
        &direct_tagged_plan_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_plan_queue_outputs[0..],
        &direct_tagged_plan_queue_context,
        entries,
        &direct_tagged_plan_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_tagged_plan_queue_context.selected);
    try QueueChecks.expectTaggedPlanQueue(direct_tagged_plan_queue.items, .{ 0, 1, 2 });

    var direct_plan_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer direct_plan_sink_state.deinit();
    try direct_plan_sink_state.addImport(5);
    try direct_plan_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try direct_plan_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try direct_plan_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var direct_plan_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_sink_builder0.deinit();
    const direct_plan_sink_output0 = try generated.Message.initRootTyped(&direct_plan_sink_builder0);
    var direct_plan_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_sink_builder1.deinit();
    const direct_plan_sink_output1 = try generated.Message.initRootTyped(&direct_plan_sink_builder1);
    var direct_plan_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_sink_builder2.deinit();
    const direct_plan_sink_output2 = try generated.Message.initRootTyped(&direct_plan_sink_builder2);
    const direct_plan_sink_outputs = [_]generated.Message.Builder{ direct_plan_sink_output0, direct_plan_sink_output1, direct_plan_sink_output2 };
    var direct_plan_sink_context: Context = .{};
    var direct_plan_sink: PlanSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToSink(
        &direct_plan_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_plan_sink_outputs[0..2],
        &direct_plan_sink_context,
        entries,
        &direct_plan_sink,
        PlanSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToSink(
        &direct_plan_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_plan_sink_outputs[0..],
        &direct_plan_sink_context,
        entries,
        &direct_plan_sink,
        PlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_plan_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), direct_plan_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1 + 2), direct_plan_sink.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72 + 73), direct_plan_sink.question_sum);

    var direct_plan_queue_state = try Seed.state();
    defer direct_plan_queue_state.deinit();
    var direct_plan_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_queue_builder0.deinit();
    const direct_plan_queue_output0 = try generated.Message.initRootTyped(&direct_plan_queue_builder0);
    var direct_plan_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_queue_builder1.deinit();
    const direct_plan_queue_output1 = try generated.Message.initRootTyped(&direct_plan_queue_builder1);
    var direct_plan_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_queue_builder2.deinit();
    const direct_plan_queue_output2 = try generated.Message.initRootTyped(&direct_plan_queue_builder2);
    const direct_plan_queue_outputs = [_]generated.Message.Builder{ direct_plan_queue_output0, direct_plan_queue_output1, direct_plan_queue_output2 };
    var direct_plan_queue_context: Context = .{};
    var direct_plan_queue = std.ArrayList(PlanQueueItem).empty;
    defer direct_plan_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToQueue(
        &direct_plan_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_plan_queue_outputs[0..2],
        &direct_plan_queue_context,
        entries,
        &direct_plan_queue,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToQueue(
        &direct_plan_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_plan_queue_outputs[0..],
        &direct_plan_queue_context,
        entries,
        &direct_plan_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_plan_queue_context.selected);
    try QueueChecks.expectPlanQueue(direct_plan_queue.items, .{ 0, 1, 2 });

    var direct_plan_split_queue_state = try Seed.state();
    defer direct_plan_split_queue_state.deinit();
    var direct_plan_split_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_split_queue_builder0.deinit();
    const direct_plan_split_queue_output0 = try generated.Message.initRootTyped(&direct_plan_split_queue_builder0);
    var direct_plan_split_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_split_queue_builder1.deinit();
    const direct_plan_split_queue_output1 = try generated.Message.initRootTyped(&direct_plan_split_queue_builder1);
    var direct_plan_split_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_plan_split_queue_builder2.deinit();
    const direct_plan_split_queue_output2 = try generated.Message.initRootTyped(&direct_plan_split_queue_builder2);
    const direct_plan_split_queue_outputs = [_]generated.Message.Builder{ direct_plan_split_queue_output0, direct_plan_split_queue_output1, direct_plan_split_queue_output2 };
    var direct_plan_split_queue_context: Context = .{};
    var direct_plan_split_response_queue = std.ArrayList(PlanQueueItem).empty;
    defer direct_plan_split_response_queue.deinit(std.testing.allocator);
    var direct_plan_split_forward_queue = std.ArrayList(PlanQueueItem).empty;
    defer direct_plan_split_forward_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToQueues(
        &direct_plan_split_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_plan_split_queue_outputs[0..2],
        &direct_plan_split_queue_context,
        entries,
        &direct_plan_split_response_queue,
        &direct_plan_split_forward_queue,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputPlansToQueues(
        &direct_plan_split_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_plan_split_queue_outputs[0..],
        &direct_plan_split_queue_context,
        entries,
        &direct_plan_split_response_queue,
        &direct_plan_split_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_plan_split_queue_context.selected);
    try QueueChecks.expectSplitPlanQueues(direct_plan_split_response_queue.items, direct_plan_split_forward_queue.items, .{ 0, 1 }, 2);

    var direct_role_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer direct_role_sink_state.deinit();
    try direct_role_sink_state.addImport(5);
    try direct_role_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try direct_role_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try direct_role_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var direct_role_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_role_sink_builder0.deinit();
    const direct_role_sink_output0 = try generated.Message.initRootTyped(&direct_role_sink_builder0);
    var direct_role_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_role_sink_builder1.deinit();
    const direct_role_sink_output1 = try generated.Message.initRootTyped(&direct_role_sink_builder1);
    var direct_role_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_role_sink_builder2.deinit();
    const direct_role_sink_output2 = try generated.Message.initRootTyped(&direct_role_sink_builder2);
    const direct_role_sink_outputs = [_]generated.Message.Builder{ direct_role_sink_output0, direct_role_sink_output1, direct_role_sink_output2 };
    var direct_role_sink_context: Context = .{};
    var direct_role_response_sink: ResponseSink = .{};
    var direct_role_forward_sink: ForwardSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToSinks(
        &direct_role_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_role_sink_outputs[0..2],
        &direct_role_sink_context,
        entries,
        &direct_role_response_sink,
        ResponseSink.handle,
        &direct_role_forward_sink,
        ForwardSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToSinks(
        &direct_role_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_role_sink_outputs[0..],
        &direct_role_sink_context,
        entries,
        &direct_role_response_sink,
        ResponseSink.handle,
        &direct_role_forward_sink,
        ForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_role_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 2), direct_role_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), direct_role_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), direct_role_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), direct_role_forward_sink.question_sum);

    var direct_tagged_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer direct_tagged_sink_state.deinit();
    try direct_tagged_sink_state.addImport(5);
    try direct_tagged_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try direct_tagged_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try direct_tagged_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var direct_tagged_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_sink_builder0.deinit();
    const direct_tagged_sink_output0 = try generated.Message.initRootTyped(&direct_tagged_sink_builder0);
    var direct_tagged_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_sink_builder1.deinit();
    const direct_tagged_sink_output1 = try generated.Message.initRootTyped(&direct_tagged_sink_builder1);
    var direct_tagged_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_sink_builder2.deinit();
    const direct_tagged_sink_output2 = try generated.Message.initRootTyped(&direct_tagged_sink_builder2);
    const direct_tagged_sink_outputs = [_]generated.Message.Builder{ direct_tagged_sink_output0, direct_tagged_sink_output1, direct_tagged_sink_output2 };
    var direct_tagged_sink_context: Context = .{};
    var direct_tagged_sink: MessageTaggedSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToTaggedSink(
        &direct_tagged_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_sink_outputs[0..2],
        &direct_tagged_sink_context,
        entries,
        &direct_tagged_sink,
        MessageTaggedSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToTaggedSink(
        &direct_tagged_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_sink_outputs[0..],
        &direct_tagged_sink_context,
        entries,
        &direct_tagged_sink,
        MessageTaggedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_tagged_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), direct_tagged_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1), direct_tagged_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), direct_tagged_sink.forward_local_sum);

    var direct_tagged_output_queue_state = try Seed.state();
    defer direct_tagged_output_queue_state.deinit();
    var direct_tagged_output_queue_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_output_queue_builder0.deinit();
    const direct_tagged_output_queue_output0 = try generated.Message.initRootTyped(&direct_tagged_output_queue_builder0);
    var direct_tagged_output_queue_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_output_queue_builder1.deinit();
    const direct_tagged_output_queue_output1 = try generated.Message.initRootTyped(&direct_tagged_output_queue_builder1);
    var direct_tagged_output_queue_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer direct_tagged_output_queue_builder2.deinit();
    const direct_tagged_output_queue_output2 = try generated.Message.initRootTyped(&direct_tagged_output_queue_builder2);
    const direct_tagged_output_queue_outputs = [_]generated.Message.Builder{ direct_tagged_output_queue_output0, direct_tagged_output_queue_output1, direct_tagged_output_queue_output2 };
    var direct_tagged_output_queue_context: Context = .{};
    var direct_tagged_output_queue = std.ArrayList(ServiceTaggedQueueItem).empty;
    defer direct_tagged_output_queue.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToTaggedQueue(
        &direct_tagged_output_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_output_queue_outputs[0..2],
        &direct_tagged_output_queue_context,
        entries,
        &direct_tagged_output_queue,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToTaggedQueue(
        &direct_tagged_output_queue_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        direct_tagged_output_queue_outputs[0..],
        &direct_tagged_output_queue_context,
        entries,
        &direct_tagged_output_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), direct_tagged_output_queue_context.selected);
    try std.testing.expectEqual(@as(usize, 3), direct_tagged_output_queue.items.len);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, direct_tagged_output_queue.items[0].position);
    try std.testing.expectEqual(@as(u32, 71), try (try direct_tagged_output_queue.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, direct_tagged_output_queue.items[1].position);
    try std.testing.expectEqual(@as(u32, 72), try (try direct_tagged_output_queue.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, direct_tagged_output_queue.items[2].position);
    try std.testing.expectEqual(@as(u32, 73), try (try direct_tagged_output_queue.items[2].message.get_call()).get_questionId());

    var output_queue_wrapper_state = try Seed.state();
    defer output_queue_wrapper_state.deinit();
    var output_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var output_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_queue_wrapper_builder0.deinit();
    const output_queue_wrapper_output0 = try generated.Message.initRootTyped(&output_queue_wrapper_builder0);
    var output_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_queue_wrapper_builder1.deinit();
    const output_queue_wrapper_output1 = try generated.Message.initRootTyped(&output_queue_wrapper_builder1);
    var output_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_queue_wrapper_builder2.deinit();
    const output_queue_wrapper_output2 = try generated.Message.initRootTyped(&output_queue_wrapper_builder2);
    const output_queue_wrapper_outputs = [_]generated.Message.Builder{ output_queue_wrapper_output0, output_queue_wrapper_output1, output_queue_wrapper_output2 };
    var output_queue_wrapper_context: Context = .{};
    var output_queue_wrapper = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue_wrapper.deinit(std.testing.allocator);
    var output_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, output_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedToQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        output_queue_wrapper_short_plan_buffer[0..],
        output_queue_wrapper_outputs[0..],
        &output_queue_wrapper_context,
        &output_queue_wrapper,
    ));
    try std.testing.expectEqual(wire_stats, try output_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedToQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        output_queue_wrapper_plan_buffer[0..],
        output_queue_wrapper_outputs[0..],
        &output_queue_wrapper_context,
        &output_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), output_queue_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), output_queue_wrapper.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try output_queue_wrapper.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try output_queue_wrapper.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try output_queue_wrapper.items[2].get_call()).get_questionId());

    var split_output_queue_wrapper_state = try Seed.state();
    defer split_output_queue_wrapper_state.deinit();
    var split_output_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var split_output_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_output_queue_wrapper_builder0.deinit();
    const split_output_queue_wrapper_output0 = try generated.Message.initRootTyped(&split_output_queue_wrapper_builder0);
    var split_output_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_output_queue_wrapper_builder1.deinit();
    const split_output_queue_wrapper_output1 = try generated.Message.initRootTyped(&split_output_queue_wrapper_builder1);
    var split_output_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer split_output_queue_wrapper_builder2.deinit();
    const split_output_queue_wrapper_output2 = try generated.Message.initRootTyped(&split_output_queue_wrapper_builder2);
    const split_output_queue_wrapper_outputs = [_]generated.Message.Builder{ split_output_queue_wrapper_output0, split_output_queue_wrapper_output1, split_output_queue_wrapper_output2 };
    var split_output_queue_wrapper_context: Context = .{};
    var output_wrapper_response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_wrapper_response_queue.deinit(std.testing.allocator);
    var output_wrapper_forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_wrapper_forward_queue.deinit(std.testing.allocator);
    var split_output_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, split_output_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedToQueues(
        std.testing.allocator,
        calls[0..],
        entries,
        split_output_queue_wrapper_short_plan_buffer[0..],
        split_output_queue_wrapper_outputs[0..],
        &split_output_queue_wrapper_context,
        &output_wrapper_response_queue,
        &output_wrapper_forward_queue,
    ));
    try std.testing.expectEqual(wire_stats, try split_output_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedToQueues(
        std.testing.allocator,
        calls[0..],
        entries,
        split_output_queue_wrapper_plan_buffer[0..],
        split_output_queue_wrapper_outputs[0..],
        &split_output_queue_wrapper_context,
        &output_wrapper_response_queue,
        &output_wrapper_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), split_output_queue_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 2), output_wrapper_response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), output_wrapper_forward_queue.items.len);
    try std.testing.expectEqual(@as(u32, 71), try (try output_wrapper_response_queue.items[0].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 72), try (try output_wrapper_response_queue.items[1].get_return_()).get_answerId());
    try std.testing.expectEqual(@as(u32, 73), try (try output_wrapper_forward_queue.items[0].get_call()).get_questionId());

    var tagged_output_queue_wrapper_state = try Seed.state();
    defer tagged_output_queue_wrapper_state.deinit();
    var tagged_output_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var tagged_output_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_output_queue_wrapper_builder0.deinit();
    const tagged_output_queue_wrapper_output0 = try generated.Message.initRootTyped(&tagged_output_queue_wrapper_builder0);
    var tagged_output_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_output_queue_wrapper_builder1.deinit();
    const tagged_output_queue_wrapper_output1 = try generated.Message.initRootTyped(&tagged_output_queue_wrapper_builder1);
    var tagged_output_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_output_queue_wrapper_builder2.deinit();
    const tagged_output_queue_wrapper_output2 = try generated.Message.initRootTyped(&tagged_output_queue_wrapper_builder2);
    const tagged_output_queue_wrapper_outputs = [_]generated.Message.Builder{ tagged_output_queue_wrapper_output0, tagged_output_queue_wrapper_output1, tagged_output_queue_wrapper_output2 };
    var tagged_output_queue_wrapper_context: Context = .{};
    var tagged_output_queue_wrapper = std.ArrayList(ServiceTaggedQueueItem).empty;
    defer tagged_output_queue_wrapper.deinit(std.testing.allocator);
    var tagged_output_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, tagged_output_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedToTaggedQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_output_queue_wrapper_short_plan_buffer[0..],
        tagged_output_queue_wrapper_outputs[0..],
        &tagged_output_queue_wrapper_context,
        &tagged_output_queue_wrapper,
    ));
    try std.testing.expectEqual(wire_stats, try tagged_output_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedToTaggedQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_output_queue_wrapper_plan_buffer[0..],
        tagged_output_queue_wrapper_outputs[0..],
        &tagged_output_queue_wrapper_context,
        &tagged_output_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), tagged_output_queue_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), tagged_output_queue_wrapper.items.len);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 0 }, tagged_output_queue_wrapper.items[0].position);
    try std.testing.expectEqual(@as(u32, 71), try (try tagged_output_queue_wrapper.items[0].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .response, .local_index = 1 }, tagged_output_queue_wrapper.items[1].position);
    try std.testing.expectEqual(@as(u32, 72), try (try tagged_output_queue_wrapper.items[1].message.get_return_()).get_answerId());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputPosition{ .role = .forward, .local_index = 0 }, tagged_output_queue_wrapper.items[2].position);
    try std.testing.expectEqual(@as(u32, 73), try (try tagged_output_queue_wrapper.items[2].message.get_call()).get_questionId());

    var tagged_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer tagged_wrapper_state.deinit();
    try tagged_wrapper_state.addImport(5);
    try tagged_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try tagged_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try tagged_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var tagged_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var tagged_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_wrapper_builder0.deinit();
    const tagged_wrapper_output0 = try generated.Message.initRootTyped(&tagged_wrapper_builder0);
    var tagged_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_wrapper_builder1.deinit();
    const tagged_wrapper_output1 = try generated.Message.initRootTyped(&tagged_wrapper_builder1);
    var tagged_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_wrapper_builder2.deinit();
    const tagged_wrapper_output2 = try generated.Message.initRootTyped(&tagged_wrapper_builder2);
    const tagged_wrapper_outputs = [_]generated.Message.Builder{ tagged_wrapper_output0, tagged_wrapper_output1, tagged_wrapper_output2 };
    var tagged_wrapper_context: Context = .{};
    var tagged_wrapper_sink: MessageTaggedSink = .{};
    var tagged_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, tagged_wrapper_state.dispatchWireCallServiceActionsUnifiedToTaggedSink(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_wrapper_short_plan_buffer[0..],
        tagged_wrapper_outputs[0..],
        &tagged_wrapper_context,
        &tagged_wrapper_sink,
        MessageTaggedSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try tagged_wrapper_state.dispatchWireCallServiceActionsUnifiedToTaggedSink(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_wrapper_plan_buffer[0..],
        tagged_wrapper_outputs[0..],
        &tagged_wrapper_context,
        &tagged_wrapper_sink,
        MessageTaggedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), tagged_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), tagged_wrapper_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1), tagged_wrapper_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_wrapper_sink.forward_local_sum);

    var role_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer role_wrapper_state.deinit();
    try role_wrapper_state.addImport(5);
    try role_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try role_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try role_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var role_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var role_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_wrapper_builder0.deinit();
    const role_wrapper_output0 = try generated.Message.initRootTyped(&role_wrapper_builder0);
    var role_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_wrapper_builder1.deinit();
    const role_wrapper_output1 = try generated.Message.initRootTyped(&role_wrapper_builder1);
    var role_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer role_wrapper_builder2.deinit();
    const role_wrapper_output2 = try generated.Message.initRootTyped(&role_wrapper_builder2);
    const role_wrapper_outputs = [_]generated.Message.Builder{ role_wrapper_output0, role_wrapper_output1, role_wrapper_output2 };
    var role_wrapper_context: Context = .{};
    var role_wrapper_response_sink: ResponseSink = .{};
    var role_wrapper_forward_sink: ForwardSink = .{};
    var role_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, role_wrapper_state.dispatchWireCallServiceActionsUnifiedToSinks(
        std.testing.allocator,
        calls[0..],
        entries,
        role_wrapper_short_plan_buffer[0..],
        role_wrapper_outputs[0..],
        &role_wrapper_context,
        &role_wrapper_response_sink,
        ResponseSink.handle,
        &role_wrapper_forward_sink,
        ForwardSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try role_wrapper_state.dispatchWireCallServiceActionsUnifiedToSinks(
        std.testing.allocator,
        calls[0..],
        entries,
        role_wrapper_plan_buffer[0..],
        role_wrapper_outputs[0..],
        &role_wrapper_context,
        &role_wrapper_response_sink,
        ResponseSink.handle,
        &role_wrapper_forward_sink,
        ForwardSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), role_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 2), role_wrapper_response_sink.sent);
    try std.testing.expectEqual(@as(u32, 71 + 72), role_wrapper_response_sink.answer_sum);
    try std.testing.expectEqual(@as(usize, 1), role_wrapper_forward_sink.sent);
    try std.testing.expectEqual(@as(u32, 73), role_wrapper_forward_sink.question_sum);

    var plan_sink_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer plan_sink_wrapper_state.deinit();
    try plan_sink_wrapper_state.addImport(5);
    try plan_sink_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try plan_sink_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try plan_sink_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var plan_sink_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var plan_sink_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_sink_wrapper_builder0.deinit();
    const plan_sink_wrapper_output0 = try generated.Message.initRootTyped(&plan_sink_wrapper_builder0);
    var plan_sink_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_sink_wrapper_builder1.deinit();
    const plan_sink_wrapper_output1 = try generated.Message.initRootTyped(&plan_sink_wrapper_builder1);
    var plan_sink_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_sink_wrapper_builder2.deinit();
    const plan_sink_wrapper_output2 = try generated.Message.initRootTyped(&plan_sink_wrapper_builder2);
    const plan_sink_wrapper_outputs = [_]generated.Message.Builder{ plan_sink_wrapper_output0, plan_sink_wrapper_output1, plan_sink_wrapper_output2 };
    var plan_sink_wrapper_context: Context = .{};
    var plan_sink_wrapper: PlanSink = .{};
    var plan_sink_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, plan_sink_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToSink(
        std.testing.allocator,
        calls[0..],
        entries,
        plan_sink_wrapper_short_plan_buffer[0..],
        plan_sink_wrapper_outputs[0..],
        &plan_sink_wrapper_context,
        &plan_sink_wrapper,
        PlanSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try plan_sink_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToSink(
        std.testing.allocator,
        calls[0..],
        entries,
        plan_sink_wrapper_plan_buffer[0..],
        plan_sink_wrapper_outputs[0..],
        &plan_sink_wrapper_context,
        &plan_sink_wrapper,
        PlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), plan_sink_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), plan_sink_wrapper.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1 + 2), plan_sink_wrapper.source_sum);
    try std.testing.expectEqual(@as(u32, 71 + 72 + 73), plan_sink_wrapper.question_sum);

    var plan_queue_wrapper_state = try Seed.state();
    defer plan_queue_wrapper_state.deinit();
    var plan_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var plan_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_queue_wrapper_builder0.deinit();
    const plan_queue_wrapper_output0 = try generated.Message.initRootTyped(&plan_queue_wrapper_builder0);
    var plan_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_queue_wrapper_builder1.deinit();
    const plan_queue_wrapper_output1 = try generated.Message.initRootTyped(&plan_queue_wrapper_builder1);
    var plan_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_queue_wrapper_builder2.deinit();
    const plan_queue_wrapper_output2 = try generated.Message.initRootTyped(&plan_queue_wrapper_builder2);
    const plan_queue_wrapper_outputs = [_]generated.Message.Builder{ plan_queue_wrapper_output0, plan_queue_wrapper_output1, plan_queue_wrapper_output2 };
    var plan_queue_wrapper_context: Context = .{};
    var plan_queue_wrapper = std.ArrayList(PlanQueueItem).empty;
    defer plan_queue_wrapper.deinit(std.testing.allocator);
    var plan_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, plan_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        plan_queue_wrapper_short_plan_buffer[0..],
        plan_queue_wrapper_outputs[0..],
        &plan_queue_wrapper_context,
        &plan_queue_wrapper,
    ));
    try std.testing.expectEqual(wire_stats, try plan_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        plan_queue_wrapper_plan_buffer[0..],
        plan_queue_wrapper_outputs[0..],
        &plan_queue_wrapper_context,
        &plan_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), plan_queue_wrapper_context.selected);
    try QueueChecks.expectPlanQueue(plan_queue_wrapper.items, .{ 0, 1, 2 });

    var plan_split_queue_wrapper_state = try Seed.state();
    defer plan_split_queue_wrapper_state.deinit();
    var plan_split_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var plan_split_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_split_queue_wrapper_builder0.deinit();
    const plan_split_queue_wrapper_output0 = try generated.Message.initRootTyped(&plan_split_queue_wrapper_builder0);
    var plan_split_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_split_queue_wrapper_builder1.deinit();
    const plan_split_queue_wrapper_output1 = try generated.Message.initRootTyped(&plan_split_queue_wrapper_builder1);
    var plan_split_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer plan_split_queue_wrapper_builder2.deinit();
    const plan_split_queue_wrapper_output2 = try generated.Message.initRootTyped(&plan_split_queue_wrapper_builder2);
    const plan_split_queue_wrapper_outputs = [_]generated.Message.Builder{ plan_split_queue_wrapper_output0, plan_split_queue_wrapper_output1, plan_split_queue_wrapper_output2 };
    var plan_split_queue_wrapper_context: Context = .{};
    var plan_split_response_queue = std.ArrayList(PlanQueueItem).empty;
    defer plan_split_response_queue.deinit(std.testing.allocator);
    var plan_split_forward_queue = std.ArrayList(PlanQueueItem).empty;
    defer plan_split_forward_queue.deinit(std.testing.allocator);
    var plan_split_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, plan_split_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToQueues(
        std.testing.allocator,
        calls[0..],
        entries,
        plan_split_queue_wrapper_short_plan_buffer[0..],
        plan_split_queue_wrapper_outputs[0..],
        &plan_split_queue_wrapper_context,
        &plan_split_response_queue,
        &plan_split_forward_queue,
    ));
    try std.testing.expectEqual(wire_stats, try plan_split_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToQueues(
        std.testing.allocator,
        calls[0..],
        entries,
        plan_split_queue_wrapper_plan_buffer[0..],
        plan_split_queue_wrapper_outputs[0..],
        &plan_split_queue_wrapper_context,
        &plan_split_response_queue,
        &plan_split_forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 71), plan_split_queue_wrapper_context.selected);
    try QueueChecks.expectSplitPlanQueues(plan_split_response_queue.items, plan_split_forward_queue.items, .{ 0, 1 }, 2);

    var tagged_plan_wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer tagged_plan_wrapper_state.deinit();
    try tagged_plan_wrapper_state.addImport(5);
    try tagged_plan_wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try tagged_plan_wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try tagged_plan_wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var tagged_plan_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var tagged_plan_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_plan_wrapper_builder0.deinit();
    const tagged_plan_wrapper_output0 = try generated.Message.initRootTyped(&tagged_plan_wrapper_builder0);
    var tagged_plan_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_plan_wrapper_builder1.deinit();
    const tagged_plan_wrapper_output1 = try generated.Message.initRootTyped(&tagged_plan_wrapper_builder1);
    var tagged_plan_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_plan_wrapper_builder2.deinit();
    const tagged_plan_wrapper_output2 = try generated.Message.initRootTyped(&tagged_plan_wrapper_builder2);
    const tagged_plan_wrapper_outputs = [_]generated.Message.Builder{ tagged_plan_wrapper_output0, tagged_plan_wrapper_output1, tagged_plan_wrapper_output2 };
    var tagged_plan_wrapper_context: Context = .{};
    var tagged_plan_wrapper_sink: TaggedPlanSink = .{};
    var tagged_plan_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, tagged_plan_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToTaggedSink(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_plan_wrapper_short_plan_buffer[0..],
        tagged_plan_wrapper_outputs[0..],
        &tagged_plan_wrapper_context,
        &tagged_plan_wrapper_sink,
        TaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try tagged_plan_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToTaggedSink(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_plan_wrapper_plan_buffer[0..],
        tagged_plan_wrapper_outputs[0..],
        &tagged_plan_wrapper_context,
        &tagged_plan_wrapper_sink,
        TaggedPlanSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), tagged_plan_wrapper_context.selected);
    try std.testing.expectEqual(@as(usize, 3), tagged_plan_wrapper_sink.sent);
    try std.testing.expectEqual(@as(usize, 0 + 1 + 2), tagged_plan_wrapper_sink.source_sum);
    try std.testing.expectEqual(@as(usize, 0 + 1), tagged_plan_wrapper_sink.response_local_sum);
    try std.testing.expectEqual(@as(usize, 0), tagged_plan_wrapper_sink.forward_local_sum);

    var tagged_plan_queue_wrapper_state = try Seed.state();
    defer tagged_plan_queue_wrapper_state.deinit();
    var tagged_plan_queue_wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var tagged_plan_queue_wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_plan_queue_wrapper_builder0.deinit();
    const tagged_plan_queue_wrapper_output0 = try generated.Message.initRootTyped(&tagged_plan_queue_wrapper_builder0);
    var tagged_plan_queue_wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_plan_queue_wrapper_builder1.deinit();
    const tagged_plan_queue_wrapper_output1 = try generated.Message.initRootTyped(&tagged_plan_queue_wrapper_builder1);
    var tagged_plan_queue_wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer tagged_plan_queue_wrapper_builder2.deinit();
    const tagged_plan_queue_wrapper_output2 = try generated.Message.initRootTyped(&tagged_plan_queue_wrapper_builder2);
    const tagged_plan_queue_wrapper_outputs = [_]generated.Message.Builder{ tagged_plan_queue_wrapper_output0, tagged_plan_queue_wrapper_output1, tagged_plan_queue_wrapper_output2 };
    var tagged_plan_queue_wrapper_context: Context = .{};
    var tagged_plan_queue_wrapper = std.ArrayList(PlanTaggedQueueItem).empty;
    defer tagged_plan_queue_wrapper.deinit(std.testing.allocator);
    var tagged_plan_queue_wrapper_short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, tagged_plan_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToTaggedQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_plan_queue_wrapper_short_plan_buffer[0..],
        tagged_plan_queue_wrapper_outputs[0..],
        &tagged_plan_queue_wrapper_context,
        &tagged_plan_queue_wrapper,
    ));
    try std.testing.expectEqual(wire_stats, try tagged_plan_queue_wrapper_state.dispatchWireCallServiceActionsUnifiedOutputPlansToTaggedQueue(
        std.testing.allocator,
        calls[0..],
        entries,
        tagged_plan_queue_wrapper_plan_buffer[0..],
        tagged_plan_queue_wrapper_outputs[0..],
        &tagged_plan_queue_wrapper_context,
        &tagged_plan_queue_wrapper,
    ));
    try std.testing.expectEqual(@as(u32, 71), tagged_plan_queue_wrapper_context.selected);
    try QueueChecks.expectTaggedPlanQueue(tagged_plan_queue_wrapper.items, .{ 0, 1, 2 });

    const UnifiedSink = struct {
        sent: usize = 0,
        responses: usize = 0,
        forwards: usize = 0,
        answer_sum: u32 = 0,
        question_sum: u32 = 0,

        fn handle(context: *@This(), message: anytype) !void {
            context.sent += 1;
            switch ((try message.which()).?) {
                .return_ => {
                    context.responses += 1;
                    context.answer_sum += try (try message.get_return_()).get_answerId();
                },
                .call => {
                    context.forwards += 1;
                    context.question_sum += try (try message.get_call()).get_questionId();
                },
                else => return error.TestUnexpectedResult,
            }
        }
    };
    var unified_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer unified_sink_state.deinit();
    try unified_sink_state.addImport(5);
    try unified_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try unified_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try unified_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var unified_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_sink_builder0.deinit();
    const unified_sink0 = try generated.Message.initRootTyped(&unified_sink_builder0);
    var unified_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_sink_builder1.deinit();
    const unified_sink1 = try generated.Message.initRootTyped(&unified_sink_builder1);
    var unified_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer unified_sink_builder2.deinit();
    const unified_sink2 = try generated.Message.initRootTyped(&unified_sink_builder2);
    const unified_sink_outputs = [_]generated.Message.Builder{ unified_sink0, unified_sink1, unified_sink2 };
    var unified_sink_context: Context = .{};
    var unified_sink: UnifiedSink = .{};
    try std.testing.expectError(error.InvalidTransition, cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToSink(
        &unified_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        unified_sink_outputs[0..2],
        &unified_sink_context,
        entries,
        &unified_sink,
        UnifiedSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try cpz.rpc.initWireCallServiceActionPlanUnifiedOutputsToSink(
        &unified_sink_state,
        std.testing.allocator,
        calls[0..],
        wire_plans[0..],
        unified_sink_outputs[0..],
        &unified_sink_context,
        entries,
        &unified_sink,
        UnifiedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), unified_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), unified_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), unified_sink.responses);
    try std.testing.expectEqual(@as(usize, 1), unified_sink.forwards);
    try std.testing.expectEqual(@as(u32, 71 + 72), unified_sink.answer_sum);
    try std.testing.expectEqual(@as(u32, 73), unified_sink.question_sum);

    var wrapper_state = cpz.rpc.State.init(std.testing.allocator);
    defer wrapper_state.deinit();
    try wrapper_state.addImport(5);
    try wrapper_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try wrapper_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try wrapper_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var wrapper_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var wrapper_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer wrapper_builder0.deinit();
    const wrapper_output0 = try generated.Message.initRootTyped(&wrapper_builder0);
    var wrapper_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer wrapper_builder1.deinit();
    const wrapper_output1 = try generated.Message.initRootTyped(&wrapper_builder1);
    var wrapper_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer wrapper_builder2.deinit();
    const wrapper_output2 = try generated.Message.initRootTyped(&wrapper_builder2);
    const wrapper_outputs = [_]generated.Message.Builder{ wrapper_output0, wrapper_output1, wrapper_output2 };
    var wrapper_context: Context = .{};
    var short_plan_buffer: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, wrapper_state.dispatchWireCallServiceActionsUnified(std.testing.allocator, calls[0..], entries, short_plan_buffer[0..], wrapper_outputs[0..], &wrapper_context));
    try std.testing.expectEqual(
        wire_stats,
        try wrapper_state.dispatchWireCallServiceActionsUnified(std.testing.allocator, calls[0..], entries, wrapper_plan_buffer[0..], wrapper_outputs[0..], &wrapper_context),
    );
    try std.testing.expectEqual(@as(u32, 71), wrapper_context.selected);
    var wrapper_reader0 = cpz.MessageReader.init(try wrapper_builder0.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 71), (try generated.Message.fromReader(try wrapper_reader0.getRoot()).return_()).answerId());
    var wrapper_reader1 = cpz.MessageReader.init(try wrapper_builder1.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 72), (try generated.Message.fromReader(try wrapper_reader1.getRoot()).return_()).answerId());
    var wrapper_reader2 = cpz.MessageReader.init(try wrapper_builder2.segmentsConst(), .{});
    const wrapper_forward = try generated.Message.fromReader(try wrapper_reader2.getRoot()).call();
    try std.testing.expectEqual(@as(u32, 73), wrapper_forward.questionId());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, try cpz.rpc.callTargetFromWireCall(wrapper_forward));

    var wrapper_sink_state = cpz.rpc.State.init(std.testing.allocator);
    defer wrapper_sink_state.deinit();
    try wrapper_sink_state.addImport(5);
    try wrapper_sink_state.applyCapDescriptor(.{ .sender_promise = 8 });
    try wrapper_sink_state.resolveImportTo(8, .{ .sender_hosted = 9 });
    try wrapper_sink_state.applyCapDescriptor(.{ .sender_hosted = 9 });
    var wrapper_sink_plan_buffer: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    var wrapper_sink_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer wrapper_sink_builder0.deinit();
    const wrapper_sink_output0 = try generated.Message.initRootTyped(&wrapper_sink_builder0);
    var wrapper_sink_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer wrapper_sink_builder1.deinit();
    const wrapper_sink_output1 = try generated.Message.initRootTyped(&wrapper_sink_builder1);
    var wrapper_sink_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer wrapper_sink_builder2.deinit();
    const wrapper_sink_output2 = try generated.Message.initRootTyped(&wrapper_sink_builder2);
    const wrapper_sink_outputs = [_]generated.Message.Builder{ wrapper_sink_output0, wrapper_sink_output1, wrapper_sink_output2 };
    var wrapper_sink_context: Context = .{};
    var wrapper_unified_sink: UnifiedSink = .{};
    try std.testing.expectError(error.InvalidTransition, wrapper_sink_state.dispatchWireCallServiceActionsUnifiedToSink(
        std.testing.allocator,
        calls[0..],
        entries,
        short_plan_buffer[0..],
        wrapper_sink_outputs[0..],
        &wrapper_sink_context,
        &wrapper_unified_sink,
        UnifiedSink.handle,
    ));
    try std.testing.expectEqual(wire_stats, try wrapper_sink_state.dispatchWireCallServiceActionsUnifiedToSink(
        std.testing.allocator,
        calls[0..],
        entries,
        wrapper_sink_plan_buffer[0..],
        wrapper_sink_outputs[0..],
        &wrapper_sink_context,
        &wrapper_unified_sink,
        UnifiedSink.handle,
    ));
    try std.testing.expectEqual(@as(u32, 71), wrapper_sink_context.selected);
    try std.testing.expectEqual(@as(usize, 3), wrapper_unified_sink.sent);
    try std.testing.expectEqual(@as(usize, 2), wrapper_unified_sink.responses);
    try std.testing.expectEqual(@as(usize, 1), wrapper_unified_sink.forwards);
    try std.testing.expectEqual(@as(u32, 71 + 72), wrapper_unified_sink.answer_sum);
    try std.testing.expectEqual(@as(u32, 73), wrapper_unified_sink.question_sum);

    var short_actions: [2]cpz.rpc.TrackedCallServiceAction = undefined;
    try std.testing.expectError(error.InvalidTransition, state.initWireCallServiceActions(calls[0..], entries, short_actions[0..]));
    var short_plans: [2]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectError(error.InvalidTransition, state.initWireCallServiceActionPlans(calls[0..], entries, short_plans[0..]));

    for (calls) |call| try state.applyWireCall(std.testing.allocator, call);
    const ids = [_]cpz.rpc.QuestionId{ 71, 72, 73, 74 };
    const tracked_stats = try state.trackedCallServiceActionStats(ids[0..], entries);
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionStats{
        .dispatch = 1,
        .forward = 1,
        .unimplemented = 1,
        .missing = 1,
    }, tracked_stats);
    try std.testing.expectEqual(@as(usize, 3), tracked_stats.actions());
    try std.testing.expectEqual(@as(usize, 4), tracked_stats.total());
    try tracked_stats.validateSplitCapacity(1, 1, 1);
    try tracked_stats.validateOutputCapacity(2, 1);
    try tracked_stats.validateActionCapacity(3);
    var tracked_actions: [3]cpz.rpc.TrackedCallServiceAction = undefined;
    try std.testing.expectEqual(tracked_stats, try state.initTrackedCallServiceActions(ids[0..], entries, tracked_actions[0..]));
    try std.testing.expectEqual(@as(usize, 0), tracked_actions[0].dispatch);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, tracked_actions[1].forward);
    try std.testing.expect(tracked_actions[2].isUnimplemented());
    var tracked_plans: [3]cpz.rpc.TrackedCallServiceActionPlan = undefined;
    try std.testing.expectEqual(tracked_stats, try state.initTrackedCallServiceActionPlans(ids[0..], entries, tracked_plans[0..]));
    try std.testing.expectEqual(@as(usize, 0), tracked_plans[0].source_index);
    try std.testing.expectEqual(@as(u32, 71), tracked_plans[0].question_id);
    try std.testing.expectEqual(@as(usize, 0), tracked_plans[0].action.dispatch);
    try std.testing.expectEqual(@as(usize, 2), tracked_plans[1].source_index);
    try std.testing.expectEqual(@as(u32, 73), tracked_plans[1].question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 9 }, tracked_plans[1].action.forward);
    try std.testing.expectEqual(@as(usize, 1), tracked_plans[2].source_index);
    try std.testing.expectEqual(@as(u32, 72), tracked_plans[2].question_id);
    try std.testing.expect(tracked_plans[2].action.isUnimplemented());
    try std.testing.expectError(error.InvalidTransition, state.initTrackedCallServiceActions(ids[0..], entries, short_actions[0..]));
    try std.testing.expectError(error.InvalidTransition, state.initTrackedCallServiceActionPlans(ids[0..], entries, short_plans[0..]));
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
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 140 }, state.trackedCallTarget(140).?);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 141 }, state.trackedCallTargetResolution(140).?);
    try std.testing.expectEqual(@as(?bool, true), state.trackedCallTargetResolved(140));
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, state.trackedCallTargetForwardTarget(140).?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, (try state.trackedCallTargetTransitiveForwardTarget(140)).?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, state.trackedCallEffectiveTarget(140).?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, (try state.trackedCallTransitiveEffectiveTarget(140)).?);
    const dispatch_info = (try state.trackedCallDispatchInfo(140)).?;
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 140 }, dispatch_info.info.target);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 141 }, dispatch_info.resolution.?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, dispatch_info.forward_target.?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, dispatch_info.effective_target);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, dispatch_info.transitive_forward_target.?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, dispatch_info.transitive_effective_target);
    try std.testing.expect(dispatch_info.needsForward());
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, dispatch_info.dispatchOutcome());
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, try state.wireCallDispatchOutcome(try request.call()));
    const default_method = cpz.rpc.CallMethod{};
    const entries = .{default_method.methodEntry(Handler.handle)};
    const wire_dispatch_info = try state.wireCallDispatchInfo(try request.call());
    try std.testing.expectEqual(@as(cpz.rpc.QuestionId, 140), wire_dispatch_info.info.question_id);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 140 }, wire_dispatch_info.info.target);
    try std.testing.expectEqual(default_method, wire_dispatch_info.info.callMethod());
    try std.testing.expectEqual(default_method.callOptions(), wire_dispatch_info.options);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, wire_dispatch_info.transitive_forward_target.?);
    try std.testing.expect(wire_dispatch_info.needsForward());
    const wire_info_action = try wire_dispatch_info.serviceAction(entries);
    try std.testing.expect(wire_info_action.isForward());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, wire_info_action.forward);
    const preview_action = try state.wireCallServiceAction(try request.call(), entries);
    try std.testing.expect(preview_action.isForward());
    try std.testing.expect(!preview_action.needsResponse());
    try std.testing.expect(preview_action.needsForward());
    try std.testing.expectEqual(cpz.rpc.TrackedCallServiceActionOutputRole.forward, preview_action.outputRole());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, preview_action.forward);
    const action = (try state.trackedCallServiceAction(140, entries)).?;
    try std.testing.expect(action.isForward());
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 141 }, action.forward);
    try std.testing.expect((try state.trackedCallServiceAction(141, entries)) == null);
    try std.testing.expect((try state.trackedCallDispatchInfo(141)) == null);
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

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue = std.ArrayList(generated.Message.Builder).empty;
    defer queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, try cpz.rpc.dispatchWireMessageMethodsToQueueOutcome(
        &queue_state,
        std.testing.allocator,
        queue_response,
        request,
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &queue,
    ));
    try std.testing.expectEqual(@as(u32, 0), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 32), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try support.expectQueuedReturnAnswer(queue.items[0], 32);
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

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 160 });
    try queue_state.resolveImportTo(160, .{ .sender_hosted = 161 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 161 });
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    const queue_outcome = try cpz.rpc.dispatchWireMessageForwardingToQueueOutcome(
        &queue_state,
        std.testing.allocator,
        queue_response,
        queue_forward,
        request,
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_call_seen,
        CallHandler.handle,
        &forward_queue,
    );
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, queue_outcome);
    try std.testing.expectEqual(@as(u32, 0), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 160, .{ .imported_cap = 161 });
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), queue_state.questionState(160));
    try std.testing.expectEqual(@as(usize, 1), queue_state.callInfoCount());
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
    try support.expectPayloadUInt32List(params, &.{ 1, 2, 3 });
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
    try support.expectPayloadUInt32List(try forwarded.params(), &.{ 9, 19 });

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.applyCapDescriptor(.{ .sender_promise = 190 });
    try queue_state.resolveImportTo(190, .{ .sender_hosted = 191 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 191 });
    var queue_response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_response_builder.deinit();
    const queue_response = try generated.Message.initRootTyped(&queue_response_builder);
    var queue_forward_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_forward_builder.deinit();
    const queue_forward = try generated.Message.initRootTyped(&queue_forward_builder);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_context: Context = .{};
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.forward_required, try cpz.rpc.dispatchWireMessageMethodsForwardingToQueueOutcome(
        &queue_state,
        std.testing.allocator,
        queue_response,
        queue_forward,
        request,
        &queue_bootstrap_seen,
        BootstrapHandler.handle,
        &queue_context,
        entries,
        &forward_queue,
    ));
    try std.testing.expectEqual(@as(u32, 0), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_context.selected);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 190, .{ .imported_cap = 191 });
}
