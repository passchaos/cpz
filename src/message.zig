const std = @import("std");
const wire = @import("wire.zig");
const serialize = @import("serialize.zig");

pub const Error = wire.Error || std.mem.Allocator.Error || error{
    ReadOnly,
    NestingLimitExceeded,
    TraversalLimitExceeded,
    SerializedSizeOverflow,
    InvalidDefaultValue,
    TextNotNulTerminated,
    TextContainsInteriorNul,
    Utf8Invalid,
    IncompatibleListShape,
};

pub const ReaderOptions = struct {
    traversal_limit_words: usize = 8 * 1024 * 1024, // 64 MiB like C++ default.
    nesting_limit: u16 = 64,
    capability_count_limit: ?usize = null,
};

pub const MessageStats = struct {
    /// Pointer slots inspected, including null slots and the root pointer.
    pointer_slots: usize = 0,
    non_null_pointers: usize = 0,
    structs: usize = 0,
    lists: usize = 0,
    capabilities: usize = 0,
    max_capability_index: ?u32 = null,
    data_words: usize = 0,
    pointer_words: usize = 0,
    total_words: usize = 0,

    pub fn size(self: MessageStats) MessageSize {
        return .{ .word_count = self.total_words, .cap_count = self.capabilities };
    }

    pub fn isEmpty(self: MessageStats) bool {
        return self.pointer_slots == 0 and self.total_words == 0 and self.capabilities == 0;
    }

    pub fn hasCapabilities(self: MessageStats) bool {
        return self.capabilities != 0;
    }

    pub fn hasPointerSlots(self: MessageStats) bool {
        return self.pointer_slots != 0;
    }

    pub fn hasNonNullPointers(self: MessageStats) bool {
        return self.non_null_pointers != 0;
    }

    pub fn hasStructs(self: MessageStats) bool {
        return self.structs != 0;
    }

    pub fn hasLists(self: MessageStats) bool {
        return self.lists != 0;
    }

    pub fn hasDataWords(self: MessageStats) bool {
        return self.data_words != 0;
    }

    pub fn hasPointerWords(self: MessageStats) bool {
        return self.pointer_words != 0;
    }

    pub fn hasWords(self: MessageStats) bool {
        return self.total_words != 0;
    }

    pub fn pointerSlotCount(self: MessageStats) usize {
        return self.pointer_slots;
    }

    pub fn nonNullPointerCount(self: MessageStats) usize {
        return self.non_null_pointers;
    }

    pub fn structCount(self: MessageStats) usize {
        return self.structs;
    }

    pub fn listCount(self: MessageStats) usize {
        return self.lists;
    }

    pub fn dataWordCount(self: MessageStats) usize {
        return self.data_words;
    }

    pub fn pointerWordCount(self: MessageStats) usize {
        return self.pointer_words;
    }

    pub fn wordCount(self: MessageStats) usize {
        return self.total_words;
    }

    pub fn capabilityCount(self: MessageStats) usize {
        return self.capabilities;
    }

    pub fn matchesPointerSlots(self: MessageStats, count: usize) bool {
        return self.pointer_slots == count;
    }

    pub fn matchesNonNullPointers(self: MessageStats, count: usize) bool {
        return self.non_null_pointers == count;
    }

    pub fn matchesStructs(self: MessageStats, count: usize) bool {
        return self.structs == count;
    }

    pub fn matchesLists(self: MessageStats, count: usize) bool {
        return self.lists == count;
    }

    pub fn matchesDataWords(self: MessageStats, count: usize) bool {
        return self.data_words == count;
    }

    pub fn matchesPointerWords(self: MessageStats, count: usize) bool {
        return self.pointer_words == count;
    }

    pub fn matchesWords(self: MessageStats, count: usize) bool {
        return self.total_words == count;
    }

    pub fn matchesCapabilities(self: MessageStats, count: usize) bool {
        return self.capabilities == count;
    }

    pub fn maxCapabilityIndex(self: MessageStats) ?u32 {
        return self.max_capability_index;
    }

    pub fn maxCapabilityCount(self: MessageStats) usize {
        if (self.max_capability_index) |index| {
            return @as(usize, index) + 1;
        }
        return 0;
    }
};

pub const MessageSize = struct {
    word_count: usize = 0,
    cap_count: usize = 0,

    pub fn wordCount(self: MessageSize) usize {
        return self.word_count;
    }

    pub fn capabilityCount(self: MessageSize) usize {
        return self.cap_count;
    }

    pub fn matchesWords(self: MessageSize, count: usize) bool {
        return self.word_count == count;
    }

    pub fn matchesCapabilities(self: MessageSize, count: usize) bool {
        return self.cap_count == count;
    }

    pub fn isEmpty(self: MessageSize) bool {
        return self.word_count == 0 and self.cap_count == 0;
    }

    pub fn hasCapabilities(self: MessageSize) bool {
        return self.cap_count != 0;
    }

    pub fn hasWords(self: MessageSize) bool {
        return self.word_count != 0;
    }
};

