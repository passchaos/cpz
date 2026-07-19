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
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .return_ = 13 }, event);
        try std.testing.expectEqual(cpz.rpc.Event{ .return_ = 13 }, event.toStateEvent().?);
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_finish();
        try payload.set_questionId(14);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .finish = 14 }, event);
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

test "rpc wire-only events stay separate from simplified state events" {
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_provide();
        try payload.set_questionId(22);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .provide = 22 }, event);
        try std.testing.expect(event.toStateEvent() == null);
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
    }
    {
        var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
        defer builder.deinit();
        const root = try generated.Message.initRootTyped(&builder);
        const payload = try root.init_thirdPartyAnswer();
        try payload.set_answerId(24);
        const event = try decode(&builder);
        try std.testing.expectEqual(cpz.rpc.WireEvent{ .third_party_answer = 24 }, event);
        try std.testing.expect(event.toStateEvent() == null);
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
    }
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
