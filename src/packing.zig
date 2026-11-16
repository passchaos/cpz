const std = @import("std");
const wire = @import("wire.zig");
const zero = @import("zero.zig");
const packing_simd = @import("packing_simd.zig");

/// Low byte: payload length. Next byte: tag.
inline fn packWordFast(dest: []u8, out_i: usize, input: []const u8, i: usize) u16 {
    if (comptime packing_simd.use_in_packing) {
        if (input.len - i >= 16) {
            const compressed = packing_simd.compressWord(input[i..][0..16]);
            dest[out_i] = compressed.tag;
            const payload: *align(1) packing_simd.Payload = @ptrCast(dest.ptr + out_i + 1);
            payload.* = compressed.payload;
            return (@as(u16, compressed.tag) << 8) | packing_simd.count_table[compressed.tag];
        }
    }
    const word: [wire.bytes_per_word]u8 = input[i..][0..wire.bytes_per_word].*;
    var tag: u8 = 0;
    var payload_len: u8 = 0;
    dest[out_i] = 0;
    inline for (0..wire.bytes_per_word) |j| {
        const b = word[j];
        if (b != 0) {
            tag |= @as(u8, 1) << @as(u3, @intCast(j));
            dest[out_i + 1 + payload_len] = b;
            payload_len += 1;
        }
    }
    dest[out_i] = tag;
    return (@as(u16, tag) << 8) | payload_len;
}

pub const Error = error{
    PackedInputTruncated,
    PackedOutputLengthMismatch,
    PackedOutputTooSmall,
    PackedSizeOverflow,
    UnpackedInputNotWordAligned,
} || std.mem.Allocator.Error;

pub fn maxPackedSize(unpacked_len: usize) Error!usize {
    if (unpacked_len % wire.bytes_per_word != 0) return error.UnpackedInputNotWordAligned;
    const words = unpacked_len / wire.bytes_per_word;
    return std.math.mul(usize, words, wire.bytes_per_word + 2) catch return error.PackedSizeOverflow;
}

pub fn packedSize(unpacked_bytes: []const u8) Error!usize {
    if (unpacked_bytes.len % wire.bytes_per_word != 0) return error.UnpackedInputNotWordAligned;

    var packed_len: usize = 0;
    var i: usize = 0;
    while (i < unpacked_bytes.len) {
        var tag: u8 = 0;
        var payload_len: usize = 0;
        inline for (0..wire.bytes_per_word) |j| {
            const b = unpacked_bytes[i + j];
            if (b != 0) {
                tag |= @as(u8, 1) << @as(u3, @intCast(j));
                payload_len += 1;
            }
        }
        packed_len = std.math.add(usize, packed_len, 1 + payload_len) catch return error.PackedSizeOverflow;
        i += wire.bytes_per_word;

        if (tag == 0x00) {
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and isZeroWord(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            packed_len = std.math.add(usize, packed_len, 1) catch return error.PackedSizeOverflow;
        } else if (tag == 0xff) {
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and shouldCopyRaw(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            packed_len = std.math.add(usize, packed_len, 1 + run_words * wire.bytes_per_word) catch return error.PackedSizeOverflow;
        }
    }
    return packed_len;
}

pub fn unpackedSize(packed_bytes: []const u8) Error!usize {
    var out_len: usize = 0;
    var i: usize = 0;
    while (i < packed_bytes.len) {
        const tag = packed_bytes[i];
        i += 1;
        out_len = std.math.add(usize, out_len, wire.bytes_per_word) catch return error.PackedSizeOverflow;
        inline for (0..wire.bytes_per_word) |j| {
            if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                if (i >= packed_bytes.len) return error.PackedInputTruncated;
                i += 1;
            }
        }
        if (tag == 0x00) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const additional_bytes = @as(usize, packed_bytes[i]) * wire.bytes_per_word;
            i += 1;
            out_len = std.math.add(usize, out_len, additional_bytes) catch return error.PackedSizeOverflow;
        } else if (tag == 0xff) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const raw_bytes = @as(usize, packed_bytes[i]) * wire.bytes_per_word;
            i += 1;
            if (packed_bytes.len - i < raw_bytes) return error.PackedInputTruncated;
            i += raw_bytes;
            out_len = std.math.add(usize, out_len, raw_bytes) catch return error.PackedSizeOverflow;
        }
    }
    return out_len;
}

