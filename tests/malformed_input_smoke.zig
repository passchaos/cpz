const std = @import("std");
const cpz = @import("cpz");

fn fillDeterministic(seed: *u64, buf: []u8) void {
    for (buf) |*byte| {
        seed.* = seed.* *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(seed.* >> 56);
    }
}

test "malformed flat and packed inputs return errors instead of crashing" {
    var seed: u64 = 0x4350_5a5f_4655_5a5a;
    var storage: [512]u8 = undefined;
    var view_segments: [64]cpz.ConstSegment = undefined;
    var packed_view_segments: [64]cpz.ConstSegment = undefined;
    var packed_flat_buffer: [4096]u8 = undefined;

    for (0..2000) |case_index| {
        const len = case_index % storage.len;
        fillDeterministic(&seed, storage[0..len]);

        if (cpz.readFlatMessage(std.testing.allocator, storage[0..len])) |message| {
            var owned = message;
            owned.deinit(std.testing.allocator);
        } else |_| {}

        if (cpz.readFlatMessageViewInto(&view_segments, storage[0..len])) |view| {
            var owned_view = view;
            owned_view.deinit(std.testing.allocator);
        } else |_| {}

        if (cpz.readPackedMessage(std.testing.allocator, storage[0..len])) |message| {
            var owned = message;
            owned.deinit(std.testing.allocator);
        } else |_| {}

        if (cpz.readPackedMessageViewInto(&packed_view_segments, &packed_flat_buffer, storage[0..len])) |view| {
            var owned_view = view;
            owned_view.deinit(std.testing.allocator);
        } else |_| {}
    }
}
