const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");
const support = @import("test_support");

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
        try support.expectPayloadUInt32List(results, &.{ 5, 10, 15 });
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
        try support.expectPayloadUInt32List(results, &.{ 20, 40 });
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
    try support.expectPayloadUInt32List(results, &.{ 80, 160 });
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

test "rpc return capability helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(79, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessagePayloadCapabilityAndApplyState(
        &state,
        root,
        79,
        false,
        false,
        0,
        &.{.{ .sender_hosted = 82 }},
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(79));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(79));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(82));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 82 }, descriptors[0]);

    var finish_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer finish_builder.deinit();
    const finish_root = try generated.Message.initRootTyped(&finish_builder);
    try cpz.rpc.initWireFinishMessage(finish_root, .{ .question_id = 79, .release_result_caps = true });
    var finish_reader = cpz.MessageReader.init(try finish_builder.segmentsConst(), .{});
    try state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try finish_reader.getRoot()));
    try std.testing.expectEqual(@as(usize, 0), state.resultImportCount(79));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(82));
}

test "rpc return capability-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(86, .call);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 87 }, .attached_fd = 11 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessagePayloadCapabilityInfoAndApplyState(
        &state,
        root,
        86,
        false,
        false,
        0,
        infos[0..],
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(86));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(86));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(87));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc return registry capability helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "registry-return-state");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(87, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessagePayloadCapabilityFromRegistryAndApplyState(
        &state,
        std.testing.allocator,
        root,
        87,
        false,
        false,
        0,
        &registry,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(87));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(87));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(?u32, 0), try cpz.rpc.payloadContentCapabilityIndex(results));
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc return struct helper can apply initialized state" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
            (try builder.getPointerField(0)).setCapability(0);
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(95, .call);

    var value: u32 = 0x1234;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageStructWithAndApplyState(
        &state,
        root,
        95,
        false,
        false,
        cpz.StructSize{ .data_words = 1, .pointer_count = 1 },
        &.{.{ .sender_hosted = 96 }},
        &value,
        Fill.write,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(95));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(95));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(96));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x1234), content.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 0), try content.getPointerField(0).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 96 }, descriptors[0]);
}

test "rpc return struct-info helper can apply initialized state" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
            (try builder.getPointerField(0)).setCapability(0);
        }
    };

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(96, .call);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 97 }, .attached_fd = 15 }};
    var value: u32 = 0x5678;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageStructInfoWithAndApplyState(
        &state,
        root,
        96,
        false,
        false,
        cpz.StructSize{ .data_words = 1, .pointer_count = 1 },
        infos[0..],
        &value,
        Fill.write,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(96));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(96));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(97));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x5678), content.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 0), try content.getPointerField(0).getCapabilityIndex());
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc return registry struct helper can apply initialized state" {
    const Fill = struct {
        fn write(value: *const u32, builder: cpz.StructBuilder) !void {
            try builder.setUInt32(0, value.*, 0);
            (try builder.getPointerField(0)).setCapability(0);
        }
    };

    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "registry-struct-return-state");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(98, .call);

    var value: u32 = 0x9abc;
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageStructFromRegistryAndApplyState(
        &state,
        std.testing.allocator,
        root,
        98,
        false,
        false,
        cpz.StructSize{ .data_words = 1, .pointer_count = 1 },
        &registry,
        &value,
        Fill.write,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(98));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(98));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    const content = try (try results.content()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0x9abc), content.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 0), try content.getPointerField(0).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc return text helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(80, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageTextAndApplyState(
        &state,
        root,
        80,
        false,
        false,
        "state text result",
        &.{.{ .sender_hosted = 83 }},
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(80));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(80));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(83));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualStrings("state text result", try (try results.content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 83 }, descriptors[0]);
}

test "rpc return text-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(88, .call);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 89 }, .attached_fd = 12 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageTextInfoAndApplyState(
        &state,
        root,
        88,
        false,
        false,
        "state text info result",
        infos[0..],
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(88));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(88));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(89));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualStrings("state text info result", try (try results.content()).getText());
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc return registry text helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "registry-text-return-state");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(92, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageTextFromRegistryAndApplyState(
        &state,
        std.testing.allocator,
        root,
        92,
        false,
        false,
        "registry state text",
        &registry,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(92));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(92));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualStrings("registry state text", try (try results.content()).getText());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc return data helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(81, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageDataAndApplyState(
        &state,
        root,
        81,
        false,
        false,
        "state data result",
        &.{.{ .sender_hosted = 84 }},
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(81));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(81));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(84));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualSlices(u8, "state data result", try (try results.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 84 }, descriptors[0]);
}

