const std = @import("std");
const packing = @import("packing.zig");
const wire = @import("wire.zig");

pub const Segment = []u8;
pub const ConstSegment = []const u8;
pub const max_segment_count: usize = 65_536;

pub const Error = error{
    EmptyMessage,
    SegmentNotWordAligned,
    TooManySegments,
    SegmentTooLarge,
    MessageTruncated,
    SegmentTableTruncated,
    SegmentTableOverflow,
    SerializedOutputTooSmall,
    SerializedSizeOverflow,
    MessageNotWordAligned,
} || packing.Error || std.mem.Allocator.Error;

pub const FlatMessage = struct {
    /// Owned copy of the complete serialized message bytes consumed by this
    /// reader. Segment slices point into this allocation.
    bytes: []u8,
    segments: []ConstSegment,
    source_consumed_len: usize = 0,
    consumed_len: usize,

    pub fn deinit(self: *FlatMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.segments);
        allocator.free(self.bytes);
        self.* = undefined;
    }

    pub fn consumedBytes(self: FlatMessage) []const u8 {
        return self.bytes[0..self.consumed_len];
    }

    pub fn sourceConsumedLen(self: FlatMessage) usize {
        return if (self.source_consumed_len != 0) self.source_consumed_len else self.consumed_len;
    }
};

pub const FlatMessageView = struct {
    /// Segment slices point into caller-owned serialized bytes. The caller must
    /// keep those bytes alive while this view is used.
    bytes: []const u8,
    segments: []ConstSegment,
    consumed_len: usize,

    pub fn deinit(self: *FlatMessageView, allocator: std.mem.Allocator) void {
        allocator.free(self.segments);
        self.* = undefined;
    }

    pub fn consumedBytes(self: FlatMessageView) []const u8 {
        return self.bytes[0..self.consumed_len];
    }

    pub fn sourceConsumedLen(self: FlatMessageView) usize {
        return self.consumed_len;
    }
};

pub fn computeSerializedSize(segments: []const ConstSegment) Error!usize {
    if (segments.len == 0) return error.EmptyMessage;
    if (segments.len > max_segment_count) return error.TooManySegments;

    var words_sum: usize = 0;
    for (segments) |segment| {
        if (segment.len % wire.bytes_per_word != 0) return error.SegmentNotWordAligned;
        const words = segment.len / wire.bytes_per_word;
        if (words > std.math.maxInt(u32)) return error.SegmentTooLarge;
        words_sum = std.math.add(usize, words_sum, words) catch return error.SerializedSizeOverflow;
    }

    const table_words = (try segmentTableByteLen(segments.len)) / wire.bytes_per_word;
    const total_words = std.math.add(usize, table_words, words_sum) catch return error.SerializedSizeOverflow;
    return std.math.mul(usize, total_words, wire.bytes_per_word) catch return error.SerializedSizeOverflow;
}

pub fn computeSerializedSizeInWords(segments: []const ConstSegment) Error!usize {
    return (try computeSerializedSize(segments)) / wire.bytes_per_word;
}

pub fn segmentTableWords(segment_count: usize) usize {
    // 4 bytes for segment_count_minus_one plus 4 bytes per segment, rounded up
    // to a word boundary.
    return (4 + 4 * segment_count + 7) / 8;
}

pub fn writeSegmentTable(dest: []u8, segments: []const ConstSegment) Error!usize {
    if (segments.len == 0) return error.EmptyMessage;
    if (segments.len > max_segment_count) return error.TooManySegments;
    const table_len = try segmentTableByteLen(segments.len);
    if (dest.len < table_len) return error.SegmentTableTruncated;
    @memset(dest[0..table_len], 0);

    writeU32(dest[0..4], @intCast(segments.len - 1));
    var off: usize = 4;
    for (segments) |segment| {
        if (segment.len % wire.bytes_per_word != 0) return error.SegmentNotWordAligned;
        const words = segment.len / wire.bytes_per_word;
        if (words > std.math.maxInt(u32)) return error.SegmentTooLarge;
        writeU32(dest[off..][0..4], @intCast(words));
        off += 4;
    }
    return table_len;
}

