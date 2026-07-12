const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_schema");

test "generated schema exposes file id" {
    try std.testing.expectEqual(@as(u64, 0xc0ffee), generated.@"cpz.file_id");
}

test "generated simple constants compile" {
    try std.testing.expectEqual(@as(u32, 12345), generated.globalId);
    try std.testing.expectEqual(true, generated.globalActive);
    try std.testing.expectEqualSlices(u8, "const text", generated.globalName);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xde, 0xad, 0xbe, 0xef }, generated.globalPayload);
    try std.testing.expectEqual(generated.Color.blue, generated.globalShade);
    try std.testing.expectEqual(@as(f64, 125.0), generated.globalRatio);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 10, 20, 30 }, generated.globalScores);
    try std.testing.expectEqualSlices(u8, "beta", generated.globalNames[1]);
    try std.testing.expectEqualSlices(u8, "delta", generated.globalNamesAlias[1]);
    try std.testing.expectEqual(generated.Color.blue, generated.globalShades[1]);
    try std.testing.expectEqual(@as(u16, 99), generated.Person.defaultAge);
    try std.testing.expectEqualSlices(u8, "nested const", generated.Person.defaultAlias);
    try std.testing.expectEqual(generated.Color.red, generated.Person.defaultColor);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 7, 8, 9 }, generated.Person.defaultScores);
}

test "generated reader and builder accessors compile and round-trip" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_id(7);
    try std.testing.expectEqual(@as(u32, 7), try person_builder.get_id());
    try std.testing.expectEqual(generated.Person.size, person_builder.actualSize());
    try std.testing.expectEqual(@as(u8, 7 ^ 42), person_builder.dataSection()[0]);
    const root_builder = try generated.Person.getRootTyped(&builder);
    try std.testing.expectEqual(@as(u32, 7), try root_builder.get_id());
    var builder_reader = try builder.asReader(.{});
    const builder_view = person_builder.asReader(&builder_reader);
    try std.testing.expectEqual(@as(u32, 7), builder_view.id());
    const builder_view_size = try builder_view.totalSize();
    try std.testing.expect(builder_view_size.word_count > 0);
    const builder_size = try person_builder.totalSize();
    try std.testing.expect(builder_size.word_count > 0);
    try person_builder.set_active(false);
    try std.testing.expectEqual(false, try person_builder.get_active());
    try std.testing.expectEqual(false, try person_builder.has_name());
    try std.testing.expectEqualSlices(u8, "anon", try person_builder.get_nickname());
    try person_builder.set_name("Ada");
    try std.testing.expectEqual(true, try person_builder.has_name());
    try std.testing.expectEqualSlices(u8, "Ada", try person_builder.get_name());
    const builder_pointer_section = person_builder.pointerSection();
    try std.testing.expectEqual(@as(usize, generated.Person.size.pointer_count), builder_pointer_section.len());
    try std.testing.expectEqualSlices(u8, "Ada", try (try builder_pointer_section.getPointerElement(0)).getText());
    const name_builder_pointer = try person_builder.get_nameAsPointer();
    try std.testing.expectEqualSlices(u8, "Ada", try name_builder_pointer.getText());
    var name_view_reader = try builder.asReader(.{});
    const name_pointer_view = try person_builder.get_nameAsReader(&name_view_reader);
    try std.testing.expectEqualSlices(u8, "Ada", try name_pointer_view.getText());
    try std.testing.expectEqual(cpz.wire.PointerType.list, (try person_builder.get_namePointerKind()).?);
    const name_raw_pointer = try person_builder.get_nameRawPointer();
    try std.testing.expectEqual(cpz.wire.PointerType.list, cpz.wire.pointerType(name_raw_pointer));
    const name_decoded = (try person_builder.get_nameDecodedPointer()).?.list;
    try std.testing.expectEqual(cpz.ElementSize.byte, name_decoded.element_size);
    const name_total_size = try person_builder.get_nameTotalSize();
    try std.testing.expect(name_total_size.word_count > 0);
    try person_builder.set_favorite(.blue);
    try std.testing.expectEqual(generated.Color.blue, try person_builder.get_favorite());
    try std.testing.expectEqual(@as(u16, 2), try person_builder.get_favorite_raw());
    const scores = try person_builder.init_scores(2);
    try std.testing.expect(!scores.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), try scores.lastIndex());
    try std.testing.expectEqual(cpz.ElementSize.four_bytes, scores.elementSize());
    try scores.set(0, 10);
    try scores.set(1, 20);
    try std.testing.expectEqual(@as(u32, 20), try scores.get(1));
    try std.testing.expectEqual(@as(usize, 8), scores.rawBytes().len);
    try std.testing.expectEqual(@as(u8, 10), scores.rawBytes()[0]);
    const scores_prefix = try scores.slice(0, 1);
    try std.testing.expectEqual(@as(usize, 1), scores_prefix.len());
    try std.testing.expectEqual(@as(u32, 10), try scores_prefix.get(0));
    const scores_tail_copy = try scores.slice(1, 1);
    try std.testing.expectEqual(@as(u32, 20), try scores_tail_copy.get(0));
    try scores_tail_copy.set(0, 99);
    try std.testing.expectEqual(@as(u32, 20), try scores.get(1));
    var score_list_orphan = try generated.Person.Person_scores_Orphan.newOrphanIn(scores.orphanage(), 1);
    score_list_orphan.release();
    try std.testing.expect(score_list_orphan.isNull());
    var scores_reader = try builder.asReader(.{});
    const scores_view = scores.asReader(&scores_reader);
    try std.testing.expectEqual(@as(u32, 10), scores_view.get(0));
    const same_scores = try person_builder.get_scores();
    try std.testing.expectEqual(@as(u32, 10), try same_scores.get(0));
    const children = try person_builder.init_children(1);
    try std.testing.expectEqual(generated.Person.size, children.structElementSize());
    const child = try children.get(0);
    try child.set_id(99);
    try child.set_name("Grace");
    const children_slice = try children.slice(0, 1);
    try std.testing.expectEqual(@as(u32, 99), try (try children_slice.get(0)).get_id());
    const same_children = try person_builder.get_children();
    const same_child = try same_children.get(0);
    try std.testing.expectEqual(@as(u32, 99), try same_child.get_id());
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
    try std.testing.expectEqual(false, try aliases.elementIsNull(0));
    try std.testing.expectEqual(cpz.wire.PointerType.list, (try aliases.elementPointerKind(0)).?);
    const alias_element_raw = try aliases.elementRawPointer(0);
    try std.testing.expectEqual(cpz.wire.PointerType.list, cpz.wire.pointerType(alias_element_raw));
    const alias_element_decoded = (try aliases.elementDecodedPointer(0)).?.list;
    try std.testing.expectEqual(cpz.ElementSize.byte, alias_element_decoded.element_size);
    var alias_element_reader = try builder.asReader(.{});
    const alias_element_pointer = try aliases.elementAsReader(1, &alias_element_reader);
    try std.testing.expectEqualSlices(u8, "Lovelace", try alias_element_pointer.getText());
    try std.testing.expectEqualSlices(u8, "A", try aliases.elementAsText(0));
    const alias_element_size = try aliases.elementTotalSize(0);
    try std.testing.expect(alias_element_size.word_count > 0);
    try std.testing.expectEqualSlices(u8, "Lovelace", try aliases.get(1));
    const same_aliases = try person_builder.get_aliases();
    try std.testing.expectEqualSlices(u8, "A", try same_aliases.get(0));
    const payloads = try person_builder.init_payloads(1);
    try payloads.set(0, &[_]u8{ 4, 5, 6 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6 }, try payloads.elementAsData(0));
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
    const marks = try person_builder.init_marks(2);
    try marks.set(0, {});
    try marks.get(1);
    const same_marks = try person_builder.get_marks();
    try same_marks.get(0);
    try person_builder.set_maybeName("Optional Ada");
    const maybe_friend = try person_builder.init_maybeFriend();
    try maybe_friend.set_id(64);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = try generated.Person.getRoot(&reader);
    try std.testing.expectEqual(generated.Person.size, person.actualSize());
    try std.testing.expectEqual(@as(u8, 7 ^ 42), person.dataSection()[0]);
    const person_pointer_section = person.pointerSection();
    try std.testing.expectEqual(@as(usize, generated.Person.size.pointer_count), person_pointer_section.len());
    try std.testing.expectEqualSlices(u8, "Ada", try (try person_pointer_section.getPointerElement(0)).getText());
    try std.testing.expectEqual(@as(u32, 7), person.id());
    try std.testing.expectEqual(false, person.active());
    try std.testing.expect(person.has_name());
    try std.testing.expectEqualSlices(u8, "Ada", try person.name());
    const read_name_pointer = try person.nameAsPointer();
    try std.testing.expectEqualSlices(u8, "Ada", try read_name_pointer.getText());
    try std.testing.expectEqual(cpz.wire.PointerType.list, (try person.namePointerKind()).?);
    const read_name_raw_pointer = try person.nameRawPointer();
    try std.testing.expectEqual(cpz.wire.PointerType.list, cpz.wire.pointerType(read_name_raw_pointer));
    const read_name_decoded = (try person.nameDecodedPointer()).?.list;
    try std.testing.expectEqual(cpz.ElementSize.byte, read_name_decoded.element_size);
    const read_name_total_size = try person.nameTotalSize();
    try std.testing.expect(read_name_total_size.word_count > 0);
    try std.testing.expect(generated.Color.blue == try person.favorite());
    try std.testing.expectEqual(@as(u16, 2), person.favorite_raw());
    const read_scores = try person.scores();
    try std.testing.expect(!read_scores.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), try read_scores.lastIndex());
    try std.testing.expectEqual(cpz.ElementSize.four_bytes, read_scores.elementSize());
    try std.testing.expectEqual(@as(u32, 20), read_scores.get(1));
    try std.testing.expectEqual(@as(usize, 8), read_scores.rawBytes().len);
    try std.testing.expectEqual(@as(u8, 20), read_scores.rawBytes()[4]);
    const read_scores_prefix = try read_scores.slice(0, 1);
    try std.testing.expectEqual(@as(usize, 1), read_scores_prefix.len());
    try std.testing.expectEqual(@as(u32, 10), read_scores_prefix.get(0));
    const read_scores_tail = try read_scores.slice(1, 1);
    try std.testing.expectEqual(@as(usize, 1), read_scores_tail.len());
    try std.testing.expectEqual(@as(u32, 20), read_scores_tail.get(0));
    try std.testing.expectEqual(@as(usize, 4), read_scores_tail.rawBytes().len);
    const read_children = try person.children();
    try std.testing.expectEqual(generated.Person.size, read_children.structElementSize());
    const read_child = try read_children.get(0);
    try std.testing.expectEqual(@as(u32, 99), read_child.id());
    try std.testing.expectEqualSlices(u8, "Grace", try read_child.name());
    const read_child_slice = try read_children.slice(0, 1);
    try std.testing.expectEqual(@as(u32, 99), (try read_child_slice.get(0)).id());
    const children_size = try read_children.totalSize();
    try std.testing.expect(children_size.word_count > 0);
    try std.testing.expectEqual(@as(usize, 0), children_size.cap_count);
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
    try std.testing.expectEqual(false, try read_aliases.elementIsNull(1));
    try std.testing.expectEqual(cpz.wire.PointerType.list, (try read_aliases.elementPointerKind(1)).?);
    const read_alias_element_raw = try read_aliases.elementRawPointer(1);
    try std.testing.expectEqual(cpz.wire.PointerType.list, cpz.wire.pointerType(read_alias_element_raw));
    const read_alias_decoded = (try read_aliases.elementDecodedPointer(1)).?.list;
    try std.testing.expectEqual(cpz.ElementSize.byte, read_alias_decoded.element_size);
    try std.testing.expectEqualSlices(u8, "A", try (try read_aliases.elementAsPointer(0)).getText());
    try std.testing.expectEqualSlices(u8, "Lovelace", try read_aliases.elementAsText(1));
    const read_alias_element_size = try read_aliases.elementTotalSize(1);
    try std.testing.expect(read_alias_element_size.word_count > 0);
    const read_payloads = try person.payloads();
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6 }, try read_payloads.get(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6 }, try read_payloads.elementAsData(0));
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
    const read_marks = try person.marks();
    try std.testing.expectEqual(@as(usize, 2), read_marks.len());
    read_marks.get(1);
    try std.testing.expect(person.has_maybeName());
    try std.testing.expectEqualSlices(u8, "Optional Ada", try person.maybeName());
    const read_maybe_friend = try person.maybeFriend();
    try std.testing.expectEqual(@as(u32, 64), read_maybe_friend.id());
    const person_size = try person.totalSize();
    try std.testing.expect(person_size.word_count > 0);
    try std.testing.expectEqual(@as(usize, 0), person_size.cap_count);
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

