const std = @import("std");
const generated = @import("generated_method_defaults_schema");

test "generated method default flats expose typed scalar and enum getters" {
    try std.testing.expectEqual(@as(usize, 1), generated.Defaults.@"cpz.methodCount");
    try std.testing.expectEqual(@as(usize, 15), generated.Defaults.@"cpz.method.scalars.params.fieldCount");
    try std.testing.expectEqual(@as(usize, 1), generated.Defaults.@"cpz.method.scalars.results.fieldCount");

    var void_reader = generated.Defaults.@"cpz.method.scalars.params.field.v.defaultFlat".reader(.{});
    try generated.Defaults.@"cpz.method.scalars.params.field.v.defaultFlat".get(&void_reader);

    var bool_reader = generated.Defaults.@"cpz.method.scalars.params.field.b.defaultFlat".reader(.{});
    try std.testing.expectEqual(true, try generated.Defaults.@"cpz.method.scalars.params.field.b.defaultFlat".get(&bool_reader));

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

    var text_reader = generated.Defaults.@"cpz.method.scalars.params.field.text.defaultFlat".reader(.{});
    try std.testing.expectEqualStrings("hi", try generated.Defaults.@"cpz.method.scalars.params.field.text.defaultFlat".get(&text_reader));

    var data_reader = generated.Defaults.@"cpz.method.scalars.params.field.data.defaultFlat".reader(.{});
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2 }, try generated.Defaults.@"cpz.method.scalars.params.field.data.defaultFlat".get(&data_reader));

    var result_mode_reader = generated.Defaults.@"cpz.method.scalars.results.field.resultMode.defaultFlat".reader(.{});
    try std.testing.expectEqual(generated.Mode.off, try generated.Defaults.@"cpz.method.scalars.results.field.resultMode.defaultFlat".get(&result_mode_reader));
}
