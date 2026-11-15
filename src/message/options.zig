const std = @import("std");
const wire = @import("../wire.zig");

pub fn wordsToBytesSaturating(words: usize) usize {
    return std.math.mul(usize, words, wire.bytes_per_word) catch std.math.maxInt(usize);
}

pub fn wordsToBytesChecked(words: usize) Error!usize {
    return std.math.mul(usize, words, wire.bytes_per_word) catch return error.SerializedSizeOverflow;
}

/// Errors produced by dynamic message readers, builders, and validation.
pub const Error = wire.Error || std.mem.Allocator.Error || error{
    ReadOnly,
    NestingLimitExceeded,
    TraversalLimitExceeded,
    SerializedSizeOverflow,
    SegmentNotWordAligned,
    InvalidDefaultValue,
    TextNotNulTerminated,
    TextContainsInteriorNul,
    Utf8Invalid,
    IncompatibleListShape,
};

/// Safety limits applied while traversing untrusted messages.
pub const ReaderOptions = struct {
    traversal_limit_words: usize = 8 * 1024 * 1024, // 64 MiB like C++ default.
    nesting_limit: u16 = 64,
    capability_count_limit: ?usize = null,

    pub fn traversalLimitWords(self: ReaderOptions) usize {
        return self.traversal_limit_words;
    }

    pub fn traversalLimitBytes(self: ReaderOptions) usize {
        return wordsToBytesSaturating(self.traversal_limit_words);
    }

    pub fn nestingLimit(self: ReaderOptions) u16 {
        return self.nesting_limit;
    }

    pub fn capabilityCountLimit(self: ReaderOptions) ?usize {
        return self.capability_count_limit;
    }

    pub fn hasCapabilityCountLimit(self: ReaderOptions) bool {
        return self.capability_count_limit != null;
    }

    pub fn matchesTraversalLimitWords(self: ReaderOptions, count: usize) bool {
        return self.traversal_limit_words == count;
    }

    pub fn matchesTraversalLimitBytes(self: ReaderOptions, count: usize) bool {
        return self.traversalLimitBytes() == count;
    }

    pub fn matchesNestingLimit(self: ReaderOptions, count: u16) bool {
        return self.nesting_limit == count;
    }

    pub fn matchesCapabilityCountLimit(self: ReaderOptions, count: usize) bool {
        return self.capability_count_limit != null and self.capability_count_limit.? == count;
    }
};

/// Schema-agnostic statistics collected during message validation.
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

    pub fn dataByteCount(self: MessageStats) usize {
        return wordsToBytesSaturating(self.data_words);
    }

    pub fn pointerWordCount(self: MessageStats) usize {
        return self.pointer_words;
    }

    pub fn pointerByteCount(self: MessageStats) usize {
        return wordsToBytesSaturating(self.pointer_words);
    }

    pub fn wordCount(self: MessageStats) usize {
        return self.total_words;
    }

    pub fn byteCount(self: MessageStats) usize {
        return wordsToBytesSaturating(self.total_words);
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

    pub fn matchesDataBytes(self: MessageStats, count: usize) bool {
        return self.dataByteCount() == count;
    }

    pub fn matchesPointerWords(self: MessageStats, count: usize) bool {
        return self.pointer_words == count;
    }

    pub fn matchesPointerBytes(self: MessageStats, count: usize) bool {
        return self.pointerByteCount() == count;
    }

    pub fn matchesWords(self: MessageStats, count: usize) bool {
        return self.total_words == count;
    }

    pub fn matchesBytes(self: MessageStats, count: usize) bool {
        return self.byteCount() == count;
    }

    pub fn matchesCapabilities(self: MessageStats, count: usize) bool {
        return self.capabilities == count;
    }

    pub fn maxCapabilityIndex(self: MessageStats) ?u32 {
        return self.max_capability_index;
    }

    pub fn hasMaxCapabilityIndex(self: MessageStats) bool {
        return self.max_capability_index != null;
    }

    pub fn matchesMaxCapabilityIndex(self: MessageStats, index: u32) bool {
        return self.max_capability_index != null and self.max_capability_index.? == index;
    }

    pub fn maxCapabilityCount(self: MessageStats) usize {
        if (self.max_capability_index) |index| {
            // Saturate for consistency with CapabilityPointer.maxCapabilityCount()
            // on 32-bit targets, where u32.max + 1 exceeds usize.
            return std.math.add(usize, @intCast(index), 1) catch std.math.maxInt(usize);
        }
        return 0;
    }

    pub fn matchesMaxCapabilityCount(self: MessageStats, count: usize) bool {
        return self.maxCapabilityCount() == count;
    }
};

/// Byte and word counts derived from `MessageStats`.
pub const MessageSize = struct {
    word_count: usize = 0,
    cap_count: usize = 0,

    pub fn wordCount(self: MessageSize) usize {
        return self.word_count;
    }

    pub fn byteCount(self: MessageSize) usize {
        return wordsToBytesSaturating(self.word_count);
    }

    pub fn capabilityCount(self: MessageSize) usize {
        return self.cap_count;
    }

    pub fn matchesWords(self: MessageSize, count: usize) bool {
        return self.word_count == count;
    }

    pub fn matchesBytes(self: MessageSize, count: usize) bool {
        return self.byteCount() == count;
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