test "rpc return data-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(89, .call);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 90 }, .attached_fd = 13 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageDataInfoAndApplyState(
        &state,
        root,
        89,
        false,
        false,
        "state data info result",
        infos[0..],
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(89));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(89));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(90));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualSlices(u8, "state data info result", try (try results.content()).getData());
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc return registry data helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "registry-data-return-state");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(93, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageDataFromRegistryAndApplyState(
        &state,
        std.testing.allocator,
        root,
        93,
        false,
        false,
        "registry state data",
        &registry,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(93));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(93));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try std.testing.expectEqualSlices(u8, "registry state data", try (try results.content()).getData());
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
}

test "rpc return uint32-list helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(82, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageUInt32ListAndApplyState(
        &state,
        root,
        82,
        false,
        false,
        &.{ 3, 6, 9 },
        &.{.{ .sender_hosted = 85 }},
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(82));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(82));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(85));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try support.expectPayloadUInt32List(results, &.{ 3, 6, 9 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 85 }, descriptors[0]);
}

test "rpc return uint32-list-info helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(90, .call);

    const infos = [_]cpz.rpc.CapDescriptorInfo{.{ .descriptor = .{ .sender_promise = 91 }, .attached_fd = 14 }};
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageUInt32ListInfoAndApplyState(
        &state,
        root,
        90,
        false,
        false,
        &.{ 4, 8, 12 },
        infos[0..],
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(90));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(90));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(91));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try support.expectPayloadUInt32List(results, &.{ 4, 8, 12 });
    const decoded_infos = try cpz.rpc.capTableInfoFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(decoded_infos);
    try std.testing.expectEqual(@as(usize, 1), decoded_infos.len);
    try std.testing.expectEqual(infos[0], decoded_infos[0]);
}

test "rpc return registry uint32-list helper can apply initialized state" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);
    _ = try registry.register(std.testing.allocator, "registry-list-return-state");

    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(94, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnMessageUInt32ListFromRegistryAndApplyState(
        &state,
        std.testing.allocator,
        root,
        94,
        false,
        false,
        &.{ 6, 12, 18 },
        &registry,
    );

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(94));
    try std.testing.expectEqual(@as(usize, 1), state.resultImportCount(94));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(0));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
    const results = try return_.results();
    try support.expectPayloadUInt32List(results, &.{ 6, 12, 18 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = 0 }, descriptors[0]);
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
        try support.expectPayloadUInt32List(results, &.{ 7, 14, 21 });
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
        try support.expectPayloadUInt32List(results, &.{ 28, 56 });
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
    try support.expectPayloadUInt32List(results, &.{ 112, 224 });
    const descriptors = try cpz.rpc.capTableFromWirePayload(std.testing.allocator, results);
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
        try exception.set_trace("stack line 1\nstack line 2");

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const message = generated.Message.fromReader(try reader.getRoot());
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        try std.testing.expect(outcome.isException());
        try std.testing.expect(outcome.isNonResult());
        try std.testing.expect(!outcome.isResults());
        const info = switch (outcome) {
            .exception => |value| value,
            else => return error.TestUnexpectedResult,
        };
        try std.testing.expectEqual(info, outcome.exceptionInfo().?);
        try std.testing.expectEqualStrings("network down", info.reason.?);
        try std.testing.expectEqual(@as(u16, 2), info.type_raw);
        try std.testing.expectEqual(cpz.rpc.ExceptionType.disconnected, info.exceptionType().?);
        try std.testing.expect(info.matchesType(.disconnected));
        try std.testing.expect(info.isDisconnected());
        try std.testing.expect(!info.isFailed());
        try std.testing.expectEqualStrings("stack line 1\nstack line 2", info.trace.?);
        try std.testing.expect(info.hasReason());
        try std.testing.expect(info.hasTrace());

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
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.canceled, outcome);
        try std.testing.expect(outcome.isCanceled());
        try std.testing.expect(outcome.isNonResult());

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
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results_sent_elsewhere, outcome);
        try std.testing.expect(outcome.isResultsSentElsewhere());
        try std.testing.expect(outcome.takeFromOtherQuestionId() == null);
        try std.testing.expect(outcome.isNonResult());

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
        const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try message.return_());
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome{ .take_from_other_question = 83 }, outcome);
        try std.testing.expect(outcome.isTakeFromOtherQuestion());
        try std.testing.expectEqual(@as(?u32, 83), outcome.takeFromOtherQuestionId());
        try std.testing.expect(!outcome.isAwaitFromThirdParty());

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
        try std.testing.expect(outcome.isAwaitFromThirdParty());
        try std.testing.expectEqual(usage, outcome.awaitFromThirdPartyUsage().?);
        try std.testing.expect(outcome.awaitsThirdPartyCapability(4));
        try std.testing.expect(!outcome.awaitsThirdPartyCapability(3));

        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(84, .call);
        try state.applyWireMessage(std.testing.allocator, message);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(84));
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

