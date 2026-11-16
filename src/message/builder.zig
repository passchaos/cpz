const std = @import("std");
const wire = @import("../wire.zig");
const zero = @import("../zero.zig");
const serialize = @import("../serialize.zig");

const mod_list = @import("list.zig");
const mod_options = @import("options.zig");
const mod_pointer = @import("pointer.zig");
const mod_reader = @import("reader.zig");
const mod_struct = @import("struct.zig");
const mod_validate = @import("validate.zig");

const ListBuilder = mod_list.ListBuilder;
const ListReader = mod_list.ListReader;
const Error = mod_options.Error;
const MessageSize = mod_options.MessageSize;
const MessageStats = mod_options.MessageStats;
const ReaderOptions = mod_options.ReaderOptions;
const wordsToBytesChecked = mod_options.wordsToBytesChecked;
const wordsToBytesSaturating = mod_options.wordsToBytesSaturating;
const PointerBuilder = mod_pointer.PointerBuilder;
const PointerReader = mod_pointer.PointerReader;
const MessageReader = mod_reader.MessageReader;
const messageToCanonicalSegmentBytes = mod_reader.messageToCanonicalSegmentBytes;
const messageToSingleSegmentFlatBytes = mod_reader.messageToSingleSegmentFlatBytes;
const toCanonicalSegmentBytes = mod_reader.toCanonicalSegmentBytes;
const toSingleSegmentFlatBytes = mod_reader.toSingleSegmentFlatBytes;
const StructBuilder = mod_struct.StructBuilder;
const StructReader = mod_struct.StructReader;
const segmentIdFromIndex = mod_validate.segmentIdFromIndex;
const tag_forFarWithZeroOffset = mod_validate.tag_forFarWithZeroOffset;

/// Initial segment sizing options for `MessageBuilder`.
pub const BuilderOptions = struct {
    first_segment_words: usize = 1024,
    next_segment_min_words: usize = 1024,

    pub fn firstSegmentWords(self: BuilderOptions) usize {
        return self.first_segment_words;
    }

    pub fn firstSegmentBytes(self: BuilderOptions) usize {
        return wordsToBytesSaturating(self.first_segment_words);
    }

    pub fn nextSegmentMinWords(self: BuilderOptions) usize {
        return self.next_segment_min_words;
    }

    pub fn nextSegmentMinBytes(self: BuilderOptions) usize {
        return wordsToBytesSaturating(self.next_segment_min_words);
    }

    pub fn matchesFirstSegmentWords(self: BuilderOptions, count: usize) bool {
        return self.first_segment_words == count;
    }

    pub fn matchesFirstSegmentBytes(self: BuilderOptions, count: usize) bool {
        return self.firstSegmentBytes() == count;
    }

    pub fn matchesNextSegmentMinWords(self: BuilderOptions, count: usize) bool {
        return self.next_segment_min_words == count;
    }

    pub fn matchesNextSegmentMinBytes(self: BuilderOptions, count: usize) bool {
        return self.nextSegmentMinBytes() == count;
    }
};

pub const SegmentBuilder = struct {
    words: std.ArrayList(wire.Word),
    used: usize,

    fn init(allocator: std.mem.Allocator, capacity_words: usize) !SegmentBuilder {
        var words = try std.ArrayList(wire.Word).initCapacity(allocator, capacity_words);
        try words.resize(allocator, capacity_words);
        return .{ .words = words, .used = 0 };
    }

    fn deinit(self: *SegmentBuilder, allocator: std.mem.Allocator) void {
        self.words.deinit(allocator);
        self.* = undefined;
    }

    fn alloc(self: *SegmentBuilder, word_count: usize) ?usize {
        if (word_count == 0) return self.used;
        if (self.words.items.len - self.used < word_count) return null;
        const start = self.used;
        self.used += word_count;
        zero.bytes(std.mem.sliceAsBytes(self.words.items[start..self.used]));
        return start;
    }

    fn allocatedBytes(self: *const SegmentBuilder) []const u8 {
        return std.mem.sliceAsBytes(self.words.items[0..self.used]);
    }
};

pub const SegmentCursor = struct {
    id: u32,
    start: usize,
};