pub fn serializeSegmentTable(allocator: std.mem.Allocator, segments: []const ConstSegment) Error![]u8 {
    const table_len = try segmentTableByteLen(segments.len);
    const table = try allocator.alloc(u8, table_len);
    errdefer allocator.free(table);
    _ = try writeSegmentTable(table, segments);
    return table;
}

/// Serialize segments using Cap'n Proto's standard stream framing.
pub fn messageToFlatBytes(allocator: std.mem.Allocator, segments: []const ConstSegment) Error![]u8 {
    const total_len = try computeSerializedSize(segments);
    const out = try allocator.alloc(u8, total_len);
    errdefer allocator.free(out);

    _ = try messageToFlatBytesInto(out, segments);
    return out;
}

/// Serialize segments into a caller-provided buffer using Cap'n Proto's
/// standard stream framing. Returns the number of bytes written. This avoids
/// allocating a complete flat message buffer on hot paths.
pub fn messageToFlatBytesInto(dest: []u8, segments: []const ConstSegment) Error!usize {
    const total_len = try computeSerializedSize(segments);
    if (dest.len < total_len) return error.SerializedOutputTooSmall;

    const table_len = try writeSegmentTable(dest[0..total_len], segments);
    var off = table_len;
    for (segments) |segment| {
        @memcpy(dest[off .. off + segment.len], segment);
        off += segment.len;
    }
    return total_len;
}

/// Write standard stream framing directly to an Io writer without first
/// allocating a complete flat message buffer.
pub fn writeMessageToWriter(writer: *std.Io.Writer, segments: []const ConstSegment) (Error || std.Io.Writer.Error)!void {
    _ = try computeSerializedSize(segments);

    var word_buf: [4]u8 = undefined;
    writeU32(&word_buf, @intCast(segments.len - 1));
    try writer.writeAll(&word_buf);
    for (segments) |segment| {
        writeU32(&word_buf, @intCast(segment.len / wire.bytes_per_word));
        try writer.writeAll(&word_buf);
    }
    if (segments.len % 2 == 0) {
        try writer.writeAll(&[_]u8{0} ** 4);
    }
    for (segments) |segment| {
        try writer.writeAll(segment);
    }
}

/// Serialize segments using standard stream framing, then apply Cap'n Proto
/// packing to the framed bytes. This is the format used by C++'s packed
/// stream helpers.
pub fn messageToPackedBytes(allocator: std.mem.Allocator, segments: []const ConstSegment) Error![]u8 {
    const flat = try messageToFlatBytes(allocator, segments);
    defer allocator.free(flat);
    return packing.pack(allocator, flat);
}

/// Serialize segments as a packed stream into caller-provided buffers. The
/// `table_buffer` stores the temporary flat segment table, while `dest`
/// receives the packed stream bytes. Returns bytes written to `dest`.
pub fn messageToPackedBytesInto(table_buffer: []u8, dest: []u8, segments: []const ConstSegment) Error!usize {
    _ = try computeSerializedSize(segments);
    const table_len = try writeSegmentTable(table_buffer, segments);
    var out_i: usize = 0;

    const packed_table_len = try packing.packInto(dest[out_i..], table_buffer[0..table_len]);
    out_i += packed_table_len;
    for (segments) |segment| {
        const packed_segment_len = try packing.packInto(dest[out_i..], segment);
        out_i += packed_segment_len;
    }
    return out_i;
}

/// Write packed stream framing directly to an Io writer. This allocates only
/// the bounded segment table, then streams packed table/segment chunks.
pub fn writePackedMessageToWriter(allocator: std.mem.Allocator, writer: *std.Io.Writer, segments: []const ConstSegment) (Error || std.Io.Writer.Error)!void {
    _ = try computeSerializedSize(segments);
    const table = try serializeSegmentTable(allocator, segments);
    defer allocator.free(table);
    try packing.packToWriter(writer, table);
    for (segments) |segment| {
        try packing.packToWriter(writer, segment);
    }
}