test "generated builders can disown and adopt pointer fields" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_name("Orphaned name");
    const friend = try person_builder.init_friend();
    try friend.set_id(2024);
    try friend.set_name("Orphaned friend");

    var name_orphan = try person_builder.disown_name();
    try std.testing.expectEqual(false, try person_builder.has_name());
    try person_builder.adopt_nickname(&name_orphan);
    try std.testing.expectEqual(@as(u64, 0), name_orphan.raw);
    try std.testing.expectEqualSlices(u8, "Orphaned name", try person_builder.get_nickname());
    var nickname_orphan = try person_builder.new_nickname_orphan("Allocated nickname");
    try std.testing.expectEqualSlices(u8, "Allocated nickname", try nickname_orphan.getText());
    try person_builder.adopt_nickname(&nickname_orphan);
    try std.testing.expectEqualSlices(u8, "Allocated nickname", try person_builder.get_nickname());
    var payload_orphan = try person_builder.new_maybeName_orphan("Allocated maybe name");
    try std.testing.expectEqualSlices(u8, "Allocated maybe name", try payload_orphan.getText());
    try person_builder.adopt_maybeName(&payload_orphan);
    try std.testing.expectEqualSlices(u8, "Allocated maybe name", try person_builder.get_maybeName());

    var friend_orphan = try person_builder.disown_friend();
    try std.testing.expectEqual(false, try person_builder.has_friend());
    try person_builder.adopt_maybeFriend(&friend_orphan);
    const maybe_friend = try person_builder.get_maybeFriend();
    try std.testing.expectEqual(@as(u32, 2024), try maybe_friend.get_id());
    try std.testing.expectEqualSlices(u8, "Orphaned friend", try maybe_friend.get_name());

    var allocated_friend_orphan = try person_builder.new_friend_orphan();
    const allocated_friend_builder = try allocated_friend_orphan.get();
    try allocated_friend_builder.set_id(2025);
    try allocated_friend_builder.set_name("Allocated friend orphan");
    try person_builder.adopt_friend_typed(&allocated_friend_orphan);
    const allocated_friend = try person_builder.get_friend();
    try std.testing.expectEqual(@as(u32, 2025), try allocated_friend.get_id());

    const typed_friend = try person_builder.init_friend();
    try typed_friend.set_id(3030);
    try typed_friend.set_name("Typed orphan");
    var typed_orphan: generated.Person.Orphan = try person_builder.disown_friend_typed();
    try std.testing.expect(!typed_orphan.isNull());
    const orphan_builder = try typed_orphan.get();
    try std.testing.expectEqual(@as(u32, 3030), try orphan_builder.get_id());
    try std.testing.expectEqualSlices(u8, "Typed orphan", try orphan_builder.get_name());
    var orphan_reader = try builder.asReader(.{});
    const orphan_view = try typed_orphan.getReader(&orphan_reader);
    try std.testing.expectEqual(@as(u32, 3030), orphan_view.id());
    var orphan_reader_alias = try builder.asReader(.{});
    const orphan_view_alias = try typed_orphan.asReader(&orphan_reader_alias);
    try std.testing.expectEqual(@as(u32, 3030), orphan_view_alias.id());
    var orphan_decode_reader = try builder.asReader(.{});
    const orphan_pointer_reader = typed_orphan.asPointerReader(&orphan_decode_reader);
    try std.testing.expectEqual(cpz.wire.PointerType.struct_ptr, (try orphan_pointer_reader.pointerType()).?);
    const decoded_orphan = (try typed_orphan.decode(&orphan_decode_reader)).?.struct_ptr;
    try std.testing.expectEqual(generated.Person.size.data_words, decoded_orphan.data_words);
    try std.testing.expectEqual(generated.Person.size.pointer_count, decoded_orphan.pointer_count);
    const orphan_size = try typed_orphan.totalSize();
    try std.testing.expect(orphan_size.word_count > 0);
    try person_builder.adopt_maybeFriend_typed(&typed_orphan);
    try std.testing.expectEqual(@as(u64, 0), typed_orphan.raw());
    const typed_maybe_friend = try person_builder.get_maybeFriend();
    try std.testing.expectEqual(@as(u32, 3030), try typed_maybe_friend.get_id());
    try std.testing.expectEqualSlices(u8, "Typed orphan", try typed_maybe_friend.get_name());

    const raw_typed_friend = try person_builder.init_friend();
    try raw_typed_friend.set_id(4040);
    try raw_typed_friend.set_name("From raw orphan");
    var raw_orphan = try person_builder.disown_friend();
    var typed_from_raw = generated.Person.Orphan.fromRaw(raw_orphan);
    raw_orphan.release();
    try person_builder.adopt_maybeFriend_typed(&typed_from_raw);
    const from_raw_friend = try person_builder.get_maybeFriend();
    try std.testing.expectEqual(@as(u32, 4040), try from_raw_friend.get_id());

    var copy_reader_for_orphan = try builder.asReader(.{});
    var copied_friend_orphan = try person_builder.new_maybeFriend_copyOrphan(from_raw_friend.asReader(&copy_reader_for_orphan));
    try person_builder.adopt_maybeFriend_typed(&copied_friend_orphan);
    const copied_friend = try person_builder.get_maybeFriend();
    try std.testing.expectEqual(@as(u32, 4040), try copied_friend.get_id());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    try std.testing.expect(!person.has_name());
    try std.testing.expectEqualSlices(u8, "Allocated nickname", try person.nickname());
    try std.testing.expectEqualSlices(u8, "Allocated maybe name", try person.maybeName());
    try std.testing.expect(!person.has_friend());
    const read_maybe_friend = try person.maybeFriend();
    try std.testing.expectEqual(@as(u32, 4040), read_maybe_friend.id());
    try std.testing.expectEqualSlices(u8, "From raw orphan", try read_maybe_friend.name());
}

