const std = @import("std");
const generated = @import("generated_scalar_const_lists_schema");

test "generated scalar list constants expose flat containers" {
    try std.testing.expectEqual(@as(usize, 12), generated.@"cpz.constCount");
    try std.testing.expectEqual(@as(usize, 12), generated.@"cpz.consts".len);

    try std.testing.expectEqual(@as(usize, 3), generated.voids.len);
    try std.testing.expect(generated.voidsFlat.flatBytes.len > 0);
    var voids_reader = generated.voidsFlat.reader(.{});
    const voids_flat = try generated.voidsFlat.list(&voids_reader);
    try std.testing.expectEqual(@as(usize, 3), voids_flat.len());
    try std.testing.expectEqual(.void, voids_flat.elementSize());
    const voids_stats = try generated.voidsFlat.validate(.{});
    try std.testing.expect(voids_stats.hasLists());

    try std.testing.expectEqualSlices(bool, &[_]bool{ true, false, true, true, false, false, true, false, true }, generated.flags);
    try std.testing.expect(generated.flagsFlat.flatBytes.len > 0);
    var flags_reader = generated.flagsFlat.reader(.{});
    const flags_flat = try generated.flagsFlat.list(&flags_reader);
    try std.testing.expectEqual(@as(usize, 9), flags_flat.len());
    try std.testing.expectEqual(true, flags_flat.getBool(0));
    try std.testing.expectEqual(false, flags_flat.getBool(1));
    try std.testing.expectEqual(true, flags_flat.getBool(8));
    const flags_stats = try generated.flagsFlat.validate(.{});
    try std.testing.expect(flags_stats.total_words > 0);

    try std.testing.expectEqualSlices(i8, &[_]i8{ -128, -1, 0, 127 }, generated.int8s);
    var int8s_reader = generated.int8sFlat.reader(.{});
    const int8s_flat = try generated.int8sFlat.list(&int8s_reader);
    try std.testing.expectEqual(@as(i8, -128), int8s_flat.getInt8(0));
    try std.testing.expectEqual(@as(i8, -1), int8s_flat.getInt8(1));
    try std.testing.expectEqual(@as(i8, 127), int8s_flat.getInt8(3));
    const int8s_stats = try generated.int8sFlat.validate(.{});
    try std.testing.expect(int8s_stats.total_words > 0);

    try std.testing.expectEqualSlices(i16, &[_]i16{ -1234, 0, 5678 }, generated.int16s);
    var int16s_reader = generated.int16sFlat.reader(.{});
    const int16s_flat = try generated.int16sFlat.list(&int16s_reader);
    try std.testing.expectEqual(@as(i16, -1234), int16s_flat.getInt16(0));
    try std.testing.expectEqual(@as(i16, 5678), int16s_flat.getInt16(2));
    const int16s_stats = try generated.int16sFlat.validate(.{});
    try std.testing.expect(int16s_stats.total_words > 0);

    try std.testing.expectEqualSlices(i32, &[_]i32{ -100000, 0, 200000 }, generated.int32s);
    var int32s_reader = generated.int32sFlat.reader(.{});
    const int32s_flat = try generated.int32sFlat.list(&int32s_reader);
    try std.testing.expectEqual(@as(i32, -100000), int32s_flat.getInt32(0));
    try std.testing.expectEqual(@as(i32, 200000), int32s_flat.getInt32(2));
    const int32s_stats = try generated.int32sFlat.validate(.{});
    try std.testing.expect(int32s_stats.total_words > 0);

    try std.testing.expectEqualSlices(i64, &[_]i64{ -9000000000, 0, 9000000000 }, generated.int64s);
    var int64s_reader = generated.int64sFlat.reader(.{});
    const int64s_flat = try generated.int64sFlat.list(&int64s_reader);
    try std.testing.expectEqual(@as(i64, -9000000000), int64s_flat.getInt64(0));
    try std.testing.expectEqual(@as(i64, 9000000000), int64s_flat.getInt64(2));
    const int64s_stats = try generated.int64sFlat.validate(.{});
    try std.testing.expect(int64s_stats.total_words > 0);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 0, 42, 255 }, generated.uint8s);
    var uint8s_reader = generated.uint8sFlat.reader(.{});
    const uint8s_flat = try generated.uint8sFlat.list(&uint8s_reader);
    try std.testing.expectEqual(@as(u8, 0), uint8s_flat.getUInt8(0));
    try std.testing.expectEqual(@as(u8, 255), uint8s_flat.getUInt8(2));
    const uint8s_stats = try generated.uint8sFlat.validate(.{});
    try std.testing.expect(uint8s_stats.total_words > 0);

    try std.testing.expectEqualSlices(u16, &[_]u16{ 1, 65535 }, generated.uint16s);
    var uint16s_reader = generated.uint16sFlat.reader(.{});
    const uint16s_flat = try generated.uint16sFlat.list(&uint16s_reader);
    try std.testing.expectEqual(@as(u16, 1), uint16s_flat.getUInt16(0));
    try std.testing.expectEqual(@as(u16, 65535), uint16s_flat.getUInt16(1));
    const uint16s_stats = try generated.uint16sFlat.validate(.{});
    try std.testing.expect(uint16s_stats.total_words > 0);

    try std.testing.expectEqualSlices(u32, &[_]u32{ 1, 4294967295 }, generated.uint32s);
    var uint32s_reader = generated.uint32sFlat.reader(.{});
    const uint32s_flat = try generated.uint32sFlat.list(&uint32s_reader);
    try std.testing.expectEqual(@as(u32, 1), uint32s_flat.getUInt32(0));
    try std.testing.expectEqual(@as(u32, 4294967295), uint32s_flat.getUInt32(1));
    const uint32s_stats = try generated.uint32sFlat.validate(.{});
    try std.testing.expect(uint32s_stats.total_words > 0);

    try std.testing.expectEqualSlices(u64, &[_]u64{ 0, 18446744073709551615 }, generated.uint64s);
    var uint64s_reader = generated.uint64sFlat.reader(.{});
    const uint64s_flat = try generated.uint64sFlat.list(&uint64s_reader);
    try std.testing.expectEqual(@as(u64, 0), uint64s_flat.getUInt64(0));
    try std.testing.expectEqual(@as(u64, 18446744073709551615), uint64s_flat.getUInt64(1));
    const uint64s_stats = try generated.uint64sFlat.validate(.{});
    try std.testing.expect(uint64s_stats.total_words > 0);

    var float32s_reader = generated.float32sFlat.reader(.{});
    const float32s_flat = try generated.float32sFlat.list(&float32s_reader);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), float32s_flat.getFloat32(0), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, -2.25), float32s_flat.getFloat32(1), 0.0);
    try std.testing.expect(std.math.isInf(float32s_flat.getFloat32(2)));
    const float32s_stats = try generated.float32sFlat.validate(.{});
    try std.testing.expect(float32s_stats.total_words > 0);

    var float64s_reader = generated.float64sFlat.reader(.{});
    const float64s_flat = try generated.float64sFlat.list(&float64s_reader);
    try std.testing.expectApproxEqAbs(@as(f64, 125.0), float64s_flat.getFloat64(0), 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, -0.5), float64s_flat.getFloat64(1), 0.0);
    try std.testing.expect(std.math.isNan(float64s_flat.getFloat64(2)));
    const float64s_stats = try generated.float64sFlat.validate(.{});
    try std.testing.expect(float64s_stats.total_words > 0);
}
