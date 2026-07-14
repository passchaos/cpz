const std = @import("std");

pub const Word = u64;
pub const bytes_per_word: usize = 8;
pub const bits_per_word: usize = 64;

pub const Error = error{
    NullPointer,
    InvalidPointerKind,
    InvalidFarPointer,
    InvalidCapabilityPointer,
    PointerOutOfBounds,
    SegmentOutOfBounds,
    MessageTooLarge,
    CountOutOfRange,
    OffsetOutOfRange,
    UnsupportedElementSize,
    NonCanonical,
};

pub const PointerType = enum(u2) {
    struct_ptr = 0,
    list = 1,
    far = 2,
    other = 3,
};

pub const ElementSize = enum(u3) {
    void = 0,
    bit = 1,
    byte = 2,
    two_bytes = 3,
    four_bytes = 4,
    eight_bytes = 5,
    pointer = 6,
    composite = 7,

    pub fn bits(self: ElementSize) usize {
        return bitsPerElement(self);
    }

    pub fn bytes(self: ElementSize) Error!usize {
        return bytesPerElement(self);
    }

    pub fn wordsForElements(self: ElementSize, element_count: usize) Error!usize {
        return wordsForList(self, element_count);
    }

    pub fn isVoid(self: ElementSize) bool {
        return self == .void;
    }

    pub fn isBit(self: ElementSize) bool {
        return self == .bit;
    }

    pub fn isPointer(self: ElementSize) bool {
        return self == .pointer;
    }

    pub fn isByteAligned(self: ElementSize) bool {
        return self.bits() % 8 == 0;
    }

    pub fn isWordAligned(self: ElementSize) bool {
        return self.bits() == bits_per_word;
    }

    pub fn isComposite(self: ElementSize) bool {
        return self == .composite;
    }

    pub fn isInlineData(self: ElementSize) bool {
        return switch (self) {
            .bit, .byte, .two_bytes, .four_bytes, .eight_bytes => true,
            .void, .pointer, .composite => false,
        };
    }

    pub fn isPrimitive(self: ElementSize) bool {
        return switch (self) {
            .void, .bit, .byte, .two_bytes, .four_bytes, .eight_bytes => true,
            .pointer, .composite => false,
        };
    }

    pub fn isScalar(self: ElementSize) bool {
        return switch (self) {
            .bit, .byte, .two_bytes, .four_bytes, .eight_bytes => true,
            .void, .pointer, .composite => false,
        };
    }

    pub fn isPointerLike(self: ElementSize) bool {
        return self == .pointer or self == .composite;
    }

    pub fn isNonCompositeList(self: ElementSize) bool {
        return self != .composite;
    }

    pub fn isFixedWidth(self: ElementSize) bool {
        return self != .composite;
    }

    pub fn hasPayloadBits(self: ElementSize) bool {
        return self.bits() != 0;
    }

    pub fn matchesBits(self: ElementSize, bit_count: usize) bool {
        return self.bits() == bit_count;
    }

    pub fn matchesBytes(self: ElementSize, byte_count: usize) bool {
        return (self.bytes() catch return false) == byte_count;
    }
};

pub const StructSize = struct {
    data_words: u16 = 0,
    pointer_count: u16 = 0,

    pub fn dataWordCount(self: StructSize) u16 {
        return self.data_words;
    }

    pub fn pointerCount(self: StructSize) u16 {
        return self.pointer_count;
    }

    pub fn totalWords(self: StructSize) usize {
        return @as(usize, self.data_words) + @as(usize, self.pointer_count);
    }

    pub fn dataByteCount(self: StructSize) usize {
        return @as(usize, self.data_words) * bytes_per_word;
    }

    pub fn pointerByteCount(self: StructSize) usize {
        return @as(usize, self.pointer_count) * bytes_per_word;
    }

    pub fn totalByteCount(self: StructSize) usize {
        return self.totalWords() * bytes_per_word;
    }

    pub fn isEmpty(self: StructSize) bool {
        return self.data_words == 0 and self.pointer_count == 0;
    }

    pub fn hasDataWords(self: StructSize) bool {
        return self.data_words != 0;
    }

    pub fn hasPointers(self: StructSize) bool {
        return self.pointer_count != 0;
    }

    pub fn matchesDataWords(self: StructSize, count: u16) bool {
        return self.data_words == count;
    }

    pub fn matchesPointerCount(self: StructSize, count: u16) bool {
        return self.pointer_count == count;
    }

    pub fn matchesTotalWords(self: StructSize, count: usize) bool {
        return self.totalWords() == count;
    }

    pub fn matchesDataBytes(self: StructSize, count: usize) bool {
        return self.dataByteCount() == count;
    }

    pub fn matchesPointerBytes(self: StructSize, count: usize) bool {
        return self.pointerByteCount() == count;
    }

    pub fn matchesTotalBytes(self: StructSize, count: usize) bool {
        return self.totalByteCount() == count;
    }
};

