const std = @import("std");
const wire = @import("../wire.zig");

const mod_list = @import("list.zig");
const mod_options = @import("options.zig");
const mod_pointer = @import("pointer.zig");
const mod_struct = @import("struct.zig");

const ListReader = mod_list.ListReader;
const Error = mod_options.Error;
const MessageStats = mod_options.MessageStats;
const PointerReader = mod_pointer.PointerReader;
const StructReader = mod_struct.StructReader;

pub fn tag_forFarWithZeroOffset(tag: wire.Word) Error!wire.Word {
    return switch (wire.pointerType(tag)) {
        .struct_ptr => blk: {
            const s = wire.decodeStruct(tag);
            break :blk try wire.encodeStruct(0, s.data_words, s.pointer_count);
        },
        .list => blk: {
            const l = try wire.decodeList(tag);
            break :blk try wire.encodeList(0, l.element_size, l.element_count_or_words);
        },
        else => tag,
    };
}

pub fn primitiveDataWords(size: wire.ElementSize) u16 {
    return switch (size) {
        .pointer => 0,
        .void => 0,
        .bit => 0,
        .byte, .two_bytes, .four_bytes, .eight_bytes => 1,
        .composite => 0,
    };
}

pub fn primitivePointerCount(size: wire.ElementSize) u16 {
    return if (size == .pointer) 1 else 0;
}

pub fn listDataBitsPerElement(size: wire.ElementSize) usize {
    return switch (size) {
        .void, .pointer => 0,
        .bit, .byte, .two_bytes, .four_bytes, .eight_bytes => wire.bitsPerElement(size),
        .composite => 0,
    };
}

pub fn upgradedStructListShape(size: wire.ElementSize) Error!struct { data_words: u16, pointer_count: u16 } {
    return switch (size) {
        .void => .{ .data_words = 0, .pointer_count = 0 },
        .bit, .byte, .two_bytes, .four_bytes, .eight_bytes => .{ .data_words = 1, .pointer_count = 0 },
        .pointer => .{ .data_words = 0, .pointer_count = 1 },
        .composite => error.IncompatibleListShape,
    };
}

pub fn validatePointer(ptr: PointerReader, stats: *MessageStats) Error!void {
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

pub fn collectStructStats(s: StructReader, stats: *MessageStats) Error!void {
    try addStat(&stats.structs, 1);
    try addStat(&stats.data_words, s.data_words);
    try addStat(&stats.pointer_words, s.pointer_count);
    try addStat(&stats.total_words, @as(usize, s.data_words) + @as(usize, s.pointer_count));
    for (0..s.pointer_count) |i| {
        try validatePointer(s.getPointerField(i), stats);
    }
}

pub fn collectListStats(list: ListReader, stats: *MessageStats) Error!void {
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

pub fn addStat(target: *usize, amount: usize) Error!void {
    target.* = std.math.add(usize, target.*, amount) catch return error.SerializedSizeOverflow;
}

pub fn canonicalStructSize(s: StructReader) Error!wire.StructSize {
    var data_words: usize = s.data_words;
    while (data_words > 0) {
        const word_index = std.math.add(usize, s.data_start, data_words - 1) catch return error.MessageTooLarge;
        const word = try s.message.readWord(s.segment_id, word_index);
        if (word != 0) break;
        data_words -= 1;
    }

    var pointer_count: usize = s.pointer_count;
    while (pointer_count > 0) {
        const word_index = std.math.add(usize, s.pointer_start, pointer_count - 1) catch return error.MessageTooLarge;
        const word = try s.message.readWord(s.segment_id, word_index);
        if (word != 0) break;
        pointer_count -= 1;
    }

    return .{
        .data_words = @intCast(data_words),
        .pointer_count = @intCast(pointer_count),
    };
}

pub fn canonicalStructListSize(list: ListReader) Error!wire.StructSize {
    var data_words: usize = list.data_words;
    while (data_words > 0) {
        const word_index = data_words - 1;
        var all_zero = true;
        for (0..list.element_count) |i| {
            const element = try list.getStructElement(i);
            const element_word_index = std.math.add(usize, element.data_start, word_index) catch return error.MessageTooLarge;
            const word = try element.message.readWord(element.segment_id, element_word_index);
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
            const element_word_index = std.math.add(usize, element.pointer_start, pointer_index) catch return error.MessageTooLarge;
            const word = try element.message.readWord(element.segment_id, element_word_index);
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

pub fn wordRangesOverlap(a_start: usize, a_end: usize, b_start: usize, b_end: usize) bool {
    return a_start < b_end and b_start < a_end;
}

pub fn structEndWord(start: usize, data_words: u16, pointer_count: u16) Error!usize {
    const payload_words = @as(usize, data_words) + @as(usize, pointer_count);
    return std.math.add(usize, start, payload_words) catch return error.MessageTooLarge;
}

pub fn textElementCount(byte_len: usize) Error!usize {
    return std.math.add(usize, byte_len, 1) catch return error.MessageTooLarge;
}

pub fn exactBytesForBits(bits: usize) Error!usize {
    if (bits % 8 != 0) return error.UnsupportedElementSize;
    return bits / 8;
}

pub fn exactWordsForBits(bits: usize) Error!usize {
    if (bits % wire.bits_per_word != 0) return error.UnsupportedElementSize;
    return bits / wire.bits_per_word;
}

pub fn checkedListBitLen(element_count: usize, step_bits: usize) Error!usize {
    return std.math.mul(usize, element_count, step_bits) catch return error.MessageTooLarge;
}

pub fn checkedListByteLen(element_count: usize, step_bits: usize) Error!usize {
    const bits = try checkedListBitLen(element_count, step_bits);
    return bits / 8 + @intFromBool(bits % 8 != 0);
}

pub fn checkedListWordLen(element_count: usize, step_bits: usize) Error!usize {
    const bits = try checkedListBitLen(element_count, step_bits);
    return bits / wire.bits_per_word + @intFromBool(bits % wire.bits_per_word != 0);
}

pub fn checkedWordBitOffset(word_index: usize, bit_offset: usize) Error!usize {
    const word_bits = std.math.mul(usize, word_index, wire.bits_per_word) catch return error.MessageTooLarge;
    return std.math.add(usize, word_bits, bit_offset) catch return error.MessageTooLarge;
}

pub fn checkedWordByteOffset(word_index: usize, bit_offset: usize) Error!usize {
    const word_bytes = std.math.mul(usize, word_index, wire.bytes_per_word) catch return error.MessageTooLarge;
    return std.math.add(usize, word_bytes, bit_offset / 8) catch return error.MessageTooLarge;
}

pub fn segmentIdFromIndex(index: usize) Error!u32 {
    if (index > std.math.maxInt(u32)) return error.MessageTooLarge;
    return @intCast(index);
}

var empty_mutable_bytes: [0]u8 = .{};

pub fn emptyMutableBytes() []u8 {
    return empty_mutable_bytes[0..];
}