test "generated structs can allocate typed orphans" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    var orphan = try generated.Person.newOrphan(&builder);
    const orphan_builder = try orphan.get();
    try orphan_builder.set_id(5150);
    try orphan_builder.set_name("Allocated orphan");

    var orphan_reader = try builder.asReader(.{});
    const orphan_view = try orphan.getReader(&orphan_reader);
    try std.testing.expectEqual(@as(u32, 5150), orphan_view.id());
    try std.testing.expectEqualSlices(u8, "Allocated orphan", try orphan_view.name());

    try person_builder.adopt_friend_typed(&orphan);
    try std.testing.expect(orphan.isNull());

    var dropped = try generated.Person.newOrphan(&builder);
    dropped.release();
    try std.testing.expect(dropped.isNull());

    var orphan_from_orphanage = try generated.Person.newOrphanIn(person_builder.orphanage());
    const orphanage_builder = try orphan_from_orphanage.get();
    try orphanage_builder.set_id(5252);
    try orphanage_builder.set_name("Orphanage orphan");
    try person_builder.adopt_maybeFriend_typed(&orphan_from_orphanage);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const friend = try person.friend();
    try std.testing.expectEqual(@as(u32, 5150), friend.id());
    try std.testing.expectEqualSlices(u8, "Allocated orphan", try friend.name());
    const maybe_friend = try person.maybeFriend();
    try std.testing.expectEqual(@as(u32, 5252), maybe_friend.id());
    try std.testing.expectEqualSlices(u8, "Orphanage orphan", try maybe_friend.name());
}

test "generated structs can allocate typed orphan copies" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    try source_person_builder.set_id(6161);
    try source_person_builder.set_name("Copied orphan");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_person = generated.Person.fromReader(try source_reader.getRoot());

    var target_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer target_builder.deinit();
    const target_person_builder = try generated.Person.initRootTyped(&target_builder);
    var orphan = try generated.Person.newOrphanCopy(&target_builder, source_person);
    try target_person_builder.adopt_friend_typed(&orphan);
    var orphanage_copy = try generated.Person.newOrphanCopyIn(cpz.Orphanage.init(&target_builder), source_person);
    try target_person_builder.adopt_maybeFriend_typed(&orphanage_copy);

    var target_reader = cpz.MessageReader.init(try target_builder.segmentsConst(), .{});
    const target_person = generated.Person.fromReader(try target_reader.getRoot());
    const friend = try target_person.friend();
    try std.testing.expectEqual(@as(u32, 6161), friend.id());
    try std.testing.expectEqualSlices(u8, "Copied orphan", try friend.name());
    const maybe_friend = try target_person.maybeFriend();
    try std.testing.expectEqual(@as(u32, 6161), maybe_friend.id());
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

test "generated builders can copy and clear whole structs" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    try source_person_builder.set_id(909);
    try source_person_builder.set_name("WholeCopy");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_person = generated.Person.fromReader(try source_reader.getRoot());

    var target_builder_message = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer target_builder_message.deinit();
    const target_person_builder = try generated.Person.initRootTyped(&target_builder_message);
    try target_person_builder.copyFrom(source_person);
    try std.testing.expectEqual(@as(u32, 909), try target_person_builder.get_id());
    try std.testing.expectEqualSlices(u8, "WholeCopy", try target_person_builder.get_name());
    try target_person_builder.clear();
    try std.testing.expectEqual(@as(u32, 42), try target_person_builder.get_id());
    try std.testing.expectEqual(false, try target_person_builder.has_name());
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