pub const StructPointer = struct {
    offset_words: i32,
    data_words: u16,
    pointer_count: u16,

    pub fn size(self: StructPointer) StructSize {
        return .{ .data_words = self.data_words, .pointer_count = self.pointer_count };
    }

    pub fn targetIndex(self: StructPointer, pointer_word_index: usize) Error!usize {
        return targetWordIndex(pointer_word_index, self.offset_words);
    }

    pub fn matchesTargetIndex(self: StructPointer, pointer_word_index: usize, expected: usize) bool {
        return (self.targetIndex(pointer_word_index) catch return false) == expected;
    }

    pub fn matchesOffsetWords(self: StructPointer, offset: i32) bool {
        return self.offset_words == offset;
    }

    pub fn dataWordCount(self: StructPointer) u16 {
        return self.data_words;
    }

    pub fn pointerCount(self: StructPointer) u16 {
        return self.pointer_count;
    }

    pub fn totalWords(self: StructPointer) usize {
        return self.size().totalWords();
    }

    pub fn dataByteCount(self: StructPointer) usize {
        return self.size().dataByteCount();
    }

    pub fn pointerByteCount(self: StructPointer) usize {
        return self.size().pointerByteCount();
    }

    pub fn totalByteCount(self: StructPointer) usize {
        return self.size().totalByteCount();
    }

    pub fn isEmpty(self: StructPointer) bool {
        return self.size().isEmpty();
    }

    pub fn hasDataWords(self: StructPointer) bool {
        return self.size().hasDataWords();
    }

    pub fn hasPointers(self: StructPointer) bool {
        return self.size().hasPointers();
    }

    pub fn matchesSize(self: StructPointer, expected: StructSize) bool {
        return self.data_words == expected.data_words and self.pointer_count == expected.pointer_count;
    }

    pub fn matchesDataWords(self: StructPointer, count: u16) bool {
        return self.data_words == count;
    }

    pub fn matchesPointerCount(self: StructPointer, count: u16) bool {
        return self.pointer_count == count;
    }

    pub fn matchesTotalWords(self: StructPointer, count: usize) bool {
        return self.totalWords() == count;
    }

    pub fn matchesDataBytes(self: StructPointer, count: usize) bool {
        return self.dataByteCount() == count;
    }

    pub fn matchesPointerBytes(self: StructPointer, count: usize) bool {
        return self.pointerByteCount() == count;
    }

    pub fn matchesTotalBytes(self: StructPointer, count: usize) bool {
        return self.totalByteCount() == count;
    }
};

