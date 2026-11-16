const std = @import("std");
const wire = @import("../wire.zig");
const zero = @import("../zero.zig");

const mod_builder = @import("builder.zig");
const mod_list = @import("list.zig");
const mod_options = @import("options.zig");
const mod_pointer = @import("pointer.zig");
const mod_reader = @import("reader.zig");
const mod_validate = @import("validate.zig");

const MessageBuilder = mod_builder.MessageBuilder;
const Orphanage = mod_builder.Orphanage;
const ListBuilder = mod_list.ListBuilder;
const ListReader = mod_list.ListReader;
const Error = mod_options.Error;
const MessageSize = mod_options.MessageSize;
const MessageStats = mod_options.MessageStats;
const ReaderOptions = mod_options.ReaderOptions;
const PointerBuilder = mod_pointer.PointerBuilder;
const PointerReader = mod_pointer.PointerReader;
const copyStructDataFromReader = mod_pointer.copyStructDataFromReader;
const MessageReader = mod_reader.MessageReader;
const checkedWordBitOffset = mod_validate.checkedWordBitOffset;
const checkedWordByteOffset = mod_validate.checkedWordByteOffset;
const collectStructStats = mod_validate.collectStructStats;
const emptyMutableBytes = mod_validate.emptyMutableBytes;
const structEndWord = mod_validate.structEndWord;
const wordRangesOverlap = mod_validate.wordRangesOverlap;