/// Write packed stream framing directly to an Io writer using caller-provided
/// scratch space for the segment table. This avoids allocator traffic on the
/// packed writer path while still streaming table and segment chunks.
pub fn writePackedMessageToWriterWithTableBuffer(table_buffer: []u8, writer: *std.Io.Writer, segments: []const ConstSegment) (Error || std.Io.Writer.Error)!void {
    _ = try computeSerializedSize(segments);
    const table_len = try writeSegmentTable(table_buffer, segments);
    try packing.packToWriter(writer, table_buffer[0..table_len]);
    for (segments) |segment| {
        try packing.packToWriter(writer, segment);
    }
}

/// Parse a flat serialized message and copy exactly the consumed message bytes.
/// Extra trailing data is allowed and reported via `consumed_len`.
pub fn readFlatMessage(allocator: std.mem.Allocator, bytes: []const u8) Error!FlatMessage {
    const expected_len = try expectedSize(bytes);
    if (bytes.len < expected_len) return error.MessageTruncated;
    const owned = try allocator.dupe(u8, bytes[0..expected_len]);
    return readOwnedFlatMessageWithSourceConsumedLen(allocator, owned, expected_len);
}

/// Parse a flat serialized message without copying message bytes. Segment
/// slices point directly into `bytes`; only the segment slice table is
/// allocated. Extra trailing data is allowed and reported via `consumed_len`.
pub fn readFlatMessageView(allocator: std.mem.Allocator, bytes: []const u8) Error!FlatMessageView {
    const expected_len = try expectedSize(bytes);
    if (bytes.len < expected_len) return error.MessageTruncated;
    const table = try parseSegmentTable(bytes[0..expected_len]);
    const segments = try allocator.alloc(ConstSegment, table.segment_count);
    errdefer allocator.free(segments);

    var off = table.table_len;
    for (0..table.segment_count) |idx| {
        const words = readU32(bytes[4 + idx * 4 ..][0..4]);
        const len = @as(usize, words) * wire.bytes_per_word;
        segments[idx] = bytes[off .. off + len];
        off += len;
    }

    return .{ .bytes = bytes, .segments = segments, .consumed_len = expected_len };
}

/// Parse one packed Cap'n Proto stream message from a byte slice. Decoding
/// stops exactly when the unpacked stream framing says the first message is
/// complete; extra trailing packed data is allowed. The returned FlatMessage
/// owns the unpacked flat bytes for the consumed message and its segment
/// slices point into that allocation.
pub fn readPackedMessage(allocator: std.mem.Allocator, packed_bytes: []const u8) Error!FlatMessage {
    var unpacked = std.ArrayList(u8).empty;
    errdefer unpacked.deinit(allocator);

    var i: usize = 0;
    while (true) {
        if (i >= packed_bytes.len) return error.MessageTruncated;
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
        try unpacked.appendSlice(allocator, &word);

        if (tag == 0x00) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const additional_words = @as(usize, packed_bytes[i]);
            i += 1;
            try unpacked.appendNTimes(allocator, 0, additional_words * wire.bytes_per_word);
        } else if (tag == 0xff) {
            if (i >= packed_bytes.len) return error.PackedInputTruncated;
            const raw_words = @as(usize, packed_bytes[i]);
            i += 1;
            const raw_bytes = raw_words * wire.bytes_per_word;
            if (packed_bytes.len - i < raw_bytes) return error.PackedInputTruncated;
            try unpacked.appendSlice(allocator, packed_bytes[i .. i + raw_bytes]);
            i += raw_bytes;
        }

        if (unpacked.items.len >= wire.bytes_per_word) {
            const expected_len = try expectedSize(unpacked.items);
            if (unpacked.items.len >= expected_len) {
                if (unpacked.items.len != expected_len) return error.PackedOutputLengthMismatch;
                const owned = try unpacked.toOwnedSlice(allocator);
                return readOwnedFlatMessageWithSourceConsumedLen(allocator, owned, i);
            }
        }
    }
}