pub const ListPointer = struct {
    offset_words: i32,
    element_size: ElementSize,
    element_count_or_words: u29,

    pub fn targetIndex(self: ListPointer, pointer_word_index: usize) Error!usize {
        return targetWordIndex(pointer_word_index, self.offset_words);
    }

    pub fn matchesTargetIndex(self: ListPointer, pointer_word_index: usize, expected: usize) bool {
        return (self.targetIndex(pointer_word_index) catch return false) == expected;
    }

    pub fn matchesOffsetWords(self: ListPointer, offset: i32) bool {
        return self.offset_words == offset;
    }

    pub fn elementSize(self: ListPointer) ElementSize {
        return self.element_size;
    }

    pub fn elementCountOrWordCount(self: ListPointer) usize {
        return self.element_count_or_words;
    }

    pub fn elementCount(self: ListPointer) Error!usize {
        if (self.element_size == .composite) return error.UnsupportedElementSize;
        return self.element_count_or_words;
    }

    pub fn compositeWordCount(self: ListPointer) Error!usize {
        if (self.element_size != .composite) return error.UnsupportedElementSize;
        return self.element_count_or_words;
    }

    pub fn hasElementsOrWords(self: ListPointer) bool {
        return self.element_count_or_words != 0;
    }

    pub fn matchesElementSize(self: ListPointer, expected: ElementSize) bool {
        return self.element_size == expected;
    }

    pub fn matchesElementCount(self: ListPointer, count: usize) bool {
        return self.element_size != .composite and @as(usize, self.element_count_or_words) == count;
    }

    pub fn matchesCompositeWordCount(self: ListPointer, count: usize) bool {
        return self.element_size == .composite and @as(usize, self.element_count_or_words) == count;
    }

    pub fn matchesElementCountOrWordCount(self: ListPointer, count: usize) bool {
        return @as(usize, self.element_count_or_words) == count;
    }
};

pub const FarPointer = struct {
    two_word_landing_pad: bool,
    landing_pad_offset: u29,
    segment_id: u32,

    pub fn isDoubleFar(self: FarPointer) bool {
        return self.two_word_landing_pad;
    }

    pub fn isSingleFar(self: FarPointer) bool {
        return !self.two_word_landing_pad;
    }

    pub fn matchesDoubleFar(self: FarPointer, is_double: bool) bool {
        return self.two_word_landing_pad == is_double;
    }

    pub fn matchesSingleFar(self: FarPointer, is_single: bool) bool {
        return self.isSingleFar() == is_single;
    }

    pub fn landingPadWordIndex(self: FarPointer) usize {
        return self.landing_pad_offset;
    }

    pub fn landingPadSegmentId(self: FarPointer) u32 {
        return self.segment_id;
    }

    pub fn matchesLandingPadWordIndex(self: FarPointer, word_index: usize) bool {
        return @as(usize, self.landing_pad_offset) == word_index;
    }

    pub fn matchesSegmentId(self: FarPointer, segment_id: u32) bool {
        return self.segment_id == segment_id;
    }
};

pub const CapabilityPointer = struct {
    index: u32,

    pub fn capabilityIndex(self: CapabilityPointer) u32 {
        return self.index;
    }

    pub fn matchesIndex(self: CapabilityPointer, index: u32) bool {
        return self.index == index;
    }
};

pub const DecodedPointer = union(PointerType) {
    struct_ptr: StructPointer,
    list: ListPointer,
    far: FarPointer,
    other: CapabilityPointer,

    pub fn kind(self: DecodedPointer) PointerType {
        return switch (self) {
            .struct_ptr => .struct_ptr,
            .list => .list,
            .far => .far,
            .other => .other,
        };
    }

    pub fn matchesKind(self: DecodedPointer, expected: PointerType) bool {
        return self.kind() == expected;
    }

    pub fn isStruct(self: DecodedPointer) bool {
        return self.kind() == .struct_ptr;
    }

    pub fn isList(self: DecodedPointer) bool {
        return self.kind() == .list;
    }

    pub fn isFar(self: DecodedPointer) bool {
        return self.kind() == .far;
    }

    pub fn isCapability(self: DecodedPointer) bool {
        return self.kind() == .other;
    }

    pub fn asStruct(self: DecodedPointer) ?StructPointer {
        return switch (self) {
            .struct_ptr => |ptr| ptr,
            else => null,
        };
    }

    pub fn asList(self: DecodedPointer) ?ListPointer {
        return switch (self) {
            .list => |ptr| ptr,
            else => null,
        };
    }

    pub fn asFar(self: DecodedPointer) ?FarPointer {
        return switch (self) {
            .far => |ptr| ptr,
            else => null,
        };
    }

    pub fn asCapability(self: DecodedPointer) ?CapabilityPointer {
        return switch (self) {
            .other => |ptr| ptr,
            else => null,
        };
    }

    pub fn asOther(self: DecodedPointer) ?CapabilityPointer {
        return self.asCapability();
    }
};

