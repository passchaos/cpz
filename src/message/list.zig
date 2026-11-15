const std = @import("std");
const wire = @import("../wire.zig");

const mod_builder = @import("builder.zig");
const mod_options = @import("options.zig");
const mod_pointer = @import("pointer.zig");
const mod_reader = @import("reader.zig");
const mod_struct = @import("struct.zig");
const mod_validate = @import("validate.zig");

const MessageBuilder = mod_builder.MessageBuilder;
const Orphan = mod_builder.Orphan;
const Orphanage = mod_builder.Orphanage;
const Error = mod_options.Error;
const MessageSize = mod_options.MessageSize;
const MessageStats = mod_options.MessageStats;
const ReaderOptions = mod_options.ReaderOptions;
const PointerBuilder = mod_pointer.PointerBuilder;
const PointerReader = mod_pointer.PointerReader;
const copyPrimitiveBuilderList = mod_pointer.copyPrimitiveBuilderList;
const listRangeShouldCopyBackward = mod_pointer.listRangeShouldCopyBackward;
const MessageReader = mod_reader.MessageReader;
const StructBuilder = mod_struct.StructBuilder;
const StructReader = mod_struct.StructReader;
const checkedListBitLen = mod_validate.checkedListBitLen;
const checkedListByteLen = mod_validate.checkedListByteLen;
const checkedListWordLen = mod_validate.checkedListWordLen;
const checkedWordBitOffset = mod_validate.checkedWordBitOffset;
const checkedWordByteOffset = mod_validate.checkedWordByteOffset;
const collectListStats = mod_validate.collectListStats;
const emptyMutableBytes = mod_validate.emptyMutableBytes;
const exactBytesForBits = mod_validate.exactBytesForBits;
const exactWordsForBits = mod_validate.exactWordsForBits;

