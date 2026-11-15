const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

test "rpc call helpers decode and write send-results-to targets" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try cpz.rpc.writeSendResultsToToWire(.yourself, call);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call_reader = generated.Call.fromReader(try reader.getRoot());
        const target = try cpz.rpc.sendResultsToFromWireCall(call_reader);
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.yourself, target);
        try std.testing.expect(target.isYourself());
        try std.testing.expect(!target.isCaller());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try cpz.rpc.writeSendResultsToThirdPartyToWire(call, .{ .max_capability_count = 4, .capability = 3 });

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const call_reader = generated.Call.fromReader(try reader.getRoot());
        const target = try cpz.rpc.sendResultsToFromWireCall(call_reader);
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, target);
        try std.testing.expect(target.isThirdParty());
        try std.testing.expect(!target.isYourself());
        const usage = (try cpz.rpc.sendResultsToThirdPartyUsageFromWireCall(call_reader)).?;
        try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, usage);
        try usage.validate();
        try std.testing.expect(usage.hasCapability());
        try std.testing.expect(usage.matchesCapability(3));
        try std.testing.expect(!usage.matchesCapability(2));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const call = try generated.Call.initRootTyped(&builder);
        try std.testing.expectError(error.InvalidTransition, cpz.rpc.writeSendResultsToThirdPartyToWire(call, .{ .max_capability_count = 4, .capability = 4 }));
        try std.testing.expectError(error.InvalidTransition, (cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 4 }).validate());
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
        const target = try cpz.rpc.sendResultsToFromWireCall(call_reader);
        try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.caller, target);
        try std.testing.expect(target.isCaller());
        try std.testing.expect(!target.isThirdParty());
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

test "rpc call capability helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessagePayloadCapabilityWithOptionsAndApplyState(
        &state,
        root,
        104,
        .{ .imported_cap = 5 },
        0,
        &.{.{ .sender_hosted = 105 }},
        .{ .method = .{ .interface_id = 0x104, .method_id = 15 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(104));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(104));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(105));
    const tracked = state.callInfo(104).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x104, .method_id = 15 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 105 }, descriptors[0]);
}

test "rpc call capability-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 106 }, .attached_fd = 20 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessagePayloadCapabilityInfoWithOptionsAndApplyState(
        &state,
        root,
        105,
        .{ .imported_cap = 5 },
        0,
        infos[0..],
        .{ .method = .{ .interface_id = 0x105, .method_id = 16 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(105));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(105));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(106));
    const tracked = state.callInfo(105).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x105, .method_id = 16 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc registry call capability helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "state-registry-call-capability");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessagePayloadCapabilityFromRegistryWithOptionsAndApplyState(
        &state,
        std.testing.allocator,
        root,
        106,
        .{ .imported_cap = 5 },
        0,
        &registry,
        .{ .method = .{ .interface_id = 0x106, .method_id = 17 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(106));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(106));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    const tracked = state.callInfo(106).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x106, .method_id = 17 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(params));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call struct helper can apply initialized state" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
            (try builder.getPointerField(0)).setCapability(0);
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var value: u32 = 0x2468ace0;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageStructWithOptionsAndApplyState(
        &state,
        root,
        107,
        .{ .imported_cap = 5 },
        cpz.StructSize{ .data_words = 1, .pointer_count = 1 },
        &.{.{ .sender_hosted = 108 }},
        &value,
        Fill.write,
        .{ .method = .{ .interface_id = 0x107, .method_id = 18 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(107));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(107));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(108));
    const tracked = state.callInfo(107).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x107, .method_id = 18 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x2468ace0), content.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 0), try content.getPointerField(0).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 108 }, descriptors[0]);
}