pub inline fn readWord(bytes: []const u8, word_index: usize) Error!Word {
    const byte_index = word_index * bytes_per_word;
    if (byte_index > bytes.len or bytes.len - byte_index < bytes_per_word) return error.SegmentOutOfBounds;
    return readWordAt(bytes[byte_index..][0..bytes_per_word]);
}

pub inline fn readWordAt(bytes: *const [bytes_per_word]u8) Word {
    return std.mem.readInt(Word, bytes, .little);
}

pub inline fn writeWordAt(bytes: *[bytes_per_word]u8, value: Word) void {
    std.mem.writeInt(Word, bytes, value, .little);
}

pub inline fn pointerType(raw: Word) PointerType {
    return @enumFromInt(@as(u2, @truncate(raw & 0x3)));
}

pub inline fn isNull(raw: Word) bool {
    return raw == 0;
}

pub fn decode(raw: Word) Error!DecodedPointer {
    return switch (pointerType(raw)) {
        .struct_ptr => .{ .struct_ptr = decodeStruct(raw) },
        .list => .{ .list = try decodeList(raw) },
        .far => .{ .far = decodeFar(raw) },
        .other => .{ .other = try decodeOther(raw) },
    };
}

pub inline fn decodeStruct(raw: Word) StructPointer {
    return .{
        .offset_words = decodeSigned30(@as(u30, @truncate(raw >> 2))),
        .data_words = @as(u16, @truncate(raw >> 32)),
        .pointer_count = @as(u16, @truncate(raw >> 48)),
    };
}

pub inline fn decodeList(raw: Word) Error!ListPointer {
    return .{
        .offset_words = decodeSigned30(@as(u30, @truncate(raw >> 2))),
        .element_size = @enumFromInt(@as(u3, @truncate(raw >> 32))),
        .element_count_or_words = @as(u29, @truncate(raw >> 35)),
    };
}

pub inline fn decodeFar(raw: Word) FarPointer {
    return .{
        .two_word_landing_pad = ((raw >> 2) & 1) != 0,
        .landing_pad_offset = @as(u29, @truncate(raw >> 3)),
        .segment_id = @as(u32, @truncate(raw >> 32)),
    };
}

pub inline fn decodeOther(raw: Word) Error!CapabilityPointer {
    const subtype: u30 = @truncate(raw >> 2);
    if (subtype != 0) return error.InvalidCapabilityPointer;
    return .{ .index = @as(u32, @truncate(raw >> 32)) };
}

pub fn encodeStruct(offset_words: i32, data_words: u16, pointer_count: u16) Error!Word {
    const off = try encodeSigned30(offset_words);
    return @as(Word, @intFromEnum(PointerType.struct_ptr)) |
        (@as(Word, off) << 2) |
        (@as(Word, data_words) << 32) |
        (@as(Word, pointer_count) << 48);
}

pub fn encodeList(offset_words: i32, element_size: ElementSize, element_count_or_words: usize) Error!Word {
    if (element_count_or_words > std.math.maxInt(u29)) return error.CountOutOfRange;
    const off = try encodeSigned30(offset_words);
    return @as(Word, @intFromEnum(PointerType.list)) |
        (@as(Word, off) << 2) |
        (@as(Word, @intFromEnum(element_size)) << 32) |
        (@as(Word, @as(u29, @intCast(element_count_or_words))) << 35);
}

pub fn encodeFar(two_word_landing_pad: bool, landing_pad_offset: usize, segment_id: u32) Error!Word {
    if (landing_pad_offset > std.math.maxInt(u29)) return error.CountOutOfRange;
    return @as(Word, @intFromEnum(PointerType.far)) |
        (@as(Word, @intFromBool(two_word_landing_pad)) << 2) |
        (@as(Word, @as(u29, @intCast(landing_pad_offset))) << 3) |
        (@as(Word, segment_id) << 32);
}

