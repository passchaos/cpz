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
    try std.testing.expectEqual(generated.error_.ok, value.enum_());
}

test "generated code sanitizes keyword defaults" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    _ = try generated.fn_.initRootTyped(&builder);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const value = generated.fn_.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 5), value.error_());
    try std.testing.expectEqual(generated.error_.test_, value.enum_());
}
