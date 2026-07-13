const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_keyword_schema");

test "generated code sanitizes Zig keywords and still round-trips" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const value_builder = try generated.fn_.initRootTyped(&builder);
    try value_builder.set_error_(9);
    try value_builder.set_enum_(.ok);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.fn_.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 9), value.error_());
    try std.testing.expectEqual(generated.error_.ok, try value.enum_());
}

test "generated code sanitizes keyword defaults" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    _ = try generated.fn_.initRootTyped(&builder);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.fn_.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 5), value.error_());
    try std.testing.expectEqual(generated.error_.test_, try value.enum_());
}

test "generated enum getters reject unknown ordinals" {
    try std.testing.expectEqual(generated.error_.ok, generated.@"cpz.enum.error_.fromRaw"(1).?);
    try std.testing.expectEqual(@as(?generated.error_, null), generated.@"cpz.enum.error_.fromRaw"(99));
    try std.testing.expectEqual(@as(u16, 0), generated.@"cpz.enum.error_.toRaw"(.test_));
    try std.testing.expectEqualStrings("test", generated.@"cpz.enum.error_.name"(.test_));
    try std.testing.expectEqualStrings("ok", generated.@"cpz.enum.error_.nameFromRaw"(1).?);
    try std.testing.expectEqual(generated.error_.test_, generated.@"cpz.enum.error_.valueByName"("test").?);
    try std.testing.expectEqual(@as(?generated.error_, null), generated.@"cpz.enum.error_.valueByName"("test_"));

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const raw = try builder.initRoot(generated.fn_.size);
    try raw.setUInt16(4, 99, 0);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.fn_.fromReader(try reader.getRoot());
    try std.testing.expectError(error.InvalidEnumValue, value.enum_());
    try std.testing.expectEqual(@as(u16, 99), value.enum__raw());
}

test "generated keyword enum raw setter preserves unknown ordinals" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const value_builder = try generated.fn_.initRootTyped(&builder);
    try value_builder.set_enum__raw(77);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.fn_.fromReader(try reader.getRoot());
    try std.testing.expectError(error.InvalidEnumValue, value.enum_());
    try std.testing.expectEqual(@as(u16, 77), value.enum__raw());
}

test "generated code sanitizes primitive and literal names" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const value_builder = try generated.type_.initRootTyped(&builder);
    try value_builder.set_null_(42);
    try value_builder.set_true_("literal");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.type_.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 42), value.null_());
    try std.testing.expectEqualSlices(u8, "literal", try value.true_());
}

test "generated helper parameter names do not shadow fields" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const value_builder = try generated.HelperClash.initRootTyped(&builder);
    try value_builder.set_message("no shadow");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.HelperClash.fromReader(try reader.getRoot());
    try std.testing.expectEqualSlices(u8, "no shadow", try value.message());
}