pub inline fn encodeCapability(index: u32) Word {
    return @as(Word, @intFromEnum(PointerType.other)) | (@as(Word, index) << 32);
}

pub fn targetWordIndex(pointer_word_index: usize, offset_words: i32) Error!usize {
    const base: isize = @intCast(pointer_word_index + 1);
    const target = base + @as(isize, @intCast(offset_words));
    if (target < 0) return error.PointerOutOfBounds;
    return @intCast(target);
}

pub fn offsetFromPointer(pointer_word_index: usize, target_word_index: usize) Error!i32 {
    const base: isize = @intCast(pointer_word_index + 1);
    const target: isize = @intCast(target_word_index);
    const offset = target - base;
    if (offset < std.math.minInt(i30) or offset > std.math.maxInt(i30)) return error.OffsetOutOfRange;
    return @intCast(offset);
}

pub inline fn bitsPerElement(size: ElementSize) usize {
    return switch (size) {
        .void => 0,
        .bit => 1,
        .byte => 8,
        .two_bytes => 16,
        .four_bytes => 32,
        .eight_bytes, .pointer => 64,
        .composite => 0,
    };
}

pub inline fn bytesPerElement(size: ElementSize) Error!usize {
    return switch (size) {
        .void => 0,
        .bit, .composite => error.UnsupportedElementSize,
        .byte => 1,
        .two_bytes => 2,
        .four_bytes => 4,
        .eight_bytes, .pointer => bytes_per_word,
    };
}

pub inline fn wordsForBits(bits: usize) usize {
    return (bits + bits_per_word - 1) / bits_per_word;
}

pub inline fn wordsForList(size: ElementSize, element_count: usize) Error!usize {
    if (size == .composite) return error.UnsupportedElementSize;
    const bits = std.math.mul(usize, bitsPerElement(size), element_count) catch return error.MessageTooLarge;
    return wordsForBits(bits);
}

pub inline fn wordsForStructList(element_count: usize, size: StructSize) Error!usize {
    return std.math.mul(usize, element_count, size.totalWords()) catch return error.MessageTooLarge;
}

pub fn encodeStructListTag(element_count: usize, size: StructSize) Error!Word {
    if (element_count > std.math.maxInt(i29)) return error.CountOutOfRange;
    return try encodeStruct(@intCast(element_count), size.data_words, size.pointer_count);
}

pub fn decodeStructListTag(raw: Word) Error!struct { element_count: usize, size: StructSize } {
    if (pointerType(raw) != .struct_ptr) return error.InvalidPointerKind;
    const tag = decodeStruct(raw);
    if (tag.offset_words < 0) return error.CountOutOfRange;
    return .{
        .element_count = @intCast(tag.offset_words),
        .size = .{ .data_words = tag.data_words, .pointer_count = tag.pointer_count },
    };
}

inline fn decodeSigned30(bits: u30) i32 {
    const signed: i30 = @bitCast(bits);
    return @intCast(signed);
}

inline fn encodeSigned30(value: i32) Error!u30 {
    if (value < std.math.minInt(i30) or value > std.math.maxInt(i30)) return error.OffsetOutOfRange;
    const signed: i30 = @intCast(value);
    return @bitCast(signed);
}

