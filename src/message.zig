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
        const root = PointerBuilder{ .message = self, .segment_id = 0, .word_index = 0 };
        return root.initStruct(size);
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

    pub fn asReader(self: *MessageBuilder, options: ReaderOptions) !MessageReader {
        return MessageReader.init(try self.segmentsConst(), options);
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
        if (self.segments.len == 0) return error.SegmentOutOfBounds;
        const ptr = PointerReader{ .message = self, .segment_id = 0, .word_index = 0, .nesting_left = self.options.nesting_limit };
        return ptr.getStruct(null);
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

pub const PointerBuilder = struct {
    message: *MessageBuilder,
    segment_id: u32,
    word_index: usize,

    pub fn isNull(self: PointerBuilder) bool {
        return self.message.readWord(self.segment_id, self.word_index) == 0;
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

    pub fn setText(self: PointerBuilder, text: []const u8) Error!void {
        const list = try self.initList(.byte, text.len + 1);
        const bytes = list.bytes();
        @memcpy(bytes[0..text.len], text);
        bytes[text.len] = 0;
    }

    pub fn setData(self: PointerBuilder, data: []const u8) Error!void {
        const list = try self.initList(.byte, data.len);
        @memcpy(list.bytes(), data);
    }
};

pub const PointerReader = struct {
    message: *MessageReader,
    segment_id: u32,
    word_index: usize,
    nesting_left: u16,
    null_override: bool = false,

    pub fn raw(self: PointerReader) Error!wire.Word {
        if (self.null_override) return 0;
        return self.message.readWord(self.segment_id, self.word_index);
    }

    pub fn isNull(self: PointerReader) bool {
        return (self.raw() catch 0) == 0;
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
        if (expected) |exp| if (exp != l.element_size) return error.IncompatibleListShape;
        const target = try wire.targetWordIndex(resolved.pointer_word_index, l.offset_words);

        if (l.element_size == .composite) {
            const content_words: usize = l.element_count_or_words;
            try self.boundsCheck(resolved.segment_id, target, content_words + 1);
            const tag = try self.message.readWord(resolved.segment_id, target);
            const decoded_tag = try wire.decodeStructListTag(tag);
            const expected_words = try wire.wordsForStructList(decoded_tag.element_count, decoded_tag.size);
            if (expected_words > content_words) return error.PointerOutOfBounds;
            try self.descend(@max(content_words, decoded_tag.element_count));
            return .{
                .message = self.message,
                .segment_id = resolved.segment_id,
                .start = target + 1,
                .element_count = decoded_tag.element_count,
                .element_size = .composite,
                .data_words = decoded_tag.size.data_words,
                .pointer_count = decoded_tag.size.pointer_count,
                .step_bits = decoded_tag.size.totalWords() * wire.bits_per_word,
                .nesting_left = self.nesting_left - 1,
            };
        }

        const words = try wire.wordsForList(l.element_size, l.element_count_or_words);
        try self.boundsCheck(resolved.segment_id, target, words);
        try self.descend(@max(words, @as(usize, l.element_count_or_words)));
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

    pub fn getData(self: PointerReader) Error![]const u8 {
        return (try self.getList(.byte)).bytes();
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
        const raw_value = try self.message.readWord(self.segment_id, self.word_index);
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

    pub fn setInt32(self: StructBuilder, byte_offset: usize, value: i32, default_value: i32) Error!void {
        try self.setInt(i32, byte_offset, value, default_value);
    }

    pub fn setFloat32(self: StructBuilder, byte_offset: usize, value: f32, default_value: f32) Error!void {
        try self.setInt(u32, byte_offset, @bitCast(value), @bitCast(default_value));
    }

    pub fn setFloat64(self: StructBuilder, byte_offset: usize, value: f64, default_value: f64) Error!void {
        try self.setInt(u64, byte_offset, @bitCast(value), @bitCast(default_value));
    }

    pub fn setText(self: StructBuilder, pointer_index: usize, text: []const u8) Error!void {
        try (try self.getPointerField(pointer_index)).setText(text);
    }

    pub fn setData(self: StructBuilder, pointer_index: usize, data: []const u8) Error!void {
        try (try self.getPointerField(pointer_index)).setData(data);
    }

    fn setInt(self: StructBuilder, comptime T: type, byte_offset: usize, value: T, default_value: T) Error!void {
        try self.checkDataBytes(byte_offset, @sizeOf(T));
        const encoded = value ^ default_value;
        const bytes = self.dataBytes()[byte_offset..][0..@sizeOf(T)];
        std.mem.writeInt(T, bytes, encoded, .little);
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

    pub fn getPointerField(self: StructReader, index: usize) PointerReader {
        if (index >= self.pointer_count) {
            return .{ .message = self.message, .segment_id = self.segment_id, .word_index = 0, .nesting_left = self.nesting_left, .null_override = true };
        }
        return .{ .message = self.message, .segment_id = self.segment_id, .word_index = self.pointer_start + index, .nesting_left = self.nesting_left };
    }

    pub fn getBool(self: StructReader, bit_offset: usize, default_value: bool) bool {
        if (bit_offset >= @as(usize, self.data_words) * wire.bits_per_word) return default_value;
        const abs_bit = self.data_start * wire.bits_per_word + bit_offset;
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

    pub fn getInt32(self: StructReader, byte_offset: usize, default_value: i32) i32 {
        return self.getInt(i32, byte_offset, default_value);
    }

    pub fn getFloat32(self: StructReader, byte_offset: usize, default_value: f32) f32 {
        return @bitCast(self.getInt(u32, byte_offset, @bitCast(default_value)));
    }

    pub fn getFloat64(self: StructReader, byte_offset: usize, default_value: f64) f64 {
        return @bitCast(self.getInt(u64, byte_offset, @bitCast(default_value)));
    }

    fn getInt(self: StructReader, comptime T: type, byte_offset: usize, default_value: T) T {
        const data_len = @as(usize, self.data_words) * wire.bytes_per_word;
        if (byte_offset > data_len or data_len - byte_offset < @sizeOf(T)) return default_value;
        const bytes = self.dataBytes()[byte_offset..][0..@sizeOf(T)];
        return std.mem.readInt(T, bytes, .little) ^ default_value;
    }

    fn dataBytes(self: StructReader) []const u8 {
        if (self.segment_id >= self.message.segments.len) return &.{};
        return self.message.segments[self.segment_id][self.data_start * wire.bytes_per_word .. (self.data_start + self.data_words) * wire.bytes_per_word];
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

    pub fn bytes(self: ListBuilder) []u8 {
        const word_count = wire.wordsForBits(self.element_count * self.step_bits);
        return std.mem.sliceAsBytes(self.message.segments.items[self.segment_id].words.items[self.start .. self.start + word_count])[0..listByteLen(self.element_count, self.step_bits)];
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

    pub fn setBool(self: ListBuilder, index: usize, value: bool) Error!void {
        if (self.element_size != .bit or index >= self.element_count) return error.PointerOutOfBounds;
        const abs_bit = self.start * wire.bits_per_word + index;
        const word_index = abs_bit / wire.bits_per_word;
        const bit: u6 = @intCast(abs_bit % wire.bits_per_word);
        var word = self.message.readWord(self.segment_id, word_index);
        if (value) word |= @as(u64, 1) << bit else word &= ~(@as(u64, 1) << bit);
        self.message.segments.items[self.segment_id].words.items[word_index] = word;
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

    fn setPrimitive(self: ListBuilder, comptime T: type, index: usize, value: T) Error!void {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        const byte_offset = index * @sizeOf(T);
        const target_bytes = self.bytes()[byte_offset..][0..@sizeOf(T)];
        std.mem.writeInt(T, target_bytes, value, .little);
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

    pub fn len(self: ListReader) usize {
        return self.element_count;
    }

    pub fn bytes(self: ListReader) []const u8 {
        const word_count = wire.wordsForBits(self.element_count * self.step_bits);
        const all = self.message.segments[self.segment_id][self.start * wire.bytes_per_word .. (self.start + word_count) * wire.bytes_per_word];
        return all[0..listByteLen(self.element_count, self.step_bits)];
    }

    pub fn getBool(self: ListReader, index: usize) bool {
        if (self.element_size != .bit or index >= self.element_count) return false;
        const abs_bit = self.start * wire.bits_per_word + index;
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

    pub fn getStructElement(self: ListReader, index: usize) Error!StructReader {
        if (self.element_size == .bit or index >= self.element_count) return error.PointerOutOfBounds;
        const data_words = self.data_words;
        const pointer_count = self.pointer_count;
        const step_words = @as(usize, data_words) + @as(usize, pointer_count);
        const start = self.start + index * step_words;
        return .{
            .message = self.message,
            .segment_id = self.segment_id,
            .data_start = start,
            .pointer_start = start + data_words,
            .data_words = data_words,
            .pointer_count = pointer_count,
            .nesting_left = self.nesting_left,
        };
    }

    fn getPrimitive(self: ListReader, comptime T: type, index: usize) Error!T {
        if (index >= self.element_count) return error.PointerOutOfBounds;
        if (wire.bitsPerElement(self.element_size) != @bitSizeOf(T)) return error.IncompatibleListShape;
        const byte_offset = index * @sizeOf(T);
        const b = self.bytes()[byte_offset..][0..@sizeOf(T)];
        return std.mem.readInt(T, b, .little);
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
    const nums = try (try root.getPointerField(0)).initList(.two_bytes, 3);
    try nums.setUInt16(0, 10);
    try nums.setUInt16(1, 20);
    try nums.setUInt16(2, 30);

    const people = try (try root.getPointerField(1)).initStructList(2, .{ .data_words = 1, .pointer_count = 1 });
    const p0 = try people.getStructElement(0);
    try p0.setUInt32(0, 1, 0);
    try p0.setText(0, "a");
    const p1 = try people.getStructElement(1);
    try p1.setUInt32(0, 2, 0);
    try p1.setText(0, "bb");

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const r = try reader.getRoot();
    const read_nums = try r.getPointerField(0).getList(.two_bytes);
    try testing.expectEqual(@as(usize, 3), read_nums.len());
    try testing.expectEqual(@as(u16, 20), read_nums.getUInt16(1));

    const read_people = try r.getPointerField(1).getList(.composite);
    try testing.expectEqual(@as(usize, 2), read_people.len());
    const read_p1 = try read_people.getStructElement(1);
    try testing.expectEqual(@as(u32, 2), read_p1.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "bb", try read_p1.getPointerField(0).getText());
}
