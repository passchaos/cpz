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
    const friend = try person_builder.init_friend();
    try friend.set_id(1234);
    try friend.set_name("Lin");
    const palette = try person_builder.init_palette(2);
    try palette.set(0, .red);
    try palette.set(1, .green);
    const aliases = try person_builder.init_aliases(2);
    try aliases.set(0, "A");
    try aliases.set(1, "Lovelace");
    const payloads = try person_builder.init_payloads(1);
    try payloads.set(0, &[_]u8{ 4, 5, 6 });
    const flags = try person_builder.init_flags(3);
    try flags.set(0, true);
    try flags.set(1, false);
    try flags.set(2, true);

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
    const read_friend = try person.friend();
    try std.testing.expectEqual(@as(u32, 1234), read_friend.id());
    try std.testing.expectEqualSlices(u8, "Lin", try read_friend.name());
    const read_palette = try person.palette();
    try std.testing.expectEqual(generated.Color.red, read_palette.get(0));
    try std.testing.expectEqual(generated.Color.green, read_palette.get(1));
    const read_aliases = try person.aliases();
    try std.testing.expectEqualSlices(u8, "A", try read_aliases.get(0));
    try std.testing.expectEqualSlices(u8, "Lovelace", try read_aliases.get(1));
    const read_payloads = try person.payloads();
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6 }, try read_payloads.get(0));
    const read_flags = try person.flags();
    try std.testing.expectEqual(true, read_flags.get(0));
    try std.testing.expectEqual(false, read_flags.get(1));
    try std.testing.expectEqual(true, read_flags.get(2));
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
    try std.testing.expectEqualSlices(u8, "anon", try person.nickname());
}

test "generated builders can clear pointer fields" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_name("Temporary");
    _ = try person_builder.init_friend();
    try person_builder.clear_name();
    try person_builder.clear_friend();

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    try std.testing.expectError(error.NullPointer, person.name());
    try std.testing.expectError(error.NullPointer, person.friend());
}

test "generated builders can copy nested struct fields from readers" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    try source_person_builder.set_id(888);
    try source_person_builder.set_name("Copied");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_person = generated.Person.fromReader(try source_reader.getRoot());

    var target_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer target_builder.deinit();
    const target_person_builder = try generated.Person.initRootTyped(&target_builder);
    try target_person_builder.set_friend_from(source_person);

    var target_reader = cpz.MessageReader.init(try target_builder.segmentsConst(), .{});
    const target_person = generated.Person.fromReader(try target_reader.getRoot());
    const friend = try target_person.friend();
    try std.testing.expectEqual(@as(u32, 888), friend.id());
    try std.testing.expectEqualSlices(u8, "Copied", try friend.name());
}

test "generated struct list builders can copy elements from readers" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    try source_person_builder.set_id(321);
    try source_person_builder.set_name("ListCopy");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_person = generated.Person.fromReader(try source_reader.getRoot());

    var target_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer target_builder.deinit();
    const target_person_builder = try generated.Person.initRootTyped(&target_builder);
    const children = try target_person_builder.init_children(1);
    try children.set(0, source_person);

    var target_reader = cpz.MessageReader.init(try target_builder.segmentsConst(), .{});
    const target_person = generated.Person.fromReader(try target_reader.getRoot());
    const read_children = try target_person.children();
    const child = try read_children.get(0);
    try std.testing.expectEqual(@as(u32, 321), child.id());
    try std.testing.expectEqualSlices(u8, "ListCopy", try child.name());
}

test "generated list builders can clear pointer-backed and struct elements" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    const aliases = try person_builder.init_aliases(1);
    try aliases.set(0, "drop");
    try aliases.clear(0);
    const payloads = try person_builder.init_payloads(1);
    try payloads.set(0, &[_]u8{7});
    try payloads.clear(0);
    const children = try person_builder.init_children(1);
    const child = try children.get(0);
    try child.set_id(111);
    try child.set_name("drop child");
    try children.clear(0);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const read_aliases = try person.aliases();
    try std.testing.expectError(error.NullPointer, read_aliases.get(0));
    const read_payloads = try person.payloads();
    try std.testing.expectError(error.NullPointer, read_payloads.get(0));
    const read_children = try person.children();
    const read_child = try read_children.get(0);
    try std.testing.expectEqual(@as(u32, 42), read_child.id());
    try std.testing.expectError(error.NullPointer, read_child.name());
}