test "element size helper methods" {
    const testing = std.testing;

    try testing.expect(ElementSize.void.isVoid());
    try testing.expect(ElementSize.bit.isBit());
    try testing.expect(ElementSize.pointer.isPointer());
    try testing.expect(ElementSize.composite.isComposite());
    try testing.expect(!ElementSize.composite.isFixedWidth());
    try testing.expect(ElementSize.eight_bytes.isFixedWidth());
    try testing.expect(ElementSize.byte.isInlineData());
    try testing.expect(ElementSize.four_bytes.isInlineData());
    try testing.expect(!ElementSize.void.isInlineData());
    try testing.expect(!ElementSize.pointer.isInlineData());
    try testing.expect(!ElementSize.composite.isInlineData());
    try testing.expect(ElementSize.void.isPrimitive());
    try testing.expect(ElementSize.bit.isPrimitive());
    try testing.expect(ElementSize.eight_bytes.isPrimitive());
    try testing.expect(!ElementSize.pointer.isPrimitive());
    try testing.expect(!ElementSize.composite.isPrimitive());
    try testing.expect(ElementSize.bit.isScalar());
    try testing.expect(ElementSize.eight_bytes.isScalar());
    try testing.expect(!ElementSize.void.isScalar());
    try testing.expect(!ElementSize.pointer.isScalar());
    try testing.expect(ElementSize.pointer.isPointerLike());
    try testing.expect(ElementSize.composite.isPointerLike());
    try testing.expect(!ElementSize.byte.isPointerLike());
    try testing.expect(ElementSize.pointer.isNonCompositeList());
    try testing.expect(!ElementSize.composite.isNonCompositeList());
    try testing.expect(!ElementSize.void.hasPayloadBits());
    try testing.expect(ElementSize.pointer.hasPayloadBits());
    try testing.expectEqual(@as(usize, 16), ElementSize.two_bytes.bits());
    try testing.expectEqual(@as(usize, 2), try ElementSize.two_bytes.bytes());
    try testing.expectEqual(@as(usize, 8), try ElementSize.pointer.bytes());
    try testing.expectEqual(@as(usize, 0), try ElementSize.void.bytes());
    try testing.expectError(error.UnsupportedElementSize, ElementSize.bit.bytes());
    try testing.expectError(error.UnsupportedElementSize, ElementSize.composite.bytes());
    try testing.expect(ElementSize.two_bytes.matchesBits(16));
    try testing.expect(ElementSize.four_bytes.matchesBytes(4));
    try testing.expect(!ElementSize.four_bytes.matchesBytes(8));
    try testing.expect(!ElementSize.bit.matchesBytes(1));
    try testing.expect(!ElementSize.composite.matchesBytes(0));
    try testing.expect(!ElementSize.bit.isByteAligned());
    try testing.expect(ElementSize.byte.isByteAligned());
    try testing.expect(ElementSize.void.isByteAligned());
    try testing.expect(ElementSize.pointer.isWordAligned());
    try testing.expect(ElementSize.eight_bytes.isWordAligned());
    try testing.expect(!ElementSize.four_bytes.isWordAligned());
    try testing.expectEqual(@as(usize, 2), try ElementSize.two_bytes.wordsForElements(5));
    try testing.expectEqual(@as(usize, 5), try ElementSize.eight_bytes.wordsForElements(5));
    try testing.expectError(error.UnsupportedElementSize, ElementSize.composite.wordsForElements(1));
}

test "struct size byte helper methods" {
    const testing = std.testing;

    const empty = StructSize{};
    try testing.expectEqual(@as(usize, 0), empty.dataByteCount());
    try testing.expectEqual(@as(usize, 0), empty.pointerByteCount());
    try testing.expectEqual(@as(usize, 0), empty.totalByteCount());
    try testing.expect(empty.matchesTotalBytes(0));

    const size = StructSize{ .data_words = 3, .pointer_count = 2 };
    try testing.expectEqual(@as(usize, 24), size.dataByteCount());
    try testing.expectEqual(@as(usize, 16), size.pointerByteCount());
    try testing.expectEqual(@as(usize, 40), size.totalByteCount());
    try testing.expect(size.matchesDataBytes(24));
    try testing.expect(size.matchesPointerBytes(16));
    try testing.expect(size.matchesTotalBytes(40));
    try testing.expect(!size.matchesTotalBytes(41));
}