pub const OwnedMessageReader = struct {
    flat: serialize.FlatMessage,
    reader: MessageReader,

    pub fn initFlat(allocator: std.mem.Allocator, flat_bytes: []const u8, options: ReaderOptions) (Error || serialize.Error)!OwnedMessageReader {
        var flat = try serialize.readFlatMessage(allocator, flat_bytes);
        errdefer flat.deinit(allocator);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initPacked(allocator: std.mem.Allocator, packed_bytes: []const u8, options: ReaderOptions) (Error || serialize.Error)!OwnedMessageReader {
        var flat = try serialize.readPackedMessage(allocator, packed_bytes);
        errdefer flat.deinit(allocator);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initFromReader(allocator: std.mem.Allocator, source: *std.Io.Reader, options: ReaderOptions) (Error || serialize.Error || std.Io.Reader.Error)!OwnedMessageReader {
        var flat = try serialize.readMessageFromReader(allocator, source);
        errdefer flat.deinit(allocator);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initPackedFromReader(allocator: std.mem.Allocator, source: *std.Io.Reader, options: ReaderOptions) (Error || serialize.Error || std.Io.Reader.Error)!OwnedMessageReader {
        var flat = try serialize.readPackedMessageFromReader(allocator, source);
        errdefer flat.deinit(allocator);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn deinit(self: *OwnedMessageReader, allocator: std.mem.Allocator) void {
        self.flat.deinit(allocator);
        self.reader = undefined;
    }

    pub fn asReader(self: *OwnedMessageReader) *MessageReader {
        return &self.reader;
    }

    pub fn getRoot(self: *OwnedMessageReader) Error!StructReader {
        return self.reader.getRoot();
    }

    pub fn getRootPointer(self: *OwnedMessageReader) Error!PointerReader {
        return self.reader.getRootPointer();
    }

    pub fn getRootList(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!ListReader {
        return self.reader.getRootList(expected);
    }

    pub fn getRootText(self: *OwnedMessageReader) Error![]const u8 {
        return self.reader.getRootText();
    }

    pub fn getRootData(self: *OwnedMessageReader) Error![]const u8 {
        return self.reader.getRootData();
    }

    pub fn getRootTextDefault(self: *OwnedMessageReader, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootTextDefault(default_value);
    }

    pub fn getRootDataDefault(self: *OwnedMessageReader, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootDataDefault(default_value);
    }

    pub fn getRootCapability(self: *OwnedMessageReader) Error!u32 {
        return self.reader.getRootCapability();
    }

    pub fn validate(self: *OwnedMessageReader) Error!MessageStats {
        return self.reader.validate();
    }

    pub fn validateWithOptions(self: *const OwnedMessageReader, options: ReaderOptions) Error!MessageStats {
        return self.reader.validateWithOptions(options);
    }

    pub fn totalSize(self: *OwnedMessageReader) Error!MessageSize {
        return self.reader.totalSize();
    }

    pub fn totalSizeWithOptions(self: *const OwnedMessageReader, options: ReaderOptions) Error!MessageSize {
        return self.reader.totalSizeWithOptions(options);
    }

    pub fn isRootNull(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootNull();
    }

    pub fn getRootPointerKind(self: *OwnedMessageReader) Error!?wire.PointerType {
        return self.reader.getRootPointerKind();
    }

    pub fn getRootRawPointer(self: *OwnedMessageReader) Error!wire.Word {
        return self.reader.getRootRawPointer();
    }

    pub fn getRootDecodedPointer(self: *OwnedMessageReader) Error!?wire.DecodedPointer {
        return self.reader.getRootDecodedPointer();
    }

    pub fn segmentCount(self: *const OwnedMessageReader) usize {
        return self.reader.segmentCount();
    }

    pub fn segmentBytes(self: *const OwnedMessageReader, index: usize) Error!serialize.ConstSegment {
        return self.reader.segmentBytes(index);
    }

    pub fn segmentByteLen(self: *const OwnedMessageReader, index: usize) Error!usize {
        return self.reader.segmentByteLen(index);
    }

    pub fn segmentWordLen(self: *const OwnedMessageReader, index: usize) (Error || serialize.Error)!usize {
        return self.reader.segmentWordLen(index);
    }

    pub fn serializedSize(self: *const OwnedMessageReader) (Error || serialize.Error)!usize {
        return self.reader.serializedSize();
    }

    pub fn serializedSizeInWords(self: *const OwnedMessageReader) (Error || serialize.Error)!usize {
        return self.reader.serializedSizeInWords();
    }

    pub fn traversalLimitWords(self: *const OwnedMessageReader) usize {
        return self.reader.traversalLimitWords();
    }

    pub fn traversalRemainingWords(self: *const OwnedMessageReader) usize {
        return self.reader.traversalRemainingWords();
    }

    pub fn nestingLimit(self: *const OwnedMessageReader) u16 {
        return self.reader.nestingLimit();
    }

    pub fn capabilityCountLimit(self: *const OwnedMessageReader) ?usize {
        return self.reader.capabilityCountLimit();
    }

    pub fn serializeSegmentTable(self: *const OwnedMessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.serializeSegmentTable(allocator);
    }

    pub fn toFlatBytes(self: *const OwnedMessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.toFlatBytes(allocator);
    }

    pub fn toFlatBytesInto(self: *const OwnedMessageReader, dest: []u8) (Error || serialize.Error)!usize {
        return self.reader.toFlatBytesInto(dest);
    }

    pub fn toPackedBytes(self: *const OwnedMessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.toPackedBytes(allocator);
    }

    pub fn maxPackedSize(self: *const OwnedMessageReader) (Error || serialize.Error)!usize {
        return self.reader.maxPackedSize();
    }

    pub fn toPackedBytesInto(self: *const OwnedMessageReader, table_buffer: []u8, dest: []u8) (Error || serialize.Error)!usize {
        return self.reader.toPackedBytesInto(table_buffer, dest);
    }

    pub fn writeToWriter(self: *const OwnedMessageReader, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return self.reader.writeToWriter(writer);
    }

    pub fn writePackedToWriter(self: *const OwnedMessageReader, allocator: std.mem.Allocator, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return self.reader.writePackedToWriter(allocator, writer);
    }

    pub fn writePackedToWriterWithTableBuffer(self: *const OwnedMessageReader, table_buffer: []u8, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return self.reader.writePackedToWriterWithTableBuffer(table_buffer, writer);
    }

    pub fn toCanonicalSegmentBytes(self: *const OwnedMessageReader, allocator: std.mem.Allocator) Error![]u8 {
        return self.reader.toCanonicalSegmentBytes(allocator);
    }

    pub fn toSingleSegmentFlatBytes(self: *const OwnedMessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.toSingleSegmentFlatBytes(allocator);
    }

    pub fn consumedLen(self: *const OwnedMessageReader) usize {
        return self.flat.consumed_len;
    }

    pub fn sourceConsumedLen(self: *const OwnedMessageReader) usize {
        return self.flat.sourceConsumedLen();
    }

    pub fn bytes(self: *const OwnedMessageReader) []const u8 {
        return self.flat.consumedBytes();
    }
};

pub const MessageReaderView = struct {
    flat: serialize.FlatMessageView,
    reader: MessageReader,

    pub fn initFlat(allocator: std.mem.Allocator, flat_bytes: []const u8, options: ReaderOptions) (Error || serialize.Error)!MessageReaderView {
        var flat = try serialize.readFlatMessageView(allocator, flat_bytes);
        errdefer flat.deinit(allocator);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initFlatInto(segment_table: []serialize.ConstSegment, flat_bytes: []const u8, options: ReaderOptions) (Error || serialize.Error)!MessageReaderView {
        const flat = try serialize.readFlatMessageViewInto(segment_table, flat_bytes);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initFromReaderInto(segment_table: []serialize.ConstSegment, flat_buffer: []u8, source: *std.Io.Reader, options: ReaderOptions) (Error || serialize.Error || std.Io.Reader.Error)!MessageReaderView {
        const flat = try serialize.readMessageViewFromReaderInto(segment_table, flat_buffer, source);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initPackedInto(segment_table: []serialize.ConstSegment, flat_buffer: []u8, packed_bytes: []const u8, options: ReaderOptions) (Error || serialize.Error)!MessageReaderView {
        const flat = try serialize.readPackedMessageViewInto(segment_table, flat_buffer, packed_bytes);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn initPackedFromReaderInto(segment_table: []serialize.ConstSegment, flat_buffer: []u8, source: *std.Io.Reader, options: ReaderOptions) (Error || serialize.Error || std.Io.Reader.Error)!MessageReaderView {
        const flat = try serialize.readPackedMessageViewFromReaderInto(segment_table, flat_buffer, source);
        return .{
            .reader = MessageReader.init(flat.segments, options),
            .flat = flat,
        };
    }

    pub fn deinit(self: *MessageReaderView, allocator: std.mem.Allocator) void {
        self.flat.deinit(allocator);
        self.reader = undefined;
    }

    pub fn asReader(self: *MessageReaderView) *MessageReader {
        return &self.reader;
    }

    pub fn getRoot(self: *MessageReaderView) Error!StructReader {
        return self.reader.getRoot();
    }

    pub fn getRootPointer(self: *MessageReaderView) Error!PointerReader {
        return self.reader.getRootPointer();
    }

    pub fn getRootList(self: *MessageReaderView, expected: ?wire.ElementSize) Error!ListReader {
        return self.reader.getRootList(expected);
    }

    pub fn getRootText(self: *MessageReaderView) Error![]const u8 {
        return self.reader.getRootText();
    }

    pub fn getRootData(self: *MessageReaderView) Error![]const u8 {
        return self.reader.getRootData();
    }

    pub fn getRootTextDefault(self: *MessageReaderView, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootTextDefault(default_value);
    }

    pub fn getRootDataDefault(self: *MessageReaderView, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootDataDefault(default_value);
    }

    pub fn getRootCapability(self: *MessageReaderView) Error!u32 {
        return self.reader.getRootCapability();
    }

    pub fn validate(self: *MessageReaderView) Error!MessageStats {
        return self.reader.validate();
    }

    pub fn validateWithOptions(self: *const MessageReaderView, options: ReaderOptions) Error!MessageStats {
        return self.reader.validateWithOptions(options);
    }

    pub fn totalSize(self: *MessageReaderView) Error!MessageSize {
        return self.reader.totalSize();
    }

    pub fn totalSizeWithOptions(self: *const MessageReaderView, options: ReaderOptions) Error!MessageSize {
        return self.reader.totalSizeWithOptions(options);
    }

    pub fn isRootNull(self: *MessageReaderView) Error!bool {
        return self.reader.isRootNull();
    }

    pub fn getRootPointerKind(self: *MessageReaderView) Error!?wire.PointerType {
        return self.reader.getRootPointerKind();
    }

    pub fn getRootRawPointer(self: *MessageReaderView) Error!wire.Word {
        return self.reader.getRootRawPointer();
    }

    pub fn getRootDecodedPointer(self: *MessageReaderView) Error!?wire.DecodedPointer {
        return self.reader.getRootDecodedPointer();
    }

    pub fn segmentCount(self: *const MessageReaderView) usize {
        return self.reader.segmentCount();
    }

    pub fn segmentBytes(self: *const MessageReaderView, index: usize) Error!serialize.ConstSegment {
        return self.reader.segmentBytes(index);
    }

    pub fn segmentByteLen(self: *const MessageReaderView, index: usize) Error!usize {
        return self.reader.segmentByteLen(index);
    }

    pub fn segmentWordLen(self: *const MessageReaderView, index: usize) (Error || serialize.Error)!usize {
        return self.reader.segmentWordLen(index);
    }

    pub fn serializedSize(self: *const MessageReaderView) (Error || serialize.Error)!usize {
        return self.reader.serializedSize();
    }

    pub fn serializedSizeInWords(self: *const MessageReaderView) (Error || serialize.Error)!usize {
        return self.reader.serializedSizeInWords();
    }

    pub fn traversalLimitWords(self: *const MessageReaderView) usize {
        return self.reader.traversalLimitWords();
    }

    pub fn traversalRemainingWords(self: *const MessageReaderView) usize {
        return self.reader.traversalRemainingWords();
    }

    pub fn nestingLimit(self: *const MessageReaderView) u16 {
        return self.reader.nestingLimit();
    }

    pub fn capabilityCountLimit(self: *const MessageReaderView) ?usize {
        return self.reader.capabilityCountLimit();
    }

    pub fn serializeSegmentTable(self: *const MessageReaderView, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.serializeSegmentTable(allocator);
    }

    pub fn toFlatBytes(self: *const MessageReaderView, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.toFlatBytes(allocator);
    }

    pub fn toFlatBytesInto(self: *const MessageReaderView, dest: []u8) (Error || serialize.Error)!usize {
        return self.reader.toFlatBytesInto(dest);
    }

    pub fn toPackedBytes(self: *const MessageReaderView, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.toPackedBytes(allocator);
    }

    pub fn maxPackedSize(self: *const MessageReaderView) (Error || serialize.Error)!usize {
        return self.reader.maxPackedSize();
    }

    pub fn toPackedBytesInto(self: *const MessageReaderView, table_buffer: []u8, dest: []u8) (Error || serialize.Error)!usize {
        return self.reader.toPackedBytesInto(table_buffer, dest);
    }

    pub fn writeToWriter(self: *const MessageReaderView, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return self.reader.writeToWriter(writer);
    }

    pub fn writePackedToWriter(self: *const MessageReaderView, allocator: std.mem.Allocator, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return self.reader.writePackedToWriter(allocator, writer);
    }

    pub fn writePackedToWriterWithTableBuffer(self: *const MessageReaderView, table_buffer: []u8, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return self.reader.writePackedToWriterWithTableBuffer(table_buffer, writer);
    }

    pub fn toCanonicalSegmentBytes(self: *const MessageReaderView, allocator: std.mem.Allocator) Error![]u8 {
        return self.reader.toCanonicalSegmentBytes(allocator);
    }

    pub fn toSingleSegmentFlatBytes(self: *const MessageReaderView, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return self.reader.toSingleSegmentFlatBytes(allocator);
    }

    pub fn consumedLen(self: *const MessageReaderView) usize {
        return self.flat.consumed_len;
    }

    pub fn sourceConsumedLen(self: *const MessageReaderView) usize {
        return self.flat.sourceConsumedLen();
    }

    pub fn bytes(self: *const MessageReaderView) []const u8 {
        return self.flat.consumedBytes();
    }
};

pub const BuilderOptions = struct {
    first_segment_words: usize = 1024,
    next_segment_min_words: usize = 1024,
};

const SegmentBuilder = struct {
    words: std.ArrayList(wire.Word),
    used: usize,

    fn init(allocator: std.mem.Allocator, capacity_words: usize) !SegmentBuilder {
        var words = try std.ArrayList(wire.Word).initCapacity(allocator, capacity_words);
        try words.resize(allocator, capacity_words);
        @memset(words.items, 0);
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
        @memset(self.words.items[start..self.used], 0);
        return start;
    }

    fn allocatedBytes(self: *const SegmentBuilder) []const u8 {
        return std.mem.sliceAsBytes(self.words.items[0..self.used]);
    }
};

const SegmentCursor = struct {
    id: u32,
    start: usize,
};

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
        };
    }

    pub fn getText(self: Orphan) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getText();
    }

    pub fn getData(self: Orphan) Error![]const u8 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getData();
    }

    pub fn getCapabilityIndex(self: Orphan) Error!u32 {
        var reader = MessageReader.init(try self.message.segmentsConst(), .{});
        return self.asReader(&reader).getCapabilityIndex();
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

    pub fn newCopyList(self: Orphanage, source: ListReader) Error!Orphan {
        return self.message.newOrphanCopyList(source);
    }

    pub fn newCopyPointer(self: Orphanage, source: PointerReader) Error!Orphan {
        return self.message.newOrphanCopyPointer(source);
    }
};

pub const MessageBuilder = struct {
    allocator: std.mem.Allocator,
    segments: std.ArrayList(SegmentBuilder),
    const_segments_cache: std.ArrayList(serialize.ConstSegment),
    options: BuilderOptions,

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

    pub fn newOrphanCopyList(self: *MessageBuilder, source: ListReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyListFrom(source);
        return slot.disown();
    }

    pub fn newOrphanCopyPointer(self: *MessageBuilder, source: PointerReader) Error!Orphan {
        const slot = try self.newOrphanPointer();
        try slot.copyFrom(source);
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

    pub fn copyRootPointerFrom(self: *MessageBuilder, source: PointerReader) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyFrom(source);
        return dst_root;
    }

    pub fn copyRootTo(self: *MessageBuilder, target: *MessageBuilder) Error!PointerBuilder {
        var reader = MessageReader.init(try self.segmentsConst(), .{});
        return target.copyRootPointerFrom(try reader.getRootPointer());
    }

    pub fn copyRootCanonicalFrom(self: *MessageBuilder, source: *MessageReader) Error!StructBuilder {
        const dst_root = try self.getRootPointer();
        const src_root = try source.getRootPointer();
        try dst_root.copyFromCanonical(src_root);
        return self.getRoot();
    }

    pub fn copyRootPointerCanonicalFrom(self: *MessageBuilder, source: PointerReader) Error!PointerBuilder {
        const dst_root = try self.getRootPointer();
        try dst_root.copyFromCanonical(source);
        return dst_root;
    }

    pub fn copyRootCanonicalTo(self: *MessageBuilder, target: *MessageBuilder) Error!PointerBuilder {
        var reader = MessageReader.init(try self.segmentsConst(), .{});
        return target.copyRootPointerCanonicalFrom(try reader.getRootPointer());
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

    pub fn getRootData(self: *MessageBuilder) Error![]const u8 {
        return (try self.getRootPointer()).getData();
    }

    pub fn getRootDataDefault(self: *MessageBuilder, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getDataDefault(default_value);
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
        return self.options.first_segment_words;
    }

    pub fn nextSegmentMinWords(self: *const MessageBuilder) usize {
        return self.options.next_segment_min_words;
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
        return self.segments.items[index].used * wire.bytes_per_word;
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
        return (try self.segmentCapacityWords(index)) * wire.bytes_per_word;
    }

    pub fn segmentRemainingBytes(self: *MessageBuilder, index: usize) Error!usize {
        return (try self.segmentRemainingWords(index)) * wire.bytes_per_word;
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

    fn writePtr(self: *MessageBuilder, segment_id: u32, word_index: usize, value: wire.Word) void {
        self.segments.items[segment_id].words.items[word_index] = value;
    }

    fn readWord(self: *MessageBuilder, segment_id: u32, word_index: usize) wire.Word {
        return self.segments.items[segment_id].words.items[word_index];
    }

    fn allocObject(self: *MessageBuilder, preferred_segment_id: u32, word_count: usize) Error!SegmentCursor {
        if (word_count == 0) return .{ .id = preferred_segment_id, .start = 0 };
        if (preferred_segment_id < self.segments.items.len) {
            if (self.segments.items[preferred_segment_id].alloc(word_count)) |start| {
                return .{ .id = preferred_segment_id, .start = start };
            }
        }
        const min_words = @max(self.options.next_segment_min_words, word_count);
        var segment = try SegmentBuilder.init(self.allocator, min_words);
        errdefer segment.deinit(self.allocator);
        const start = segment.alloc(word_count).?;
        try self.segments.append(self.allocator, segment);
        return .{ .id = @intCast(self.segments.items.len - 1), .start = start };
    }

    fn placePointerToObject(self: *MessageBuilder, pointer: PointerBuilder, object: SegmentCursor, object_word_count: usize, tag_for_far: wire.Word, near_raw: wire.Word) Error!void {
        if (object.id == pointer.segment_id) {
            _ = object_word_count;
            self.writePtr(pointer.segment_id, pointer.word_index, near_raw);
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
            self.writePtr(landing.id, landing.start, landing_raw);
            self.writePtr(pointer.segment_id, pointer.word_index, try wire.encodeFar(false, landing.start, landing.id));
            return;
        }

        const double = try self.allocObject(pointer.segment_id, 2);
        const far_to_content = try wire.encodeFar(false, object.start, object.id);
        self.writePtr(double.id, double.start, far_to_content);
        self.writePtr(double.id, double.start + 1, tag_forFarWithZeroOffset(tag_for_far));
        self.writePtr(pointer.segment_id, pointer.word_index, try wire.encodeFar(true, double.start, double.id));
        _ = object_word_count;
    }
};

pub const MessageReader = struct {
    segments: []const serialize.ConstSegment,
    options: ReaderOptions,
    traversal_remaining: usize,

    pub fn init(segments: []const serialize.ConstSegment, options: ReaderOptions) MessageReader {
        return .{
            .segments = segments,
            .options = options,
            .traversal_remaining = options.traversal_limit_words,
        };
    }

    pub fn getRoot(self: *MessageReader) Error!StructReader {
        return (try self.getRootPointer()).getStruct(null);
    }

    pub fn getRootPointer(self: *MessageReader) Error!PointerReader {
        if (self.segments.len == 0) return error.SegmentOutOfBounds;
        return .{ .message = self, .segment_id = 0, .word_index = 0, .nesting_left = self.options.nesting_limit };
    }

    pub fn isRootNull(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isNull();
    }

    pub fn getRootPointerKind(self: *MessageReader) Error!?wire.PointerType {
        return (try self.getRootPointer()).pointerType();
    }

    pub fn getRootRawPointer(self: *MessageReader) Error!wire.Word {
        return (try self.getRootPointer()).raw();
    }

    pub fn getRootDecodedPointer(self: *MessageReader) Error!?wire.DecodedPointer {
        return (try self.getRootPointer()).decode();
    }

    pub fn getRootPointerStatsWithOptions(self: *MessageReader, options: ReaderOptions) Error!MessageStats {
        return (try self.getRootPointer()).validateWithOptions(options);
    }

    pub fn getRootPointerStats(self: *MessageReader) Error!MessageStats {
        return (try self.getRootPointer()).validate();
    }

    pub fn getRootPointerTotalSizeWithOptions(self: *MessageReader, options: ReaderOptions) Error!MessageSize {
        return (try self.getRootPointerStatsWithOptions(options)).size();
    }

    pub fn getRootPointerTotalSize(self: *MessageReader) Error!MessageSize {
        return (try self.getRootPointerStats()).size();
    }

    pub fn getRootList(self: *MessageReader, expected: ?wire.ElementSize) Error!ListReader {
        return (try self.getRootPointer()).getList(expected);
    }

    pub fn getRootText(self: *MessageReader) Error![]const u8 {
        return (try self.getRootPointer()).getText();
    }

    pub fn getRootTextDefault(self: *MessageReader, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getTextDefault(default_value);
    }

    pub fn getRootData(self: *MessageReader) Error![]const u8 {
        return (try self.getRootPointer()).getData();
    }

    pub fn getRootDataDefault(self: *MessageReader, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getDataDefault(default_value);
    }

    pub fn getRootCapability(self: *MessageReader) Error!u32 {
        return (try self.getRootPointer()).getCapabilityIndex();
    }

    /// Lazily traverses every reachable pointer without schema knowledge.
    /// This validates pointer bounds, far-pointer landing pads, traversal
    /// limits, and nesting limits while returning coarse wire-layout stats.
    /// The traversal consumes this reader's traversal budget just like normal
    /// accessor calls.
    pub fn validate(self: *MessageReader) Error!MessageStats {
        var stats: MessageStats = .{};
        const root = PointerReader{ .message = self, .segment_id = 0, .word_index = 0, .nesting_left = self.options.nesting_limit };
        try validatePointer(root, &stats);
        return stats;
    }

    pub fn validateWithOptions(self: *const MessageReader, options: ReaderOptions) Error!MessageStats {
        var reader = MessageReader.init(self.segments, options);
        return reader.validate();
    }

    pub fn totalSize(self: *MessageReader) Error!MessageSize {
        const stats = try self.validate();
        return stats.size();
    }

    pub fn totalSizeWithOptions(self: *const MessageReader, options: ReaderOptions) Error!MessageSize {
        return (try self.validateWithOptions(options)).size();
    }

    pub fn traversalLimitWords(self: *const MessageReader) usize {
        return self.options.traversal_limit_words;
    }

    pub fn traversalRemainingWords(self: *const MessageReader) usize {
        return self.traversal_remaining;
    }

    pub fn nestingLimit(self: *const MessageReader) u16 {
        return self.options.nesting_limit;
    }

    pub fn capabilityCountLimit(self: *const MessageReader) ?usize {
        return self.options.capability_count_limit;
    }

    pub fn segmentCount(self: *const MessageReader) usize {
        return self.segments.len;
    }

    pub fn segmentBytes(self: *const MessageReader, index: usize) Error!serialize.ConstSegment {
        if (index >= self.segments.len) return error.SegmentOutOfBounds;
        return self.segments[index];
    }

    pub fn segmentByteLen(self: *const MessageReader, index: usize) Error!usize {
        if (index >= self.segments.len) return error.SegmentOutOfBounds;
        return self.segments[index].len;
    }

    pub fn segmentWordLen(self: *const MessageReader, index: usize) (Error || serialize.Error)!usize {
        if (index >= self.segments.len) return error.SegmentOutOfBounds;
        if (self.segments[index].len % wire.bytes_per_word != 0) return error.SegmentNotWordAligned;
        return self.segments[index].len / wire.bytes_per_word;
    }

    pub fn serializedSize(self: *const MessageReader) (Error || serialize.Error)!usize {
        return serialize.computeSerializedSize(self.segments);
    }

    pub fn serializedSizeInWords(self: *const MessageReader) (Error || serialize.Error)!usize {
        return serialize.computeSerializedSizeInWords(self.segments);
    }

    pub fn serializeSegmentTable(self: *const MessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return serialize.serializeSegmentTable(allocator, self.segments);
    }

    pub fn toFlatBytes(self: *const MessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return serialize.messageToFlatBytes(allocator, self.segments);
    }

    pub fn toFlatBytesInto(self: *const MessageReader, dest: []u8) (Error || serialize.Error)!usize {
        return serialize.messageToFlatBytesInto(dest, self.segments);
    }

    pub fn toPackedBytes(self: *const MessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return serialize.messageToPackedBytes(allocator, self.segments);
    }

    pub fn maxPackedSize(self: *const MessageReader) (Error || serialize.Error)!usize {
        return serialize.maxPackedMessageSize(self.segments);
    }

    pub fn toPackedBytesInto(self: *const MessageReader, table_buffer: []u8, dest: []u8) (Error || serialize.Error)!usize {
        return serialize.messageToPackedBytesInto(table_buffer, dest, self.segments);
    }

    pub fn writeToWriter(self: *const MessageReader, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return serialize.writeMessageToWriter(writer, self.segments);
    }

    pub fn writePackedToWriter(self: *const MessageReader, allocator: std.mem.Allocator, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return serialize.writePackedMessageToWriter(allocator, writer, self.segments);
    }

    pub fn writePackedToWriterWithTableBuffer(self: *const MessageReader, table_buffer: []u8, writer: *std.Io.Writer) (Error || serialize.Error || std.Io.Writer.Error)!void {
        return serialize.writePackedMessageToWriterWithTableBuffer(table_buffer, writer, self.segments);
    }

    pub fn toCanonicalSegmentBytes(self: *const MessageReader, allocator: std.mem.Allocator) Error![]u8 {
        return messageToCanonicalSegmentBytes(allocator, self);
    }

    pub fn toSingleSegmentFlatBytes(self: *const MessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)![]u8 {
        return messageToSingleSegmentFlatBytes(allocator, self);
    }

    fn segmentWords(self: *const MessageReader, segment_id: u32) Error!usize {
        if (segment_id >= self.segments.len) return error.SegmentOutOfBounds;
        const segment = self.segments[segment_id];
        if (segment.len % wire.bytes_per_word != 0) return error.SegmentOutOfBounds;
        return segment.len / wire.bytes_per_word;
    }

    fn readWord(self: *const MessageReader, segment_id: u32, word_index: usize) Error!wire.Word {
        if (segment_id >= self.segments.len) return error.SegmentOutOfBounds;
        return wire.readWord(self.segments[segment_id], word_index);
    }

    fn charge(self: *MessageReader, words: usize) Error!void {
        const charged = @max(words, 1);
        if (charged > self.traversal_remaining) return error.TraversalLimitExceeded;
        self.traversal_remaining -= charged;
    }
};

/// Copy a message into a fresh builder with enough initial capacity to keep
/// every reachable object in segment 0, then serialize it using standard stream
/// framing. This is useful as a deterministic, mmap-friendly normalization
/// step and as a foundation for stricter canonicalization.
pub fn toSingleSegmentFlatBytes(allocator: std.mem.Allocator, source: *const MessageReader) (Error || serialize.Error)![]u8 {
    return messageToSingleSegmentFlatBytes(allocator, source);
}

fn messageToSingleSegmentFlatBytes(allocator: std.mem.Allocator, source: *const MessageReader) (Error || serialize.Error)![]u8 {
    var stats_reader = MessageReader.init(source.segments, source.options);
    const stats = try stats_reader.validate();
    const capacity = std.math.add(usize, stats.total_words, 1) catch return error.SerializedSizeOverflow;

    var copy_reader = MessageReader.init(source.segments, source.options);
    var builder = try MessageBuilder.init(allocator, .{
        .first_segment_words = @max(capacity, 1),
        .next_segment_min_words = @max(capacity, 1),
    });
    defer builder.deinit();

    _ = try builder.copyRootFrom(&copy_reader);
    const segments = try builder.segmentsConst();
    std.debug.assert(segments.len == 1);
    return serialize.messageToFlatBytes(allocator, segments);
}

/// Copy a message into a single segment in preorder while applying basic
/// schema-less canonicalization rules: far pointers are removed and trailing
/// zero-valued words in standalone struct data/pointer sections are truncated.
/// The returned bytes are the canonical segment payload; no stream segment
/// table is included.
pub fn toCanonicalSegmentBytes(allocator: std.mem.Allocator, source: *const MessageReader) Error![]u8 {
    return messageToCanonicalSegmentBytes(allocator, source);
}

fn messageToCanonicalSegmentBytes(allocator: std.mem.Allocator, source: *const MessageReader) Error![]u8 {
    var stats_reader = MessageReader.init(source.segments, source.options);
    const stats = try stats_reader.validate();
    const capacity = std.math.add(usize, stats.total_words, 1) catch return error.SerializedSizeOverflow;

    var copy_reader = MessageReader.init(source.segments, source.options);
    var builder = try MessageBuilder.init(allocator, .{
        .first_segment_words = @max(capacity, 1),
        .next_segment_min_words = @max(capacity, 1),
    });
    defer builder.deinit();

    _ = try builder.copyRootCanonicalFrom(&copy_reader);
    const segments = try builder.segmentsConst();
    std.debug.assert(segments.len == 1);
    return allocator.dupe(u8, segments[0]);
}

pub const PointerBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    word_index: usize,

    pub fn raw(self: PointerBuilder) wire.Word {
        return self.message.readWord(self.segment_id, self.word_index);
    }

    pub fn isNull(self: PointerBuilder) bool {
        return self.raw() == 0;
    }

    pub fn pointerType(self: PointerBuilder) ?wire.PointerType {
        const raw_value = self.raw();
        if (raw_value == 0) return null;
        return wire.pointerType(raw_value);
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
        self.message.writePtr(self.segment_id, self.word_index, 0);
    }

    pub fn disown(self: PointerBuilder) Orphan {
        const raw_value = self.message.readWord(self.segment_id, self.word_index);
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
                    self.message.writePtr(self.segment_id, self.word_index, try wire.encodeStruct(-1, 0, 0));
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
                    self.message.writePtr(self.segment_id, self.word_index, try wire.encodeList(0, l.element_size, l.element_count_or_words));
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
            .far, .other => self.message.writePtr(self.segment_id, self.word_index, orphan.raw),
        }
        orphan.raw = 0;
    }

    pub fn initStruct(self: PointerBuilder, size: wire.StructSize) Error!StructBuilder {
        const total_words = size.totalWords();
        if (total_words == 0) {
            self.message.writePtr(self.segment_id, self.word_index, try wire.encodeStruct(-1, 0, 0));
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
        self.message.writePtr(object.id, object.start, try wire.encodeStructListTag(element_count, size));
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

    pub fn setText(self: PointerBuilder, text: []const u8) Error!void {
        if (std.mem.indexOfScalar(u8, text, 0) != null) return error.TextContainsInteriorNul;
        if (!std.unicode.utf8ValidateSlice(text)) return error.Utf8Invalid;
        const list = try self.initList(.byte, text.len + 1);
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

    pub fn setCapability(self: PointerBuilder, index: u32) void {
        self.message.writePtr(self.segment_id, self.word_index, wire.encodeCapability(index));
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

    pub fn copyFrom(self: PointerBuilder, source: PointerReader) Error!void {
        try self.copyFromMode(source, false);
    }

    pub fn copyFromCanonical(self: PointerBuilder, source: PointerReader) Error!void {
        try self.copyFromMode(source, true);
    }

    pub fn copyStructFrom(self: PointerBuilder, source: StructReader) Error!void {
        const dst = try self.initStruct(.{
            .data_words = source.data_words,
            .pointer_count = source.pointer_count,
        });
        @memcpy(dst.dataBytes(), source.dataBytes());
        for (0..source.pointer_count) |i| {
            try (try dst.getPointerField(i)).copyFrom(source.getPointerField(i));
        }
    }

    pub fn copyStructFromBuilder(self: PointerBuilder, source: StructBuilder) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyStructFrom(source.asReader(&reader));
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

    fn copyFromMode(self: PointerBuilder, source: PointerReader, canonical: bool) Error!void {
        const resolved = try source.resolve();
        if (resolved.raw == 0) {
            self.message.writePtr(self.segment_id, self.word_index, 0);
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
                @memcpy(dst.dataBytes(), src.dataBytes()[0..dst.dataBytes().len]);
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
                self.message.writePtr(self.segment_id, self.word_index, resolved.raw);
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
                @memcpy(dst_element.dataBytes(), src_element.dataBytes()[0..dst_element.dataBytes().len]);
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

fn copyPrimitiveList(dst: ListBuilder, source: ListReader) Error!void {
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

fn copyPrimitiveBuilderList(dst: ListBuilder, source: ListBuilder, start_index: usize) Error!void {
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

    pub fn getList(self: PointerReader, expected: ?wire.ElementSize) Error!ListReader {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return error.NullPointer;
        if (wire.pointerType(resolved.raw) != .list) return error.InvalidPointerKind;
        const l = try wire.decodeList(resolved.raw);
        const struct_list_upgrade = if (expected) |exp| blk: {
            if (exp == l.element_size) break :blk false;
            if (l.element_size != .composite and exp == .composite) break :blk true;
            if (l.element_size != .composite) return error.IncompatibleListShape;
            break :blk false;
        } else false;
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
            .element_size = l.element_size,
            .data_words = primitiveDataWords(l.element_size),
            .pointer_count = primitivePointerCount(l.element_size),
            .step_bits = wire.bitsPerElement(l.element_size),
            .nesting_left = self.nesting_left - 1,
        };
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

    pub fn getData(self: PointerReader) Error![]const u8 {
        return (try self.getList(.byte)).bytes();
    }

    pub fn getDataDefault(self: PointerReader, default_value: []const u8) Error![]const u8 {
        if ((try self.raw()) == 0) return default_value;
        return self.getData();
    }

    pub fn getCapabilityIndex(self: PointerReader) Error!u32 {
        const resolved = try self.resolve();
        if (resolved.raw == 0) return error.NullPointer;
        if (wire.pointerType(resolved.raw) != .other) return error.InvalidPointerKind;
        return (try wire.decodeOther(resolved.raw)).index;
    }

    fn descend(self: PointerReader, words: usize) Error!void {
        if (self.nesting_left == 0) return error.NestingLimitExceeded;
        try self.message.charge(words);
    }

    fn boundsCheck(self: PointerReader, segment_id: u32, start: usize, words: usize) Error!void {
        const segment_words = try self.message.segmentWords(segment_id);
        if (start > segment_words or segment_words - start < words) return error.PointerOutOfBounds;
    }

    fn resolve(self: PointerReader) Error!ResolvedPointer {
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
        if (landing_far.landing_pad_offset >= target_segment_words) return error.InvalidFarPointer;
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

const ResolvedPointer = struct {
    segment_id: u32,
    pointer_word_index: usize,
    raw: wire.Word,
};

pub const StructBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    data_start: usize,
    pointer_start: usize,
    data_words: u16,
    pointer_count: u16,

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
        return .{ .message = self.message, .segment_id = self.segment_id, .word_index = self.pointer_start + index };
    }

    pub fn setBool(self: StructBuilder, bit_offset: usize, value: bool, default_value: bool) Error!void {
        try self.checkDataBit(bit_offset);
        const encoded = value != default_value;
        const abs_bit = self.data_start * wire.bits_per_word + bit_offset;
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        var word = self.message.readWord(self.segment_id, word_index);
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
        const abs_bit = self.data_start * wire.bits_per_word + bit_offset;
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        const word = self.message.readWord(self.segment_id, word_index);
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
        @memset(self.dataBytes()[byte_offset..][0..len], 0);
    }

    pub fn clear(self: StructBuilder) Error!void {
        @memset(self.dataBytes(), 0);
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
        const data_len = @min(self.dataBytes().len, source.dataBytes().len);
        @memcpy(self.dataBytes()[0..data_len], source.dataBytes()[0..data_len]);
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
        if (source.segment_id >= source.message.segments.len) return false;
        const dst_segment = std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items);
        const src_segment = source.message.segments[source.segment_id];
        if (dst_segment.ptr != src_segment.ptr) return false;

        const dst_start = self.data_start;
        const dst_end = dst_start + @as(usize, self.data_words) + @as(usize, self.pointer_count);
        const src_start = source.data_start;
        const src_end = src_start + @as(usize, source.data_words) + @as(usize, source.pointer_count);
        return wordRangesOverlap(dst_start, dst_end, src_start, src_end);
    }

    fn setInt(self: StructBuilder, comptime T: type, byte_offset: usize, value: T, default_value: T) Error!void {
        try self.checkDataBytes(byte_offset, @sizeOf(T));
        const encoded = value ^ default_value;
        const bytes = self.dataBytes()[byte_offset..][0..@sizeOf(T)];
        std.mem.writeInt(T, bytes, encoded, .little);
    }

    fn getInt(self: StructBuilder, comptime T: type, byte_offset: usize, default_value: T) Error!T {
        try self.checkDataBytes(byte_offset, @sizeOf(T));
        const bytes = self.dataBytes()[byte_offset..][0..@sizeOf(T)];
        return std.mem.readInt(T, bytes, .little) ^ default_value;
    }

    fn dataBytes(self: StructBuilder) []u8 {
        return std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items[self.data_start .. self.data_start + self.data_words]);
    }

    fn checkDataBit(self: StructBuilder, bit_offset: usize) Error!void {
        if (bit_offset >= @as(usize, self.data_words) * wire.bits_per_word) return error.PointerOutOfBounds;
    }

    fn checkDataBytes(self: StructBuilder, byte_offset: usize, len: usize) Error!void {
        const data_len = @as(usize, self.data_words) * wire.bytes_per_word;
        if (byte_offset > data_len or data_len - byte_offset < len) return error.PointerOutOfBounds;
    }
};

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
        return .{ .message = self.message, .segment_id = self.segment_id, .word_index = self.pointer_start + index, .nesting_left = self.nesting_left };
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
        const abs_bit = self.data_start * wire.bits_per_word + self.data_bit_offset + bit_offset;
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
        const field_bit_offset = byte_offset * 8;
        if (field_bit_offset > data_bits or data_bits - field_bit_offset < value_bits) return default_value;
        const absolute_bit_offset = self.data_bit_offset + field_bit_offset;
        if (absolute_bit_offset % 8 != 0) return default_value;
        const byte_start = self.data_start * wire.bytes_per_word + absolute_bit_offset / 8;
        if (self.segment_id >= self.message.segments.len) return default_value;
        const segment = self.message.segments[self.segment_id];
        if (byte_start > segment.len or segment.len - byte_start < @sizeOf(T)) return default_value;
        return std.mem.readInt(T, segment[byte_start..][0..@sizeOf(T)], .little) ^ default_value;
    }

    fn dataBytes(self: StructReader) []const u8 {
        if (self.segment_id >= self.message.segments.len) return &.{};
        if (self.data_bit_offset % 8 != 0) return &.{};
        const byte_start = self.data_start * wire.bytes_per_word + self.data_bit_offset / 8;
        const byte_len = self.effectiveDataBits() / 8;
        const segment = self.message.segments[self.segment_id];
        if (byte_start > segment.len or segment.len - byte_start < byte_len) return &.{};
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
};

pub const ListBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    start: usize,
    element_count: usize,
    element_size: wire.ElementSize,
    data_words: u16,
    pointer_count: u16,
    step_bits: usize,

    pub fn len(self: ListBuilder) usize {
        return self.element_count;
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

    pub fn structElementSize(self: ListBuilder) wire.StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn slice(self: ListBuilder, start_index: usize, count: usize) Error!ListBuilder {
        if (start_index > self.element_count or self.element_count - start_index < count) return error.PointerOutOfBounds;
        if (self.element_size != .pointer and self.element_size != .composite) {
            const start_bits = std.math.mul(usize, start_index, self.step_bits) catch return error.MessageTooLarge;
            if (start_bits % wire.bits_per_word != 0) {
                const copy = try self.orphanage().newList(self.element_size, count);
                const list = try copy.getList(self.element_size);
                try copyPrimitiveBuilderList(list, self, start_index);
                return list;
            }
        }
        const start_bits = std.math.mul(usize, start_index, self.step_bits) catch return error.MessageTooLarge;
        if (start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start_words = start_bits / wire.bits_per_word;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .start = self.start + start_words,
            .element_count = count,
            .element_size = self.element_size,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
            .step_bits = self.step_bits,
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
        const word_count = wire.wordsForBits(self.element_count * self.step_bits);
        return std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items[self.start .. self.start + word_count])[0..listByteLen(self.element_count, self.step_bits)];
    }

    pub fn rawPrimitiveBytes(self: ListBuilder) Error![]u8 {
        if (self.element_size == .pointer or self.element_size == .composite) return error.IncompatibleListShape;
        return self.bytes();
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
        const abs_bit = self.start * wire.bits_per_word + index;
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        var word = self.message.readWord(self.segment_id, word_index);
        if (value) word |= @as(u64, 1) << bit else word &= ~(@as(u64, 1) << bit);
        self.message.segments.items[self.segment_id].words.items[word_index] = word;
    }

    pub fn getBool(self: ListBuilder, index: usize) Error!bool {
        if (self.element_size != .bit or index >= self.element_count) return error.PointerOutOfBounds;
        const abs_bit = self.start * wire.bits_per_word + index;
        const word = self.message.readWord(self.segment_id, abs_bit / wire.bits_per_word);
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
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .word_index = self.start + index,
        };
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
        const step_words = @as(usize, self.data_words) + @as(usize, self.pointer_count);
        const start = self.start + index * step_words;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .data_start = start,
            .pointer_start = start + self.data_words,
            .data_words = self.data_words,
            .pointer_count = self.pointer_count,
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

    pub fn copyElementsFrom(self: ListBuilder, index: usize, source: ListReader, source_index: usize, count: usize) Error!void {
        if (index > self.element_count or self.element_count - index < count) return error.PointerOutOfBounds;
        if (source_index > source.element_count or source.element_count - source_index < count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .byte, .two_bytes, .four_bytes, .eight_bytes => {
                const bytes_per_element = wire.bitsPerElement(self.element_size) / 8;
                const byte_count = std.math.mul(usize, count, bytes_per_element) catch return error.MessageTooLarge;
                const dst_start = std.math.mul(usize, index, bytes_per_element) catch return error.MessageTooLarge;
                const src_start = std.math.mul(usize, source_index, bytes_per_element) catch return error.MessageTooLarge;
                const source_bytes = try source.rawPrimitiveBytes();
                const dest_bytes = try self.rawPrimitiveBytes();
                @memcpy(dest_bytes[dst_start..][0..byte_count], source_bytes[src_start..][0..byte_count]);
                return;
            },
            else => {},
        }
        for (0..count) |offset| {
            try self.copyElementFrom(index + offset, source, source_index + offset);
        }
    }

    pub fn copyElementFromBuilder(self: ListBuilder, index: usize, source: ListBuilder, source_index: usize) Error!void {
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyElementFrom(index, source.asReader(&reader), source_index);
    }

    pub fn copyElementsFromBuilder(self: ListBuilder, index: usize, source: ListBuilder, source_index: usize, count: usize) Error!void {
        if (index > self.element_count or self.element_count - index < count) return error.PointerOutOfBounds;
        if (source_index > source.element_count or source.element_count - source_index < count) return error.PointerOutOfBounds;
        if (self.element_size != source.element_size) return error.IncompatibleListShape;
        switch (self.element_size) {
            .byte, .two_bytes, .four_bytes, .eight_bytes => {
                const bytes_per_element = wire.bitsPerElement(self.element_size) / 8;
                const byte_count = std.math.mul(usize, count, bytes_per_element) catch return error.MessageTooLarge;
                const dst_start = std.math.mul(usize, index, bytes_per_element) catch return error.MessageTooLarge;
                const src_start = std.math.mul(usize, source_index, bytes_per_element) catch return error.MessageTooLarge;
                const source_bytes = try source.rawPrimitiveBytes();
                const dest_bytes = try self.rawPrimitiveBytes();
                @memmove(dest_bytes[dst_start..][0..byte_count], source_bytes[src_start..][0..byte_count]);
                return;
            },
            else => {},
        }
        var reader = MessageReader.init(try source.message.segmentsConst(), .{});
        return self.copyElementsFrom(index, source.asReader(&reader), source_index, count);
    }

    fn setPrimitive(self: ListBuilder, comptime T: type, index: usize, value: T) Error!void {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        const byte_offset = index * @sizeOf(T);
        const target_bytes = self.bytes()[byte_offset..][0..@sizeOf(T)];
        std.mem.writeInt(T, target_bytes, value, .little);
    }

    fn getPrimitive(self: ListBuilder, comptime T: type, index: usize) Error!T {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        const byte_offset = index * @sizeOf(T);
        const source_bytes = self.bytes()[byte_offset..][0..@sizeOf(T)];
        return std.mem.readInt(T, source_bytes, .little);
    }
};

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

    pub fn structElementSize(self: ListReader) wire.StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn slice(self: ListReader, start_index: usize, count: usize) Error!ListReader {
        if (start_index > self.element_count or self.element_count - start_index < count) return error.PointerOutOfBounds;
        const relative_start_bits = std.math.mul(usize, start_index, self.step_bits) catch return error.MessageTooLarge;
        const start_bits = std.math.add(usize, self.bit_offset, relative_start_bits) catch return error.MessageTooLarge;
        if ((self.element_size == .pointer or self.element_size == .composite) and start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start_words = start_bits / wire.bits_per_word;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .start = self.start + start_words,
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
        if (self.segment_id >= self.message.segments.len) return &.{};
        if (self.bit_offset % 8 != 0) return &.{};
        const bit_len = std.math.mul(usize, self.element_count, self.step_bits) catch return &.{};
        const byte_len = (bit_len + 7) / 8;
        const byte_start = (std.math.mul(usize, self.start, wire.bytes_per_word) catch return &.{}) + self.bit_offset / 8;
        const segment = self.message.segments[self.segment_id];
        if (byte_start > segment.len or segment.len - byte_start < byte_len) return &.{};
        return segment[byte_start..][0..byte_len];
    }

    pub fn rawPrimitiveBytes(self: ListReader) Error![]const u8 {
        if (self.element_size == .pointer or self.element_size == .composite) return error.IncompatibleListShape;
        if (self.bit_offset % 8 != 0) return error.UnsupportedElementSize;
        return self.bytes();
    }

    pub fn getBool(self: ListReader, index: usize) bool {
        if (self.element_size != .bit or index >= self.element_count) return false;
        const element_bits = std.math.mul(usize, index, self.step_bits) catch return false;
        const relative_bit = std.math.add(usize, self.bit_offset, element_bits) catch return false;
        if (self.limit_element_data_bits and self.element_data_bits == 0) return false;
        const abs_bit = self.start * wire.bits_per_word + relative_bit;
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
            return .{
                .message = self.message,
                .segment_id = self.segment_id,
                .word_index = self.start + index,
                .nesting_left = self.nesting_left,
            };
        }
        if (self.pointer_count == 0) {
            return .{ .message = self.message, .segment_id = self.segment_id, .word_index = 0, .nesting_left = self.nesting_left, .null_override = true };
        }
        const element_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (element_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .word_index = self.start + element_bits / wire.bits_per_word + self.data_words,
            .nesting_left = self.nesting_left,
        };
    }

    pub fn getStructElement(self: ListReader, index: usize) Error!StructReader {
        if (self.element_size == .bit or index >= self.element_count) return error.PointerOutOfBounds;
        const start_bits = std.math.add(usize, self.bit_offset, std.math.mul(usize, index, self.step_bits) catch return error.MessageTooLarge) catch return error.MessageTooLarge;
        if (self.pointer_count != 0 and start_bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
        const start = self.start + start_bits / wire.bits_per_word;
        const data_bit_offset = start_bits % wire.bits_per_word;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .data_start = start,
            .pointer_start = start + self.data_words,
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

fn tag_forFarWithZeroOffset(tag: wire.Word) wire.Word {
    return switch (wire.pointerType(tag)) {
        .struct_ptr => blk: {
            const s = wire.decodeStruct(tag);
            break :blk wire.encodeStruct(0, s.data_words, s.pointer_count) catch unreachable;
        },
        .list => blk: {
            const l = wire.decodeList(tag) catch unreachable;
            break :blk wire.encodeList(0, l.element_size, l.element_count_or_words) catch unreachable;
        },
        else => tag,
    };
}

fn primitiveDataWords(size: wire.ElementSize) u16 {
    return switch (size) {
        .pointer => 0,
        .void => 0,
        .bit => 0,
        .byte, .two_bytes, .four_bytes, .eight_bytes => 1,
        .composite => 0,
    };
}

fn primitivePointerCount(size: wire.ElementSize) u16 {
    return if (size == .pointer) 1 else 0;
}

fn upgradedStructListShape(size: wire.ElementSize) Error!struct { data_words: u16, pointer_count: u16 } {
    return switch (size) {
        .void => .{ .data_words = 0, .pointer_count = 0 },
        .bit, .byte, .two_bytes, .four_bytes, .eight_bytes => .{ .data_words = 1, .pointer_count = 0 },
        .pointer => .{ .data_words = 0, .pointer_count = 1 },
        .composite => error.IncompatibleListShape,
    };
}

fn validatePointer(ptr: PointerReader, stats: *MessageStats) Error!void {
    try addStat(&stats.pointer_slots, 1);

    const resolved = try ptr.resolve();
    if (resolved.raw == 0) return;
    try addStat(&stats.non_null_pointers, 1);

    switch (wire.pointerType(resolved.raw)) {
        .struct_ptr => {
            const s = try ptr.getStruct(null);
            try collectStructStats(s, stats);
        },
        .list => {
            const list = try ptr.getList(null);
            try collectListStats(list, stats);
        },
        .far => return error.InvalidFarPointer,
        .other => {
            const cap = try wire.decodeOther(resolved.raw);
            if (ptr.message.options.capability_count_limit) |limit| {
                if (@as(usize, cap.index) >= limit) return error.InvalidCapabilityPointer;
            }
            try addStat(&stats.capabilities, 1);
            if (stats.max_capability_index == null or cap.index > stats.max_capability_index.?) {
                stats.max_capability_index = cap.index;
            }
        },
    }
}

fn collectStructStats(s: StructReader, stats: *MessageStats) Error!void {
    try addStat(&stats.structs, 1);
    try addStat(&stats.data_words, s.data_words);
    try addStat(&stats.pointer_words, s.pointer_count);
    try addStat(&stats.total_words, @as(usize, s.data_words) + @as(usize, s.pointer_count));
    for (0..s.pointer_count) |i| {
        try validatePointer(s.getPointerField(i), stats);
    }
}

fn collectListStats(list: ListReader, stats: *MessageStats) Error!void {
    try addStat(&stats.lists, 1);
    switch (list.element_size) {
        .pointer => {
            try addStat(&stats.pointer_words, list.element_count);
            try addStat(&stats.total_words, list.element_count);
            for (0..list.element_count) |i| {
                try validatePointer(try list.getPointerElement(i), stats);
            }
        },
        .composite => {
            if (list.limit_element_data_bits) {
                const content_words = wire.wordsForBits(std.math.mul(usize, list.element_data_bits, list.element_count) catch return error.SerializedSizeOverflow);
                try addStat(&stats.structs, list.element_count);
                try addStat(&stats.data_words, content_words);
                try addStat(&stats.total_words, content_words);
                return;
            }
            const element_words = @as(usize, list.data_words) + @as(usize, list.pointer_count);
            const content_words = std.math.mul(usize, element_words, list.element_count) catch return error.SerializedSizeOverflow;
            try addStat(&stats.structs, list.element_count);
            try addStat(&stats.data_words, std.math.mul(usize, list.data_words, list.element_count) catch return error.SerializedSizeOverflow);
            try addStat(&stats.pointer_words, std.math.mul(usize, list.pointer_count, list.element_count) catch return error.SerializedSizeOverflow);
            try addStat(&stats.total_words, std.math.add(usize, content_words, 1) catch return error.SerializedSizeOverflow); // include composite tag word.
            for (0..list.element_count) |element_index| {
                const element = try list.getStructElement(element_index);
                for (0..element.pointer_count) |pointer_index| {
                    try validatePointer(element.getPointerField(pointer_index), stats);
                }
            }
        },
        else => {
            const words = try wire.wordsForList(list.element_size, list.element_count);
            try addStat(&stats.data_words, words);
            try addStat(&stats.total_words, words);
        },
    }
}

fn addStat(target: *usize, amount: usize) Error!void {
    target.* = std.math.add(usize, target.*, amount) catch return error.SerializedSizeOverflow;
}

fn canonicalStructSize(s: StructReader) Error!wire.StructSize {
    var data_words: usize = s.data_words;
    while (data_words > 0) {
        const word = try s.message.readWord(s.segment_id, s.data_start + data_words - 1);
        if (word != 0) break;
        data_words -= 1;
    }

    var pointer_count: usize = s.pointer_count;
    while (pointer_count > 0) {
        const word = try s.message.readWord(s.segment_id, s.pointer_start + pointer_count - 1);
        if (word != 0) break;
        pointer_count -= 1;
    }

    return .{
        .data_words = @intCast(data_words),
        .pointer_count = @intCast(pointer_count),
    };
}

fn canonicalStructListSize(list: ListReader) Error!wire.StructSize {
    var data_words: usize = list.data_words;
    while (data_words > 0) {
        const word_index = data_words - 1;
        var all_zero = true;
        for (0..list.element_count) |i| {
            const element = try list.getStructElement(i);
            const word = try element.message.readWord(element.segment_id, element.data_start + word_index);
            if (word != 0) {
                all_zero = false;
                break;
            }
        }
        if (!all_zero) break;
        data_words -= 1;
    }

    var pointer_count: usize = list.pointer_count;
    while (pointer_count > 0) {
        const pointer_index = pointer_count - 1;
        var all_zero = true;
        for (0..list.element_count) |i| {
            const element = try list.getStructElement(i);
            const word = try element.message.readWord(element.segment_id, element.pointer_start + pointer_index);
            if (word != 0) {
                all_zero = false;
                break;
            }
        }
        if (!all_zero) break;
        pointer_count -= 1;
    }

    return .{
        .data_words = @intCast(data_words),
        .pointer_count = @intCast(pointer_count),
    };
}

fn wordRangesOverlap(a_start: usize, a_end: usize, b_start: usize, b_end: usize) bool {
    return a_start < b_end and b_start < a_end;
}

fn listByteLen(element_count: usize, step_bits: usize) usize {
    const bits = std.math.mul(usize, element_count, step_bits) catch @panic("list byte length overflow");
    return (bits + 7) / 8;
}

test "builder and reader round-trip struct with text" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 0x1234_5678, 0);
    try root.setBool(32, true, false);
    try root.setText(0, "hello");

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 0x1234_5678), read_root.getUInt32(0, 0));
    try testing.expect(read_root.getBool(32, false));
    try testing.expectEqualSlices(u8, "hello", try read_root.getPointerField(0).getText());
}

test "message builder serializes flat, packed, and canonical bytes directly" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 2, .pointer_count = 1 });
    try root.setUInt32(0, 11, 0);
    try root.setText(0, "direct");

    const flat = try builder.toFlatBytes();
    defer testing.allocator.free(flat);
    var builder_flat_buffer: [128]u8 = undefined;
    const builder_flat_len = try builder.toFlatBytesInto(&builder_flat_buffer);
    try testing.expectEqualSlices(u8, flat, builder_flat_buffer[0..builder_flat_len]);
    var parsed = try serialize.readFlatMessage(testing.allocator, flat);
    defer parsed.deinit(testing.allocator);
    var flat_reader = MessageReader.init(parsed.segments, .{});
    try testing.expectEqual(@as(u32, 11), (try flat_reader.getRoot()).getUInt32(0, 0));

    const packed_bytes = try builder.toPackedBytes();
    defer testing.allocator.free(packed_bytes);
    try testing.expect((try builder.maxPackedSize()) >= packed_bytes.len);
    var builder_packed_table_buffer: [8]u8 = undefined;
    var builder_packed_buffer: [128]u8 = undefined;
    const builder_packed_len = try builder.toPackedBytesInto(&builder_packed_table_buffer, &builder_packed_buffer);
    var builder_packed_parsed = try serialize.readPackedMessage(testing.allocator, builder_packed_buffer[0..builder_packed_len]);
    defer builder_packed_parsed.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, flat, builder_packed_parsed.bytes);
    var parsed_packed = try serialize.readPackedMessage(testing.allocator, packed_bytes);
    defer parsed_packed.deinit(testing.allocator);
    var packed_reader = MessageReader.init(parsed_packed.segments, .{});
    try testing.expectEqualSlices(u8, "direct", try (try packed_reader.getRoot()).getPointerField(0).getText());

    const canonical = try builder.toCanonicalSegmentBytes(.{});
    defer testing.allocator.free(canonical);
    const root_ptr = wire.decodeStruct(try wire.readWord(canonical, 0));
    try testing.expectEqual(@as(u16, 1), root_ptr.data_words);
}

test "owned message readers parse flat and packed bytes" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 5150, 0);
    try root.setText(0, "owned");

    const flat = try builder.toFlatBytes();
    defer testing.allocator.free(flat);
    var owned_flat = try OwnedMessageReader.initFlat(testing.allocator, flat, .{});
    defer owned_flat.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_flat.consumedLen());
    try testing.expectEqual(flat.len, owned_flat.sourceConsumedLen());
    try testing.expectEqual(flat.len, owned_flat.bytes().len);
    try testing.expectEqual(@as(u32, 5150), (try owned_flat.asReader().getRoot()).getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "owned", try (try owned_flat.asReader().getRoot()).getPointerField(0).getText());
    try testing.expectEqual(@as(u32, 5150), (try owned_flat.getRoot()).getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "owned", try (try owned_flat.getRoot()).getPointerField(0).getText());
    const owned_root_pointer = try owned_flat.getRootPointer();
    try testing.expectEqual(wire.PointerType.struct_ptr, (try owned_root_pointer.pointerType()).?);
    try testing.expect(!try owned_flat.isRootNull());
    try testing.expectEqual(wire.PointerType.struct_ptr, (try owned_flat.getRootPointerKind()).?);
    try testing.expectEqual(wire.PointerType.struct_ptr, wire.pointerType(try owned_flat.getRootRawPointer()));
    switch ((try owned_flat.getRootDecodedPointer()).?) {
        .struct_ptr => {},
        else => return error.TestUnexpectedResult,
    }
    try testing.expectEqual(@as(usize, 1), owned_flat.segmentCount());
    try testing.expect((try owned_flat.segmentByteLen(0)) > 0);
    try testing.expect((try owned_flat.segmentWordLen(0)) > 0);
    try testing.expectEqual(flat.len, try owned_flat.serializedSize());
    try testing.expectEqual(flat.len / wire.bytes_per_word, try owned_flat.serializedSizeInWords());
    try testing.expectEqual(@as(usize, 8 * 1024 * 1024), owned_flat.traversalLimitWords());
    try testing.expectEqual(@as(u16, 64), owned_flat.nestingLimit());
    try testing.expectEqual(@as(?usize, null), owned_flat.capabilityCountLimit());
    const owned_table = try owned_flat.serializeSegmentTable(testing.allocator);
    defer testing.allocator.free(owned_table);
    try testing.expectEqual(serialize.segmentTableWords(owned_flat.segmentCount()) * wire.bytes_per_word, owned_table.len);
    const owned_flat_bytes = try owned_flat.toFlatBytes(testing.allocator);
    defer testing.allocator.free(owned_flat_bytes);
    try testing.expectEqualSlices(u8, flat, owned_flat_bytes);
    var owned_flat_into_buffer: [128]u8 = undefined;
    const owned_flat_into_len = try owned_flat.toFlatBytesInto(&owned_flat_into_buffer);
    try testing.expectEqualSlices(u8, flat, owned_flat_into_buffer[0..owned_flat_into_len]);
    const owned_packed_bytes = try owned_flat.toPackedBytes(testing.allocator);
    defer testing.allocator.free(owned_packed_bytes);
    try testing.expect((try owned_flat.maxPackedSize()) >= owned_packed_bytes.len);
    var owned_packed_into_table: [8]u8 = undefined;
    var owned_packed_into_buffer: [128]u8 = undefined;
    const owned_packed_into_len = try owned_flat.toPackedBytesInto(&owned_packed_into_table, &owned_packed_into_buffer);
    var owned_packed_into = try serialize.readPackedMessage(testing.allocator, owned_packed_into_buffer[0..owned_packed_into_len]);
    defer owned_packed_into.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, flat, owned_packed_into.bytes);
    var owned_roundtrip = try serialize.readPackedMessage(testing.allocator, owned_packed_bytes);
    defer owned_roundtrip.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_roundtrip.consumed_len);
    var owned_write_buffer: [128]u8 = undefined;
    var owned_writer = std.Io.Writer.fixed(&owned_write_buffer);
    try owned_flat.writeToWriter(&owned_writer);
    try testing.expectEqualSlices(u8, flat, std.Io.Writer.buffered(&owned_writer));
    var owned_packed_write_buffer: [128]u8 = undefined;
    var owned_packed_writer = std.Io.Writer.fixed(&owned_packed_write_buffer);
    try owned_flat.writePackedToWriter(testing.allocator, &owned_packed_writer);
    var owned_packed_table_buffer: [8]u8 = undefined;
    var owned_packed_no_alloc_buffer: [128]u8 = undefined;
    var owned_packed_no_alloc_writer = std.Io.Writer.fixed(&owned_packed_no_alloc_buffer);
    try owned_flat.writePackedToWriterWithTableBuffer(&owned_packed_table_buffer, &owned_packed_no_alloc_writer);
    try testing.expectEqualSlices(u8, std.Io.Writer.buffered(&owned_packed_writer), std.Io.Writer.buffered(&owned_packed_no_alloc_writer));
    var owned_packed_stream = try serialize.readPackedMessage(testing.allocator, std.Io.Writer.buffered(&owned_packed_writer));
    defer owned_packed_stream.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_packed_stream.consumed_len);
    const owned_canonical = try owned_flat.toCanonicalSegmentBytes(testing.allocator);
    defer testing.allocator.free(owned_canonical);
    try testing.expect(owned_canonical.len > 0);
    const owned_single = try owned_flat.toSingleSegmentFlatBytes(testing.allocator);
    defer testing.allocator.free(owned_single);
    try testing.expectEqual(flat.len, owned_single.len);
    try testing.expect((try owned_flat.validate()).total_words > 0);
    try testing.expect((try owned_flat.totalSize()).word_count > 0);

    const packed_bytes = try builder.toPackedBytes();
    defer testing.allocator.free(packed_bytes);
    var owned_packed = try OwnedMessageReader.initPacked(testing.allocator, packed_bytes, .{});
    defer owned_packed.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_packed.consumedLen());
    try testing.expectEqual(packed_bytes.len, owned_packed.sourceConsumedLen());
    try testing.expectEqual(@as(u32, 5150), (try owned_packed.asReader().getRoot()).getUInt32(0, 0));

    var empty_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer empty_builder.deinit();
    const empty_flat = try empty_builder.toFlatBytes();
    defer testing.allocator.free(empty_flat);
    var empty_owned = try OwnedMessageReader.initFlat(testing.allocator, empty_flat, .{});
    defer empty_owned.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, "owned default", try empty_owned.getRootTextDefault("owned default"));
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2 }, try empty_owned.getRootDataDefault(&[_]u8{ 1, 2 }));

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer data_builder.deinit();
    try data_builder.setRootData(&[_]u8{ 4, 5 });
    const data_flat = try data_builder.toFlatBytes();
    defer testing.allocator.free(data_flat);
    var data_owned = try OwnedMessageReader.initFlat(testing.allocator, data_flat, .{});
    defer data_owned.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, &[_]u8{ 4, 5 }, try data_owned.getRootDataDefault(&[_]u8{ 1, 2 }));

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer text_builder.deinit();
    try text_builder.setRootText("owned root text");
    const text_flat = try text_builder.toFlatBytes();
    defer testing.allocator.free(text_flat);
    var text_owned = try OwnedMessageReader.initFlat(testing.allocator, text_flat, .{});
    defer text_owned.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, "owned root text", try text_owned.getRootTextDefault("ignored"));

    const trailer = [_]u8{ 0xde, 0xad };
    const flat_with_trailer = try std.mem.concat(testing.allocator, u8, &.{ flat, &trailer });
    defer testing.allocator.free(flat_with_trailer);
    var owned_flat_with_trailer = try OwnedMessageReader.initFlat(testing.allocator, flat_with_trailer, .{});
    defer owned_flat_with_trailer.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_flat_with_trailer.consumedLen());
    try testing.expectEqual(flat.len, owned_flat_with_trailer.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, owned_flat_with_trailer.bytes());
    var flat_stream = std.Io.Reader.fixed(flat_with_trailer);
    var owned_from_reader = try OwnedMessageReader.initFromReader(testing.allocator, &flat_stream, .{});
    defer owned_from_reader.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_from_reader.consumedLen());
    try testing.expectEqual(flat.len, owned_from_reader.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, owned_from_reader.bytes());
    try testing.expectEqualSlices(u8, &trailer, flat_stream.buffered());

    const packed_with_trailer = try std.mem.concat(testing.allocator, u8, &.{ packed_bytes, &trailer });
    defer testing.allocator.free(packed_with_trailer);
    var owned_packed_with_trailer = try OwnedMessageReader.initPacked(testing.allocator, packed_with_trailer, .{});
    defer owned_packed_with_trailer.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_packed_with_trailer.consumedLen());
    try testing.expectEqual(packed_bytes.len, owned_packed_with_trailer.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, owned_packed_with_trailer.bytes());
    var packed_slice_view_segments: [1]serialize.ConstSegment = undefined;
    var packed_slice_view_buffer: [128]u8 = undefined;
    var packed_slice_view = try MessageReaderView.initPackedInto(&packed_slice_view_segments, &packed_slice_view_buffer, packed_with_trailer, .{});
    defer packed_slice_view.deinit(testing.allocator);
    try testing.expectEqual(flat.len, packed_slice_view.consumedLen());
    try testing.expectEqual(packed_bytes.len, packed_slice_view.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, packed_slice_view.bytes());
    var packed_stream = std.Io.Reader.fixed(packed_with_trailer);
    var owned_packed_from_reader = try OwnedMessageReader.initPackedFromReader(testing.allocator, &packed_stream, .{});
    defer owned_packed_from_reader.deinit(testing.allocator);
    try testing.expectEqual(flat.len, owned_packed_from_reader.consumedLen());
    try testing.expectEqual(packed_bytes.len, owned_packed_from_reader.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, owned_packed_from_reader.bytes());
    try testing.expectEqualSlices(u8, &trailer, packed_stream.buffered());
    var packed_view_stream = std.Io.Reader.fixed(packed_with_trailer);
    var packed_view_segments: [1]serialize.ConstSegment = undefined;
    var packed_view_buffer: [128]u8 = undefined;
    var packed_view = try MessageReaderView.initPackedFromReaderInto(&packed_view_segments, &packed_view_buffer, &packed_view_stream, .{});
    defer packed_view.deinit(testing.allocator);
    try testing.expectEqual(flat.len, packed_view.consumedLen());
    try testing.expectEqual(packed_bytes.len, packed_view.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, packed_view.bytes());
    try testing.expectEqualSlices(u8, &trailer, packed_view_stream.buffered());
}

