const std = @import("std");
const wire = @import("../wire.zig");
const serialize = @import("../serialize.zig");

const mod_builder = @import("builder.zig");
const mod_list = @import("list.zig");
const mod_options = @import("options.zig");
const mod_pointer = @import("pointer.zig");
const mod_struct = @import("struct.zig");
const mod_validate = @import("validate.zig");

const MessageBuilder = mod_builder.MessageBuilder;
const ListReader = mod_list.ListReader;
const Error = mod_options.Error;
const MessageSize = mod_options.MessageSize;
const MessageStats = mod_options.MessageStats;
const ReaderOptions = mod_options.ReaderOptions;
const wordsToBytesSaturating = mod_options.wordsToBytesSaturating;
const PointerReader = mod_pointer.PointerReader;
const StructReader = mod_struct.StructReader;
const validatePointer = mod_validate.validatePointer;

/// A reader that owns its decoded flat message storage.
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

    pub fn getRootListLen(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListLen(expected);
    }

    pub fn rootListMatchesLen(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesLen(expected, count);
    }

    pub fn rootListIsEmpty(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!bool {
        return self.reader.rootListIsEmpty(expected);
    }

    pub fn rootListHasIndex(self: *OwnedMessageReader, expected: ?wire.ElementSize, index: usize) Error!bool {
        return self.reader.rootListHasIndex(expected, index);
    }

    pub fn getRootListFirstIndex(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListFirstIndex(expected);
    }

    pub fn getRootListLastIndex(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListLastIndex(expected);
    }

    pub fn getRootListElementSize(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return self.reader.getRootListElementSize(expected);
    }

    pub fn rootListMatchesElementSize(self: *OwnedMessageReader, expected: ?wire.ElementSize, element_size: wire.ElementSize) Error!bool {
        return self.reader.rootListMatchesElementSize(expected, element_size);
    }

    pub fn getRootListElementBitCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListElementBitCount(expected);
    }

    pub fn rootListMatchesElementBits(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesElementBits(expected, count);
    }

    pub fn getRootListElementByteCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListElementByteCount(expected);
    }

    pub fn rootListMatchesElementBytes(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesElementBytes(expected, count);
    }

    pub fn getRootListElementWordCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListElementWordCount(expected);
    }

    pub fn rootListMatchesElementWords(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesElementWords(expected, count);
    }

    pub fn getRootListContentBitCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListContentBitCount(expected);
    }

    pub fn rootListMatchesContentBits(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesContentBits(expected, count);
    }

    pub fn getRootListContentByteCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListContentByteCount(expected);
    }

    pub fn getRootListContentWordCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListContentWordCount(expected);
    }

    pub fn rootListMatchesContentBytes(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesContentBytes(expected, count);
    }

    pub fn rootListMatchesContentWords(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesContentWords(expected, count);
    }

    pub fn getRootListStructElementSize(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!wire.StructSize {
        return self.reader.getRootListStructElementSize(expected);
    }

    pub fn getRootListStructElementDataWordCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!u16 {
        return self.reader.getRootListStructElementDataWordCount(expected);
    }

    pub fn getRootListStructElementPointerCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!u16 {
        return self.reader.getRootListStructElementPointerCount(expected);
    }

    pub fn getRootListStructElementTotalWords(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementTotalWords(expected);
    }

    pub fn getRootListStructElementDataByteCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementDataByteCount(expected);
    }

    pub fn getRootListStructElementPointerByteCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementPointerByteCount(expected);
    }

    pub fn getRootListStructElementTotalByteCount(self: *OwnedMessageReader, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementTotalByteCount(expected);
    }

    pub fn rootListMatchesStructElementSize(self: *OwnedMessageReader, expected: ?wire.ElementSize, size: wire.StructSize) Error!bool {
        return self.reader.rootListMatchesStructElementSize(expected, size);
    }

    pub fn rootListMatchesStructElementDataWords(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: u16) Error!bool {
        return self.reader.rootListMatchesStructElementDataWords(expected, count);
    }

    pub fn rootListMatchesStructElementPointerCount(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: u16) Error!bool {
        return self.reader.rootListMatchesStructElementPointerCount(expected, count);
    }

    pub fn rootListMatchesStructElementTotalWords(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementTotalWords(expected, count);
    }

    pub fn rootListMatchesStructElementDataBytes(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementDataBytes(expected, count);
    }

    pub fn rootListMatchesStructElementPointerBytes(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementPointerBytes(expected, count);
    }

    pub fn rootListMatchesStructElementTotalBytes(self: *OwnedMessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementTotalBytes(expected, count);
    }

    pub fn getRootText(self: *OwnedMessageReader) Error![]const u8 {
        return self.reader.getRootText();
    }

    pub fn getRootTextByteCount(self: *OwnedMessageReader) Error!usize {
        return self.reader.getRootTextByteCount();
    }

    pub fn rootTextMatchesBytes(self: *OwnedMessageReader, count: usize) Error!bool {
        return self.reader.rootTextMatchesBytes(count);
    }

    pub fn getRootData(self: *OwnedMessageReader) Error![]const u8 {
        return self.reader.getRootData();
    }

    pub fn getRootDataByteCount(self: *OwnedMessageReader) Error!usize {
        return self.reader.getRootDataByteCount();
    }

    pub fn rootDataMatchesBytes(self: *OwnedMessageReader, count: usize) Error!bool {
        return self.reader.rootDataMatchesBytes(count);
    }

    pub fn getRootTextDefault(self: *OwnedMessageReader, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootTextDefault(default_value);
    }

    pub fn getRootTextDefaultByteCount(self: *OwnedMessageReader, default_value: []const u8) Error!usize {
        return self.reader.getRootTextDefaultByteCount(default_value);
    }

    pub fn rootTextDefaultMatchesBytes(self: *OwnedMessageReader, default_value: []const u8, count: usize) Error!bool {
        return self.reader.rootTextDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootDataDefault(self: *OwnedMessageReader, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootDataDefault(default_value);
    }

    pub fn getRootDataDefaultByteCount(self: *OwnedMessageReader, default_value: []const u8) Error!usize {
        return self.reader.getRootDataDefaultByteCount(default_value);
    }

    pub fn rootDataDefaultMatchesBytes(self: *OwnedMessageReader, default_value: []const u8, count: usize) Error!bool {
        return self.reader.rootDataDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootCapability(self: *OwnedMessageReader) Error!u32 {
        return self.reader.getRootCapability();
    }

    pub fn getRootPointerStatsWithOptions(self: *OwnedMessageReader, options: ReaderOptions) Error!MessageStats {
        return self.reader.getRootPointerStatsWithOptions(options);
    }

    pub fn getRootPointerStats(self: *OwnedMessageReader) Error!MessageStats {
        return self.reader.getRootPointerStats();
    }

    pub fn getRootPointerTotalSizeWithOptions(self: *OwnedMessageReader, options: ReaderOptions) Error!MessageSize {
        return self.reader.getRootPointerTotalSizeWithOptions(options);
    }

    pub fn getRootPointerTotalSize(self: *OwnedMessageReader) Error!MessageSize {
        return self.reader.getRootPointerTotalSize();
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

    pub fn matchesRootPointerType(self: *OwnedMessageReader, expected: wire.PointerType) Error!bool {
        return self.reader.matchesRootPointerType(expected);
    }

    pub fn isRootStructPointer(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootStructPointer();
    }

    pub fn isRootListPointer(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootListPointer();
    }

    pub fn isRootFarPointer(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootFarPointer();
    }

    pub fn isRootOtherPointer(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootOtherPointer();
    }

    pub fn isRootCapabilityPointer(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootCapabilityPointer();
    }

    pub fn isRootNearPointer(self: *OwnedMessageReader) Error!bool {
        return self.reader.isRootNearPointer();
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

    pub fn traversalLimitBytes(self: *const OwnedMessageReader) usize {
        return self.reader.traversalLimitBytes();
    }

    pub fn matchesTraversalLimitWords(self: *const OwnedMessageReader, count: usize) bool {
        return self.reader.matchesTraversalLimitWords(count);
    }

    pub fn matchesTraversalLimitBytes(self: *const OwnedMessageReader, count: usize) bool {
        return self.reader.matchesTraversalLimitBytes(count);
    }

    pub fn traversalRemainingWords(self: *const OwnedMessageReader) usize {
        return self.reader.traversalRemainingWords();
    }

    pub fn traversalRemainingBytes(self: *const OwnedMessageReader) usize {
        return self.reader.traversalRemainingBytes();
    }

    pub fn nestingLimit(self: *const OwnedMessageReader) u16 {
        return self.reader.nestingLimit();
    }

    pub fn matchesNestingLimit(self: *const OwnedMessageReader, count: u16) bool {
        return self.reader.matchesNestingLimit(count);
    }

    pub fn capabilityCountLimit(self: *const OwnedMessageReader) ?usize {
        return self.reader.capabilityCountLimit();
    }

    pub fn hasCapabilityCountLimit(self: *const OwnedMessageReader) bool {
        return self.reader.hasCapabilityCountLimit();
    }

    pub fn matchesCapabilityCountLimit(self: *const OwnedMessageReader, count: usize) bool {
        return self.reader.matchesCapabilityCountLimit(count);
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

    pub fn packedSize(self: *const OwnedMessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)!usize {
        return self.reader.packedSize(allocator);
    }

    pub fn packedSizeWithTableBuffer(self: *const OwnedMessageReader, table_buffer: []u8) (Error || serialize.Error)!usize {
        return self.reader.packedSizeWithTableBuffer(table_buffer);
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

/// A reader view that owns only its segment table, not segment bytes.
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

    pub fn getRootListLen(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListLen(expected);
    }

    pub fn rootListMatchesLen(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesLen(expected, count);
    }

    pub fn rootListIsEmpty(self: *MessageReaderView, expected: ?wire.ElementSize) Error!bool {
        return self.reader.rootListIsEmpty(expected);
    }

    pub fn rootListHasIndex(self: *MessageReaderView, expected: ?wire.ElementSize, index: usize) Error!bool {
        return self.reader.rootListHasIndex(expected, index);
    }

    pub fn getRootListFirstIndex(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListFirstIndex(expected);
    }

    pub fn getRootListLastIndex(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListLastIndex(expected);
    }

    pub fn getRootListElementSize(self: *MessageReaderView, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return self.reader.getRootListElementSize(expected);
    }

    pub fn rootListMatchesElementSize(self: *MessageReaderView, expected: ?wire.ElementSize, element_size: wire.ElementSize) Error!bool {
        return self.reader.rootListMatchesElementSize(expected, element_size);
    }

    pub fn getRootListElementBitCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListElementBitCount(expected);
    }

    pub fn rootListMatchesElementBits(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesElementBits(expected, count);
    }

    pub fn getRootListElementByteCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListElementByteCount(expected);
    }

    pub fn rootListMatchesElementBytes(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesElementBytes(expected, count);
    }

    pub fn getRootListElementWordCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListElementWordCount(expected);
    }

    pub fn rootListMatchesElementWords(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesElementWords(expected, count);
    }

    pub fn getRootListContentBitCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListContentBitCount(expected);
    }

    pub fn rootListMatchesContentBits(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesContentBits(expected, count);
    }

    pub fn getRootListContentByteCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListContentByteCount(expected);
    }

    pub fn getRootListContentWordCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListContentWordCount(expected);
    }

    pub fn rootListMatchesContentBytes(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesContentBytes(expected, count);
    }

    pub fn rootListMatchesContentWords(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesContentWords(expected, count);
    }

    pub fn getRootListStructElementSize(self: *MessageReaderView, expected: ?wire.ElementSize) Error!wire.StructSize {
        return self.reader.getRootListStructElementSize(expected);
    }

    pub fn getRootListStructElementDataWordCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!u16 {
        return self.reader.getRootListStructElementDataWordCount(expected);
    }

    pub fn getRootListStructElementPointerCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!u16 {
        return self.reader.getRootListStructElementPointerCount(expected);
    }

    pub fn getRootListStructElementTotalWords(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementTotalWords(expected);
    }

    pub fn getRootListStructElementDataByteCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementDataByteCount(expected);
    }

    pub fn getRootListStructElementPointerByteCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementPointerByteCount(expected);
    }

    pub fn getRootListStructElementTotalByteCount(self: *MessageReaderView, expected: ?wire.ElementSize) Error!usize {
        return self.reader.getRootListStructElementTotalByteCount(expected);
    }

    pub fn rootListMatchesStructElementSize(self: *MessageReaderView, expected: ?wire.ElementSize, size: wire.StructSize) Error!bool {
        return self.reader.rootListMatchesStructElementSize(expected, size);
    }

    pub fn rootListMatchesStructElementDataWords(self: *MessageReaderView, expected: ?wire.ElementSize, count: u16) Error!bool {
        return self.reader.rootListMatchesStructElementDataWords(expected, count);
    }

    pub fn rootListMatchesStructElementPointerCount(self: *MessageReaderView, expected: ?wire.ElementSize, count: u16) Error!bool {
        return self.reader.rootListMatchesStructElementPointerCount(expected, count);
    }

    pub fn rootListMatchesStructElementTotalWords(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementTotalWords(expected, count);
    }

    pub fn rootListMatchesStructElementDataBytes(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementDataBytes(expected, count);
    }

    pub fn rootListMatchesStructElementPointerBytes(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementPointerBytes(expected, count);
    }

    pub fn rootListMatchesStructElementTotalBytes(self: *MessageReaderView, expected: ?wire.ElementSize, count: usize) Error!bool {
        return self.reader.rootListMatchesStructElementTotalBytes(expected, count);
    }

    pub fn getRootText(self: *MessageReaderView) Error![]const u8 {
        return self.reader.getRootText();
    }

    pub fn getRootTextByteCount(self: *MessageReaderView) Error!usize {
        return self.reader.getRootTextByteCount();
    }

    pub fn rootTextMatchesBytes(self: *MessageReaderView, count: usize) Error!bool {
        return self.reader.rootTextMatchesBytes(count);
    }

    pub fn getRootData(self: *MessageReaderView) Error![]const u8 {
        return self.reader.getRootData();
    }

    pub fn getRootDataByteCount(self: *MessageReaderView) Error!usize {
        return self.reader.getRootDataByteCount();
    }

    pub fn rootDataMatchesBytes(self: *MessageReaderView, count: usize) Error!bool {
        return self.reader.rootDataMatchesBytes(count);
    }

    pub fn getRootTextDefault(self: *MessageReaderView, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootTextDefault(default_value);
    }

    pub fn getRootTextDefaultByteCount(self: *MessageReaderView, default_value: []const u8) Error!usize {
        return self.reader.getRootTextDefaultByteCount(default_value);
    }

    pub fn rootTextDefaultMatchesBytes(self: *MessageReaderView, default_value: []const u8, count: usize) Error!bool {
        return self.reader.rootTextDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootDataDefault(self: *MessageReaderView, default_value: []const u8) Error![]const u8 {
        return self.reader.getRootDataDefault(default_value);
    }

    pub fn getRootDataDefaultByteCount(self: *MessageReaderView, default_value: []const u8) Error!usize {
        return self.reader.getRootDataDefaultByteCount(default_value);
    }

    pub fn rootDataDefaultMatchesBytes(self: *MessageReaderView, default_value: []const u8, count: usize) Error!bool {
        return self.reader.rootDataDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootCapability(self: *MessageReaderView) Error!u32 {
        return self.reader.getRootCapability();
    }

    pub fn getRootPointerStatsWithOptions(self: *MessageReaderView, options: ReaderOptions) Error!MessageStats {
        return self.reader.getRootPointerStatsWithOptions(options);
    }

    pub fn getRootPointerStats(self: *MessageReaderView) Error!MessageStats {
        return self.reader.getRootPointerStats();
    }

    pub fn getRootPointerTotalSizeWithOptions(self: *MessageReaderView, options: ReaderOptions) Error!MessageSize {
        return self.reader.getRootPointerTotalSizeWithOptions(options);
    }

    pub fn getRootPointerTotalSize(self: *MessageReaderView) Error!MessageSize {
        return self.reader.getRootPointerTotalSize();
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

    pub fn matchesRootPointerType(self: *MessageReaderView, expected: wire.PointerType) Error!bool {
        return self.reader.matchesRootPointerType(expected);
    }

    pub fn isRootStructPointer(self: *MessageReaderView) Error!bool {
        return self.reader.isRootStructPointer();
    }

    pub fn isRootListPointer(self: *MessageReaderView) Error!bool {
        return self.reader.isRootListPointer();
    }

    pub fn isRootFarPointer(self: *MessageReaderView) Error!bool {
        return self.reader.isRootFarPointer();
    }

    pub fn isRootOtherPointer(self: *MessageReaderView) Error!bool {
        return self.reader.isRootOtherPointer();
    }

    pub fn isRootCapabilityPointer(self: *MessageReaderView) Error!bool {
        return self.reader.isRootCapabilityPointer();
    }

    pub fn isRootNearPointer(self: *MessageReaderView) Error!bool {
        return self.reader.isRootNearPointer();
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

    pub fn traversalLimitBytes(self: *const MessageReaderView) usize {
        return self.reader.traversalLimitBytes();
    }

    pub fn matchesTraversalLimitWords(self: *const MessageReaderView, count: usize) bool {
        return self.reader.matchesTraversalLimitWords(count);
    }

    pub fn matchesTraversalLimitBytes(self: *const MessageReaderView, count: usize) bool {
        return self.reader.matchesTraversalLimitBytes(count);
    }

    pub fn traversalRemainingWords(self: *const MessageReaderView) usize {
        return self.reader.traversalRemainingWords();
    }

    pub fn traversalRemainingBytes(self: *const MessageReaderView) usize {
        return self.reader.traversalRemainingBytes();
    }

    pub fn nestingLimit(self: *const MessageReaderView) u16 {
        return self.reader.nestingLimit();
    }

    pub fn matchesNestingLimit(self: *const MessageReaderView, count: u16) bool {
        return self.reader.matchesNestingLimit(count);
    }

    pub fn capabilityCountLimit(self: *const MessageReaderView) ?usize {
        return self.reader.capabilityCountLimit();
    }

    pub fn hasCapabilityCountLimit(self: *const MessageReaderView) bool {
        return self.reader.hasCapabilityCountLimit();
    }

    pub fn matchesCapabilityCountLimit(self: *const MessageReaderView, count: usize) bool {
        return self.reader.matchesCapabilityCountLimit(count);
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

    pub fn packedSize(self: *const MessageReaderView, allocator: std.mem.Allocator) (Error || serialize.Error)!usize {
        return self.reader.packedSize(allocator);
    }

    pub fn packedSizeWithTableBuffer(self: *const MessageReaderView, table_buffer: []u8) (Error || serialize.Error)!usize {
        return self.reader.packedSizeWithTableBuffer(table_buffer);
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

/// A lazy, zero-copy reader over caller-owned message segments.
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

    pub fn matchesRootPointerType(self: *MessageReader, expected: wire.PointerType) Error!bool {
        return (try self.getRootPointer()).matchesPointerType(expected);
    }

    pub fn isRootStructPointer(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isStructPointer();
    }

    pub fn isRootListPointer(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isListPointer();
    }

    pub fn isRootFarPointer(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isFarPointer();
    }

    pub fn isRootOtherPointer(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isOtherPointer();
    }

    pub fn isRootCapabilityPointer(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isCapabilityPointer();
    }

    pub fn isRootNearPointer(self: *MessageReader) Error!bool {
        return (try self.getRootPointer()).isNearPointer();
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

    pub fn getRootListLen(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).len();
    }

    pub fn rootListMatchesLen(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesLen(count);
    }

    pub fn rootListIsEmpty(self: *MessageReader, expected: ?wire.ElementSize) Error!bool {
        return (try self.getRootList(expected)).isEmpty();
    }

    pub fn rootListHasIndex(self: *MessageReader, expected: ?wire.ElementSize, index: usize) Error!bool {
        return (try self.getRootList(expected)).hasIndex(index);
    }

    pub fn getRootListFirstIndex(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).firstIndex();
    }

    pub fn getRootListLastIndex(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).lastIndex();
    }

    pub fn getRootListElementSize(self: *MessageReader, expected: ?wire.ElementSize) Error!wire.ElementSize {
        return (try self.getRootList(expected)).elementSize();
    }

    pub fn rootListMatchesElementSize(self: *MessageReader, expected: ?wire.ElementSize, element_size: wire.ElementSize) Error!bool {
        return (try self.getRootList(expected)).matchesElementSize(element_size);
    }

    pub fn getRootListElementBitCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).elementBitCount();
    }

    pub fn rootListMatchesElementBits(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesElementBits(count);
    }

    pub fn getRootListElementByteCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).elementByteCount();
    }

    pub fn rootListMatchesElementBytes(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesElementBytes(count);
    }

    pub fn getRootListElementWordCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).elementWordCount();
    }

    pub fn rootListMatchesElementWords(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesElementWords(count);
    }

    pub fn getRootListContentBitCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).contentBitCount();
    }

    pub fn rootListMatchesContentBits(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesContentBits(count);
    }

    pub fn getRootListContentByteCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).contentByteCount();
    }

    pub fn getRootListContentWordCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).contentWordCount();
    }

    pub fn rootListMatchesContentBytes(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesContentBytes(count);
    }

    pub fn rootListMatchesContentWords(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesContentWords(count);
    }

    pub fn getRootListStructElementSize(self: *MessageReader, expected: ?wire.ElementSize) Error!wire.StructSize {
        return (try self.getRootList(expected)).structElementSize();
    }

    pub fn getRootListStructElementDataWordCount(self: *MessageReader, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getRootList(expected)).structElementDataWordCount();
    }

    pub fn getRootListStructElementPointerCount(self: *MessageReader, expected: ?wire.ElementSize) Error!u16 {
        return (try self.getRootList(expected)).structElementPointerCount();
    }

    pub fn getRootListStructElementTotalWords(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementTotalWords();
    }

    pub fn getRootListStructElementDataByteCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementDataByteCount();
    }

    pub fn getRootListStructElementPointerByteCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementPointerByteCount();
    }

    pub fn getRootListStructElementTotalByteCount(self: *MessageReader, expected: ?wire.ElementSize) Error!usize {
        return (try self.getRootList(expected)).structElementTotalByteCount();
    }

    pub fn rootListMatchesStructElementSize(self: *MessageReader, expected: ?wire.ElementSize, size: wire.StructSize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementSize(size);
    }

    pub fn rootListMatchesStructElementDataWords(self: *MessageReader, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementDataWords(count);
    }

    pub fn rootListMatchesStructElementPointerCount(self: *MessageReader, expected: ?wire.ElementSize, count: u16) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementPointerCount(count);
    }

    pub fn rootListMatchesStructElementTotalWords(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementTotalWords(count);
    }

    pub fn rootListMatchesStructElementDataBytes(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementDataBytes(count);
    }

    pub fn rootListMatchesStructElementPointerBytes(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementPointerBytes(count);
    }

    pub fn rootListMatchesStructElementTotalBytes(self: *MessageReader, expected: ?wire.ElementSize, count: usize) Error!bool {
        return (try self.getRootList(expected)).matchesStructElementTotalBytes(count);
    }

    pub fn getRootText(self: *MessageReader) Error![]const u8 {
        return (try self.getRootPointer()).getText();
    }

    pub fn getRootTextDefault(self: *MessageReader, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getTextDefault(default_value);
    }

    pub fn getRootTextDefaultByteCount(self: *MessageReader, default_value: []const u8) Error!usize {
        return (try self.getRootPointer()).getTextDefaultByteCount(default_value);
    }

    pub fn rootTextDefaultMatchesBytes(self: *MessageReader, default_value: []const u8, count: usize) Error!bool {
        return (try self.getRootPointer()).textDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootTextByteCount(self: *MessageReader) Error!usize {
        return (try self.getRootPointer()).getTextByteCount();
    }

    pub fn rootTextMatchesBytes(self: *MessageReader, count: usize) Error!bool {
        return (try self.getRootPointer()).textMatchesBytes(count);
    }

    pub fn getRootData(self: *MessageReader) Error![]const u8 {
        return (try self.getRootPointer()).getData();
    }

    pub fn getRootDataDefault(self: *MessageReader, default_value: []const u8) Error![]const u8 {
        return (try self.getRootPointer()).getDataDefault(default_value);
    }

    pub fn getRootDataDefaultByteCount(self: *MessageReader, default_value: []const u8) Error!usize {
        return (try self.getRootPointer()).getDataDefaultByteCount(default_value);
    }

    pub fn rootDataDefaultMatchesBytes(self: *MessageReader, default_value: []const u8, count: usize) Error!bool {
        return (try self.getRootPointer()).dataDefaultMatchesBytes(default_value, count);
    }

    pub fn getRootDataByteCount(self: *MessageReader) Error!usize {
        return (try self.getRootPointer()).getDataByteCount();
    }

    pub fn rootDataMatchesBytes(self: *MessageReader, count: usize) Error!bool {
        return (try self.getRootPointer()).dataMatchesBytes(count);
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
        try self.validateSegmentAlignment();
        var stats: MessageStats = .{};
        const root = PointerReader{ .message = self, .segment_id = 0, .word_index = 0, .nesting_left = self.options.nesting_limit };
        try validatePointer(root, &stats);
        return stats;
    }

    fn validateSegmentAlignment(self: *const MessageReader) Error!void {
        for (self.segments) |segment| {
            if (segment.len % wire.bytes_per_word != 0) return error.SegmentNotWordAligned;
        }
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

    pub fn traversalLimitBytes(self: *const MessageReader) usize {
        return self.options.traversalLimitBytes();
    }

    pub fn matchesTraversalLimitWords(self: *const MessageReader, count: usize) bool {
        return self.options.matchesTraversalLimitWords(count);
    }

    pub fn matchesTraversalLimitBytes(self: *const MessageReader, count: usize) bool {
        return self.options.matchesTraversalLimitBytes(count);
    }

    pub fn traversalRemainingWords(self: *const MessageReader) usize {
        return self.traversal_remaining;
    }

    pub fn traversalRemainingBytes(self: *const MessageReader) usize {
        return wordsToBytesSaturating(self.traversal_remaining);
    }

    pub fn nestingLimit(self: *const MessageReader) u16 {
        return self.options.nesting_limit;
    }

    pub fn matchesNestingLimit(self: *const MessageReader, count: u16) bool {
        return self.options.matchesNestingLimit(count);
    }

    pub fn capabilityCountLimit(self: *const MessageReader) ?usize {
        return self.options.capability_count_limit;
    }

    pub fn hasCapabilityCountLimit(self: *const MessageReader) bool {
        return self.options.hasCapabilityCountLimit();
    }

    pub fn matchesCapabilityCountLimit(self: *const MessageReader, count: usize) bool {
        return self.options.matchesCapabilityCountLimit(count);
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

    pub fn packedSize(self: *const MessageReader, allocator: std.mem.Allocator) (Error || serialize.Error)!usize {
        return serialize.packedMessageSize(allocator, self.segments);
    }

    pub fn packedSizeWithTableBuffer(self: *const MessageReader, table_buffer: []u8) (Error || serialize.Error)!usize {
        return serialize.packedMessageSizeWithTableBuffer(table_buffer, self.segments);
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

    pub fn segmentWords(self: *const MessageReader, segment_id: u32) Error!usize {
        if (segment_id >= self.segments.len) return error.SegmentOutOfBounds;
        const segment = self.segments[segment_id];
        if (segment.len % wire.bytes_per_word != 0) return error.SegmentNotWordAligned;
        return segment.len / wire.bytes_per_word;
    }

    pub fn readWord(self: *const MessageReader, segment_id: u32, word_index: usize) Error!wire.Word {
        if (segment_id >= self.segments.len) return error.SegmentOutOfBounds;
        return wire.readWord(self.segments[segment_id], word_index);
    }

    pub fn charge(self: *MessageReader, words: usize) Error!void {
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

pub fn messageToSingleSegmentFlatBytes(allocator: std.mem.Allocator, source: *const MessageReader) (Error || serialize.Error)![]u8 {
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
    try ensureSingleSegment(segments);
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

pub fn messageToCanonicalSegmentBytes(allocator: std.mem.Allocator, source: *const MessageReader) Error![]u8 {
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
    try ensureSingleSegment(segments);
    return allocator.dupe(u8, segments[0]);
}

pub fn ensureSingleSegment(segments: []const serialize.ConstSegment) Error!void {
    if (segments.len != 1) return error.MessageTooLarge;
}