/// Read one packed stream-framed message from an Io reader. Decoding stops
/// exactly when the unpacked stream framing says the message is complete,
/// leaving any following bytes buffered for the next message.
pub fn readPackedMessageFromReader(allocator: std.mem.Allocator, reader: *std.Io.Reader) (Error || std.Io.Reader.Error)!FlatMessage {
    var unpacked = std.ArrayList(u8).empty;
    errdefer unpacked.deinit(allocator);
    var source_consumed_len: usize = 0;

    while (true) {
        const tag = try takePackedByteCount(reader, &source_consumed_len);
        var word = [_]u8{0} ** wire.bytes_per_word;
        inline for (0..wire.bytes_per_word) |j| {
            if ((tag & (@as(u8, 1) << @as(u3, @intCast(j)))) != 0) {
                word[j] = try takePackedByteCount(reader, &source_consumed_len);
            }
        }
        try unpacked.appendSlice(allocator, &word);

        if (tag == 0x00) {
            const additional_words = @as(usize, try takePackedByteCount(reader, &source_consumed_len));
            try unpacked.appendNTimes(allocator, 0, additional_words * wire.bytes_per_word);
        } else if (tag == 0xff) {
            const raw_words = @as(usize, try takePackedByteCount(reader, &source_consumed_len));
            const raw_bytes = raw_words * wire.bytes_per_word;
            const dest = try unpacked.addManyAsSlice(allocator, raw_bytes);
            try readPackedExactCount(reader, dest, &source_consumed_len);
        }

        if (unpacked.items.len >= wire.bytes_per_word) {
            const expected_len = try expectedSize(unpacked.items);
            if (unpacked.items.len >= expected_len) {
                if (unpacked.items.len != expected_len) return error.PackedOutputLengthMismatch;
                const owned = try unpacked.toOwnedSlice(allocator);
                return readOwnedFlatMessageWithSourceConsumedLen(allocator, owned, source_consumed_len);
            }
        }
    }
}

/// Read one standard stream-framed message from an Io reader. The returned
/// FlatMessage owns the exact bytes consumed for that message.
pub fn readMessageFromReader(allocator: std.mem.Allocator, reader: *std.Io.Reader) (Error || std.Io.Reader.Error)!FlatMessage {
    var first_word: [wire.bytes_per_word]u8 = undefined;
    reader.readSliceAll(&first_word) catch |err| switch (err) {
        error.EndOfStream => return error.MessageTruncated,
        else => |e| return e,
    };

    const table_len = try expectedSize(&first_word);
    var table = try allocator.alloc(u8, table_len);
    defer allocator.free(table);
    @memcpy(table[0..wire.bytes_per_word], &first_word);
    if (table_len > wire.bytes_per_word) {
        reader.readSliceAll(table[wire.bytes_per_word..]) catch |err| switch (err) {
            error.EndOfStream => return error.MessageTruncated,
            else => |e| return e,
        };
    }

    const expected_len = try expectedSize(table);
    const owned = try allocator.alloc(u8, expected_len);
    errdefer allocator.free(owned);
    @memcpy(owned[0..table_len], table);
    if (expected_len > table_len) {
        reader.readSliceAll(owned[table_len..]) catch |err| switch (err) {
            error.EndOfStream => return error.MessageTruncated,
            else => |e| return e,
        };
    }
    return readOwnedFlatMessageWithSourceConsumedLen(allocator, owned, expected_len);
}

fn takePackedByte(reader: *std.Io.Reader) (Error || std.Io.Reader.Error)!u8 {
    return reader.takeByte() catch |err| switch (err) {
        error.EndOfStream => error.MessageTruncated,
        else => |e| e,
    };
}

fn takePackedByteCount(reader: *std.Io.Reader, source_consumed_len: *usize) (Error || std.Io.Reader.Error)!u8 {
    const byte = try takePackedByte(reader);
    source_consumed_len.* += 1;
    return byte;
}

