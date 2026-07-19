const std = @import("std");
const cpz = @import("cpz");

// Optional compatibility smoke for the upstream Cap'n Proto C++ fixture corpus.
// The fixtures are not vendored into cpz, so missing local checkouts skip the
// test instead of making ordinary source distributions depend on a sibling repo.
const fixture_base = "/home/passchaos/Work/capnproto/c++/src/capnp/testdata";
const max_fixture_bytes = 64 * 1024 * 1024;

fn fixturePath(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ fixture_base, name });
}

fn readFixture(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    const path = try fixturePath(allocator, name);
    defer allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(max_fixture_bytes)) catch |err| switch (err) {
        error.FileNotFound => error.SkipZigTest,
        else => err,
    };
}

fn readStreamFixture(allocator: std.mem.Allocator, name: []const u8, is_packed: bool) !cpz.FlatMessage {
    const bytes = try readFixture(allocator, name);
    defer allocator.free(bytes);
    return if (is_packed) try cpz.readPackedMessage(allocator, bytes) else try cpz.readFlatMessage(allocator, bytes);
}

fn readSingleSegmentFixture(allocator: std.mem.Allocator, name: []const u8, is_packed: bool) ![]u8 {
    const bytes = try readFixture(allocator, name);
    if (!is_packed) return bytes;
    defer allocator.free(bytes);
    return try cpz.unpack(allocator, bytes);
}

fn validateStreamFixture(name: []const u8, is_packed: bool) !void {
    var flat = try readStreamFixture(std.testing.allocator, name, is_packed);
    defer flat.deinit(std.testing.allocator);
    var reader = cpz.MessageReader.init(flat.segments, .{});
    _ = try reader.validate();
    _ = try reader.getRootPointer();
}

fn expectText(ptr: cpz.PointerReader, expected: []const u8) !void {
    try std.testing.expectEqualStrings(expected, try ptr.getText());
}

fn expectData(ptr: cpz.PointerReader, expected: []const u8) !void {
    try std.testing.expectEqualSlices(u8, expected, try ptr.getData());
}

fn expectUInt8List(list: cpz.ListReader, expected: []const u8) !void {
    try std.testing.expectEqual(.byte, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getUInt8(index));
}

fn expectInt8List(list: cpz.ListReader, expected: []const i8) !void {
    try std.testing.expectEqual(.byte, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getInt8(index));
}

fn expectUInt16List(list: cpz.ListReader, expected: []const u16) !void {
    try std.testing.expectEqual(.two_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getUInt16(index));
}

fn expectInt16List(list: cpz.ListReader, expected: []const i16) !void {
    try std.testing.expectEqual(.two_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getInt16(index));
}

fn expectUInt32List(list: cpz.ListReader, expected: []const u32) !void {
    try std.testing.expectEqual(.four_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getUInt32(index));
}

fn expectInt32List(list: cpz.ListReader, expected: []const i32) !void {
    try std.testing.expectEqual(.four_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getInt32(index));
}

fn expectUInt64List(list: cpz.ListReader, expected: []const u64) !void {
    try std.testing.expectEqual(.eight_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getUInt64(index));
}

fn expectInt64List(list: cpz.ListReader, expected: []const i64) !void {
    try std.testing.expectEqual(.eight_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getInt64(index));
}