test "generated builders can copy whole list fields from readers" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    const source_scores = try source_person_builder.init_scores(2);
    try source_scores.set(0, 12);
    try source_scores.set(1, 34);
    const source_children = try source_person_builder.init_children(1);
    const source_child = try source_children.get(0);
    try source_child.set_id(901);
    try source_child.set_name("WholeListCopy");
    const source_aliases = try source_person_builder.init_aliases(1);
    try source_aliases.set(0, "CopiedAlias");
    const source_groups = try source_person_builder.init_scoreGroups(1);
    const source_group = try source_groups.init(0, .four_bytes, 1);
    try source_group.setUInt32(0, 777);
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_person = generated.Person.fromReader(try source_reader.getRoot());

    var target_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer target_builder.deinit();
    const target_person_builder = try generated.Person.initRootTyped(&target_builder);
    try target_person_builder.set_scores_from(try source_person.scores());
    try target_person_builder.set_children_from(try source_person.children());
    try target_person_builder.set_aliases_from(try source_person.aliases());
    try target_person_builder.set_scoreGroups_from(try source_person.scoreGroups());

    var target_reader = cpz.MessageReader.init(try target_builder.segmentsConst(), .{});
    const target_person = generated.Person.fromReader(try target_reader.getRoot());
    const target_scores = try target_person.scores();
    try std.testing.expectEqual(@as(u32, 12), target_scores.get(0));
    try std.testing.expectEqual(@as(u32, 34), target_scores.get(1));
    const target_children = try target_person.children();
    const target_child = try target_children.get(0);
    try std.testing.expectEqual(@as(u32, 901), target_child.id());
    try std.testing.expectEqualSlices(u8, "WholeListCopy", try target_child.name());
    const target_aliases = try target_person.aliases();
    try std.testing.expectEqualSlices(u8, "CopiedAlias", try target_aliases.get(0));
    const target_groups = try target_person.scoreGroups();
    try std.testing.expectEqual(@as(u32, 777), (try target_groups.get(0)).getUInt32(0));
}

test "generated builders can use typed list field orphans" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_scores(&[_]u32{ 1, 2 });
    var scores_orphan = try person_builder.disown_scores_typed();
    try std.testing.expectEqual(false, try person_builder.has_scores());
    const orphan_scores = try scores_orphan.get();
    try std.testing.expectEqual(@as(u32, 2), try orphan_scores.get(1));
    try orphan_scores.set(1, 42);
    var orphan_reader = try builder.asReader(.{});
    const orphan_scores_reader = try scores_orphan.getReader(&orphan_reader);
    try std.testing.expectEqual(@as(u32, 42), orphan_scores_reader.get(1));
    var orphan_reader_alias = try builder.asReader(.{});
    const orphan_scores_reader_alias = try scores_orphan.asReader(&orphan_reader_alias);
    try std.testing.expectEqual(@as(u32, 42), orphan_scores_reader_alias.get(1));
    var scores_decode_reader = try builder.asReader(.{});
    const scores_pointer_reader = scores_orphan.asPointerReader(&scores_decode_reader);
    try std.testing.expectEqual(cpz.wire.PointerType.list, (try scores_pointer_reader.pointerType()).?);
    const decoded_scores = (try scores_orphan.decode(&scores_decode_reader)).?.list;
    try std.testing.expectEqual(cpz.wire.ElementSize.four_bytes, decoded_scores.element_size);
    try std.testing.expectEqual(@as(u29, 2), decoded_scores.element_count_or_words);
    try person_builder.adopt_scores_typed(&scores_orphan);
    try std.testing.expect(scores_orphan.isNull());

    try person_builder.set_scores(&[_]u32{ 3, 4 });
    var raw_scores = try person_builder.disown_scores();
    var scores_from_raw = generated.Person.Person_scores_Orphan.fromRaw(raw_scores);
    raw_scores.release();
    const from_raw_scores = try scores_from_raw.get();
    try from_raw_scores.set(0, 33);
    try person_builder.adopt_scores_typed(&scores_from_raw);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const scores = try person.scores();
    try std.testing.expectEqual(@as(u32, 33), scores.get(0));
    try std.testing.expectEqual(@as(u32, 4), scores.get(1));
}

test "generated list orphan wrappers can allocate new orphans" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    var scores_orphan = try generated.Person.Person_scores_Orphan.newOrphan(&builder, 2);
    const orphan_scores = try scores_orphan.get();
    try orphan_scores.set(0, 123);
    try orphan_scores.set(1, 456);
    try person_builder.adopt_scores_typed(&scores_orphan);

    var children_orphan = try generated.Person.Person_children_Orphan.newOrphan(&builder, 1);
    const orphan_children = try children_orphan.get();
    const child = try orphan_children.get(0);
    try child.set_id(654);
    try child.set_name("List orphan child");
    try person_builder.adopt_children_typed(&children_orphan);

    var dropped_scores = try generated.Person.Person_scores_Orphan.newOrphan(&builder, 1);
    dropped_scores.release();
    try std.testing.expect(dropped_scores.isNull());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const scores = try person.scores();
    try std.testing.expectEqual(@as(u32, 123), scores.get(0));
    try std.testing.expectEqual(@as(u32, 456), scores.get(1));
    const children = try person.children();
    const read_child = try children.get(0);
    try std.testing.expectEqual(@as(u32, 654), read_child.id());
    try std.testing.expectEqualSlices(u8, "List orphan child", try read_child.name());

    var orphanage_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer orphanage_builder.deinit();
    const orphanage_person_builder = try generated.Person.initRootTyped(&orphanage_builder);
    var orphanage_scores = try generated.Person.Person_scores_Orphan.newOrphanIn(orphanage_person_builder.orphanage(), 1);
    const orphanage_scores_builder = try orphanage_scores.get();
    try orphanage_scores_builder.set(0, 999);
    try orphanage_person_builder.adopt_scores_typed(&orphanage_scores);
    var orphanage_reader = cpz.MessageReader.init(try orphanage_builder.segmentsConst(), .{});
    const orphanage_person = generated.Person.fromReader(try orphanage_reader.getRoot());
    const orphanage_read_scores = try orphanage_person.scores();
    try std.testing.expectEqual(@as(u32, 999), orphanage_read_scores.get(0));
}

test "generated list orphan wrappers can allocate orphan copies" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    try source_person_builder.set_scores(&[_]u32{ 7, 14 });
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_person = generated.Person.fromReader(try source_reader.getRoot());

    var target_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer target_builder.deinit();
    const target_person_builder = try generated.Person.initRootTyped(&target_builder);
    var scores_orphan = try generated.Person.Person_scores_Orphan.newOrphanCopy(&target_builder, try source_person.scores());
    const orphan_scores = try scores_orphan.get();
    try orphan_scores.set(1, 28);
    try target_person_builder.adopt_scores_typed(&scores_orphan);

    var target_reader = cpz.MessageReader.init(try target_builder.segmentsConst(), .{});
    const target_person = generated.Person.fromReader(try target_reader.getRoot());
    const scores = try target_person.scores();
    try std.testing.expectEqual(@as(u32, 7), scores.get(0));
    try std.testing.expectEqual(@as(u32, 28), scores.get(1));

    var target_copy_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer target_copy_builder.deinit();
    const target_copy_person_builder = try generated.Person.initRootTyped(&target_copy_builder);
    var scores_orphanage = try generated.Person.Person_scores_Orphan.newOrphanCopyIn(target_copy_person_builder.orphanage(), try source_person.scores());
    try target_copy_person_builder.adopt_scores_typed(&scores_orphanage);
    var target_copy_reader = cpz.MessageReader.init(try target_copy_builder.segmentsConst(), .{});
    const target_copy_person = generated.Person.fromReader(try target_copy_reader.getRoot());
    const copied_scores = try target_copy_person.scores();
    try std.testing.expectEqual(@as(u32, 14), copied_scores.get(1));
}