fn readPackedExact(reader: *std.Io.Reader, dest: []u8) (Error || std.Io.Reader.Error)!void {
    reader.readSliceAll(dest) catch |err| switch (err) {
        error.EndOfStream => return error.MessageTruncated,
        else => |e| return e,
    };
}

fn readPackedExactCount(reader: *std.Io.Reader, dest: []u8, source_consumed_len: *usize) (Error || std.Io.Reader.Error)!void {
    try readPackedExact(reader, dest);
    source_consumed_len.* += dest.len;
}

fn readOwnedFlatMessageWithSourceConsumedLen(allocator: std.mem.Allocator, owned: []u8, source_consumed_len: usize) Error!FlatMessage {
    errdefer allocator.free(owned);

    const expected_len = try expectedSize(owned);
    if (owned.len < expected_len) return error.MessageTruncated;
    const table = try parseSegmentTable(owned[0..expected_len]);
    const segments = try allocator.alloc(ConstSegment, table.segment_count);
    errdefer allocator.free(segments);

    var off = table.table_len;
    for (0..table.segment_count) |idx| {
        const words = readU32(owned[4 + idx * 4 ..][0..4]);
        const len = @as(usize, words) * wire.bytes_per_word;
        segments[idx] = owned[off .. off + len];
        off += len;
    }

    return .{ .bytes = owned, .segments = segments, .source_consumed_len = source_consumed_len, .consumed_len = expected_len };
}

/// Return exact total size if enough prefix is available to read the whole
/// segment table; otherwise return the minimum bytes still required to finish
/// reading the table. This follows the intent of Cap'n Proto's
/// expectedSizeInWordsFromPrefix() but returns bytes for Zig slice ergonomics.
pub fn expectedSize(prefix: []const u8) Error!usize {
    if (prefix.len < 4) return 8;
    const segment_count_minus_one = readU32(prefix[0..4]);
    const segment_count = std.math.add(usize, @as(usize, segment_count_minus_one), 1) catch return error.SegmentTableOverflow;
    if (segment_count > max_segment_count) return error.TooManySegments;
    const table_len = try segmentTableByteLen(segment_count);
    if (prefix.len < table_len) return table_len;

    var total_words = table_len / wire.bytes_per_word;
    var off: usize = 4;
    for (0..segment_count) |_| {
        const words = readU32(prefix[off..][0..4]);
        total_words = std.math.add(usize, total_words, words) catch return error.SerializedSizeOverflow;
        off += 4;
    }
    return std.math.mul(usize, total_words, wire.bytes_per_word) catch return error.SerializedSizeOverflow;
}

/// Like expectedSize(), but returns a word count for parity with the C++ helper
/// expectedSizeInWordsFromPrefix().
pub fn expectedSizeInWordsFromPrefix(prefix: []const u8) Error!usize {
    return (try expectedSize(prefix)) / wire.bytes_per_word;
}

pub fn parseSegmentTable(bytes: []const u8) Error!struct { segment_count: usize, table_len: usize } {
    if (bytes.len < 8) return error.SegmentTableTruncated;
    if (bytes.len % wire.bytes_per_word != 0) return error.MessageNotWordAligned;
    const segment_count = std.math.add(usize, @as(usize, readU32(bytes[0..4])), 1) catch return error.SegmentTableOverflow;
    if (segment_count > max_segment_count) return error.TooManySegments;
    const table_len = try segmentTableByteLen(segment_count);
    if (bytes.len < table_len) return error.SegmentTableTruncated;
    return .{ .segment_count = segment_count, .table_len = table_len };
}

pub fn segmentTableByteLen(segment_count: usize) Error!usize {
    if (segment_count == 0) return error.EmptyMessage;
    if (segment_count > max_segment_count) return error.TooManySegments;
    const size_words_bytes = std.math.mul(usize, segment_count, 4) catch return error.SegmentTableOverflow;
    const unpadded = std.math.add(usize, 4, size_words_bytes) catch return error.SegmentTableOverflow;
    const padded = std.math.add(usize, unpadded, wire.bytes_per_word - 1) catch return error.SegmentTableOverflow;
    return (padded / wire.bytes_per_word) * wire.bytes_per_word;
}