/// Cap'n Proto packing encoder. Input must be whole words.
///
/// The implementation keeps the hot path branch-light: collect the tag and
/// non-zero payload bytes for one word, then handle only the two special tags
/// (0x00 and 0xff). This mirrors the C++ format while exposing Zig slices.
pub fn pack(allocator: std.mem.Allocator, unpacked_bytes: []const u8) Error![]u8 {
    const max_len = try maxPackedSize(unpacked_bytes.len);
    const out = try allocator.alloc(u8, max_len);
    errdefer allocator.free(out);
    const written = try packInto(out, unpacked_bytes);
    if (written == max_len) return out;
    return allocator.realloc(out, written);
}

/// Encode into a caller-provided buffer. Returns bytes written. This avoids
/// allocator traffic for latency-sensitive packed streams.
pub noinline fn packInto(dest: []u8, unpacked_bytes: []const u8) Error!usize {
    if (unpacked_bytes.len % wire.bytes_per_word != 0) return error.UnpackedInputNotWordAligned;

    var out_i: usize = 0;
    var i: usize = 0;
    while (i < unpacked_bytes.len) {
        var tag: u8 = 0;
        if (dest.len - out_i >= wire.bytes_per_word + 1) {
            const packed_word = packWordFast(dest, out_i, unpacked_bytes, i);
            tag = @truncate(packed_word >> 8);
            out_i += 1 + @as(usize, @as(u8, @truncate(packed_word)));
        } else {
            var payload_len: usize = 0;
            var payload: [wire.bytes_per_word]u8 = undefined;
            inline for (0..wire.bytes_per_word) |j| {
                const b = unpacked_bytes[i + j];
                if (b != 0) {
                    tag |= @as(u8, 1) << @as(u3, @intCast(j));
                    payload[payload_len] = b;
                    payload_len += 1;
                }
            }
            out_i = try writePackedSlice(dest, out_i, &[_]u8{tag});
            out_i = try writePackedSlice(dest, out_i, payload[0..payload_len]);
        }
        i += wire.bytes_per_word;

        if (tag == 0x00) {
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and isZeroWord(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            out_i = try writePackedSlice(dest, out_i, &[_]u8{@intCast(run_words)});
        } else if (tag == 0xff) {
            const run_start = i;
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and shouldCopyRaw(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            out_i = try writePackedSlice(dest, out_i, &[_]u8{@intCast(run_words)});
            out_i = try writePackedSlice(dest, out_i, unpacked_bytes[run_start..i]);
        }
    }

    return out_i;
}

/// Encode whole words and stream packed bytes directly to a writer using a
/// small stack buffer.
pub noinline fn packToWriter(writer: *std.Io.Writer, unpacked_bytes: []const u8) (Error || std.Io.Writer.Error)!void {
    if (unpacked_bytes.len % wire.bytes_per_word != 0) return error.UnpackedInputNotWordAligned;

    var out_buf: [4096]u8 = undefined;
    var out_i: usize = 0;
    var i: usize = 0;
    while (i < unpacked_bytes.len) {
        var tag: u8 = 0;
        if (out_buf.len - out_i >= wire.bytes_per_word + 1) {
            const packed_word = packWordFast(out_buf[0..], out_i, unpacked_bytes, i);
            tag = @truncate(packed_word >> 8);
            out_i += 1 + @as(usize, @as(u8, @truncate(packed_word)));
        } else {
            var payload_len: usize = 0;
            var payload: [wire.bytes_per_word]u8 = undefined;
            inline for (0..wire.bytes_per_word) |j| {
                const b = unpacked_bytes[i + j];
                if (b != 0) {
                    tag |= @as(u8, 1) << @as(u3, @intCast(j));
                    payload[payload_len] = b;
                    payload_len += 1;
                }
            }
            out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, &[_]u8{tag});
            out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, payload[0..payload_len]);
        }
        i += wire.bytes_per_word;

        if (tag == 0x00) {
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and isZeroWord(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, &[_]u8{@intCast(run_words)});
        } else if (tag == 0xff) {
            const run_start = i;
            var run_words: usize = 0;
            while (i < unpacked_bytes.len and run_words < 255 and shouldCopyRaw(unpacked_bytes[i..][0..wire.bytes_per_word])) {
                i += wire.bytes_per_word;
                run_words += 1;
            }
            out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, &[_]u8{@intCast(run_words)});
            out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, unpacked_bytes[run_start..i]);
        }
    }

    if (out_i != 0) try writer.writeAll(out_buf[0..out_i]);
}

