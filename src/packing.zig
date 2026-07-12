const std = @import("std");
const wire = @import("wire.zig");

pub const Error = error{
    PackedInputTruncated,
    PackedOutputLengthMismatch,
    PackedOutputTooSmall,
    UnpackedInputNotWordAligned,
} || std.mem.Allocator.Error;

/// Cap'n Proto packing encoder. Input must be whole words.
///
/// The implementation keeps the hot path branch-light: collect the tag and
/// non-zero payload bytes for one word, then handle only the two special tags
/// (0x00 and 0xff). This mirrors the C++ format while exposing Zig slices.
pub fn pack(allocator: std.mem.Allocator, unpacked_bytes: []const u8) Error![]u8 {
    if (unpacked_bytes.len % wire.bytes_per_word != 0) return error.UnpackedInputNotWordAligned;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < unpacked_bytes.len) {
        var tag: u8 = 0;
        var payload: [wire.bytes_per_word]u8 = undefined;
        var payload_len: usize = 0;
        inline for (0..wire.bytes_per_word) |j| {
            const b = unpacked_bytes[i + j];
            if (b != 0) {
                tag |= @as(u8, 1) << @as(u3, @intCast(j));
                payload[payload_len] = b;
                payload_len += 1;
            }
        }
        try out.append(allocator, tag);
        try out.appendSlice(allocator, payload[0..payload_len]);
        i += wire.bytes_per_word;

        if (tag == 0x00) {
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and isZeroWord(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            try out.append(allocator, @intCast(run_words));
        } else if (tag == 0xff) {
            const run_start = i;
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and shouldCopyRaw(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            try out.append(allocator, @intCast(run_words));
            try out.appendSlice(allocator, unpacked_bytes[run_start..i]);
        }
    }

    return out.toOwnedSlice(allocator);
}

/// Encode into a caller-provided buffer. Returns bytes written. This avoids
/// allocator traffic for latency-sensitive packed streams.
pub fn packInto(dest: []u8, unpacked_bytes: []const u8) Error!usize {
    if (unpacked_bytes.len % wire.bytes_per_word != 0) return error.UnpackedInputNotWordAligned;

    var out_i: usize = 0;
    var i: usize = 0;
    while (i < unpacked_bytes.len) {
        var tag: u8 = 0;
        var payload: [wire.bytes_per_word]u8 = undefined;
        var payload_len: usize = 0;
        inline for (0..wire.bytes_per_word) |j| {
            const b = unpacked_bytes[i + j];
            if (b != 0) {
                tag |= @as(u8, 1) << @as(u3, @intCast(j));
                payload[payload_len] = b;
                payload_len += 1;
            }
        }
        try writePackedSlice(dest, &out_i, &[_]u8{tag});
        try writePackedSlice(dest, &out_i, payload[0..payload_len]);
        i += wire.bytes_per_word;

        if (tag == 0x00) {
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and isZeroWord(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            try writePackedSlice(dest, &out_i, &[_]u8{@intCast(run_words)});
        } else if (tag == 0xff) {
            const run_start = i;
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and shouldCopyRaw(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            try writePackedSlice(dest, &out_i, &[_]u8{@intCast(run_words)});
            try writePackedSlice(dest, &out_i, unpacked_bytes[run_start..i]);
        }
    }

    return out_i;
}

/// Decode a packed Cap'n Proto stream into a newly-allocated word-aligned byte
/// sequence. The returned slice length is always a multiple of 8.
pub fn unpack(allocator: std.mem.Allocator, packed_bytes: []const u8) Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < packed_bytes.len) {
        const tag = packed_bytes[i];
        i += 1;

        var word = [_]u8{0} ** wire.bytes_per_word;
        inline for (0..wire.bytes_per_word) |j| {
            if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                if (i >= packed_bytes.len) return error.PackedInputTruncated;
                word[j] = packed_bytes[i];
                i += 1;
            }
        }
        try out.appendSlice(allocator, &word);

        if (tag == 0x00) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const additional_words = @as(usize, packed_bytes[i]);
            i += 1;
            try out.appendNTimes(allocator, 0, additional_words * wire.bytes_per_word);
        } else if (tag == 0xff) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const raw_words = @as(usize, packed_bytes[i]);
            i += 1;
            const raw_bytes = raw_words * wire.bytes_per_word;
            if (packed_bytes.len - i < raw_bytes) return error.PackedInputTruncated;
            try out.appendSlice(allocator, packed_bytes[i .. i + raw_bytes]);
            i += raw_bytes;
        }
    }

    return out.toOwnedSlice(allocator);
}