inline fn readU32(bytes: *const [4]u8) u32 {
    return std.mem.readInt(u32, bytes, .little);
}

inline fn writeU32(bytes: *[4]u8, value: u32) void {
    std.mem.writeInt(u32, bytes, value, .little);
}

test "standard stream framing serializes single segment" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const segment = [_]u8{0} ** 16;
    const trailer = [_]u8{ 0xaa, 0xbb };
    const segments = [_]ConstSegment{&segment};
    const bytes = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(bytes);
    const combined = try std.mem.concat(allocator, u8, &.{ bytes, &trailer });
    defer allocator.free(combined);

    try testing.expectEqual(@as(usize, 24), bytes.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 0, 0, 0, 2, 0, 0, 0 }, bytes[0..8]);
    try testing.expectEqualSlices(u8, &segment, bytes[8..]);
    var stack_bytes: [24]u8 = undefined;
    try testing.expectEqual(bytes.len, try messageToFlatBytesInto(&stack_bytes, &segments));
    try testing.expectEqualSlices(u8, bytes, &stack_bytes);
    var short_stack: [23]u8 = undefined;
    try testing.expectError(error.SerializedOutputTooSmall, messageToFlatBytesInto(&short_stack, &segments));

    var flat = try readFlatMessage(allocator, combined);
    defer flat.deinit(allocator);
    try testing.expectEqual(@as(usize, bytes.len), flat.consumed_len);
    try testing.expectEqual(bytes.len, flat.sourceConsumedLen());
    try testing.expectEqualSlices(u8, bytes, flat.consumedBytes());
    try testing.expectEqual(bytes.len, flat.bytes.len);
    try testing.expectEqual(@as(usize, 1), flat.segments.len);
    try testing.expectEqualSlices(u8, &segment, flat.segments[0]);
}

test "flat message view parses without copying segment bytes" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const segment = [_]u8{0x42} ** 16;
    const trailer = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    const segments = [_]ConstSegment{&segment};
    const bytes = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(bytes);
    const combined = try std.mem.concat(allocator, u8, &.{ bytes, &trailer });
    defer allocator.free(combined);

    var view = try readFlatMessageView(allocator, combined);
    defer view.deinit(allocator);
    try testing.expectEqual(bytes.len, view.consumed_len);
    try testing.expectEqual(bytes.len, view.sourceConsumedLen());
    try testing.expectEqualSlices(u8, bytes, view.consumedBytes());
    try testing.expectEqual(@as(usize, 1), view.segments.len);
    try testing.expectEqualSlices(u8, &segment, view.segments[0]);
    try testing.expectEqual(@intFromPtr(combined.ptr) + 8, @intFromPtr(view.segments[0].ptr));
}

test "standard stream framing serializes even segment count with padding" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s0 = [_]u8{0xaa} ** 8;
    const s1 = [_]u8{0xbb} ** 16;
    const segments = [_]ConstSegment{ &s0, &s1 };
    const bytes = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(bytes);

    try testing.expectEqualSlices(u8, &[_]u8{ 1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0 }, bytes[0..16]);
    try testing.expectEqualSlices(u8, &s0, bytes[16..24]);
    try testing.expectEqualSlices(u8, &s1, bytes[24..40]);
    try testing.expectEqual(@as(usize, 40), try expectedSize(bytes[0..16]));
    try testing.expectEqual(@as(usize, 5), try expectedSizeInWordsFromPrefix(bytes[0..16]));
    try testing.expectEqual(@as(usize, 1), try expectedSizeInWordsFromPrefix(bytes[0..0]));
}

test "standard stream framing writes directly to Io writer" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s0 = [_]u8{0xaa} ** 8;
    const s1 = [_]u8{0xbb} ** 16;
    const segments = [_]ConstSegment{ &s0, &s1 };

    const expected = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(expected);

    var buffer: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try writeMessageToWriter(&writer, &segments);
    try testing.expectEqualSlices(u8, expected, std.Io.Writer.buffered(&writer));

    var small: [8]u8 = undefined;
    var small_writer = std.Io.Writer.fixed(&small);
    try testing.expectError(error.WriteFailed, writeMessageToWriter(&small_writer, &segments));
}

