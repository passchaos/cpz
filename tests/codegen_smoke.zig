const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_schema");

test "generated reader and builder accessors compile and round-trip" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_id(7);
    try person_builder.set_active(false);
    try person_builder.set_name("Ada");
    try person_builder.set_favorite(.blue);
    const scores = try person_builder.init_scores(2);
    try scores.set(0, 10);
    try scores.set(1, 20);
    const children = try person_builder.init_children(1);
    const child = try children.get(0);
    try child.set_id(99);
    try child.set_name("Grace");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try reader.getRoot();
    const person = generated.Person.fromReader(root);
    try std.testing.expectEqual(@as(u32, 7), person.id());
    try std.testing.expectEqual(false, person.active());
    try std.testing.expectEqualSlices(u8, "Ada", try person.name());
    try std.testing.expectEqual(generated.Color.blue, person.favorite());
    const read_scores = try person.scores();
    try std.testing.expectEqual(@as(u32, 20), read_scores.get(1));
    const read_children = try person.children();
    const read_child = try read_children.get(0);
    try std.testing.expectEqual(@as(u32, 99), read_child.id());
    try std.testing.expectEqualSlices(u8, "Grace", try read_child.name());
}

test "generated accessors honor scalar defaults" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    _ = try generated.Person.initRootTyped(&builder);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 42), person.id());
    try std.testing.expectEqual(true, person.active());
    try std.testing.expectEqual(generated.Color.green, person.favorite());
}