test "rpc call struct-info helper can apply initialized state" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
            (try builder.getPointerField(0)).setCapability(0);
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 109 }, .attached_fd = 21 }};
    var value: u32 = 0x13579bdf;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageStructInfoWithOptionsAndApplyState(
        &state,
        root,
        108,
        .{ .imported_cap = 5 },
        cpz.StructSize{ .data_words = 1, .pointer_count = 1 },
        infos[0..],
        &value,
        Fill.write,
        .{ .method = .{ .interface_id = 0x108, .method_id = 19 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(108));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(108));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(109));
    const tracked = state.callInfo(108).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x108, .method_id = 19 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x13579bdf), content.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 0), try content.getPointerField(0).getCapabilityIndex());
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc registry call struct helper can apply initialized state" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
            (try builder.getPointerField(0)).setCapability(0);
        }
    };

    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "state-registry-call-struct");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var value: u32 = 0xfedcba98;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageStructFromRegistryWithOptionsAndApplyState(
        &state,
        std.testing.allocator,
        root,
        109,
        .{ .imported_cap = 5 },
        cpz.StructSize{ .data_words = 1, .pointer_count = 1 },
        &registry,
        &value,
        Fill.write,
        .{ .method = .{ .interface_id = 0x109, .method_id = 20 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(109));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(109));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    const tracked = state.callInfo(109).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x109, .method_id = 20 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    const content = try (try params.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0xfedcba98), content.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 0), try content.getPointerField(0).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call text-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 92 }, .attached_fd = 17 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageTextInfoWithOptionsAndApplyState(
        &state,
        root,
        98,
        .{ .imported_cap = 5 },
        "state call text info",
        infos[0..],
        .{ .method = .{ .interface_id = 0x98, .method_id = 8 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(98));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(98));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(92));
    const tracked = state.callInfo(98).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x98, .method_id = 8 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualStrings("state call text info", try (try params.content()).getText());
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc call data-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 94 }, .attached_fd = 18 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageDataInfoWithOptionsAndApplyState(
        &state,
        root,
        99,
        .{ .imported_cap = 5 },
        "state call data info",
        infos[0..],
        .{ .method = .{ .interface_id = 0x99, .method_id = 9 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(99));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(99));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(94));
    const tracked = state.callInfo(99).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x99, .method_id = 9 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualSlices(u8, "state call data info", try (try params.content()).getData());
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc call text helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageTextWithOptionsAndApplyState(
        &state,
        root,
        84,
        .{ .imported_cap = 5 },
        "state call text",
        &.{.{ .sender_hosted = 91 }},
        .{
            .method = .{ .interface_id = 0x84, .method_id = 4 },
            .flags = .{ .no_promise_pipelining = true },
        },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(84));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(84));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(91));
    const tracked = state.callInfo(84).?;
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, tracked.target);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x84, .method_id = 4 }, tracked.method);
    try std.testing.expect(tracked.flags.no_promise_pipelining);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqualStrings("state call text", try (try (try call.params()).content()).getText());
}

test "rpc registry call text helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "state-registry-call-text");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageTextFromRegistryWithOptionsAndApplyState(
        &state,
        std.testing.allocator,
        root,
        101,
        .{ .imported_cap = 5 },
        "state registry call text",
        &registry,
        .{ .method = .{ .interface_id = 0x101, .method_id = 11 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(101));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(101));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    const tracked = state.callInfo(101).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x101, .method_id = 11 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualStrings("state registry call text", try (try params.content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call data helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageDataWithOptionsAndApplyState(
        &state,
        root,
        96,
        .{ .imported_cap = 5 },
        "state call data",
        &.{.{ .sender_hosted = 98 }},
        .{
            .method = .{ .interface_id = 0x96, .method_id = 6 },
            .flags = .{ .only_promise_pipeline = true },
        },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(96));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(96));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(98));
    const tracked = state.callInfo(96).?;
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, tracked.target);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x96, .method_id = 6 }, tracked.method);
    try std.testing.expect(tracked.flags.only_promise_pipeline);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try std.testing.expectEqualSlices(u8, "state call data", try (try (try call.params()).content()).getData());
}