test "standard stream framing reads one message from Io reader" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s0 = [_]u8{0xaa} ** 8;
    const s1 = [_]u8{0xbb} ** 16;
    const trailer = [_]u8{ 0x99, 0x88, 0x77 };
    const segments = [_]ConstSegment{ &s0, &s1 };
    const flat = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(flat);
    const with_trailer = try std.mem.concat(allocator, u8, &.{ flat, &trailer });
    defer allocator.free(with_trailer);

    var reader = std.Io.Reader.fixed(with_trailer);
    var parsed = try readMessageFromReader(allocator, &reader);
    defer parsed.deinit(allocator);
    try testing.expectEqual(flat.len, parsed.consumed_len);
    try testing.expectEqual(flat.len, parsed.sourceConsumedLen());
    try testing.expectEqualSlices(u8, &s0, parsed.segments[0]);
    try testing.expectEqualSlices(u8, &s1, parsed.segments[1]);
    try testing.expectEqualSlices(u8, &trailer, reader.buffered());

    var truncated_reader = std.Io.Reader.fixed(flat[0 .. flat.len - 1]);
    try testing.expectError(error.MessageTruncated, readMessageFromReader(allocator, &truncated_reader));
}

test "segment table rejects excessive segment counts before allocation" {
    const testing = std.testing;

    var too_many = [_]u8{0} ** 8;
    writeU32(too_many[0..4], @intCast(max_segment_count));
    try testing.expectError(error.TooManySegments, expectedSize(&too_many));
    try testing.expectError(error.TooManySegments, parseSegmentTable(&too_many));

    var max_prefix = [_]u8{0} ** 8;
    writeU32(max_prefix[0..4], @intCast(max_segment_count - 1));
    try testing.expectEqual(try segmentTableByteLen(max_segment_count), try expectedSize(&max_prefix));
    try testing.expectEqual((try segmentTableByteLen(max_segment_count)) / wire.bytes_per_word, try expectedSizeInWordsFromPrefix(&max_prefix));
}

test "packed stream framing round-trips through unpacked parser" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s0 = [_]u8{
        0x08, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00,
        0x19, 0x00, 0x00, 0x00, 0xaa, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    const s1 = [_]u8{0x8a} ** 16;
    const segments = [_]ConstSegment{ &s0, &s1 };

    const flat = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(flat);
    const packed_bytes = try messageToPackedBytes(allocator, &segments);
    defer allocator.free(packed_bytes);
    try testing.expect(packed_bytes.len < flat.len);

    var parsed = try readPackedMessage(allocator, packed_bytes);
    defer parsed.deinit(allocator);
    try testing.expectEqual(flat.len, parsed.consumed_len);
    try testing.expectEqual(packed_bytes.len, parsed.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, parsed.consumedBytes());
    try testing.expectEqual(@as(usize, 2), parsed.segments.len);
    try testing.expectEqualSlices(u8, &s0, parsed.segments[0]);
    try testing.expectEqualSlices(u8, &s1, parsed.segments[1]);

    const trailer = [_]u8{ 0x44, 0x55, 0x66 };
    const with_trailer = try std.mem.concat(allocator, u8, &.{ packed_bytes, &trailer });
    defer allocator.free(with_trailer);
    var parsed_with_trailer = try readPackedMessage(allocator, with_trailer);
    defer parsed_with_trailer.deinit(allocator);
    try testing.expectEqual(flat.len, parsed_with_trailer.consumed_len);
    try testing.expectEqual(packed_bytes.len, parsed_with_trailer.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, parsed_with_trailer.consumedBytes());
    try testing.expectEqualSlices(u8, &s0, parsed_with_trailer.segments[0]);

    try testing.expectError(error.PackedInputTruncated, readPackedMessage(allocator, packed_bytes[0 .. packed_bytes.len - 1]));
}

