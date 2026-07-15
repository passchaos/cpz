const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_method_defaults_schema");

test "generated optional constants expose values and flats" {
    try std.testing.expectEqualStrings("maybe local", generated.Defaults.defaultMaybeLabel.?);
    var label_reader = generated.Defaults.defaultMaybeLabelFlat.reader(.{});
    try std.testing.expectEqualStrings("maybe local", try generated.Defaults.defaultMaybeLabelFlat.get(&label_reader));

    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x0e, 0x0f }, generated.Defaults.defaultMaybePayload.?);
    var payload_reader = generated.Defaults.defaultMaybePayloadFlat.reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x0e, 0x0f }, try generated.Defaults.defaultMaybePayloadFlat.get(&payload_reader));

    try std.testing.expectEqualSlices(u16, &[_]u16{ 5, 6 }, generated.Defaults.defaultMaybeNumbers.?);
    var numbers_reader = generated.Defaults.defaultMaybeNumbersFlat.reader(.{});
    try std.testing.expectEqual(@as(u16, 5), try generated.Defaults.defaultMaybeNumbersFlat.get(&numbers_reader, 0));
    try std.testing.expectEqual(@as(u16, 6), try generated.Defaults.defaultMaybeNumbersFlat.get(&numbers_reader, 1));

    try std.testing.expectEqual(@as(usize, 2), generated.Defaults.defaultMaybeItem.fieldCount);
    var item_reader = generated.Defaults.defaultMaybeItem.reader(.{});
    const item = try generated.Defaults.defaultMaybeItem.typedRoot(&item_reader);
    try std.testing.expectEqual(@as(u32, 77), item.value());
    try std.testing.expectEqualStrings("seventy-seven", try item.label());

    try std.testing.expectEqual(@as(usize, 2), generated.Defaults.defaultMaybeItems.itemCount);
    var items_reader = generated.Defaults.defaultMaybeItems.reader(.{});
    const maybe_item0 = try generated.Defaults.defaultMaybeItems.get(&items_reader, 0);
    try std.testing.expectEqual(@as(u32, 30), maybe_item0.value());
    try std.testing.expectEqualStrings("thirty", try maybe_item0.label());
    const maybe_item1 = try generated.Defaults.defaultMaybeItems.get(&items_reader, 1);
    try std.testing.expectEqual(@as(u32, 40), maybe_item1.value());
    try std.testing.expectEqualStrings("forty", try maybe_item1.label());

    try std.testing.expectEqual(@as(?generated.Defaults.Item, null), generated.Defaults.defaultNothing);
    var nothing_reader = generated.Defaults.defaultNothingFlat.reader(.{});
    try std.testing.expect(try generated.Defaults.defaultNothingFlat.isNull(&nothing_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.Defaults.defaultNothingFlat.rawPointer(&nothing_reader));
}

test "generated struct optional null defaults expose flats" {
    try std.testing.expectEqualStrings("null", generated.MaybeDefaults.@"cpz.field.absent.default");
    var absent_reader = generated.MaybeDefaults.absentDefaultFlat.reader(.{});
    try std.testing.expect(try generated.MaybeDefaults.absentDefaultFlat.isNull(&absent_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.MaybeDefaults.absentDefaultFlat.rawPointer(&absent_reader));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.MaybeDefaults.absentDefaultFlat.pointerKind(&absent_reader));
    try std.testing.expect(generated.MaybeDefaults.absentDefaultFlat.matchesSegmentCount(1));
    try std.testing.expect(generated.MaybeDefaults.absentDefaultFlat.matchesSerializedSize(generated.MaybeDefaults.absentDefaultFlat.flatBytes.len));

    try std.testing.expectEqualStrings("null", generated.MaybeDefaults.@"cpz.field.absentData.default");
    var absent_data_reader = generated.MaybeDefaults.absentDataDefaultFlat.reader(.{});
    try std.testing.expect(try generated.MaybeDefaults.absentDataDefaultFlat.isNull(&absent_data_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.MaybeDefaults.absentDataDefaultFlat.rawPointer(&absent_data_reader));

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const root_builder = try generated.MaybeDefaults.initRootTyped(&builder);
    try std.testing.expectEqual(@as(?[]const u8, null), try root_builder.get_absentOrNull());
    try std.testing.expectEqual(@as(?[]const u8, null), try root_builder.get_absentDataOrNull());
    try root_builder.set_absentOrNull("present");
    if (try root_builder.get_absentOrNull()) |value| {
        try std.testing.expectEqualStrings("present", value);
    } else return error.TestExpectedEqual;
    try root_builder.set_absentDataOrNull(&[_]u8{ 0xaa, 0xbb });
    if (try root_builder.get_absentDataOrNull()) |value| {
        try std.testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0xbb }, value);
    } else return error.TestExpectedEqual;
    try root_builder.set_absentOrNull(null);
    try root_builder.set_absentDataOrNull(null);
    try std.testing.expectEqual(@as(?[]const u8, null), try root_builder.get_absentOrNull());
    try std.testing.expectEqual(@as(?[]const u8, null), try root_builder.get_absentDataOrNull());

    var message_reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root_reader = try generated.MaybeDefaults.getRoot(&message_reader);
    try std.testing.expectEqual(@as(?[]const u8, null), try root_reader.absentOrNull());
    try std.testing.expectEqual(@as(?[]const u8, null), try root_reader.absentDataOrNull());
}

