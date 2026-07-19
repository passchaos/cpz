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
    var flat_view_buffer: [512]u8 = undefined;
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

        var flat_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.readMessageFromReader(std.testing.allocator, &flat_reader)) |message| {
            var owned = message;
            owned.deinit(std.testing.allocator);
        } else |_| {}

        var flat_view_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.readMessageViewFromReaderInto(&view_segments, &flat_view_buffer, &flat_view_reader)) |view| {
            var owned_view = view;
            owned_view.deinit(std.testing.allocator);
        } else |_| {}

        var packed_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.readPackedMessageFromReader(std.testing.allocator, &packed_reader)) |message| {
            var owned = message;
            owned.deinit(std.testing.allocator);
        } else |_| {}

        var packed_view_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.readPackedMessageViewFromReaderInto(&packed_view_segments, &packed_flat_buffer, &packed_view_reader)) |view| {
            var owned_view = view;
            owned_view.deinit(std.testing.allocator);
        } else |_| {}

        if (cpz.OwnedMessageReader.initFlat(std.testing.allocator, storage[0..len], .{})) |reader| {
            var owned_reader = reader;
            owned_reader.deinit(std.testing.allocator);
        } else |_| {}

        if (cpz.MessageReaderView.initFlatInto(&view_segments, storage[0..len], .{})) |reader| {
            var view_reader_value = reader;
            view_reader_value.deinit(std.testing.allocator);
        } else |_| {}

        if (cpz.MessageReaderView.initPackedInto(&packed_view_segments, &packed_flat_buffer, storage[0..len], .{})) |reader| {
            var view_reader_value = reader;
            view_reader_value.deinit(std.testing.allocator);
        } else |_| {}

        var owned_flat_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.OwnedMessageReader.initFromReader(std.testing.allocator, &owned_flat_reader, .{})) |reader| {
            var owned_reader = reader;
            owned_reader.deinit(std.testing.allocator);
        } else |_| {}

        var owned_packed_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.OwnedMessageReader.initPackedFromReader(std.testing.allocator, &owned_packed_reader, .{})) |reader| {
            var owned_reader = reader;
            owned_reader.deinit(std.testing.allocator);
        } else |_| {}

        var view_flat_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.MessageReaderView.initFromReaderInto(&view_segments, &flat_view_buffer, &view_flat_reader, .{})) |reader| {
            var view_reader_value = reader;
            view_reader_value.deinit(std.testing.allocator);
        } else |_| {}

        var view_packed_reader = std.Io.Reader.fixed(storage[0..len]);
        if (cpz.MessageReaderView.initPackedFromReaderInto(&packed_view_segments, &packed_flat_buffer, &view_packed_reader, .{})) |reader| {
            var view_reader_value = reader;
            view_reader_value.deinit(std.testing.allocator);
        } else |_| {}
    }
}