/// Encode whole words from an Io reader and stream packed bytes directly to a
/// writer. The input stream must end on a word boundary. This preserves the
/// same zero-run/raw-run encoding heuristic as pack() without requiring the
/// caller to materialize the whole unpacked byte sequence.
pub fn packReaderToWriter(reader: *std.Io.Reader, writer: *std.Io.Writer) (Error || std.Io.Reader.Error || std.Io.Writer.Error)!void {
    var in_buf: [4096]u8 = undefined;
    var in_len: usize = 0;
    var in_pos: usize = 0;
    var out_buf: [4096]u8 = undefined;
    var out_i: usize = 0;

    while (true) {
        if (in_pos == in_len) {
            in_len = try reader.readSliceShort(&in_buf);
            in_pos = 0;
            if (in_len == 0) break;
        }
        var i = in_pos;
        while (in_len - i >= wire.bytes_per_word) {
            var tag: u8 = 0;
            if (out_buf.len - out_i >= wire.bytes_per_word + 1) {
                const packed_word = packWordFast(out_buf[0..], out_i, in_buf[0..in_len], i);
                tag = @truncate(packed_word >> 8);
                out_i += 1 + @as(usize, @as(u8, @truncate(packed_word)));
            } else {
                var payload_len: usize = 0;
                var payload: [wire.bytes_per_word]u8 = undefined;
                inline for (0..wire.bytes_per_word) |j| {
                    const b = in_buf[i + j];
                    if (b != 0) {
                        tag |= @as(u8, 1) << @as(u3, @intCast(j));
                        payload[payload_len] = b;
                        payload_len += 1;
                    }
                }
                out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, &[_]u8{tag});
                out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, payload[0..payload_len]);
            }
            i += wire.bytes_per_word;

            if (tag == 0x00) {
                var run_words: usize = 0;
                while (in_len - i >= wire.bytes_per_word and run_words < 255 and isZeroWord(in_buf[i..][0..wire.bytes_per_word])) {
                    i += wire.bytes_per_word;
                    run_words += 1;
                }
                out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, &[_]u8{@intCast(run_words)});
            } else if (tag == 0xff) {
                const run_start = i;
                var run_words: usize = 0;
                while (in_len - i >= wire.bytes_per_word and run_words < 255 and shouldCopyRaw(in_buf[i..][0..wire.bytes_per_word])) {
                    i += wire.bytes_per_word;
                    run_words += 1;
                }
                out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, &[_]u8{@intCast(run_words)});
                out_i = try writeStreamingPackedSlice(writer, out_buf[0..], out_i, in_buf[run_start..i]);
            }
        }
        in_pos = i;
        if (in_pos != in_len) {
            const remaining = in_len - in_pos;
            std.mem.copyForwards(u8, in_buf[0..remaining], in_buf[in_pos..in_len]);
            in_len = remaining;
            in_pos = 0;
            const n = try reader.readSliceShort(in_buf[in_len..]);
            if (n == 0) {
                if (in_len != 0) return error.UnpackedInputNotWordAligned;
                break;
            }
            in_len += n;
        }
    }
    if (out_i != 0) try writer.writeAll(out_buf[0..out_i]);
}