test "generated struct pointer null defaults expose flats" {
    try std.testing.expectEqualStrings("null", generated.NullPointerDefaults.@"cpz.field.text.default");
    var text_reader = generated.NullPointerDefaults.textDefaultFlat.reader(.{});
    try std.testing.expect(try generated.NullPointerDefaults.textDefaultFlat.isNull(&text_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.NullPointerDefaults.textDefaultFlat.rawPointer(&text_reader));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.NullPointerDefaults.textDefaultFlat.pointerKind(&text_reader));

    try std.testing.expectEqualStrings("null", generated.NullPointerDefaults.@"cpz.field.data.default");
    var data_reader = generated.NullPointerDefaults.dataDefaultFlat.reader(.{});
    try std.testing.expect(try generated.NullPointerDefaults.dataDefaultFlat.isNull(&data_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.NullPointerDefaults.dataDefaultFlat.rawPointer(&data_reader));

    try std.testing.expectEqualStrings("null", generated.NullPointerDefaults.@"cpz.field.numbers.default");
    var numbers_reader = generated.NullPointerDefaults.numbersDefaultFlat.reader(.{});
    try std.testing.expect(try generated.NullPointerDefaults.numbersDefaultFlat.isNull(&numbers_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.NullPointerDefaults.numbersDefaultFlat.rawPointer(&numbers_reader));

    try std.testing.expectEqualStrings("null", generated.NullPointerDefaults.@"cpz.field.item.default");
    var item_reader = generated.NullPointerDefaults.itemDefaultFlat.reader(.{});
    try std.testing.expect(try generated.NullPointerDefaults.itemDefaultFlat.isNull(&item_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.NullPointerDefaults.itemDefaultFlat.rawPointer(&item_reader));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.NullPointerDefaults.itemDefaultFlat.pointerKind(&item_reader));

    try std.testing.expectEqualStrings("void", generated.NullPointerDefaults.@"cpz.field.cap.default");
    var cap_reader = generated.NullPointerDefaults.capDefaultFlat.reader(.{});
    try std.testing.expect(try generated.NullPointerDefaults.capDefaultFlat.isNull(&cap_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.NullPointerDefaults.capDefaultFlat.rawPointer(&cap_reader));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.NullPointerDefaults.capDefaultFlat.pointerKind(&cap_reader));

    try std.testing.expectEqualStrings("void", generated.NullPointerDefaults.@"cpz.field.callback.default");
    var callback_reader = generated.NullPointerDefaults.callbackDefaultFlat.reader(.{});
    try std.testing.expect(try generated.NullPointerDefaults.callbackDefaultFlat.isNull(&callback_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.NullPointerDefaults.callbackDefaultFlat.rawPointer(&callback_reader));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.NullPointerDefaults.callbackDefaultFlat.pointerKind(&callback_reader));

    try std.testing.expect(generated.NullPointerDefaults.textDefaultFlat.matchesSegmentCount(1));
    try std.testing.expect(generated.NullPointerDefaults.callbackDefaultFlat.matchesSerializedSize(generated.NullPointerDefaults.callbackDefaultFlat.flatBytes.len));

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const root_builder = try generated.NullPointerDefaults.initRootTyped(&builder);
    try std.testing.expectEqual(@as(?u32, null), try root_builder.get_capOrNull());
    try std.testing.expectEqual(@as(?u32, null), try root_builder.get_callbackOrNull());
    var root_reader_message = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root_reader = try generated.NullPointerDefaults.getRoot(&root_reader_message);
    try std.testing.expectEqual(@as(?u32, null), try root_reader.capOrNull());
    try std.testing.expectEqual(@as(?u32, null), try root_reader.callbackOrNull());
    try root_builder.set_cap(1234);
    try root_builder.set_callback(5678);
    try std.testing.expectEqual(@as(?u32, 1234), try root_builder.get_capOrNull());
    try std.testing.expectEqual(@as(?u32, 5678), try root_builder.get_callbackOrNull());
    try root_builder.set_capOrNull(null);
    try root_builder.set_callbackOrNull(null);
    try std.testing.expectEqual(@as(?u32, null), try root_builder.get_capOrNull());
    try std.testing.expectEqual(@as(?u32, null), try root_builder.get_callbackOrNull());
    try root_builder.set_capOrNull(4321);
    try root_builder.set_callbackOrNull(8765);
    try std.testing.expectEqual(@as(?u32, 4321), try root_builder.get_capOrNull());
    try std.testing.expectEqual(@as(?u32, 8765), try root_builder.get_callbackOrNull());
}

test "generated struct field defaults resolve const references" {
    var empty_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer empty_builder.deinit();
    _ = try generated.ConstRefDefaults.initRootTyped(&empty_builder);
    var empty_reader = cpz.MessageReader.init(try empty_builder.segmentsConst(), .{});
    const empty_root = try generated.ConstRefDefaults.getRoot(&empty_reader);
    try std.testing.expectEqualStrings("referenced text", try empty_root.text());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x12, 0x34 }, try empty_root.data());
    try std.testing.expectEqualStrings("local text", try empty_root.localTextField());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x56, 0x78 }, try empty_root.localDataField());
    try std.testing.expectEqual(true, empty_root.flag());
    try std.testing.expectEqual(@as(u32, 123), empty_root.amount());
    try std.testing.expectApproxEqAbs(@as(f64, 125.0), empty_root.ratio(), 0.0);
    try std.testing.expectEqual(generated.Mode.on, try empty_root.mode());
    try std.testing.expectEqual(false, empty_root.localFlagField());
    try std.testing.expectEqual(@as(u32, 456), empty_root.localAmountField());
    try std.testing.expectApproxEqAbs(@as(f64, -2.5), empty_root.localRatioField(), 0.0);
    try std.testing.expectEqual(generated.Mode.off, try empty_root.localModeField());

    var empty_builder_reader = cpz.MessageReader.init(try empty_builder.segmentsConst(), .{});
    const empty_root_builder = try generated.ConstRefDefaults.getRootTyped(&empty_builder);
    try std.testing.expectEqualStrings("referenced text", try empty_root_builder.get_text());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x12, 0x34 }, try empty_root_builder.get_data());
    try std.testing.expectEqualStrings("local text", try empty_root_builder.get_localTextField());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x56, 0x78 }, try empty_root_builder.get_localDataField());
    try std.testing.expectEqual(true, try empty_root_builder.get_flag());
    try std.testing.expectEqual(@as(u32, 123), try empty_root_builder.get_amount());
    try std.testing.expectApproxEqAbs(@as(f64, 125.0), try empty_root_builder.get_ratio(), 0.0);
    try std.testing.expectEqual(generated.Mode.on, try empty_root_builder.get_mode());
    try std.testing.expectEqual(false, try empty_root_builder.get_localFlagField());
    try std.testing.expectEqual(@as(u32, 456), try empty_root_builder.get_localAmountField());
    try std.testing.expectApproxEqAbs(@as(f64, -2.5), try empty_root_builder.get_localRatioField(), 0.0);
    try std.testing.expectEqual(generated.Mode.off, try empty_root_builder.get_localModeField());
    try std.testing.expect(!try empty_root_builder.has_numbers());
    const materialized_numbers_builder = try empty_root_builder.get_numbers();
    try std.testing.expectEqual(@as(usize, 2), materialized_numbers_builder.len());
    try std.testing.expectEqual(@as(u16, 7), try materialized_numbers_builder.get(0));
    try std.testing.expectEqual(@as(u16, 8), try materialized_numbers_builder.get(1));
    try std.testing.expect(try empty_root_builder.has_numbers());
    try std.testing.expect(!try empty_root_builder.has_localNumbersField());
    const materialized_local_numbers_builder = try empty_root_builder.get_localNumbersField();
    try std.testing.expectEqual(@as(u16, 9), try materialized_local_numbers_builder.get(0));
    try std.testing.expectEqual(@as(u16, 10), try materialized_local_numbers_builder.get(1));
    try std.testing.expect(try empty_root_builder.has_localNumbersField());
    try std.testing.expect(!try empty_root_builder.has_capList());
    const materialized_caps_builder = try empty_root_builder.get_capList();
    try std.testing.expectEqual(@as(usize, 2), materialized_caps_builder.len());
    try std.testing.expect(try materialized_caps_builder.elementIsNull(0));
    try std.testing.expect(try materialized_caps_builder.elementIsNull(1));
    try std.testing.expect(try empty_root_builder.has_capList());
    try std.testing.expect(!try empty_root_builder.has_callbackList());
    const materialized_callbacks_builder = try empty_root_builder.get_callbackList();
    try std.testing.expectEqual(@as(usize, 1), materialized_callbacks_builder.len());
    try std.testing.expect(try materialized_callbacks_builder.elementIsNull(0));
    try std.testing.expect(try empty_root_builder.has_callbackList());
    try std.testing.expect(!try empty_root_builder.has_any());
    const materialized_any_builder = try empty_root_builder.get_any();
    try std.testing.expectEqual(cpz.wire.PointerType.struct_ptr, materialized_any_builder.pointerType().?);
    const materialized_any_struct_builder = try empty_root_builder.get_anyAsStruct();
    try std.testing.expectEqual(@as(u32, 88), try materialized_any_struct_builder.getUInt32(0, 0));
    try std.testing.expect(try empty_root_builder.has_any());
    try std.testing.expect(!try empty_root_builder.has_anyStruct());
    const materialized_any_struct_field_builder = try empty_root_builder.get_anyStruct();
    try std.testing.expectEqual(@as(u32, 88), try materialized_any_struct_field_builder.getUInt32(0, 0));
    try std.testing.expect(try empty_root_builder.has_anyStruct());
    try std.testing.expect(!try empty_root_builder.has_anyList());
    const materialized_any_list_builder = try empty_root_builder.get_anyList();
    try std.testing.expectEqual(@as(usize, 2), materialized_any_list_builder.len());
    try std.testing.expectEqual(@as(u16, 7), try materialized_any_list_builder.getUInt16(0));
    try std.testing.expectEqual(@as(u16, 8), try materialized_any_list_builder.getUInt16(1));
    try std.testing.expect(try empty_root_builder.has_anyList());
    try std.testing.expect(!try empty_root_builder.has_item());
    const materialized_item_builder = try empty_root_builder.get_item();
    try std.testing.expectEqual(@as(u32, 88), try materialized_item_builder.get_value());
    try std.testing.expectEqualStrings("referenced item", try materialized_item_builder.get_label());
    try std.testing.expect(try empty_root_builder.has_item());
    const empty_root_as_reader = empty_root_builder.asReader(&empty_builder_reader);
    try std.testing.expectEqualStrings("local text", try empty_root_as_reader.localTextField());
    try std.testing.expectEqual(@as(u32, 456), empty_root_as_reader.localAmountField());
    const materialized_numbers_reader = try empty_root_as_reader.numbers();
    try std.testing.expectEqual(@as(u16, 7), materialized_numbers_reader.get(0));
    try std.testing.expectEqual(@as(u16, 8), materialized_numbers_reader.get(1));
    const materialized_item_reader = try empty_root_as_reader.item();
    try std.testing.expectEqual(@as(u32, 88), materialized_item_reader.value());
    try std.testing.expectEqualStrings("referenced item", try materialized_item_reader.label());

    var text_default_reader = generated.ConstRefDefaults.textDefaultFlat.reader(.{});
    try std.testing.expectEqualStrings("referenced text", try generated.ConstRefDefaults.textDefaultFlat.get(&text_default_reader));
    var data_default_reader = generated.ConstRefDefaults.dataDefaultFlat.reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x12, 0x34 }, try generated.ConstRefDefaults.dataDefaultFlat.get(&data_default_reader));
    var local_text_default_reader = generated.ConstRefDefaults.localTextFieldDefaultFlat.reader(.{});
    try std.testing.expectEqualStrings("local text", try generated.ConstRefDefaults.localTextFieldDefaultFlat.get(&local_text_default_reader));
    var local_data_default_reader = generated.ConstRefDefaults.localDataFieldDefaultFlat.reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x56, 0x78 }, try generated.ConstRefDefaults.localDataFieldDefaultFlat.get(&local_data_default_reader));
    var flag_default_reader = generated.ConstRefDefaults.flagDefaultFlat.reader(.{});
    try std.testing.expectEqual(true, try generated.ConstRefDefaults.flagDefaultFlat.get(&flag_default_reader));
    var amount_default_reader = generated.ConstRefDefaults.amountDefaultFlat.reader(.{});
    try std.testing.expectEqual(@as(u32, 123), try generated.ConstRefDefaults.amountDefaultFlat.get(&amount_default_reader));
    var ratio_default_reader = generated.ConstRefDefaults.ratioDefaultFlat.reader(.{});
    try std.testing.expectApproxEqAbs(@as(f64, 125.0), try generated.ConstRefDefaults.ratioDefaultFlat.get(&ratio_default_reader), 0.0);
    var mode_default_reader = generated.ConstRefDefaults.modeDefaultFlat.reader(.{});
    try std.testing.expectEqual(generated.Mode.on, try generated.ConstRefDefaults.modeDefaultFlat.get(&mode_default_reader));
    var local_flag_default_reader = generated.ConstRefDefaults.localFlagFieldDefaultFlat.reader(.{});
    try std.testing.expectEqual(false, try generated.ConstRefDefaults.localFlagFieldDefaultFlat.get(&local_flag_default_reader));
    var local_amount_default_reader = generated.ConstRefDefaults.localAmountFieldDefaultFlat.reader(.{});
    try std.testing.expectEqual(@as(u32, 456), try generated.ConstRefDefaults.localAmountFieldDefaultFlat.get(&local_amount_default_reader));
    var local_ratio_default_reader = generated.ConstRefDefaults.localRatioFieldDefaultFlat.reader(.{});
    try std.testing.expectApproxEqAbs(@as(f64, -2.5), try generated.ConstRefDefaults.localRatioFieldDefaultFlat.get(&local_ratio_default_reader), 0.0);
    var local_mode_default_reader = generated.ConstRefDefaults.localModeFieldDefaultFlat.reader(.{});
    try std.testing.expectEqual(generated.Mode.off, try generated.ConstRefDefaults.localModeFieldDefaultFlat.get(&local_mode_default_reader));
    var numbers_default_reader = generated.ConstRefDefaults.numbersDefaultFlat.reader(.{});
    try std.testing.expectEqual(@as(u16, 7), try generated.ConstRefDefaults.numbersDefaultFlat.get(&numbers_default_reader, 0));
    try std.testing.expectEqual(@as(u16, 8), try generated.ConstRefDefaults.numbersDefaultFlat.get(&numbers_default_reader, 1));
    var local_numbers_default_reader = generated.ConstRefDefaults.localNumbersFieldDefaultFlat.reader(.{});
    try std.testing.expectEqual(@as(u16, 9), try generated.ConstRefDefaults.localNumbersFieldDefaultFlat.get(&local_numbers_default_reader, 0));
    try std.testing.expectEqual(@as(u16, 10), try generated.ConstRefDefaults.localNumbersFieldDefaultFlat.get(&local_numbers_default_reader, 1));
    var item_default_reader = generated.ConstRefDefaults.itemDefaultFlat.reader(.{});
    const item_default = try generated.ConstRefDefaults.itemDefaultFlat.typedRoot(&item_default_reader);
    try std.testing.expectEqual(@as(u32, 88), item_default.value());
    try std.testing.expectEqualStrings("referenced item", try item_default.label());
    var any_default_reader = generated.ConstRefDefaults.anyDefaultFlat.reader(.{});
    try std.testing.expectEqual(cpz.wire.PointerType.struct_ptr, (try generated.ConstRefDefaults.anyDefaultFlat.pointerKind(&any_default_reader)).?);
    var any_struct_default_reader = generated.ConstRefDefaults.anyStructDefaultFlat.reader(.{});
    const any_struct_default = try generated.ConstRefDefaults.anyStructDefaultFlat.get(&any_struct_default_reader);
    try std.testing.expectEqual(@as(u32, 88), any_struct_default.getUInt32(0, 0));
    var any_list_default_reader = generated.ConstRefDefaults.anyListDefaultFlat.reader(.{});
    const any_list_default = try generated.ConstRefDefaults.anyListDefaultFlat.get(&any_list_default_reader, .two_bytes);
    try std.testing.expectEqual(@as(u16, 7), any_list_default.getUInt16(0));
    try std.testing.expectEqual(@as(u16, 8), any_list_default.getUInt16(1));
    var cap_list_default_reader = generated.ConstRefDefaults.capListDefaultFlat.reader(.{});
    const cap_list_default = try generated.ConstRefDefaults.capListDefaultFlat.list(&cap_list_default_reader);
    try std.testing.expectEqual(@as(usize, 2), cap_list_default.len());
    try std.testing.expect(try generated.ConstRefDefaults.capListDefaultFlat.elementIsNull(&cap_list_default_reader, 0));
    try std.testing.expect(try generated.ConstRefDefaults.capListDefaultFlat.elementIsNull(&cap_list_default_reader, 1));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.ConstRefDefaults.capListDefaultFlat.rawPointer(&cap_list_default_reader, 0));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.ConstRefDefaults.capListDefaultFlat.elementPointerKind(&cap_list_default_reader, 1));
    var callback_list_default_reader = generated.ConstRefDefaults.callbackListDefaultFlat.reader(.{});
    const callback_list_default = try generated.ConstRefDefaults.callbackListDefaultFlat.list(&callback_list_default_reader);
    try std.testing.expectEqual(@as(usize, 1), callback_list_default.len());
    try std.testing.expect(try generated.ConstRefDefaults.callbackListDefaultFlat.elementIsNull(&callback_list_default_reader, 0));
}

