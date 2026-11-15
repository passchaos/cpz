const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_lean_schema");

test "lean generated accessors round-trip" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    _ = try builder.initRoot(generated.Lean.size);
    const root = try generated.Lean.getRootTyped(&builder);
    try root.set_value(1234);
    try root.set_text("lean");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try generated.Lean.getRoot(&reader);
    try std.testing.expectEqual(@as(u32, 1234), read_root.value());
    try std.testing.expectEqualStrings("lean", try read_root.text());
}
