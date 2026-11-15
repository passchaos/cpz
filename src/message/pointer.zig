const std = @import("std");
const wire = @import("../wire.zig");

const mod_builder = @import("builder.zig");
const mod_list = @import("list.zig");
const mod_options = @import("options.zig");
const mod_reader = @import("reader.zig");
const mod_struct = @import("struct.zig");
const mod_validate = @import("validate.zig");

const MessageBuilder = mod_builder.MessageBuilder;
const Orphan = mod_builder.Orphan;
const SegmentCursor = mod_builder.SegmentCursor;
const ListBuilder = mod_list.ListBuilder;
const ListReader = mod_list.ListReader;
const Error = mod_options.Error;
const MessageSize = mod_options.MessageSize;
const MessageStats = mod_options.MessageStats;
const ReaderOptions = mod_options.ReaderOptions;
const MessageReader = mod_reader.MessageReader;
const StructBuilder = mod_struct.StructBuilder;
const StructReader = mod_struct.StructReader;
const canonicalStructListSize = mod_validate.canonicalStructListSize;
const canonicalStructSize = mod_validate.canonicalStructSize;
const checkedWordBitOffset = mod_validate.checkedWordBitOffset;
const listDataBitsPerElement = mod_validate.listDataBitsPerElement;
const primitiveDataWords = mod_validate.primitiveDataWords;
const primitivePointerCount = mod_validate.primitivePointerCount;
const textElementCount = mod_validate.textElementCount;
const upgradedStructListShape = mod_validate.upgradedStructListShape;
const validatePointer = mod_validate.validatePointer;