test "generated helpers avoid count field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    _ = try generated.CountFieldDefaults.initRootTyped(&builder);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.CountFieldDefaults.getRoot(&reader);
    try std.testing.expectEqual(@as(u32, 7), root.count());
    try std.testing.expectEqualStrings("counted", try root.label());
    try std.testing.expect(generated.CountFieldDefaults.labelDefaultFlat.matchesSegmentCount(1));
    try std.testing.expect(generated.CountFieldDefaults.labelDefaultFlat.matchesSerializedSize(generated.CountFieldDefaults.labelDefaultFlat.flatBytes.len));
    try std.testing.expectEqual(@as(usize, "counted".len), try root.labelByteCount());
    try std.testing.expect(try root.labelMatchesBytes("counted".len));
    try std.testing.expect(!try root.labelMatchesMaxCapabilityCount(0));
}

test "generated helpers avoid expected field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const builder_root = try generated.ExpectedFieldDefaults.initRootTyped(&builder);
    try builder_root.set_expected("expected");
    const items = try builder_root.init_items(2);
    try items.set(0, 1);
    try items.set(1, 2);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.ExpectedFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("expected", try root.expected());
    try std.testing.expectEqual(@as(usize, "expected".len), try root.expectedByteCount());
    try std.testing.expect(try root.expectedMatchesBytes("expected".len));
    try std.testing.expect(try root.expectedListMatchesLen(.byte, "expected".len + 1));
    try std.testing.expect(try root.itemsListMatchesLen(.two_bytes, 2));
    try std.testing.expect(try root.itemsListMatchesElementSize(.two_bytes, .two_bytes));
}