test "message reader views parse flat bytes without copying message data" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 6160, 0);
    try root.setText(0, "view");

    const flat = try builder.toFlatBytes();
    defer testing.allocator.free(flat);
    const trailer = [_]u8{ 1, 2, 3 };
    const flat_with_trailer = try std.mem.concat(testing.allocator, u8, &.{ flat, &trailer });
    defer testing.allocator.free(flat_with_trailer);

    var view = try MessageReaderView.initFlat(testing.allocator, flat_with_trailer, .{});
    defer view.deinit(testing.allocator);
    try testing.expectEqual(flat.len, view.consumedLen());
    try testing.expectEqual(flat.len, view.sourceConsumedLen());
    try testing.expectEqualSlices(u8, flat, view.bytes());
    var stack_view_segments: [1]serialize.ConstSegment = undefined;
    var stack_view = try MessageReaderView.initFlatInto(&stack_view_segments, flat_with_trailer, .{});
    defer stack_view.deinit(testing.allocator);
    try testing.expectEqual(flat.len, stack_view.consumedLen());
    try testing.expectEqualSlices(u8, flat, stack_view.bytes());
    try testing.expect(!stack_view.flat.owns_segments);
    try testing.expectEqual(@as(u32, 6160), (try stack_view.getRoot()).getUInt32(0, 0));
    var stack_stream = std.Io.Reader.fixed(flat_with_trailer);
    var stream_view_segments: [1]serialize.ConstSegment = undefined;
    var stream_view_buffer: [128]u8 = undefined;
    var stream_view = try MessageReaderView.initFromReaderInto(&stream_view_segments, &stream_view_buffer, &stack_stream, .{});
    defer stream_view.deinit(testing.allocator);
    try testing.expectEqual(flat.len, stream_view.consumedLen());
    try testing.expectEqualSlices(u8, flat, stream_view.bytes());
    try testing.expectEqualSlices(u8, &trailer, stack_stream.buffered());
    try testing.expectEqual(@as(u32, 6160), (try stream_view.getRoot()).getUInt32(0, 0));
    try testing.expectEqual(@as(u32, 6160), (try view.asReader().getRoot()).getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "view", try (try view.asReader().getRoot()).getPointerField(0).getText());
    try testing.expectEqual(@as(u32, 6160), (try view.getRoot()).getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "view", try (try view.getRoot()).getPointerField(0).getText());
    const view_root_pointer = try view.getRootPointer();
    try testing.expectEqual(wire.PointerType.struct_ptr, (try view_root_pointer.pointerType()).?);
    try testing.expect(!try view.isRootNull());
    try testing.expectEqual(wire.PointerType.struct_ptr, (try view.getRootPointerKind()).?);
    try testing.expectEqual(wire.PointerType.struct_ptr, wire.pointerType(try view.getRootRawPointer()));
    try testing.expectEqual(@as(usize, 1), view.segmentCount());
    try testing.expect((try view.segmentByteLen(0)) > 0);
    try testing.expectEqual(flat.len, try view.serializedSize());
    const view_flat_bytes = try view.toFlatBytes(testing.allocator);
    defer testing.allocator.free(view_flat_bytes);
    try testing.expectEqualSlices(u8, flat, view_flat_bytes);
    var view_flat_into_buffer: [128]u8 = undefined;
    const view_flat_into_len = try view.toFlatBytesInto(&view_flat_into_buffer);
    try testing.expectEqualSlices(u8, flat, view_flat_into_buffer[0..view_flat_into_len]);
    var view_write_buffer: [128]u8 = undefined;
    var view_writer = std.Io.Writer.fixed(&view_write_buffer);
    try view.writeToWriter(&view_writer);
    try testing.expectEqualSlices(u8, flat, std.Io.Writer.buffered(&view_writer));
    var view_packed_write_buffer: [128]u8 = undefined;
    var view_packed_writer = std.Io.Writer.fixed(&view_packed_write_buffer);
    try view.writePackedToWriter(testing.allocator, &view_packed_writer);
    try testing.expect((try view.maxPackedSize()) >= std.Io.Writer.buffered(&view_packed_writer).len);
    var view_packed_into_table: [8]u8 = undefined;
    var view_packed_into_buffer: [128]u8 = undefined;
    const view_packed_into_len = try view.toPackedBytesInto(&view_packed_into_table, &view_packed_into_buffer);
    try testing.expectEqualSlices(u8, std.Io.Writer.buffered(&view_packed_writer), view_packed_into_buffer[0..view_packed_into_len]);
    var view_packed_table_buffer: [8]u8 = undefined;
    var view_packed_no_alloc_buffer: [128]u8 = undefined;
    var view_packed_no_alloc_writer = std.Io.Writer.fixed(&view_packed_no_alloc_buffer);
    try view.writePackedToWriterWithTableBuffer(&view_packed_table_buffer, &view_packed_no_alloc_writer);
    try testing.expectEqualSlices(u8, std.Io.Writer.buffered(&view_packed_writer), std.Io.Writer.buffered(&view_packed_no_alloc_writer));
    var view_packed_stream = try serialize.readPackedMessage(testing.allocator, std.Io.Writer.buffered(&view_packed_writer));
    defer view_packed_stream.deinit(testing.allocator);
    try testing.expectEqual(flat.len, view_packed_stream.consumed_len);
    const view_canonical = try view.toCanonicalSegmentBytes(testing.allocator);
    defer testing.allocator.free(view_canonical);
    try testing.expect(view_canonical.len > 0);
    const view_single = try view.toSingleSegmentFlatBytes(testing.allocator);
    defer testing.allocator.free(view_single);
    try testing.expectEqual(flat.len, view_single.len);
    try testing.expect((try view.validate()).total_words > 0);
    try testing.expect((try view.totalSize()).word_count > 0);
    const segment0 = try view.asReader().segmentBytes(0);
    const segment0_addr = @intFromPtr(segment0.ptr);
    const flat_addr = @intFromPtr(flat_with_trailer.ptr);
    try testing.expect(segment0_addr >= flat_addr);
    try testing.expect(segment0_addr < flat_addr + flat_with_trailer.len);

    var empty_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer empty_builder.deinit();
    const empty_flat = try empty_builder.toFlatBytes();
    defer testing.allocator.free(empty_flat);
    var empty_view = try MessageReaderView.initFlat(testing.allocator, empty_flat, .{});
    defer empty_view.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, "view default", try empty_view.getRootTextDefault("view default"));

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer text_builder.deinit();
    try text_builder.setRootText("view root text");
    const text_flat = try text_builder.toFlatBytes();
    defer testing.allocator.free(text_flat);
    var text_view = try MessageReaderView.initFlat(testing.allocator, text_flat, .{});
    defer text_view.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, "view root text", try text_view.getRootTextDefault("ignored"));
}