fn expectFloat32List(list: cpz.ListReader, expected: []const f32) !void {
    try std.testing.expectEqual(.four_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| {
        if (std.math.isNan(value)) {
            try std.testing.expect(std.math.isNan(list.getFloat32(index)));
        } else {
            try std.testing.expectEqual(value, list.getFloat32(index));
        }
    }
}

fn expectFloat64List(list: cpz.ListReader, expected: []const f64) !void {
    try std.testing.expectEqual(.eight_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| {
        if (std.math.isNan(value)) {
            try std.testing.expect(std.math.isNan(list.getFloat64(index)));
        } else {
            try std.testing.expectEqual(value, list.getFloat64(index));
        }
    }
}

fn expectTextList(list: cpz.ListReader, expected: []const []const u8) !void {
    try std.testing.expectEqual(.pointer, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try expectText(try list.getPointerElement(index), value);
}

fn expectDataList(list: cpz.ListReader, expected: []const []const u8) !void {
    try std.testing.expectEqual(.pointer, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try expectData(try list.getPointerElement(index), value);
}

fn expectEnumList(list: cpz.ListReader, expected: []const u16) !void {
    try std.testing.expectEqual(.two_bytes, list.elementSize());
    try std.testing.expectEqual(expected.len, list.len());
    for (expected, 0..) |value, index| try std.testing.expectEqual(value, list.getUInt16(index));
}

fn expectSecondLevelStruct(value: cpz.StructReader) !void {
    try std.testing.expectEqual(false, value.getBool(0, false));
    try std.testing.expectEqual(@as(i8, 0), value.getInt8(1, 0));
    try std.testing.expectEqual(@as(i16, 0), value.getInt16(2, 0));
    try std.testing.expectEqual(@as(i32, 0), value.getInt32(4, 0));
    try std.testing.expectEqual(@as(i64, 0), value.getInt64(8, 0));
    try std.testing.expectEqual(@as(u8, 0), value.getUInt8(16, 0));
    try std.testing.expectEqual(@as(u16, 0), value.getUInt16(18, 0));
    try std.testing.expectEqual(@as(u32, 0), value.getUInt32(20, 0));
    try std.testing.expectEqual(@as(u64, 0), value.getUInt64(24, 0));
    try std.testing.expectEqual(@as(f32, 0), value.getFloat32(32, 0));
    try std.testing.expectEqual(@as(f64, 0), value.getFloat64(40, 0));
    try std.testing.expectEqual(@as(u16, 0), value.getUInt16(36, 0));
    try expectText(value.getPointerField(0), "nested");

    const third = try value.getPointerField(2).getStruct(null);
    try std.testing.expectEqual(false, third.getBool(0, false));
    try std.testing.expectEqual(@as(u16, 0), third.getUInt16(36, 0));
    try expectText(third.getPointerField(0), "really nested");
}

fn expectStructList(list: cpz.ListReader, comptime prefix: []const u8) !void {
    try std.testing.expectEqual(.composite, list.elementSize());
    try std.testing.expectEqual(@as(usize, 3), list.len());
    for (0..3) |index| {
        const item = try list.getStructElement(index);
        var expected_buf: [32]u8 = undefined;
        const expected = try std.fmt.bufPrint(&expected_buf, prefix ++ "{}", .{index + 1});
        try expectText(item.getPointerField(0), expected);
        try std.testing.expectEqual(@as(u16, 0), item.getUInt16(36, 0));
    }
}

fn expectTestAllTypesRoot(root: cpz.StructReader) !void {
    try std.testing.expectEqual(@as(u16, 6), root.dataWordCount());
    try std.testing.expectEqual(@as(u16, 20), root.pointerCount());
    try std.testing.expectEqual(true, root.getBool(0, false));
    try std.testing.expectEqual(@as(i8, -123), root.getInt8(1, 0));
    try std.testing.expectEqual(@as(i16, -12345), root.getInt16(2, 0));
    try std.testing.expectEqual(@as(i32, -12345678), root.getInt32(4, 0));
    try std.testing.expectEqual(@as(i64, -123456789012345), root.getInt64(8, 0));
    try std.testing.expectEqual(@as(u8, 234), root.getUInt8(16, 0));
    try std.testing.expectEqual(@as(u16, 45678), root.getUInt16(18, 0));
    try std.testing.expectEqual(@as(u32, 3456789012), root.getUInt32(20, 0));
    try std.testing.expectEqual(@as(u64, 12345678901234567890), root.getUInt64(24, 0));
    try std.testing.expectEqual(@as(f32, 1234.5), root.getFloat32(32, 0));
    try std.testing.expectEqual(@as(f64, -123e45), root.getFloat64(40, 0));
    try std.testing.expectEqual(@as(u16, 5), root.getUInt16(36, 0));
    try expectText(root.getPointerField(0), "foo");
    try expectData(root.getPointerField(1), "bar");

    const nested = try root.getPointerField(2).getStruct(null);
    try std.testing.expectEqual(true, nested.getBool(0, false));
    try std.testing.expectEqual(@as(i8, -12), nested.getInt8(1, 0));
    try std.testing.expectEqual(@as(i16, 3456), nested.getInt16(2, 0));
    try std.testing.expectEqual(@as(i32, -78901234), nested.getInt32(4, 0));
    try std.testing.expectEqual(@as(i64, 56789012345678), nested.getInt64(8, 0));
    try std.testing.expectEqual(@as(u8, 90), nested.getUInt8(16, 0));
    try std.testing.expectEqual(@as(u16, 1234), nested.getUInt16(18, 0));
    try std.testing.expectEqual(@as(u32, 56789012), nested.getUInt32(20, 0));
    try std.testing.expectEqual(@as(u64, 345678901234567890), nested.getUInt64(24, 0));
    try std.testing.expectEqual(@as(f32, -1.25e-10), nested.getFloat32(32, 0));
    try std.testing.expectEqual(@as(f64, 345), nested.getFloat64(40, 0));
    try std.testing.expectEqual(@as(u16, 2), nested.getUInt16(36, 0));
    try expectText(nested.getPointerField(0), "baz");
    try expectData(nested.getPointerField(1), "qux");
    try expectSecondLevelStruct(try nested.getPointerField(2).getStruct(null));

    try std.testing.expectEqual(@as(usize, 6), (try root.getPointerField(3).getList(.void)).len());
    const bools = try root.getPointerField(4).getList(.bit);
    try std.testing.expectEqual(@as(usize, 4), bools.len());
    try std.testing.expectEqual(true, bools.getBool(0));
    try std.testing.expectEqual(false, bools.getBool(1));
    try std.testing.expectEqual(false, bools.getBool(2));
    try std.testing.expectEqual(true, bools.getBool(3));
    try expectInt8List(try root.getPointerField(5).getList(.byte), &.{ 111, -111 });
    try expectInt16List(try root.getPointerField(6).getList(.two_bytes), &.{ 11111, -11111 });
    try expectInt32List(try root.getPointerField(7).getList(.four_bytes), &.{ 111111111, -111111111 });
    try expectInt64List(try root.getPointerField(8).getList(.eight_bytes), &.{ 1111111111111111111, -1111111111111111111 });
    try expectUInt8List(try root.getPointerField(9).getList(.byte), &.{ 111, 222 });
    try expectUInt16List(try root.getPointerField(10).getList(.two_bytes), &.{ 33333, 44444 });
    try expectUInt32List(try root.getPointerField(11).getList(.four_bytes), &.{3333333333});
    try expectUInt64List(try root.getPointerField(12).getList(.eight_bytes), &.{11111111111111111111});
    try expectFloat32List(try root.getPointerField(13).getList(.four_bytes), &.{ 5555.5, std.math.inf(f32), -std.math.inf(f32), std.math.nan(f32) });
    try expectFloat64List(try root.getPointerField(14).getList(.eight_bytes), &.{ 7777.75, std.math.inf(f64), -std.math.inf(f64), std.math.nan(f64) });
    try expectTextList(try root.getPointerField(15).getList(.pointer), &.{ "plugh", "xyzzy", "thud" });
    try expectDataList(try root.getPointerField(16).getList(.pointer), &.{ "oops", "exhausted", "rfc3092" });
    try expectStructList(try root.getPointerField(17).getList(.composite), "structlist ");
    try expectEnumList(try root.getPointerField(18).getList(.two_bytes), &.{ 0, 7 });
}

fn expectTestAllTypesStreamFixture(name: []const u8, is_packed: bool) !void {
    var flat = try readStreamFixture(std.testing.allocator, name, is_packed);
    defer flat.deinit(std.testing.allocator);
    var reader = cpz.MessageReader.init(flat.segments, .{});
    try expectTestAllTypesRoot(try reader.getRoot());
}

fn expectTestAllTypesSingleSegmentFixture(name: []const u8, is_packed: bool) !void {
    const bytes = try readSingleSegmentFixture(std.testing.allocator, name, is_packed);
    defer std.testing.allocator.free(bytes);
    var segments = [_]cpz.ConstSegment{bytes};
    var reader = cpz.MessageReader.init(&segments, .{});
    try expectTestAllTypesRoot(try reader.getRoot());
}

test "upstream C++ binary fixtures parse and expose TestAllTypes values" {
    // The six TestAllTypes fixtures exercise the same logical message through
    // stream framing, flat single-segment encoding, packing, and multi-segment
    // far-pointer layouts produced by the C++ implementation.
    try expectTestAllTypesStreamFixture("binary", false);
    try expectTestAllTypesStreamFixture("segmented", false);
    try expectTestAllTypesStreamFixture("packed", true);
    try expectTestAllTypesStreamFixture("segmented-packed", true);
    try expectTestAllTypesSingleSegmentFixture("flat", false);
    try expectTestAllTypesSingleSegmentFixture("packedflat", true);

    // Additional upstream fixtures use different schemas; schema-agnostic
    // validation is still valuable because it walks all reachable pointers.
    try validateStreamFixture("lists.binary", false);
    try validateStreamFixture("annotated-json.binary", false);
}