test "generated helpers avoid index field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const builder_root = try generated.IndexFieldDefaults.initRootTyped(&builder);
    const items = try builder_root.init_items(2);
    try items.set(0, "zero");
    try items.set(1, "one");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.IndexFieldDefaults.getRoot(&reader);
    try std.testing.expectEqual(@as(u32, 9), root.index());
    const read_items = try root.items();
    try std.testing.expect(read_items.hasIndex(1));
    try std.testing.expectEqualStrings("zero", try read_items.get(0));
    try std.testing.expectEqualStrings("one", try read_items.get(1));
    try std.testing.expect(try read_items.matchesBytes(0, "zero".len));
}

test "generated helpers avoid source field shadowing" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer source_builder.deinit();
    const source_root = try generated.SourceFieldDefaults.initRootTyped(&source_builder);
    const source_items = try source_root.init_items(2);
    try source_items.set(0, "alpha");
    try source_items.set(1, "beta");

    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_value = try generated.SourceFieldDefaults.getRoot(&source_reader);
    const source_list = try source_value.items();

    var target_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer target_builder.deinit();
    const target_root = try generated.SourceFieldDefaults.initRootTyped(&target_builder);
    const target_items = try target_root.init_items(2);
    try target_items.copyFrom(0, source_list, 0);
    try target_items.copyRangeFrom(1, source_list, 1, 1);
    try std.testing.expectEqualStrings("alpha", try target_items.get(0));
    try std.testing.expectEqualStrings("beta", try target_items.get(1));
}