test "message builder writes flat and packed streams directly" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 777, 0);
    try root.setText(0, "writer");

    const expected_flat = try builder.toFlatBytes();
    defer testing.allocator.free(expected_flat);
    var flat_buffer: [128]u8 = undefined;
    var flat_writer = std.Io.Writer.fixed(&flat_buffer);
    try builder.writeToWriter(&flat_writer);
    try testing.expectEqualSlices(u8, expected_flat, std.Io.Writer.buffered(&flat_writer));

    var packed_buffer: [128]u8 = undefined;
    var packed_writer = std.Io.Writer.fixed(&packed_buffer);
    try builder.writePackedToWriter(&packed_writer);
    var packed_table_buffer: [8]u8 = undefined;
    var packed_no_alloc_buffer: [128]u8 = undefined;
    var packed_no_alloc_writer = std.Io.Writer.fixed(&packed_no_alloc_buffer);
    try builder.writePackedToWriterWithTableBuffer(&packed_table_buffer, &packed_no_alloc_writer);
    try testing.expectEqualSlices(u8, std.Io.Writer.buffered(&packed_writer), std.Io.Writer.buffered(&packed_no_alloc_writer));
    var parsed = try serialize.readPackedMessage(testing.allocator, std.Io.Writer.buffered(&packed_writer));
    defer parsed.deinit(testing.allocator);
    var reader = MessageReader.init(parsed.segments, .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 777), read_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "writer", try read_root.getPointerField(0).getText());
}