/// A mutable pointer slot inside a `MessageBuilder`.
pub const PointerBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    word_index: usize,

    pub fn raw(self: PointerBuilder) wire.Word {
        return self.message.readWord(self.segment_id, self.word_index) catch 0;
    }

    pub fn isNull(self: PointerBuilder) bool {
        return self.raw() == 0;
    }

    pub fn pointerType(self: PointerBuilder) ?wire.PointerType {
        const raw_value = self.raw();
        if (raw_value == 0) return null;
        return wire.pointerType(raw_value);
    }

    pub fn segmentId(self: PointerBuilder) u32 {
        return self.segment_id;
    }

    pub fn pointerWordIndex(self: PointerBuilder) usize {
        return self.word_index;
    }

    pub fn matchesLocation(self: PointerBuilder, segment_id: u32, word_index: usize) bool {
        return self.segment_id == segment_id and self.word_index == word_index;
    }

    pub fn matchesPointerType(self: PointerBuilder, expected: wire.PointerType) bool {
        const kind = self.pointerType() orelse return false;
        return kind.matches(expected);
    }

    pub fn isStructPointer(self: PointerBuilder) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isStruct();
    }

    pub fn isListPointer(self: PointerBuilder) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isList();
    }

    pub fn isFarPointer(self: PointerBuilder) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isFar();
    }

    pub fn isCapabilityPointer(self: PointerBuilder) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isCapability();
    }

    pub fn isOtherPointer(self: PointerBuilder) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isOther();
    }

    pub fn isNearPointer(self: PointerBuilder) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isNear();
    }

    /// Create a read-only view using a caller-owned MessageReader over the
    /// same message segments. The caller must keep `message_reader` alive for
    /// the returned PointerReader.
    pub fn asReader(self: PointerBuilder, message_reader: *MessageReader) PointerReader {
        return .{
            .message = message_reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = message_reader.options.nesting_limit,
        };
    }

    pub fn decode(self: PointerBuilder) Error!?wire.DecodedPointer {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).decode();
    }

    pub fn validateWithOptions(self: PointerBuilder, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(try self.message.segmentsConst(), options);
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).validate();
    }

    pub fn validate(self: PointerBuilder) Error!MessageStats {
        return self.validateWithOptions(.{});
    }

    pub fn totalSizeWithOptions(self: PointerBuilder, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn totalSize(self: PointerBuilder) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn clear(self: PointerBuilder) void {
        self.message.writePtr(self.segment_id, self.word_index, 0) catch return;
    }

    pub fn disown(self: PointerBuilder) Orphan {
        const raw_value = self.message.readWord(self.segment_id, self.word_index) catch 0;
        self.clear();
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .pointer_word_index = self.word_index,
            .raw = raw_value,
        };
    }

    pub fn adopt(self: PointerBuilder, orphan: *Orphan) Error!void {
        if (orphan.raw == 0) {
            self.clear();
            return;
        }
        if (orphan.message != self.message) return error.InvalidPointerKind;
        switch (wire.pointerType(orphan.raw)) {
            .struct_ptr => {
                const s = wire.decodeStruct(orphan.raw);
                const total_words = @as(usize, s.data_words) + @as(usize, s.pointer_count);
                if (total_words == 0) {
                    try self.message.writePtr(self.segment_id, self.word_index, try wire.encodeStruct(-1, 0, 0));
                } else {
                    const target = try wire.targetWordIndex(orphan.pointer_word_index, s.offset_words);
                    const object = SegmentCursor{ .id = orphan.segment_id, .start = target };
                    const near_raw = if (object.id == self.segment_id)
                        try wire.encodeStruct(try wire.offsetFromPointer(self.word_index, target), s.data_words, s.pointer_count)
                    else
                        try wire.encodeStruct(0, s.data_words, s.pointer_count);
                    const tag = try wire.encodeStruct(0, s.data_words, s.pointer_count);
                    try self.message.placePointerToObject(self, object, total_words, tag, near_raw);
                }
            },
            .list => {
                const l = try wire.decodeList(orphan.raw);
                const object_word_count = if (l.element_size == .composite)
                    std.math.add(usize, l.element_count_or_words, 1) catch return error.MessageTooLarge
                else
                    try wire.wordsForList(l.element_size, l.element_count_or_words);
                if (object_word_count == 0) {
                    try self.message.writePtr(self.segment_id, self.word_index, try wire.encodeList(0, l.element_size, l.element_count_or_words));
                } else {
                    const target = try wire.targetWordIndex(orphan.pointer_word_index, l.offset_words);
                    const object = SegmentCursor{ .id = orphan.segment_id, .start = target };
                    const near_raw = if (object.id == self.segment_id)
                        try wire.encodeList(try wire.offsetFromPointer(self.word_index, target), l.element_size, l.element_count_or_words)
                    else
                        try wire.encodeList(0, l.element_size, l.element_count_or_words);
                    const tag = try wire.encodeList(0, l.element_size, l.element_count_or_words);
                    try self.message.placePointerToObject(self, object, object_word_count, tag, near_raw);
                }
            },
            .far, .other => try self.message.writePtr(self.segment_id, self.word_index, orphan.raw),
        }
        orphan.raw = 0;
    }

    pub fn initStruct(self: PointerBuilder, size: wire.StructSize) Error!StructBuilder {
        const total_words = size.totalWords();
        if (total_words == 0) {
            try self.message.writePtr(self.segment_id, self.word_index, try wire.encodeStruct(-1, 0, 0));
            return .{
                .message = self.message,
                .segment_id = self.segment_id,
                .data_start = self.word_index,
                .pointer_start = self.word_index,
                .data_words = 0,
                .pointer_count = 0,
            };
        }

        const object = try self.message.allocObject(self.segment_id, total_words);
        const offset = try wire.offsetFromPointer(self.word_index, object.start);
        const near_raw = try wire.encodeStruct(offset, size.data_words, size.pointer_count);
        const tag = try wire.encodeStruct(0, size.data_words, size.pointer_count);
        try self.message.placePointerToObject(self, object, total_words, tag, near_raw);
        return .{
            .message = self.message,
            .segment_id = object.id,
            .data_start = object.start,
            .pointer_start = object.start + size.data_words,
            .data_words = size.data_words,
            .pointer_count = size.pointer_count,
        };
    }

    pub fn initList(self: PointerBuilder, element_size: wire.ElementSize, element_count: usize) Error!ListBuilder {
        if (element_size == .composite) return error.UnsupportedElementSize;
        const words = try wire.wordsForList(element_size, element_count);
        const object = try self.message.allocObject(self.segment_id, words);
        const offset = if (words == 0) @as(i32, 0) else try wire.offsetFromPointer(self.word_index, object.start);
        const near_raw = try wire.encodeList(offset, element_size, element_count);
        const tag = try wire.encodeList(0, element_size, element_count);
        try self.message.placePointerToObject(self, object, words, tag, near_raw);
        return .{
            .message = self.message,
            .segment_id = object.id,
            .start = object.start,
            .element_count = element_count,
            .element_size = element_size,
            .data_words = 0,
            .pointer_count = 0,
            .step_bits = wire.bitsPerElement(element_size),
        };
    }

    pub fn initStructList(self: PointerBuilder, element_count: usize, size: wire.StructSize) Error!ListBuilder {
        const content_words = try wire.wordsForStructList(element_count, size);
        const total_words = std.math.add(usize, 1, content_words) catch return error.MessageTooLarge;
        const object = try self.message.allocObject(self.segment_id, total_words);
        try self.message.writePtr(object.id, object.start, try wire.encodeStructListTag(element_count, size));
        const offset = try wire.offsetFromPointer(self.word_index, object.start);
        const near_raw = try wire.encodeList(offset, .composite, content_words);
        const tag = try wire.encodeList(0, .composite, content_words);
        try self.message.placePointerToObject(self, object, total_words, tag, near_raw);
        return .{
            .message = self.message,
            .segment_id = object.id,
            .start = object.start + 1,
            .element_count = element_count,
            .element_size = .composite,
            .data_words = size.data_words,
            .pointer_count = size.pointer_count,
            .step_bits = size.totalWords() * wire.bits_per_word,
        };
    }

    pub fn getStruct(self: PointerBuilder) Error!StructBuilder {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        const struct_reader = try (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getStruct(null);
        return .{
            .message = self.message,
            .segment_id = struct_reader.segment_id,
            .data_start = struct_reader.data_start,
            .pointer_start = struct_reader.pointer_start,
            .data_words = struct_reader.data_words,
            .pointer_count = struct_reader.pointer_count,
        };
    }

    pub fn getStructSize(self: PointerBuilder) Error!wire.StructSize {
        return (try self.getStruct()).size();
    }

    pub fn getStructDataWordCount(self: PointerBuilder) Error!u16 {
        return (try self.getStructSize()).dataWordCount();
    }

    pub fn getStructPointerCount(self: PointerBuilder) Error!u16 {
        return (try self.getStructSize()).pointerCount();
    }

    pub fn getStructTotalWords(self: PointerBuilder) Error!usize {
        return (try self.getStructSize()).totalWords();
    }

    pub fn getStructDataByteCount(self: PointerBuilder) Error!usize {
        return (try self.getStructSize()).dataByteCount();
    }

    pub fn getStructPointerByteCount(self: PointerBuilder) Error!usize {
        return (try self.getStructSize()).pointerByteCount();
    }

    pub fn getStructTotalByteCount(self: PointerBuilder) Error!usize {
        return (try self.getStructSize()).totalByteCount();
    }

    pub fn structMatchesSize(self: PointerBuilder, expected: wire.StructSize) Error!bool {
        const actual = try self.getStructSize();
        return actual.data_words == expected.data_words and actual.pointer_count == expected.pointer_count;
    }

    pub fn structMatchesDataWords(self: PointerBuilder, count: u16) Error!bool {
        return (try self.getStructSize()).matchesDataWords(count);
    }

    pub fn structMatchesPointerCount(self: PointerBuilder, count: u16) Error!bool {
        return (try self.getStructSize()).matchesPointerCount(count);
    }

    pub fn structMatchesTotalWords(self: PointerBuilder, count: usize) Error!bool {
        return (try self.getStructSize()).matchesTotalWords(count);
    }

    pub fn structMatchesTotalBytes(self: PointerBuilder, count: usize) Error!bool {
        return (try self.getStructSize()).matchesTotalBytes(count);
    }

    pub fn getList(self: PointerBuilder, expected: ?wire.ElementSize) Error!ListBuilder {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        const list_reader = try (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getList(expected);
        return .{
            .message = self.message,
            .segment_id = list_reader.segment_id,
            .start = list_reader.start,
            .element_count = list_reader.element_count,
            .element_size = list_reader.element_size,
            .data_words = list_reader.data_words,
            .pointer_count = list_reader.pointer_count,
            .step_bits = list_reader.step_bits,
        };
    }

    pub fn getListLen(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).len();
    }

    pub fn listMatchesLen(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesLen(count);
    }

    pub fn listIsEmpty(self: PointerBuilder, expected: ?wire.ElementSize) Error!bool {
        return (try self.getList(expected)).isEmpty();
    }

    pub fn listHasIndex(self: PointerBuilder, expected: ?wire.ElementSize, index: usize) Error!bool {
        return (try self.getList(expected)).hasIndex(index);
    }

    pub fn getListFirstIndex(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).firstIndex();
    }

    pub fn getListLastIndex(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).lastIndex();
    }

    pub fn getListElementSize(self: PointerBuilder, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return (try self.getList(expected)).elementSize();
    }

    pub fn listMatchesElementSize(self: PointerBuilder, expected: ?wire.ElementSize, element_size: wire.ElementSize) Error!bool {
        return (try self.getList(expected)).matchesElementSize(element_size);
    }

    pub fn getListElementBitCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementBitCount();
    }

    pub fn listMatchesElementBits(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesElementBits(count);
    }

    pub fn getListElementByteCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementByteCount();
    }

    pub fn listMatchesElementBytes(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesElementBytes(count);
    }

    pub fn getListElementWordCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementWordCount();
    }

    pub fn listMatchesElementWords(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesElementWords(count);
    }

    pub fn getListContentBitCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentBitCount();
    }

    pub fn listMatchesContentBits(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesContentBits(count);
    }

    pub fn getListContentByteCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentByteCount();
    }

    pub fn getListContentWordCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentWordCount();
    }

    pub fn listMatchesContentBytes(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesContentBytes(count);
    }

    pub fn listMatchesContentWords(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesContentWords(count);
    }

    pub fn getListStructElementSize(self: PointerBuilder, expected: ?wire.ElementSize) Error!wire.StructSize {
        return (try self.getList(expected)).structElementSize();
    }

    pub fn getListStructElementDataWordCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getList(expected)).structElementDataWordCount();
    }

    pub fn getListStructElementPointerCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getList(expected)).structElementPointerCount();
    }

    pub fn getListStructElementTotalWords(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementTotalWords();
    }

    pub fn getListStructElementDataByteCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementDataByteCount();
    }

    pub fn getListStructElementPointerByteCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementPointerByteCount();
    }

    pub fn getListStructElementTotalByteCount(self: PointerBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementTotalByteCount();
    }

    pub fn listMatchesStructElementSize(self: PointerBuilder, expected: ?wire.ElementSize, size: wire.StructSize) Error!bool {
        return (try self.getList(expected)).matchesStructElementSize(size);
    }

    pub fn listMatchesStructElementDataWords(self: PointerBuilder, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getList(expected)).matchesStructElementDataWords(count);
    }

    pub fn listMatchesStructElementPointerCount(self: PointerBuilder, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getList(expected)).matchesStructElementPointerCount(count);
    }

    pub fn listMatchesStructElementTotalWords(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementTotalWords(count);
    }

    pub fn listMatchesStructElementDataBytes(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementDataBytes(count);
    }

    pub fn listMatchesStructElementPointerBytes(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementPointerBytes(count);
    }

    pub fn listMatchesStructElementTotalBytes(self: PointerBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementTotalBytes(count);
    }

    pub fn setText(self: PointerBuilder, text: []const u8) Error!void {
        if (std.mem.indexOfScalar(u8, text, 0) != null) return error.TextContainsInteriorNul;
        if (!std.unicode.utf8ValidateSlice(text)) return error.Utf8Invalid;
        const list = try self.initList(.byte, try textElementCount(text.len));
        const bytes = list.bytes();
        @memcpy(bytes[0..text.len], text);
        bytes[text.len] = 0;
    }

    pub fn setData(self: PointerBuilder, data: []const u8) Error!void {
        const list = try self.initList(.byte, data.len);
        @memcpy(list.bytes(), data);
    }

    pub fn getText(self: PointerBuilder) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getText();
    }

    pub fn getTextDefault(self: PointerBuilder, default_value: []const u8) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getTextDefault(default_value);
    }

    pub fn getTextDefaultByteCount(self: PointerBuilder, default_value: []const u8) Error!usize {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getTextDefaultByteCount(default_value);
    }

    pub fn textDefaultMatchesBytes(self: PointerBuilder, default_value: []const u8, count: usize) Error!bool {
        return (try self.getTextDefaultByteCount(default_value)) == count;
    }

    pub fn getTextByteCount(self: PointerBuilder) Error!usize {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getTextByteCount();
    }

    pub fn textMatchesBytes(self: PointerBuilder, count: usize) Error!bool {
        return (try self.getTextByteCount()) == count;
    }

    pub fn getData(self: PointerBuilder) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getData();
    }

    pub fn getDataDefault(self: PointerBuilder, default_value: []const u8) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getDataDefault(default_value);
    }

    pub fn getDataDefaultByteCount(self: PointerBuilder, default_value: []const u8) Error!usize {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getDataDefaultByteCount(default_value);
    }

    pub fn dataDefaultMatchesBytes(self: PointerBuilder, default_value: []const u8, count: usize) Error!bool {
        return (try self.getDataDefaultByteCount(default_value)) == count;
    }

    pub fn getDataByteCount(self: PointerBuilder) Error!usize {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getDataByteCount();
    }

    pub fn dataMatchesBytes(self: PointerBuilder, count: usize) Error!bool {
        return (try self.getDataByteCount()) == count;
    }

    pub fn setCapability(self: PointerBuilder, index: u32) void {
        self.message.writePtr(self.segment_id, self.word_index, wire.encodeCapability(index)) catch return;
    }

    pub fn getCapabilityIndex(self: PointerBuilder) Error!u32 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).getCapabilityIndex();
    }

    pub fn maxCapabilityCount(self: PointerBuilder) Error!usize {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
        }).maxCapabilityCount();
    }

    pub fn matchesMaxCapabilityCount(self: PointerBuilder, count: usize) bool {
        return (self.maxCapabilityCount() catch return false) == count;
    }

    pub fn copyFrom(self: PointerBuilder, source: PointerReader) Error!void {
        try self.copyFromMode(source, false);
    }

    pub fn copyFromBuilder(self: PointerBuilder, source: PointerBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyFrom(source.asReader(&reader));
    }

    pub fn copyFromCanonical(self: PointerBuilder, source: PointerReader) Error!void {
        try self.copyFromMode(source, true);
    }

    pub fn copyFromCanonicalBuilder(self: PointerBuilder, source: PointerBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyFromCanonical(source.asReader(&reader));
    }

    pub fn copyStructFrom(self: PointerBuilder, source: StructReader) Error!void {
        const dst = try self.initStruct(.{
            .data_words = source.data_words,
            .pointer_count = source.pointer_count,
        });
        try copyStructDataFromReader(dst, source);
        for (0..source.pointer_count) |i| {
            try (try dst.getPointerField(i)).copyFrom(source.getPointerField(i));
        }
    }

    pub fn copyStructFromCanonical(self: PointerBuilder, source: StructReader) Error!void {
        const dst_size = try canonicalStructSize(source);
        const dst = try self.initStruct(dst_size);
        try copyStructDataFromReader(dst, source);
        for (0..dst_size.pointer_count) |i| {
            try (try dst.getPointerField(i)).copyFromCanonical(source.getPointerField(i));
        }
    }

    pub fn copyStructFromBuilder(self: PointerBuilder, source: StructBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyStructFrom(source.asReader(&reader));
    }

    pub fn copyStructFromCanonicalBuilder(self: PointerBuilder, source: StructBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyStructFromCanonical(source.asReader(&reader));
    }

    pub fn copyListFrom(self: PointerBuilder, source: ListReader) Error!void {
        try self.copyListFromMode(source, false);
    }

    pub fn copyListFromBuilder(self: PointerBuilder, source: ListBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyListFrom(source.asReader(&reader));
    }

    pub fn copyListFromCanonical(self: PointerBuilder, source: ListReader) Error!void {
        try self.copyListFromMode(source, true);
    }

    pub fn copyListFromCanonicalBuilder(self: PointerBuilder, source: ListBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyListFromCanonical(source.asReader(&reader));
    }

    fn copyFromMode(self: PointerBuilder, source: PointerReader, canonical: bool) Error!void {
        const resolved = try source.resolve();
        if (resolved.raw == 0) {
            try self.message.writePtr(self.segment_id, self.word_index, 0);
            return;
        }

        switch (wire.pointerType(resolved.raw)) {
            .struct_ptr => {
                const src = try source.getStruct(null);
                const dst_size = if (canonical) try canonicalStructSize(src) else wire.StructSize{
                    .data_words = src.data_words,
                    .pointer_count = src.pointer_count,
                };
                const dst = try self.initStruct(.{
                    .data_words = dst_size.data_words,
                    .pointer_count = dst_size.pointer_count,
                });
                try copyStructDataFromReader(dst, src);
                for (0..dst_size.pointer_count) |i| {
                    const dst_ptr = try dst.getPointerField(i);
                    if (canonical) {
                        try dst_ptr.copyFromCanonical(src.getPointerField(i));
                    } else {
                        try dst_ptr.copyFrom(src.getPointerField(i));
                    }
                }
            },
            .list => {
                const src = try source.getList(null);
                try self.copyListFromMode(src, canonical);
            },
            .far => return error.InvalidFarPointer,
            .other => {
                _ = try wire.decodeOther(resolved.raw);
                try self.message.writePtr(self.segment_id, self.word_index, resolved.raw);
            },
        }
    }

    fn copyListFromMode(self: PointerBuilder, source: ListReader, canonical: bool) Error!void {
        if (source.element_size == .composite) {
            const dst_size = if (canonical) try canonicalStructListSize(source) else wire.StructSize{
                .data_words = source.data_words,
                .pointer_count = source.pointer_count,
            };
            const dst = try self.initStructList(source.element_count, dst_size);
            for (0..source.element_count) |i| {
                const src_element = try source.getStructElement(i);
                const dst_element = try dst.getStructElement(i);
                try copyStructDataFromReader(dst_element, src_element);
                for (0..dst_size.pointer_count) |j| {
                    const dst_ptr = try dst_element.getPointerField(j);
                    if (canonical) {
                        try dst_ptr.copyFromCanonical(src_element.getPointerField(j));
                    } else {
                        try dst_ptr.copyFrom(src_element.getPointerField(j));
                    }
                }
            }
            return;
        }

        const dst = try self.initList(source.element_size, source.element_count);
        if (source.element_size == .pointer) {
            for (0..source.element_count) |i| {
                const dst_ptr = try dst.getPointerElement(i);
                const src_ptr = try source.getPointerElement(i);
                if (canonical) {
                    try dst_ptr.copyFromCanonical(src_ptr);
                } else {
                    try dst_ptr.copyFrom(src_ptr);
                }
            }
        } else {
            try copyPrimitiveList(dst, source);
        }
    }
};