test "generated helpers avoid start field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const root_builder = try generated.StartFieldDefaults.initRootTyped(&builder);
    try root_builder.set_start("start");
    const items_builder = try root_builder.init_items(3);
    try items_builder.set(0, 1);
    try items_builder.set(1, 2);
    try items_builder.set(2, 3);
    const builder_slice = try items_builder.slice(1, 2);
    try std.testing.expectEqual(@as(usize, 2), builder_slice.len());
    try items_builder.clearRange(1, 1);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.StartFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("start", try root.start());
    const items = try root.items();
    const slice = try items.slice(1, 2);
    try std.testing.expectEqual(@as(usize, 2), slice.len());
}

test "generated helpers avoid builder field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const root_builder = try generated.BuilderFieldDefaults.initRootTyped(&builder);
    try root_builder.set_builder("builder");
    const items_builder = try root_builder.init_items(1);
    try items_builder.set(0, "build");

    var list_orphan = try generated.BuilderFieldDefaults.BuilderFieldDefaults_items_Orphan.newOrphan(&builder, 1);
    defer list_orphan.release();
    try std.testing.expect(list_orphan.matchesLen(1));

    var copied_orphan = try generated.BuilderFieldDefaults.BuilderFieldDefaults_items_Orphan.newOrphanCopyFromBuilder(&builder, items_builder);
    defer copied_orphan.release();
    const copied = try copied_orphan.get();
    try std.testing.expectEqualStrings("build", try copied.get(0));
}

test "generated helpers avoid options field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const root_builder = try generated.OptionsFieldDefaults.initRootTyped(&builder);
    try root_builder.set_options("options");
    _ = try root_builder.init_item();

    try std.testing.expect((try root_builder.validateWithOptions(.{})).hasStructs());
    try std.testing.expect((try root_builder.get_itemStatsWithOptions(.{})).hasStructs());
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.OptionsFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("options", try root.options());
    try std.testing.expect((try root.validateWithOptions(.{})).hasStructs());
    try std.testing.expect((try root.itemStatsWithOptions(.{})).hasStructs());
}

test "generated helpers avoid location field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const root_builder = try generated.LocationFieldDefaults.initRootTyped(&builder);
    try root_builder.set_segment_id("segment");
    try root_builder.set_word_index("word");
    _ = try root_builder.init_item();

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.LocationFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("segment", try root.segment_id());
    try std.testing.expectEqualStrings("word", try root.word_index());
    const segment_id = try root.itemPointerSegmentId();
    const word_index = try root.itemPointerWordIndex();
    try std.testing.expect(try root.itemPointerMatchesLocation(segment_id, word_index));
    try std.testing.expect(try root_builder.get_itemPointerMatchesLocation(segment_id, word_index));
}

test "generated helpers avoid element_size field shadowing" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const root_builder = try generated.ElementSizeFieldDefaults.initRootTyped(&builder);
    try root_builder.set_element_size("element");
    _ = try root_builder.init_any_list(.two_bytes, 2);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.ElementSizeFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("element", try root.element_size());
    try std.testing.expect(try root.anyListMatchesElementSize(.two_bytes, .two_bytes));
    _ = try root_builder.init_any_list(.byte, 1);
    var list_orphan = try root_builder.new_any_listOrphan(.byte, 1);
    defer list_orphan.release();
}

test "generated reader field name is sanitized" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const root_builder = try generated.ReaderFieldDefaults.initRootTyped(&builder);
    try root_builder.set_reader_("reader");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.ReaderFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("reader", try root.reader_());
}

test "generated size field name is sanitized" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const root_builder = try generated.SizeFieldDefaults.initRootTyped(&builder);
    try std.testing.expectEqual(@as(u32, 64), try root_builder.get_size_());
    try root_builder.set_size_(128);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.SizeFieldDefaults.getRoot(&reader);
    try std.testing.expectEqual(@as(u32, 128), root.size_());
    try std.testing.expectEqual(@as(u16, 1), generated.SizeFieldDefaults.size.data_words);
}

test "generated new_value field name is sanitized" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 2 });
    defer builder.deinit();
    const root_builder = try generated.NewValueFieldDefaults.initRootTyped(&builder);
    try root_builder.set_new_value_("new");
    const items = try root_builder.init_items(1);
    try items.set(0, "value");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.NewValueFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("new", try root.new_value_());
    const read_items = try root.items();
    try std.testing.expectEqualStrings("value", try read_items.get(0));
}

test "generated orphan field name is sanitized" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const root_builder = try generated.OrphanFieldDefaults.initRootTyped(&builder);
    try root_builder.set_orphan_("orphan");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.OrphanFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("orphan", try root.orphan_());
}

test "generated member field names are sanitized" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();
    const root_builder = try generated.GeneratedMemberFieldDefaults.initRootTyped(&builder);
    try root_builder.set_validate_("validate");
    try root_builder.set_totalSize_("total");
    try root_builder.set_Orphan_("orphan-type");
    try root_builder.set_Builder_("builder-type");
    try root_builder.set_fromReader_("from-reader");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const root = try generated.GeneratedMemberFieldDefaults.getRoot(&reader);
    try std.testing.expectEqualStrings("validate", try root.validate_());
    try std.testing.expectEqualStrings("total", try root.totalSize_());
    try std.testing.expectEqualStrings("orphan-type", try root.Orphan_());
    try std.testing.expectEqualStrings("builder-type", try root.Builder_());
    try std.testing.expectEqualStrings("from-reader", try root.fromReader_());
}

