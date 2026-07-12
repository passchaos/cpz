const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_schema");

test "generated reader and builder accessors compile and round-trip" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_id(7);
    try std.testing.expectEqual(@as(u32, 7), try person_builder.get_id());
    try person_builder.set_active(false);
    try std.testing.expectEqual(false, try person_builder.get_active());
    try std.testing.expectEqual(false, try person_builder.has_name());
    try std.testing.expectEqualSlices(u8, "anon", try person_builder.get_nickname());
    try person_builder.set_name("Ada");
    try std.testing.expectEqual(true, try person_builder.has_name());
    try std.testing.expectEqualSlices(u8, "Ada", try person_builder.get_name());
    try person_builder.set_favorite(.blue);
    try std.testing.expectEqual(generated.Color.blue, try person_builder.get_favorite());
    try std.testing.expectEqual(@as(u16, 2), try person_builder.get_favorite_raw());
    const scores = try person_builder.init_scores(2);
    try scores.set(0, 10);
    try scores.set(1, 20);
    try std.testing.expectEqual(@as(u32, 20), try scores.get(1));
    const children = try person_builder.init_children(1);
    const child = try children.get(0);
    try child.set_id(99);
    try child.set_name("Grace");
    const friend = try person_builder.init_friend();
    try friend.set_id(1234);
    try friend.set_name("Lin");
    const same_friend = try person_builder.get_friend();
    try std.testing.expectEqual(@as(u32, 1234), try same_friend.get_id());
    const palette = try person_builder.init_palette(2);
    try palette.set(0, .red);
    try palette.set(1, .green);
    try std.testing.expectEqual(generated.Color.green, try palette.get(1));
    try std.testing.expectEqual(@as(u16, 1), try palette.getRaw(1));
    const aliases = try person_builder.init_aliases(2);
    try aliases.set(0, "A");
    try aliases.set(1, "Lovelace");
    try std.testing.expectEqualSlices(u8, "Lovelace", try aliases.get(1));
    const payloads = try person_builder.init_payloads(1);
    try payloads.set(0, &[_]u8{ 4, 5, 6 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6 }, try payloads.get(0));
    const flags = try person_builder.init_flags(3);
    try flags.set(0, true);
    try flags.set(1, false);
    try flags.set(2, true);
    try std.testing.expectEqual(true, try flags.get(2));
    const ratios = try person_builder.init_ratios(2);
    try ratios.set(0, 1.5);
    try ratios.set(1, -2.25);
    try std.testing.expectEqual(@as(f32, -2.25), try ratios.get(1));
    const weights = try person_builder.init_weights(2);
    try weights.set(0, 10.125);
    try weights.set(1, -20.5);
    try std.testing.expectEqual(@as(f64, 10.125), try weights.get(0));
    try person_builder.set_maybeName("Optional Ada");
    const maybe_friend = try person_builder.init_maybeFriend();
    try maybe_friend.set_id(64);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try reader.getRoot();
    const person = generated.Person.fromReader(root);
    try std.testing.expectEqual(@as(u32, 7), person.id());
    try std.testing.expectEqual(false, person.active());
    try std.testing.expect(person.has_name());
    try std.testing.expectEqualSlices(u8, "Ada", try person.name());
    try std.testing.expect(generated.Color.blue == try person.favorite());
    try std.testing.expectEqual(@as(u16, 2), person.favorite_raw());
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
    try std.testing.expectEqual(generated.Color.red, try read_palette.get(0));
    try std.testing.expectEqual(@as(u16, 0), read_palette.getRaw(0));
    try std.testing.expectEqual(generated.Color.green, try read_palette.get(1));
    try std.testing.expectEqual(@as(u16, 1), read_palette.getRaw(1));
    const read_aliases = try person.aliases();
    try std.testing.expectEqualSlices(u8, "A", try read_aliases.get(0));
    try std.testing.expectEqualSlices(u8, "Lovelace", try read_aliases.get(1));
    const read_payloads = try person.payloads();
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6 }, try read_payloads.get(0));
    const read_flags = try person.flags();
    try std.testing.expectEqual(true, read_flags.get(0));
    try std.testing.expectEqual(false, read_flags.get(1));
    try std.testing.expectEqual(true, read_flags.get(2));
    const read_ratios = try person.ratios();
    try std.testing.expectEqual(@as(f32, 1.5), read_ratios.get(0));
    try std.testing.expectEqual(@as(f32, -2.25), read_ratios.get(1));
    const read_weights = try person.weights();
    try std.testing.expectEqual(@as(f64, 10.125), read_weights.get(0));
    try std.testing.expectEqual(@as(f64, -20.5), read_weights.get(1));
    try std.testing.expect(person.has_maybeName());
    try std.testing.expectEqualSlices(u8, "Optional Ada", try person.maybeName());
    const read_maybe_friend = try person.maybeFriend();
    try std.testing.expectEqual(@as(u32, 64), read_maybe_friend.id());
}

test "generated accessors honor scalar defaults" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    _ = try generated.Person.initRootTyped(&builder);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 42), person.id());
    try std.testing.expectEqual(true, person.active());
    try std.testing.expectEqual(generated.Color.green, try person.favorite());
    try std.testing.expectEqual(@as(u16, 1), person.favorite_raw());
    try std.testing.expect(!person.has_nickname());
    try std.testing.expectEqualSlices(u8, "anon", try person.nickname());
}