const ReaderBuffer = struct {
    reader: *std.Io.Reader,
    buf: [4096]u8 = undefined,
    pos: usize = 0,
    len: usize = 0,

    fn refill(self: *ReaderBuffer) (Error || std.Io.Reader.Error)!bool {
        self.len = try self.reader.readSliceShort(&self.buf);
        self.pos = 0;
        return self.len != 0;
    }

    fn next(self: *ReaderBuffer) (Error || std.Io.Reader.Error)!?u8 {
        if (self.pos == self.len and !try self.refill()) return null;
        const b = self.buf[self.pos];
        self.pos += 1;
        return b;
    }

    fn take(self: *ReaderBuffer) (Error || std.Io.Reader.Error)!u8 {
        return (try self.next()) orelse error.PackedInputTruncated;
    }

    fn copyExact(self: *ReaderBuffer, dest: []u8) (Error || std.Io.Reader.Error)!void {
        var off: usize = 0;
        if (self.pos != self.len) {
            const chunk = @min(dest.len, self.len - self.pos);
            @memcpy(dest[0..chunk], self.buf[self.pos..][0..chunk]);
            self.pos += chunk;
            off = chunk;
        }
        if (off < dest.len) {
            self.reader.readSliceAll(dest[off..]) catch |err| switch (err) {
                error.EndOfStream => return error.PackedInputTruncated,
                else => |e| return e,
            };
            self.pos = 0;
            self.len = 0;
        }
    }
};

/// Decode a packed Cap'n Proto stream into a newly-allocated word-aligned byte
/// sequence. The returned slice length is always a multiple of 8.
pub fn unpack(allocator: std.mem.Allocator, packed_bytes: []const u8) Error![]u8 {
    const out_len = try unpackedSize(packed_bytes);
    const out = try allocator.alloc(u8, out_len);
    errdefer allocator.free(out);
    const written = try unpackInto(out, packed_bytes);
    if (written != out_len) return error.PackedOutputLengthMismatch;
    return out;
}

/// Decode into a caller-provided buffer. Returns bytes written.
pub noinline fn unpackInto(dest: []u8, packed_bytes: []const u8) Error!usize {
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
            zero.bytes(dest[out_i .. out_i + additional_bytes]);
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

/// Decode a packed Cap'n Proto byte slice directly to an Io writer without
/// allocating the complete unpacked output.
pub noinline fn unpackToWriter(writer: *std.Io.Writer, packed_bytes: []const u8) (Error || std.Io.Writer.Error)!void {
    var out_buf: [4096]u8 = undefined;
    var out_i: usize = 0;
    var i: usize = 0;
    while (i < packed_bytes.len) {
        const tag = packed_bytes[i];
        i += 1;

        if (out_buf.len - out_i < wire.bytes_per_word) {
            if (out_i != 0) {
                try writer.writeAll(out_buf[0..out_i]);
                out_i = 0;
            }
        }
        @memset(out_buf[out_i..][0..wire.bytes_per_word], 0);
        if (packed_bytes.len - i >= wire.bytes_per_word) {
            inline for (0..wire.bytes_per_word) |j| {
                if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                    out_buf[out_i + j] = packed_bytes[i];
                    i += 1;
                }
            }
        } else {
            inline for (0..wire.bytes_per_word) |j| {
                if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                    if (i >= packed_bytes.len) return error.PackedInputTruncated;
                    out_buf[out_i + j] = packed_bytes[i];
                    i += 1;
                }
            }
        }
        out_i += wire.bytes_per_word;

        if (tag == 0x00) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            var remaining = @as(usize, packed_bytes[i]) * wire.bytes_per_word;
            i += 1;
            while (remaining != 0) {
                if (out_i == out_buf.len) {
                    try writer.writeAll(out_buf[0..out_i]);
                    out_i = 0;
                }
                const chunk = @min(remaining, out_buf.len - out_i);
                zero.bytes(out_buf[out_i..][0..chunk]);
                out_i += chunk;
                remaining -= chunk;
            }
        } else if (tag == 0xff) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const raw_bytes = @as(usize, packed_bytes[i]) * wire.bytes_per_word;
            i += 1;
            if (packed_bytes.len - i < raw_bytes) return error.PackedInputTruncated;
            var src = packed_bytes[i .. i + raw_bytes];
            while (src.len != 0) {
                if (out_i == out_buf.len) {
                    try writer.writeAll(out_buf[0..out_i]);
                    out_i = 0;
                }
                const chunk = @min(src.len, out_buf.len - out_i);
                @memcpy(out_buf[out_i..][0..chunk], src[0..chunk]);
                out_i += chunk;
                src = src[chunk..];
            }
            i += raw_bytes;
        }
    }
    if (out_i != 0) try writer.writeAll(out_buf[0..out_i]);
}