test "packed stream framing writes directly to Io writer" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s0 = [_]u8{0} ** 24;
    const s1 = [_]u8{0x8a} ** 32;
    const segments = [_]ConstSegment{ &s0, &s1 };
    const flat = try messageToFlatBytes(allocator, &segments);
    defer allocator.free(flat);

    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try writePackedMessageToWriter(allocator, &writer, &segments);
    const packed_bytes = std.Io.Writer.buffered(&writer);

    const unpacked = try packing.unpack(allocator, packed_bytes);
    defer allocator.free(unpacked);
    try testing.expectEqualSlices(u8, flat, unpacked);

    var parsed = try readPackedMessage(allocator, packed_bytes);
    defer parsed.deinit(allocator);
    try testing.expectEqualSlices(u8, &s0, parsed.segments[0]);
    try testing.expectEqualSlices(u8, &s1, parsed.segments[1]);

    var table_buffer: [16]u8 = undefined;
    var buffered_writer_storage: [256]u8 = undefined;
    var buffered_writer = std.Io.Writer.fixed(&buffered_writer_storage);
    try writePackedMessageToWriterWithTableBuffer(&table_buffer, &buffered_writer, &segments);
    try testing.expectEqualSlices(u8, packed_bytes, std.Io.Writer.buffered(&buffered_writer));
    var packed_into_table_buffer: [16]u8 = undefined;
    var packed_into_buffer: [256]u8 = undefined;
    const packed_into_len = try messageToPackedBytesInto(&packed_into_table_buffer, &packed_into_buffer, &segments);
    try testing.expectEqualSlices(u8, std.Io.Writer.buffered(&buffered_writer), packed_into_buffer[0..packed_into_len]);
    var parsed_into = try readPackedMessage(allocator, packed_into_buffer[0..packed_into_len]);
    defer parsed_into.deinit(allocator);
    try testing.expectEqualSlices(u8, &s1, parsed_into.segments[1]);
    try testing.expectError(error.PackedOutputTooSmall, messageToPackedBytesInto(&packed_into_table_buffer, packed_into_buffer[0 .. packed_into_len - 1], &segments));
    var short_table_buffer: [8]u8 = undefined;
    var short_table_writer_storage: [256]u8 = undefined;
    var short_table_writer = std.Io.Writer.fixed(&short_table_writer_storage);
    try testing.expectError(error.SegmentTableTruncated, writePackedMessageToWriterWithTableBuffer(&short_table_buffer, &short_table_writer, &segments));
    try testing.expectError(error.SegmentTableTruncated, messageToPackedBytesInto(&short_table_buffer, &packed_into_buffer, &segments));
}

test "packed stream framing reads one message from Io reader" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const s0 = [_]u8{0} ** 24;
    const s1 = [_]u8{0x8a} ** 32;
    const trailer = [_]u8{ 0x44, 0x55, 0x66 };
    const segments = [_]ConstSegment{ &s0, &s1 };
    const packed_bytes = try messageToPackedBytes(allocator, &segments);
    defer allocator.free(packed_bytes);
    const with_trailer = try std.mem.concat(allocator, u8, &.{ packed_bytes, &trailer });
    defer allocator.free(with_trailer);

    var reader = std.Io.Reader.fixed(with_trailer);
    var parsed = try readPackedMessageFromReader(allocator, &reader);
    defer parsed.deinit(allocator);
    try testing.expectEqual(packed_bytes.len, parsed.sourceConsumedLen());
    try testing.expectEqualSlices(u8, &s0, parsed.segments[0]);
    try testing.expectEqualSlices(u8, &s1, parsed.segments[1]);
    try testing.expectEqualSlices(u8, &trailer, reader.buffered());

    var truncated_reader = std.Io.Reader.fixed(packed_bytes[0 .. packed_bytes.len - 1]);
    try testing.expectError(error.MessageTruncated, readPackedMessageFromReader(allocator, &truncated_reader));
}