/// Decode into a caller-provided buffer. Returns bytes written.
pub fn unpackInto(dest: []u8, packed_bytes: []const u8) Error!usize {
    var out_i: usize = 0;
    var i: usize = 0;
    while (i < packed_bytes.len) {
        const tag = packed_bytes[i];
        i += 1;
        if (dest.len - out_i < wire.bytes_per_word) return error.PackedOutputTooSmall;
        @memset(dest[out_i .. out_i + wire.bytes_per_word], 0);
        inline for (0..wire.bytes_per_word) |j| {
            if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                if (i >= packed_bytes.len) return error.PackedInputTruncated;
                dest[out_i + j] = packed_bytes[i];
                i += 1;
            }
        }
        out_i += wire.bytes_per_word;

        if (tag == 0x00) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const additional_bytes = @as(usize, packed_bytes[i]) * wire.bytes_per_word;
            i += 1;
            if (dest.len - out_i < additional_bytes) return error.PackedOutputTooSmall;
            @memset(dest[out_i .. out_i + additional_bytes], 0);
            out_i += additional_bytes;
        } else if (tag == 0xff) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const raw_bytes = @as(usize, packed_bytes[i]) * wire.bytes_per_word;
            i += 1;
            if (packed_bytes.len - i < raw_bytes) return error.PackedInputTruncated;
            if (dest.len - out_i < raw_bytes) return error.PackedOutputTooSmall;
            @memcpy(dest[out_i .. out_i + raw_bytes], packed_bytes[i .. i + raw_bytes]);
            out_i += raw_bytes;
            i += raw_bytes;
        }
    }
    return out_i;
}

fn writePackedSlice(dest: []u8, out_i: *usize, bytes: []const u8) Error!void {
    if (dest.len - out_i.* < bytes.len) return error.PackedOutputTooSmall;
    @memcpy(dest[out_i.* .. out_i.* + bytes.len], bytes);
    out_i.* += bytes.len;
}

inline fn isZeroWord(word: *const [wire.bytes_per_word]u8) bool {
    return wire.readWordAt(word) == 0;
}

inline fn shouldCopyRaw(word: *const [wire.bytes_per_word]u8) bool {
    var zeros: usize = 0;
    inline for (0..wire.bytes_per_word) |j| {
        zeros += @intFromBool(word[j] == 0);
    }
    // Copy raw runs while words are dense enough that tag+payload packing is
    // not materially better. The decoder accepts any raw run length; this is
    // only an encoder heuristic.
    return zeros <= 1;
}

test "packing spec examples" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked1 = [_]u8{0} ** 32;
    const packed1 = try pack(allocator, &unpacked1);
    defer allocator.free(packed1);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x03 }, packed1);
    const round1 = try unpack(allocator, packed1);
    defer allocator.free(round1);
    try testing.expectEqualSlices(u8, &unpacked1, round1);

    const unpacked2 = [_]u8{0x8a} ** 32;
    const packed2 = try pack(allocator, &unpacked2);
    defer allocator.free(packed2);
    try testing.expectEqualSlices(u8, &([_]u8{0xff} ++ ([_]u8{0x8a} ** 8) ++ [_]u8{0x03} ++ ([_]u8{0x8a} ** 24)), packed2);
    const round2 = try unpack(allocator, packed2);
    defer allocator.free(round2);
    try testing.expectEqualSlices(u8, &unpacked2, round2);
}

test "packing pointer example" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked = [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
        0x19, 0x00, 0x00, 0x00, 0xaa, 0x01, 0x00, 0x00,
    };
    const packed_out = try pack(allocator, &unpacked);
    defer allocator.free(packed_out);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x51, 0x08, 0x03, 0x02, 0x31, 0x19, 0xaa, 0x01 }, packed_out);
}

test "packInto matches allocating encoder and reports small buffers" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked = ([_]u8{0} ** 24) ++ ([_]u8{0x8a} ** 32) ++ [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
        0x19, 0x00, 0x00, 0x00, 0xaa, 0x01, 0x00, 0x00,
    };
    const expected = try pack(allocator, &unpacked);
    defer allocator.free(expected);

    var buffer: [256]u8 = undefined;
    const written = try packInto(&buffer, &unpacked);
    try testing.expectEqualSlices(u8, expected, buffer[0..written]);
    try testing.expectError(error.PackedOutputTooSmall, packInto(buffer[0 .. written - 1], &unpacked));
}