/// A mutable list view supporting primitive and composite elements.
pub const ListBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    start: usize,
    element_count: usize,
    element_size: wire.ElementSize,
    data_words: u16,
    pointer_count: u16,
    step_bits: usize,
    bit_offset: usize = 0,
    element_data_bits: usize = 0,
    limit_element_data_bits: bool = false,

    pub fn len(self: ListBuilder) usize {
        return self.element_count;
    }

    pub fn matchesLen(self: ListBuilder, count: usize) bool {
        return self.element_count == count;
    }

    pub fn isEmpty(self: ListBuilder) bool {
        return self.element_count == 0;
    }

    pub fn hasIndex(self: ListBuilder, index: usize) bool {
        return index < self.element_count;
    }

    pub fn firstIndex(self: ListBuilder) Error!usize {
        if (self.element_count == 0) return error.PointerOutOfBounds;
        return 0;
    }

    pub fn lastIndex(self: ListBuilder) Error!usize {
        if (self.element_count == 0) return error.PointerOutOfBounds;
        return self.element_count - 1;
    }

    pub fn elementSize(self: ListBuilder) wire.ElementSize {
        return self.element_size;
    }

    pub fn matchesElementSize(self: ListBuilder, expected: wire.ElementSize) bool {
        return self.element_size == expected;
    }

    pub fn elementBitCount(self: ListBuilder) usize {
        return self.step_bits;
    }

    pub fn elementByteCount(self: ListBuilder) Error!usize {
        return exactBytesForBits(self.step_bits);
    }

    pub fn elementWordCount(self: ListBuilder) Error!usize {
        return exactWordsForBits(self.step_bits);
    }

    pub fn contentBitCount(self: ListBuilder) Error!usize {
        return checkedListBitLen(self.element_count, self.step_bits);
    }

    pub fn contentByteCount(self: ListBuilder) Error!usize {
        return checkedListByteLen(self.element_count, self.step_bits);
    }

    pub fn contentWordCount(self: ListBuilder) Error!usize {
        return checkedListWordLen(self.element_count, self.step_bits);
    }

    pub fn matchesElementBits(self: ListBuilder, count: usize) bool {
        return self.elementBitCount() == count;
    }

    pub fn matchesElementBytes(self: ListBuilder, count: usize) bool {
        return (self.elementByteCount() catch return false) == count;
    }

    pub fn matchesElementWords(self: ListBuilder, count: usize) bool {
        return (self.elementWordCount() catch return false) == count;
    }

    pub fn matchesContentBits(self: ListBuilder, count: usize) bool {
        return (self.contentBitCount() catch return false) == count;
    }

    pub fn matchesContentBytes(self: ListBuilder, count: usize) bool {
        return (self.contentByteCount() catch return false) == count;
    }

    pub fn matchesContentWords(self: ListBuilder, count: usize) bool {
        return (self.contentWordCount() catch return false) == count;
    }

    pub fn structElementSize(self: ListBuilder) wire.StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn matchesStructElementSize(self: ListBuilder, expected: wire.StructSize) bool {
        return self.data_words == expected.data_words and self.pointer_count == expected.pointer_count;
    }

    pub fn structElementDataWordCount(self: ListBuilder) u16 {
        return self.structElementSize().dataWordCount();
    }

    pub fn structElementPointerCount(self: ListBuilder) u16 {
        return self.structElementSize().pointerCount();
    }

    pub fn structElementTotalWords(self: ListBuilder) usize {
        return self.structElementSize().totalWords();
    }

    pub fn structElementDataByteCount(self: ListBuilder) usize {
        return self.structElementSize().dataByteCount();
    }

    pub fn structElementPointerByteCount(self: ListBuilder) usize {
        return self.structElementSize().pointerByteCount();
    }

    pub fn structElementTotalByteCount(self: ListBuilder) usize {
        return self.structElementSize().totalByteCount();
    }

    pub fn matchesStructElementDataWords(self: ListBuilder, count: u16) bool {
        return self.structElementSize().matchesDataWords(count);
    }

    pub fn matchesStructElementPointerCount(self: ListBuilder, count: u16) bool {
        return self.structElementSize().matchesPointerCount(count);
    }

    pub fn matchesStructElementTotalWords(self: ListBuilder, count: usize) bool {
        return self.structElementSize().matchesTotalWords(count);
    }

    pub fn matchesStructElementDataBytes(self: ListBuilder, count: usize) bool {
        return self.structElementSize().matchesDataBytes(count);
    }

    pub fn matchesStructElementPointerBytes(self: ListBuilder, count: usize) bool {
        return self.structElementSize().matchesPointerBytes(count);
    }

    pub fn matchesStructElementTotalBytes(self: ListBuilder, count: usize) bool {
        return self.structElementSize().matchesTotalBytes(count);
    }

    pub fn slice(self: ListBuilder, start_index: usize, count: usize) Error!ListBuilder {
        if (start_index > self.element_count or self.element_count - start_index < count) return error.PointerOutOfBounds;
        const start_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, start_index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (self.element_size != .pointer and self.element_size != .composite and start_bits % wire.bits_per_word != 0) {
            const copy = try self.orphanage().newList(self.element_size, count);
            const list = try copy.getList(self.element_size);
            try copyPrimitiveBuilderList(list, self, start_index);
            return list;
        }
        if ((self.element_size == .pointer or self.element_size == .composite) and start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start_words = start_bits / wire.bits_per_word;
        const start = std.math.add(usize, self.start, start_words) catch return error.MessageTooLarge;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .start = start,
            .element_count = count,
            .element_size = self.element_size,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .step_bits = self.step_bits,
            .bit_offset = start_bits % wire.bits_per_word,
            .element_data_bits = self.element_data_bits,
            .limit_element_data_bits = self.limit_element_data_bits,
        };
    }

    /// Create a read-only view using a caller-owned MessageReader over the
    /// same message segments. The caller must keep `message_reader` alive for
    /// the returned ListReader.
    pub fn asReader(self: ListBuilder, message_reader: *MessageReader) ListReader {
        return .{
            .message = message_reader,
            .segment_id = self.segment_id,
            .start = self.start,
            .element_count = self.element_count,
            .element_size = self.element_size,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .step_bits = self.step_bits,
            .nesting_left = message_reader.options.nesting_limit,
            .bit_offset = self.bit_offset,
            .element_data_bits = self.element_data_bits,
            .limit_element_data_bits = self.limit_element_data_bits,
        };
    }

    pub fn validateWithOptions(self: ListBuilder, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(try self.message.segmentsConst(), options);
        return self.asReader(&reader).validate();
    }

    pub fn validate(self: ListBuilder) Error!MessageStats {
        return self.validateWithOptions(.{});
    }

    pub fn totalSizeWithOptions(self: ListBuilder, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn totalSize(self: ListBuilder) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn orphanage(self: ListBuilder) Orphanage {
        return Orphanage.init(self.message);
    }

    pub fn bytes(self: ListBuilder) []u8 {
        return self.bytesChecked() catch emptyMutableBytes();
    }

    fn bytesChecked(self: ListBuilder) Error![]u8 {
        if (self.segment_id >= self.message.segments.items.len) return error.SegmentOutOfBounds;
        if (self.bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const bit_len = std.math.mul(usize, self.element_count, self.step_bits) catch return error.MessageTooLarge;
        const byte_len = std.math.divCeil(usize, bit_len, 8) catch return error.MessageTooLarge;
        const byte_start = try checkedWordByteOffset(self.start, self.bit_offset);
        const segment = std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items);
        if (byte_start > segment.len or segment.len - byte_start < byte_len) return error.PointerOutOfBounds;
        return segment[byte_start..][0..byte_len];
    }

    pub fn rawPrimitiveBytes(self: ListBuilder) Error![]u8 {
        if (self.element_size == .pointer or self.element_size == .composite) return error.IncompatibleListShape;
        return self.bytesChecked();
    }

    pub fn setUInt8(self: ListBuilder, index: usize, value: u8) Error!void {
        try self.setPrimitive(u8, index, value);
    }

    pub fn setUInt16(self: ListBuilder, index: usize, value: u16) Error!void {
        try self.setPrimitive(u16, index, value);
    }

    pub fn setUInt32(self: ListBuilder, index: usize, value: u32) Error!void {
        try self.setPrimitive(u32, index, value);
    }

    pub fn setUInt64(self: ListBuilder, index: usize, value: u64) Error!void {
        try self.setPrimitive(u64, index, value);
    }

    pub fn setInt8(self: ListBuilder, index: usize, value: i8) Error!void {
        try self.setPrimitive(i8, index, value);
    }

    pub fn setInt16(self: ListBuilder, index: usize, value: i16) Error!void {
        try self.setPrimitive(i16, index, value);
    }

    pub fn setInt32(self: ListBuilder, index: usize, value: i32) Error!void {
        try self.setPrimitive(i32, index, value);
    }

    pub fn setInt64(self: ListBuilder, index: usize, value: i64) Error!void {
        try self.setPrimitive(i64, index, value);
    }

    pub fn setFloat32(self: ListBuilder, index: usize, value: f32) Error!void {
        try self.setPrimitive(u32, index, @bitCast(value));
    }

    pub fn setFloat64(self: ListBuilder, index: usize, value: f64) Error!void {
        try self.setPrimitive(u64, index, @bitCast(value));
    }

    pub fn setBool(self: ListBuilder, index: usize, value: bool) Error!void {
        if (self.element_size != .bit or index >= self.element_count) return error.PointerOutOfBounds;
        if (self.limit_element_data_bits and self.element_data_bits == 0) return error.PointerOutOfBounds;
        const element_bits = std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge;
        const relative_bit = std.math.add(usize, self.bit_offset, element_bits) catch return error.MessageTooLarge;
        const abs_bit = try checkedWordBitOffset(self.start, relative_bit);
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        var word = try self.message.readWord(self.segment_id, word_index);
        if (value) word |= @as(u64, 1) << bit else word &= ~(@as(u64, 1) << bit);
        self.message.segments.items[self.segment_id].words.items[word_index] = word;
    }

    pub fn getBool(self: ListBuilder, index: usize) Error!bool {
        if (self.element_size != .bit or index >= self.element_count) return error.PointerOutOfBounds;
        if (self.limit_element_data_bits and self.element_data_bits == 0) return error.PointerOutOfBounds;
        const element_bits = std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge;
        const relative_bit = std.math.add(usize, self.bit_offset, element_bits) catch return error.MessageTooLarge;
        const abs_bit = try checkedWordBitOffset(self.start, relative_bit);
        const word = try self.message.readWord(self.segment_id, abs_bit / wire.bits_per_word);
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        return ((word >> bit) & 1) != 0;
    }

    pub fn getUInt8(self: ListBuilder, index: usize) Error!u8 {
        return self.getPrimitive(u8, index);
    }

    pub fn getUInt16(self: ListBuilder, index: usize) Error!u16 {
        return self.getPrimitive(u16, index);
    }

    pub fn getUInt32(self: ListBuilder, index: usize) Error!u32 {
        return self.getPrimitive(u32, index);
    }

    pub fn getUInt64(self: ListBuilder, index: usize) Error!u64 {
        return self.getPrimitive(u64, index);
    }

    pub fn getInt8(self: ListBuilder, index: usize) Error!i8 {
        return self.getPrimitive(i8, index);
    }

    pub fn getInt16(self: ListBuilder, index: usize) Error!i16 {
        return self.getPrimitive(i16, index);
    }

    pub fn getInt32(self: ListBuilder, index: usize) Error!i32 {
        return self.getPrimitive(i32, index);
    }

    pub fn getInt64(self: ListBuilder, index: usize) Error!i64 {
        return self.getPrimitive(i64, index);
    }

    pub fn getFloat32(self: ListBuilder, index: usize) Error!f32 {
        return @bitCast(try self.getPrimitive(u32, index));
    }

    pub fn getFloat64(self: ListBuilder, index: usize) Error!f64 {
        return @bitCast(try self.getPrimitive(u64, index));
    }

    pub fn getPointerElement(self: ListBuilder, index: usize) Error!PointerBuilder {
        if (self.element_size != .pointer or index >= self.element_count) return error.PointerOutOfBounds;
        if (self.pointer_count == 0 and self.data_words == 0 and self.step_bits == wire.bits_per_word and self.bit_offset == 0) {
            const word_index = std.math.add(usize, self.start, index) catch return error.MessageTooLarge;
            return .{
                .message = self.message,
                .segment_id = self.segment_id,
                .word_index = word_index,
            };
        }
        if (self.pointer_count == 0) return error.PointerOutOfBounds;
        const element_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (element_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const element_word = std.math.add(usize, self.start, element_bits / wire.bits_per_word) catch return error.MessageTooLarge;
        const word_index = std.math.add(usize, element_word, self.data_words) catch return error.MessageTooLarge;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .word_index = word_index,
        };
    }

    pub fn elementMatchesPointerType(self: ListBuilder, index: usize, expected: wire.PointerType) Error!bool {
        return (try self.getPointerElement(index)).matchesPointerType(expected);
    }

    pub fn elementIsStructPointer(self: ListBuilder, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isStructPointer();
    }

    pub fn elementIsListPointer(self: ListBuilder, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isListPointer();
    }

    pub fn elementIsFarPointer(self: ListBuilder, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isFarPointer();
    }

    pub fn elementIsOtherPointer(self: ListBuilder, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isOtherPointer();
    }

    pub fn elementIsCapabilityPointer(self: ListBuilder, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isCapabilityPointer();
    }

    pub fn elementIsNearPointer(self: ListBuilder, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isNearPointer();
    }

    pub fn clearPointerElement(self: ListBuilder, index: usize) Error!void {
        (try self.getPointerElement(index)).clear();
    }

    pub fn disownPointerElement(self: ListBuilder, index: usize) Error!Orphan {
        return (try self.getPointerElement(index)).disown();
    }

    pub fn adoptPointerElement(self: ListBuilder, index: usize, orphan: *Orphan) Error!void {
        return (try self.getPointerElement(index)).adopt(orphan);
    }

    pub fn getStructElement(self: ListBuilder, index: usize) Error!StructBuilder {
        if (self.element_size != .composite or index >= self.element_count) return error.PointerOutOfBounds;
        const start_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (self.pointer_count != 0 and start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start = std.math.add(usize, self.start, start_bits / wire.bits_per_word) catch return error.MessageTooLarge;
        const pointer_start = std.math.add(usize, start, self.data_words) catch return error.MessageTooLarge;
        const data_bit_offset = start_bits % wire.bits_per_word;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .data_start = start,
            .pointer_start = pointer_start,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .data_bit_offset = data_bit_offset,
            .data_bit_len = if (self.limit_element_data_bits) self.element_data_bits else 0,
        };
    }

    pub fn clearStructElement(self: ListBuilder, index: usize) Error!void {
        return (try self.getStructElement(index)).clear();
    }

    pub fn clearElement(self: ListBuilder, index: usize) Error!void {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        switch (self.element_size) {
            .void => {},
            .bit => try self.setBool(index, false),
            .byte => try self.setUInt8(index, 0),
            .two_bytes => try self.setUInt16(index, 0),
            .four_bytes => try self.setUInt32(index, 0),
            .eight_bytes => try self.setUInt64(index, 0),
            .pointer => try self.clearPointerElement(index),
            .composite => try self.clearStructElement(index),
        }
    }

    pub fn clearElements(self: ListBuilder, start_index: usize, count: usize) Error!void {
        if (start_index > self.element_count or self.element_count - start_index < count) return error.PointerOutOfBounds;
        for (0..count) |offset| {
            try self.clearElement(start_index + offset);
        }
    }

    pub fn copyElementFrom(self: ListBuilder, index: usize, source: ListReader, source_index: usize) Error!void {
        if (index >= self.element_count or source_index >= source.element_count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .void => {},
            .bit => try self.setBool(index, source.getBool(source_index)),
            .byte => try self.setUInt8(index, source.getUInt8(source_index)),
            .two_bytes => try self.setUInt16(index, source.getUInt16(source_index)),
            .four_bytes => try self.setUInt32(index, source.getUInt32(source_index)),
            .eight_bytes => try self.setUInt64(index, source.getUInt64(source_index)),
            .pointer => try (try self.getPointerElement(index)).copyFrom(try source.getPointerElement(source_index)),
            .composite => {
                const dst = try self.getStructElement(index);
                const src = try source.getStructElement(source_index);
                try dst.copyFromReader(src);
            },
        }
    }

    pub fn copyElementFromCanonical(self: ListBuilder, index: usize, source: ListReader, source_index: usize) Error!void {
        if (index >= self.element_count or source_index >= source.element_count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .void => {},
            .bit => try self.setBool(index, source.getBool(source_index)),
            .byte => try self.setUInt8(index, source.getUInt8(source_index)),
            .two_bytes => try self.setUInt16(index, source.getUInt16(source_index)),
            .four_bytes => try self.setUInt32(index, source.getUInt32(source_index)),
            .eight_bytes => try self.setUInt64(index, source.getUInt64(source_index)),
            .pointer => try (try self.getPointerElement(index)).copyFromCanonical(try source.getPointerElement(source_index)),
            .composite => {
                const dst = try self.getStructElement(index);
                const src = try source.getStructElement(source_index);
                try dst.copyFromReader(src);
            },
        }
    }

    pub fn copyElementsFrom(self: ListBuilder, index: usize, source: ListReader, source_index: usize, count: usize) Error!void {
        if (index > self.element_count or self.element_count - index < count) return error.PointerOutOfBounds;
        if (source_index > source.element_count or source.element_count - source_index < count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .byte, .two_bytes, .four_bytes, .eight_bytes => {
                if (self.isCompactPrimitiveView() and source.isCompactPrimitiveView()) {
                    const bytes_per_element = wire.bitsPerElement(self.element_size) / 8;
                    const byte_count = std.math.mul(usize, count, bytes_per_element) catch return error.MessageTooLarge;
                    const dst_start = std.math.mul(usize, index, bytes_per_element) catch return error.MessageTooLarge;
                    const src_start = std.math.mul(usize, source_index, bytes_per_element) catch return error.MessageTooLarge;
                    const source_bytes = try source.rawPrimitiveBytes();
                    const dest_bytes = try self.rawPrimitiveBytes();
                    @memmove(dest_bytes[dst_start..][0..byte_count], source_bytes[src_start..][0..byte_count]);
                    return;
                }
            },
            else => {},
        }
        if (try listRangeShouldCopyBackward(self, index, source, source_index, count)) {
            var remaining = count;
            while (remaining != 0) {
                remaining -= 1;
                try self.copyElementFrom(index + remaining, source, source_index + remaining);
            }
        } else {
            for (0..count) |offset| {
                try self.copyElementFrom(index + offset, source, source_index + offset);
            }
        }
    }

    pub fn copyElementsFromCanonical(self: ListBuilder, index: usize, source: ListReader, source_index: usize, count: usize) Error!void {
        if (index > self.element_count or self.element_count - index < count) return error.PointerOutOfBounds;
        if (source_index > source.element_count or source.element_count - source_index < count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .byte, .two_bytes, .four_bytes, .eight_bytes => {
                return self.copyElementsFrom(index, source, source_index, count);
            },
            else => {},
        }
        if (try listRangeShouldCopyBackward(self, index, source, source_index, count)) {
            var remaining = count;
            while (remaining != 0) {
                remaining -= 1;
                try self.copyElementFromCanonical(index + remaining, source, source_index + remaining);
            }
        } else {
            for (0..count) |offset| {
                try self.copyElementFromCanonical(index + offset, source, source_index + offset);
            }
        }
    }

    pub fn copyElementFromBuilder(self: ListBuilder, index: usize, source: ListBuilder, source_index: usize) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyElementFrom(index, source.asReader(&reader), source_index);
    }

    pub fn copyElementFromCanonicalBuilder(self: ListBuilder, index: usize, source: ListBuilder, source_index: usize) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyElementFromCanonical(index, source.asReader(&reader), source_index);
    }

    pub fn copyElementsFromBuilder(self: ListBuilder, index: usize, source: ListBuilder, source_index: usize, count: usize) Error!void {
        if (index > self.element_count or self.element_count - index < count) return error.PointerOutOfBounds;
        if (source_index > source.element_count or source.element_count - source_index < count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .byte, .two_bytes, .four_bytes, .eight_bytes => {
                if (self.isCompactPrimitiveView() and source.isCompactPrimitiveView()) {
                    const bytes_per_element = wire.bitsPerElement(self.element_size) / 8;
                    const byte_count = std.math.mul(usize, count, bytes_per_element) catch return error.MessageTooLarge;
                    const dst_start = std.math.mul(usize, index, bytes_per_element) catch return error.MessageTooLarge;
                    const src_start = std.math.mul(usize, source_index, bytes_per_element) catch return error.MessageTooLarge;
                    const source_bytes = try source.rawPrimitiveBytes();
                    const dest_bytes = try self.rawPrimitiveBytes();
                    @memmove(dest_bytes[dst_start..][0..byte_count], source_bytes[src_start..][0..byte_count]);
                    return;
                }
            },
            else => {},
        }
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyElementsFrom(index, source.asReader(&reader), source_index, count);
    }

    pub fn copyElementsFromCanonicalBuilder(self: ListBuilder, index: usize, source: ListBuilder, source_index: usize, count: usize) Error!void {
        if (index > self.element_count or self.element_count - index < count) return error.PointerOutOfBounds;
        if (source_index > source.element_count or source.element_count - source_index < count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .byte, .two_bytes, .four_bytes, .eight_bytes => {
                return self.copyElementsFromBuilder(index, source, source_index, count);
            },
            else => {},
        }
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyElementsFromCanonical(index, source.asReader(&reader), source_index, count);
    }

    fn setPrimitive(self: ListBuilder, comptime T: type, index: usize, value: T) Error!void {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        const target_bytes = try self.primitiveElementBytes(T, index);
        std.mem.writeInt(T, target_bytes, value, .little);
    }

    fn getPrimitive(self: ListBuilder, comptime T: type, index: usize) Error!T {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        const source_bytes = try self.primitiveElementBytes(T, index);
        return std.mem.readInt(T, source_bytes, .little);
    }

    fn primitiveElementBytes(self: ListBuilder, comptime T: type, index: usize) Error!*[@sizeOf(T)]u8 {
        if (self.limit_element_data_bits and @bitSizeOf(T) > self.element_data_bits) return error.PointerOutOfBounds;
        const element_bits = std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge;
        const bit_offset = std.math.add(usize, self.bit_offset, element_bits) catch return error.MessageTooLarge;
        if (bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const byte_offset = std.math.add(usize, std.math.mul(usize, self.start, wire.bytes_per_word) catch return error.PointerOutOfBounds, bit_offset / 8) catch return error.PointerOutOfBounds;
        if (self.segment_id >= self.message.segments.items.len) return error.SegmentOutOfBounds;
        const segment = std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items);
        if (byte_offset > segment.len or segment.len - byte_offset < @sizeOf(T)) return error.PointerOutOfBounds;
        return segment[byte_offset..][0..@sizeOf(T)];
    }

    fn isCompactPrimitiveView(self: ListBuilder) bool {
        return self.bit_offset == 0 and
            !self.limit_element_data_bits and
            self.element_size != .pointer and
            self.element_size != .composite and
            self.step_bits == wire.bitsPerElement(self.element_size);
    }
};