test "rpc registry call data helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "state-registry-call-data");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageDataFromRegistryWithOptionsAndApplyState(
        &state,
        std.testing.allocator,
        root,
        102,
        .{ .imported_cap = 5 },
        "state registry call data",
        &registry,
        .{ .method = .{ .interface_id = 0x102, .method_id = 12 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(102));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(102));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    const tracked = state.callInfo(102).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x102, .method_id = 12 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try std.testing.expectEqualSlices(u8, "state registry call data", try (try params.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call uint32-list-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 100 }, .attached_fd = 19 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageUInt32ListInfoWithOptionsAndApplyState(
        &state,
        root,
        100,
        .{ .imported_cap = 5 },
        &.{ 5, 10, 15 },
        infos[0..],
        .{ .method = .{ .interface_id = 0x100, .method_id = 10 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(100));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(100));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(100));
    const tracked = state.callInfo(100).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x100, .method_id = 10 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try support.expectPayloadUInt32List(params, &.{ 5, 10, 15 });
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc registry call uint32-list helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "state-registry-call-list");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageUInt32ListFromRegistryWithOptionsAndApplyState(
        &state,
        std.testing.allocator,
        root,
        103,
        .{ .imported_cap = 5 },
        &.{ 11, 22, 33 },
        &registry,
        .{ .method = .{ .interface_id = 0x103, .method_id = 13 } },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(103));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(103));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));
    const tracked = state.callInfo(103).?;
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x103, .method_id = 13 }, tracked.method);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const params = try (try generated.Message.fromReader(try reader.getRoot()).call()).params();
    try support.expectPayloadUInt32List(params, &.{ 11, 22, 33 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, params);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc call uint32-list helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireCallMessageUInt32ListWithOptionsAndApplyState(
        &state,
        root,
        97,
        .{ .imported_cap = 5 },
        &.{ 7, 14, 28 },
        &.{.{ .sender_hosted = 99 }},
        .{
            .method = .{ .interface_id = 0x97, .method_id = 7 },
            .send_results_to = .third_party,
            .send_results_to_third_party = .{ .max_capability_count = 4, .capability = 3 },
            .flags = .{ .allow_third_party_tail_call = true },
        },
    );

    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(97));
    try std.testing.expectEqual(@as(usize, 1), state.paramImportCount(97));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(99));
    const tracked = state.callInfo(97).?;
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, tracked.target);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x97, .method_id = 7 }, tracked.method);
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x97, .method_id = 7 }, tracked.callMethod());
    try std.testing.expect(tracked.hasMethod());
    try std.testing.expect(tracked.flags.allow_third_party_tail_call);
    try std.testing.expect(tracked.sendsResultsTo(.third_party));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, tracked.thirdPartyResultsUsage().?);
    try std.testing.expect(tracked.hasThirdPartyResultsUsage());
    try std.testing.expect(tracked.allowsThirdPartyTailCall());
    try std.testing.expect(!tracked.forbidsPromisePipelining());
    try std.testing.expect(!tracked.onlyAllowsPromisePipeline());
    try std.testing.expectEqual(@as(?bool, false), state.callSendsResultsTo(97, .caller));
    try std.testing.expectEqual(@as(?bool, true), state.callSendsResultsTo(97, .third_party));
    try std.testing.expectEqual(@as(?bool, true), state.callHasMethod(97));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, state.callThirdPartyResultsUsage(97).?);
    try std.testing.expectEqual(@as(?bool, true), state.callHasThirdPartyResultsUsage(97));
    try std.testing.expectEqual(@as(?bool, true), state.callAllowsThirdPartyTailCall(97));
    try std.testing.expectEqual(@as(?bool, false), state.callForbidsPromisePipelining(97));
    try std.testing.expectEqual(@as(?bool, false), state.callOnlyAllowsPromisePipeline(97));
    const tracked_options = tracked.callOptions();
    try std.testing.expectEqual(cpz.rpc.CallMethod{ .interface_id = 0x97, .method_id = 7 }, tracked_options.method);
    try std.testing.expect(tracked_options.matchesMethod(.{ .interface_id = 0x97, .method_id = 7 }));
    try std.testing.expect(!tracked_options.matchesMethod(.{ .interface_id = 0x97, .method_id = 8 }));
    try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, tracked_options.send_results_to);
    try std.testing.expect(tracked_options.sendsResultsTo(.third_party));
    try std.testing.expect(!tracked_options.sendsResultsTo(.caller));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, tracked_options.send_results_to_third_party.?);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, tracked_options.thirdPartyResultsUsage().?);
    try std.testing.expect(tracked_options.hasThirdPartyResultsUsage());
    try std.testing.expect(tracked_options.flags.allow_third_party_tail_call);
    try std.testing.expect(tracked_options.allowsThirdPartyTailCall());
    try std.testing.expect(!tracked_options.forbidsPromisePipelining());
    try std.testing.expect(!tracked_options.onlyAllowsPromisePipeline());
    try std.testing.expectEqual(tracked_options, state.callOptions(97).?);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const call = try generated.Message.fromReader(try reader.getRoot()).call();
    try support.expectPayloadUInt32List(try call.params(), &.{ 7, 14, 28 });
}