test "generated builders can clear pointer fields" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_name("Temporary");
    _ = try person_builder.init_friend();
    try std.testing.expectEqual(true, try person_builder.has_name());
    try person_builder.clear_name();
    try std.testing.expectEqual(false, try person_builder.has_name());
    try std.testing.expectEqual(true, try person_builder.has_friend());
    try person_builder.clear_friend();
    try std.testing.expectEqual(false, try person_builder.has_friend());

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

test "generated enum raw setters preserve unknown ordinals" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_favorite_raw(77);
    const palette = try person_builder.init_palette(1);
    try palette.setRaw(0, 88);
    try std.testing.expectEqual(@as(u16, 88), try palette.getRaw(0));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    try std.testing.expectError(error.InvalidEnumValue, person.favorite());
    try std.testing.expectEqual(@as(u16, 77), person.favorite_raw());
    const read_palette = try person.palette();
    try std.testing.expectError(error.InvalidEnumValue, read_palette.get(0));
    try std.testing.expectEqual(@as(u16, 88), read_palette.getRaw(0));
}

test "generated anonymous union accessors activate and guard fields" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const choice_builder = try generated.Choice.initRootTyped(&builder);
    try choice_builder.set_before("pre");
    try choice_builder.set_after("post");
    try choice_builder.set_name("Ada");
    try std.testing.expectEqual(generated.Choice.Union0.name, (try choice_builder.which()).?);
    try std.testing.expectEqual(true, try choice_builder.has_name());
    try std.testing.expectEqualSlices(u8, "Ada", try choice_builder.get_name());
    try std.testing.expectError(error.InactiveUnionField, choice_builder.get_id());

    try choice_builder.set_id(99);
    try std.testing.expectEqual(generated.Choice.Union0.id, (try choice_builder.which()).?);
    try std.testing.expectEqual(false, try choice_builder.has_name());
    try std.testing.expectError(error.InactiveUnionField, choice_builder.get_name());
    try std.testing.expectEqual(@as(u32, 99), try choice_builder.get_id());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const choice = generated.Choice.fromReader(try reader.getRoot());
    try std.testing.expectEqual(generated.Choice.Union0.id, choice.which().?);
    try std.testing.expectEqualSlices(u8, "pre", try choice.before());
    try std.testing.expectEqualSlices(u8, "post", try choice.after());
    try std.testing.expectError(error.InactiveUnionField, choice.name());
    try std.testing.expectEqual(@as(u32, 99), try choice.id());
}

test "generated builtin any and capability accessors round-trip" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_root = try source_builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try source_root.setUInt32(0, 0xdecafbad, 0);
    try source_root.setText(0, "dynamic");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_struct = try source_reader.getRoot();

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const box_builder = try generated.DynamicBox.initRootTyped(&builder);
    try box_builder.set_any(source_struct.getPointerField(0));
    try box_builder.set_anyStruct_from(source_struct);
    const any_list = try box_builder.init_anyList(.two_bytes, 2);
    try any_list.setUInt16(0, 111);
    try any_list.setUInt16(1, 222);
    try box_builder.set_cap(77);
    const caps = try box_builder.init_capList(2);
    try caps.set(0, 88);
    try caps.set(1, 99);
    try std.testing.expectEqual(@as(u32, 77), try box_builder.get_cap());
    try std.testing.expectEqual(@as(u32, 99), try caps.get(1));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const dynamic_box = generated.DynamicBox.fromReader(try reader.getRoot());
    try std.testing.expect(dynamic_box.has_any());
    try std.testing.expectEqualSlices(u8, "dynamic", try (try dynamic_box.any()).getText());
    const any_struct = try dynamic_box.anyStruct();
    try std.testing.expectEqual(@as(u32, 0xdecafbad), any_struct.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "dynamic", try any_struct.getPointerField(0).getText());
    const read_list = try dynamic_box.anyList();
    try std.testing.expectEqual(@as(u16, 222), read_list.getUInt16(1));
    try std.testing.expectEqual(@as(u32, 77), try dynamic_box.cap());
    const read_caps = try dynamic_box.capList();
    try std.testing.expectEqual(@as(u32, 88), try read_caps.get(0));
    try std.testing.expectEqual(@as(u32, 99), try read_caps.get(1));
}

test "generated using aliases resolve for layout and accessors" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_root = try source_builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    try source_root.setText(0, "aliased pointer");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_struct = try source_reader.getRoot();

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const box_builder = try generated.AliasBox.initRootTyped(&builder);
    try box_builder.set_id(123);
    try box_builder.set_shade(.green);
    const names = try box_builder.init_names(2);
    try names.set(0, "Ada");
    try names.set(1, "Grace");
    try box_builder.set_dynamic(source_struct.getPointerField(0));
    const caps = try box_builder.init_caps(2);
    try caps.set(0, 700);
    try caps.set(1, 701);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const box = generated.AliasBox.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 123), box.id());
    try std.testing.expectEqual(generated.Color.green, try box.shade());
    const read_names = try box.names();
    try std.testing.expectEqualSlices(u8, "Grace", try read_names.get(1));
    try std.testing.expectEqualSlices(u8, "aliased pointer", try (try box.dynamic()).getText());
    const read_caps = try box.caps();
    try std.testing.expectEqual(@as(u32, 700), try read_caps.get(0));
    try std.testing.expectEqual(@as(u32, 701), try read_caps.get(1));
}