test "rpc return exception helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(58);
    const target = try call.init_target();
    try target.set_importedCap(5);
    try cpz.rpc.initWireCallParamsText(call, "exception state return", &.{.{ .sender_hosted = 101 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    try state.applyWireCall(std.testing.allocator, try generated.Message.fromReader(try call_reader.getRoot()).call());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    try cpz.rpc.initWireReturnExceptionMessageAndApplyState(&state, return_root, 58, true, false, .{
        .reason = "state exception",
        .type_raw = 3,
    });

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(58));
    try std.testing.expectEqual(@as(?cpz.rpc.QuestionState, .open), state.questionState(58));
    try std.testing.expectEqual(@as(usize, 0), state.paramImportCount(58));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(101));

    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try generated.Message.fromReader(try return_reader.getRoot()).return_());
    const info = switch (outcome) {
        .exception => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqualStrings("state exception", info.reason.?);
    try std.testing.expectEqual(@as(u16, 3), info.type_raw);
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

test "rpc non-result return helpers can apply initialized state" {
    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.addImport(5);

        var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
        defer call_builder.deinit();
        const call_root = try generated.Message.initRootTyped(&call_builder);
        const call = try call_root.init_call();
        try call.set_questionId(201);
        const target = try call.init_target();
        try target.set_importedCap(5);
        try cpz.rpc.initWireCallParamsData(call, "cancel params", &.{.{ .sender_hosted = 102 }});
        var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
        try state.applyWireCall(std.testing.allocator, try generated.Message.fromReader(try call_reader.getRoot()).call());

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnCanceledMessageAndApplyState(&state, root, 201, true);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(201));
        try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(102));

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.canceled, try cpz.rpc.returnOutcomeFromWireReturn(try generated.Message.fromReader(try reader.getRoot()).return_()));
    }
    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(202, .call);

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnResultsSentElsewhereMessageAndApplyState(&state, root, 202, false);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(202));

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results_sent_elsewhere, try cpz.rpc.returnOutcomeFromWireReturn(try generated.Message.fromReader(try reader.getRoot()).return_()));
    }
    {
        var state = cpz.rpc.State.init(std.testing.allocator);
        defer state.deinit();
        try state.openQuestion(203, .call);
        try state.openQuestion(204, .call);

        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireReturnTakeFromOtherQuestionMessageAndApplyState(&state, root, 203, false, 204);
        try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(203));

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try std.testing.expectEqual(
            cpz.rpc.ReturnOutcome{ .take_from_other_question = 204 },
            try cpz.rpc.returnOutcomeFromWireReturn(try generated.Message.fromReader(try reader.getRoot()).return_()),
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

test "rpc await-from-third-party return helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.openQuestion(205, .call);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const root = try generated.Message.initRootTyped(&builder);
    try cpz.rpc.initWireReturnAwaitFromThirdPartyMessageAndApplyState(&state, root, 205, false, true, 7);
    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(205));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const outcome = try cpz.rpc.returnOutcomeFromWireReturn(try generated.Message.fromReader(try reader.getRoot()).return_());
    const usage = switch (outcome) {
        .await_from_third_party => |value| value,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(@as(?u32, 7), usage.capability);
    try std.testing.expectEqual(@as(usize, 8), usage.max_capability_count);
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

test "rpc empty return helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(55);
    const target = try call.init_target();
    try target.set_importedCap(5);
    try cpz.rpc.initWireCallParamsText(call, "empty state return", &.{.{ .sender_hosted = 100 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    try state.applyWireCall(std.testing.allocator, try generated.Message.fromReader(try call_reader.getRoot()).call());
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(100));

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    try cpz.rpc.initEmptyReturnMessageAndApplyState(&state, return_root, 55, true, true);

    try std.testing.expect(state.questionComplete(55));
    try std.testing.expectEqual(@as(usize, 0), state.paramImportCount(55));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(100));

    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    const return_ = try generated.Message.fromReader(try return_reader.getRoot()).return_();
    try std.testing.expect(return_.releaseParamCaps());
    try std.testing.expect(return_.noFinishNeeded());
    _ = try return_.results();
}

test "rpc dispatch return helper can apply initialized state" {
    var state = cpz.rpc.State.init(std.testing.allocator);
    defer state.deinit();
    try state.addImport(5);

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(56);
    const target = try call.init_target();
    try target.set_importedCap(5);
    try cpz.rpc.initWireCallParamsText(call, "dispatch state return", &.{.{ .sender_hosted = 103 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    try state.applyWireCall(std.testing.allocator, try generated.Message.fromReader(try call_reader.getRoot()).call());

    var return_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer return_builder.deinit();
    const return_root = try generated.Message.initRootTyped(&return_builder);
    try cpz.rpc.initDispatchReturnMessageAndApplyState(&state, return_root, 56, .{ .capability = 104 });

    try std.testing.expectEqual(@as(?cpz.rpc.AnswerState, .resolved), state.answerState(56));
    try std.testing.expectEqual(@as(usize, 0), state.paramImportCount(56));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .released), state.importState(103));
    try std.testing.expectEqual(@as(?cpz.rpc.CapabilityLifetime, .live), state.importState(104));

    var return_reader = cpz.MessageReader.init(try return_builder.segmentsConst(), .{});
    try support.expectReturnCapabilityResult(generated.Message.fromReader(try return_reader.getRoot()), 104);
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
        try support.expectPayloadUInt32List(results, &.{ 7, 8, 9 });
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
        try support.expectPayloadUInt32List(results, &.{ 10, 20, 30 });
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
        try support.expectPayloadUInt32List(results, &.{ 1, 3, 5 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 56, 60 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 57, 70 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 58, 80 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 59, 90 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 60, 100 });
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
        try support.expectPayloadUInt32List(try forwarded.params(), &.{ 61, 110 });
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
    const outcome = try cpz.rpc.returnOutcomeFromWireReturn(return_);
    try std.testing.expectEqual(cpz.rpc.ReturnOutcome.results, outcome);
    try std.testing.expect(outcome.isResults());
    try std.testing.expect(!outcome.isNonResult());
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
        try support.expectReturnCapabilityResult(response, 185);
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
        try support.expectPayloadUInt32List(results, &.{ 6, 2 });
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
        try support.expectPayloadUInt32List(results, &.{ 6, 3 });
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
        try support.expectPayloadUInt32List(results, &.{ 6, 4 });
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
    try std.testing.expect(stats.hasWork());
    try std.testing.expect(!stats.isEmpty());
    try std.testing.expect(stats.matchesStats(cpz.rpc.WireDispatchStats{ .response_initialized = 2, .forward_required = 1, .state_applied = 1 }));
    try stats.validateAgainstStats(cpz.rpc.WireDispatchStats{ .response_initialized = 2, .forward_required = 1, .state_applied = 1 });
    try std.testing.expectError(error.InvalidTransition, stats.validateAgainstStats(cpz.rpc.WireDispatchStats{ .response_initialized = 2 }));
    try std.testing.expect(!((cpz.rpc.WireDispatchStats{}).hasWork()));
    try std.testing.expect((cpz.rpc.WireDispatchStats{}).isEmpty());
    try std.testing.expectEqual(@as(usize, 2), stats.denseResponseSlots());
    try std.testing.expectEqual(@as(usize, 1), stats.denseForwardSlots());
    try std.testing.expectEqual(@as(usize, 3), stats.denseOutputSlots());
    try std.testing.expectEqual(
        cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 },
        cpz.rpc.RpcOutputStats.fromDispatchStats(stats),
    );
    try std.testing.expect((cpz.rpc.RpcOutputStats{}).isEmpty());
    try std.testing.expect(!(cpz.rpc.RpcOutputStats{}).hasOutputs());
    try std.testing.expect(!(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }).isEmpty());
    try std.testing.expect((cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }).hasOutputs());
    try std.testing.expect((cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }).matchesDispatchStats(stats));
    try std.testing.expect(!(cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1 }).matchesDispatchStats(stats));
    try (cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }).validateAgainstDispatchStats(stats);
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.RpcOutputStats{ .responses = 1, .forwards = 1 }).validateAgainstDispatchStats(stats));
    try std.testing.expectEqual(
        cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2 },
        cpz.rpc.RpcTurnResponseSourceStats.fromDispatchStats(stats),
    );
    try std.testing.expect((cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2 }).matchesDispatchStats(stats));
    try (cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 2 }).validateAgainstDispatchStats(stats);
    try std.testing.expectError(error.InvalidTransition, (cpz.rpc.RpcTurnResponseSourceStats{ .dispatch = 1 }).validateAgainstDispatchStats(stats));
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 3 }, stats.denseOutputRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, stats.denseResponseRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, stats.denseForwardRange());
    try std.testing.expectEqual(@as(usize, 3), stats.denseOutputRange().len());
    try std.testing.expectEqual(@as(usize, 2), stats.denseResponseRange().len());
    try std.testing.expectEqual(@as(usize, 1), stats.denseForwardRange().len());
    try std.testing.expectEqual(@as(?usize, 2), stats.denseOutputLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), stats.denseOutputLocalIndex(3));
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutputPosition{ .role = .response, .local_index = 2 }, stats.nextDenseOutputPosition(.response));
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutputPosition{ .role = .forward, .local_index = 1 }, stats.nextDenseOutputPosition(.forward));
    const dense_response_position = stats.unifiedDenseOutputPosition(1).?;
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutputPosition{ .role = .response, .local_index = 1 }, dense_response_position);
    try std.testing.expectEqual(@as(?usize, 1), stats.denseOutputIndex(dense_response_position));
    try std.testing.expectEqual(@as(?usize, 1), stats.denseResponseOutputIndex(1));
    try std.testing.expectEqual(@as(?usize, null), stats.denseResponseOutputIndex(2));
    try std.testing.expect(dense_response_position.isResponse());
    try std.testing.expect(!dense_response_position.isForward());
    const dense_forward_position = cpz.rpc.wireDispatchUnifiedDenseOutputPosition(stats, 2).?;
    try std.testing.expectEqual(cpz.rpc.WireDispatchOutputPosition{ .role = .forward, .local_index = 0 }, dense_forward_position);
    try std.testing.expectEqual(@as(?usize, 2), stats.denseOutputIndex(dense_forward_position));
    try std.testing.expectEqual(@as(?usize, 2), stats.denseForwardOutputIndex(0));
    try std.testing.expectEqual(@as(?usize, null), stats.denseForwardOutputIndex(1));
    try std.testing.expectEqual(@as(?usize, 0), stats.denseForwardLocalIndex(2));
    try std.testing.expectEqual(@as(?usize, null), stats.denseResponseLocalIndex(2));
    try std.testing.expect(dense_forward_position.isForward());
    try std.testing.expect(!dense_forward_position.isResponse());
    try std.testing.expect(stats.unifiedDenseOutputPosition(3) == null);
    var dense_dispatch_stats: cpz.rpc.WireDispatchStats = .{};
    dense_dispatch_stats.recordDenseOutputPosition(dense_response_position);
    try dense_dispatch_stats.recordDenseOutputIndex(stats, 0);
    dense_dispatch_stats.recordDenseOutputPosition(dense_forward_position);
    try std.testing.expectEqual(cpz.rpc.WireDispatchStats{ .response_initialized = 2, .forward_required = 1 }, dense_dispatch_stats);
    try std.testing.expectError(error.InvalidTransition, dense_dispatch_stats.recordDenseOutputIndex(stats, 3));
    var dense_indexed_stats: cpz.rpc.RpcOutputStats = .{};
    dense_indexed_stats.recordWireDispatchPosition(dense_response_position);
    try dense_indexed_stats.recordWireDispatchOutputIndex(stats, 0);
    try dense_indexed_stats.recordWireDispatchOutputIndex(stats, 2);
    try std.testing.expectEqual(cpz.rpc.RpcOutputStats{ .responses = 2, .forwards = 1 }, dense_indexed_stats);
    try std.testing.expectError(error.InvalidTransition, dense_indexed_stats.recordWireDispatchOutputIndex(stats, 3));
    try std.testing.expect(!stats.denseResponseRange().isEmpty());
    try std.testing.expect(stats.denseResponseRange().contains(1));
    try std.testing.expect(!stats.denseResponseRange().contains(2));
    try stats.denseForwardRange().validateCapacity(3);
    try std.testing.expectError(error.InvalidTransition, stats.denseForwardRange().validateCapacity(2));
    try stats.validateDenseResponseCapacity(2);
    try stats.validateDenseForwardCapacity(1);
    try stats.validateDenseOutputCapacity(2, 1);
    try stats.validateDenseResponseBuilders(requests[0..2]);
    try stats.validateDenseForwardBuilders(requests[0..1]);
    try stats.validateDenseOutputBuilders(requests[0..2], requests[0..1]);
    try stats.validateUnifiedDenseOutputCapacity(3);
    try stats.validateUnifiedDenseOutputBuilders(requests[0..3]);
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseResponseCapacity(1));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseForwardCapacity(0));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseResponseBuilders(requests[0..1]));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseForwardBuilders(requests[0..0]));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseOutputCapacity(2, 0));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseOutputBuilders(requests[0..1], requests[0..1]));
    try std.testing.expectError(error.InvalidTransition, stats.validateDenseOutputBuilders(requests[0..2], requests[0..0]));
    try std.testing.expectError(error.InvalidTransition, stats.validateUnifiedDenseOutputCapacity(2));
    try std.testing.expectError(error.InvalidTransition, stats.validateUnifiedDenseOutputBuilders(requests[0..2]));
    try std.testing.expect(stats.initializedAnyResponse());
    try std.testing.expect(stats.requiredAnyForward());
    try std.testing.expect(stats.appliedAnyState());
    try std.testing.expect(cpz.rpc.WireDispatchOutcome.response_initialized.isResponseInitialized());
    try std.testing.expect(cpz.rpc.WireDispatchOutcome.forward_required.isForwardRequired());
    try std.testing.expect(cpz.rpc.WireDispatchOutcome.state_applied.isStateApplied());

    const method_stats = try cpz.rpc.planWireMessagesMethodsDispatch(&state, requests[0..], entries);
    try std.testing.expectEqual(stats, method_stats);

    const turn_plan = try cpz.rpc.planRpcTurn(&state, requests[0..]);
    try std.testing.expectEqual(stats, turn_plan.dispatch);
    try std.testing.expectEqual(cpz.rpc.StateHandoffReturnStats{}, turn_plan.handoff_returns);
    try std.testing.expectEqual(@as(usize, 2), turn_plan.dispatchResponseMessages());
    try std.testing.expect(turn_plan.hasDispatchResponses());
    try std.testing.expectEqual(@as(usize, 0), turn_plan.handoffReturnMessages());
    try std.testing.expect(!turn_plan.hasHandoffReturns());
    try std.testing.expectEqual(@as(usize, 2), turn_plan.responseMessages());
    try std.testing.expectEqual(@as(usize, 1), turn_plan.forwardedMessages());
    try std.testing.expectEqual(@as(usize, 1), turn_plan.stateOnlyMessages());
    try std.testing.expectEqual(@as(usize, 3), turn_plan.totalOutputMessages());
    try std.testing.expectEqual(@as(usize, 0), turn_plan.disembargoMessages());
    try std.testing.expect(turn_plan.hasResponses());
    try std.testing.expect(turn_plan.hasForwards());
    try std.testing.expect(turn_plan.hasStateOnly());
    try std.testing.expect(turn_plan.hasOutputs());
    try std.testing.expect(!turn_plan.hasDisembargos());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, turn_plan.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, turn_plan.forwardedMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 3, .end = 3 }, turn_plan.disembargoMessageRange());
    try std.testing.expect(turn_plan.disembargoMessageRange().isEmpty());
    try turn_plan.validateOutputCapacity(2, 1);
    try turn_plan.validateResponseCapacity(2);
    try turn_plan.validateForwardCapacity(1);
    try turn_plan.validateResponseBuilders(requests[0..2]);
    try turn_plan.validateForwardBuilders(requests[0..1]);
    try turn_plan.validateUnifiedOutputCapacity(3);
    try turn_plan.validateUnifiedOutputBuilders(requests[0..3]);
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateResponseCapacity(1));
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateForwardCapacity(0));
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateResponseBuilders(requests[0..1]));
    try std.testing.expectError(error.InvalidTransition, turn_plan.validateForwardBuilders(requests[0..0]));
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
        try embargo_plan.validateDisembargoBuilders(disembargo_builders[0..]);
        try std.testing.expectError(error.InvalidTransition, embargo_plan.validateDisembargoBuilders(disembargo_builders[0..0]));
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