test "rpc wire calls apply target and params state together" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    const call = try root.init_call();
    try call.set_questionId(50);
    try cpz.rpc.writeCallMethodToWire(.{ .interface_id = 0x50, .method_id = 5 }, call);
    try cpz.rpc.writeSendResultsToThirdPartyToWire(call, .{ .max_capability_count = 4, .capability = 3 });
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
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, state.trackedCallTarget(50).?);
    try std.testing.expectEqual(@as(?bool, false), state.trackedCallTargetResolved(50));
    try std.testing.expect(state.trackedCallTargetResolution(50) == null);
    try std.testing.expect(state.trackedCallTargetForwardTarget(50) == null);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, state.trackedCallEffectiveTarget(50).?);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, (try state.trackedCallTransitiveEffectiveTarget(50)).?);
    const expected_method: cpz.rpc.CallMethod = .{ .interface_id = 0x50, .method_id = 5 };
    const dispatch_info = (try state.trackedCallDispatchInfo(50)).?;
    try std.testing.expectEqual(tracked, dispatch_info.info);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, dispatch_info.effective_target);
    try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 5 }, dispatch_info.transitive_effective_target);
    try std.testing.expect(dispatch_info.resolution == null);
    try std.testing.expect(dispatch_info.forward_target == null);
    try std.testing.expect(dispatch_info.transitive_forward_target == null);
    try std.testing.expect(!dispatch_info.needsForward());
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, dispatch_info.dispatchOutcome());
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, try state.wireCallDispatchOutcome(try message.call()));
    const Noop = struct {
        fn handle(_: void, _: anytype) !cpz.rpc.DispatchResult {
            return .empty;
        }
    };
    const entries = .{expected_method.methodEntry(Noop.handle)};
    try std.testing.expectEqual(@as(?usize, 0), try dispatch_info.methodEntryIndex(entries));
    const service_action = try dispatch_info.serviceAction(entries);
    try std.testing.expect(service_action.isDispatch());
    try std.testing.expectEqual(@as(usize, 0), service_action.dispatch);
    const missing_action = try dispatch_info.serviceAction(.{(cpz.rpc.CallMethod{ .interface_id = 0x50, .method_id = 6 }).methodEntry(Noop.handle)});
    try std.testing.expect(missing_action.isUnimplemented());
    try std.testing.expect(state.trackedCallTarget(51) == null);
    try std.testing.expect(state.trackedCallTargetResolved(51) == null);
    try std.testing.expect((try state.trackedCallTargetTransitiveForwardTarget(51)) == null);
    try std.testing.expectEqual(expected_method, tracked.method);
    try std.testing.expect(tracked.matchesMethod(expected_method));
    try std.testing.expect(tracked.matchesWireCall(try message.call()));
    try std.testing.expect(try tracked.matchesWireMessage(message));
    try std.testing.expectEqual(@as(?bool, true), state.callMatchesCallMethod(50, expected_method));
    try std.testing.expectEqual(@as(?bool, true), state.callMatchesMethod(50, 0x50, 5));
    try std.testing.expectEqual(@as(?bool, true), state.callMatchesWireCall(50, try message.call()));
    try std.testing.expectEqual(@as(?bool, true), try state.callMatchesWireMessage(50, message));
    const MismatchedWireCall = struct {
        pub fn interfaceId(_: @This()) u64 {
            return 0x50;
        }

        pub fn methodId(_: @This()) u16 {
            return 6;
        }
    };
    try std.testing.expectEqual(@as(?bool, false), state.callMatchesWireCall(50, MismatchedWireCall{}));
    try std.testing.expectEqual(@as(?bool, false), state.callMatchesCallMethod(50, .{ .interface_id = 0x50, .method_id = 6 }));
    try std.testing.expectEqual(@as(?bool, false), state.callMatchesMethod(50, 0x50, 6));
    try std.testing.expectEqual(@as(?bool, null), state.callMatchesCallMethod(51, expected_method));
    try std.testing.expectEqual(@as(?bool, null), state.callMatchesWireCall(51, try message.call()));
    try std.testing.expectEqual(@as(?bool, null), try state.callMatchesWireMessage(51, message));
    try std.testing.expect(tracked.flags.no_promise_pipelining);
    try std.testing.expect(tracked.sendsResultsTo(.third_party));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, tracked.thirdPartyResultsUsage().?);
    try std.testing.expect(tracked.hasThirdPartyResultsUsage());
    try std.testing.expect(tracked.forbidsPromisePipelining());
    try std.testing.expect(!tracked.allowsThirdPartyTailCall());
    try std.testing.expect(!tracked.onlyAllowsPromisePipeline());
    try std.testing.expectEqual(@as(?bool, false), state.callSendsResultsTo(50, .caller));
    try std.testing.expectEqual(@as(?bool, true), state.callSendsResultsTo(50, .third_party));
    try std.testing.expectEqual(@as(?bool, true), state.callHasMethod(50));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, state.callThirdPartyResultsUsage(50).?);
    try std.testing.expectEqual(@as(?bool, true), state.callHasThirdPartyResultsUsage(50));
    try std.testing.expectEqual(@as(?bool, true), state.callForbidsPromisePipelining(50));
    try std.testing.expectEqual(@as(?bool, false), state.callAllowsThirdPartyTailCall(50));
    try std.testing.expectEqual(@as(?bool, false), state.callOnlyAllowsPromisePipeline(50));
    try std.testing.expectEqual(@as(?bool, null), state.callSendsResultsTo(51, .caller));
    try std.testing.expect(state.callThirdPartyResultsUsage(51) == null);
    try std.testing.expectEqual(@as(?bool, null), state.callHasThirdPartyResultsUsage(51));
    try std.testing.expectEqual(@as(?bool, null), state.callForbidsPromisePipelining(51));
    const tracked_options = tracked.callOptions();
    try std.testing.expectEqual(expected_method, tracked_options.method);
    try std.testing.expect(tracked_options.matchesMethod(expected_method));
    try std.testing.expectEqual(cpz.rpc.CallSendResultsTo.third_party, tracked_options.send_results_to);
    try std.testing.expect(tracked_options.sendsResultsTo(.third_party));
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, tracked_options.send_results_to_third_party.?);
    try std.testing.expectEqual(cpz.rpc.AnyPointerUsage{ .max_capability_count = 4, .capability = 3 }, tracked_options.thirdPartyResultsUsage().?);
    try std.testing.expect(tracked_options.flags.no_promise_pipelining);
    try std.testing.expect(tracked_options.forbidsPromisePipelining());
    try std.testing.expect(!tracked_options.allowsThirdPartyTailCall());
    try std.testing.expect(!tracked_options.onlyAllowsPromisePipeline());
    try std.testing.expectEqual(tracked_options, state.callOptions(50).?);
    try std.testing.expect(state.callOptions(51) == null);
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
    try std.testing.expectEqual(cpz.rpc.ExceptionType.disconnected, decoded_exception.exceptionType().?);
    try std.testing.expect(decoded_exception.isDisconnected());
    try std.testing.expectEqualStrings("promise trace", decoded_exception.trace.?);

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addExport(96);
    try state.applyWireMessage(std.testing.allocator, message);
    try std.testing.expectEqual(@as(?bool, true), state.exportResolved(96));
    try std.testing.expect(state.exportResolution(96) == null);
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
    try std.testing.expect(!info.hasCap());
    try std.testing.expect(info.hasException());
    try std.testing.expect(info.isBroken());
    try std.testing.expect(!info.isForwardableToCallTarget());
    try std.testing.expect(info.forwardableCallTarget() == null);
    try info.validate();
    const exception = info.exception orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualStrings("resolve failed", exception.reason.?);
    try std.testing.expectEqual(@as(u16, 3), exception.type_raw);
    try std.testing.expectEqual(cpz.rpc.ExceptionType.unimplemented, exception.exceptionType().?);
    try std.testing.expect(exception.isUnimplemented());
    try std.testing.expect(!exception.isOverloaded());
    try std.testing.expectEqualStrings("resolve trace", exception.trace.?);
    try std.testing.expect(exception.hasReason());
    try std.testing.expect(exception.hasTrace());
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
    try std.testing.expectEqual(cpz.rpc.ExceptionType.overloaded, exception.exceptionType().?);
    try std.testing.expect(exception.isOverloaded());
    try std.testing.expect(!exception.isUnimplemented());
    try std.testing.expect(!exception.hasReason());
    try std.testing.expect(!exception.hasTrace());

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
        try state.applyWireEvent(try support.decode(&builder));
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(31));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_finish();
        try payload.set_questionId(31);
        try state.applyWireEvent(try support.decode(&builder));
        try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .finished), state.questionState(31));
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_return_();
        try payload.set_answerId(31);
        try state.applyWireEvent(try support.decode(&builder));
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
        try state.applyWireEvent(try support.decode(&builder));
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

    const event = try support.decode(&builder);
    try std.testing.expectEqual(cpz.rpc.WireEvent{ .release = .{ .id = 41, .reference_count = 2 } }, event);
    try std.testing.expect(event.toStateEvent() == null);
    try state.applyWireEvent(event);
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(41));
    try std.testing.expectEqual(@as(?u32, 1), state.importReferenceCount(41));
}