test "generated method default flats expose typed scalar and enum getters" {
    try std.testing.expectEqual(@as(usize, 8), generated.Defaults.@"cpz.methodCount");
    try std.testing.expectEqual(@as(usize, 15), generated.Defaults.@"cpz.method.scalars.params.fieldCount");
    try std.testing.expectEqual(@as(usize, 1), generated.Defaults.@"cpz.method.scalars.results.fieldCount");

    var void_reader = generated.Defaults.@"cpz.method.scalars.params.field.v.defaultFlat".reader(.{});
    try generated.Defaults.@"cpz.method.scalars.params.field.v.defaultFlat".get(&void_reader);

    var bool_reader = generated.Defaults.@"cpz.method.scalars.params.field.b.defaultFlat".reader(.{});
    try std.testing.expectEqual(true, try generated.Defaults.@"cpz.method.scalars.params.field.b.defaultFlat".get(&bool_reader));
    var bool_wrapped = generated.Defaults.@"cpz.method.scalars.params.field.b.defaultFlat".init(.{});
    try std.testing.expectEqual(true, try bool_wrapped.get());
    try std.testing.expect((try bool_wrapped.totalSize()).hasWords());

    var int8_reader = generated.Defaults.@"cpz.method.scalars.params.field.i8_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(i8, -8), try generated.Defaults.@"cpz.method.scalars.params.field.i8_.defaultFlat".get(&int8_reader));

    var int16_reader = generated.Defaults.@"cpz.method.scalars.params.field.i16_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(i16, -16), try generated.Defaults.@"cpz.method.scalars.params.field.i16_.defaultFlat".get(&int16_reader));

    var int32_reader = generated.Defaults.@"cpz.method.scalars.params.field.i32_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(i32, -32), try generated.Defaults.@"cpz.method.scalars.params.field.i32_.defaultFlat".get(&int32_reader));

    var int64_reader = generated.Defaults.@"cpz.method.scalars.params.field.i64_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(i64, -64), try generated.Defaults.@"cpz.method.scalars.params.field.i64_.defaultFlat".get(&int64_reader));

    var uint8_reader = generated.Defaults.@"cpz.method.scalars.params.field.u8_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u8, 8), try generated.Defaults.@"cpz.method.scalars.params.field.u8_.defaultFlat".get(&uint8_reader));

    var uint16_reader = generated.Defaults.@"cpz.method.scalars.params.field.u16_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u16, 16), try generated.Defaults.@"cpz.method.scalars.params.field.u16_.defaultFlat".get(&uint16_reader));

    var uint32_reader = generated.Defaults.@"cpz.method.scalars.params.field.u32_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u32, 32), try generated.Defaults.@"cpz.method.scalars.params.field.u32_.defaultFlat".get(&uint32_reader));

    var uint64_reader = generated.Defaults.@"cpz.method.scalars.params.field.u64_.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u64, 64), try generated.Defaults.@"cpz.method.scalars.params.field.u64_.defaultFlat".get(&uint64_reader));

    var float32_reader = generated.Defaults.@"cpz.method.scalars.params.field.f32_.defaultFlat".reader(.{});
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), try generated.Defaults.@"cpz.method.scalars.params.field.f32_.defaultFlat".get(&float32_reader), 0.0);

    var float64_reader = generated.Defaults.@"cpz.method.scalars.params.field.f64_.defaultFlat".reader(.{});
    try std.testing.expectApproxEqAbs(@as(f64, -2.25), try generated.Defaults.@"cpz.method.scalars.params.field.f64_.defaultFlat".get(&float64_reader), 0.0);

    var mode_reader = generated.Defaults.@"cpz.method.scalars.params.field.mode.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u16, 1), try generated.Defaults.@"cpz.method.scalars.params.field.mode.defaultFlat".getRaw(&mode_reader));
    var mode_reader_typed = generated.Defaults.@"cpz.method.scalars.params.field.mode.defaultFlat".reader(.{});
    try std.testing.expectEqual(generated.Mode.on, try generated.Defaults.@"cpz.method.scalars.params.field.mode.defaultFlat".get(&mode_reader_typed));
    var mode_wrapped = generated.Defaults.@"cpz.method.scalars.params.field.mode.defaultFlat".init(.{});
    try std.testing.expectEqual(@as(u16, 1), try mode_wrapped.getRaw());
    try std.testing.expectEqual(generated.Mode.on, try mode_wrapped.get());

    var text_reader = generated.Defaults.@"cpz.method.scalars.params.field.text.defaultFlat".reader(.{});
    try std.testing.expectEqualStrings("hi", try generated.Defaults.@"cpz.method.scalars.params.field.text.defaultFlat".get(&text_reader));
    var text_wrapped = generated.Defaults.@"cpz.method.scalars.params.field.text.defaultFlat".init(.{});
    try std.testing.expectEqualStrings("hi", try text_wrapped.get());
    try std.testing.expectEqual(@as(usize, 2), try text_wrapped.getByteCount());

    var data_reader = generated.Defaults.@"cpz.method.scalars.params.field.data.defaultFlat".reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2 }, try generated.Defaults.@"cpz.method.scalars.params.field.data.defaultFlat".get(&data_reader));

    var result_mode_reader = generated.Defaults.@"cpz.method.scalars.results.field.resultMode.defaultFlat".reader(.{});
    try std.testing.expectEqual(generated.Mode.off, try generated.Defaults.@"cpz.method.scalars.results.field.resultMode.defaultFlat".get(&result_mode_reader));
}

test "generated method default flats resolve interface scoped aliases and const references" {
    try std.testing.expectEqualStrings("scoped", generated.Defaults.@"cpz.methodByName"("scoped").?.name);
    try std.testing.expectEqualStrings("Defaults.LocalMode", generated.Defaults.@"cpz.method.scoped.params.field.mode.resolvedType");
    try std.testing.expectEqualStrings("defaultLocalMode", generated.Defaults.@"cpz.method.scoped.params.field.mode.default".?);

    var mode_reader = generated.Defaults.@"cpz.method.scoped.params.field.mode.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u16, 1), try generated.Defaults.@"cpz.method.scoped.params.field.mode.defaultFlat".getRaw(&mode_reader));
    var mode_reader_typed = generated.Defaults.@"cpz.method.scoped.params.field.mode.defaultFlat".reader(.{});
    try std.testing.expectEqual(generated.Defaults.LocalMode.running, try generated.Defaults.@"cpz.method.scoped.params.field.mode.defaultFlat".get(&mode_reader_typed));
    var scoped_mode_wrapped = generated.Defaults.@"cpz.method.scoped.params.field.mode.defaultFlat".init(.{});
    try std.testing.expectEqual(generated.Defaults.LocalMode.running, try scoped_mode_wrapped.get());

    var label_reader = generated.Defaults.@"cpz.method.scoped.params.field.label.defaultFlat".reader(.{});
    try std.testing.expectEqualStrings("local", try generated.Defaults.@"cpz.method.scoped.params.field.label.defaultFlat".get(&label_reader));

    var payload_reader = generated.Defaults.@"cpz.method.scoped.params.field.payload.defaultFlat".reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x0a, 0x0b }, try generated.Defaults.@"cpz.method.scoped.params.field.payload.defaultFlat".get(&payload_reader));

    var result_mode_reader = generated.Defaults.@"cpz.method.scoped.results.field.resultMode.defaultFlat".reader(.{});
    try std.testing.expectEqual(generated.Defaults.LocalMode.running, try generated.Defaults.@"cpz.method.scoped.results.field.resultMode.defaultFlat".get(&result_mode_reader));
}