test "builder rejects invalid UTF-8 text" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 4 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    try testing.expectError(error.Utf8Invalid, root.setText(0, &[_]u8{ 0xff, 0xfe }));
    try testing.expectError(error.TextContainsInteriorNul, root.setText(0, "bad\x00text"));
}

test "pointer reader returns caller defaults for null text and data" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqualSlices(u8, "fallback", try read_root.getPointerField(0).getTextDefault("fallback"));
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, try read_root.getPointerField(1).getDataDefault(&[_]u8{ 1, 2, 3 }));
    try testing.expectError(error.TextContainsInteriorNul, read_root.getPointerField(0).getTextDefault("bad\x00default"));

    try root.setText(0, "actual");
    try root.setData(1, &[_]u8{ 9, 8 });
    var reader2 = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root2 = try reader2.getRoot();
    try testing.expectEqualSlices(u8, "actual", try read_root2.getPointerField(0).getTextDefault("fallback"));
    try testing.expectEqualSlices(u8, &[_]u8{ 9, 8 }, try read_root2.getPointerField(1).getDataDefault(&[_]u8{ 1, 2, 3 }));
}

test "builder creates multiple segments and reader follows far pointers" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2, .next_segment_min_words = 2 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setText(0, "far");

    try testing.expect(builder.segments.items.len > 1);
    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqualSlices(u8, "far", try read_root.getPointerField(0).getText());
}

test "primitive and struct lists" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    try testing.expectEqual(wire.StructSize{ .data_words = 0, .pointer_count = 2 }, root.size());
    try testing.expect(!root.size().isEmpty());
    try testing.expect(!root.size().hasDataWords());
    try testing.expect(root.size().hasPointers());
    try testing.expect(root.size().matchesDataWords(0));
    try testing.expect(root.size().matchesPointerCount(2));
    try testing.expectEqual(@as(u16, 0), root.size().dataWordCount());
    try testing.expectEqual(@as(u16, 2), root.size().pointerCount());
    const nums = try (try root.getPointerField(0)).initList(.two_bytes, 3);
    try testing.expectEqual(wire.ElementSize.two_bytes, nums.elementSize());
    try nums.setUInt16(0, 10);
    try nums.setUInt16(1, 20);
    try nums.setUInt16(2, 30);

    const people = try (try root.getPointerField(1)).initStructList(2, .{ .data_words = 1, .pointer_count = 1 });
    try testing.expectEqual(wire.ElementSize.composite, people.elementSize());
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, people.structElementSize());
    try testing.expectEqual(@as(usize, 2), people.structElementSize().totalWords());
    const p0 = try people.getStructElement(0);
    try p0.setUInt32(0, 1, 0);
    try p0.setText(0, "a");
    const p1 = try people.getStructElement(1);
    try p1.setUInt32(0, 2, 0);
    try p1.setText(0, "bb");

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const r = try reader.getRoot();
    try testing.expectEqual(wire.StructSize{ .data_words = 0, .pointer_count = 2 }, r.size());
    const read_nums = try r.getPointerField(0).getList(.two_bytes);
    try testing.expectEqual(@as(usize, 3), read_nums.len());
    try testing.expectEqual(wire.ElementSize.two_bytes, read_nums.elementSize());
    try testing.expectEqual(@as(u16, 20), read_nums.getUInt16(1));
    const nums_prefix = try read_nums.slice(0, 2);
    try testing.expectEqual(@as(usize, 2), nums_prefix.len());
    try testing.expectEqual(@as(u16, 10), nums_prefix.getUInt16(0));
    try testing.expectEqual(@as(u16, 20), nums_prefix.getUInt16(1));
    const nums_unaligned = try read_nums.slice(1, 2);
    try testing.expectEqual(@as(usize, 2), nums_unaligned.len());
    try testing.expectEqual(@as(u16, 20), nums_unaligned.getUInt16(0));
    try testing.expectEqual(@as(u16, 30), nums_unaligned.getUInt16(1));
    try testing.expectEqual(@as(usize, 4), nums_unaligned.bytes().len);
    try testing.expectEqual(@as(u8, 20), nums_unaligned.bytes()[0]);
    try testing.expectError(error.PointerOutOfBounds, read_nums.slice(2, 2));

    const read_people = try r.getPointerField(1).getList(.composite);
    try testing.expectEqual(@as(usize, 2), read_people.len());
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, read_people.structElementSize());
    const read_p1 = try read_people.getStructElement(1);
    try testing.expectEqual(@as(u32, 2), read_p1.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "bb", try read_p1.getPointerField(0).getText());
    const second_person = try read_people.slice(1, 1);
    try testing.expectEqual(@as(usize, 1), second_person.len());
    try testing.expectEqual(@as(u32, 2), (try second_person.getStructElement(0)).getUInt32(0, 0));

    const root_size = try r.totalSize();
    try testing.expectEqual(@as(usize, 10), root_size.word_count);
    try testing.expectEqual(@as(usize, 0), root_size.cap_count);
    const nums_size = try read_nums.totalSize();
    try testing.expectEqual(@as(usize, 1), nums_size.word_count);
    try testing.expectEqual(@as(usize, 0), nums_size.cap_count);
    const people_size = try read_people.totalSize();
    try testing.expectEqual(@as(usize, 7), people_size.word_count);
    try testing.expectEqual(@as(usize, 0), people_size.cap_count);

    var message_reader = MessageReader.init(try builder.segmentsConst(), .{});
    const reader_size = try message_reader.totalSize();
    try testing.expectEqual(@as(usize, 10), reader_size.word_count);
    try testing.expectEqual(@as(usize, 0), reader_size.cap_count);
    const builder_size = try builder.totalSize();
    try testing.expectEqual(@as(usize, 10), builder_size.word_count);
    try testing.expectEqual(@as(usize, 0), builder_size.cap_count);

    const nums_builder_tail = try nums.slice(0, 2);
    try nums_builder_tail.setUInt16(1, 44);
    try testing.expectEqual(@as(u16, 44), try nums.getUInt16(1));
    const nums_builder_copy = try nums.slice(1, 2);
    try testing.expectEqual(@as(u16, 44), try nums_builder_copy.getUInt16(0));
    try nums_builder_copy.setUInt16(0, 55);
    try testing.expectEqual(@as(u16, 44), try nums.getUInt16(1));
}

test "primitive lists expose raw bytes" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const values = try builder.initRootList(.four_bytes, 2);
    try values.setUInt32(0, 0x11223344);
    try values.setUInt32(1, 0x55667788);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x44, 0x33, 0x22, 0x11, 0x88, 0x77, 0x66, 0x55 }, try values.rawPrimitiveBytes());

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_values = try reader.getRootList(.four_bytes);
    try testing.expectEqualSlices(u8, try values.rawPrimitiveBytes(), try read_values.rawPrimitiveBytes());

    const text = try builder.initRootList(.pointer, 1);
    try testing.expectError(error.IncompatibleListShape, text.rawPrimitiveBytes());
    var pointer_reader = MessageReader.init(try builder.segmentsConst(), .{});
    try testing.expectError(error.IncompatibleListShape, (try pointer_reader.getRootList(.pointer)).rawPrimitiveBytes());
}

