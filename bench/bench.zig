const std = @import("std");
const cpz = @import("cpz");

const reader_iterations = 200_000;
const serialize_iterations = 50_000;
const rounds = 5;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer std.debug.assert(gpa_state.deinit() == .ok);
    const allocator = gpa_state.allocator();
    const io = std.Io.Threaded.global_single_threaded.io();

    var builder = try cpz.MessageBuilder.init(allocator, .{ .first_segment_words = 4096 });
    defer builder.deinit();
    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try root.setUInt32(0, 42, 0);
    try root.setText(0, "benchmark payload");
    const nums = try (try root.getPointerField(1)).initList(.four_bytes, 1024);
    for (0..nums.len()) |i| try nums.setUInt32(i, @intCast(i));

    const segments = try builder.segmentsConst();
    const flat_bytes = try cpz.messageToFlatBytes(allocator, segments);
    defer allocator.free(flat_bytes);
    const packed_bytes = try cpz.messageToPackedBytes(allocator, segments);
    defer allocator.free(packed_bytes);

    var flat = try cpz.readFlatMessage(allocator, flat_bytes);
    defer flat.deinit(allocator);
    var packed_message = try cpz.readPackedMessage(allocator, packed_bytes);
    defer packed_message.deinit(allocator);

    std.debug.print("message: {} segments, {} bytes flat, {} bytes packed\n", .{
        flat.segments.len,
        flat.bytes.len,
        packed_message.bytes.len,
    });

    var reader_ns: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var warmup = cpz.MessageReader.init(flat.segments, .{ .traversal_limit_words = std.math.maxInt(usize) });
        _ = try readRound(&warmup, reader_iterations / 10);
        var reader = cpz.MessageReader.init(flat.segments, .{ .traversal_limit_words = std.math.maxInt(usize) });
        const start = std.Io.Clock.awake.now(io);
        _ = try readRound(&reader, reader_iterations);
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        reader_ns = @min(reader_ns, elapsed);
    }

    var flat_ns: u64 = std.math.maxInt(u64);
    var packed_ns: u64 = std.math.maxInt(u64);
    var flat_buffer: [128 * 1024]u8 = undefined;
    var packed_buffer: [128 * 1024]u8 = undefined;
    var table_buffer: [128]u8 = undefined;
    for (0..rounds) |_| {
        const flat_start = std.Io.Clock.awake.now(io);
        var flat_checksum: usize = 0;
        for (0..serialize_iterations) |_| {
            flat_checksum +%= try cpz.messageToFlatBytesInto(&flat_buffer, segments);
        }
        flat_ns = @min(flat_ns, @as(u64, @intCast(flat_start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds)));
        std.mem.doNotOptimizeAway(flat_checksum);

        const packed_start = std.Io.Clock.awake.now(io);
        var packed_checksum: usize = 0;
        for (0..serialize_iterations) |_| {
            packed_checksum +%= try cpz.messageToPackedBytesInto(&table_buffer, &packed_buffer, segments);
        }
        packed_ns = @min(packed_ns, @as(u64, @intCast(packed_start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds)));
        std.mem.doNotOptimizeAway(packed_checksum);
    }

    printResult("dynamic reader", reader_ns, reader_iterations);
    printResult("flat serialize", flat_ns, serialize_iterations);
    printResult("packed serialize", packed_ns, serialize_iterations);
}

fn readRound(reader: *cpz.MessageReader, iterations: usize) !u64 {
    var checksum: u64 = 0;
    for (0..iterations) |_| {
        const root = try reader.getRoot();
        checksum +%= root.getUInt32(0, 0);
        const list = try root.getPointerField(1).getList(.four_bytes);
        checksum +%= list.getUInt32(17);
    }
    return checksum;
}

fn printResult(name: []const u8, elapsed_ns: u64, iterations: usize) void {
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    std.debug.print("{s}: {d} iterations, {d} ns total, {d:.1} ns/op\n", .{
        name,
        iterations,
        elapsed_ns,
        ns_per_op,
    });
}