test "wire pointer encoding matches Cap'n Proto spec examples" {
    const testing = std.testing;

    const struct_raw = try encodeStruct(2, 3, 2);
    try testing.expectEqual(@as(Word, 0x0002_0003_0000_0008), struct_raw);
    const decoded_struct = try decode(struct_raw);
    try testing.expectEqual(PointerType.struct_ptr, decoded_struct.kind());
    try testing.expect(decoded_struct.matchesKind(.struct_ptr));
    try testing.expect(decoded_struct.isStruct());
    try testing.expect(!decoded_struct.isList());
    try testing.expect(!decoded_struct.isFar());
    try testing.expect(!decoded_struct.isCapability());
    try testing.expectEqual(@as(u16, 3), decoded_struct.asStruct().?.data_words);
    try testing.expect(decoded_struct.asList() == null);
    try testing.expect(decoded_struct.asFar() == null);
    try testing.expect(decoded_struct.asCapability() == null);
    try testing.expect(decoded_struct.asOther() == null);
    const struct_ptr = decodeStruct(struct_raw);
    try testing.expectEqual(@as(i32, 2), struct_ptr.offset_words);
    try testing.expectEqual(@as(u16, 3), struct_ptr.data_words);
    try testing.expectEqual(@as(u16, 2), struct_ptr.pointer_count);
    try testing.expectEqual(StructSize{ .data_words = 3, .pointer_count = 2 }, struct_ptr.size());
    try testing.expectEqual(@as(usize, 3), try struct_ptr.targetIndex(0));
    try testing.expect(struct_ptr.matchesTargetIndex(0, 3));
    try testing.expect(!struct_ptr.matchesTargetIndex(0, 2));
    try testing.expect(struct_ptr.matchesOffsetWords(2));
    try testing.expect(!struct_ptr.matchesOffsetWords(1));
    try testing.expectEqual(@as(u16, 3), struct_ptr.dataWordCount());
    try testing.expectEqual(@as(u16, 2), struct_ptr.pointerCount());
    try testing.expectEqual(@as(usize, 5), struct_ptr.totalWords());
    try testing.expectEqual(@as(usize, 24), struct_ptr.dataByteCount());
    try testing.expectEqual(@as(usize, 16), struct_ptr.pointerByteCount());
    try testing.expectEqual(@as(usize, 40), struct_ptr.totalByteCount());
    try testing.expect(!struct_ptr.isEmpty());
    try testing.expect(struct_ptr.hasDataWords());
    try testing.expect(struct_ptr.hasPointers());
    try testing.expect(struct_ptr.size().matchesTotalWords(5));
    try testing.expect(struct_ptr.matchesSize(.{ .data_words = 3, .pointer_count = 2 }));
    try testing.expect(struct_ptr.matchesDataWords(3));
    try testing.expect(!struct_ptr.matchesDataWords(2));
    try testing.expect(struct_ptr.matchesPointerCount(2));
    try testing.expect(!struct_ptr.matchesPointerCount(3));
    try testing.expect(struct_ptr.matchesTotalWords(5));
    try testing.expect(!struct_ptr.matchesTotalWords(4));
    try testing.expect(struct_ptr.matchesDataBytes(24));
    try testing.expect(struct_ptr.matchesPointerBytes(16));
    try testing.expect(struct_ptr.matchesTotalBytes(40));
    try testing.expect(!struct_ptr.matchesTotalBytes(32));

    const text_raw = try encodeList(6, .byte, 53);
    try testing.expectEqual(@as(Word, 0x0000_01aa_0000_0019), text_raw);
    const decoded_list = try decode(text_raw);
    try testing.expectEqual(PointerType.list, decoded_list.kind());
    try testing.expect(decoded_list.isList());
    try testing.expectEqual(ElementSize.byte, decoded_list.asList().?.element_size);
    try testing.expect(decoded_list.asStruct() == null);
    const list_ptr = try decodeList(text_raw);
    try testing.expectEqual(@as(i32, 6), list_ptr.offset_words);
    try testing.expectEqual(ElementSize.byte, list_ptr.element_size);
    try testing.expectEqual(@as(u29, 53), list_ptr.element_count_or_words);
    try testing.expectEqual(@as(usize, 8), try list_ptr.targetIndex(1));
    try testing.expect(list_ptr.matchesTargetIndex(1, 8));
    try testing.expect(!list_ptr.matchesTargetIndex(1, 7));
    try testing.expect(list_ptr.matchesOffsetWords(6));
    try testing.expect(!list_ptr.matchesOffsetWords(5));
    try testing.expectEqual(ElementSize.byte, list_ptr.elementSize());
    try testing.expectEqual(@as(usize, 53), list_ptr.elementCountOrWordCount());
    try testing.expectEqual(@as(usize, 53), try list_ptr.elementCount());
    try testing.expectError(error.UnsupportedElementSize, list_ptr.compositeWordCount());
    try testing.expect(list_ptr.hasElementsOrWords());
    try testing.expect(list_ptr.matchesElementSize(.byte));
    try testing.expect(list_ptr.matchesElementCount(53));
    try testing.expect(!list_ptr.matchesElementCount(52));
    try testing.expect(!list_ptr.matchesCompositeWordCount(53));
    try testing.expect(list_ptr.matchesElementCountOrWordCount(53));

    const composite_raw = try encodeList(1, .composite, 7);
    const composite_ptr = try decodeList(composite_raw);
    try testing.expectError(error.UnsupportedElementSize, composite_ptr.elementCount());
    try testing.expectEqual(@as(usize, 7), try composite_ptr.compositeWordCount());
    try testing.expect(!composite_ptr.matchesElementCount(7));
    try testing.expect(composite_ptr.matchesCompositeWordCount(7));
    try testing.expect(!composite_ptr.matchesCompositeWordCount(8));
}