/// Decode a packed Cap'n Proto stream from an Io reader directly to an Io
/// writer without allocating the complete packed or unpacked byte sequence.
pub noinline fn unpackReaderToWriter(reader: *std.Io.Reader, writer: *std.Io.Writer) (Error || std.Io.Reader.Error || std.Io.Writer.Error)!void {
    var in = ReaderBuffer{ .reader = reader };
    var out_buf: [4096]u8 = undefined;
    var out_i: usize = 0;
    while (true) {
        if (in.pos == in.len and !try in.refill()) break;
        const tag = in.buf[in.pos];
        in.pos += 1;

        if (out_buf.len - out_i < wire.bytes_per_word) {
            if (out_i != 0) {
                try writer.writeAll(out_buf[0..out_i]);
                out_i = 0;
            }
        }
        @memset(out_buf[out_i..][0..wire.bytes_per_word], 0);
        if (in.len - in.pos >= wire.bytes_per_word) {
            inline for (0..wire.bytes_per_word) |j| {
                if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                    out_buf[out_i + j] = in.buf[in.pos];
                    in.pos += 1;
                }
            }
        } else {
            inline for (0..wire.bytes_per_word) |j| {
                if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                    out_buf[out_i + j] = try in.take();
                }
            }
        }
        out_i += wire.bytes_per_word;

        if (tag == 0x00) {
            var remaining = @as(usize, try in.take()) * wire.bytes_per_word;
            while (remaining != 0) {
                if (out_i == out_buf.len) {
                    try writer.writeAll(out_buf[0..out_i]);
                    out_i = 0;
                }
                const chunk = @min(remaining, out_buf.len - out_i);
                zero.bytes(out_buf[out_i..][0..chunk]);
                out_i += chunk;
                remaining -= chunk;
            }
        } else if (tag == 0xff) {
            var remaining = @as(usize, try in.take()) * wire.bytes_per_word;
            while (remaining != 0) {
                if (out_i == out_buf.len) {
                    try writer.writeAll(out_buf[0..out_i]);
                    out_i = 0;
                }
                const chunk = @min(remaining, out_buf.len - out_i);
                try in.copyExact(out_buf[out_i..][0..chunk]);
                out_i += chunk;
                remaining -= chunk;
            }
        }
    }
    if (out_i != 0) try writer.writeAll(out_buf[0..out_i]);
}

fn writePackedSlice(dest: []u8, out_i: usize, bytes: []const u8) Error!usize {
    if (dest.len - out_i < bytes.len) return error.PackedOutputTooSmall;
    @memcpy(dest[out_i..][0..bytes.len], bytes);
    return out_i + bytes.len;
}