test "generated builders can set whole list fields from slices" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_child_builder = try generated.Person.initRootTyped(&source_builder);
    try source_child_builder.set_id(444);
    try source_child_builder.set_name("SliceChild");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_child = generated.Person.fromReader(try source_reader.getRoot());

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const person_builder = try generated.Person.initRootTyped(&builder);
    try person_builder.set_scores(&[_]u32{ 5, 8, 13 });
    try person_builder.set_flags(&[_]bool{ true, false, true });
    try person_builder.set_ratios(&[_]f32{ 0.5, 1.25 });
    try person_builder.set_palette(&[_]generated.Color{ .blue, .red });
    try person_builder.set_palette_raw(&[_]u16{ 2, 0 });
    const aliases = [_][]const u8{ "slice", "setter" };
    try person_builder.set_aliases(&aliases);
    const payload0 = [_]u8{ 9, 8, 7 };
    const payload1 = [_]u8{6};
    const payloads = [_][]const u8{ &payload0, &payload1 };
    try person_builder.set_payloads(&payloads);
    const children = [_]generated.Person{source_child};
    try person_builder.set_children(&children);
    try person_builder.set_marks(&[_]void{ {}, {}, {} });

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const read_scores = try person.scores();
    try std.testing.expectEqual(@as(u32, 13), read_scores.get(2));
    const read_flags = try person.flags();
    try std.testing.expectEqual(true, read_flags.get(0));
    try std.testing.expectEqual(false, read_flags.get(1));
    const read_ratios = try person.ratios();
    try std.testing.expectEqual(@as(f32, 1.25), read_ratios.get(1));
    const read_palette = try person.palette();
    try std.testing.expectEqual(generated.Color.blue, try read_palette.get(0));
    try std.testing.expectEqual(@as(u16, 0), read_palette.getRaw(1));
    const read_aliases = try person.aliases();
    try std.testing.expectEqualSlices(u8, "setter", try read_aliases.get(1));
    const read_payloads = try person.payloads();
    try std.testing.expectEqualSlices(u8, &payload0, try read_payloads.get(0));
    const read_children = try person.children();
    const read_child = try read_children.get(0);
    try std.testing.expectEqual(@as(u32, 444), read_child.id());
    try std.testing.expectEqualSlices(u8, "SliceChild", try read_child.name());
    const read_marks = try person.marks();
    try std.testing.expectEqual(@as(usize, 3), read_marks.len());

    var cap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer cap_builder.deinit();
    const dynamic_builder = try generated.DynamicBox.initRootTyped(&cap_builder);
    try dynamic_builder.set_capList(&[_]u32{ 41, 42 });
    var cap_reader = cpz.MessageReader.init(try cap_builder.segmentsConst(), .{});
    const dynamic_box = generated.DynamicBox.fromReader(try cap_reader.getRoot());
    const read_caps = try dynamic_box.capList();
    try std.testing.expectEqual(@as(u32, 42), try read_caps.get(1));

    var interface_builder_message = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer interface_builder_message.deinit();
    const interface_builder = try generated.InterfaceBox.initRootTyped(&interface_builder_message);
    try interface_builder.set_services(&[_]u32{ 51, 52 });
    var interface_reader = cpz.MessageReader.init(try interface_builder_message.segmentsConst(), .{});
    const interface_box = generated.InterfaceBox.fromReader(try interface_reader.getRoot());
    const read_services = try interface_box.services();
    try std.testing.expectEqual(@as(u32, 52), try read_services.get(1));
}

test "generated list builders can clear pointer-backed and struct elements" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    const aliases = try person_builder.init_aliases(1);
    try aliases.set(0, "drop");
    try aliases.clear(0);
    try std.testing.expect(try aliases.elementIsNull(0));
    const payloads = try person_builder.init_payloads(1);
    try payloads.set(0, &[_]u8{7});
    try payloads.clear(0);
    try std.testing.expect(try payloads.elementIsNull(0));
    const children = try person_builder.init_children(1);
    const child = try children.get(0);
    try child.set_id(111);
    try child.set_name("drop child");
    try children.clear(0);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const read_aliases = try person.aliases();
    try std.testing.expect(try read_aliases.elementIsNull(0));
    try std.testing.expectError(error.NullPointer, read_aliases.get(0));
    const read_payloads = try person.payloads();
    try std.testing.expect(try read_payloads.elementIsNull(0));
    try std.testing.expectError(error.NullPointer, read_payloads.get(0));
    const read_children = try person.children();
    const read_child = try read_children.get(0);
    try std.testing.expectEqual(@as(u32, 42), read_child.id());
    try std.testing.expectError(error.NullPointer, read_child.name());
}

test "generated pointer list builders can disown and adopt elements" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    const aliases = try person_builder.init_aliases(2);
    try aliases.set(0, "move alias");
    try aliases.set(1, "replace me");
    var alias_orphan = try aliases.disown(0);
    try aliases.adopt(1, &alias_orphan);
    try std.testing.expectEqual(@as(u64, 0), alias_orphan.raw);
    var new_alias_orphan = try aliases.newOrphan("new alias");
    try aliases.adopt(0, &new_alias_orphan);
    try std.testing.expect(new_alias_orphan.isNull());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const read_aliases = try person.aliases();
    try std.testing.expectEqualSlices(u8, "new alias", try read_aliases.get(0));
    try std.testing.expectEqualSlices(u8, "move alias", try read_aliases.get(1));

    var cap_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer cap_builder.deinit();
    const caps = try (try generated.DynamicBox.initRootTyped(&cap_builder)).init_capList(2);
    try caps.set(0, 1000);
    try caps.set(1, 2000);
    var cap_orphan = try caps.disown(0);
    try caps.adopt(1, &cap_orphan);
    var new_cap_orphan = try caps.newOrphan(3000);
    try caps.adopt(0, &new_cap_orphan);

    var cap_reader = cpz.MessageReader.init(try cap_builder.segmentsConst(), .{});
    const box = generated.DynamicBox.fromReader(try cap_reader.getRoot());
    const read_caps = try box.capList();
    try std.testing.expectEqual(@as(u32, 3000), try read_caps.get(0));
    try std.testing.expectEqual(@as(u32, 1000), try read_caps.get(1));
}

test "generated nested list wrappers round-trip" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    const score_groups = try person_builder.init_scoreGroups(2);
    const first_scores = try score_groups.init(0, .four_bytes, 2);
    try first_scores.setUInt32(0, 100);
    try first_scores.setUInt32(1, 200);
    const second_scores = try score_groups.init(1, .four_bytes, 1);
    try second_scores.setUInt32(0, 300);
    try std.testing.expectEqual(@as(u32, 200), try (try score_groups.get(0)).getUInt32(1));
    const same_score_groups = try person_builder.get_scoreGroups();
    try std.testing.expectEqual(@as(u32, 300), try (try same_score_groups.get(1)).getUInt32(0));

    const alias_groups = try person_builder.init_aliasGroups(1);
    const aliases = try alias_groups.init(0, .pointer, 2);
    try (try aliases.getPointerElement(0)).setText("nested");
    try (try aliases.getPointerElement(1)).setText("text");
    try std.testing.expectEqualSlices(u8, "nested", try (try (try alias_groups.get(0)).getPointerElement(0)).getText());
    const same_alias_groups = try person_builder.get_aliasGroups();
    try std.testing.expectEqualSlices(u8, "text", try (try (try same_alias_groups.get(0)).getPointerElement(1)).getText());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const read_score_groups = try person.scoreGroups();
    try std.testing.expectEqual(@as(usize, 2), read_score_groups.len());
    const read_first_scores = try read_score_groups.get(0);
    try std.testing.expectEqual(@as(u32, 100), read_first_scores.getUInt32(0));
    try std.testing.expectEqual(@as(u32, 200), read_first_scores.getUInt32(1));
    const read_second_scores = try read_score_groups.get(1);
    try std.testing.expectEqual(@as(u32, 300), read_second_scores.getUInt32(0));

    const read_alias_groups = try person.aliasGroups();
    try std.testing.expectEqual(@as(usize, 1), read_alias_groups.len());
    const read_aliases = try read_alias_groups.get(0);
    try std.testing.expectEqualSlices(u8, "nested", try (try read_aliases.getPointerElement(0)).getText());
    try std.testing.expectEqualSlices(u8, "text", try (try read_aliases.getPointerElement(1)).getText());
}