/// A detached object owned by a `MessageBuilder`.
pub const Orphan = struct {
    message: *MessageBuilder,
    segment_id: u32,
    pointer_word_index: usize,
    raw: wire.Word,

    pub fn isNull(self: Orphan) bool {
        return self.raw == 0;
    }

    pub fn pointerType(self: Orphan) ?wire.PointerType {
        if (self.raw == 0) return null;
        return wire.pointerType(self.raw);
    }

    pub fn segmentId(self: Orphan) u32 {
        return self.segment_id;
    }

    pub fn pointerWordIndex(self: Orphan) usize {
        return self.pointer_word_index;
    }

    pub fn matchesLocation(self: Orphan, segment_id: u32, word_index: usize) bool {
        return self.segment_id == segment_id and self.pointer_word_index == word_index;
    }

    pub fn matchesPointerType(self: Orphan, expected: wire.PointerType) bool {
        const kind = self.pointerType() orelse return false;
        return kind.matches(expected);
    }

    pub fn isStructPointer(self: Orphan) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isStruct();
    }

    pub fn isListPointer(self: Orphan) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isList();
    }

    pub fn isFarPointer(self: Orphan) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isFar();
    }

    pub fn isOtherPointer(self: Orphan) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isOther();
    }

    pub fn isCapabilityPointer(self: Orphan) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isCapability();
    }

    pub fn isNearPointer(self: Orphan) bool {
        const kind = self.pointerType() orelse return false;
        return kind.isNear();
    }

    pub fn decode(self: Orphan, message_reader: *MessageReader) Error!?wire.DecodedPointer {
        return self.asReader(message_reader).decode();
    }

    pub fn asReader(self: Orphan, message_reader: *MessageReader) PointerReader {
        return .{
            .message = message_reader,
            .segment_id = self.segment_id,
            .word_index = self.pointer_word_index,
            .nesting_left = message_reader.options.nesting_limit,
            .raw_override = self.raw,
        };
    }

    pub fn getStruct(self: Orphan) Error!StructBuilder {
        if (self.raw == 0) return error.NullPointer;
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        const struct_reader = try self.asReader(&reader).getStruct(null);
        return .{
            .message = self.message,
            .segment_id = struct_reader.segment_id,
            .data_start = struct_reader.data_start,
            .pointer_start = struct_reader.pointer_start,
            .data_words = struct_reader.data_words,
            .pointer_count = struct_reader.pointer_count,
        };
    }

    pub fn structSize(self: Orphan) Error!wire.StructSize {
        return (try self.getStruct()).size();
    }

    pub fn structDataWordCount(self: Orphan) Error!u16 {
        return (try self.structSize()).dataWordCount();
    }

    pub fn structPointerCount(self: Orphan) Error!u16 {
        return (try self.structSize()).pointerCount();
    }

    pub fn structTotalWords(self: Orphan) Error!usize {
        return (try self.structSize()).totalWords();
    }

    pub fn structDataByteCount(self: Orphan) Error!usize {
        return (try self.structSize()).dataByteCount();
    }

    pub fn structPointerByteCount(self: Orphan) Error!usize {
        return (try self.structSize()).pointerByteCount();
    }

    pub fn structTotalByteCount(self: Orphan) Error!usize {
        return (try self.structSize()).totalByteCount();
    }

    pub fn structMatchesSize(self: Orphan, expected: wire.StructSize) bool {
        const actual = self.structSize() catch return false;
        return actual.data_words == expected.data_words and actual.pointer_count == expected.pointer_count;
    }

    pub fn structMatchesDataWords(self: Orphan, count: u16) bool {
        return (self.structDataWordCount() catch return false) == count;
    }

    pub fn structMatchesPointerCount(self: Orphan, count: u16) bool {
        return (self.structPointerCount() catch return false) == count;
    }

    pub fn structMatchesTotalWords(self: Orphan, count: usize) bool {
        return (self.structTotalWords() catch return false) == count;
    }

    pub fn structMatchesTotalBytes(self: Orphan, count: usize) bool {
        return (self.structTotalByteCount() catch return false) == count;
    }

    pub fn getList(self: Orphan, expected: ?wire.ElementSize) Error!ListBuilder {
        if (self.raw == 0) return error.NullPointer;
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        const list_reader = try self.asReader(&reader).getList(expected);
        return .{
            .message = self.message,
            .segment_id = list_reader.segment_id,
            .start = list_reader.start,
            .element_count = list_reader.element_count,
            .element_size = list_reader.element_size,
            .data_words = list_reader.data_words,
            .pointer_count = list_reader.pointer_count,
            .step_bits = list_reader.step_bits,
            .bit_offset = list_reader.bit_offset,
            .element_data_bits = list_reader.element_data_bits,
            .limit_element_data_bits = list_reader.limit_element_data_bits,
        };
    }

    pub fn getListLen(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).len();
    }

    pub fn listMatchesLen(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListLen(expected) catch return false) == count;
    }

    pub fn listIsEmpty(self: Orphan, expected: ?wire.ElementSize) bool {
        return (self.getList(expected) catch return false).isEmpty();
    }

    pub fn listHasIndex(self: Orphan, expected: ?wire.ElementSize, index: usize) bool {
        return (self.getList(expected) catch return false).hasIndex(index);
    }

    pub fn getListFirstIndex(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).firstIndex();
    }

    pub fn getListLastIndex(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).lastIndex();
    }

    pub fn getListElementSize(self: Orphan, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return (try self.getList(expected)).elementSize();
    }

    pub fn listMatchesElementSize(self: Orphan, expected: ?wire.ElementSize, element_size: wire.ElementSize) bool {
        return (self.getListElementSize(expected) catch return false) == element_size;
    }

    pub fn getListElementBitCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementBitCount();
    }

    pub fn listMatchesElementBits(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListElementBitCount(expected) catch return false) == count;
    }

    pub fn getListElementByteCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementByteCount();
    }

    pub fn listMatchesElementBytes(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListElementByteCount(expected) catch return false) == count;
    }

    pub fn getListElementWordCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).elementWordCount();
    }

    pub fn listMatchesElementWords(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListElementWordCount(expected) catch return false) == count;
    }

    pub fn getListContentBitCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentBitCount();
    }

    pub fn listMatchesContentBits(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListContentBitCount(expected) catch return false) == count;
    }

    pub fn getListContentByteCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentByteCount();
    }

    pub fn getListContentWordCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).contentWordCount();
    }

    pub fn listMatchesContentBytes(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListContentByteCount(expected) catch return false) == count;
    }

    pub fn listMatchesContentWords(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListContentWordCount(expected) catch return false) == count;
    }

    pub fn getListStructElementSize(self: Orphan, expected: ?wire.ElementSize) Error!wire.StructSize {
        return (try self.getList(expected)).structElementSize();
    }

    pub fn getListStructElementDataWordCount(self: Orphan, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getList(expected)).structElementDataWordCount();
    }

    pub fn getListStructElementPointerCount(self: Orphan, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getList(expected)).structElementPointerCount();
    }

    pub fn getListStructElementTotalWords(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementTotalWords();
    }

    pub fn getListStructElementDataByteCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementDataByteCount();
    }

    pub fn getListStructElementPointerByteCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementPointerByteCount();
    }

    pub fn getListStructElementTotalByteCount(self: Orphan, expected: ?wire.ElementSize) Error!usize {
        return (try self.getList(expected)).structElementTotalByteCount();
    }

    pub fn listMatchesStructElementSize(self: Orphan, expected: ?wire.ElementSize, size: wire.StructSize) bool {
        const actual = self.getListStructElementSize(expected) catch return false;
        return actual.data_words == size.data_words and actual.pointer_count == size.pointer_count;
    }

    pub fn listMatchesStructElementDataWords(self: Orphan, expected: ?wire.ElementSize, count: u16) bool {
        return (self.getListStructElementDataWordCount(expected) catch return false) == count;
    }

    pub fn listMatchesStructElementPointerCount(self: Orphan, expected: ?wire.ElementSize, count: u16) bool {
        return (self.getListStructElementPointerCount(expected) catch return false) == count;
    }

    pub fn listMatchesStructElementTotalWords(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListStructElementTotalWords(expected) catch return false) == count;
    }

    pub fn listMatchesStructElementDataBytes(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListStructElementDataByteCount(expected) catch return false) == count;
    }

    pub fn listMatchesStructElementPointerBytes(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListStructElementPointerByteCount(expected) catch return false) == count;
    }

    pub fn listMatchesStructElementTotalBytes(self: Orphan, expected: ?wire.ElementSize, count: usize) bool {
        return (self.getListStructElementTotalByteCount(expected) catch return false) == count;
    }

    pub fn getText(self: Orphan) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getText();
    }

    pub fn getTextDefault(self: Orphan, default_value: []const u8) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getTextDefault(default_value);
    }

    pub fn getTextDefaultByteCount(self: Orphan, default_value: []const u8) Error!usize {
        return (try self.getTextDefault(default_value)).len;
    }

    pub fn textDefaultMatchesBytes(self: Orphan, default_value: []const u8, count: usize) bool {
        return (self.getTextDefaultByteCount(default_value) catch return false) == count;
    }

    pub fn getTextByteCount(self: Orphan) Error!usize {
        return (try self.getText()).len;
    }

    pub fn textMatchesBytes(self: Orphan, count: usize) bool {
        return (self.getTextByteCount() catch return false) == count;
    }

    pub fn getData(self: Orphan) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getData();
    }

    pub fn getDataDefault(self: Orphan, default_value: []const u8) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getDataDefault(default_value);
    }

    pub fn getDataDefaultByteCount(self: Orphan, default_value: []const u8) Error!usize {
        return (try self.getDataDefault(default_value)).len;
    }

    pub fn dataDefaultMatchesBytes(self: Orphan, default_value: []const u8, count: usize) bool {
        return (self.getDataDefaultByteCount(default_value) catch return false) == count;
    }

    pub fn getDataByteCount(self: Orphan) Error!usize {
        return (try self.getData()).len;
    }

    pub fn dataMatchesBytes(self: Orphan, count: usize) bool {
        return (self.getDataByteCount() catch return false) == count;
    }

    pub fn getCapabilityIndex(self: Orphan) Error!u32 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getCapabilityIndex();
    }

    pub fn maxCapabilityCount(self: Orphan) Error!usize {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).maxCapabilityCount();
    }

    pub fn matchesMaxCapabilityCount(self: Orphan, count: usize) bool {
        return (self.maxCapabilityCount() catch return false) == count;
    }

    pub fn validateWithOptions(self: Orphan, options: ReaderOptions) Error!MessageStats {
        if (self.raw == 0) return error.NullPointer;
        var reader = MessageReader.init(try self.message.segmentsConst(), options);
        return self.asReader(&reader).validate();
    }

    pub fn validate(self: Orphan) Error!MessageStats {
        return self.validateWithOptions(.{});
    }

    pub fn totalSizeWithOptions(self: Orphan, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn totalSize(self: Orphan) Error!MessageSize {
        return (try self.validate()).size();
    }

    pub fn release(self: *Orphan) void {
        self.raw = 0;
    }
};