/// A read-only list view supporting primitive and composite elements.
pub const ListReader = struct {
    message: *MessageReader,
    segment_id: u32,
    start: usize,
    element_count: usize,
    element_size: wire.ElementSize,
    data_words: u16,
    pointer_count: u16,
    step_bits: usize,
    nesting_left: u16,
    bit_offset: usize = 0,
    element_data_bits: usize = 0,
    limit_element_data_bits: bool = false,

    pub fn len(self: ListReader) usize {
        return self.element_count;
    }

    pub fn matchesLen(self: ListReader, count: usize) bool {
        return self.element_count == count;
    }

    pub fn isEmpty(self: ListReader) bool {
        return self.element_count == 0;
    }

    pub fn hasIndex(self: ListReader, index: usize) bool {
        return index < self.element_count;
    }

    pub fn firstIndex(self: ListReader) Error!usize {
        if (self.element_count == 0) return error.PointerOutOfBounds;
        return 0;
    }

    pub fn lastIndex(self: ListReader) Error!usize {
        if (self.element_count == 0) return error.PointerOutOfBounds;
        return self.element_count - 1;
    }

    pub fn elementSize(self: ListReader) wire.ElementSize {
        return self.element_size;
    }

    pub fn matchesElementSize(self: ListReader, expected: wire.ElementSize) bool {
        return self.element_size == expected;
    }

    pub fn elementBitCount(self: ListReader) usize {
        return self.step_bits;
    }

    pub fn elementByteCount(self: ListReader) Error!usize {
        return exactBytesForBits(self.step_bits);
    }

    pub fn elementWordCount(self: ListReader) Error!usize {
        return exactWordsForBits(self.step_bits);
    }

    pub fn contentBitCount(self: ListReader) Error!usize {
        return checkedListBitLen(self.element_count, self.step_bits);
    }

    pub fn contentByteCount(self: ListReader) Error!usize {
        return checkedListByteLen(self.element_count, self.step_bits);
    }

    pub fn contentWordCount(self: ListReader) Error!usize {
        return checkedListWordLen(self.element_count, self.step_bits);
    }

    pub fn matchesElementBits(self: ListReader, count: usize) bool {
        return self.elementBitCount() == count;
    }

    pub fn matchesElementBytes(self: ListReader, count: usize) bool {
        return (self.elementByteCount() catch return false) == count;
    }

    pub fn matchesElementWords(self: ListReader, count: usize) bool {
        return (self.elementWordCount() catch return false) == count;
    }

    pub fn matchesContentBits(self: ListReader, count: usize) bool {
        return (self.contentBitCount() catch return false) == count;
    }

    pub fn matchesContentBytes(self: ListReader, count: usize) bool {
        return (self.contentByteCount() catch return false) == count;
    }

    pub fn matchesContentWords(self: ListReader, count: usize) bool {
        return (self.contentWordCount() catch return false) == count;
    }

    pub fn structElementSize(self: ListReader) wire.StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn matchesStructElementSize(self: ListReader, expected: wire.StructSize) bool {
        return self.data_words == expected.data_words and self.pointer_count == expected.pointer_count;
    }

    pub fn structElementDataWordCount(self: ListReader) u16 {
        return self.structElementSize().dataWordCount();
    }

    pub fn structElementPointerCount(self: ListReader) u16 {
        return self.structElementSize().pointerCount();
    }

    pub fn structElementTotalWords(self: ListReader) usize {
        return self.structElementSize().totalWords();
    }

    pub fn structElementDataByteCount(self: ListReader) usize {
        return self.structElementSize().dataByteCount();
    }

    pub fn structElementPointerByteCount(self: ListReader) usize {
        return self.structElementSize().pointerByteCount();
    }

    pub fn structElementTotalByteCount(self: ListReader) usize {
        return self.structElementSize().totalByteCount();
    }

    pub fn matchesStructElementDataWords(self: ListReader, count: u16) bool {
        return self.structElementSize().matchesDataWords(count);
    }

    pub fn matchesStructElementPointerCount(self: ListReader, count: u16) bool {
        return self.structElementSize().matchesPointerCount(count);
    }

    pub fn matchesStructElementTotalWords(self: ListReader, count: usize) bool {
        return self.structElementSize().matchesTotalWords(count);
    }

    pub fn matchesStructElementDataBytes(self: ListReader, count: usize) bool {
        return self.structElementSize().matchesDataBytes(count);
    }

    pub fn matchesStructElementPointerBytes(self: ListReader, count: usize) bool {
        return self.structElementSize().matchesPointerBytes(count);
    }

    pub fn matchesStructElementTotalBytes(self: ListReader, count: usize) bool {
        return self.structElementSize().matchesTotalBytes(count);
    }

    pub fn slice(self: ListReader, start_index: usize, count: usize) Error!ListReader {
        if (start_index > self.element_count or self.element_count - start_index < count) return error.PointerOutOfBounds;
        const relative_start_bits = std.math.mul(usize, start_index, self.step_bits) catch return error.MessageTooLarge;
        const start_bits = std.math.add(usize, self.bit_offset, relative_start_bits) catch return error.MessageTooLarge;
        if ((self.element_size == .pointer or self.element_size == .composite) and start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start_words = start_bits / wire.bits_per_word;
        const start = std.math.add(usize, self.start, start_words) catch return error.MessageTooLarge;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .start = start,
            .element_count = count,
            .element_size = self.element_size,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .step_bits = self.step_bits,
            .nesting_left = self.nesting_left,
            .bit_offset = start_bits % wire.bits_per_word,
            .element_data_bits = self.element_data_bits,
            .limit_element_data_bits = self.limit_element_data_bits,
        };
    }

    pub fn bytes(self: ListReader) []const u8 {
        return self.bytesChecked() catch &.{};
    }

    fn bytesChecked(self: ListReader) Error![]const u8 {
        if (self.segment_id >= self.message.segments.len) return error.SegmentOutOfBounds;
        if (self.bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const bit_len = std.math.mul(usize, self.element_count, self.step_bits) catch return error.MessageTooLarge;
        const byte_len = std.math.divCeil(usize, bit_len, 8) catch return error.MessageTooLarge;
        const byte_start = try checkedWordByteOffset(self.start, self.bit_offset);
        const segment = self.message.segments[self.segment_id];
        if (byte_start > segment.len or segment.len - byte_start < byte_len) return error.PointerOutOfBounds;
        return segment[byte_start..][0..byte_len];
    }

    pub fn rawPrimitiveBytes(self: ListReader) Error![]const u8 {
        if (self.element_size == .pointer or self.element_size == .composite) return error.IncompatibleListShape;
        if (self.bit_offset % 8 != 0) return error.UnsupportedElementSize;
        return self.bytesChecked();
    }

    pub fn getBool(self: ListReader, index: usize) bool {
        if (self.element_size != .bit or index >= self.element_count) return false;
        const element_bits = std.math.mul(usize, index, self.step_bits) catch return false;
        const relative_bit = std.math.add(usize, self.bit_offset, element_bits) catch return false;
        if (self.limit_element_data_bits and self.element_data_bits == 0) return false;
        const abs_bit = checkedWordBitOffset(self.start, relative_bit) catch return false;
        const word = self.message.readWord(self.segment_id, abs_bit / wire.bits_per_word) catch return false;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        return ((word >> bit) & 1) != 0;
    }

    pub fn getUInt8(self: ListReader, index: usize) u8 {
        return self.getPrimitive(u8, index) catch 0;
    }

    pub fn getUInt16(self: ListReader, index: usize) u16 {
        return self.getPrimitive(u16, index) catch 0;
    }

    pub fn getUInt32(self: ListReader, index: usize) u32 {
        return self.getPrimitive(u32, index) catch 0;
    }

    pub fn getUInt64(self: ListReader, index: usize) u64 {
        return self.getPrimitive(u64, index) catch 0;
    }

    pub fn getInt8(self: ListReader, index: usize) i8 {
        return self.getPrimitive(i8, index) catch 0;
    }

    pub fn getInt16(self: ListReader, index: usize) i16 {
        return self.getPrimitive(i16, index) catch 0;
    }

    pub fn getInt32(self: ListReader, index: usize) i32 {
        return self.getPrimitive(i32, index) catch 0;
    }

    pub fn getInt64(self: ListReader, index: usize) i64 {
        return self.getPrimitive(i64, index) catch 0;
    }

    pub fn getFloat32(self: ListReader, index: usize) f32 {
        return @bitCast(self.getPrimitive(u32, index) catch 0);
    }

    pub fn getFloat64(self: ListReader, index: usize) f64 {
        return @bitCast(self.getPrimitive(u64, index) catch 0);
    }

    pub fn getPointerElement(self: ListReader, index: usize) Error!PointerReader {
        if (self.element_size != .pointer or index >= self.element_count) return error.PointerOutOfBounds;
        if (self.pointer_count == 0 and self.data_words == 0 and self.step_bits == wire.bits_per_word and self.bit_offset == 0) {
            const word_index = std.math.add(usize, self.start, index) catch return error.MessageTooLarge;
            return .{
                .message = self.message,
                .segment_id = self.segment_id,
                .word_index = word_index,
                .nesting_left = self.nesting_left,
            };
        }
        if (self.pointer_count == 0) {
            return .{ .message = self.message, .segment_id = self.segment_id, .word_index = 0, .nesting_left = self.nesting_left, .null_override = true };
        }
        const element_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (element_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const element_word = std.math.add(usize, self.start, element_bits / wire.bits_per_word) catch return error.MessageTooLarge;
        const pointer_word = std.math.add(usize, element_word, self.data_words) catch return error.MessageTooLarge;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .word_index = pointer_word,
            .nesting_left = self.nesting_left,
        };
    }

    pub fn elementMatchesPointerType(self: ListReader, index: usize, expected: wire.PointerType) Error!bool {
        return (try self.getPointerElement(index)).matchesPointerType(expected);
    }

    pub fn elementIsStructPointer(self: ListReader, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isStructPointer();
    }

    pub fn elementIsListPointer(self: ListReader, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isListPointer();
    }

    pub fn elementIsFarPointer(self: ListReader, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isFarPointer();
    }

    pub fn elementIsOtherPointer(self: ListReader, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isOtherPointer();
    }

    pub fn elementIsCapabilityPointer(self: ListReader, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isCapabilityPointer();
    }

    pub fn elementIsNearPointer(self: ListReader, index: usize) Error!bool {
        return (try self.getPointerElement(index)).isNearPointer();
    }

    pub fn getStructElement(self: ListReader, index: usize) Error!StructReader {
        if (self.element_size == .bit or index >= self.element_count) return error.PointerOutOfBounds;
        const start_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (self.pointer_count != 0 and start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start = std.math.add(usize, self.start, start_bits / wire.bits_per_word) catch return error.MessageTooLarge;
        const pointer_start = std.math.add(usize, start, self.data_words) catch return error.MessageTooLarge;
        const data_bit_offset = start_bits % wire.bits_per_word;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .data_start = start,
            .pointer_start = pointer_start,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .nesting_left = self.nesting_left,
            .data_bit_offset = data_bit_offset,
            .data_bit_len = if (self.limit_element_data_bits) self.element_data_bits else 0,
        };
    }

    fn getPrimitive(self: ListReader, comptime T: type, index: usize) Error!T {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        if (self.limit_element_data_bits and @bitSizeOf(T) > self.element_data_bits) return error.PointerOutOfBounds;
        const element_bits = std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge;
        const bit_offset = std.math.add(usize, self.bit_offset, element_bits) catch return error.MessageTooLarge;
        if (bit_offset % 8 != 0) return error.UnsupportedElementSize;
        const byte_offset = std.math.add(usize, std.math.mul(usize, self.start, wire.bytes_per_word) catch return error.MessageTooLarge, bit_offset / 8) catch return error.MessageTooLarge;
        if (self.segment_id >= self.message.segments.len) return error.SegmentOutOfBounds;
        const segment = self.message.segments[self.segment_id];
        if (byte_offset > segment.len or segment.len - byte_offset < @sizeOf(T)) return error.PointerOutOfBounds;
        return std.mem.readInt(T, segment[byte_offset..][0..@sizeOf(T)], .little);
    }

    fn isCompactPrimitiveView(self: ListReader) bool {
        return self.bit_offset == 0 and
            !self.limit_element_data_bits and
            self.element_size != .pointer and
            self.element_size != .composite and
            self.step_bits == wire.bitsPerElement(self.element_size);
    }

    pub fn validate(self: ListReader) Error!MessageStats {
        var stats: MessageStats = .{};
        try collectListStats(self, &stats);
        return stats;
    }

    pub fn validateWithOptions(self: ListReader, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(self.message.segments, options);
        return (ListReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .start = self.start,
            .element_count = self.element_count,
            .element_size = self.element_size,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .step_bits = self.step_bits,
            .nesting_left = reader.options.nesting_limit,
            .bit_offset = self.bit_offset,
            .element_data_bits = self.element_data_bits,
            .limit_element_data_bits = self.limit_element_data_bits,
        }).validate();
    }

    pub fn totalSize(self: ListReader) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn totalSizeWithOptions(self: ListReader, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }
};
