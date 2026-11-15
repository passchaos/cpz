const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_no_orphans_schema");

test "minimal no-orphans generated accessors round-trip" {
    try std.testing.expect(!@hasDecl(generated.Root, "Orphan"));
    try std.testing.expect(!@hasDecl(generated.Item, "Orphan"));
    try std.testing.expect(!@hasDecl(generated.Root.Builder, "newOrphan"));

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    _ = try builder.initRoot(generated.Root.size);
    const root = try generated.Root.getRootTyped(&builder);

    const item = try root.init_item();
    try item.set_id(7);
    try item.set_name("seven");

    const items = try root.init_items(2);
    const item0 = try items.get(0);
    try item0.set_id(1);
    try item0.set_name("one");
    const item1 = try items.get(1);
    try item1.set_id(2);

    const scores = try root.init_scores(3);
    try scores.set(0, 10);
    try scores.set(1, 20);
    try scores.set(2, 30);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try generated.Root.getRoot(&reader);
    const read_item = try read_root.item();
    try std.testing.expectEqual(@as(u32, 7), read_item.id());
    try std.testing.expectEqualStrings("seven", try read_item.name());

    const read_items = try read_root.items();
    try std.testing.expectEqual(@as(usize, 2), read_items.len());
    const read_item0 = try read_items.get(0);
    try std.testing.expectEqual(@as(u32, 1), read_item0.id());
    try std.testing.expectEqualStrings("one", try read_item0.name());

    const read_scores = try read_root.scores();
    try std.testing.expectEqual(@as(usize, 3), read_scores.len());
    try std.testing.expectEqual(@as(u32, 10), read_scores.get(0));
    try std.testing.expectEqual(@as(u32, 30), read_scores.get(2));
}