test "wire signed offsets and far/capability pointers" {
    const testing = std.testing;

    const zero_struct = try encodeStruct(-1, 0, 0);
    try testing.expectEqual(@as(Word, 0x0000_0000_ffff_fffc), zero_struct);
    try testing.expectEqual(@as(i32, -1), decodeStruct(zero_struct).offset_words);

    const far_raw = try encodeFar(true, 17, 9);
    const decoded_far = try decode(far_raw);
    try testing.expectEqual(PointerType.far, decoded_far.kind());
    try testing.expect(decoded_far.isFar());
    try testing.expectEqual(@as(u32, 9), decoded_far.asFar().?.segment_id);
    try testing.expect(decoded_far.asCapability() == null);
    const far = decodeFar(far_raw);
    try testing.expect(far.two_word_landing_pad);
    try testing.expectEqual(@as(u29, 17), far.landing_pad_offset);
    try testing.expectEqual(@as(u32, 9), far.segment_id);
    try testing.expect(far.isDoubleFar());
    try testing.expect(!far.isSingleFar());
    try testing.expect(far.matchesDoubleFar(true));
    try testing.expect(!far.matchesDoubleFar(false));
    try testing.expect(!far.matchesSingleFar(true));
    try testing.expect(far.matchesSingleFar(false));
    try testing.expectEqual(@as(usize, 17), far.landingPadWordIndex());
    try testing.expectEqual(@as(u32, 9), far.landingPadSegmentId());
    try testing.expect(far.matchesLandingPadWordIndex(17));
    try testing.expect(far.matchesSegmentId(9));

    const single_far = decodeFar(try encodeFar(false, 3, 2));
    try testing.expect(single_far.isSingleFar());
    try testing.expect(!single_far.isDoubleFar());
    try testing.expect(single_far.matchesDoubleFar(false));
    try testing.expect(single_far.matchesSingleFar(true));

    const cap_raw = encodeCapability(1234);
    const decoded_cap = try decode(cap_raw);
    try testing.expectEqual(PointerType.other, decoded_cap.kind());
    try testing.expect(decoded_cap.isCapability());
    try testing.expectEqual(@as(u32, 1234), decoded_cap.asCapability().?.index);
    try testing.expectEqual(@as(u32, 1234), decoded_cap.asOther().?.index);
    try testing.expect(decoded_cap.asFar() == null);
    const cap = try decodeOther(cap_raw);
    try testing.expectEqual(@as(u32, 1234), cap.index);
    try testing.expectEqual(@as(u32, 1234), cap.capabilityIndex());
    try testing.expect(cap.matchesIndex(1234));
}