/// An allocator for detached objects within a `MessageBuilder`.
pub const Orphanage = struct {
    message: *MessageBuilder,

    pub fn init(message: *MessageBuilder) Orphanage {
        return .{ .message = message };
    }

    pub fn newStruct(self: Orphanage, size: wire.StructSize) Error!Orphan {
        return self.message.newOrphanStruct(size);
    }

    pub fn newList(self: Orphanage, element_size: wire.ElementSize, element_count: usize) Error!Orphan {
        return self.message.newOrphanList(element_size, element_count);
    }

    pub fn newStructList(self: Orphanage, element_count: usize, size: wire.StructSize) Error!Orphan {
        return self.message.newOrphanStructList(element_count, size);
    }

    pub fn newText(self: Orphanage, text: []const u8) Error!Orphan {
        return self.message.newOrphanText(text);
    }

    pub fn newData(self: Orphanage, data: []const u8) Error!Orphan {
        return self.message.newOrphanData(data);
    }

    pub fn newCapability(self: Orphanage, index: u32) Error!Orphan {
        return self.message.newOrphanCapability(index);
    }

    pub fn newCopyStruct(self: Orphanage, source: StructReader) Error!Orphan {
        return self.message.newOrphanCopyStruct(source);
    }

    pub fn newCopyStructCanonical(self: Orphanage, source: StructReader) Error!Orphan {
        return self.message.newOrphanCopyStructCanonical(source);
    }

    pub fn newCopyStructFromBuilder(self: Orphanage, source: StructBuilder) Error!Orphan {
        return self.message.newOrphanCopyStructFromBuilder(source);
    }

    pub fn newCopyStructCanonicalFromBuilder(self: Orphanage, source: StructBuilder) Error!Orphan {
        return self.message.newOrphanCopyStructCanonicalFromBuilder(source);
    }

    pub fn newCopyList(self: Orphanage, source: ListReader) Error!Orphan {
        return self.message.newOrphanCopyList(source);
    }

    pub fn newCopyListCanonical(self: Orphanage, source: ListReader) Error!Orphan {
        return self.message.newOrphanCopyListCanonical(source);
    }

    pub fn newCopyListFromBuilder(self: Orphanage, source: ListBuilder) Error!Orphan {
        return self.message.newOrphanCopyListFromBuilder(source);
    }

    pub fn newCopyListCanonicalFromBuilder(self: Orphanage, source: ListBuilder) Error!Orphan {
        return self.message.newOrphanCopyListCanonicalFromBuilder(source);
    }

    pub fn newCopyPointer(self: Orphanage, source: PointerReader) Error!Orphan {
        return self.message.newOrphanCopyPointer(source);
    }

    pub fn newCopyPointerCanonical(self: Orphanage, source: PointerReader) Error!Orphan {
        return self.message.newOrphanCopyPointerCanonical(source);
    }

    pub fn newCopyPointerFromBuilder(self: Orphanage, source: PointerBuilder) Error!Orphan {
        return self.message.newOrphanCopyPointerFromBuilder(source);
    }

    pub fn newCopyPointerCanonicalFromBuilder(self: Orphanage, source: PointerBuilder) Error!Orphan {
        return self.message.newOrphanCopyPointerCanonicalFromBuilder(source);
    }
};

