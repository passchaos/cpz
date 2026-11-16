const std = @import("std");
const builtin = @import("builtin");
const wire = @import("wire.zig");

/// NEON byte-table shuffles are available on aarch64. Other targets keep the
/// scalar packing loop in `packing.zig`.
pub const enabled = builtin.cpu.arch == .aarch64;

/// Debug builds use the scalar path: the shuffle saves little without
/// optimization and is much slower with safety checks enabled.
pub const use_in_packing = enabled and builtin.mode != .Debug;

const V8 = @Vector(8, u8);
const V16 = @Vector(16, u8);

/// Eight payload bytes in a vector so callers can store them with one
/// instruction instead of extracting bytes individually.
pub const Payload = V8;

pub const CompressedWord = struct {
    tag: u8,
    /// Compacted payload bytes followed by zeros; only `count_table[tag]`
    /// leading bytes are meaningful.
    payload: Payload,
};

/// For each tag, the source index of the payload byte written to each output
/// position, or 0x80 to write zero.
pub const shuffle_table: [256][8]u8 = makeShuffleTable();
pub const count_table: [256]u8 = makeCountTable();

fn makeShuffleTable() [256][8]u8 {
    @setEvalBranchQuota(100_000);
    var table: [256][8]u8 = undefined;
    for (0..256) |tag| {
        var entry: [8]u8 = .{0x80} ** 8;
        var k: usize = 0;
        for (0..8) |j| {
            if ((tag >> @as(u3, @intCast(j))) & 1 != 0) {
                entry[k] = @intCast(j);
                k += 1;
            }
        }
        table[tag] = entry;
    }
    return table;
}

fn makeCountTable() [256]u8 {
    @setEvalBranchQuota(100_000);
    var table: [256]u8 = undefined;
    for (0..256) |tag| table[tag] = @popCount(tag);
    return table;
}

/// Compact the non-zero bytes of `source[0..8]` into the low bytes of the
/// result and compute the packed tag in one table shuffle.
pub inline fn compressWord(source: *const [16]u8) CompressedWord {
    const src: V16 = source.*;
    const tag = computeTag(source[0..wire.bytes_per_word]);
    return .{ .tag = tag, .payload = tbl(src, shuffle_table[tag]) };
}

/// Compute the Cap'n Proto packed tag for one word without per-byte branches.
inline fn computeTag(word: *const [8]u8) u8 {
    const w = std.mem.readInt(u64, word, .little);
    const zero_mask = ~(((w & 0x7f7f7f7f7f7f7f7f) +% 0x7f7f7f7f7f7f7f7f) | w | 0x7f7f7f7f7f7f7f7f) & 0x8080808080808080;
    const nonzero_mask = ~zero_mask & 0x8080808080808080;
    return @truncate(((nonzero_mask >> 7) *% 0x0102040810204080) >> 56);
}

inline fn tbl(src: V16, idx: V8) V8 {
    if (comptime enabled) {
        return asm ("tbl %[out].8b, {%[src].16b}, %[idx].8b"
            : [out] "=w" (-> V8),
            : [src] "w" (src),
              [idx] "w" (idx),
        );
    }
    var out: [8]u8 = undefined;
    for (0..8) |j| {
        const index = idx[j];
        out[j] = if (index < 16) src[index] else 0;
    }
    return out;
}

test "simd compression matches the scalar reference" {
    const testing = std.testing;
    var prng = std.Random.DefaultPrng.init(0x5eed_cafe);
    const random = prng.random();
    var source: [16]u8 = undefined;
    for (0..2000) |_| {
        random.bytes(&source);
        // Exercise zero-heavy and dense words.
        for (0..8) |j| {
            if (random.boolean() and random.boolean()) source[j] = 0;
        }

        const compressed = compressWord(&source);

        var tag: u8 = 0;
        var payload: [8]u8 = undefined;
        var payload_len: usize = 0;
        for (0..8) |j| {
            const b = source[j];
            if (b != 0) {
                tag |= @as(u8, 1) << @as(u3, @intCast(j));
                payload[payload_len] = b;
                payload_len += 1;
            }
        }
        try testing.expectEqual(tag, compressed.tag);
        try testing.expectEqual(@as(u8, @intCast(payload_len)), count_table[tag]);
        const compressed_bytes: [8]u8 = compressed.payload;
        try testing.expectEqualSlices(u8, payload[0..payload_len], compressed_bytes[0..payload_len]);
    }
}

test "tag computation covers every byte value" {
    const testing = std.testing;
    var word: [8]u8 = undefined;
    for (0..256) |value| {
        @memset(&word, 0);
        word[3] = @intCast(value);
        const expected: u8 = if (value == 0) 0 else 1 << 3;
        try testing.expectEqual(expected, computeTag(&word));
    }
}