fn writeStreamingPackedSlice(writer: *std.Io.Writer, out_buf: []u8, out_i: usize, bytes: []const u8) (Error || std.Io.Writer.Error)!usize {
    if (bytes.len > out_buf.len) {
        if (out_i != 0) {
            try writer.writeAll(out_buf[0..out_i]);
        }
        try writer.writeAll(bytes);
        return 0;
    }
    var next = out_i;
    if (out_buf.len - next < bytes.len) {
        try writer.writeAll(out_buf[0..next]);
        next = 0;
    }
    @memcpy(out_buf[next..][0..bytes.len], bytes);
    return next + bytes.len;
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
    try testing.expectEqual(packed1.len, try packedSize(&unpacked1));
    try testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x03 }, packed1);
    const round1 = try unpack(allocator, packed1);
    defer allocator.free(round1);
    try testing.expectEqualSlices(u8, &unpacked1, round1);

    const unpacked2 = [_]u8{0x8a} ** 32;
    const packed2 = try pack(allocator, &unpacked2);
    defer allocator.free(packed2);
    try testing.expectEqual(packed2.len, try packedSize(&unpacked2));
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
    try testing.expectEqual(packed_out.len, try packedSize(&unpacked));
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
    try testing.expectEqual(expected.len, try packedSize(&unpacked));
    try testing.expectEqual(unpacked.len, try unpackedSize(expected));

    const buffer = try allocator.alloc(u8, try maxPackedSize(unpacked.len));
    defer allocator.free(buffer);
    const written = try packInto(buffer, &unpacked);
    try testing.expectEqualSlices(u8, expected, buffer[0..written]);
    try testing.expectError(error.PackedOutputTooSmall, packInto(buffer[0 .. written - 1], &unpacked));
    try testing.expectError(error.UnpackedInputNotWordAligned, maxPackedSize(unpacked.len - 1));
    try testing.expectError(error.UnpackedInputNotWordAligned, packedSize(unpacked[0 .. unpacked.len - 1]));
    try testing.expectError(error.PackedInputTruncated, unpackedSize(expected[0 .. expected.len - 1]));
    const huge_aligned_len = std.math.maxInt(usize) - (std.math.maxInt(usize) % wire.bytes_per_word);
    try testing.expectError(error.PackedSizeOverflow, maxPackedSize(huge_aligned_len));
}

test "packToWriter matches allocating encoder" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked = ([_]u8{0x8a} ** 4096) ++ ([_]u8{0} ** 64) ++ [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
    };
    const expected = try pack(allocator, &unpacked);
    defer allocator.free(expected);

    var buffer: [8192]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try packToWriter(&writer, &unpacked);
    try testing.expectEqualSlices(u8, expected, std.Io.Writer.buffered(&writer));
}

test "packReaderToWriter matches allocating encoder" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked = ([_]u8{0x8a} ** 4096) ++ ([_]u8{0} ** 64) ++ [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
    };
    const expected = try pack(allocator, &unpacked);
    defer allocator.free(expected);

    var reader = std.Io.Reader.fixed(&unpacked);
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try packReaderToWriter(&reader, &writer);
    try testing.expectEqualSlices(u8, expected, std.Io.Writer.buffered(&writer));

    var unaligned_reader = std.Io.Reader.fixed(unpacked[0 .. unpacked.len - 1]);
    var unaligned_writer = std.Io.Writer.fixed(&buffer);
    try testing.expectError(error.UnpackedInputNotWordAligned, packReaderToWriter(&unaligned_reader, &unaligned_writer));
}

test "unpackToWriter matches allocating decoder" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked = ([_]u8{0x8a} ** 4096) ++ ([_]u8{0} ** 64) ++ [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
    };
    const packed_bytes = try pack(allocator, &unpacked);
    defer allocator.free(packed_bytes);

    const expected = try unpack(allocator, packed_bytes);
    defer allocator.free(expected);
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try unpackToWriter(&writer, packed_bytes);
    try testing.expectEqualSlices(u8, expected, std.Io.Writer.buffered(&writer));

    var truncated_writer = std.Io.Writer.fixed(&buffer);
    try testing.expectError(error.PackedInputTruncated, unpackToWriter(&truncated_writer, packed_bytes[0 .. packed_bytes.len - 1]));
}

test "unpackReaderToWriter streams packed input to writer" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const unpacked = ([_]u8{0x8a} ** 4096) ++ ([_]u8{0} ** 64) ++ [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
    };
    const packed_bytes = try pack(allocator, &unpacked);
    defer allocator.free(packed_bytes);

    var reader = std.Io.Reader.fixed(packed_bytes);
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try unpackReaderToWriter(&reader, &writer);
    try testing.expectEqualSlices(u8, &unpacked, std.Io.Writer.buffered(&writer));

    var truncated_reader = std.Io.Reader.fixed(packed_bytes[0 .. packed_bytes.len - 1]);
    var truncated_writer = std.Io.Writer.fixed(&buffer);
    try testing.expectError(error.PackedInputTruncated, unpackReaderToWriter(&truncated_reader, &truncated_writer));
}