test "pointer lists hold nested text values" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const names = try (try root.getPointerField(0)).initList(.pointer, 3);
    try (try names.getPointerElement(0)).setText("alice");
    try (try names.getPointerElement(1)).setText("bob");
    try (try names.getPointerElement(2)).setText("carol");

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    const read_names = try read_root.getPointerField(0).getList(.pointer);
    try testing.expectEqual(@as(usize, 3), read_names.len());
    try testing.expectEqualSlices(u8, "alice", try (try read_names.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, "bob", try (try read_names.getPointerElement(1)).getText());
    try testing.expectEqualSlices(u8, "carol", try (try read_names.getPointerElement(2)).getText());
}

test "root pointer APIs support non-struct roots" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const nums = try builder.initRootList(.two_bytes, 2);
    try nums.setUInt16(0, 111);
    try nums.setUInt16(1, 222);
    const builder_root_list = try builder.getRootList(.two_bytes);
    try testing.expectEqual(@as(u16, 222), try builder_root_list.getUInt16(1));
    const bools = try (try builder.getRootPointer()).initList(.bit, 5);
    try bools.setBool(0, true);
    try bools.setBool(1, false);
    try bools.setBool(2, true);
    try bools.setBool(3, true);
    try bools.setBool(4, false);
    const bool_tail = try bools.slice(1, 3);
    try testing.expectEqual(@as(usize, 3), bool_tail.len());
    try testing.expectEqual(false, try bool_tail.getBool(0));
    try testing.expectEqual(true, try bool_tail.getBool(1));
    try testing.expectEqual(true, try bool_tail.getBool(2));
    var bool_reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_bools = try bool_reader.getRootList(.bit);
    const read_bool_tail = try read_bools.slice(1, 3);
    try testing.expectEqual(false, read_bool_tail.getBool(0));
    try testing.expectEqual(true, read_bool_tail.getBool(1));
    try testing.expectEqual(true, read_bool_tail.getBool(2));
    try testing.expectEqual(@as(usize, 0), read_bool_tail.bytes().len);
    _ = try (try builder.getRootPointer()).initList(.two_bytes, 2);
    const nums_reset = try builder.getRootList(.two_bytes);
    try nums_reset.setUInt16(0, 111);
    try nums_reset.setUInt16(1, 222);
    const root_ptr_builder = try builder.getRootPointer();
    try testing.expect(!root_ptr_builder.isNull());
    try testing.expectEqual(wire.PointerType.list, (try builder.getRootPointerKind()).?);
    try testing.expectEqual(wire.PointerType.list, wire.pointerType(try builder.getRootRawPointer()));
    try testing.expectEqual(wire.ElementSize.two_bytes, (try builder.getRootDecodedPointer()).?.list.element_size);
    const root_ptr_builder_size = try root_ptr_builder.totalSize();
    try testing.expectEqual(@as(usize, 1), root_ptr_builder_size.word_count);
    try testing.expectEqual(@as(usize, 0), root_ptr_builder_size.cap_count);
    const root_ptr_builder_size_direct = try builder.getRootPointerTotalSize();
    try testing.expectEqual(@as(usize, 1), root_ptr_builder_size_direct.word_count);
    var builder_view_reader = MessageReader.init(try builder.segmentsConst(), .{});
    const root_ptr_builder_view = root_ptr_builder.asReader(&builder_view_reader);
    try testing.expectEqual(wire.PointerType.list, (try root_ptr_builder_view.pointerType()).?);
    const builder_view_nums = try root_ptr_builder_view.getList(.two_bytes);
    try testing.expectEqual(@as(u16, 222), builder_view_nums.getUInt16(1));

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const root_ptr = try reader.getRootPointer();
    try testing.expectEqual(wire.PointerType.list, (try root_ptr.pointerType()).?);
    try testing.expectEqual(wire.PointerType.list, (try reader.getRootPointerKind()).?);
    try testing.expectEqual(wire.PointerType.list, wire.pointerType(try reader.getRootRawPointer()));
    const decoded_root = (try root_ptr.decode()).?.list;
    try testing.expectEqual(wire.ElementSize.two_bytes, decoded_root.element_size);
    try testing.expectEqual(@as(u29, 2), decoded_root.element_count_or_words);
    try testing.expectEqual(wire.ElementSize.two_bytes, (try reader.getRootDecodedPointer()).?.list.element_size);
    const decoded_builder_root = (try (try builder.getRootPointer()).decode()).?.list;
    try testing.expectEqual(@as(u29, 2), decoded_builder_root.element_count_or_words);
    const root_ptr_size = try root_ptr.totalSize();
    try testing.expectEqual(@as(usize, 1), root_ptr_size.word_count);
    try testing.expectEqual(@as(usize, 0), root_ptr_size.cap_count);
    const root_ptr_size_direct = try reader.getRootPointerTotalSize();
    try testing.expectEqual(@as(usize, 1), root_ptr_size_direct.word_count);
    try testing.expectEqual(wire.PointerType.list, (try builder.getRootPointer()).pointerType().?);
    const direct_read_nums = try reader.getRootList(.two_bytes);
    try testing.expectEqual(@as(u16, 222), direct_read_nums.getUInt16(1));
    const read_nums = try root_ptr.getList(.two_bytes);
    try testing.expectEqual(@as(u16, 111), read_nums.getUInt16(0));
    try testing.expectEqual(@as(u16, 222), read_nums.getUInt16(1));
    try testing.expectError(error.InvalidPointerKind, reader.getRoot());

    var copied = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer copied.deinit();
    try (try copied.getRootPointer()).copyFrom(root_ptr);
    var copied_reader = MessageReader.init(try copied.segmentsConst(), .{});
    const copied_nums = try (try copied_reader.getRootPointer()).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 222), copied_nums.getUInt16(1));

    (try copied.getRootPointer()).clear();
    try testing.expect((try copied.getRootPointer()).pointerType() == null);
    var cleared_reader = MessageReader.init(try copied.segmentsConst(), .{});
    try testing.expect((try (try cleared_reader.getRootPointer()).pointerType()) == null);
}

test "builders can clear pointer fields and elements" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    try root.setText(0, "clear me");
    try root.clearPointer(0);

    const names = try (try root.getPointerField(1)).initList(.pointer, 2);
    try (try names.getPointerElement(0)).setText("keep");
    try (try names.getPointerElement(1)).setText("drop");
    try names.clearPointerElement(1);

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expect(read_root.getPointerField(0).isNull());
    const read_names = try read_root.getPointerField(1).getList(.pointer);
    try testing.expectEqualSlices(u8, "keep", try (try read_names.getPointerElement(0)).getText());
    try testing.expect((try read_names.getPointerElement(1)).isNull());
}

test "builders can clear struct list elements" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const people = try builder.initRootStructList(1, .{ .data_words = 1, .pointer_count = 1 });
    const person = try people.getStructElement(0);
    try person.setUInt32(0, 123, 42);
    try person.setText(0, "drop struct element");
    try people.clearStructElement(0);
    try testing.expectError(error.PointerOutOfBounds, people.clearStructElement(1));

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_people = try reader.getRootList(.composite);
    const read_person = try read_people.getStructElement(0);
    try testing.expectEqual(@as(u32, 42), read_person.getUInt32(0, 42));
    try testing.expect(read_person.getPointerField(0).isNull());
    try testing.expectError(error.NullPointer, read_person.getPointerField(0).getText());
}

test "builders can clear arbitrary list elements" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 4 });

    const ints = try (try root.getPointerField(0)).initList(.four_bytes, 2);
    try ints.setUInt32(0, 11);
    try ints.setUInt32(1, 22);
    try ints.clearElements(0, 2);
    try testing.expectEqual(@as(u32, 0), try ints.getUInt32(0));
    try testing.expectEqual(@as(u32, 0), try ints.getUInt32(1));
    try testing.expectError(error.PointerOutOfBounds, ints.clearElements(1, 2));

    const bits = try (try root.getPointerField(1)).initList(.bit, 2);
    try bits.setBool(0, true);
    try bits.setBool(1, true);
    try bits.clearElements(0, 1);
    try testing.expectEqual(false, try bits.getBool(0));
    try testing.expectEqual(true, try bits.getBool(1));

    const pointers = try (try root.getPointerField(2)).initList(.pointer, 1);
    try (try pointers.getPointerElement(0)).setText("drop");
    try pointers.clearElements(0, 1);

    const structs = try (try root.getPointerField(3)).initStructList(1, .{ .data_words = 1, .pointer_count = 1 });
    const item = try structs.getStructElement(0);
    try item.setUInt16(0, 77, 0);
    try item.setText(0, "drop struct");
    try structs.clearElements(0, 1);
    try testing.expectError(error.PointerOutOfBounds, structs.clearElement(1));

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 0), (try read_root.getPointerField(0).getList(.four_bytes)).getUInt32(1));
    try testing.expect(!(try read_root.getPointerField(1).getList(.bit)).getBool(0));
    try testing.expect((try (try read_root.getPointerField(2).getList(.pointer)).getPointerElement(0)).isNull());
    const read_item = try (try read_root.getPointerField(3).getList(.composite)).getStructElement(0);
    try testing.expectEqual(@as(u16, 0), read_item.getUInt16(0, 0));
    try testing.expect(read_item.getPointerField(0).isNull());
}

test "builders can copy individual list elements from readers" {
    const testing = std.testing;

    var source_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer source_builder.deinit();
    const source_root = try source_builder.initRoot(.{ .data_words = 0, .pointer_count = 4 });
    const source_ints = try (try source_root.getPointerField(0)).initList(.four_bytes, 2);
    try source_ints.setUInt32(0, 100);
    try source_ints.setUInt32(1, 200);
    const source_bits = try (try source_root.getPointerField(1)).initList(.bit, 2);
    try source_bits.setBool(0, true);
    try source_bits.setBool(1, false);
    const source_names = try (try source_root.getPointerField(2)).initList(.pointer, 2);
    try (try source_names.getPointerElement(0)).setText("zero");
    try (try source_names.getPointerElement(1)).setText("one");
    const source_people = try (try source_root.getPointerField(3)).initStructList(2, .{ .data_words = 1, .pointer_count = 1 });
    const source_person0 = try source_people.getStructElement(0);
    try source_person0.setUInt32(0, 123, 0);
    try source_person0.setText(0, "range element");
    const source_person = try source_people.getStructElement(1);
    try source_person.setUInt32(0, 321, 0);
    try source_person.setText(0, "copied element");

    var source_reader = MessageReader.init(try source_builder.segmentsConst(), .{});
    const read_source_root = try source_reader.getRoot();

    var target_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer target_builder.deinit();
    const target_root = try target_builder.initRoot(.{ .data_words = 0, .pointer_count = 4 });
    const target_ints = try (try target_root.getPointerField(0)).initList(.four_bytes, 4);
    const target_bits = try (try target_root.getPointerField(1)).initList(.bit, 2);
    const target_names = try (try target_root.getPointerField(2)).initList(.pointer, 4);
    const target_people = try (try target_root.getPointerField(3)).initStructList(4, .{ .data_words = 1, .pointer_count = 1 });

    const read_source_ints = try read_source_root.getPointerField(0).getList(.four_bytes);
    const read_source_names = try read_source_root.getPointerField(2).getList(.pointer);
    try target_ints.copyElementFrom(0, read_source_ints, 1);
    try target_ints.copyElementFromBuilder(1, source_ints, 0);
    try target_ints.copyElementsFrom(2, read_source_ints, 0, 2);
    try target_bits.copyElementFrom(1, try read_source_root.getPointerField(1).getList(.bit), 0);
    try target_names.copyElementFrom(0, read_source_names, 1);
    try target_names.copyElementFromBuilder(1, source_names, 0);
    try target_names.copyElementsFrom(2, read_source_names, 0, 2);
    try target_people.copyElementFrom(0, try read_source_root.getPointerField(3).getList(.composite), 1);
    try target_people.copyElementFromBuilder(1, source_people, 1);
    try target_people.copyElementsFromBuilder(2, source_people, 0, 2);
    try testing.expectError(error.IncompatibleListShape, target_ints.copyElementFrom(1, try read_source_root.getPointerField(1).getList(.bit), 0));
    try testing.expectError(error.PointerOutOfBounds, target_ints.copyElementFrom(4, read_source_ints, 0));
    try testing.expectError(error.PointerOutOfBounds, target_ints.copyElementsFrom(3, read_source_ints, 0, 2));

    var target_reader = MessageReader.init(try target_builder.segmentsConst(), .{});
    const read_target_root = try target_reader.getRoot();
    const read_target_ints = try read_target_root.getPointerField(0).getList(.four_bytes);
    try testing.expectEqual(@as(u32, 200), read_target_ints.getUInt32(0));
    try testing.expectEqual(@as(u32, 100), read_target_ints.getUInt32(1));
    try testing.expectEqual(@as(u32, 100), read_target_ints.getUInt32(2));
    try testing.expectEqual(@as(u32, 200), read_target_ints.getUInt32(3));
    try testing.expect((try read_target_root.getPointerField(1).getList(.bit)).getBool(1));
    const read_names = try read_target_root.getPointerField(2).getList(.pointer);
    try testing.expectEqualSlices(u8, "one", try (try read_names.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, "zero", try (try read_names.getPointerElement(1)).getText());
    try testing.expectEqualSlices(u8, "zero", try (try read_names.getPointerElement(2)).getText());
    try testing.expectEqualSlices(u8, "one", try (try read_names.getPointerElement(3)).getText());
    const read_person = try (try read_target_root.getPointerField(3).getList(.composite)).getStructElement(0);
    try testing.expectEqual(@as(u32, 321), read_person.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "copied element", try read_person.getPointerField(0).getText());
    const read_person_from_builder = try (try read_target_root.getPointerField(3).getList(.composite)).getStructElement(1);
    try testing.expectEqual(@as(u32, 321), read_person_from_builder.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "copied element", try read_person_from_builder.getPointerField(0).getText());
    const read_range_person0 = try (try read_target_root.getPointerField(3).getList(.composite)).getStructElement(2);
    try testing.expectEqual(@as(u32, 123), read_range_person0.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "range element", try read_range_person0.getPointerField(0).getText());
    const read_range_person1 = try (try read_target_root.getPointerField(3).getList(.composite)).getStructElement(3);
    try testing.expectEqual(@as(u32, 321), read_range_person1.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "copied element", try read_range_person1.getPointerField(0).getText());
}

test "builders can copy overlapping primitive list ranges" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    const forward = try (try root.getPointerField(0)).initList(.four_bytes, 4);
    try forward.setUInt32(0, 1);
    try forward.setUInt32(1, 2);
    try forward.setUInt32(2, 3);
    try forward.setUInt32(3, 4);
    try forward.copyElementsFromBuilder(1, forward, 0, 3);
    try testing.expectEqual(@as(u32, 1), try forward.getUInt32(0));
    try testing.expectEqual(@as(u32, 1), try forward.getUInt32(1));
    try testing.expectEqual(@as(u32, 2), try forward.getUInt32(2));
    try testing.expectEqual(@as(u32, 3), try forward.getUInt32(3));

    const backward = try (try root.getPointerField(1)).initList(.two_bytes, 4);
    try backward.setUInt16(0, 10);
    try backward.setUInt16(1, 20);
    try backward.setUInt16(2, 30);
    try backward.setUInt16(3, 40);
    try backward.copyElementsFromBuilder(0, backward, 1, 3);
    try testing.expectEqual(@as(u16, 20), try backward.getUInt16(0));
    try testing.expectEqual(@as(u16, 30), try backward.getUInt16(1));
    try testing.expectEqual(@as(u16, 40), try backward.getUInt16(2));
    try testing.expectEqual(@as(u16, 40), try backward.getUInt16(3));
}

test "pointer builders can disown and adopt within a message" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    try root.setText(0, "move me");
    const field0 = try root.getPointerField(0);
    const field1 = try root.getPointerField(1);

    var orphan = field0.disown();
    try testing.expect(field0.isNull());
    try testing.expect(!orphan.isNull());
    try testing.expectEqual(wire.PointerType.list, orphan.pointerType().?);
    var orphan_decode_reader = MessageReader.init(try builder.segmentsConst(), .{});
    const decoded_orphan = (try orphan.decode(&orphan_decode_reader)).?.list;
    try testing.expectEqual(wire.ElementSize.byte, decoded_orphan.element_size);
    const orphan_size = try orphan.totalSize();
    try testing.expectEqual(@as(usize, 1), orphan_size.word_count);
    const orphan_text = try orphan.getList(.byte);
    try testing.expectEqual(@as(u8, 'm'), try orphan_text.getUInt8(0));
    try field1.adopt(&orphan);
    try testing.expectEqual(@as(u64, 0), orphan.raw);
    try testing.expect(field0.isNull());
    try testing.expect(!field1.isNull());

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expect(read_root.getPointerField(0).isNull());
    try testing.expectEqualSlices(u8, "move me", try read_root.getPointerField(1).getText());
}

test "pointer builders reject adopting from another message" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    try source_root.setText(0, "foreign");
    var orphan = (try source_root.getPointerField(0)).disown();

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer target.deinit();
    const target_root = try target.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    try testing.expectError(error.InvalidPointerKind, (try target_root.getPointerField(0)).adopt(&orphan));
}

test "pointer list elements can disown and adopt within a message" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const list = try (try root.getPointerField(0)).initList(.pointer, 2);
    try (try list.getPointerElement(0)).setText("first");
    try (try list.getPointerElement(1)).setText("second");

    var orphan = try list.disownPointerElement(0);
    try testing.expect((try list.getPointerElement(0)).isNull());
    try list.adoptPointerElement(1, &orphan);
    try testing.expectEqual(@as(u64, 0), orphan.raw);

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_list = try (try reader.getRoot()).getPointerField(0).getList(.pointer);
    try testing.expect((try read_list.getPointerElement(0)).isNull());
    try testing.expectEqualSlices(u8, "first", try (try read_list.getPointerElement(1)).getText());
}