test "rpc generic dispatch return helper builds non-capability payloads" {
    try std.testing.expect((@as(cpz.rpc.DispatchResult, .empty)).isEmpty());
    const capability_result = cpz.rpc.DispatchResult{ .capability = 10 };
    try std.testing.expect(capability_result.isCapability());
    try std.testing.expectEqual(@as(?u32, 10), capability_result.capabilityId());
    const exception_result = cpz.rpc.DispatchResult{ .exception = .{ .reason = "x", .type_raw = 1 } };
    try std.testing.expect(exception_result.isException());
    try std.testing.expectEqualStrings("x", exception_result.exceptionInfo().?.reason.?);
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const dispatch_result = cpz.rpc.DispatchResult{ .text = "text result" };
        try std.testing.expectEqualStrings("text result", dispatch_result.textBytes().?);
        try std.testing.expect(!dispatch_result.isNonResult());
        try std.testing.expect(dispatch_result.isResult());
        try cpz.rpc.initDispatchReturnMessage(root, 36, dispatch_result);

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
        const dispatch_result = cpz.rpc.DispatchResult{ .data = "data result" };
        try std.testing.expectEqualSlices(u8, "data result", dispatch_result.dataBytes().?);
        try cpz.rpc.initDispatchReturnMessage(root, 37, dispatch_result);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const return_ = try generated.Message.fromReader(try reader.getRoot()).return_();
        try std.testing.expect(return_.releaseParamCaps());
        try std.testing.expectEqualSlices(u8, "data result", try (try (try return_.results()).content()).getData());
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const dispatch_result = cpz.rpc.DispatchResult{ .uint32_list = &.{ 4, 5, 6 } };
        try std.testing.expectEqualSlices(u32, &.{ 4, 5, 6 }, dispatch_result.uint32Values().?);
        try cpz.rpc.initDispatchReturnMessage(root, 38, dispatch_result);

        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        const results = try (try generated.Message.fromReader(try reader.getRoot()).return_()).results();
        try support.expectPayloadUInt32List(results, &.{ 4, 5, 6 });
    }
}