/// A mutable struct view with data and pointer sections.
pub const StructBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    data_start: usize,
    pointer_start: usize,
    data_words: u16,
    pointer_count: u16,
    data_bit_offset: usize = 0,
    data_bit_len: usize = 0,

    /// Create a read-only view using a caller-owned MessageReader over the
    /// same message segments. The caller must keep `message_reader` alive for
    /// the returned StructReader.
    pub fn asReader(self: StructBuilder, message_reader: *MessageReader) StructReader {
        return .{
            .message = message_reader,
            .segment_id = self.segment_id,
            .data_start = self.data_start,
            .pointer_start = self.pointer_start,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .nesting_left = message_reader.options.nesting_limit,
            .data_bit_offset = self.data_bit_offset,
            .data_bit_len = self.data_bit_len,
        };
    }

    pub fn validateWithOptions(self: StructBuilder, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(try self.message.segmentsConst(), options);
        return self.asReader(&reader).validate();
    }

    pub fn validate(self: StructBuilder) Error!MessageStats {
        return self.validateWithOptions(.{});
    }

    pub fn totalSizeWithOptions(self: StructBuilder, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn totalSize(self: StructBuilder) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn size(self: StructBuilder) wire.StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn dataWordCount(self: StructBuilder) u16 {
        return self.size().dataWordCount();
    }

    pub fn pointerCount(self: StructBuilder) u16 {
        return self.size().pointerCount();
    }

    pub fn totalWords(self: StructBuilder) usize {
        return self.size().totalWords();
    }

    pub fn dataByteCount(self: StructBuilder) usize {
        return self.size().dataByteCount();
    }

    pub fn pointerByteCount(self: StructBuilder) usize {
        return self.size().pointerByteCount();
    }

    pub fn totalByteCount(self: StructBuilder) usize {
        return self.size().totalByteCount();
    }

    pub fn isEmpty(self: StructBuilder) bool {
        return self.size().isEmpty();
    }

    pub fn hasDataWords(self: StructBuilder) bool {
        return self.size().hasDataWords();
    }

    pub fn hasPointers(self: StructBuilder) bool {
        return self.size().hasPointers();
    }

    pub fn matchesSize(self: StructBuilder, expected: wire.StructSize) bool {
        return self.data_words == expected.data_words and self.pointer_count == expected.pointer_count;
    }

    pub fn matchesDataWords(self: StructBuilder, count: u16) bool {
        return self.size().matchesDataWords(count);
    }

    pub fn matchesPointerCount(self: StructBuilder, count: u16) bool {
        return self.size().matchesPointerCount(count);
    }

    pub fn matchesTotalWords(self: StructBuilder, count: usize) bool {
        return self.size().matchesTotalWords(count);
    }

    pub fn matchesDataBytes(self: StructBuilder, count: usize) bool {
        return self.size().matchesDataBytes(count);
    }

    pub fn matchesPointerBytes(self: StructBuilder, count: usize) bool {
        return self.size().matchesPointerBytes(count);
    }

    pub fn matchesTotalBytes(self: StructBuilder, count: usize) bool {
        return self.size().matchesTotalBytes(count);
    }

    pub fn orphanage(self: StructBuilder) Orphanage {
        return Orphanage.init(self.message);
    }

    pub fn pointerSectionAsList(self: StructBuilder) ListBuilder {
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .start = self.pointer_start,
            .element_count = self.pointer_count,
            .element_size = .pointer,
            .data_words = 0,
            .pointer_count = 1,
            .step_bits = wire.bits_per_word,
        };
    }

    pub fn dataSectionBytes(self: StructBuilder) []u8 {
        return self.dataBytes();
    }

    pub fn getPointerField(self: StructBuilder, index: usize) Error!PointerBuilder {
        if (index >= self.pointer_count) return error.PointerOutOfBounds;
        const word_index = std.math.add(usize, self.pointer_start, index) catch return error.MessageTooLarge;
        return .{ .message = self.message, .segment_id = self.segment_id, .word_index = word_index };
    }

    pub fn setBool(self: StructBuilder, bit_offset: usize, value: bool, default_value: bool) Error!void {
        try self.checkDataBit(bit_offset);
        const encoded = value != default_value;
        const relative_bit = std.math.add(usize, self.data_bit_offset, bit_offset) catch return error.MessageTooLarge;
        const abs_bit = try checkedWordBitOffset(self.data_start, relative_bit);
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        var word = try self.message.readWord(self.segment_id, word_index);
        if (encoded) {
            word |= @as(u64, 1) << bit;
        } else {
            word &= ~(@as(u64, 1) << bit);
        }
        self.message.segments.items[self.segment_id].words.items[word_index] = word;
    }

    pub fn setUInt8(self: StructBuilder, byte_offset: usize, value: u8, default_value: u8) Error!void {
        try self.setInt(u8, byte_offset, value, default_value);
    }

    pub fn setUInt16(self: StructBuilder, byte_offset: usize, value: u16, default_value: u16) Error!void {
        try self.setInt(u16, byte_offset, value, default_value);
    }

    pub fn setUInt32(self: StructBuilder, byte_offset: usize, value: u32, default_value: u32) Error!void {
        try self.setInt(u32, byte_offset, value, default_value);
    }

    pub fn setUInt64(self: StructBuilder, byte_offset: usize, value: u64, default_value: u64) Error!void {
        try self.setInt(u64, byte_offset, value, default_value);
    }

    pub fn setInt8(self: StructBuilder, byte_offset: usize, value: i8, default_value: i8) Error!void {
        try self.setInt(i8, byte_offset, value, default_value);
    }

    pub fn setInt16(self: StructBuilder, byte_offset: usize, value: i16, default_value: i16) Error!void {
        try self.setInt(i16, byte_offset, value, default_value);
    }

    pub fn setInt32(self: StructBuilder, byte_offset: usize, value: i32, default_value: i32) Error!void {
        try self.setInt(i32, byte_offset, value, default_value);
    }

    pub fn setInt64(self: StructBuilder, byte_offset: usize, value: i64, default_value: i64) Error!void {
        try self.setInt(i64, byte_offset, value, default_value);
    }

    pub fn setFloat32(self: StructBuilder, byte_offset: usize, value: f32, default_value: f32) Error!void {
        try self.setInt(u32, byte_offset, @bitCast(value), @bitCast(default_value));
    }

    pub fn setFloat64(self: StructBuilder, byte_offset: usize, value: f64, default_value: f64) Error!void {
        try self.setInt(u64, byte_offset, @bitCast(value), @bitCast(default_value));
    }

    pub fn getBool(self: StructBuilder, bit_offset: usize, default_value: bool) Error!bool {
        try self.checkDataBit(bit_offset);
        const relative_bit = std.math.add(usize, self.data_bit_offset, bit_offset) catch return error.MessageTooLarge;
        const abs_bit = try checkedWordBitOffset(self.data_start, relative_bit);
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        const word = try self.message.readWord(self.segment_id, word_index);
        return (((word >> bit) & 1) != 0) != default_value;
    }

    pub fn getUInt8(self: StructBuilder, byte_offset: usize, default_value: u8) Error!u8 {
        return self.getInt(u8, byte_offset, default_value);
    }

    pub fn getUInt16(self: StructBuilder, byte_offset: usize, default_value: u16) Error!u16 {
        return self.getInt(u16, byte_offset, default_value);
    }

    pub fn getUInt32(self: StructBuilder, byte_offset: usize, default_value: u32) Error!u32 {
        return self.getInt(u32, byte_offset, default_value);
    }

    pub fn getUInt64(self: StructBuilder, byte_offset: usize, default_value: u64) Error!u64 {
        return self.getInt(u64, byte_offset, default_value);
    }

    pub fn getInt8(self: StructBuilder, byte_offset: usize, default_value: i8) Error!i8 {
        return self.getInt(i8, byte_offset, default_value);
    }

    pub fn getInt16(self: StructBuilder, byte_offset: usize, default_value: i16) Error!i16 {
        return self.getInt(i16, byte_offset, default_value);
    }

    pub fn getInt32(self: StructBuilder, byte_offset: usize, default_value: i32) Error!i32 {
        return self.getInt(i32, byte_offset, default_value);
    }

    pub fn getInt64(self: StructBuilder, byte_offset: usize, default_value: i64) Error!i64 {
        return self.getInt(i64, byte_offset, default_value);
    }

    pub fn getFloat32(self: StructBuilder, byte_offset: usize, default_value: f32) Error!f32 {
        return @bitCast(try self.getInt(u32, byte_offset, @bitCast(default_value)));
    }

    pub fn getFloat64(self: StructBuilder, byte_offset: usize, default_value: f64) Error!f64 {
        return @bitCast(try self.getInt(u64, byte_offset, @bitCast(default_value)));
    }

    pub fn setText(self: StructBuilder, pointer_index: usize, text: []const u8) Error!void {
        try (try self.getPointerField(pointer_index)).setText(text);
    }

    pub fn setData(self: StructBuilder, pointer_index: usize, data: []const u8) Error!void {
        try (try self.getPointerField(pointer_index)).setData(data);
    }

    pub fn clearPointer(self: StructBuilder, pointer_index: usize) Error!void {
        (try self.getPointerField(pointer_index)).clear();
    }

    pub fn clearDataBytes(self: StructBuilder, byte_offset: usize, len: usize) Error!void {
        try self.checkDataBytes(byte_offset, len);
        zero.bytes(self.dataBytes()[byte_offset..][0..len]);
    }

    pub fn clear(self: StructBuilder) Error!void {
        zero.bytes(try self.dataBytesChecked());
        for (0..self.pointer_count) |i| {
            try self.clearPointer(i);
        }
    }

    pub fn copyFromReader(self: StructBuilder, source: StructReader) Error!void {
        if (self.overlapsSource(source)) {
            if (self.data_start == source.data_start and
                self.pointer_start == source.pointer_start and
                self.data_words == source.data_words and
                self.pointer_count == source.pointer_count)
            {
                return;
            }

            var temp = try MessageBuilder.init(self.message.allocator, .{
                .first_segment_words = @max(@as(usize, source.data_words) + @as(usize, source.pointer_count) + 1, 1),
                .next_segment_min_words = 1,
            });
            defer temp.deinit();
            const temp_root = try temp.initRoot(.{
                .data_words = source.data_words,
                .pointer_count = source.pointer_count,
            });
            try temp_root.copyFromReader(source);
            var temp_reader = MessageReader.init(try temp.segmentsConst(), .{});
            return self.copyFromReader(try temp_reader.getRoot());
        }

        try self.clear();
        try copyStructDataFromReader(self, source);
        const pointer_len = @min(self.pointer_count, source.pointer_count);
        for (0..pointer_len) |i| {
            try (try self.getPointerField(i)).copyFrom(source.getPointerField(i));
        }
    }

    pub fn copyFromBuilder(self: StructBuilder, source: StructBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyFromReader(source.asReader(&reader));
    }

    fn overlapsSource(self: StructBuilder, source: StructReader) bool {
        if (self.segment_id != source.segment_id) return false;
        if (self.segment_id >= self.message.segments.items.len) return false;
        if (source.segment_id >= source.message.segments.len) return false;
        const dst_segment = std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items);
        const src_segment = source.message.segments[source.segment_id];
        if (dst_segment.ptr != src_segment.ptr) return false;

        const dst_start = self.data_start;
        const dst_end = structEndWord(dst_start, self.data_words, self.pointer_count) catch return false;
        const src_start = source.data_start;
        const src_end = structEndWord(src_start, source.data_words, source.pointer_count) catch return false;
        return wordRangesOverlap(dst_start, dst_end, src_start, src_end);
    }

    fn setInt(self: StructBuilder, comptime T: type, byte_offset: usize, value: T, default_value: T) Error!void {
        const bytes = try self.dataFieldBytes(T, byte_offset);
        const encoded = value ^ default_value;
        std.mem.writeInt(T, bytes, encoded, .little);
    }

    fn getInt(self: StructBuilder, comptime T: type, byte_offset: usize, default_value: T) Error!T {
        const bytes = try self.dataFieldBytes(T, byte_offset);
        return std.mem.readInt(T, bytes, .little) ^ default_value;
    }

    fn dataBytes(self: StructBuilder) []u8 {
        return self.dataBytesChecked() catch emptyMutableBytes();
    }

    pub fn dataBytesChecked(self: StructBuilder) Error![]u8 {
        _ = try self.dataWordBounds();
        if (self.data_bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const bit_len = self.effectiveDataBits();
        if (bit_len % 8 != 0) return error.UnsupportedElementSize;
        const byte_start = try checkedWordByteOffset(self.data_start, self.data_bit_offset);
        const byte_len = bit_len / 8;
        if (self.segment_id >= self.message.segments.items.len) return error.SegmentOutOfBounds;
        const segment_bytes = std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items);
        if (byte_start > segment_bytes.len or segment_bytes.len - byte_start < byte_len) return error.PointerOutOfBounds;
        return segment_bytes[byte_start..][0..byte_len];
    }

    fn dataWordBounds(self: StructBuilder) Error!struct { start: usize, end: usize } {
        if (self.segment_id >= self.message.segments.items.len) return error.SegmentOutOfBounds;
        const words = self.message.segments.items[self.segment_id].words.items;
        if (self.data_start > words.len or words.len - self.data_start < self.data_words) return error.PointerOutOfBounds;
        return .{
            .start = self.data_start,
            .end = self.data_start + @as(usize, self.data_words),
        };
    }

    fn checkDataBit(self: StructBuilder, bit_offset: usize) Error!void {
        if (bit_offset >= self.effectiveDataBits()) return error.PointerOutOfBounds;
        _ = try self.dataWordBounds();
    }

    fn checkDataBytes(self: StructBuilder, byte_offset: usize, len: usize) Error!void {
        const data_bits = self.effectiveDataBits();
        if (data_bits % 8 != 0) return error.UnsupportedElementSize;
        const data_len = data_bits / 8;
        if (byte_offset > data_len or data_len - byte_offset < len) return error.PointerOutOfBounds;
        _ = try self.dataWordBounds();
    }

    fn dataFieldBytes(self: StructBuilder, comptime T: type, byte_offset: usize) Error!*[@sizeOf(T)]u8 {
        try self.checkDataBytes(byte_offset, @sizeOf(T));
        const field_bit_offset = std.math.mul(usize, byte_offset, 8) catch return error.MessageTooLarge;
        const absolute_bit_offset = std.math.add(usize, self.data_bit_offset, field_bit_offset) catch return error.MessageTooLarge;
        if (absolute_bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const byte_start = try checkedWordByteOffset(self.data_start, absolute_bit_offset);
        if (self.segment_id >= self.message.segments.items.len) return error.SegmentOutOfBounds;
        const segment_bytes = std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items);
        if (byte_start > segment_bytes.len or segment_bytes.len - byte_start < @sizeOf(T)) return error.PointerOutOfBounds;
        return segment_bytes[byte_start..][0..@sizeOf(T)];
    }

    fn effectiveDataBits(self: StructBuilder) usize {
        if (self.data_bit_len != 0) return self.data_bit_len;
        return @as(usize, self.data_words) * wire.bits_per_word;
    }
};

