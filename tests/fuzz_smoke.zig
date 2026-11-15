const std = @import("std");
const cpz = @import("cpz");

const Context = struct {};

const max_input_bytes = 8 * 1024;

fn takeInput(smith: *std.testing.Smith, buf: []u8, hash: u32) []const u8 {
    if (smith.in) |input| {
        const len = @min(input.len, buf.len);
        @memcpy(buf[0..len], input[0..len]);
        smith.in = input[len..];
        return buf[0..len];
    }
    const len = smith.sliceWithHash(buf, hash);
    return buf[0..@intCast(len)];
}

fn exerciseWire(input: []const u8) !void {
    var word_index: usize = 0;
    while (word_index + @sizeOf(u64) <= input.len) : (word_index += @sizeOf(u64)) {
        const raw = std.mem.readInt(u64, input[word_index..][0..@sizeOf(u64)], .little);
        _ = cpz.wire.decode(raw) catch {};
        _ = cpz.wire.decodeStruct(raw);
        _ = cpz.wire.decodeList(raw) catch {};
        _ = cpz.wire.decodeFar(raw);
        _ = cpz.wire.decodeOther(raw) catch {};
    }

    if (cpz.readFlatMessage(std.testing.allocator, input)) |message| {
        var owned = message;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    if (cpz.readFlatMessageView(std.testing.allocator, input)) |view| {
        var owned = view;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    var flat_segments: [64]cpz.ConstSegment = undefined;
    if (cpz.readFlatMessageViewInto(&flat_segments, input)) |view| {
        var owned = view;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    if (cpz.readPackedMessage(std.testing.allocator, input)) |message| {
        var owned = message;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    var packed_segments: [64]cpz.ConstSegment = undefined;
    var packed_flat_buffer: [max_input_bytes * 2]u8 = undefined;
    if (cpz.readPackedMessageViewInto(&packed_segments, &packed_flat_buffer, input)) |view| {
        var owned = view;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    var flat_reader = std.Io.Reader.fixed(input);
    if (cpz.readMessageFromReader(std.testing.allocator, &flat_reader)) |message| {
        var owned = message;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    var packed_reader = std.Io.Reader.fixed(input);
    if (cpz.readPackedMessageFromReader(std.testing.allocator, &packed_reader)) |message| {
        var owned = message;
        owned.deinit(std.testing.allocator);
    } else |_| {}

    if (cpz.unpack(std.testing.allocator, input)) |unpacked| {
        defer std.testing.allocator.free(unpacked);
        const packed_bytes = cpz.pack(std.testing.allocator, unpacked) catch return;
        defer std.testing.allocator.free(packed_bytes);
        try std.testing.expectEqual(unpacked.len, try cpz.unpackedSize(packed_bytes));
        const round_trip = try cpz.unpack(std.testing.allocator, packed_bytes);
        defer std.testing.allocator.free(round_trip);
        try std.testing.expectEqualSlices(u8, unpacked, round_trip);
    } else |_| {}
}

fn exerciseSchema(input: []const u8) !void {
    var file = cpz.schema.parse(std.testing.allocator, input) catch return;
    defer file.deinit(std.testing.allocator);

    var layouts = cpz.schema.planLayouts(std.testing.allocator, &file) catch return;
    defer layouts.deinit(std.testing.allocator);

    const generated = cpz.schema.generateZig(std.testing.allocator, &file, &layouts) catch return;
    defer std.testing.allocator.free(generated);
    try std.testing.expect(generated.len != 0);
}

fn fuzzWire(_: Context, smith: *std.testing.Smith) !void {
    var storage: [max_input_bytes]u8 = undefined;
    try exerciseWire(takeInput(smith, &storage, 0));
}

fn fuzzSchema(_: Context, smith: *std.testing.Smith) !void {
    var storage: [max_input_bytes]u8 = undefined;
    try exerciseSchema(takeInput(smith, &storage, 1));
}

test "fuzz wire pointers and flat/packed readers" {
    try std.testing.fuzz(Context{}, fuzzWire, .{ .corpus = &.{
        &.{},
        &[_]u8{0} ** 8,
        @embedFile("fixtures/person.bin"),
        @embedFile("fixtures/raw.bin"),
        @embedFile("fixtures/text.txt"),
    } });
}

test "fuzz schema parser, layout, and codegen" {
    try std.testing.fuzz(Context{}, fuzzSchema, .{ .corpus = &.{
        &.{},
        "struct Tiny { a @0 :UInt32; b @1 :Text; }",
        "enum Color { red @0; green @1; }",
        "interface Service { call @0 (x :UInt32) -> (y :Text); }",
        "this is not a schema",
    } });
}

test "randomized wire and schema inputs" {
    var prng = std.Random.DefaultPrng.init(0x4350_5a5f_4655_5a5a);
    const random = prng.random();
    var storage: [max_input_bytes]u8 = undefined;

    for (0..2_000) |_| {
        const len = random.intRangeAtMost(usize, 0, storage.len);
        random.bytes(storage[0..len]);
        try exerciseWire(storage[0..len]);

        const schema_len = random.intRangeAtMost(usize, 0, 2 * 1024);
        try exerciseSchema(storage[0..schema_len]);
    }
}