pub fn copyPrimitiveList(dst: ListBuilder, source: ListReader) Error!void {
    if (dst.element_count != source.element_count) return error.IncompatibleListShape;
    if (wire.bitsPerElement(dst.element_size) != wire.bitsPerElement(source.element_size)) return error.IncompatibleListShape;
    switch (source.element_size) {
        .void => {},
        .bit => for (0..source.element_count) |i| try dst.setBool(i, source.getBool(i)),
        .byte => for (0..source.element_count) |i| try dst.setUInt8(i, source.getUInt8(i)),
        .two_bytes => for (0..source.element_count) |i| try dst.setUInt16(i, source.getUInt16(i)),
        .four_bytes => for (0..source.element_count) |i| try dst.setUInt32(i, source.getUInt32(i)),
        .eight_bytes => for (0..source.element_count) |i| try dst.setUInt64(i, source.getUInt64(i)),
        .pointer, .composite => return error.IncompatibleListShape,
    }
}

pub fn copyPrimitiveBuilderList(dst: ListBuilder, source: ListBuilder, start_index: usize) Error!void {
    if (wire.bitsPerElement(dst.element_size) != wire.bitsPerElement(source.element_size)) return error.IncompatibleListShape;
    if (start_index > source.element_count or source.element_count - start_index < dst.element_count) return error.PointerOutOfBounds;
    switch (source.element_size) {
        .void => {},
        .bit => for (0..dst.element_count) |i| try dst.setBool(i, try source.getBool(start_index + i)),
        .byte => for (0..dst.element_count) |i| try dst.setUInt8(i, try source.getUInt8(start_index + i)),
        .two_bytes => for (0..dst.element_count) |i| try dst.setUInt16(i, try source.getUInt16(start_index + i)),
        .four_bytes => for (0..dst.element_count) |i| try dst.setUInt32(i, try source.getUInt32(start_index + i)),
        .eight_bytes => for (0..dst.element_count) |i| try dst.setUInt64(i, try source.getUInt64(start_index + i)),
        .pointer, .composite => return error.IncompatibleListShape,
    }
}

