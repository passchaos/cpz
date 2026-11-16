const std = @import("std");

/// Zero a byte range with plain stores instead of `@memset`.
///
/// `@memset` lowers to the C library `memset`, whose `dc zva` fast path can be
/// pathologically slow on some aarch64 virtual machines (observed at roughly
/// 5 GB/s versus 80 GB/s for `memcpy`). Volatile stores keep this a store loop
/// on every target; the memory is still zeroed before any later read.
pub fn bytes(buffer: []u8) void {
    const Block = [16]u8;
    const zero = [_]u8{0} ** @sizeOf(Block);
    const block_ptr: [*]volatile Block = @ptrCast(buffer.ptr);
    var i: usize = 0;
    while (i + @sizeOf(Block) <= buffer.len) : (i += @sizeOf(Block)) {
        block_ptr[i / @sizeOf(Block)] = zero;
    }
    const byte_ptr: [*]volatile u8 = @ptrCast(buffer.ptr);
    while (i < buffer.len) : (i += 1) byte_ptr[i] = 0;
}

test "zero bytes covers every length and offset" {
    const testing = std.testing;
    var storage = [_]u8{0xaa} ** 64;
    const expected = [_]u8{0} ** 24;
    for (0..40) |offset| {
        for (0..24) |len| {
            @memset(&storage, 0xaa);
            bytes(storage[offset..][0..len]);
            try testing.expectEqualSlices(u8, expected[0..len], storage[offset..][0..len]);
            try testing.expectEqual(@as(u8, 0xaa), storage[offset + len]);
        }
    }
}