test "message builder allocates new orphan structs and lists" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    var struct_orphan = try builder.newOrphanStruct(.{ .data_words = 1, .pointer_count = 1 });
    const orphan_struct = try struct_orphan.getStruct();
    try orphan_struct.setUInt32(0, 4242, 0);
    try orphan_struct.setText(0, "new orphan");
    const struct_size = try struct_orphan.totalSize();
    try testing.expectEqual(@as(usize, 4), struct_size.word_count);

    try (try builder.getRootPointer()).adopt(&struct_orphan);
    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 4242), root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "new orphan", try root.getPointerField(0).getText());

    var list_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer list_builder.deinit();
    var list_orphan = try list_builder.newOrphanList(.two_bytes, 2);
    const orphan_list = try list_orphan.getList(.two_bytes);
    try orphan_list.setUInt16(0, 77);
    try orphan_list.setUInt16(1, 88);

    try (try list_builder.getRootPointer()).adopt(&list_orphan);
    var list_reader = MessageReader.init(try list_builder.segmentsConst(), .{});
    const root_list = try (try list_reader.getRootPointer()).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 77), root_list.getUInt16(0));
    try testing.expectEqual(@as(u16, 88), root_list.getUInt16(1));

    var dropped = try list_builder.newOrphanList(.byte, 1);
    dropped.release();
    try testing.expect(dropped.isNull());
    try testing.expectError(error.NullPointer, dropped.totalSize());
}

test "message builder allocates scalar orphans" {
    const testing = std.testing;

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer text_builder.deinit();
    var text_orphan = try text_builder.newOrphanText("allocated text");
    try testing.expectEqualSlices(u8, "allocated text", try text_orphan.getText());
    try (try text_builder.getRootPointer()).adopt(&text_orphan);
    var text_reader = MessageReader.init(try text_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "allocated text", try text_reader.getRootText());

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer data_builder.deinit();
    var data_orphan = try data_builder.newOrphanData(&[_]u8{ 1, 3, 3, 7 });
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 3, 3, 7 }, try data_orphan.getData());
    try (try data_builder.getRootPointer()).adopt(&data_orphan);
    var data_reader = MessageReader.init(try data_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 3, 3, 7 }, try data_reader.getRootData());

    var cap_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer cap_builder.deinit();
    var cap_orphan = try cap_builder.newOrphanCapability(9001);
    try testing.expectEqual(@as(u32, 9001), try cap_orphan.getCapabilityIndex());
    try (try cap_builder.getRootPointer()).adopt(&cap_orphan);
    var cap_reader = MessageReader.init(try cap_builder.segmentsConst(), .{});
    try testing.expectEqual(@as(u32, 9001), try cap_reader.getRootCapability());
}

test "message builder allocates orphan copies from readers" {
    const testing = std.testing;

    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try source_root.setUInt32(0, 707, 0);
    try source_root.setText(0, "copy orphan");
    var source_reader = MessageReader.init(try source.segmentsConst(), .{});
    const source_struct = try source_reader.getRoot();

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer target.deinit();
    var struct_orphan = try target.newOrphanCopyStruct(source_struct);
    try (try target.getRootPointer()).adopt(&struct_orphan);
    var target_reader = MessageReader.init(try target.segmentsConst(), .{});
    const target_root = try target_reader.getRoot();
    try testing.expectEqual(@as(u32, 707), target_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "copy orphan", try target_root.getPointerField(0).getText());

    var source_list_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer source_list_builder.deinit();
    const source_list = try source_list_builder.initRootList(.four_bytes, 2);
    try source_list.setUInt32(0, 11);
    try source_list.setUInt32(1, 22);
    var source_list_reader = MessageReader.init(try source_list_builder.segmentsConst(), .{});
    const source_list_view = try (try source_list_reader.getRootPointer()).getList(.four_bytes);

    var target_list_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer target_list_builder.deinit();
    var list_orphan = try target_list_builder.newOrphanCopyList(source_list_view);
    try (try target_list_builder.getRootPointer()).adopt(&list_orphan);
    var target_list_reader = MessageReader.init(try target_list_builder.segmentsConst(), .{});
    const target_list = try (try target_list_reader.getRootPointer()).getList(.four_bytes);
    try testing.expectEqual(@as(u32, 11), target_list.getUInt32(0));
    try testing.expectEqual(@as(u32, 22), target_list.getUInt32(1));

    var bool_source_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer bool_source_builder.deinit();
    const bool_source_list = try bool_source_builder.initRootList(.bit, 5);
    try bool_source_list.setBool(0, true);
    try bool_source_list.setBool(1, false);
    try bool_source_list.setBool(2, true);
    try bool_source_list.setBool(3, true);
    try bool_source_list.setBool(4, false);
    var bool_source_reader = MessageReader.init(try bool_source_builder.segmentsConst(), .{});
    const bool_source_view = try (try bool_source_reader.getRootPointer()).getList(.bit);
    var bool_target_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer bool_target_builder.deinit();
    var bool_orphan = try bool_target_builder.newOrphanCopyList(bool_source_view);
    try (try bool_target_builder.getRootPointer()).adopt(&bool_orphan);
    var bool_target_reader = MessageReader.init(try bool_target_builder.segmentsConst(), .{});
    const bool_target_list = try (try bool_target_reader.getRootPointer()).getList(.bit);
    try testing.expectEqual(true, bool_target_list.getBool(0));
    try testing.expectEqual(false, bool_target_list.getBool(1));
    try testing.expectEqual(true, bool_target_list.getBool(2));
    try testing.expectEqual(true, bool_target_list.getBool(3));
    try testing.expectEqual(false, bool_target_list.getBool(4));

    var pointer_copy_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer pointer_copy_builder.deinit();
    var pointer_orphan = try pointer_copy_builder.newOrphanCopyPointer(source_struct.getPointerField(0));
    try (try pointer_copy_builder.getRootPointer()).adopt(&pointer_orphan);
    var pointer_copy_reader = MessageReader.init(try pointer_copy_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "copy orphan", try (try pointer_copy_reader.getRootPointer()).getText());
}

test "orphanage facade allocates and copies orphans" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root_for_orphanage = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const orphanage = root_for_orphanage.orphanage();

    var struct_orphan = try orphanage.newStruct(.{ .data_words = 1, .pointer_count = 1 });
    const struct_builder = try struct_orphan.getStruct();
    try struct_builder.setUInt32(0, 8080, 0);
    try struct_builder.setText(0, "orphanage");
    try (try root_for_orphanage.getPointerField(0)).adopt(&struct_orphan);

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const root = try (try reader.getRoot()).getPointerField(0).getStruct(null);
    try testing.expectEqual(@as(u32, 8080), root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "orphanage", try root.getPointerField(0).getText());

    var copy_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer copy_builder.deinit();
    const copy_orphanage = Orphanage.init(&copy_builder);
    var copied = try copy_orphanage.newCopyStruct(root);
    try (try copy_builder.getRootPointer()).adopt(&copied);
    var copy_reader = MessageReader.init(try copy_builder.segmentsConst(), .{});
    const copy_root = try copy_reader.getRoot();
    try testing.expectEqual(@as(u32, 8080), copy_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "orphanage", try copy_root.getPointerField(0).getText());

    var list_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer list_builder.deinit();
    var list_orphan = try Orphanage.init(&list_builder).newList(.two_bytes, 1);
    const list = try list_orphan.getList(.two_bytes);
    try list.setUInt16(0, 9090);
    try (try list_builder.getRootPointer()).adopt(&list_orphan);
    var list_reader = MessageReader.init(try list_builder.segmentsConst(), .{});
    const root_list = try (try list_reader.getRootPointer()).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 9090), root_list.getUInt16(0));
}

test "schema-agnostic validation returns reachable layout stats" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const names = try (try root.getPointerField(0)).initList(.pointer, 2);
    try (try names.getPointerElement(0)).setText("a");
    try (try names.getPointerElement(1)).setText("bb");
    const pointer_section = root.pointerSectionAsList();
    try testing.expectEqual(@as(usize, 1), pointer_section.len());
    const names_from_builder_section = try (try pointer_section.getPointerElement(0)).getList(.pointer);
    const first_name_from_section = try names_from_builder_section.getPointerElement(0);
    try testing.expectEqualSlices(u8, "a", try first_name_from_section.getText());

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    const read_pointer_section = read_root.pointerSectionAsList();
    try testing.expectEqual(@as(usize, 1), read_pointer_section.len());
    const read_names_from_section = try (try read_pointer_section.getPointerElement(0)).getList(.pointer);
    try testing.expectEqualSlices(u8, "bb", try (try read_names_from_section.getPointerElement(1)).getText());

    var stats_reader = MessageReader.init(try builder.segmentsConst(), .{});
    const stats = try stats_reader.validate();
    try testing.expectEqual(@as(usize, 4), stats.pointer_slots); // root, root field, two list elements.
    try testing.expectEqual(@as(usize, 4), stats.non_null_pointers);
    try testing.expectEqual(@as(usize, 1), stats.structs);
    try testing.expectEqual(@as(usize, 3), stats.lists); // pointer list plus two text byte lists.
    try testing.expectEqual(@as(usize, 2), stats.data_words);
    try testing.expectEqual(@as(usize, 3), stats.pointer_words);
    try testing.expectEqual(@as(usize, 5), stats.total_words);
}

test "struct data sections expose raw bytes" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 0 });
    try root.setUInt32(0, 0x12345678, 0);
    const data = root.dataSectionBytes();
    try testing.expectEqual(@as(usize, 8), data.len);
    try testing.expectEqual(@as(u8, 0x78), data[0]);
    data[4] = 0xaa;

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_data = (try reader.getRoot()).dataSectionBytes();
    try testing.expectEqual(@as(u8, 0x78), read_data[0]);
    try testing.expectEqual(@as(u8, 0xaa), read_data[4]);
}

test "validation reports traversal budget and bounds failures" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    try root.setText(0, "budget");

    var limited = MessageReader.init(try builder.segmentsConst(), .{ .traversal_limit_words = 1 });
    try testing.expectError(error.TraversalLimitExceeded, limited.validate());

    var bad_words = [_]wire.Word{try wire.encodeStruct(10, 1, 0)};
    const bad_segments = [_]serialize.ConstSegment{std.mem.sliceAsBytes(&bad_words)};
    var invalid = MessageReader.init(&bad_segments, .{});
    try testing.expectError(error.PointerOutOfBounds, invalid.validate());
}

test "message builder deep-copies from a reader" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer source.deinit();

    const root = try source.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try root.setUInt32(0, 77, 0);
    const names = try (try root.getPointerField(0)).initList(.pointer, 2);
    try (try names.getPointerElement(0)).setText("left");
    try (try names.getPointerElement(1)).setText("right");
    const people = try (try root.getPointerField(1)).initStructList(1, .{ .data_words = 1, .pointer_count = 1 });
    const person = try people.getStructElement(0);
    try person.setUInt32(0, 123, 0);
    try person.setText(0, "nested");

    var source_reader = MessageReader.init(try source.segmentsConst(), .{});
    var copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2, .next_segment_min_words = 2 });
    defer copy.deinit();
    _ = try copy.copyRootFrom(&source_reader);

    var copy_reader = MessageReader.init(try copy.segmentsConst(), .{});
    const copied_root = try copy_reader.getRoot();
    try testing.expectEqual(@as(u32, 77), copied_root.getUInt32(0, 0));
    const copied_names = try copied_root.getPointerField(0).getList(.pointer);
    try testing.expectEqualSlices(u8, "left", try (try copied_names.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, "right", try (try copied_names.getPointerElement(1)).getText());
    const copied_people = try copied_root.getPointerField(1).getList(.composite);
    const copied_person = try copied_people.getStructElement(0);
    try testing.expectEqual(@as(u32, 123), copied_person.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "nested", try copied_person.getPointerField(0).getText());

    var validating = MessageReader.init(try copy.segmentsConst(), .{});
    _ = try validating.validate();
}

test "message builder copies arbitrary root pointers" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer source.deinit();

    const root_list = try source.initRootList(.pointer, 2);
    try (try root_list.getPointerElement(0)).setText("root pointer copy");
    try (try root_list.getPointerElement(1)).setData(&[_]u8{ 1, 2, 3 });

    var source_reader = MessageReader.init(try source.segmentsConst(), .{});
    const source_root = try source_reader.getRootPointer();

    var copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer copy.deinit();
    const copied_root_ptr = try copy.copyRootPointerFrom(source_root);
    try testing.expectEqual(wire.ElementSize.pointer, (try copied_root_ptr.decode()).?.list.element_size);

    var copy_reader = MessageReader.init(try copy.segmentsConst(), .{});
    const copied_list = try (try copy_reader.getRootPointer()).getList(.pointer);
    try testing.expectEqualSlices(u8, "root pointer copy", try (try copied_list.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, try (try copied_list.getPointerElement(1)).getData());

    var canonical_copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer canonical_copy.deinit();
    const canonical_root_ptr = try canonical_copy.copyRootPointerCanonicalFrom(source_root);
    try testing.expectEqual(wire.ElementSize.pointer, (try canonical_root_ptr.decode()).?.list.element_size);
    var canonical_reader = MessageReader.init(try canonical_copy.segmentsConst(), .{});
    const canonical_list = try (try canonical_reader.getRootPointer()).getList(.pointer);
    try testing.expectEqualSlices(u8, "root pointer copy", try (try canonical_list.getPointerElement(0)).getText());

    var builder_copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer builder_copy.deinit();
    _ = try source.copyRootTo(&builder_copy);
    var builder_copy_reader = MessageReader.init(try builder_copy.segmentsConst(), .{});
    const builder_copy_list = try (try builder_copy_reader.getRootPointer()).getList(.pointer);
    try testing.expectEqualSlices(u8, "root pointer copy", try (try builder_copy_list.getPointerElement(0)).getText());

    var builder_canonical_copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer builder_canonical_copy.deinit();
    _ = try source.copyRootCanonicalTo(&builder_canonical_copy);
    var builder_canonical_reader = MessageReader.init(try builder_canonical_copy.segmentsConst(), .{});
    const builder_canonical_list = try (try builder_canonical_reader.getRootPointer()).getList(.pointer);
    try testing.expectEqualSlices(u8, "root pointer copy", try (try builder_canonical_list.getPointerElement(0)).getText());
}

test "message builder and reader expose scalar root pointer helpers" {
    const testing = std.testing;

    var empty_text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer empty_text_builder.deinit();
    try testing.expectEqualSlices(u8, "default root", try empty_text_builder.getRootTextDefault("default root"));
    var empty_text_reader = MessageReader.init(try empty_text_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "default root", try empty_text_reader.getRootTextDefault("default root"));

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer text_builder.deinit();
    try text_builder.setRootText("root text");
    try testing.expectEqualSlices(u8, "root text", try text_builder.getRootText());
    try testing.expectEqualSlices(u8, "root text", try text_builder.getRootTextDefault("ignored"));
    var text_reader = MessageReader.init(try text_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "root text", try text_reader.getRootText());
    try testing.expectEqualSlices(u8, "root text", try text_reader.getRootTextDefault("ignored"));
    try testing.expectError(error.TextContainsInteriorNul, empty_text_reader.getRootTextDefault("bad\x00default"));

    var empty_data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer empty_data_builder.deinit();
    try testing.expectEqualSlices(u8, &[_]u8{ 9, 9 }, try empty_data_builder.getRootDataDefault(&[_]u8{ 9, 9 }));
    var empty_data_reader = MessageReader.init(try empty_data_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, &[_]u8{ 9, 9 }, try empty_data_reader.getRootDataDefault(&[_]u8{ 9, 9 }));

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer data_builder.deinit();
    try data_builder.setRootData(&[_]u8{ 3, 1, 4 });
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_builder.getRootData());
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_builder.getRootDataDefault(&[_]u8{ 9, 9 }));
    var data_reader = MessageReader.init(try data_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_reader.getRootData());
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_reader.getRootDataDefault(&[_]u8{ 9, 9 }));

    var cap_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer cap_builder.deinit();
    try cap_builder.setRootCapability(4242);
    try testing.expectEqual(@as(u32, 4242), try cap_builder.getRootCapability());
    var cap_reader = MessageReader.init(try cap_builder.segmentsConst(), .{});
    try testing.expectEqual(@as(u32, 4242), try cap_reader.getRootCapability());
}

test "message builder can disown and adopt root pointers" {
    const testing = std.testing;

    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    try builder.setRootText("root orphan");

    var orphan = try builder.disownRoot();
    try testing.expectEqual(wire.PointerType.list, orphan.pointerType().?);
    try testing.expect((try builder.getRootPointer()).isNull());
    const orphan_bytes = (try orphan.getList(.byte)).bytes();
    try testing.expectEqualSlices(u8, "root orphan", orphan_bytes[0.."root orphan".len]);

    _ = try builder.adoptRoot(&orphan);
    try testing.expect(orphan.isNull());
    try testing.expectEqualSlices(u8, "root orphan", try builder.getRootText());

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "root orphan", try reader.getRootText());
}

test "orphan scalar accessors read moved pointers" {
    const testing = std.testing;

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer text_builder.deinit();
    try text_builder.setRootText("orphan text");
    var text_orphan = try text_builder.disownRoot();
    try testing.expectEqualSlices(u8, "orphan text", try text_orphan.getText());

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer data_builder.deinit();
    try data_builder.setRootData(&[_]u8{ 9, 8, 7 });
    var data_orphan = try data_builder.disownRoot();
    try testing.expectEqualSlices(u8, &[_]u8{ 9, 8, 7 }, try data_orphan.getData());

    var cap_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer cap_builder.deinit();
    try cap_builder.setRootCapability(5150);
    var cap_orphan = try cap_builder.disownRoot();
    try testing.expectEqual(@as(u32, 5150), try cap_orphan.getCapabilityIndex());
}

