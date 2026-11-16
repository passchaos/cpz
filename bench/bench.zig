const std = @import("std");
const cpz = @import("cpz");

const reader_iterations = 200_000;
const serialize_iterations = 50_000;
const rounds = 5;

// Each benchmark runs in its own non-inlined function so that the surrounding
// harness cannot change how LLVM compiles the measured loop. Inlining these
// loops into one large `main` previously distorted results by up to 3x.
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

    var flat_buffer: [128 * 1024]u8 = undefined;
    var packed_buffer: [128 * 1024]u8 = undefined;
    var unpacked_buffer: [128 * 1024]u8 = undefined;
    var stream_buffer: [128 * 1024]u8 = undefined;
    var table_buffer: [128]u8 = undefined;
    var packed_alloc_buffer: [128 * 1024]u8 = undefined;
    var packed_alloc_allocator = std.heap.FixedBufferAllocator.init(&packed_alloc_buffer);
    var pack_alloc_buffer: [128 * 1024]u8 = undefined;
    var pack_alloc_allocator = std.heap.FixedBufferAllocator.init(&pack_alloc_buffer);
    var build_buffer: [128 * 1024]u8 = undefined;
    var build_allocator = std.heap.FixedBufferAllocator.init(&build_buffer);

    printResult("dynamic reader", try readerRound(io, flat), reader_iterations);
    printResult("bulk read list", try bulkReadRound(io, flat), serialize_iterations);
    printResult("build message", try buildRound(io, &build_allocator, &values), serialize_iterations);
    printResult("flat serialize", try flatRound(io, segments, &flat_buffer), serialize_iterations);
    printResult("packed serialize", try packedRound(io, segments, &table_buffer, &packed_buffer), serialize_iterations);
    printResult("packed serialize (allocating)", try packedAllocRound(io, &packed_alloc_allocator, segments), serialize_iterations);
    printResult("pack (allocating)", try packAllocRound(io, &pack_alloc_allocator, flat_bytes), serialize_iterations);
    printResult("pack to writer", try packToWriterRound(io, flat_bytes, &stream_buffer), serialize_iterations);
    printResult("pack reader to writer", try packReaderToWriterRound(io, flat_bytes, &stream_buffer), serialize_iterations);
    printResult("unpack", try unpackRound(io, packed_bytes, &unpacked_buffer), serialize_iterations);
    printResult("unpack to writer", try unpackToWriterRound(io, packed_bytes, &stream_buffer), serialize_iterations);
    printResult("unpack reader to writer", try unpackReaderToWriterRound(io, packed_bytes, &stream_buffer), serialize_iterations);
}

noinline fn readerRound(io: std.Io, flat: cpz.FlatMessage) !u64 {
    var best: u64 = std.math.maxInt(u64);
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
        best = @min(best, elapsed);
    }
    return best;
}

noinline fn bulkReadRound(io: std.Io, flat: cpz.FlatMessage) !u64 {
    var values: [1024]u32 = undefined;
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var reader = cpz.MessageReader.init(flat.segments, .{ .traversal_limit_words = std.math.maxInt(usize) });
        const list = try (try reader.getRoot()).getPointerField(1).getList(.four_bytes);
        const start = std.Io.Clock.awake.now(io);
        var checksum: u32 = 0;
        for (0..serialize_iterations) |_| {
            try list.getAll(u32, &values);
            checksum +%= values[17];
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn buildRound(io: std.Io, allocator: *std.heap.FixedBufferAllocator, values: []const u32) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            allocator.reset();
            var built = try buildBenchMessage(allocator.allocator(), values);
            defer built.deinit();
            checksum +%= (try built.segmentsConst())[0].len;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn flatRound(io: std.Io, segments: []const cpz.serialize.ConstSegment, buffer: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            checksum +%= try cpz.messageToFlatBytesInto(buffer, segments);
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn packedRound(io: std.Io, segments: []const cpz.serialize.ConstSegment, table_buffer: []u8, packed_buffer: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            checksum +%= try cpz.messageToPackedBytesInto(table_buffer, packed_buffer, segments);
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn unpackRound(io: std.Io, packed_bytes: []const u8, dest: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            checksum +%= try cpz.unpackInto(dest, packed_bytes);
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn packedAllocRound(io: std.Io, allocator: *std.heap.FixedBufferAllocator, segments: []const cpz.serialize.ConstSegment) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            allocator.reset();
            checksum +%= (try cpz.messageToPackedBytes(allocator.allocator(), segments)).len;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn packAllocRound(io: std.Io, allocator: *std.heap.FixedBufferAllocator, flat_bytes: []const u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            allocator.reset();
            checksum +%= (try cpz.pack(allocator.allocator(), flat_bytes)).len;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn packToWriterRound(io: std.Io, flat_bytes: []const u8, dest: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            var writer = std.Io.Writer.fixed(dest);
            try cpz.packToWriter(&writer, flat_bytes);
            checksum +%= writer.end;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn packReaderToWriterRound(io: std.Io, flat_bytes: []const u8, dest: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            var reader = std.Io.Reader.fixed(flat_bytes);
            var writer = std.Io.Writer.fixed(dest);
            try cpz.packReaderToWriter(&reader, &writer);
            checksum +%= writer.end;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn unpackToWriterRound(io: std.Io, packed_bytes: []const u8, dest: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            var writer = std.Io.Writer.fixed(dest);
            try cpz.unpackToWriter(&writer, packed_bytes);
            checksum +%= writer.end;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
}

noinline fn unpackReaderToWriterRound(io: std.Io, packed_bytes: []const u8, dest: []u8) !u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..serialize_iterations) |_| {
            var reader = std.Io.Reader.fixed(packed_bytes);
            var writer = std.Io.Writer.fixed(dest);
            try cpz.unpackReaderToWriter(&reader, &writer);
            checksum +%= writer.end;
        }
        const elapsed: u64 = @intCast(start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds);
        best = @min(best, elapsed);
        std.mem.doNotOptimizeAway(checksum);
    }
    return best;
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

fn printResult(name: []const u8, elapsed_ns: u64, iterations: usize) void {
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    std.debug.print("{s}: {d} iterations, {d} ns total, {d:.1} ns/op\n", .{
        name,
        iterations,
        elapsed_ns,
        ns_per_op,
    });
}