/// An append-only message builder over one or more word segments.
pub const MessageBuilder = struct {
    allocator: std.mem.Allocator,
    segments: std.ArrayList(SegmentBuilder),
    const_segments_cache: std.ArrayList(serialize.ConstSegment),
    options: BuilderOptions,
    /// Segment that most recently satisfied an allocation, used to find free
    /// space in existing segments before growing the segment list.
    allocation_hint: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: BuilderOptions) !MessageBuilder {
        var segments = std.ArrayList(SegmentBuilder).empty;
        errdefer {
            for (segments.items) |*segment| segment.deinit(allocator);
            segments.deinit(allocator);
        }
        try segments.append(allocator, try SegmentBuilder.init(allocator, @max(options.first_segment_words, 1)));
        _ = segments.items[0].alloc(1).?; // root pointer word.

        return .{
            .allocator = allocator,
            .segments = segments,
            .const_segments_cache = .empty,
            .options = options,
        };
    }

    pub fn deinit(self: *MessageBuilder) void {
        for (self.segments.items) |*segment| segment.deinit(self.allocator);
        self.segments.deinit(self.allocator);
        self.const_segments_cache.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn initRoot(self: *MessageBuilder, size: wire.StructSize) Error!StructBuilder {
        return (try self.getRootPointer()).initStruct(size);
    }

    pub fn initRootList(self: *MessageBuilder, element_size: wire.ElementSize, element_count: usize) Error!ListBuilder {
        return (try self.getRootPointer()).initList(element_size, element_count);
    }

    pub fn initRootStructList(self: *MessageBuilder, element_count: usize, size: wire.StructSize) Error!ListBuilder {
        return (try self.getRootPointer()).initStructList(element_count, size);
    }

    pub fn getRootList(self: *MessageBuilder, expected: ?wire.ElementSize) Error!ListBuilder {
        return (try self.getRootPointer()).getList(expected);
    }

    pub fn getRootListLen(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).len();
    }

    pub fn rootListMatchesLen(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesLen(count);
    }

    pub fn rootListIsEmpty(self: *MessageBuilder, expected: ?wire.ElementSize) Error!bool {
        return (try self.getRootList(expected)).isEmpty();
    }

    pub fn rootListHasIndex(self: *MessageBuilder, expected: ?wire.ElementSize, index: usize) Error!bool {
        return (try self.getRootList(expected)).hasIndex(index);
    }

    pub fn getRootListFirstIndex(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).firstIndex();
    }

    pub fn getRootListLastIndex(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).lastIndex();
    }

    pub fn getRootListElementSize(self: *MessageBuilder, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return (try self.getRootList(expected)).elementSize();
    }

    pub fn rootListMatchesElementSize(self: *MessageBuilder, expected: ?wire.ElementSize, element_size: wire.ElementSize) Error!bool {
        return (try self.getRootList(expected)).matchesElementSize(element_size);
    }

    pub fn getRootListElementBitCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).elementBitCount();
    }

    pub fn rootListMatchesElementBits(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesElementBits(count);
    }

    pub fn getRootListElementByteCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).elementByteCount();
    }

    pub fn rootListMatchesElementBytes(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesElementBytes(count);
    }

    pub fn getRootListElementWordCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).elementWordCount();
    }

    pub fn rootListMatchesElementWords(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesElementWords(count);
    }

    pub fn getRootListContentBitCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).contentBitCount();
    }

    pub fn rootListMatchesContentBits(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesContentBits(count);
    }

    pub fn getRootListContentByteCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).contentByteCount();
    }

    pub fn getRootListContentWordCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).contentWordCount();
    }

    pub fn rootListMatchesContentBytes(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesContentBytes(count);
    }

    pub fn rootListMatchesContentWords(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesContentWords(count);
    }

    pub fn getRootListStructElementSize(self: *MessageBuilder, expected: ?wire.ElementSize) Error!wire.StructSize {
        return (try self.getRootList(expected)).structElementSize();
    }

    pub fn getRootListStructElementDataWordCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getRootList(expected)).structElementDataWordCount();
    }

    pub fn getRootListStructElementPointerCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getRootList(expected)).structElementPointerCount();
    }

    pub fn getRootListStructElementTotalWords(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementTotalWords();
    }

    pub fn getRootListStructElementDataByteCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementDataByteCount();
    }

    pub fn getRootListStructElementPointerByteCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementPointerByteCount();
    }

    pub fn getRootListStructElementTotalByteCount(self: *MessageBuilder, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementTotalByteCount();
    }

    pub fn rootListMatchesStructElementSize(self: *MessageBuilder, expected: ?wire.ElementSize, size: wire.StructSize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementSize(size);
    }

    pub fn rootListMatchesStructElementDataWords(self: *MessageBuilder, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementDataWords(count);
    }

    pub fn rootListMatchesStructElementPointerCount(self: *MessageBuilder, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementPointerCount(count);
    }

    pub fn rootListMatchesStructElementTotalWords(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementTotalWords(count);
    }

    pub fn rootListMatchesStructElementDataBytes(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementDataBytes(count);
    }

    pub fn rootListMatchesStructElementPointerBytes(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementPointerBytes(count);
    }

    pub fn rootListMatchesStructElementTotalBytes(self: *MessageBuilder, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementTotalBytes(count);
    }

    pub fn setRootText(self: *MessageBuilder, text: []const u8) Error!void {
        return (try self.getRootPointer()).setText(text);
    }

    pub fn setRootData(self: *MessageBuilder, data: []const u8) Error!void {
        return (try self.getRootPointer()).setData(data);
    }

    pub fn setRootCapability(self: *MessageBuilder, index: u32) Error!void {
        (try self.getRootPointer()).setCapability(index);
    }

    pub fn newOrphanStruct(self: *MessageBuilder, size: wire.StructSize) Error!Orphan {
        const slot = try self.newOrphanPointer();
        _ = try slot.initStruct(size);
        return slot.disown();
    }

    pub fn newOrphanList(self: *MessageBuilder, element_size: wire.ElementSize, element_count: usize) Error!Orphan {
        const slot = try self.newOrphanPointer();
        _ = try slot.initList(element_size, element_count);
        return slot.disown();
    }

    pub fn newOrphanStructList(self: *MessageBuilder, element_count: usize, size: wire.StructSize) Error!Orphan {
        const slot = try self.newOrphanPointer();
        _ = try slot.initStructList(element_count, size);
        return slot.disown();
    }

    pub fn newOrphanText(self: *MessageBuilder, text: []const u8) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.setText(text);
        return slot.disown();
    }

    pub fn newOrphanData(self: *MessageBuilder, data: []const u8) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.setData(data);
        return slot.disown();
    }

    pub fn newOrphanCapability(self: *MessageBuilder, index: u32) Error!Orphan {
        const slot = try self.newOrphanPointer();
        slot.setCapability(index);
        return slot.disown();
    }

    pub fn newOrphanCopyStruct(self: *MessageBuilder, source: StructReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyStructFrom(source);
        return slot.disown();
    }

    pub fn newOrphanCopyStructCanonical(self: *MessageBuilder, source: StructReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyStructFromCanonical(source);
        return slot.disown();
    }

    pub fn newOrphanCopyStructFromBuilder(self: *MessageBuilder, source: StructBuilder) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyStructFromBuilder(source);
        return slot.disown();
    }

    pub fn newOrphanCopyStructCanonicalFromBuilder(self: *MessageBuilder, source: StructBuilder) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyStructFromCanonicalBuilder(source);
        return slot.disown();
    }

    pub fn newOrphanCopyList(self: *MessageBuilder, source: ListReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyListFrom(source);
        return slot.disown();
    }

    pub fn newOrphanCopyListCanonical(self: *MessageBuilder, source: ListReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyListFromCanonical(source);
        return slot.disown();
    }

    pub fn newOrphanCopyListFromBuilder(self: *MessageBuilder, source: ListBuilder) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyListFromBuilder(source);
        return slot.disown();
    }

    pub fn newOrphanCopyListCanonicalFromBuilder(self: *MessageBuilder, source: ListBuilder) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyListFromCanonicalBuilder(source);
        return slot.disown();
    }

    pub fn newOrphanCopyPointer(self: *MessageBuilder, source: PointerReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyFrom(source);
        return slot.disown();
    }

    pub fn newOrphanCopyPointerCanonical(self: *MessageBuilder, source: PointerReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyFromCanonical(source);
        return slot.disown();
    }

    pub fn newOrphanCopyPointerFromBuilder(self: *MessageBuilder, source: PointerBuilder) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyFromBuilder(source);
        return slot.disown();
    }

    pub fn newOrphanCopyPointerCanonicalFromBuilder(self: *MessageBuilder, source: PointerBuilder) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyFromCanonicalBuilder(source);
        return slot.disown();
    }

    pub fn disownRoot(self: *MessageBuilder) Error!Orphan {
        return (try self.getRootPointer()).disown();
    }

    pub fn adoptRoot(self: *MessageBuilder, orphan: *Orphan) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.adopt(orphan);
        return dst_root;
    }

    pub fn copyRootFrom(self: *MessageBuilder, source: *MessageReader) Error!StructBuilder {
        const dst_root = try self.getRootPointer();
        const src_root = try source.getRootPointer();
        try dst_root.copyFrom(src_root);
        return self.getRoot();
    }

    pub fn copyRootFromBuilder(self: *MessageBuilder, source: StructBuilder) Error!StructBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyStructFromBuilder(source);
        return self.getRoot();
    }

    pub fn copyRootPointerFrom(self: *MessageBuilder, source: PointerReader) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyFrom(source);
        return dst_root;
    }

    pub fn copyRootPointerFromBuilder(self: *MessageBuilder, source: PointerBuilder) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyFromBuilder(source);
        return dst_root;
    }

    pub fn copyRootTo(self: *MessageBuilder, target: *MessageBuilder) Error!PointerBuilder {
        var reader = MessageReader.init(try self.segmentsConst(), .{});
        return target.copyRootPointerFrom(try reader.getRootPointer());
    }

    pub fn copyRootToBuilder(self: *MessageBuilder, target: *MessageBuilder) Error!PointerBuilder {
        return target.copyRootPointerFromBuilder(try self.getRootPointer());
    }

    pub fn copyRootCanonicalFrom(self: *MessageBuilder, source: *MessageReader) Error!StructBuilder {
        const dst_root = try self.getRootPointer();
        const src_root = try source.getRootPointer();
        try dst_root.copyFromCanonical(src_root);
        return self.getRoot();
    }

    pub fn copyRootCanonicalFromBuilder(self: *MessageBuilder, source: StructBuilder) Error!StructBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyStructFromCanonicalBuilder(source);
        return self.getRoot();
    }

    pub fn copyRootPointerCanonicalFrom(self: *MessageBuilder, source: PointerReader) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyFromCanonical(source);
        return dst_root;
    }

    pub fn copyRootPointerCanonicalFromBuilder(self: *MessageBuilder, source: PointerBuilder) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyFromCanonicalBuilder(source);
        return dst_root;
    }

    pub fn copyRootCanonicalTo(self: *MessageBuilder, target: *MessageBuilder) Error!PointerBuilder {
        var reader = MessageReader.init(try self.segmentsConst(), .{});
        return target.copyRootPointerCanonicalFrom(try reader.getRootPointer());
    }

    pub fn copyRootCanonicalToBuilder(self: *MessageBuilder, target: *MessageBuilder) Error!PointerBuilder {
        return target.copyRootPointerCanonicalFromBuilder(try self.getRootPointer());
    }

    pub fn getRoot(self: *MessageBuilder) Error!StructBuilder {
        var reader = MessageReader.init(try self.segmentsConst(), .{});
        const root = try reader.getRoot();
        return .{
            .message = self,
            .segment_id = root.segment_id,
            .data_start = root.data_start,
            .pointer_start = root.pointer_start,
            .data_words = root.data_words,
            .pointer_count = root.pointer_count,
        };
    }

    pub fn getRootPointer(self: *MessageBuilder) Error!PointerBuilder {
        if (self.segments.items.len == 0) return error.SegmentOutOfBounds;
        return .{ .message = self, .segment_id = 0, .word_index = 0 };
    }

    pub fn isRootNull(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isNull();
    }

    pub fn clearRoot(self: *MessageBuilder) Error!void {
        (try self.getRootPointer()).clear();
    }

    pub fn getRootPointerKind(self: *MessageBuilder) Error!?wire.PointerType {
        return (try self.getRootPointer()).pointerType();
    }

    pub fn matchesRootPointerType(self: *MessageBuilder, expected: wire.PointerType) Error!bool {
        return (try self.getRootPointer()).matchesPointerType(expected);
    }

    pub fn isRootStructPointer(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isStructPointer();
    }

    pub fn isRootListPointer(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isListPointer();
    }

    pub fn isRootFarPointer(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isFarPointer();
    }

    pub fn isRootOtherPointer(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isOtherPointer();
    }

    pub fn isRootCapabilityPointer(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isCapabilityPointer();
    }

    pub fn isRootNearPointer(self: *MessageBuilder) Error!bool {
        return (try self.getRootPointer()).isNearPointer();
    }

    pub fn getRootRawPointer(self: *MessageBuilder) Error!wire.Word {
        return (try self.getRootPointer()).raw();
    }

    pub fn getRootDecodedPointer(self: *MessageBuilder) Error!?wire.DecodedPointer {
        return (try self.getRootPointer()).decode();
    }

    pub fn getRootPointerStatsWithOptions(self: *MessageBuilder, options: ReaderOptions) Error!MessageStats {
        return (try self.getRootPointer()).validateWithOptions(options);
    }

    pub fn getRootPointerStats(self: *MessageBuilder) Error!MessageStats {
        return self.getRootPointerStatsWithOptions(.{});
    }

    pub fn getRootPointerTotalSizeWithOptions(self: *MessageBuilder, options: ReaderOptions) Error!MessageSize {
        return (try self.getRootPointerStatsWithOptions(options)).size();
    }

    pub fn getRootPointerTotalSize(self: *MessageBuilder) Error!MessageSize {
        return (try self.getRootPointerStats()).size();
    }

    pub fn getRootText(self: *MessageBuilder) Error![]const u8 {
        return (try self.getRootPointer()).getText();
    }

    pub fn getRootTextDefault(self: *MessageBuilder, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getTextDefault(default_value);
    }

    pub fn getRootTextDefaultByteCount(self: *MessageBuilder, default_value: []const u8) Error!usize {
        return (try self.getRootPointer()).getTextDefaultByteCount(default_value);
    }

    pub fn rootTextDefaultMatchesBytes(self: *MessageBuilder, default_value: []const u8, count: usize) Error!bool {
        return (try self.getRootPointer()).textDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootTextByteCount(self: *MessageBuilder) Error!usize {
        return (try self.getRootPointer()).getTextByteCount();
    }

    pub fn rootTextMatchesBytes(self: *MessageBuilder, count: usize) Error!bool {
        return (try self.getRootPointer()).textMatchesBytes(count);
    }

    pub fn getRootData(self: *MessageBuilder) Error![]const u8 {
        return (try self.getRootPointer()).getData();
    }

    pub fn getRootDataDefault(self: *MessageBuilder, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getDataDefault(default_value);
    }

    pub fn getRootDataDefaultByteCount(self: *MessageBuilder, default_value: []const u8) Error!usize {
        return (try self.getRootPointer()).getDataDefaultByteCount(default_value);
    }

    pub fn rootDataDefaultMatchesBytes(self: *MessageBuilder, default_value: []const u8, count: usize) Error!bool {
        return (try self.getRootPointer()).dataDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootDataByteCount(self: *MessageBuilder) Error!usize {
        return (try self.getRootPointer()).getDataByteCount();
    }

    pub fn rootDataMatchesBytes(self: *MessageBuilder, count: usize) Error!bool {
        return (try self.getRootPointer()).dataMatchesBytes(count);
    }

    pub fn getRootCapability(self: *MessageBuilder) Error!u32 {
        return (try self.getRootPointer()).getCapabilityIndex();
    }

    fn newOrphanPointer(self: *MessageBuilder) Error!PointerBuilder {
        const slot = try self.allocObject(0, 1);
        return .{ .message = self, .segment_id = slot.id, .word_index = slot.start };
    }

    pub fn asReader(self: *MessageBuilder, options: ReaderOptions) !MessageReader {
        return MessageReader.init(try self.segmentsConst(), options);
    }

    pub fn firstSegmentWords(self: *const MessageBuilder) usize {
        return self.options.firstSegmentWords();
    }

    pub fn firstSegmentBytes(self: *const MessageBuilder) usize {
        return self.options.firstSegmentBytes();
    }

    pub fn matchesFirstSegmentWords(self: *const MessageBuilder, count: usize) bool {
        return self.options.matchesFirstSegmentWords(count);
    }

    pub fn matchesFirstSegmentBytes(self: *const MessageBuilder, count: usize) bool {
        return self.options.matchesFirstSegmentBytes(count);
    }

    pub fn nextSegmentMinWords(self: *const MessageBuilder) usize {
        return self.options.nextSegmentMinWords();
    }

    pub fn nextSegmentMinBytes(self: *const MessageBuilder) usize {
        return self.options.nextSegmentMinBytes();
    }

    pub fn matchesNextSegmentMinWords(self: *const MessageBuilder, count: usize) bool {
        return self.options.matchesNextSegmentMinWords(count);
    }

    pub fn matchesNextSegmentMinBytes(self: *const MessageBuilder, count: usize) bool {
        return self.options.matchesNextSegmentMinBytes(count);
    }

    pub fn segmentCount(self: *MessageBuilder) usize {
        return self.segments.items.len;
    }

    pub fn segmentBytes(self: *MessageBuilder, index: usize) Error!serialize.ConstSegment {
        if (index >= self.segments.items.len) return error.SegmentOutOfBounds;
        return self.segments.items[index].allocatedBytes();
    }

    pub fn segmentByteLen(self: *MessageBuilder, index: usize) Error!usize {
        if (index >= self.segments.items.len) return error.SegmentOutOfBounds;
        return wordsToBytesChecked(self.segments.items[index].used);
    }

    pub fn segmentWordLen(self: *MessageBuilder, index: usize) Error!usize {
        if (index >= self.segments.items.len) return error.SegmentOutOfBounds;
        return self.segments.items[index].used;
    }

    pub fn segmentCapacityWords(self: *MessageBuilder, index: usize) Error!usize {
        if (index >= self.segments.items.len) return error.SegmentOutOfBounds;
        return self.segments.items[index].words.items.len;
    }

    pub fn segmentRemainingWords(self: *MessageBuilder, index: usize) Error!usize {
        if (index >= self.segments.items.len) return error.SegmentOutOfBounds;
        const segment = self.segments.items[index];
        return segment.words.items.len - segment.used;
    }

    pub fn segmentCapacityBytes(self: *MessageBuilder, index: usize) Error!usize {
        return wordsToBytesChecked(try self.segmentCapacityWords(index));
    }

    pub fn segmentRemainingBytes(self: *MessageBuilder, index: usize) Error!usize {
        return wordsToBytesChecked(try self.segmentRemainingWords(index));
    }

    pub fn serializedSize(self: *MessageBuilder) (Error || serialize.Error)!usize {
        return serialize.computeSerializedSize(try self.segmentsConst());
    }

    pub fn serializedSizeInWords(self: *MessageBuilder) (Error || serialize.Error)!usize {
        return serialize.computeSerializedSizeInWords(try self.segmentsConst());
    }

    pub fn serializeSegmentTable(self: *MessageBuilder) (Error || serialize.Error)![]u8 {
        return serialize.serializeSegmentTable(self.allocator, try self.segmentsConst());
    }

    pub fn toFlatBytes(self: *MessageBuilder) (Error || serialize.Error)![]u8 {
        return serialize.messageToFlatBytes(self.allocator, try self.segmentsConst());
    }

    pub fn toFlatBytesInto(self: *MessageBuilder, dest: []u8) (Error || serialize.Error)!usize {
        return serialize.messageToFlatBytesInto(dest, try self.segmentsConst());
    }

    pub fn toPackedBytes(self: *MessageBuilder) (Error || serialize.Error)![]u8 {
        return serialize.messageToPackedBytes(self.allocator, try self.segmentsConst());
    }

    pub fn packedSize(self: *MessageBuilder) (Error || serialize.Error)!usize {
        return serialize.packedMessageSize(self.allocator, try self.segmentsConst());
    }

    pub fn packedSizeWithTableBuffer(self: *MessageBuilder, table_buffer: []u8) (Error || serialize.Error)!usize {
        return serialize.packedMessageSizeWithTableBuffer(table_buffer, try self.segmentsConst());
    }

    pub fn maxPackedSize(self: *MessageBuilder) (Error || serialize.Error)!usize {
        return serialize.maxPackedMessageSize(try self.segmentsConst());
    }

    pub fn toPackedBytesInto(self: *MessageBuilder, table_buffer: []u8, dest: []u8) (Error || serialize.Error)!usize {
        return serialize.messageToPackedBytesInto(table_buffer, dest, try self.segmentsConst());
    }

    pub fn writeToWriter(self: *MessageBuilder, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return serialize.writeMessageToWriter(writer, try self.segmentsConst());
    }

    pub fn writePackedToWriter(self: *MessageBuilder, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return serialize.writePackedMessageToWriter(self.allocator, writer, try self.segmentsConst());
    }

    pub fn writePackedToWriterWithTableBuffer(self: *MessageBuilder, table_buffer: []u8, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return serialize.writePackedMessageToWriterWithTableBuffer(table_buffer, writer, try self.segmentsConst());
    }

    pub fn toCanonicalSegmentBytes(self: *MessageBuilder, options: ReaderOptions) Error![]u8 {
        var reader = MessageReader.init(try self.segmentsConst(), options);
        return messageToCanonicalSegmentBytes(self.allocator, &reader);
    }

    pub fn validate(self: *MessageBuilder, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(try self.segmentsConst(), options);
        return reader.validate();
    }

    pub fn toSingleSegmentFlatBytes(self: *MessageBuilder, options: ReaderOptions) (Error || serialize.Error)![]u8 {
        var reader = MessageReader.init(try self.segmentsConst(), options);
        return messageToSingleSegmentFlatBytes(self.allocator, &reader);
    }

    pub fn totalSize(self: *MessageBuilder) Error!MessageSize {
        return self.totalSizeWithOptions(.{});
    }

    pub fn totalSizeWithOptions(self: *MessageBuilder, options: ReaderOptions) Error!MessageSize {
        const stats = try self.validate(options);
        return stats.size();
    }

    pub fn segmentsConst(self: *MessageBuilder) ![]const serialize.ConstSegment {
        self.const_segments_cache.items.len = 0;
        try self.const_segments_cache.ensureTotalCapacity(self.allocator, self.segments.items.len);
        for (self.segments.items) |*segment| {
            self.const_segments_cache.appendAssumeCapacity(segment.allocatedBytes());
        }
        return self.const_segments_cache.items;
    }

    pub fn writePtr(self: *MessageBuilder, segment_id: u32, word_index: usize, value: wire.Word) Error!void {
        if (segment_id >= self.segments.items.len) return error.SegmentOutOfBounds;
        const words = self.segments.items[segment_id].words.items;
        if (word_index >= words.len) return error.SegmentOutOfBounds;
        self.segments.items[segment_id].words.items[word_index] = value;
    }

    pub fn readWord(self: *MessageBuilder, segment_id: u32, word_index: usize) Error!wire.Word {
        if (segment_id >= self.segments.items.len) return error.SegmentOutOfBounds;
        const segment = &self.segments.items[segment_id];
        if (word_index >= segment.words.items.len) return error.SegmentOutOfBounds;
        if (word_index >= segment.used) return 0;
        return segment.words.items[word_index];
    }

    pub fn allocObject(self: *MessageBuilder, preferred_segment_id: u32, word_count: usize) Error!SegmentCursor {
        if (word_count == 0) return .{ .id = preferred_segment_id, .start = 0 };
        if (preferred_segment_id < self.segments.items.len) {
            if (self.segments.items[preferred_segment_id].alloc(word_count)) |start| {
                return .{ .id = preferred_segment_id, .start = start };
            }
        }
        // The preferred segment is full. Reuse free space in any other existing
        // segment before growing the segment list; without this, building many
        // small children of a full parent allocates a segment per child.
        const segment_count = self.segments.items.len;
        var attempt: usize = 0;
        while (attempt < segment_count) : (attempt += 1) {
            const id = (self.allocation_hint +% attempt) % segment_count;
            if (self.segments.items[id].alloc(word_count)) |start| {
                self.allocation_hint = id;
                return .{ .id = @intCast(id), .start = start };
            }
        }
        const min_words = @max(self.options.next_segment_min_words, word_count);
        var segment = try SegmentBuilder.init(self.allocator, min_words);
        errdefer segment.deinit(self.allocator);
        const start = segment.alloc(word_count).?;
        const segment_id = try segmentIdFromIndex(self.segments.items.len);
        try self.segments.append(self.allocator, segment);
        self.allocation_hint = self.segments.items.len - 1;
        return .{ .id = segment_id, .start = start };
    }

    pub fn placePointerToObject(self: *MessageBuilder, pointer: PointerBuilder, object: SegmentCursor, object_word_count: usize, tag_for_far: wire.Word, near_raw: wire.Word) Error!void {
        if (object.id == pointer.segment_id) {
            _ = object_word_count;
            try self.writePtr(pointer.segment_id, pointer.word_index, near_raw);
            return;
        }

        const landing = try self.allocObject(object.id, 1);
        if (landing.id == object.id) {
            const landing_offset = try wire.offsetFromPointer(landing.start, object.start);
            const landing_raw = switch (wire.pointerType(tag_for_far)) {
                .struct_ptr => blk: {
                    const s = wire.decodeStruct(tag_for_far);
                    break :blk try wire.encodeStruct(landing_offset, s.data_words, s.pointer_count);
                },
                .list => blk: {
                    const l = try wire.decodeList(tag_for_far);
                    break :blk try wire.encodeList(landing_offset, l.element_size, l.element_count_or_words);
                },
                else => return error.InvalidPointerKind,
            };
            try self.writePtr(landing.id, landing.start, landing_raw);
            try self.writePtr(pointer.segment_id, pointer.word_index, try wire.encodeFar(false, landing.start, landing.id));
            return;
        }

        const double = try self.allocObject(pointer.segment_id, 2);
        const far_to_content = try wire.encodeFar(false, object.start, object.id);
        try self.writePtr(double.id, double.start, far_to_content);
        try self.writePtr(double.id, double.start + 1, try tag_forFarWithZeroOffset(tag_for_far));
        try self.writePtr(pointer.segment_id, pointer.word_index, try wire.encodeFar(true, double.start, double.id));
        _ = object_word_count;
    }
};