test "message builder can clear root pointers" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 4 });
    defer builder.deinit();

    try testing.expect(try builder.isRootNull());
    try builder.setRootText("clear me");
    try testing.expect(!(try builder.isRootNull()));
    try testing.expectEqual(wire.PointerType.list, (try builder.getRootPointerKind()).?);
    try builder.clearRoot();
    try testing.expect((try builder.getRootPointer()).isNull());
    try testing.expect(try builder.isRootNull());
    try testing.expectEqual(@as(?wire.PointerType, null), try builder.getRootPointerKind());

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    try testing.expect(try reader.isRootNull());
    try testing.expectEqual(@as(?wire.PointerType, null), try reader.getRootPointerKind());
    try testing.expectError(error.NullPointer, reader.getRootText());
}

test "struct builder copyFromReader safely handles self-copy" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 2026, 0);
    try root.setText(0, "self");

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    try root.copyFromReader(try reader.getRoot());

    var verify = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try verify.getRoot();
    try testing.expectEqual(@as(u32, 2026), read_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "self", try read_root.getPointerField(0).getText());
}

test "struct and pointer builders copy from builders" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try source_root.setUInt32(0, 77, 0);
    try source_root.setText(0, "builder copy");

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer target.deinit();
    const target_root = try target.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try target_root.copyFromBuilder(source_root);
    try (try target_root.getPointerField(1)).copyStructFromBuilder(source_root);

    var reader = MessageReader.init(try target.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 77), read_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "builder copy", try read_root.getPointerField(0).getText());
    const copied = try read_root.getPointerField(1).getStruct(null);
    try testing.expectEqual(@as(u32, 77), copied.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "builder copy", try copied.getPointerField(0).getText());
}

test "pointer builders copy lists from builders" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 0, .pointer_count = 3 });
    const source_numbers = try (try source_root.getPointerField(0)).initList(.four_bytes, 3);
    try source_numbers.setUInt32(0, 11);
    try source_numbers.setUInt32(1, 22);
    try source_numbers.setUInt32(2, 33);
    const source_texts = try (try source_root.getPointerField(1)).initList(.pointer, 2);
    try (try source_texts.getPointerElement(0)).setText("alpha");
    try (try source_texts.getPointerElement(1)).setText("beta");
    const source_structs = try (try source_root.getPointerField(2)).initStructList(1, .{ .data_words = 1, .pointer_count = 1 });
    const source_struct = try source_structs.getStructElement(0);
    try source_struct.setUInt32(0, 44, 0);
    try source_struct.setText(0, "nested");

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer target.deinit();
    const target_root = try target.initRoot(.{ .data_words = 0, .pointer_count = 3 });
    try (try target_root.getPointerField(0)).copyListFromBuilder(source_numbers);
    try (try target_root.getPointerField(1)).copyListFromBuilder(source_texts);
    try (try target_root.getPointerField(2)).copyListFromBuilder(source_structs);

    var reader = MessageReader.init(try target.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    const numbers = try read_root.getPointerField(0).getList(.four_bytes);
    try testing.expectEqual(@as(u32, 11), numbers.getUInt32(0));
    try testing.expectEqual(@as(u32, 22), numbers.getUInt32(1));
    try testing.expectEqual(@as(u32, 33), numbers.getUInt32(2));
    const texts = try read_root.getPointerField(1).getList(.pointer);
    try testing.expectEqualSlices(u8, "alpha", try (try texts.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, "beta", try (try texts.getPointerElement(1)).getText());
    const structs = try read_root.getPointerField(2).getList(.composite);
    const read_struct = try structs.getStructElement(0);
    try testing.expectEqual(@as(u32, 44), read_struct.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "nested", try read_struct.getPointerField(0).getText());
}

test "signed integer and floating-point scalar accessors" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 4, .pointer_count = 5 });
    try root.setInt8(0, -5, 1);
    try root.setInt16(2, -1234, 22);
    try root.setInt32(4, -123456, 10);
    try root.setInt64(8, -1_234_567_890_123, 7);
    try root.setFloat32(16, 1.25, 2.5);
    try root.setFloat64(24, -123.5, 4.0);

    const i8s = try (try root.getPointerField(0)).initList(.byte, 2);
    try i8s.setInt8(0, -1);
    try i8s.setInt8(1, 2);

    const i16s = try (try root.getPointerField(1)).initList(.two_bytes, 2);
    try i16s.setInt16(0, -300);
    try i16s.setInt16(1, 301);

    const i32s = try (try root.getPointerField(2)).initList(.four_bytes, 2);
    try i32s.setInt32(0, -70_000);
    try i32s.setInt32(1, 70_001);

    const f32s = try (try root.getPointerField(3)).initList(.four_bytes, 2);
    try f32s.setFloat32(0, 3.5);
    try f32s.setFloat32(1, -4.25);

    const f64s = try (try root.getPointerField(4)).initList(.eight_bytes, 2);
    try f64s.setFloat64(0, 99.125);
    try f64s.setFloat64(1, -0.5);

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(i8, -5), read_root.getInt8(0, 1));
    try testing.expectEqual(@as(i16, -1234), read_root.getInt16(2, 22));
    try testing.expectEqual(@as(i32, -123456), read_root.getInt32(4, 10));
    try testing.expectEqual(@as(i64, -1_234_567_890_123), read_root.getInt64(8, 7));
    try testing.expectEqual(@as(f32, 1.25), read_root.getFloat32(16, 2.5));
    try testing.expectEqual(@as(f64, -123.5), read_root.getFloat64(24, 4.0));

    const read_i8s = try read_root.getPointerField(0).getList(.byte);
    try testing.expectEqual(@as(i8, -1), read_i8s.getInt8(0));
    try testing.expectEqual(@as(i8, 2), read_i8s.getInt8(1));

    const read_i16s = try read_root.getPointerField(1).getList(.two_bytes);
    try testing.expectEqual(@as(i16, -300), read_i16s.getInt16(0));
    try testing.expectEqual(@as(i16, 301), read_i16s.getInt16(1));

    const read_i32s = try read_root.getPointerField(2).getList(.four_bytes);
    try testing.expectEqual(@as(i32, -70_000), read_i32s.getInt32(0));
    try testing.expectEqual(@as(i32, 70_001), read_i32s.getInt32(1));

    const read_f32s = try read_root.getPointerField(3).getList(.four_bytes);
    try testing.expectEqual(@as(f32, 3.5), read_f32s.getFloat32(0));
    try testing.expectEqual(@as(f32, -4.25), read_f32s.getFloat32(1));

    const read_f64s = try read_root.getPointerField(4).getList(.eight_bytes);
    try testing.expectEqual(@as(f64, 99.125), read_f64s.getFloat64(0));
    try testing.expectEqual(@as(f64, -0.5), read_f64s.getFloat64(1));
}

test "struct builder scalar getters reflect in-progress writes" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 4, .pointer_count = 0 });
    try testing.expectEqual(@as(u32, 123), try root.getUInt32(0, 123));
    try root.setUInt32(0, 99, 123);
    try root.setBool(32, true, false);
    try root.setInt16(6, -321, 7);
    try root.setFloat64(16, 12.5, 1.5);

    try testing.expectEqual(@as(u32, 99), try root.getUInt32(0, 123));
    try testing.expectEqual(true, try root.getBool(32, false));
    try testing.expectEqual(@as(i16, -321), try root.getInt16(6, 7));
    try testing.expectEqual(@as(f64, 12.5), try root.getFloat64(16, 1.5));
    try testing.expectError(error.PointerOutOfBounds, root.getUInt64(64, 0));
}

test "single-segment normalization removes far pointers while preserving data" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2, .next_segment_min_words = 2 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try root.setUInt32(0, 4242, 0);
    try root.setText(0, "normalized");
    const names = try (try root.getPointerField(1)).initList(.pointer, 2);
    try (try names.getPointerElement(0)).setText("a");
    try (try names.getPointerElement(1)).setText("b");
    try testing.expect(builder.segments.items.len > 1);

    var source = MessageReader.init(try builder.segmentsConst(), .{});
    const normalized = try toSingleSegmentFlatBytes(testing.allocator, &source);
    defer testing.allocator.free(normalized);

    var flat = try serialize.readFlatMessage(testing.allocator, normalized);
    defer flat.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), flat.segments.len);

    var reader = MessageReader.init(flat.segments, .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 4242), read_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "normalized", try read_root.getPointerField(0).getText());
    const read_names = try read_root.getPointerField(1).getList(.pointer);
    try testing.expectEqualSlices(u8, "a", try (try read_names.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, "b", try (try read_names.getPointerElement(1)).getText());
}

test "canonical segment bytes truncate trailing zero struct sections" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 2, .pointer_count = 2 });
    try root.setUInt32(0, 99, 0);
    try root.setText(0, "kept");

    var source = MessageReader.init(try builder.segmentsConst(), .{});
    const canonical = try toCanonicalSegmentBytes(testing.allocator, &source);
    defer testing.allocator.free(canonical);

    const root_ptr = wire.decodeStruct(try wire.readWord(canonical, 0));
    try testing.expectEqual(@as(u16, 1), root_ptr.data_words);
    try testing.expectEqual(@as(u16, 1), root_ptr.pointer_count);

    const segments = [_]serialize.ConstSegment{canonical};
    var reader = MessageReader.init(&segments, .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 99), read_root.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "kept", try read_root.getPointerField(0).getText());
    try testing.expect(read_root.getPointerField(1).isNull());
}

test "canonical segment bytes truncate trailing zero struct-list sections" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const items = try (try root.getPointerField(0)).initStructList(2, .{ .data_words = 2, .pointer_count = 2 });
    const item0 = try items.getStructElement(0);
    try item0.setUInt32(0, 1, 0);
    try item0.setText(0, "a");
    const item1 = try items.getStructElement(1);
    try item1.setUInt32(0, 2, 0);
    try item1.setText(0, "b");

    var source = MessageReader.init(try builder.segmentsConst(), .{});
    const canonical = try toCanonicalSegmentBytes(testing.allocator, &source);
    defer testing.allocator.free(canonical);

    const root_struct = wire.decodeStruct(try wire.readWord(canonical, 0));
    const root_target = try wire.targetWordIndex(0, root_struct.offset_words);
    const list_ptr_index = root_target + root_struct.data_words;
    const list_ptr = try wire.decodeList(try wire.readWord(canonical, list_ptr_index));
    try testing.expectEqual(wire.ElementSize.composite, list_ptr.element_size);
    try testing.expectEqual(@as(u29, 4), list_ptr.element_count_or_words);
    const tag_index = try wire.targetWordIndex(list_ptr_index, list_ptr.offset_words);
    const tag = try wire.decodeStructListTag(try wire.readWord(canonical, tag_index));
    try testing.expectEqual(@as(usize, 2), tag.element_count);
    try testing.expectEqual(@as(u16, 1), tag.size.data_words);
    try testing.expectEqual(@as(u16, 1), tag.size.pointer_count);

    const segments = [_]serialize.ConstSegment{canonical};
    var reader = MessageReader.init(&segments, .{});
    const read_items = try (try reader.getRoot()).getPointerField(0).getList(.composite);
    const read_item1 = try read_items.getStructElement(1);
    try testing.expectEqual(@as(u32, 2), read_item1.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "b", try read_item1.getPointerField(0).getText());
}

test "capability pointers round-trip and validate" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    (try root.getPointerField(0)).setCapability(123);
    const caps = try (try root.getPointerField(1)).initList(.pointer, 1);
    (try caps.getPointerElement(0)).setCapability(456);

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqual(@as(u32, 123), try read_root.getPointerField(0).getCapabilityIndex());
    const read_caps = try read_root.getPointerField(1).getList(.pointer);
    try testing.expectEqual(@as(u32, 456), try (try read_caps.getPointerElement(0)).getCapabilityIndex());

    var validating = MessageReader.init(try builder.segmentsConst(), .{});
    const stats = try validating.validate();
    try testing.expectEqual(@as(usize, 2), stats.capabilities);
    try testing.expectEqual(@as(?u32, 456), stats.max_capability_index);
    var size_reader = MessageReader.init(try builder.segmentsConst(), .{});
    const root_size = try (try size_reader.getRoot()).totalSize();
    try testing.expectEqual(@as(usize, 3), root_size.word_count);
    try testing.expectEqual(@as(usize, 2), root_size.cap_count);

    var limited = MessageReader.init(try builder.segmentsConst(), .{ .capability_count_limit = 200 });
    try testing.expectError(error.InvalidCapabilityPointer, limited.validate());
}

test "non-bit primitive and pointer lists can be read as struct lists" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 6 });

    const ptrs = try (try root.getPointerField(0)).initList(.pointer, 2);
    try (try ptrs.getPointerElement(0)).setText("zero");
    try (try ptrs.getPointerElement(1)).setText("one");

    const words = try (try root.getPointerField(1)).initList(.eight_bytes, 2);
    try words.setUInt64(0, 0x1111_2222_3333_4444);
    try words.setUInt64(1, 0x5555_6666_7777_8888);

    const bytes = try (try root.getPointerField(2)).initList(.byte, 3);
    try bytes.setUInt8(0, 0x11);
    try bytes.setUInt8(1, 0x22);
    try bytes.setUInt8(2, 0x33);

    const half_words = try (try root.getPointerField(3)).initList(.two_bytes, 2);
    try half_words.setUInt16(0, 0x4455);
    try half_words.setUInt16(1, 0x6677);

    const double_words = try (try root.getPointerField(4)).initList(.four_bytes, 2);
    try double_words.setUInt32(0, 0x8899_aabb);
    try double_words.setUInt32(1, 0xccdd_eeff);

    const bits = try (try root.getPointerField(5)).initList(.bit, 3);
    try bits.setBool(0, true);
    try bits.setBool(1, false);
    try bits.setBool(2, true);

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();

    const ptr_structs = try read_root.getPointerField(0).getList(.composite);
    try testing.expectEqual(@as(usize, 2), ptr_structs.len());
    const second = try ptr_structs.getStructElement(1);
    try testing.expectEqualSlices(u8, "one", try second.getPointerField(0).getText());

    const word_structs = try read_root.getPointerField(1).getList(.composite);
    try testing.expectEqual(@as(usize, 2), word_structs.len());
    const first_word = try word_structs.getStructElement(0);
    const second_word = try word_structs.getStructElement(1);
    try testing.expectEqual(@as(u64, 0x1111_2222_3333_4444), first_word.getUInt64(0, 0));
    try testing.expectEqual(@as(u64, 0x5555_6666_7777_8888), second_word.getUInt64(0, 0));

    const byte_structs = try read_root.getPointerField(2).getList(.composite);
    try testing.expectEqual(@as(usize, 3), byte_structs.len());
    try testing.expectEqual(@as(u8, 0x11), (try byte_structs.getStructElement(0)).getUInt8(0, 0));
    try testing.expectEqual(@as(u8, 0x22), (try byte_structs.getStructElement(1)).getUInt8(0, 0));
    try testing.expectEqual(@as(u8, 0x33), (try byte_structs.getStructElement(2)).getUInt8(0, 0));
    try testing.expectEqual(@as(u16, 0xbeef), (try byte_structs.getStructElement(1)).getUInt16(0, 0xbeef));
    try testing.expectEqualSlices(u8, &[_]u8{0x22}, (try byte_structs.getStructElement(1)).dataSectionBytes());
    try testing.expectEqual(@as(usize, 1), (try byte_structs.totalSize()).word_count);

    const half_word_structs = try read_root.getPointerField(3).getList(.composite);
    try testing.expectEqual(@as(u16, 0x4455), (try half_word_structs.getStructElement(0)).getUInt16(0, 0));
    try testing.expectEqual(@as(u16, 0x6677), (try half_word_structs.getStructElement(1)).getUInt16(0, 0));

    const double_word_structs = try read_root.getPointerField(4).getList(.composite);
    try testing.expectEqual(@as(u32, 0x8899_aabb), (try double_word_structs.getStructElement(0)).getUInt32(0, 0));
    try testing.expectEqual(@as(u32, 0xccdd_eeff), (try double_word_structs.getStructElement(1)).getUInt32(0, 0));

    const bit_structs = try read_root.getPointerField(5).getList(.composite);
    try testing.expectEqual(@as(usize, 3), bit_structs.len());
    try testing.expect((try bit_structs.getStructElement(0)).getBool(0, false));
    try testing.expect(!(try bit_structs.getStructElement(1)).getBool(0, false));
    try testing.expect((try bit_structs.getStructElement(2)).getBool(0, false));
    try testing.expectEqual(@as(u8, 0xee), (try bit_structs.getStructElement(0)).getUInt8(0, 0xee));
    try testing.expectEqual(@as(usize, 1), (try bit_structs.totalSize()).word_count);
}

test "struct lists can be read as primitive and pointer lists" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 24 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const structs = try (try root.getPointerField(0)).initStructList(2, .{ .data_words = 1, .pointer_count = 1 });
    const first = try structs.getStructElement(0);
    try first.setUInt32(0, 0x1122_3345, 0);
    try first.setBool(32, true, false);
    try first.setText(0, "first");
    const second = try structs.getStructElement(1);
    try second.setUInt32(0, 0x5566_7788, 0);
    try second.setBool(32, false, false);
    try second.setText(0, "second");

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();

    const as_words = try read_root.getPointerField(0).getList(.four_bytes);
    try testing.expectEqual(@as(usize, 2), as_words.len());
    try testing.expectEqual(@as(u32, 0x1122_3345), as_words.getUInt32(0));
    try testing.expectEqual(@as(u32, 0x5566_7788), as_words.getUInt32(1));

    const as_bits = try read_root.getPointerField(0).getList(.bit);
    try testing.expect(as_bits.getBool(0));
    try testing.expect(!as_bits.getBool(1));

    const as_pointers = try read_root.getPointerField(0).getList(.pointer);
    try testing.expectEqualSlices(u8, "first", try (try as_pointers.getPointerElement(0)).getText());
    try testing.expectEqualSlices(u8, "second", try (try as_pointers.getPointerElement(1)).getText());
}