/// A read-only struct view with data and pointer sections.
pub const StructReader = struct {
    message: *MessageReader,
    segment_id: u32,
    data_start: usize,
    pointer_start: usize,
    data_words: u16,
    pointer_count: u16,
    nesting_left: u16,
    data_bit_offset: usize = 0,
    data_bit_len: usize = 0,

    pub fn getPointerField(self: StructReader, index: usize) PointerReader {
        if (index >= self.pointer_count) {
            return .{ .message = self.message, .segment_id = self.segment_id, .word_index = 0, .nesting_left = self.nesting_left, .null_override = true };
        }
        const word_index = std.math.add(usize, self.pointer_start, index) catch {
            return .{ .message = self.message, .segment_id = self.segment_id, .word_index = 0, .nesting_left = self.nesting_left, .null_override = true };
        };
        return .{ .message = self.message, .segment_id = self.segment_id, .word_index = word_index, .nesting_left = self.nesting_left };
    }

    pub fn pointerSectionAsList(self: StructReader) ListReader {
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .start = self.pointer_start,
            .element_count = self.pointer_count,
            .element_size = .pointer,
            .data_words = 0,
            .pointer_count = 1,
            .step_bits = wire.bits_per_word,
            .nesting_left = self.nesting_left,
        };
    }

    pub fn dataSectionBytes(self: StructReader) []const u8 {
        return self.dataBytes();
    }

    pub fn getBool(self: StructReader, bit_offset: usize, default_value: bool) bool {
        if (bit_offset >= self.effectiveDataBits()) return default_value;
        const relative_bit_offset = std.math.add(usize, self.data_bit_offset, bit_offset) catch return default_value;
        const abs_bit = checkedWordBitOffset(self.data_start, relative_bit_offset) catch return default_value;
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        const word = self.message.readWord(self.segment_id, word_index) catch return default_value;
        return (((word >> bit) & 1) != 0) != default_value;
    }

    pub fn getUInt8(self: StructReader, byte_offset: usize, default_value: u8) u8 {
        return self.getInt(u8, byte_offset, default_value);
    }

    pub fn getUInt16(self: StructReader, byte_offset: usize, default_value: u16) u16 {
        return self.getInt(u16, byte_offset, default_value);
    }

    pub fn getUInt32(self: StructReader, byte_offset: usize, default_value: u32) u32 {
        return self.getInt(u32, byte_offset, default_value);
    }

    pub fn getUInt64(self: StructReader, byte_offset: usize, default_value: u64) u64 {
        return self.getInt(u64, byte_offset, default_value);
    }

    pub fn getInt8(self: StructReader, byte_offset: usize, default_value: i8) i8 {
        return self.getInt(i8, byte_offset, default_value);
    }

    pub fn getInt16(self: StructReader, byte_offset: usize, default_value: i16) i16 {
        return self.getInt(i16, byte_offset, default_value);
    }

    pub fn getInt32(self: StructReader, byte_offset: usize, default_value: i32) i32 {
        return self.getInt(i32, byte_offset, default_value);
    }

    pub fn getInt64(self: StructReader, byte_offset: usize, default_value: i64) i64 {
        return self.getInt(i64, byte_offset, default_value);
    }

    pub fn getFloat32(self: StructReader, byte_offset: usize, default_value: f32) f32 {
        return @bitCast(self.getInt(u32, byte_offset, @bitCast(default_value)));
    }

    pub fn getFloat64(self: StructReader, byte_offset: usize, default_value: f64) f64 {
        return @bitCast(self.getInt(u64, byte_offset, @bitCast(default_value)));
    }

    fn getInt(self: StructReader, comptime T: type, byte_offset: usize, default_value: T) T {
        const data_bits = self.effectiveDataBits();
        const value_bits = @sizeOf(T) * 8;
        const field_bit_offset = std.math.mul(usize, byte_offset, 8) catch return default_value;
        if (field_bit_offset > data_bits or data_bits - field_bit_offset < value_bits) return default_value;
        const absolute_bit_offset = std.math.add(usize, self.data_bit_offset, field_bit_offset) catch return default_value;
        if (absolute_bit_offset % 8 != 0) return default_value;
        const byte_start = checkedWordByteOffset(self.data_start, absolute_bit_offset) catch return default_value;
        if (self.segment_id >= self.message.segments.len) return default_value;
        const segment = self.message.segments[self.segment_id];
        if (byte_start > segment.len or segment.len - byte_start < @sizeOf(T)) return default_value;
        return std.mem.readInt(T, segment[byte_start..][0..@sizeOf(T)], .little) ^ default_value;
    }

    fn dataBytes(self: StructReader) []const u8 {
        return self.dataBytesChecked() catch &.{};
    }

    pub fn dataBytesChecked(self: StructReader) Error![]const u8 {
        if (self.segment_id >= self.message.segments.len) return error.SegmentOutOfBounds;
        if (self.data_bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const byte_start = try checkedWordByteOffset(self.data_start, self.data_bit_offset);
        const byte_len = self.effectiveDataBits() / 8;
        const segment = self.message.segments[self.segment_id];
        if (byte_start > segment.len or segment.len - byte_start < byte_len) return error.PointerOutOfBounds;
        return segment[byte_start..][0..byte_len];
    }

    fn effectiveDataBits(self: StructReader) usize {
        if (self.data_bit_len != 0) return self.data_bit_len;
        return @as(usize, self.data_words) * wire.bits_per_word;
    }

    pub fn validate(self: StructReader) Error!MessageStats {
        var stats: MessageStats = .{};
        try collectStructStats(self, &stats);
        return stats;
    }

    pub fn validateWithOptions(self: StructReader, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(self.message.segments, options);
        return (StructReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .data_start = self.data_start,
            .pointer_start = self.pointer_start,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .nesting_left = reader.options.nesting_limit,
            .data_bit_offset = self.data_bit_offset,
            .data_bit_len = self.data_bit_len,
        }).validate();
    }

    pub fn totalSize(self: StructReader) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn totalSizeWithOptions(self: StructReader, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn size(self: StructReader) wire.StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn dataWordCount(self: StructReader) u16 {
        return self.size().dataWordCount();
    }

    pub fn pointerCount(self: StructReader) u16 {
        return self.size().pointerCount();
    }

    pub fn totalWords(self: StructReader) usize {
        return self.size().totalWords();
    }

    pub fn dataByteCount(self: StructReader) usize {
        return self.size().dataByteCount();
    }

    pub fn pointerByteCount(self: StructReader) usize {
        return self.size().pointerByteCount();
    }

    pub fn totalByteCount(self: StructReader) usize {
        return self.size().totalByteCount();
    }

    pub fn isEmpty(self: StructReader) bool {
        return self.size().isEmpty();
    }

    pub fn hasDataWords(self: StructReader) bool {
        return self.size().hasDataWords();
    }

    pub fn hasPointers(self: StructReader) bool {
        return self.size().hasPointers();
    }

    pub fn matchesSize(self: StructReader, expected: wire.StructSize) bool {
        return self.data_words == expected.data_words and self.pointer_count == expected.pointer_count;
    }

    pub fn matchesDataWords(self: StructReader, count: u16) bool {
        return self.size().matchesDataWords(count);
    }

    pub fn matchesPointerCount(self: StructReader, count: u16) bool {
        return self.size().matchesPointerCount(count);
    }

    pub fn matchesTotalWords(self: StructReader, count: usize) bool {
        return self.size().matchesTotalWords(count);
    }

    pub fn matchesDataBytes(self: StructReader, count: usize) bool {
        return self.size().matchesDataBytes(count);
    }

    pub fn matchesPointerBytes(self: StructReader, count: usize) bool {
        return self.size().matchesPointerBytes(count);
    }

    pub fn matchesTotalBytes(self: StructReader, count: usize) bool {
        return self.size().matchesTotalBytes(count);
    }
};