test "rpc generic dispatch return helper builds non-result outcomes" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const dispatch_result = @as(cpz.rpc.DispatchResult, .canceled);
        try std.testing.expect(dispatch_result.isCanceled());
        try std.testing.expect(dispatch_result.isNonResult());
        try std.testing.expect(!dispatch_result.isResult());
        try cpz.rpc.initDispatchReturnMessage(root, 22, dispatch_result);

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
        const dispatch_result = @as(cpz.rpc.DispatchResult, .results_sent_elsewhere);
        try std.testing.expect(dispatch_result.isResultsSentElsewhere());
        try std.testing.expect(dispatch_result.takeFromOtherQuestionId() == null);
        try cpz.rpc.initDispatchReturnMessage(root, 23, dispatch_result);

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
        const dispatch_result = cpz.rpc.DispatchResult{ .take_from_other_question = 25 };
        try std.testing.expect(dispatch_result.isNonResult());
        try std.testing.expect(dispatch_result.isTakeFromOtherQuestion());
        try std.testing.expectEqual(@as(?u32, 25), dispatch_result.takeFromOtherQuestionId());
        try std.testing.expect(!dispatch_result.isAwaitFromThirdParty());
        try cpz.rpc.initDispatchReturnMessage(root, 24, dispatch_result);

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
        const dispatch_result = cpz.rpc.DispatchResult{ .await_from_third_party = 4 };
        try std.testing.expect(dispatch_result.isAwaitFromThirdParty());
        try std.testing.expectEqual(@as(?u32, 4), dispatch_result.awaitFromThirdPartyCapability());
        try std.testing.expect(dispatch_result.awaitsThirdPartyCapability(4));
        try std.testing.expect(!dispatch_result.awaitsThirdPartyCapability(3));
        try cpz.rpc.initDispatchReturnMessage(root, 26, dispatch_result);

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
        var request_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer request_builder.deinit();
        const request_root = try generated.Message.initRootTyped(&request_builder);
        try cpz.rpc.initWireBootstrapMessage(request_root, 23);

        var request_reader = cpz.MessageReader.init(try request_builder.segmentsConst(), .{});
        const request = generated.Message.fromReader(try request_reader.getRoot());
        var response_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer response_builder.deinit();
        const response_root = try generated.Message.initRootTyped(&response_builder);

        var bootstrap_seen: u32 = 0;
        var call_seen: u32 = 0;
        var queue = std.ArrayList(generated.Message.Builder).empty;
        defer queue.deinit(std.testing.allocator);
        const outcome = try cpz.rpc.dispatchWireMessageToQueueOutcome(
            &state,
            std.testing.allocator,
            response_root,
            request,
            &bootstrap_seen,
            BootstrapHandler.handle,
            &call_seen,
            CallHandler.handle,
            &queue,
        );
        stats.record(outcome);
        try std.testing.expectEqual(cpz.rpc.WireDispatchOutcome.response_initialized, outcome);
        try std.testing.expectEqual(@as(usize, 1), queue.items.len);
        try support.expectQueuedReturnAnswer(queue.items[0], 23);
        try std.testing.expectEqual(@as(u32, 0), bootstrap_seen);
        try std.testing.expectEqual(@as(u32, 0), call_seen);
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
    try std.testing.expectEqual(@as(usize, 3), stats.response_initialized);
    try std.testing.expectEqual(@as(usize, 0), stats.forward_required);
    try std.testing.expectEqual(@as(usize, 1), stats.state_applied);
    try std.testing.expectEqual(@as(usize, 4), stats.total());
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
        try support.expectReturnCapabilityResult(response, 620);
    }
    {
        var reader = cpz.MessageReader.init(try response_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 121), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1021);
    }
    {
        var reader = cpz.MessageReader.init(try forward_builder.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 661 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("no-sink turn forward", try (try (try forwarded.params()).content()).getText());
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 660 });
    try queue_state.resolveImportTo(660, .{ .sender_hosted = 661 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 661 });
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
    const queue_responses = [_]generated.Message.Builder{ queue_response0, queue_response1 };
    const queue_forwards = [_]generated.Message.Builder{queue_forward};
    var response_queue = std.ArrayList(generated.Message.Builder).empty;
    defer response_queue.deinit(std.testing.allocator);
    var forward_queue = std.ArrayList(generated.Message.Builder).empty;
    defer forward_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingDenseToQueuesFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_responses[0..],
        queue_forwards[0..],
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
        &response_queue,
        &forward_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 120), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 2), response_queue.items.len);
    try std.testing.expectEqual(@as(usize, 1), forward_queue.items.len);
    try support.expectQueuedReturnAnswer(response_queue.items[0], 120);
    try support.expectQueuedReturnAnswer(response_queue.items[1], 121);
    try support.expectQueuedForwardedCallBuilder(forward_queue.items[0], 660, .{ .imported_cap = 661 });
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}