test "generated nested struct-list wrappers can initialize composite children" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const person_builder = try generated.Person.initRootTyped(&builder);
    const struct_groups = try person_builder.init_structGroups(1);
    const people = try struct_groups.initStructList(0, 2);
    const first = generated.Person.Builder.fromBuilder(try people.getStructElement(0));
    try first.set_id(501);
    try first.set_name("Nested Alice");
    const second = generated.Person.Builder.fromBuilder(try people.getStructElement(1));
    try second.set_id(502);
    try second.set_name("Nested Bob");
    try std.testing.expectEqual(@as(u32, 502), try generated.Person.Builder.fromBuilder(try (try struct_groups.get(0)).getStructElement(1)).get_id());
    const same_struct_groups = try person_builder.get_structGroups();
    try std.testing.expectEqual(@as(u32, 501), try generated.Person.Builder.fromBuilder(try (try same_struct_groups.get(0)).getStructElement(0)).get_id());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const person = generated.Person.fromReader(try reader.getRoot());
    const read_struct_groups = try person.structGroups();
    const read_people = try read_struct_groups.get(0);
    const read_first = generated.Person.fromReader(try read_people.getStructElement(0));
    try std.testing.expectEqual(@as(u32, 501), read_first.id());
    try std.testing.expectEqualSlices(u8, "Nested Alice", try read_first.name());
    const read_second = generated.Person.fromReader(try read_people.getStructElement(1));
    try std.testing.expectEqual(@as(u32, 502), read_second.id());
    try std.testing.expectEqualSlices(u8, "Nested Bob", try read_second.name());
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