pub fn copyStructDataFromReader(dst: StructBuilder, source: StructReader) Error!void {
    const dst_data = try dst.dataBytesChecked();
    const source_data = try source.dataBytesChecked();
    const data_len = @min(dst_data.len, source_data.len);
    @memcpy(dst_data[0..data_len], source_data[0..data_len]);
}

pub fn listRangeShouldCopyBackward(dst: ListBuilder, dst_index: usize, source: ListReader, source_index: usize, count: usize) Error!bool {
    if (count <= 1) return false;
    if (dst.segment_id != source.segment_id) return false;
    if (dst.segment_id >= dst.message.segments.items.len) return error.SegmentOutOfBounds;
    if (source.segment_id >= source.message.segments.len) return error.SegmentOutOfBounds;
    const dst_segment = std.mem.sliceAsBytes(dst.message.segments.items[dst.segment_id].words.items);
    const src_segment = source.message.segments[source.segment_id];
    if (dst_segment.ptr != src_segment.ptr) return false;

    const dst_bits = try listElementBitRange(dst.start, 0, dst.step_bits, dst_index, count);
    const src_bits = try listElementBitRange(source.start, source.bit_offset, source.step_bits, source_index, count);
    return dst_bits.start > src_bits.start and dst_bits.start < src_bits.end;
}

