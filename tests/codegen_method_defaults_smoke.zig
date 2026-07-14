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

test "generated method default flats expose typed scalar and enum getters" {
    try std.testing.expectEqual(@as(usize, 6), generated.Defaults.@"cpz.methodCount");
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