test "generated method default flats expose typed list getters" {
    try std.testing.expectEqualStrings("lists", generated.Defaults.@"cpz.methodByName"("lists").?.name);
    try std.testing.expectEqual(@as(usize, 6), generated.Defaults.@"cpz.method.lists.params.fieldCount");

    var numbers_reader = generated.Defaults.@"cpz.method.lists.params.field.numbers.defaultFlat".reader(.{});
    const numbers = try generated.Defaults.@"cpz.method.lists.params.field.numbers.defaultFlat".list(&numbers_reader);
    try std.testing.expectEqual(@as(usize, 2), numbers.len());
    try std.testing.expectEqual(@as(u16, 7), try generated.Defaults.@"cpz.method.lists.params.field.numbers.defaultFlat".get(&numbers_reader, 0));
    try std.testing.expectEqual(@as(u16, 8), try generated.Defaults.@"cpz.method.lists.params.field.numbers.defaultFlat".get(&numbers_reader, 1));
    var numbers_wrapped = generated.Defaults.@"cpz.method.lists.params.field.numbers.defaultFlat".init(.{});
    const wrapped_numbers = try numbers_wrapped.list();
    try std.testing.expectEqual(@as(usize, 2), wrapped_numbers.len());
    try std.testing.expectEqual(@as(u16, 8), try numbers_wrapped.get(1));

    var labels_reader = generated.Defaults.@"cpz.method.lists.params.field.labels.defaultFlat".reader(.{});
    try std.testing.expectEqualStrings("alpha", try generated.Defaults.@"cpz.method.lists.params.field.labels.defaultFlat".get(&labels_reader, 0));
    try std.testing.expectEqualStrings("beta", try generated.Defaults.@"cpz.method.lists.params.field.labels.defaultFlat".get(&labels_reader, 1));

    var payloads_reader = generated.Defaults.@"cpz.method.lists.params.field.payloads.defaultFlat".reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x0c, 0x0d }, try generated.Defaults.@"cpz.method.lists.params.field.payloads.defaultFlat".get(&payloads_reader, 0));
    try std.testing.expectEqualStrings("raw", try generated.Defaults.@"cpz.method.lists.params.field.payloads.defaultFlat".get(&payloads_reader, 1));

    var modes_reader = generated.Defaults.@"cpz.method.lists.params.field.modes.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u16, 0), try generated.Defaults.@"cpz.method.lists.params.field.modes.defaultFlat".getRaw(&modes_reader, 0));
    try std.testing.expectEqual(generated.Defaults.LocalMode.running, try generated.Defaults.@"cpz.method.lists.params.field.modes.defaultFlat".get(&modes_reader, 1));

    var groups_reader = generated.Defaults.@"cpz.method.lists.params.field.groups.defaultFlat".reader(.{});
    const group0 = try generated.Defaults.@"cpz.method.lists.params.field.groups.defaultFlat".get(&groups_reader, 0, .two_bytes);
    try std.testing.expectEqual(@as(usize, 2), group0.len());
    try std.testing.expectEqual(@as(u16, 1), group0.getUInt16(0));
    const group1 = try generated.Defaults.@"cpz.method.lists.params.field.groups.defaultFlat".get(&groups_reader, 1, .two_bytes);
    try std.testing.expectEqual(@as(usize, 1), group1.len());
    try std.testing.expectEqual(@as(u16, 3), group1.getUInt16(0));
    var groups_wrapped = generated.Defaults.@"cpz.method.lists.params.field.groups.defaultFlat".init(.{});
    const wrapped_group0 = try groups_wrapped.get(0, .two_bytes);
    try std.testing.expectEqual(@as(u16, 2), wrapped_group0.getUInt16(1));

    var items_reader = generated.Defaults.@"cpz.method.lists.params.field.items.defaultFlat".reader(.{});
    const item0 = try generated.Defaults.@"cpz.method.lists.params.field.items.defaultFlat".get(&items_reader, 0);
    try std.testing.expectEqual(@as(u32, 10), item0.value());
    try std.testing.expectEqualStrings("ten", try item0.label());
    const item1 = try generated.Defaults.@"cpz.method.lists.params.field.items.defaultFlat".get(&items_reader, 1);
    try std.testing.expectEqual(@as(u32, 20), item1.value());
    try std.testing.expectEqualStrings("twenty", try item1.label());
}

test "generated method default flats expose typed struct getters" {
    try std.testing.expectEqualStrings("structs", generated.Defaults.@"cpz.methodByName"("structs").?.name);

    var item_reader = generated.Defaults.@"cpz.method.structs.params.field.item.defaultFlat".reader(.{});
    const item = try generated.Defaults.@"cpz.method.structs.params.field.item.defaultFlat".get(&item_reader);
    try std.testing.expectEqual(@as(u32, 99), item.value());
    try std.testing.expectEqualStrings("ninety-nine", try item.label());
    var item_wrapped = generated.Defaults.@"cpz.method.structs.params.field.item.defaultFlat".init(.{});
    const wrapped_item = try item_wrapped.get();
    try std.testing.expectEqual(@as(u32, 99), wrapped_item.value());
    try std.testing.expect((try item_wrapped.validate()).hasStructs());

    var result_reader = generated.Defaults.@"cpz.method.structs.results.field.result.defaultFlat".reader(.{});
    const result = try generated.Defaults.@"cpz.method.structs.results.field.result.defaultFlat".get(&result_reader);
    try std.testing.expectEqual(@as(u32, 123), result.value());
    try std.testing.expectEqualStrings("result", try result.label());
}