test "generated generic type applications lower to base accessors" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_person_builder = try generated.Person.initRootTyped(&source_builder);
    try source_person_builder.set_id(8181);
    try source_person_builder.set_name("generic person");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_ptr = try source_reader.getRootPointer();

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const box_builder = try generated.GenericUseBox.initRootTyped(&builder);
    const direct = try box_builder.init_direct();
    try direct.set_value_from(source_ptr);
    const alias = try box_builder.init_alias();
    try alias.set_value_from(source_ptr);
    const many = try box_builder.init_many(1);
    const many_item = try many.get(0);
    try many_item.set_value_from(source_ptr);
    const nested = try box_builder.init_nested();
    try nested.set_id(4242);
    try nested.set_label("branded nested");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const box = generated.GenericUseBox.fromReader(try reader.getRoot());
    const direct_person = generated.Person.fromReader(try (try (try box.direct()).value()).getStruct(null));
    try std.testing.expectEqual(@as(u32, 8181), direct_person.id());
    try std.testing.expectEqualSlices(u8, "generic person", try direct_person.name());
    const alias_person = generated.Person.fromReader(try (try (try box.alias()).value()).getStruct(null));
    try std.testing.expectEqual(@as(u32, 8181), alias_person.id());
    const many_person = generated.Person.fromReader(try (try (try (try box.many()).get(0)).value()).getStruct(null));
    try std.testing.expectEqualSlices(u8, "generic person", try many_person.name());
    const nested_read = try box.nested();
    try std.testing.expectEqual(@as(u32, 4242), nested_read.id());
    try std.testing.expectEqualSlices(u8, "branded nested", try nested_read.label());
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
    const any_value = try box_builder.init_any_struct(.{ .data_words = 1, .pointer_count = 1 });
    try any_value.setUInt32(0, 0xabcdef01, 0);
    try any_value.setText(0, "any struct");
    try std.testing.expectEqual(cpz.wire.PointerType.struct_ptr, (try box_builder.get_anyPointerType()).?);
    const any_builder_struct = try box_builder.get_anyAsStruct();
    try std.testing.expectEqual(@as(u32, 0xabcdef01), try any_builder_struct.getUInt32(0, 0));
    try box_builder.set_anyStruct_from(source_struct);
    const any_list = try box_builder.init_anyList(.two_bytes, 2);
    try any_list.setUInt16(0, 111);
    try any_list.setUInt16(1, 222);
    const any_struct_pointer_section = try box_builder.get_anyStructPointerSection();
    try std.testing.expectEqual(@as(usize, 1), any_struct_pointer_section.len());
    try std.testing.expectEqualSlices(u8, "dynamic", try (try any_struct_pointer_section.getPointerElement(0)).getText());
    const any_struct_data_section = try box_builder.get_anyStructDataSection();
    try std.testing.expectEqual(@as(usize, 8), any_struct_data_section.len);
    try std.testing.expectEqual(@as(u8, 0xad), any_struct_data_section[0]);
    try box_builder.set_cap(77);
    var cap_orphan_for_field = try box_builder.new_cap_orphan(7070);
    try std.testing.expectEqual(@as(u32, 7070), try cap_orphan_for_field.getCapabilityIndex());
    try box_builder.adopt_cap(&cap_orphan_for_field);
    try std.testing.expectEqual(@as(u32, 7070), try box_builder.get_cap());
    var blob_orphan = try box_builder.new_blob_orphan(&[_]u8{ 5, 6, 7 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 6, 7 }, try blob_orphan.getData());
    try box_builder.adopt_blob(&blob_orphan);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 6, 7 }, try box_builder.get_blob());
    const caps = try box_builder.init_capList(2);
    try caps.set(0, 88);
    try caps.set(1, 99);
    try std.testing.expectEqual(cpz.wire.PointerType.other, (try caps.elementPointerKind(0)).?);
    const cap_element_raw = try caps.elementRawPointer(0);
    try std.testing.expectEqual(cpz.wire.PointerType.other, cpz.wire.pointerType(cap_element_raw));
    try std.testing.expectEqual(@as(u32, 88), (try caps.elementDecodedPointer(0)).?.other.index);
    try std.testing.expectEqual(@as(u32, 99), try caps.elementAsCapability(1));
    try std.testing.expectEqual(@as(u32, 7070), try box_builder.get_cap());
    try std.testing.expectEqual(@as(u32, 99), try caps.get(1));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const dynamic_box = generated.DynamicBox.fromReader(try reader.getRoot());
    try std.testing.expect(dynamic_box.has_any());
    try std.testing.expectEqual(cpz.wire.PointerType.struct_ptr, (try dynamic_box.anyPointerType()).?);
    const read_any_via_helper = try dynamic_box.anyAsStruct();
    try std.testing.expectEqual(@as(u32, 0xabcdef01), read_any_via_helper.getUInt32(0, 0));
    const read_any = try (try dynamic_box.any()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0xabcdef01), read_any.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "any struct", try read_any.getPointerField(0).getText());
    const any_struct = try dynamic_box.anyStruct();
    try std.testing.expectEqual(@as(u32, 0xdecafbad), any_struct.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "dynamic", try any_struct.getPointerField(0).getText());
    const read_any_struct_pointer_section = try dynamic_box.anyStructPointerSection();
    try std.testing.expectEqualSlices(u8, "dynamic", try (try read_any_struct_pointer_section.getPointerElement(0)).getText());
    const read_any_struct_data_section = try dynamic_box.anyStructDataSection();
    try std.testing.expectEqual(@as(u8, 0xad), read_any_struct_data_section[0]);
    const read_list = try dynamic_box.anyList();
    try std.testing.expectEqual(@as(u16, 222), read_list.getUInt16(1));
    try std.testing.expectEqual(@as(u32, 7070), try dynamic_box.cap());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 6, 7 }, try dynamic_box.blob());
    const read_caps = try dynamic_box.capList();
    try std.testing.expectEqual(@as(u32, 88), try read_caps.get(0));
    try std.testing.expectEqual(@as(u32, 99), try read_caps.get(1));
    try std.testing.expectEqual(cpz.wire.PointerType.other, (try read_caps.elementPointerKind(1)).?);
    const read_cap_element_raw = try read_caps.elementRawPointer(1);
    try std.testing.expectEqual(cpz.wire.PointerType.other, cpz.wire.pointerType(read_cap_element_raw));
    try std.testing.expectEqual(@as(u32, 99), (try read_caps.elementDecodedPointer(1)).?.other.index);
    try std.testing.expectEqual(@as(u32, 88), try read_caps.elementAsCapability(0));

    const any_items = try box_builder.init_anyListItems(5);
    try any_items.setText(0, "list any text");
    try any_items.setData(1, &[_]u8{ 4, 5 });
    var any_item_cap = try any_items.newCapabilityOrphan(6060);
    try any_items.adopt(2, &any_item_cap);
    const any_item_struct = try any_items.initStruct(3, .{ .data_words = 1, .pointer_count = 0 });
    try any_item_struct.setUInt32(0, 0x7777, 0);
    var any_item_list_orphan = try any_items.newListOrphan(.four_bytes, 1);
    const any_item_list_builder = try any_item_list_orphan.getList(.four_bytes);
    try any_item_list_builder.setUInt32(0, 5151);
    try any_items.adopt(4, &any_item_list_orphan);
    var any_item_copy_orphan = try any_items.newCopyOrphan(source_struct.getPointerField(0));
    try any_items.adopt(1, &any_item_copy_orphan);
    try std.testing.expectEqualSlices(u8, "list any text", try any_items.getAsText(0));
    try std.testing.expectEqualSlices(u8, "dynamic", try any_items.getAsText(1));
    try std.testing.expectEqual(@as(u32, 6060), try any_items.getAsCapability(2));
    try std.testing.expectEqual(@as(u32, 0x7777), (try any_items.getAsStruct(3)).getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 5151), (try any_items.getAsList(4, .four_bytes)).getUInt32(0));

    const any_struct_items = try box_builder.init_anyStructItems(1);
    const any_struct_item = try any_struct_items.init(0, .{ .data_words = 1, .pointer_count = 1 });
    try any_struct_item.setUInt32(0, 0xbeefcafe, 0);
    try any_struct_item.setText(0, "list any struct");
    var any_struct_item_copy = try any_struct_items.newCopyOrphan(source_struct);
    try any_struct_items.adopt(0, &any_struct_item_copy);
    const read_any_struct_item = try any_struct_items.get(0);
    try std.testing.expectEqual(@as(u32, 0xdecafbad), try read_any_struct_item.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "dynamic", try (try read_any_struct_item.getPointerField(0)).getText());
    try std.testing.expectEqual(@as(u8, 0xad), (try any_struct_items.dataSection(0))[0]);
    try std.testing.expectEqualSlices(u8, "dynamic", try (try (try any_struct_items.pointerSection(0)).getPointerElement(0)).getText());
    var any_struct_items_reader = try builder.asReader(.{});
    const read_any_struct_items = (try generated.DynamicBox.fromReader(try any_struct_items_reader.getRoot()).anyStructItems());
    try std.testing.expectEqual(@as(u8, 0xad), (try read_any_struct_items.dataSection(0))[0]);
    try std.testing.expectEqualSlices(u8, "dynamic", try (try (try read_any_struct_items.pointerSection(0)).getPointerElement(0)).getText());

    var list_copy_source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer list_copy_source_builder.deinit();
    const list_copy_source = try list_copy_source_builder.initRootList(.two_bytes, 2);
    try list_copy_source.setUInt16(0, 111);
    try list_copy_source.setUInt16(1, 222);
    var list_copy_source_reader = cpz.MessageReader.init(try list_copy_source_builder.segmentsConst(), .{});
    const list_copy_source_view = try list_copy_source_reader.getRootList(.two_bytes);

    const any_list_items = try box_builder.init_anyListList(1);
    const any_list_item = try any_list_items.init(0, .four_bytes, 2);
    try any_list_item.setUInt32(0, 4242);
    try any_list_item.setUInt32(1, 8484);
    var any_list_item_copy = try any_list_items.newCopyOrphan(list_copy_source_view);
    try any_list_items.adopt(0, &any_list_item_copy);
    const read_any_list_item = try any_list_items.get(0);
    try std.testing.expectEqual(@as(u16, 222), read_any_list_item.getUInt16(1));
    try std.testing.expectEqual(cpz.ElementSize.two_bytes, try any_list_items.elementSizeAt(0));
    var any_list_items_reader = try builder.asReader(.{});
    const read_any_list_items = try generated.DynamicBox.fromReader(try any_list_items_reader.getRoot()).anyListList();
    try std.testing.expectEqual(cpz.ElementSize.two_bytes, try read_any_list_items.elementSizeAt(0));

    var orphan_builder_message = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer orphan_builder_message.deinit();
    const orphan_box_builder = try generated.DynamicBox.initRootTyped(&orphan_builder_message);
    var any_orphan = try orphan_box_builder.new_any_structOrphan(.{ .data_words = 1, .pointer_count = 1 });
    const orphan_struct = try any_orphan.getStruct();
    try orphan_struct.setUInt32(0, 0xfeedface, 0);
    try orphan_struct.setText(0, "orphan any");
    try orphan_box_builder.adopt_any(&any_orphan);
    var orphan_reader = cpz.MessageReader.init(try orphan_builder_message.segmentsConst(), .{});
    const orphan_box = generated.DynamicBox.fromReader(try orphan_reader.getRoot());
    const orphan_any = try (try orphan_box.any()).getStruct(null);
    try std.testing.expectEqual(@as(u32, 0xfeedface), orphan_any.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "orphan any", try orphan_any.getPointerField(0).getText());

    var any_struct_orphan = try orphan_box_builder.new_anyStruct_structOrphan(.{ .data_words = 1, .pointer_count = 1 });
    const any_struct_orphan_builder = try any_struct_orphan.getStruct();
    try any_struct_orphan_builder.setUInt32(0, 0x13572468, 0);
    try any_struct_orphan_builder.setText(0, "any struct orphan");
    try orphan_box_builder.adopt_anyStruct(&any_struct_orphan);
    const adopted_any_struct = try orphan_box_builder.get_anyStruct();
    try std.testing.expectEqual(@as(u32, 0x13572468), try adopted_any_struct.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "any struct orphan", try (try adopted_any_struct.getPointerField(0)).getText());

    var text_orphan = try orphan_box_builder.new_any_textOrphan("orphan text any");
    try std.testing.expectEqualSlices(u8, "orphan text any", try text_orphan.getText());
    try orphan_box_builder.adopt_any(&text_orphan);
    try std.testing.expectEqualSlices(u8, "orphan text any", try orphan_box_builder.get_anyAsText());
    var data_orphan = try orphan_box_builder.new_any_dataOrphan(&[_]u8{ 7, 8, 9 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 7, 8, 9 }, try data_orphan.getData());
    try orphan_box_builder.adopt_any(&data_orphan);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 7, 8, 9 }, try orphan_box_builder.get_anyAsData());
    var cap_orphan = try orphan_box_builder.new_any_capabilityOrphan(2468);
    try std.testing.expectEqual(@as(u32, 2468), try cap_orphan.getCapabilityIndex());
    try orphan_box_builder.adopt_any(&cap_orphan);
    try std.testing.expectEqual(@as(u32, 2468), try orphan_box_builder.get_anyAsCapability());

    var copy_orphan_builder_message = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer copy_orphan_builder_message.deinit();
    const copy_orphan_box_builder = try generated.DynamicBox.initRootTyped(&copy_orphan_builder_message);
    var copy_orphan = try copy_orphan_box_builder.new_any_copyOrphan(source_struct.getPointerField(0));
    try copy_orphan_box_builder.adopt_any(&copy_orphan);
    var copy_orphan_reader = cpz.MessageReader.init(try copy_orphan_builder_message.segmentsConst(), .{});
    const copy_orphan_box = generated.DynamicBox.fromReader(try copy_orphan_reader.getRoot());
    try std.testing.expectEqualSlices(u8, "dynamic", try (try copy_orphan_box.any()).getText());
    try std.testing.expectEqualSlices(u8, "dynamic", try copy_orphan_box.anyAsText());

    var scalar_builder_message = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer scalar_builder_message.deinit();
    const scalar_box_builder = try generated.DynamicBox.initRootTyped(&scalar_builder_message);
    try scalar_box_builder.set_any_text("any text");
    try std.testing.expectEqualSlices(u8, "any text", try scalar_box_builder.get_anyAsText());
    try scalar_box_builder.set_any_data(&[_]u8{ 1, 2, 3 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, try scalar_box_builder.get_anyAsData());
    try scalar_box_builder.set_any_capability(12345);
    try std.testing.expectEqual(@as(u32, 12345), try scalar_box_builder.get_anyAsCapability());
    var scalar_reader = cpz.MessageReader.init(try scalar_builder_message.segmentsConst(), .{});
    const scalar_box = generated.DynamicBox.fromReader(try scalar_reader.getRoot());
    try std.testing.expectEqual(@as(u32, 12345), try scalar_box.anyAsCapability());

    var list_orphan = try scalar_box_builder.new_anyList_listOrphan(.two_bytes, 2);
    const orphan_list_builder = try list_orphan.getList(.two_bytes);
    try orphan_list_builder.setUInt16(0, 314);
    try orphan_list_builder.setUInt16(1, 159);
    try scalar_box_builder.adopt_anyList(&list_orphan);
    const adopted_any_list = try scalar_box_builder.get_anyList();
    try std.testing.expectEqual(@as(u16, 159), try adopted_any_list.getUInt16(1));

    var composite_list_message = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer composite_list_message.deinit();
    const composite_box_builder = try generated.DynamicBox.initRootTyped(&composite_list_message);
    const composite_any_list = try composite_box_builder.init_anyList_structList(1, .{ .data_words = 1, .pointer_count = 1 });
    const composite_item = try composite_any_list.getStructElement(0);
    try composite_item.setUInt32(0, 3210, 0);
    try composite_item.setText(0, "any list struct");
    var composite_reader = cpz.MessageReader.init(try composite_list_message.segmentsConst(), .{});
    const composite_box = generated.DynamicBox.fromReader(try composite_reader.getRoot());
    const read_composite_list = try composite_box.anyList();
    try std.testing.expectEqual(cpz.ElementSize.composite, read_composite_list.elementSize());
    const read_composite_item = try read_composite_list.getStructElement(0);
    try std.testing.expectEqual(@as(u32, 3210), read_composite_item.getUInt32(0, 0));
    try std.testing.expectEqualSlices(u8, "any list struct", try read_composite_item.getPointerField(0).getText());
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

test "generated scoped using aliases resolve for fields, consts, lists, and unions" {
    try std.testing.expectEqual(@as(u32, 77), generated.ScopedAliasBox.defaultLocalId);
    try std.testing.expectEqualSlices(u8, "aliases", generated.ScopedAliasBox.defaultLocalNames[1]);
    try std.testing.expectEqual(@as(u32, 4), generated.ScopedAliasBox.defaultLocalScores[1]);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const box_builder = try generated.ScopedAliasBox.initRootTyped(&builder);
    try std.testing.expectEqual(@as(u32, 21), try box_builder.get_id());
    try std.testing.expectEqualSlices(u8, "local", try box_builder.get_name());
    try box_builder.set_id(202);
    try box_builder.set_name("scoped");
    try box_builder.set_shade(.blue);
    const names = try box_builder.init_names(2);
    try names.set(0, "nested");
    try names.set(1, "alias");
    const friend = try box_builder.init_friend();
    try friend.set_id(404);
    try friend.set_name("friend");
    try box_builder.set_aliasId(909);
    try std.testing.expectEqual(generated.ScopedAliasBox.Union0.aliasId, (try box_builder.which()).?);
    try std.testing.expectEqual(@as(u32, 909), try box_builder.get_aliasId());
    try std.testing.expectError(error.InactiveUnionField, box_builder.get_aliasName());
    try box_builder.set_aliasName("union alias");
    try std.testing.expectEqual(generated.ScopedAliasBox.Union0.aliasName, (try box_builder.which()).?);
    try std.testing.expectError(error.InactiveUnionField, box_builder.get_aliasId());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const box = generated.ScopedAliasBox.fromReader(try reader.getRoot());
    try std.testing.expectEqual(@as(u32, 202), box.id());
    try std.testing.expectEqualSlices(u8, "scoped", try box.name());
    try std.testing.expectEqual(generated.Color.blue, try box.shade());
    const read_names = try box.names();
    try std.testing.expectEqualSlices(u8, "alias", try read_names.get(1));
    const read_friend = try box.friend();
    try std.testing.expectEqual(@as(u32, 404), read_friend.id());
    try std.testing.expectEqualSlices(u8, "friend", try read_friend.name());
    try std.testing.expectEqual(generated.ScopedAliasBox.Union0.aliasName, box.which().?);
    try std.testing.expectError(error.InactiveUnionField, box.aliasId());
    try std.testing.expectEqualSlices(u8, "union alias", try box.aliasName());
}

test "generated interface method constants compile" {
    try std.testing.expectEqual(@as(u16, 0), generated.Service.call);
    try std.testing.expectEqual(@as(u16, 1), generated.Service.ping);
    try std.testing.expectEqual(@as(u16, 0), generated.ExtendedService.pong);
    try std.testing.expectEqual(@as(u16, 0), generated.ExtendedService.Superclass0.call);
}

test "generated interface capability accessors round-trip" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const box_builder = try generated.InterfaceBox.initRootTyped(&builder);
    try box_builder.set_service(1234);
    const services = try box_builder.init_services(2);
    try services.set(0, 2345);
    try services.set(1, 3456);
    try std.testing.expectEqual(@as(u32, 1234), try box_builder.get_service());
    try std.testing.expectEqual(@as(u32, 3456), try services.get(1));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const box = generated.InterfaceBox.fromReader(try reader.getRoot());
    try std.testing.expect(box.has_service());
    try std.testing.expectEqual(@as(u32, 1234), try box.service());
    const read_services = try box.services();
    try std.testing.expectEqual(@as(u32, 2345), try read_services.get(0));
    try std.testing.expectEqual(@as(u32, 3456), try read_services.get(1));
}

test "generated nested declarations use qualified Zig names and local aliases" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const box_builder = try generated.NestedBox.initRootTyped(&builder);
    const item_builder = try box_builder.init_item();
    try item_builder.set_value(42);
    try item_builder.set_label("nested item");
    const items_builder = try box_builder.init_items(1);
    const list_item = try items_builder.get(0);
    try list_item.set_value(77);
    try list_item.set_label("nested list item");
    try box_builder.set_status(.ready);
    try std.testing.expectEqual(generated.NestedBox_Status.ready, try box_builder.get_status());

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const box = generated.NestedBox.fromReader(try reader.getRoot());
    const item = try box.item();
    try std.testing.expectEqual(@as(u32, 42), item.value());
    try std.testing.expectEqualSlices(u8, "nested item", try item.label());
    const items = try box.items();
    const read_item = try items.get(0);
    try std.testing.expectEqual(@as(u32, 77), read_item.value());
    try std.testing.expectEqualSlices(u8, "nested list item", try read_item.label());
    try std.testing.expectEqual(generated.NestedBox_Status.ready, try box.status());
}
