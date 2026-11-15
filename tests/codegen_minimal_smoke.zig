const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_minimal_schema");

test "minimal generated accessors round-trip without introspection helpers" {
    try std.testing.expect(@hasDecl(generated.Lean, "value"));
    try std.testing.expect(@hasDecl(generated.Lean, "text"));
    try std.testing.expect(!@hasDecl(generated.Lean, "textPointerKind"));
    try std.testing.expect(!@hasDecl(generated.Lean.Builder, "get_textPointerKind"));
    try std.testing.expect(!@hasDecl(generated.Lean.Builder, "get_textListLen"));
    try std.testing.expect(!@hasDecl(generated.Lean, "actualSize"));
    try std.testing.expect(!@hasDecl(generated.Lean, "dataSection"));
    try std.testing.expect(!@hasDecl(generated.Lean.Builder, "actualSize"));
    try std.testing.expect(@hasDecl(generated.Lean, "validate"));
    try std.testing.expect(@hasDecl(generated.Lean, "totalSize"));

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    _ = try builder.initRoot(generated.Lean.size);
    const root = try generated.Lean.getRootTyped(&builder);
    try root.set_value(4321);
    try root.set_text("minimal");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try generated.Lean.getRoot(&reader);
    try std.testing.expectEqual(@as(u32, 4321), read_root.value());
    try std.testing.expectEqualStrings("minimal", try read_root.text());
}