test "generated method default flats expose typed optional pointer getters" {
    try std.testing.expectEqualStrings("optionals", generated.Defaults.@"cpz.methodByName"("optionals").?.name);

    var label_reader = generated.Defaults.@"cpz.method.optionals.params.field.label.defaultFlat".reader(.{});
    try std.testing.expectEqualStrings("maybe local", try generated.Defaults.@"cpz.method.optionals.params.field.label.defaultFlat".get(&label_reader));
    var label_wrapped = generated.Defaults.@"cpz.method.optionals.params.field.label.defaultFlat".init(.{});
    try std.testing.expectEqualStrings("maybe local", try label_wrapped.get());

    var payload_reader = generated.Defaults.@"cpz.method.optionals.params.field.payload.defaultFlat".reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x0e, 0x0f }, try generated.Defaults.@"cpz.method.optionals.params.field.payload.defaultFlat".get(&payload_reader));

    var numbers_reader = generated.Defaults.@"cpz.method.optionals.params.field.numbers.defaultFlat".reader(.{});
    try std.testing.expectEqual(@as(u16, 5), try generated.Defaults.@"cpz.method.optionals.params.field.numbers.defaultFlat".get(&numbers_reader, 0));
    try std.testing.expectEqual(@as(u16, 6), try generated.Defaults.@"cpz.method.optionals.params.field.numbers.defaultFlat".get(&numbers_reader, 1));
    var optional_numbers_wrapped = generated.Defaults.@"cpz.method.optionals.params.field.numbers.defaultFlat".init(.{});
    try std.testing.expectEqual(@as(u16, 6), try optional_numbers_wrapped.get(1));

    var item_reader = generated.Defaults.@"cpz.method.optionals.params.field.item.defaultFlat".reader(.{});
    const item = try generated.Defaults.@"cpz.method.optionals.params.field.item.defaultFlat".get(&item_reader);
    try std.testing.expectEqual(@as(u32, 77), item.value());
    try std.testing.expectEqualStrings("seventy-seven", try item.label());

    var empty_label_reader = generated.Defaults.@"cpz.method.optionals.params.field.emptyLabel.defaultFlat".reader(.{});
    try std.testing.expect(try generated.Defaults.@"cpz.method.optionals.params.field.emptyLabel.defaultFlat".isNull(&empty_label_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.Defaults.@"cpz.method.optionals.params.field.emptyLabel.defaultFlat".rawPointer(&empty_label_reader));
    var empty_label_wrapped = generated.Defaults.@"cpz.method.optionals.params.field.emptyLabel.defaultFlat".init(.{});
    try std.testing.expect(try empty_label_wrapped.isNull());

    var any_reader = generated.Defaults.@"cpz.method.optionals.params.field.any.defaultFlat".reader(.{});
    try std.testing.expect(try generated.Defaults.@"cpz.method.optionals.params.field.any.defaultFlat".isNull(&any_reader));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.Defaults.@"cpz.method.optionals.params.field.any.defaultFlat".pointerKind(&any_reader));

    var cap_reader = generated.Defaults.@"cpz.method.optionals.params.field.cap.defaultFlat".reader(.{});
    try std.testing.expect(try generated.Defaults.@"cpz.method.optionals.params.field.cap.defaultFlat".isNull(&cap_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.Defaults.@"cpz.method.optionals.params.field.cap.defaultFlat".rawPointer(&cap_reader));

    var result_reader = generated.Defaults.@"cpz.method.optionals.results.field.result.defaultFlat".reader(.{});
    const result = try generated.Defaults.@"cpz.method.optionals.results.field.result.defaultFlat".get(&result_reader);
    try std.testing.expectEqual(@as(u32, 77), result.value());
    try std.testing.expectEqualStrings("seventy-seven", try result.label());
}

test "generated method default flats resolve any pointer const references" {
    try std.testing.expectEqualStrings("anyDefaults", generated.Defaults.@"cpz.methodByName"("anyDefaults").?.name);

    var any_struct_reader = generated.Defaults.@"cpz.method.anyDefaults.params.field.anyStruct.defaultFlat".reader(.{});
    const any_struct = try generated.Defaults.@"cpz.method.anyDefaults.params.field.anyStruct.defaultFlat".asStruct(&any_struct_reader);
    try std.testing.expectEqual(@as(u32, 99), any_struct.getUInt32(0, 0));
    var any_struct_wrapped = generated.Defaults.@"cpz.method.anyDefaults.params.field.anyStruct.defaultFlat".init(.{});
    const wrapped_any_struct = try any_struct_wrapped.asStruct();
    try std.testing.expectEqual(@as(u32, 99), wrapped_any_struct.getUInt32(0, 0));

    var struct_value_reader = generated.Defaults.@"cpz.method.anyDefaults.params.field.structValue.defaultFlat".reader(.{});
    const struct_value = try generated.Defaults.@"cpz.method.anyDefaults.params.field.structValue.defaultFlat".get(&struct_value_reader);
    try std.testing.expectEqual(@as(u32, 99), struct_value.getUInt32(0, 0));

    var any_list_reader = generated.Defaults.@"cpz.method.anyDefaults.params.field.anyList.defaultFlat".reader(.{});
    const any_list = try generated.Defaults.@"cpz.method.anyDefaults.params.field.anyList.defaultFlat".asList(&any_list_reader, .two_bytes);
    try std.testing.expectEqual(@as(u16, 7), any_list.getUInt16(0));

    var list_value_reader = generated.Defaults.@"cpz.method.anyDefaults.params.field.listValue.defaultFlat".reader(.{});
    const list_value = try generated.Defaults.@"cpz.method.anyDefaults.params.field.listValue.defaultFlat".get(&list_value_reader, .two_bytes);
    try std.testing.expectEqual(@as(u16, 8), list_value.getUInt16(1));
}

test "generated method default flats expose named capability null defaults" {
    try std.testing.expectEqualStrings("capabilityDefaults", generated.Defaults.@"cpz.methodByName"("capabilityDefaults").?.name);

    var callback_reader = generated.Defaults.@"cpz.method.capabilityDefaults.params.field.callback.defaultFlat".reader(.{});
    try std.testing.expect(try generated.Defaults.@"cpz.method.capabilityDefaults.params.field.callback.defaultFlat".isNull(&callback_reader));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.Defaults.@"cpz.method.capabilityDefaults.params.field.callback.defaultFlat".rawPointer(&callback_reader));

    var callback_wrapped = generated.Defaults.@"cpz.method.capabilityDefaults.params.field.callback.defaultFlat".init(.{});
    try std.testing.expect(try callback_wrapped.isNull());
}

test "generated method default flats expose capability list defaults" {
    try std.testing.expectEqualStrings("capabilityLists", generated.Defaults.@"cpz.methodByName"("capabilityLists").?.name);

    var caps_reader = generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".reader(.{});
    const caps = try generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".list(&caps_reader);
    try std.testing.expectEqual(@as(usize, 2), caps.len());
    try std.testing.expect(try generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".elementIsNull(&caps_reader, 0));
    try std.testing.expect(try generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".elementIsNull(&caps_reader, 1));
    try std.testing.expectEqual(@as(cpz.Word, 0), try generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".rawPointer(&caps_reader, 0));
    try std.testing.expectEqual(@as(?cpz.wire.PointerType, null), try generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".elementPointerKind(&caps_reader, 1));
    var caps_wrapped = generated.Defaults.@"cpz.method.capabilityLists.params.field.caps.defaultFlat".init(.{});
    try std.testing.expect(try caps_wrapped.elementIsNull(0));
    try std.testing.expectEqual(@as(cpz.Word, 0), try caps_wrapped.rawPointer(1));

    var callbacks_reader = generated.Defaults.@"cpz.method.capabilityLists.params.field.callbacks.defaultFlat".reader(.{});
    const callbacks = try generated.Defaults.@"cpz.method.capabilityLists.params.field.callbacks.defaultFlat".list(&callbacks_reader);
    try std.testing.expectEqual(@as(usize, 1), callbacks.len());
    try std.testing.expect(try generated.Defaults.@"cpz.method.capabilityLists.params.field.callbacks.defaultFlat".elementIsNull(&callbacks_reader, 0));
    var callbacks_wrapped = generated.Defaults.@"cpz.method.capabilityLists.params.field.callbacks.defaultFlat".init(.{});
    try std.testing.expect(try callbacks_wrapped.elementIsNull(0));
}
