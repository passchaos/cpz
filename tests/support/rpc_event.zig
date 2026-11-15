const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_rpc_event_schema");

pub fn decode(builder: *cpz.MessageBuilder) !cpz.rpc.WireEvent {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const message = generated.Message.fromReader(try reader.getRoot());
    return cpz.rpc.eventFromWireMessage(message);
}

pub fn expectPayloadUInt32List(payload: anytype, expected: []const u32) !void {
    const list = try (try payload.content()).getList(.four_bytes);
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| {
        try std.testing.expectEqual(value, list.getUInt32(index));
    }
    try std.testing.expect((try cpz.rpc.payloadContentCapabilityIndex(payload)) == null);
    try cpz.rpc.validateWirePayload(std.testing.allocator, payload);
}

pub fn expectReturnCapabilityResult(message: anytype, expected_export_id: cpz.rpc.ExportId) !void {
    const return_ = try message.return_();
    const results = try return_.results();
    try std.testing.expectEqual(@as(u32, 0), try (try results.content()).getCapabilityIndex());
    const descriptors = try cpz.rpc.capTableFromWireReturnResults(std.testing.allocator, return_);
    defer std.testing.allocator.free(descriptors);
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqual(cpz.rpc.CapDescriptor{ .sender_hosted = expected_export_id }, descriptors[0]);
}

pub fn expectQueuedReturnAnswer(message: anytype, expected_answer_id: cpz.rpc.AnswerId) !void {
    try std.testing.expectEqual(generated.Message.Union0.return_, (try message.which()).?);
    try std.testing.expectEqual(expected_answer_id, try (try message.get_return_()).get_answerId());
}

pub fn expectQueuedForwardedCall(message: anytype, expected_question_id: cpz.rpc.QuestionId, expected_target: cpz.rpc.CallTarget) !void {
    try std.testing.expectEqual(generated.Message.Union0.call, message.which().?);
    const call = try message.call();
    try std.testing.expectEqual(expected_question_id, call.questionId());
    try std.testing.expectEqual(expected_target, try cpz.rpc.callTargetFromWireCall(call));
}

pub fn expectQueuedForwardedCallBuilder(message: anytype, expected_question_id: cpz.rpc.QuestionId, expected_target: cpz.rpc.CallTarget) !void {
    try std.testing.expectEqual(generated.Message.Union0.call, (try message.which()).?);
    const call = try message.get_call();
    try std.testing.expectEqual(expected_question_id, try call.get_questionId());
    const target = try call.get_target();
    try std.testing.expectEqual(generated.MessageTarget.Union0.importedCap, (try target.which()).?);
    try std.testing.expectEqual(expected_target, cpz.rpc.CallTarget{ .imported_cap = try target.get_importedCap() });
}

pub fn expectQueuedDisembargo(message: anytype, expected_target: cpz.rpc.CallTarget, expected_accept: []const u8) !void {
    try std.testing.expectEqual(generated.Message.Union0.disembargo, message.which().?);
    const info = try cpz.rpc.disembargoInfoFromWireDisembargo(try message.disembargo());
    try std.testing.expectEqual(expected_target, info.target);
    try std.testing.expectEqualStrings(expected_accept, info.context.accept);
}

pub fn expectQueuedDisembargoBuilder(message: anytype, expected_target: cpz.rpc.CallTarget, expected_accept: []const u8) !void {
    try std.testing.expectEqual(generated.Message.Union0.disembargo, (try message.which()).?);
    const disembargo = try message.get_disembargo();
    const target = try disembargo.get_target();
    try std.testing.expectEqual(generated.MessageTarget.Union0.importedCap, (try target.which()).?);
    try std.testing.expectEqual(expected_target, cpz.rpc.CallTarget{ .imported_cap = try target.get_importedCap() });
    try std.testing.expectEqualStrings(expected_accept, (try disembargo.get_acceptOrNull()) orelse "");
}

pub fn expectQueuedForwardedCallText(message: anytype, expected_question_id: cpz.rpc.QuestionId, expected_target: cpz.rpc.CallTarget, expected_text: []const u8) !void {
    try expectQueuedForwardedCall(message, expected_question_id, expected_target);
    try std.testing.expectEqualStrings(expected_text, try (try (try (try message.call()).params()).content()).getText());
}

pub fn decodeCapDescriptor(builder: *cpz.MessageBuilder) !cpz.rpc.CapDescriptor {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const descriptor = generated.CapDescriptor.fromReader(try reader.getRoot());
    return cpz.rpc.capDescriptorFromWire(descriptor);
}

pub fn decodeCapDescriptorInfo(builder: *cpz.MessageBuilder) !cpz.rpc.CapDescriptorInfo {
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const descriptor = generated.CapDescriptor.fromReader(try reader.getRoot());
    return cpz.rpc.capDescriptorInfoFromWire(descriptor);
}