test "rpc turn dispatcher fills unified dense outputs without sinks" {
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
    try state.applyCapDescriptor(.{ .sender_promise = 670 });
    try state.resolveImportTo(670, .{ .sender_hosted = 671 });
    try state.applyCapDescriptor(.{ .sender_hosted = 671 });

    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 123,
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
    try cpz.rpc.initWireBootstrapMessage(bootstrap_root, 122);
    var bootstrap_reader = cpz.MessageReader.init(try bootstrap_builder.segmentsConst(), .{});
    const bootstrap_message = generated.Message.fromReader(try bootstrap_reader.getRoot());

    var call_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer call_builder.deinit();
    const call_root = try generated.Message.initRootTyped(&call_builder);
    const call = try call_root.init_call();
    try call.set_questionId(670);
    const target = try call.init_target();
    try target.set_importedCap(670);
    try cpz.rpc.initWireCallParamsText(call, "unified turn forward", &.{.{ .sender_hosted = 672 }});
    var call_reader = cpz.MessageReader.init(try call_builder.segmentsConst(), .{});
    const call_message = generated.Message.fromReader(try call_reader.getRoot());

    const requests = [_]generated.Message{ bootstrap_message, call_message };
    const plan = try cpz.rpc.planRpcTurn(&state, requests[0..]);
    try std.testing.expectEqual(@as(usize, 3), plan.totalOutputMessages());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 0, .end = 2 }, plan.responseMessageRange());
    try std.testing.expectEqual(cpz.rpc.OutputRange{ .start = 2, .end = 3 }, plan.forwardedMessageRange());

    var output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder0.deinit();
    const output0 = try generated.Message.initRootTyped(&output_builder0);
    var output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer output_builder1.deinit();
    const output1 = try generated.Message.initRootTyped(&output_builder1);
    var output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer output_builder2.deinit();
    const output2 = try generated.Message.initRootTyped(&output_builder2);

    const outputs = [_]generated.Message.Builder{ output0, output1, output2 };
    var bootstrap_seen: u32 = 0;
    var call_seen: u32 = 0;
    var provide_context: HandoffHandler = .{};
    var accept_context: HandoffHandler = .{};
    var join_context: HandoffHandler = .{};
    const applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseFromHandlers(
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
    );
    try std.testing.expectEqual(plan, applied);
    try std.testing.expectEqual(@as(u32, 122), bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), call_seen);
    try std.testing.expectEqual(@as(usize, 1), provide_context.seen);
    try std.testing.expectEqual(@as(u32, 123), provide_context.question_sum);
    try std.testing.expectEqual(@as(usize, 0), accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), join_context.seen);

    {
        var reader = cpz.MessageReader.init(try output_builder0.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 122), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 622);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder1.segmentsConst(), .{});
        const response = generated.Message.fromReader(try reader.getRoot());
        try std.testing.expectEqual(@as(u32, 123), (try response.return_()).answerId());
        try support.expectReturnCapabilityResult(response, 1023);
    }
    {
        var reader = cpz.MessageReader.init(try output_builder2.segmentsConst(), .{});
        const forwarded = try generated.Message.fromReader(try reader.getRoot()).call();
        try std.testing.expectEqual(cpz.rpc.CallTarget{ .imported_cap = 671 }, try cpz.rpc.callTargetFromWireCall(forwarded));
        try std.testing.expectEqualStrings("unified turn forward", try (try (try forwarded.params()).content()).getText());
    }

    var queue_state = cpz.rpc.State.init(std.testing.allocator);
    defer queue_state.deinit();
    try queue_state.addImport(5);
    try queue_state.applyCapDescriptor(.{ .sender_promise = 670 });
    try queue_state.resolveImportTo(670, .{ .sender_hosted = 671 });
    try queue_state.applyCapDescriptor(.{ .sender_hosted = 671 });
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        try cpz.rpc.initWireProvideMessage(root, .{
            .question_id = 123,
            .target = .{ .imported_cap = 5 },
            .has_recipient = true,
            .recipient_max_capability_count = 1,
            .recipient_capability = 0,
        });
        var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
        try queue_state.applyWireMessage(std.testing.allocator, generated.Message.fromReader(try reader.getRoot()));
    }
    var queue_output_builder0 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder0.deinit();
    const queue_output0 = try generated.Message.initRootTyped(&queue_output_builder0);
    var queue_output_builder1 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer queue_output_builder1.deinit();
    const queue_output1 = try generated.Message.initRootTyped(&queue_output_builder1);
    var queue_output_builder2 = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer queue_output_builder2.deinit();
    const queue_output2 = try generated.Message.initRootTyped(&queue_output_builder2);
    const queue_outputs = [_]generated.Message.Builder{ queue_output0, queue_output1, queue_output2 };
    var output_queue = std.ArrayList(generated.Message.Builder).empty;
    defer output_queue.deinit(std.testing.allocator);
    var queue_bootstrap_seen: u32 = 0;
    var queue_call_seen: u32 = 0;
    var queue_provide_context: HandoffHandler = .{};
    var queue_accept_context: HandoffHandler = .{};
    var queue_join_context: HandoffHandler = .{};
    const queue_applied = try cpz.rpc.dispatchRpcTurnForwardingUnifiedDenseToQueueFromHandlers(
        &queue_state,
        std.testing.allocator,
        queue_outputs[0..],
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
        &output_queue,
    );
    try std.testing.expectEqual(applied, queue_applied);
    try std.testing.expectEqual(@as(u32, 122), queue_bootstrap_seen);
    try std.testing.expectEqual(@as(u32, 0), queue_call_seen);
    try std.testing.expectEqual(@as(usize, 3), output_queue.items.len);
    try support.expectQueuedReturnAnswer(output_queue.items[0], 122);
    try support.expectQueuedReturnAnswer(output_queue.items[1], 123);
    try support.expectQueuedForwardedCallBuilder(output_queue.items[2], 670, .{ .imported_cap = 671 });
    try std.testing.expectEqual(@as(usize, 1), queue_provide_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_accept_context.seen);
    try std.testing.expectEqual(@as(usize, 0), queue_join_context.seen);
}