pub fn listElementBitRange(base_word: usize, base_bit_offset: usize, step_bits: usize, index: usize, count: usize) Error!struct { start: usize, end: usize } {
    const start_offset = std.math.add(
        usize,
        base_bit_offset,
        std.math.mul(usize, index, step_bits) catch return error.MessageTooLarge,
    ) catch return error.MessageTooLarge;
    const start = try checkedWordBitOffset(base_word, start_offset);
    const bit_len = std.math.mul(usize, count, step_bits) catch return error.MessageTooLarge;
    return .{
        .start = start,
        .end = std.math.add(usize, start, bit_len) catch return error.MessageTooLarge,
    };
}

/// A read-only pointer slot inside a `MessageReader`.
pub const PointerReader = struct {
    message: *MessageReader,
    segment_id: u32,
    word_index: usize,
    nesting_left: u16,
    null_override: bool = false,
    raw_override: ?wire.Word = null,

    pub fn raw(self: PointerReader) Error!wire.Word {
        if (self.raw_override) |raw_value| return raw_value;
        if (self.null_override) return 0;
        return self.message.readWord(self.segment_id, self.word_index);
    }

    pub fn isNull(self: PointerReader) bool {
        return (self.raw() catch 0) == 0;
    }

    pub fn pointerType(self: PointerReader) Error!?wire.PointerType {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return null;
        return wire.pointerType(resolved.raw);
    }

    pub fn segmentId(self: PointerReader) u32 {
        return self.segment_id;
    }

    pub fn pointerWordIndex(self: PointerReader) usize {
        return self.word_index;
    }

    pub fn matchesLocation(self: PointerReader, segment_id: u32, word_index: usize) bool {
        return self.segment_id == segment_id and self.word_index == word_index;
    }

    pub fn matchesPointerType(self: PointerReader, expected: wire.PointerType) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.matches(expected);
    }

    pub fn isStructPointer(self: PointerReader) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.isStruct();
    }

    pub fn isListPointer(self: PointerReader) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.isList();
    }

    pub fn isFarPointer(self: PointerReader) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.isFar();
    }

    pub fn isCapabilityPointer(self: PointerReader) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.isCapability();
    }

    pub fn isOtherPointer(self: PointerReader) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.isOther();
    }

    pub fn isNearPointer(self: PointerReader) bool {
        const kind = self.pointerType() catch return false;
        return kind != null and kind.?.isNear();
    }

    pub fn decode(self: PointerReader) Error!?wire.DecodedPointer {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return null;
        return try wire.decode(resolved.raw);
    }

    pub fn validate(self: PointerReader) Error!MessageStats {
        var stats: MessageStats = .{};
        try validatePointer(self, &stats);
        return stats;
    }

    pub fn validateWithOptions(self: PointerReader, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(self.message.segments, options);
        return (PointerReader{
            .message = &reader,
            .segment_id = self.segment_id,
            .word_index = self.word_index,
            .nesting_left = reader.options.nesting_limit,
            .null_override = self.null_override,
            .raw_override = self.raw_override,
        }).validate();
    }

    pub fn totalSize(self: PointerReader) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn totalSizeWithOptions(self: PointerReader, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn getStruct(self: PointerReader, default_value: ?StructReader) Error!StructReader {
        const resolved = try self.resolve();
        if (resolved.raw == 0) {
            if (default_value) |default| return default;
            return error.NullPointer;
        }
        if (wire.pointerType(resolved.raw) != .struct_ptr) return error.InvalidPointerKind;
        const s = wire.decodeStruct(resolved.raw);
        const target = try wire.targetWordIndex(resolved.pointer_word_index, s.offset_words);
        const total = @as(usize, s.data_words) + @as(usize, s.pointer_count);
        try self.boundsCheck(resolved.segment_id, target, total);
        try self.descend(total);
        return .{
            .message = self.message,
            .segment_id = resolved.segment_id,
            .data_start = target,
            .pointer_start = target + s.data_words,
            .data_words = s.data_words,
            .pointer_count = s.pointer_count,
            .nesting_left = self.nesting_left - 1,
        };
    }

    pub fn getStructSize(self: PointerReader) Error!wire.StructSize {
        return (try self.getStruct(null)).size();
    }

    pub fn getStructDataWordCount(self: PointerReader) Error!u16 {
        return (try self.getStructSize()).dataWordCount();
    }

    pub fn getStructPointerCount(self: PointerReader) Error!u16 {
        return (try self.getStructSize()).pointerCount();
    }

    pub fn getStructTotalWords(self: PointerReader) Error!usize {
        return (try self.getStructSize()).totalWords();
    }

    pub fn getStructDataByteCount(self: PointerReader) Error!usize {
        return (try self.getStructSize()).dataByteCount();
    }

    pub fn getStructPointerByteCount(self: PointerReader) Error!usize {
        return (try self.getStructSize()).pointerByteCount();
    }

    pub fn getStructTotalByteCount(self: PointerReader) Error!usize {
        return (try self.getStructSize()).totalByteCount();
    }

    pub fn structMatchesSize(self: PointerReader, expected: wire.StructSize) Error!bool {
        const actual = try self.getStructSize();
        return actual.data_words == expected.data_words and actual.pointer_count == expected.pointer_count;
    }

    pub fn structMatchesDataWords(self: PointerReader, count: u16) Error!bool {
        return (try self.getStructSize()).matchesDataWords(count);
    }

    pub fn structMatchesPointerCount(self: PointerReader, count: u16) Error!bool {
        return (try self.getStructSize()).matchesPointerCount(count);
    }

    pub fn structMatchesTotalWords(self: PointerReader, count: usize) Error!bool {
        return (try self.getStructSize()).matchesTotalWords(count);
    }

    pub fn structMatchesTotalBytes(self: PointerReader, count: usize) Error!bool {
        return (try self.getStructSize()).matchesTotalBytes(count);
    }

    pub fn getList(self: PointerReader, expected: ?wire.ElementSize) Error!ListReader {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return error.NullPointer;
        if (wire.pointerType(resolved.raw) != .list) return error.InvalidPointerKind;
        const l = try wire.decodeList(resolved.raw);
        const view_element_size = if (expected) |exp| blk: {
            if (exp == l.element_size) break :blk exp;
            if (l.element_size != .composite) {
                // Match Cap'n Proto's schema-evolution rule for list views:
                // a list whose stored elements are wider may be read through a
                // narrower primitive schema by keeping the original stride and
                // reading the low-order field.  Boolean lists are excluded by
                // upstream too because bit packing cannot provide an addressable
                // struct/data field per element.
                if (exp != .composite) {
                    if (l.element_size == .bit or exp == .bit) return error.IncompatibleListShape;
                    if (listDataBitsPerElement(exp) > listDataBitsPerElement(l.element_size)) return error.IncompatibleListShape;
                    if (primitivePointerCount(exp) > primitivePointerCount(l.element_size)) return error.IncompatibleListShape;
                }
                break :blk exp;
            }
            break :blk exp;
        } else l.element_size;
        const struct_list_upgrade = l.element_size != .composite and view_element_size == .composite;
        const target = try wire.targetWordIndex(resolved.pointer_word_index, l.offset_words);

        if (l.element_size == .composite) {
            const content_words: usize = l.element_count_or_words;
            try self.boundsCheck(resolved.segment_id, target, content_words + 1);
            const tag = try self.message.readWord(resolved.segment_id, target);
            const decoded_tag = try wire.decodeStructListTag(tag);
            const expected_words = try wire.wordsForStructList(decoded_tag.element_count, decoded_tag.size);
            if (expected_words > content_words) return error.PointerOutOfBounds;
            try self.descend(@max(content_words, decoded_tag.element_count));
            const step_bits = decoded_tag.size.totalWords() * wire.bits_per_word;
            if (expected) |exp| {
                if (exp != .composite) {
                    if (listDataBitsPerElement(exp) > @as(usize, decoded_tag.size.data_words) * wire.bits_per_word) return error.IncompatibleListShape;
                    if (primitivePointerCount(exp) > decoded_tag.size.pointer_count) return error.IncompatibleListShape;
                    return .{
                        .message = self.message,
                        .segment_id = resolved.segment_id,
                        .start = target + 1,
                        .element_count = decoded_tag.element_count,
                        .element_size = exp,
                        .data_words = decoded_tag.size.data_words,
                        .pointer_count = decoded_tag.size.pointer_count,
                        .step_bits = step_bits,
                        .nesting_left = self.nesting_left - 1,
                        .element_data_bits = @as(usize, decoded_tag.size.data_words) * wire.bits_per_word,
                        .limit_element_data_bits = exp != .pointer,
                    };
                }
            }
            return .{
                .message = self.message,
                .segment_id = resolved.segment_id,
                .start = target + 1,
                .element_count = decoded_tag.element_count,
                .element_size = .composite,
                .data_words = decoded_tag.size.data_words,
                .pointer_count = decoded_tag.size.pointer_count,
                .step_bits = step_bits,
                .nesting_left = self.nesting_left - 1,
            };
        }

        const words = try wire.wordsForList(l.element_size, l.element_count_or_words);
        try self.boundsCheck(resolved.segment_id, target, words);
        try self.descend(@max(words, @as(usize, l.element_count_or_words)));
        if (struct_list_upgrade) {
            const shape = try upgradedStructListShape(l.element_size);
            return .{
                .message = self.message,
                .segment_id = resolved.segment_id,
                .start = target,
                .element_count = l.element_count_or_words,
                .element_size = .composite,
                .data_words = shape.data_words,
                .pointer_count = shape.pointer_count,
                .step_bits = wire.bitsPerElement(l.element_size),
                .nesting_left = self.nesting_left - 1,
                .element_data_bits = if (shape.pointer_count == 0) wire.bitsPerElement(l.element_size) else 0,
                .limit_element_data_bits = shape.pointer_count == 0,
            };
        }
        return .{
            .message = self.message,
            .segment_id = resolved.segment_id,
            .start = target,
            .element_count = l.element_count_or_words,
            .element_size = view_element_size,
            .data_words = primitiveDataWords(l.element_size),
            .pointer_count = primitivePointerCount(l.element_size),
            .step_bits = wire.bitsPerElement(l.element_size),
            .nesting_left = self.nesting_left - 1,
            .element_data_bits = listDataBitsPerElement(l.element_size),
            .limit_element_data_bits = view_element_size != .pointer,
        };
    }

    pub fn getListLen(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).len();
    }

    pub fn listMatchesLen(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesLen(count);
    }

    pub fn listIsEmpty(self: PointerReader, expected: ?wire.ElementSize) Error!bool {
        return (try self.getList(expected)).isEmpty();
    }

    pub fn listHasIndex(self: PointerReader, expected: ?wire.ElementSize, index: usize) Error!bool {
        return (try self.getList(expected)).hasIndex(index);
    }

    pub fn getListFirstIndex(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).firstIndex();
    }

    pub fn getListLastIndex(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).lastIndex();
    }

    pub fn getListElementSize(self: PointerReader, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return (try self.getList(expected)).elementSize();
    }

    pub fn listMatchesElementSize(self: PointerReader, expected: ?wire.ElementSize, element_size: wire.ElementSize) Error!bool {
        return (try self.getList(expected)).matchesElementSize(element_size);
    }

    pub fn getListElementBitCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementBitCount();
    }

    pub fn listMatchesElementBits(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesElementBits(count);
    }

    pub fn getListElementByteCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementByteCount();
    }

    pub fn listMatchesElementBytes(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesElementBytes(count);
    }

    pub fn getListElementWordCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementWordCount();
    }

    pub fn listMatchesElementWords(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesElementWords(count);
    }

    pub fn getListContentBitCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentBitCount();
    }

    pub fn listMatchesContentBits(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesContentBits(count);
    }

    pub fn getListContentByteCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentByteCount();
    }

    pub fn getListContentWordCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentWordCount();
    }

    pub fn listMatchesContentBytes(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesContentBytes(count);
    }

    pub fn listMatchesContentWords(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesContentWords(count);
    }

    pub fn getListStructElementSize(self: PointerReader, expected: ?wire.ElementSize) Error!wire.StructSize {
        return (try self.getList(expected)).structElementSize();
    }

    pub fn getListStructElementDataWordCount(self: PointerReader, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getList(expected)).structElementDataWordCount();
    }

    pub fn getListStructElementPointerCount(self: PointerReader, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getList(expected)).structElementPointerCount();
    }

    pub fn getListStructElementTotalWords(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementTotalWords();
    }

    pub fn getListStructElementDataByteCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementDataByteCount();
    }

    pub fn getListStructElementPointerByteCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementPointerByteCount();
    }

    pub fn getListStructElementTotalByteCount(self: PointerReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementTotalByteCount();
    }

    pub fn listMatchesStructElementSize(self: PointerReader, expected: ?wire.ElementSize, size: wire.StructSize) Error!bool {
        return (try self.getList(expected)).matchesStructElementSize(size);
    }

    pub fn listMatchesStructElementDataWords(self: PointerReader, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getList(expected)).matchesStructElementDataWords(count);
    }

    pub fn listMatchesStructElementPointerCount(self: PointerReader, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getList(expected)).matchesStructElementPointerCount(count);
    }

    pub fn listMatchesStructElementTotalWords(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementTotalWords(count);
    }

    pub fn listMatchesStructElementDataBytes(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementDataBytes(count);
    }

    pub fn listMatchesStructElementPointerBytes(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementPointerBytes(count);
    }

    pub fn listMatchesStructElementTotalBytes(self: PointerReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getList(expected)).matchesStructElementTotalBytes(count);
    }

    pub fn getText(self: PointerReader) Error![]const u8 {
        const list = try self.getList(.byte);
        const bytes = list.bytes();
        if (bytes.len == 0 or bytes[bytes.len - 1] != 0) return error.TextNotNulTerminated;
        const text = bytes[0 .. bytes.len - 1];
        if (std.mem.indexOfScalar(u8, text, 0) != null) return error.TextContainsInteriorNul;
        if (!std.unicode.utf8ValidateSlice(text)) return error.Utf8Invalid;
        return text;
    }

    pub fn getTextDefault(self: PointerReader, default_value: []const u8) Error![]const u8 {
        if ((try self.raw()) == 0) {
            if (std.mem.indexOfScalar(u8, default_value, 0) != null) return error.TextContainsInteriorNul;
            if (!std.unicode.utf8ValidateSlice(default_value)) return error.Utf8Invalid;
            return default_value;
        }
        return self.getText();
    }

    pub fn getTextDefaultByteCount(self: PointerReader, default_value: []const u8) Error!usize {
        return (try self.getTextDefault(default_value)).len;
    }

    pub fn textDefaultMatchesBytes(self: PointerReader, default_value: []const u8, count: usize) Error!bool {
        return (try self.getTextDefaultByteCount(default_value)) == count;
    }

    pub fn getTextByteCount(self: PointerReader) Error!usize {
        return (try self.getText()).len;
    }

    pub fn textMatchesBytes(self: PointerReader, count: usize) Error!bool {
        return (try self.getTextByteCount()) == count;
    }

    pub fn getData(self: PointerReader) Error![]const u8 {
        return (try self.getList(.byte)).bytes();
    }

    pub fn getDataDefault(self: PointerReader, default_value: []const u8) Error![]const u8 {
        if ((try self.raw()) == 0) return default_value;
        return self.getData();
    }

    pub fn getDataDefaultByteCount(self: PointerReader, default_value: []const u8) Error!usize {
        return (try self.getDataDefault(default_value)).len;
    }

    pub fn dataDefaultMatchesBytes(self: PointerReader, default_value: []const u8, count: usize) Error!bool {
        return (try self.getDataDefaultByteCount(default_value)) == count;
    }

    pub fn getDataByteCount(self: PointerReader) Error!usize {
        return (try self.getData()).len;
    }

    pub fn dataMatchesBytes(self: PointerReader, count: usize) Error!bool {
        return (try self.getDataByteCount()) == count;
    }

    pub fn getCapabilityIndex(self: PointerReader) Error!u32 {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return error.NullPointer;
        if (wire.pointerType(resolved.raw) != .other) return error.InvalidPointerKind;
        return (try wire.decodeOther(resolved.raw)).index;
    }

    pub fn maxCapabilityCount(self: PointerReader) Error!usize {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return error.NullPointer;
        if (wire.pointerType(resolved.raw) != .other) return error.InvalidPointerKind;
        return (try wire.decodeOther(resolved.raw)).maxCapabilityCount();
    }

    pub fn matchesMaxCapabilityCount(self: PointerReader, count: usize) bool {
        return (self.maxCapabilityCount() catch return false) == count;
    }

    fn descend(self: PointerReader, words: usize) Error!void {
        if (self.nesting_left == 0) return error.NestingLimitExceeded;
        try self.message.charge(words);
    }

    fn boundsCheck(self: PointerReader, segment_id: u32, start: usize, words: usize) Error!void {
        const segment_words = try self.message.segmentWords(segment_id);
        if (start > segment_words or segment_words - start < words) return error.PointerOutOfBounds;
    }

    pub fn resolve(self: PointerReader) Error!ResolvedPointer {
        if (self.null_override) {
            return .{ .segment_id = self.segment_id, .pointer_word_index = self.word_index, .raw = 0 };
        }
        const raw_value = if (self.raw_override) |raw_override| raw_override else try self.message.readWord(self.segment_id, self.word_index);
        if (raw_value == 0 or wire.pointerType(raw_value) != .far) {
            return .{ .segment_id = self.segment_id, .pointer_word_index = self.word_index, .raw = raw_value };
        }

        const far = wire.decodeFar(raw_value);
        const landing_segment_words = try self.message.segmentWords(far.segment_id);
        if (far.landing_pad_offset >= landing_segment_words) return error.InvalidFarPointer;

        if (!far.two_word_landing_pad) {
            const landing_raw = try self.message.readWord(far.segment_id, far.landing_pad_offset);
            return .{ .segment_id = far.segment_id, .pointer_word_index = far.landing_pad_offset, .raw = landing_raw };
        }

        if (landing_segment_words - far.landing_pad_offset < 2) return error.InvalidFarPointer;
        const landing_far_raw = try self.message.readWord(far.segment_id, far.landing_pad_offset);
        if (wire.pointerType(landing_far_raw) != .far) return error.InvalidFarPointer;
        const landing_far = wire.decodeFar(landing_far_raw);
        if (landing_far.two_word_landing_pad) return error.InvalidFarPointer;
        const tag_raw = try self.message.readWord(far.segment_id, far.landing_pad_offset + 1);
        const target_segment_words = try self.message.segmentWords(landing_far.segment_id);
        // The inner pointer in a double-far landing pad points at object content,
        // not at another landing-pad word.  Cap'n Proto permits zero-word
        // objects (for example void lists) to start exactly one-past the end of
        // their segment.  The typed reader below will perform the size-aware
        // bounds check after decoding the tag, so resolve only rejects offsets
        // that are impossible even for an empty object.
        if (@as(usize, landing_far.landing_pad_offset) > target_segment_words) return error.InvalidFarPointer;
        const adjusted_tag = switch (wire.pointerType(tag_raw)) {
            .struct_ptr => blk: {
                const s = wire.decodeStruct(tag_raw);
                break :blk try wire.encodeStruct(-1, s.data_words, s.pointer_count);
            },
            .list => blk: {
                const l = try wire.decodeList(tag_raw);
                break :blk try wire.encodeList(-1, l.element_size, l.element_count_or_words);
            },
            else => return error.InvalidFarPointer,
        };
        return .{ .segment_id = landing_far.segment_id, .pointer_word_index = landing_far.landing_pad_offset, .raw = adjusted_tag };
    }
};

pub const ResolvedPointer = struct {
    segment_id: u32,
    pointer_word_index: usize,
    raw: wire.Word,
};
