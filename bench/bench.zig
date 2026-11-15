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

    var values: [1024]u32 = undefined;
    for (0..values.len) |i| values[i] = @intCast(i);

    var builder = try buildBenchMessage(allocator, &values);
    defer builder.deinit();

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
        var warm_checksum: u64 = 0;
        for (0..reader_iterations / 10) |_| {
            const root = try warmup.getRoot();
            warm_checksum +%= root.getUInt32(0, 0);
            const list = try root.getPointerField(1).getList(.four_bytes);
            warm_checksum +%= list.getUInt32(17);
        }
        std.mem.doNotOptimizeAway(warm_checksum);

        var reader = cpz.MessageReader.init(flat.segments, .{ .traversal_limit_words = std.math.maxInt(usize) });
        const start = std.Io.Clock.awake.now(io);
        var checksum: u64 = 0;
        for (0..reader_iterations) |_| {
            const root = try reader.getRoot();
            checksum +%= root.getUInt32(0, 0);
            const list = try root.getPointerField(1).getList(.four_bytes);
            checksum +%= list.getUInt32(17);
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        std.mem.doNotOptimizeAway(checksum);
        reader_ns = @min(reader_ns, elapsed);
    }

    const bulk_read_ns = try bulkReadRound(io, flat, serialize_iterations);

    var flat_ns: u64 = std.math.maxInt(u64);
    var packed_ns: u64 = std.math.maxInt(u64);
    var unpack_ns: u64 = std.math.maxInt(u64);
    var packed_alloc_ns: u64 = std.math.maxInt(u64);
    var pack_alloc_ns: u64 = std.math.maxInt(u64);
    var build_ns: u64 = std.math.maxInt(u64);
    var flat_buffer: [128 * 1024]u8 = undefined;
    var packed_buffer: [128 * 1024]u8 = undefined;
    var unpacked_buffer: [128 * 1024]u8 = undefined;
    var table_buffer: [128]u8 = undefined;
    var packed_alloc_buffer: [128 * 1024]u8 = undefined;
    var packed_alloc_allocator = std.heap.FixedBufferAllocator.init(&packed_alloc_buffer);
    var pack_alloc_buffer: [128 * 1024]u8 = undefined;
    var pack_alloc_allocator = std.heap.FixedBufferAllocator.init(&pack_alloc_buffer);
    var build_buffer: [128 * 1024]u8 = undefined;
    var build_allocator = std.heap.FixedBufferAllocator.init(&build_buffer);
    for (0..rounds) |_| {
        const build_start = std.Io.Clock.awake.now(io);
        var build_checksum: usize = 0;
        for (0..serialize_iterations) |_| {
            build_allocator.reset();
            var built = try buildBenchMessage(build_allocator.allocator(), &values);
            defer built.deinit();
            build_checksum +%= (try built.segmentsConst())[0].len;
        }
        build_ns = @min(build_ns, @as(u64, @intCast(build_start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds)));
        std.mem.doNotOptimizeAway(build_checksum);

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

        const unpack_start = std.Io.Clock.awake.now(io);
        var unpack_checksum: usize = 0;
        for (0..serialize_iterations) |_| {
            unpack_checksum +%= try cpz.unpackInto(&unpacked_buffer, packed_bytes);
        }
        unpack_ns = @min(unpack_ns, @as(u64, @intCast(unpack_start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds)));
        std.mem.doNotOptimizeAway(unpack_checksum);

        const packed_alloc_start = std.Io.Clock.awake.now(io);
        var packed_alloc_checksum: usize = 0;
        for (0..serialize_iterations) |_| {
            packed_alloc_allocator.reset();
            packed_alloc_checksum +%= (try cpz.messageToPackedBytes(packed_alloc_allocator.allocator(), segments)).len;
        }
        packed_alloc_ns = @min(packed_alloc_ns, @as(u64, @intCast(packed_alloc_start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds)));
        std.mem.doNotOptimizeAway(packed_alloc_checksum);

        const pack_alloc_start = std.Io.Clock.awake.now(io);
        var pack_alloc_checksum: usize = 0;
        for (0..serialize_iterations) |_| {
            pack_alloc_allocator.reset();
            pack_alloc_checksum +%= (try cpz.pack(pack_alloc_allocator.allocator(), flat_bytes)).len;
        }
        pack_alloc_ns = @min(pack_alloc_ns, @as(u64, @intCast(pack_alloc_start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds)));
        std.mem.doNotOptimizeAway(pack_alloc_checksum);
    }

    printResult("dynamic reader", reader_ns, reader_iterations);
    printResult("bulk read list", bulk_read_ns, serialize_iterations);
    printResult("build message", build_ns, serialize_iterations);
    printResult("flat serialize", flat_ns, serialize_iterations);
    printResult("packed serialize", packed_ns, serialize_iterations);
    printResult("packed serialize (allocating)", packed_alloc_ns, serialize_iterations);
    printResult("pack (allocating)", pack_alloc_ns, serialize_iterations);
    printResult("unpack", unpack_ns, serialize_iterations);
}

fn buildBenchMessage(allocator: std.mem.Allocator, values: []const u32) !cpz.MessageBuilder {
    var builder = try cpz.MessageBuilder.init(allocator, .{ .first_segment_words = 4096 });
    errdefer builder.deinit();
    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try root.setUInt32(0, 42, 0);
    try root.setText(0, "benchmark payload");
    const nums = try (try root.getPointerField(1)).initList(.four_bytes, values.len);
    try nums.setAll(u32, values);
    return builder;
}

fn bulkReadRound(io: std.Io, flat: cpz.FlatMessage, iterations: usize) !u64 {
    var values: [1024]u32 = undefined;
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var reader = cpz.MessageReader.init(flat.segments, .{ .traversal_limit_words = std.math.maxInt(usize) });
        const list = try (try reader.getRoot()).getPointerField(1).getList(.four_bytes);
        const start = std.Io.Clock.awake.now(io);
        var checksum: u32 = 0;
        for (0..iterations) |_| {
            try list.getAll(u32, &values);
            checksum +%= values[17];
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
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
