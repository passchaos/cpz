const std = @import("std");
const serialize = @import("../../serialize.zig");
const wire = @import("../../wire.zig");
const message = @import("../../message.zig");
const mod_options = @import("../options.zig");
const mod_validate = @import("../validate.zig");

const BuilderOptions = message.BuilderOptions;
const CapabilityRegistry = message.CapabilityRegistry;
const CapabilityTable = message.CapabilityTable;
const ListBuilder = message.ListBuilder;
const ListReader = message.ListReader;
const MessageBuilder = message.MessageBuilder;
const MessageReader = message.MessageReader;
const MessageReaderView = message.MessageReaderView;
const MessageSize = message.MessageSize;
const MessageStats = message.MessageStats;
const Orphan = message.Orphan;
const Orphanage = message.Orphanage;
const OwnedMessageReader = message.OwnedMessageReader;
const PointerBuilder = message.PointerBuilder;
const ReaderOptions = message.ReaderOptions;
const StructBuilder = message.StructBuilder;
const StructReader = message.StructReader;
const toCanonicalSegmentBytes = message.toCanonicalSegmentBytes;
const toSingleSegmentFlatBytes = message.toSingleSegmentFlatBytes;
const wordsToBytesChecked = mod_options.wordsToBytesChecked;
const canonicalStructListSize = mod_validate.canonicalStructListSize;
const canonicalStructSize = mod_validate.canonicalStructSize;
const segmentIdFromIndex = mod_validate.segmentIdFromIndex;
const structEndWord = mod_validate.structEndWord;
const textElementCount = mod_validate.textElementCount;

test "reader options helper methods" {
    const testing = std.testing;

    const defaults = ReaderOptions{};
    try testing.expectEqual(@as(usize, 8 * 1024 * 1024), defaults.traversalLimitWords());
    try testing.expectEqual(@as(usize, 64 * 1024 * 1024), defaults.traversalLimitBytes());
    try testing.expectEqual(@as(u16, 64), defaults.nestingLimit());
    try testing.expectEqual(@as(?usize, null), defaults.capabilityCountLimit());
    try testing.expect(!defaults.hasCapabilityCountLimit());
    try testing.expect(defaults.matchesTraversalLimitWords(8 * 1024 * 1024));
    try testing.expect(defaults.matchesTraversalLimitBytes(64 * 1024 * 1024));
    try testing.expect(defaults.matchesNestingLimit(64));
    try testing.expect(!defaults.matchesCapabilityCountLimit(0));

    const huge = ReaderOptions{ .traversal_limit_words = std.math.maxInt(usize) };
    try testing.expectEqual(std.math.maxInt(usize), huge.traversalLimitBytes());
    try testing.expect(huge.matchesTraversalLimitBytes(std.math.maxInt(usize)));
    const huge_reader = MessageReader.init(&.{}, huge);
    try testing.expectEqual(std.math.maxInt(usize), huge_reader.traversalRemainingBytes());

    const custom = ReaderOptions{
        .traversal_limit_words = 10,
        .nesting_limit = 3,
        .capability_count_limit = 7,
    };
    try testing.expectEqual(@as(usize, 80), custom.traversalLimitBytes());
    try testing.expect(custom.hasCapabilityCountLimit());
    try testing.expect(custom.matchesTraversalLimitWords(10));
    try testing.expect(custom.matchesTraversalLimitBytes(80));
    try testing.expect(custom.matchesNestingLimit(3));
    try testing.expect(custom.matchesCapabilityCountLimit(7));
    try testing.expect(!custom.matchesCapabilityCountLimit(8));
}

test "message stats byte helper methods" {
    const testing = std.testing;

    const empty = MessageStats{};
    try testing.expectEqual(@as(usize, 0), empty.dataByteCount());
    try testing.expectEqual(@as(usize, 0), empty.pointerByteCount());
    try testing.expectEqual(@as(usize, 0), empty.byteCount());
    try testing.expect(empty.matchesBytes(0));
    try testing.expect(empty.isEmpty());
    try testing.expect(!empty.hasMaxCapabilityIndex());
    try testing.expect(!empty.matchesMaxCapabilityIndex(0));
    try testing.expect(empty.matchesMaxCapabilityCount(0));

    const stats = MessageStats{
        .pointer_slots = 4,
        .non_null_pointers = 3,
        .structs = 1,
        .lists = 2,
        .capabilities = 1,
        .max_capability_index = 3,
        .data_words = 5,
        .pointer_words = 7,
        .total_words = 12,
    };
    try testing.expectEqual(@as(usize, 40), stats.dataByteCount());
    try testing.expectEqual(@as(usize, 56), stats.pointerByteCount());
    try testing.expectEqual(@as(usize, 96), stats.byteCount());
    try testing.expect(stats.matchesDataBytes(40));
    try testing.expect(stats.matchesPointerBytes(56));
    try testing.expect(stats.matchesBytes(96));
    try testing.expect(!stats.matchesBytes(95));
    try testing.expectEqual(@as(usize, 4), stats.maxCapabilityCount());
    try testing.expect(stats.hasMaxCapabilityIndex());
    try testing.expect(stats.matchesMaxCapabilityIndex(3));
    try testing.expect(!stats.matchesMaxCapabilityIndex(4));
    try testing.expect(stats.matchesMaxCapabilityCount(4));
    try testing.expect(!stats.matchesMaxCapabilityCount(3));
    try testing.expectEqual(@as(usize, 96), stats.size().byteCount());
    const max_u32_capability_count = if (@bitSizeOf(usize) > 32)
        @as(usize, std.math.maxInt(u32)) + 1
    else
        std.math.maxInt(usize);
    try testing.expectEqual(max_u32_capability_count, (MessageStats{ .max_capability_index = std.math.maxInt(u32) }).maxCapabilityCount());

    const huge = MessageStats{
        .data_words = std.math.maxInt(usize),
        .pointer_words = std.math.maxInt(usize),
        .total_words = std.math.maxInt(usize),
    };
    try testing.expectEqual(std.math.maxInt(usize), huge.dataByteCount());
    try testing.expectEqual(std.math.maxInt(usize), huge.pointerByteCount());
    try testing.expectEqual(std.math.maxInt(usize), huge.byteCount());
    try testing.expect(huge.matchesBytes(std.math.maxInt(usize)));
    try testing.expectEqual(std.math.maxInt(usize), huge.size().byteCount());
}

test "message size byte helper methods" {
    const testing = std.testing;

    const empty = MessageSize{};
    try testing.expectEqual(@as(usize, 0), empty.byteCount());
    try testing.expect(empty.matchesBytes(0));
    try testing.expect(empty.isEmpty());

    const size = MessageSize{ .word_count = 5, .cap_count = 2 };
    try testing.expectEqual(@as(usize, 5), size.wordCount());
    try testing.expectEqual(@as(usize, 40), size.byteCount());
    try testing.expectEqual(@as(usize, 2), size.capabilityCount());
    try testing.expect(size.matchesWords(5));
    try testing.expect(size.matchesBytes(40));
    try testing.expect(!size.matchesBytes(41));
    try testing.expect(size.matchesCapabilities(2));
    try testing.expect(size.hasWords());
    try testing.expect(size.hasCapabilities());
}

test "capability table maps wire indexes to application handles" {
    const testing = std.testing;
    const handles = [_][]const u8{ "bootstrap", "logger", "store" };
    const table = CapabilityTable([]const u8).init(&handles);

    try testing.expectEqual(@as(usize, 3), table.len());
    try testing.expect(!table.isEmpty());
    try testing.expect(table.hasIndex(2));
    try testing.expect(!table.hasIndex(3));
    try testing.expectEqualStrings("logger", try table.get(1));
    try testing.expectEqualStrings("logger", table.getOrNull(1).?);
    try testing.expect(table.getOrNull(3) == null);
    try testing.expectError(error.InvalidCapabilityPointer, table.get(3));

    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 4 });
    defer builder.deinit();
    try builder.setRootCapability(2);
    try testing.expectEqualStrings("store", try table.getPointerBuilder(try builder.getRootPointer()));
    var null_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer null_builder.deinit();
    try testing.expectEqual(@as(?[]const u8, null), try table.getPointerBuilderOrNull(try null_builder.getRootPointer()));

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    try testing.expectEqualStrings("store", try table.getPointer(try reader.getRootPointer()));
    var null_reader = MessageReader.init(try null_builder.segmentsConst(), .{});
    try testing.expectEqual(@as(?[]const u8, null), try table.getPointerOrNull(try null_reader.getRootPointer()));
    const stats = try reader.validate();
    try testing.expect(table.satisfiesStats(stats));
    try table.validateStats(stats);

    const short_table = CapabilityTable([]const u8).init(handles[0..2]);
    try testing.expect(!short_table.satisfiesStats(stats));
    try testing.expectError(error.InvalidCapabilityPointer, short_table.validateStats(stats));

    const cap_list = try (try builder.getRootPointer()).initList(.pointer, 2);
    (try cap_list.getPointerElement(0)).setCapability(1);
    try cap_list.clearPointerElement(1);
    try testing.expectEqualStrings("logger", try table.getListBuilderElement(cap_list, 0));
    try testing.expectEqual(@as(?[]const u8, null), try table.getListBuilderElementOrNull(cap_list, 1));
    var list_reader_message = MessageReader.init(try builder.segmentsConst(), .{});
    const cap_list_reader = try (try list_reader_message.getRootPointer()).getList(.pointer);
    try testing.expectEqualStrings("logger", try table.getListElement(cap_list_reader, 0));
    try testing.expectEqual(@as(?[]const u8, null), try table.getListElementOrNull(cap_list_reader, 1));

    var orphan = (try builder.getRootPointer()).disown();
    defer orphan.release();
    try testing.expectError(error.InvalidPointerKind, table.getOrphan(orphan));
    var cap_orphan = try builder.newOrphanCapability(2);
    defer cap_orphan.release();
    try testing.expectEqualStrings("store", try table.getOrphan(cap_orphan));
    const null_orphan = Orphan{ .message = &null_builder, .segment_id = 0, .pointer_word_index = 0, .raw = 0 };
    try testing.expectEqual(@as(?[]const u8, null), try table.getOrphanOrNull(null_orphan));
}

test "capability registry assigns wire indexes for builders" {
    const testing = std.testing;
    var registry: CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(testing.allocator);

    var root_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 4 });
    defer root_builder.deinit();
    try testing.expectEqual(@as(u32, 0), try registry.registerRoot(testing.allocator, &root_builder, "root"));

    var root_reader = MessageReader.init(try root_builder.segmentsConst(), .{});
    try testing.expectEqualStrings("root", try registry.asTable().getPointer(try root_reader.getRootPointer()));

    var list_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer list_builder.deinit();
    const list = try list_builder.initRootList(.pointer, 2);
    try testing.expectEqual(@as(u32, 1), try registry.registerListElement(testing.allocator, list, 0, "first"));
    try testing.expectEqual(@as(u32, 2), try registry.registerListElement(testing.allocator, list, 1, "second"));
    try testing.expectEqual(@as(usize, 3), registry.len());
    try testing.expect(registry.hasIndex(2));
    try testing.expect(!registry.hasIndex(3));
    try testing.expectEqualStrings("second", try registry.get(2));
    try testing.expectEqualStrings("second", registry.getOrNull(2).?);
    try testing.expect(registry.getOrNull(3) == null);
    try testing.expectError(error.InvalidCapabilityPointer, registry.get(3));

    var list_reader_message = MessageReader.init(try list_builder.segmentsConst(), .{});
    const read_list = try list_reader_message.getRootList(.pointer);
    const table = registry.asTable();
    try testing.expectEqualStrings("first", try table.getListElement(read_list, 0));
    try testing.expectEqualStrings("second", try table.getListElement(read_list, 1));
    const list_stats = try list_reader_message.validate();
    try testing.expect(table.satisfiesStats(list_stats));
    try testing.expectEqual(@as(usize, 3), registry.maxCount());
    try testing.expect(registry.satisfiesStats(list_stats));
    try registry.validateStats(list_stats);
}

test "builder options helper methods" {
    const testing = std.testing;

    const defaults = BuilderOptions{};
    try testing.expectEqual(@as(usize, 1024), defaults.firstSegmentWords());
    try testing.expectEqual(@as(usize, 8192), defaults.firstSegmentBytes());
    try testing.expectEqual(@as(usize, 1024), defaults.nextSegmentMinWords());
    try testing.expectEqual(@as(usize, 8192), defaults.nextSegmentMinBytes());
    try testing.expect(defaults.matchesFirstSegmentWords(1024));
    try testing.expect(defaults.matchesFirstSegmentBytes(8192));
    try testing.expect(defaults.matchesNextSegmentMinWords(1024));
    try testing.expect(defaults.matchesNextSegmentMinBytes(8192));

    const custom = BuilderOptions{
        .first_segment_words = 5,
        .next_segment_min_words = 9,
    };
    try testing.expectEqual(@as(usize, 5), custom.firstSegmentWords());
    try testing.expectEqual(@as(usize, 40), custom.firstSegmentBytes());
    try testing.expectEqual(@as(usize, 9), custom.nextSegmentMinWords());
    try testing.expectEqual(@as(usize, 72), custom.nextSegmentMinBytes());
    try testing.expect(custom.matchesFirstSegmentWords(5));
    try testing.expect(custom.matchesFirstSegmentBytes(40));
    try testing.expect(custom.matchesNextSegmentMinWords(9));
    try testing.expect(custom.matchesNextSegmentMinBytes(72));
    try testing.expect(!custom.matchesFirstSegmentWords(6));
    try testing.expect(!custom.matchesFirstSegmentBytes(48));
    try testing.expect(!custom.matchesNextSegmentMinWords(10));
    try testing.expect(!custom.matchesNextSegmentMinBytes(80));

    const huge = BuilderOptions{
        .first_segment_words = std.math.maxInt(usize),
        .next_segment_min_words = std.math.maxInt(usize),
    };
    try testing.expectEqual(std.math.maxInt(usize), huge.firstSegmentBytes());
    try testing.expectEqual(std.math.maxInt(usize), huge.nextSegmentMinBytes());
    try testing.expect(huge.matchesFirstSegmentBytes(std.math.maxInt(usize)));
    try testing.expect(huge.matchesNextSegmentMinBytes(std.math.maxInt(usize)));
    try testing.expectError(error.SerializedSizeOverflow, wordsToBytesChecked(std.math.maxInt(usize)));
    try testing.expectEqual(@as(u32, 0), try segmentIdFromIndex(0));
    try testing.expectEqual(std.math.maxInt(u32), try segmentIdFromIndex(std.math.maxInt(u32)));
    if (@bitSizeOf(usize) > @bitSizeOf(u32)) {
        try testing.expectError(error.MessageTooLarge, segmentIdFromIndex(@as(usize, std.math.maxInt(u32)) + 1));
    }
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
    try testing.expectEqual(@as(usize, 8), builder.firstSegmentWords());
    try testing.expectEqual(@as(usize, 64), builder.firstSegmentBytes());
    try testing.expect(builder.matchesFirstSegmentWords(8));
    try testing.expect(builder.matchesFirstSegmentBytes(64));
    try testing.expectEqual(@as(usize, 1024), builder.nextSegmentMinWords());
    try testing.expectEqual(@as(usize, 8192), builder.nextSegmentMinBytes());
    try testing.expect(builder.matchesNextSegmentMinWords(1024));
    try testing.expect(builder.matchesNextSegmentMinBytes(8192));

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
    try testing.expectEqual(packed_bytes.len, try builder.packedSize());
    var builder_packed_table_buffer: [8]u8 = undefined;
    try testing.expectEqual(packed_bytes.len, try builder.packedSizeWithTableBuffer(&builder_packed_table_buffer));
    var builder_packed_buffer: [128]u8 = undefined;
    const builder_packed_len = try builder.toPackedBytesInto(&builder_packed_table_buffer, &builder_packed_buffer);
    try testing.expectEqual(packed_bytes.len, builder_packed_len);
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
    const owned_root_stats = try owned_flat.getRootPointerStats();
    try testing.expect(owned_root_stats.total_words > 0);
    const owned_root_stats_with_options = try owned_flat.getRootPointerStatsWithOptions(.{ .capability_count_limit = 100 });
    try testing.expectEqual(owned_root_stats.total_words, owned_root_stats_with_options.total_words);
    const owned_root_size = try owned_flat.getRootPointerTotalSize();
    try testing.expectEqual(owned_root_stats.size().word_count, owned_root_size.word_count);
    const owned_root_size_with_options = try owned_flat.getRootPointerTotalSizeWithOptions(.{ .capability_count_limit = 100 });
    try testing.expectEqual(owned_root_size.word_count, owned_root_size_with_options.word_count);
    try testing.expectEqual(@as(usize, 1), owned_flat.segmentCount());
    try testing.expect((try owned_flat.segmentByteLen(0)) > 0);
    try testing.expect((try owned_flat.segmentWordLen(0)) > 0);
    try testing.expectEqual(flat.len, try owned_flat.serializedSize());
    try testing.expectEqual(flat.len / wire.bytes_per_word, try owned_flat.serializedSizeInWords());
    try testing.expectEqual(@as(usize, 8 * 1024 * 1024), owned_flat.traversalLimitWords());
    try testing.expectEqual(@as(usize, 64 * 1024 * 1024), owned_flat.traversalLimitBytes());
    try testing.expect(owned_flat.matchesTraversalLimitWords(8 * 1024 * 1024));
    try testing.expect(owned_flat.matchesTraversalLimitBytes(64 * 1024 * 1024));
    try testing.expectEqual(@as(u16, 64), owned_flat.nestingLimit());
    try testing.expect(owned_flat.matchesNestingLimit(64));
    try testing.expectEqual(@as(?usize, null), owned_flat.capabilityCountLimit());
    try testing.expect(!owned_flat.hasCapabilityCountLimit());
    try testing.expect(!owned_flat.matchesCapabilityCountLimit(0));
    const owned_table = try owned_flat.serializeSegmentTable(testing.allocator);
    defer testing.allocator.free(owned_table);
    try testing.expectEqual((try serialize.segmentTableWords(owned_flat.segmentCount())) * wire.bytes_per_word, owned_table.len);
    const owned_flat_bytes = try owned_flat.toFlatBytes(testing.allocator);
    defer testing.allocator.free(owned_flat_bytes);
    try testing.expectEqualSlices(u8, flat, owned_flat_bytes);
    var owned_flat_into_buffer: [128]u8 = undefined;
    const owned_flat_into_len = try owned_flat.toFlatBytesInto(&owned_flat_into_buffer);
    try testing.expectEqualSlices(u8, flat, owned_flat_into_buffer[0..owned_flat_into_len]);
    const owned_packed_bytes = try owned_flat.toPackedBytes(testing.allocator);
    defer testing.allocator.free(owned_packed_bytes);
    try testing.expect((try owned_flat.maxPackedSize()) >= owned_packed_bytes.len);
    try testing.expectEqual(owned_packed_bytes.len, try owned_flat.packedSize(testing.allocator));
    var owned_packed_into_table: [8]u8 = undefined;
    try testing.expectEqual(owned_packed_bytes.len, try owned_flat.packedSizeWithTableBuffer(&owned_packed_into_table));
    var owned_packed_into_buffer: [128]u8 = undefined;
    const owned_packed_into_len = try owned_flat.toPackedBytesInto(&owned_packed_into_table, &owned_packed_into_buffer);
    try testing.expectEqual(owned_packed_bytes.len, owned_packed_into_len);
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
    try testing.expectEqual(@as(usize, "owned default".len), try empty_owned.getRootTextDefaultByteCount("owned default"));
    try testing.expect(try empty_owned.rootTextDefaultMatchesBytes("owned default", "owned default".len));
    try testing.expect(!try empty_owned.rootTextDefaultMatchesBytes("owned default", "owned default".len + 1));
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2 }, try empty_owned.getRootDataDefault(&[_]u8{ 1, 2 }));
    try testing.expectEqual(@as(usize, 2), try empty_owned.getRootDataDefaultByteCount(&[_]u8{ 1, 2 }));
    try testing.expect(try empty_owned.rootDataDefaultMatchesBytes(&[_]u8{ 1, 2 }, 2));
    try testing.expect(!try empty_owned.rootDataDefaultMatchesBytes(&[_]u8{ 1, 2 }, 3));

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer data_builder.deinit();
    try data_builder.setRootData(&[_]u8{ 4, 5 });
    const data_flat = try data_builder.toFlatBytes();
    defer testing.allocator.free(data_flat);
    var data_owned = try OwnedMessageReader.initFlat(testing.allocator, data_flat, .{});
    defer data_owned.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, &[_]u8{ 4, 5 }, try data_owned.getRootDataDefault(&[_]u8{ 1, 2 }));
    try testing.expectEqual(@as(usize, 2), try data_owned.getRootDataDefaultByteCount(&[_]u8{ 1, 2 }));
    try testing.expect(try data_owned.rootDataDefaultMatchesBytes(&[_]u8{ 1, 2 }, 2));
    try testing.expect(!try data_owned.rootDataDefaultMatchesBytes(&[_]u8{ 1, 2 }, 3));

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer text_builder.deinit();
    try text_builder.setRootText("owned root text");
    const text_flat = try text_builder.toFlatBytes();
    defer testing.allocator.free(text_flat);
    var text_owned = try OwnedMessageReader.initFlat(testing.allocator, text_flat, .{});
    defer text_owned.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, "owned root text", try text_owned.getRootTextDefault("ignored"));
    try testing.expectEqual(@as(usize, "owned root text".len), try text_owned.getRootTextDefaultByteCount("ignored"));
    try testing.expect(try text_owned.rootTextDefaultMatchesBytes("ignored", "owned root text".len));
    try testing.expect(!try text_owned.rootTextDefaultMatchesBytes("ignored", "ignored".len));

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
    const view_root_stats = try view.getRootPointerStats();
    try testing.expect(view_root_stats.total_words > 0);
    const view_root_stats_with_options = try view.getRootPointerStatsWithOptions(.{ .capability_count_limit = 100 });
    try testing.expectEqual(view_root_stats.total_words, view_root_stats_with_options.total_words);
    const view_root_size = try view.getRootPointerTotalSize();
    try testing.expectEqual(view_root_stats.size().word_count, view_root_size.word_count);
    const view_root_size_with_options = try view.getRootPointerTotalSizeWithOptions(.{ .capability_count_limit = 100 });
    try testing.expectEqual(view_root_size.word_count, view_root_size_with_options.word_count);
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
    const view_packed_bytes = std.Io.Writer.buffered(&view_packed_writer);
    try testing.expect((try view.maxPackedSize()) >= view_packed_bytes.len);
    try testing.expectEqual(view_packed_bytes.len, try view.packedSize(testing.allocator));
    var view_packed_into_table: [8]u8 = undefined;
    try testing.expectEqual(view_packed_bytes.len, try view.packedSizeWithTableBuffer(&view_packed_into_table));
    var view_packed_into_buffer: [128]u8 = undefined;
    const view_packed_into_len = try view.toPackedBytesInto(&view_packed_into_table, &view_packed_into_buffer);
    try testing.expectEqual(view_packed_bytes.len, view_packed_into_len);
    try testing.expectEqualSlices(u8, view_packed_bytes, view_packed_into_buffer[0..view_packed_into_len]);
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
    try testing.expectEqual(@as(usize, "view default".len), try empty_view.getRootTextDefaultByteCount("view default"));
    try testing.expect(try empty_view.rootTextDefaultMatchesBytes("view default", "view default".len));
    try testing.expect(!try empty_view.rootTextDefaultMatchesBytes("view default", "view default".len + 1));

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer text_builder.deinit();
    try text_builder.setRootText("view root text");
    const text_flat = try text_builder.toFlatBytes();
    defer testing.allocator.free(text_flat);
    var text_view = try MessageReaderView.initFlat(testing.allocator, text_flat, .{});
    defer text_view.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, "view root text", try text_view.getRootTextDefault("ignored"));
    try testing.expectEqual(@as(usize, "view root text".len), try text_view.getRootTextDefaultByteCount("ignored"));
    try testing.expect(try text_view.rootTextDefaultMatchesBytes("ignored", "view root text".len));
    try testing.expect(!try text_view.rootTextDefaultMatchesBytes("ignored", "ignored".len));
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
    try testing.expectEqual(@as(usize, 1), try textElementCount(0));
    try testing.expectError(error.MessageTooLarge, textElementCount(std.math.maxInt(usize)));
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

test "reader accepts double-far pointers to empty object at segment end" {
    const testing = std.testing;

    const root_words = [_]wire.Word{try wire.encodeFar(true, 0, 1)};
    const landing_words = [_]wire.Word{
        try wire.encodeFar(false, 0, 2),
        try wire.encodeList(0, .void, 7),
    };
    const empty_target_words = [_]wire.Word{};
    const segments = [_]serialize.ConstSegment{
        std.mem.sliceAsBytes(&root_words),
        std.mem.sliceAsBytes(&landing_words),
        std.mem.sliceAsBytes(&empty_target_words),
    };

    var reader = MessageReader.init(&segments, .{});
    const root = try reader.getRootList(.void);
    try testing.expectEqual(@as(usize, 7), root.len());
    try testing.expectEqual(@as(wire.ElementSize, .void), root.elementSize());

    var validating_reader = MessageReader.init(&segments, .{});
    const stats = try validating_reader.validate();
    try testing.expectEqual(@as(usize, 1), stats.pointer_slots);
    try testing.expectEqual(@as(usize, 1), stats.non_null_pointers);
    try testing.expectEqual(@as(usize, 1), stats.lists);
    try testing.expectEqual(@as(usize, 0), stats.total_words);
}

test "primitive and struct lists" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    try testing.expectEqual(wire.StructSize{ .data_words = 0, .pointer_count = 2 }, root.size());
    try testing.expectEqual(@as(u16, 0), root.dataWordCount());
    try testing.expectEqual(@as(u16, 2), root.pointerCount());
    try testing.expectEqual(@as(usize, 2), root.totalWords());
    try testing.expectEqual(@as(usize, 0), root.dataByteCount());
    try testing.expectEqual(@as(usize, 16), root.pointerByteCount());
    try testing.expectEqual(@as(usize, 16), root.totalByteCount());
    try testing.expect(root.matchesSize(.{ .data_words = 0, .pointer_count = 2 }));
    try testing.expect(root.matchesDataWords(0));
    try testing.expect(root.matchesPointerCount(2));
    try testing.expect(root.matchesTotalWords(2));
    try testing.expect(root.matchesDataBytes(0));
    try testing.expect(root.matchesPointerBytes(16));
    try testing.expect(root.matchesTotalBytes(16));
    try testing.expect(!root.matchesSize(.{ .data_words = 1, .pointer_count = 2 }));
    try testing.expect(!root.matchesPointerBytes(8));
    try testing.expect(!root.size().isEmpty());
    try testing.expect(!root.isEmpty());
    try testing.expect(!root.size().hasDataWords());
    try testing.expect(!root.hasDataWords());
    try testing.expect(root.size().hasPointers());
    try testing.expect(root.hasPointers());
    try testing.expect(root.size().matchesDataWords(0));
    try testing.expect(root.size().matchesPointerCount(2));
    try testing.expectEqual(@as(u16, 0), root.size().dataWordCount());
    try testing.expectEqual(@as(u16, 2), root.size().pointerCount());
    const nums = try (try root.getPointerField(0)).initList(.two_bytes, 3);
    try testing.expectEqual(wire.ElementSize.two_bytes, nums.elementSize());
    try testing.expect(nums.matchesLen(3));
    try testing.expect(nums.matchesElementSize(.two_bytes));
    try testing.expectEqual(@as(usize, 16), nums.elementBitCount());
    try testing.expectEqual(@as(usize, 2), try nums.elementByteCount());
    try testing.expectError(error.UnsupportedElementSize, nums.elementWordCount());
    try testing.expectEqual(@as(usize, 48), try nums.contentBitCount());
    try testing.expectEqual(@as(usize, 6), try nums.contentByteCount());
    try testing.expectEqual(@as(usize, 1), try nums.contentWordCount());
    try testing.expect(nums.matchesElementBits(16));
    try testing.expect(nums.matchesElementBytes(2));
    try testing.expect(!nums.matchesElementWords(1));
    try testing.expect(nums.matchesContentBits(48));
    try testing.expect(nums.matchesContentBytes(6));
    try testing.expect(nums.matchesContentWords(1));
    try nums.setUInt16(0, 10);
    try nums.setUInt16(1, 20);
    try nums.setUInt16(2, 30);

    const people = try (try root.getPointerField(1)).initStructList(2, .{ .data_words = 1, .pointer_count = 1 });
    try testing.expectEqual(wire.ElementSize.composite, people.elementSize());
    try testing.expect(people.matchesLen(2));
    try testing.expect(people.matchesElementSize(.composite));
    try testing.expectEqual(@as(usize, 128), people.elementBitCount());
    try testing.expectEqual(@as(usize, 16), try people.elementByteCount());
    try testing.expectEqual(@as(usize, 2), try people.elementWordCount());
    try testing.expectEqual(@as(usize, 256), try people.contentBitCount());
    try testing.expectEqual(@as(usize, 32), try people.contentByteCount());
    try testing.expectEqual(@as(usize, 4), try people.contentWordCount());
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, people.structElementSize());
    try testing.expect(people.matchesStructElementSize(.{ .data_words = 1, .pointer_count = 1 }));
    try testing.expectEqual(@as(u16, 1), people.structElementDataWordCount());
    try testing.expectEqual(@as(u16, 1), people.structElementPointerCount());
    try testing.expectEqual(@as(usize, 2), people.structElementTotalWords());
    try testing.expectEqual(@as(usize, 8), people.structElementDataByteCount());
    try testing.expectEqual(@as(usize, 8), people.structElementPointerByteCount());
    try testing.expectEqual(@as(usize, 16), people.structElementTotalByteCount());
    try testing.expect(people.matchesStructElementDataWords(1));
    try testing.expect(people.matchesStructElementPointerCount(1));
    try testing.expect(people.matchesStructElementTotalWords(2));
    try testing.expect(people.matchesStructElementDataBytes(8));
    try testing.expect(people.matchesStructElementPointerBytes(8));
    try testing.expect(people.matchesStructElementTotalBytes(16));
    try testing.expect(!people.matchesStructElementSize(.{ .data_words = 1, .pointer_count = 0 }));
    try testing.expect(!people.matchesStructElementTotalBytes(8));
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
    try testing.expectEqual(@as(u16, 0), r.dataWordCount());
    try testing.expectEqual(@as(u16, 2), r.pointerCount());
    try testing.expectEqual(@as(usize, 2), r.totalWords());
    try testing.expectEqual(@as(usize, 0), r.dataByteCount());
    try testing.expectEqual(@as(usize, 16), r.pointerByteCount());
    try testing.expectEqual(@as(usize, 16), r.totalByteCount());
    try testing.expect(r.matchesSize(.{ .data_words = 0, .pointer_count = 2 }));
    try testing.expect(r.matchesDataWords(0));
    try testing.expect(r.matchesPointerCount(2));
    try testing.expect(r.matchesTotalWords(2));
    try testing.expect(r.matchesDataBytes(0));
    try testing.expect(r.matchesPointerBytes(16));
    try testing.expect(r.matchesTotalBytes(16));
    try testing.expect(!r.matchesSize(.{ .data_words = 2, .pointer_count = 2 }));
    try testing.expect(!r.matchesTotalBytes(8));
    try testing.expect(!r.isEmpty());
    try testing.expect(!r.hasDataWords());
    try testing.expect(r.hasPointers());
    const read_nums = try r.getPointerField(0).getList(.two_bytes);
    try testing.expectEqual(@as(usize, 3), read_nums.len());
    try testing.expectEqual(wire.ElementSize.two_bytes, read_nums.elementSize());
    try testing.expect(read_nums.matchesLen(3));
    try testing.expect(read_nums.matchesElementSize(.two_bytes));
    try testing.expectEqual(@as(usize, 16), read_nums.elementBitCount());
    try testing.expectEqual(@as(usize, 2), try read_nums.elementByteCount());
    try testing.expectError(error.UnsupportedElementSize, read_nums.elementWordCount());
    try testing.expectEqual(@as(usize, 48), try read_nums.contentBitCount());
    try testing.expectEqual(@as(usize, 6), try read_nums.contentByteCount());
    try testing.expectEqual(@as(usize, 1), try read_nums.contentWordCount());
    try testing.expect(read_nums.matchesElementBits(16));
    try testing.expect(read_nums.matchesElementBytes(2));
    try testing.expect(!read_nums.matchesElementWords(1));
    try testing.expect(read_nums.matchesContentBits(48));
    try testing.expect(read_nums.matchesContentBytes(6));
    try testing.expect(read_nums.matchesContentWords(1));
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
    try testing.expect(read_people.matchesLen(2));
    try testing.expect(read_people.matchesElementSize(.composite));
    try testing.expectEqual(@as(usize, 128), read_people.elementBitCount());
    try testing.expectEqual(@as(usize, 16), try read_people.elementByteCount());
    try testing.expectEqual(@as(usize, 2), try read_people.elementWordCount());
    try testing.expectEqual(@as(usize, 256), try read_people.contentBitCount());
    try testing.expectEqual(@as(usize, 32), try read_people.contentByteCount());
    try testing.expectEqual(@as(usize, 4), try read_people.contentWordCount());
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, read_people.structElementSize());
    try testing.expect(read_people.matchesStructElementSize(.{ .data_words = 1, .pointer_count = 1 }));
    try testing.expectEqual(@as(u16, 1), read_people.structElementDataWordCount());
    try testing.expectEqual(@as(u16, 1), read_people.structElementPointerCount());
    try testing.expectEqual(@as(usize, 2), read_people.structElementTotalWords());
    try testing.expectEqual(@as(usize, 8), read_people.structElementDataByteCount());
    try testing.expectEqual(@as(usize, 8), read_people.structElementPointerByteCount());
    try testing.expectEqual(@as(usize, 16), read_people.structElementTotalByteCount());
    try testing.expect(read_people.matchesStructElementDataWords(1));
    try testing.expect(read_people.matchesStructElementPointerCount(1));
    try testing.expect(read_people.matchesStructElementTotalWords(2));
    try testing.expect(read_people.matchesStructElementDataBytes(8));
    try testing.expect(read_people.matchesStructElementPointerBytes(8));
    try testing.expect(read_people.matchesStructElementTotalBytes(16));
    try testing.expect(!read_people.matchesStructElementSize(.{ .data_words = 0, .pointer_count = 1 }));
    try testing.expect(!read_people.matchesStructElementTotalBytes(8));
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

test "ListBuilder.setAll copies primitive slices" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 4 });

    const u32s = try (try root.getPointerField(0)).initList(.four_bytes, 4);
    try u32s.setAll(u32, &[_]u32{ 1, 2, 0xdeadbeef, 4 });
    try testing.expectEqual(@as(u32, 0xdeadbeef), try u32s.getUInt32(2));

    const u16s = try (try root.getPointerField(1)).initList(.two_bytes, 3);
    try u16s.setAll(u16, &[_]u16{ 10, 20, 30 });
    try testing.expectEqual(@as(u16, 20), try u16s.getUInt16(1));
    try testing.expectError(error.IncompatibleListShape, u16s.setAll(u32, &[_]u32{ 1, 2, 3 }));
    try testing.expectError(error.PointerOutOfBounds, u16s.setAll(u16, &[_]u16{ 1, 2 }));

    const floats = try (try root.getPointerField(2)).initList(.four_bytes, 2);
    try floats.setAll(f32, &[_]f32{ 1.5, -2.25 });
    try testing.expectEqual(@as(f32, 1.5), try floats.getFloat32(0));

    const bits = try (try root.getPointerField(3)).initList(.bit, 5);
    try bits.setAll(bool, &[_]bool{ true, false, true, true, false });
    try testing.expect(try bits.getBool(0));
    try testing.expect(!try bits.getBool(1));
    try testing.expect(try bits.getBool(3));
}

test "ListBuilder.setSlice and ListReader.getSlice copy ranges" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 2 });

    const u32s = try (try root.getPointerField(0)).initList(.four_bytes, 5);
    try u32s.setSlice(1, u32, &[_]u32{ 10, 20, 30 });
    try testing.expectEqual(@as(u32, 0), try u32s.getUInt32(0));
    try testing.expectEqual(@as(u32, 10), try u32s.getUInt32(1));
    try testing.expectEqual(@as(u32, 30), try u32s.getUInt32(3));
    try testing.expectEqual(@as(u32, 0), try u32s.getUInt32(4));
    try testing.expectError(error.PointerOutOfBounds, u32s.setSlice(4, u32, &[_]u32{ 1, 2 }));
    try testing.expectError(error.PointerOutOfBounds, u32s.setSlice(6, u32, &[_]u32{1}));

    const bits = try (try root.getPointerField(1)).initList(.bit, 6);
    try bits.setSlice(2, bool, &[_]bool{ true, false, true });
    try testing.expect(!try bits.getBool(1));
    try testing.expect(try bits.getBool(2));
    try testing.expect(!try bits.getBool(3));
    try testing.expect(try bits.getBool(4));

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    var out: [2]u32 = undefined;
    try (try read_root.getPointerField(0).getList(.four_bytes)).getSlice(2, u32, &out);
    try testing.expectEqualSlices(u32, &[_]u32{ 20, 30 }, &out);
    try testing.expectError(error.PointerOutOfBounds, (try read_root.getPointerField(0).getList(.four_bytes)).getSlice(4, u32, &out));

    var bool_out: [2]bool = undefined;
    try (try read_root.getPointerField(1).getList(.bit)).getSlice(2, bool, &bool_out);
    try testing.expectEqualSlices(bool, &[_]bool{ true, false }, &bool_out);
}

test "ListReader.getAll copies primitive slices" {
    const testing = std.testing;
    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 4 });

    const u32s = try (try root.getPointerField(0)).initList(.four_bytes, 4);
    try u32s.setAll(u32, &[_]u32{ 1, 2, 0xdeadbeef, 4 });
    const u16s = try (try root.getPointerField(1)).initList(.two_bytes, 3);
    try u16s.setAll(u16, &[_]u16{ 10, 20, 30 });
    const floats = try (try root.getPointerField(2)).initList(.four_bytes, 2);
    try floats.setAll(f32, &[_]f32{ 1.5, -2.25 });
    const bits = try (try root.getPointerField(3)).initList(.bit, 5);
    try bits.setAll(bool, &[_]bool{ true, false, true, true, false });

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try reader.getRoot();

    var u32_out: [4]u32 = undefined;
    try (try read_root.getPointerField(0).getList(.four_bytes)).getAll(u32, &u32_out);
    try testing.expectEqualSlices(u32, &[_]u32{ 1, 2, 0xdeadbeef, 4 }, &u32_out);

    var u16_out: [3]u16 = undefined;
    try (try read_root.getPointerField(1).getList(.two_bytes)).getAll(u16, &u16_out);
    try testing.expectEqualSlices(u16, &[_]u16{ 10, 20, 30 }, &u16_out);

    var float_out: [2]f32 = undefined;
    try (try read_root.getPointerField(2).getList(.four_bytes)).getAll(f32, &float_out);
    try testing.expectEqualSlices(f32, &[_]f32{ 1.5, -2.25 }, &float_out);

    var bool_out: [5]bool = undefined;
    try (try read_root.getPointerField(3).getList(.bit)).getAll(bool, &bool_out);
    try testing.expectEqualSlices(bool, &[_]bool{ true, false, true, true, false }, &bool_out);

    var too_short: [2]u32 = undefined;
    try testing.expectError(error.PointerOutOfBounds, (try read_root.getPointerField(0).getList(.four_bytes)).getAll(u32, &too_short));
    var wrong_shape: [3]u32 = undefined;
    try testing.expectError(error.IncompatibleListShape, (try read_root.getPointerField(1).getList(.two_bytes)).getAll(u32, &wrong_shape));
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
    try testing.expectEqual(@as(usize, 2), try builder.getRootListLen(.two_bytes));
    try testing.expect(try builder.rootListMatchesLen(.two_bytes, 2));
    try testing.expect(!try builder.rootListIsEmpty(.two_bytes));
    try testing.expect(try builder.rootListHasIndex(.two_bytes, 1));
    try testing.expect(!try builder.rootListHasIndex(.two_bytes, 2));
    try testing.expectEqual(@as(usize, 0), try builder.getRootListFirstIndex(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try builder.getRootListLastIndex(.two_bytes));
    try testing.expectEqual(wire.ElementSize.two_bytes, try builder.getRootListElementSize(.two_bytes));
    try testing.expect(try builder.rootListMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try builder.getRootListElementBitCount(.two_bytes));
    try testing.expect(try builder.rootListMatchesElementBits(.two_bytes, 16));
    try testing.expectEqual(@as(usize, 2), try builder.getRootListElementByteCount(.two_bytes));
    try testing.expect(try builder.rootListMatchesElementBytes(.two_bytes, 2));
    try testing.expectError(error.UnsupportedElementSize, builder.getRootListElementWordCount(.two_bytes));
    try testing.expect(!try builder.rootListMatchesElementWords(.two_bytes, 1));
    try testing.expectEqual(@as(usize, 32), try builder.getRootListContentBitCount(.two_bytes));
    try testing.expect(try builder.rootListMatchesContentBits(.two_bytes, 32));
    try testing.expectEqual(@as(usize, 4), try builder.getRootListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try builder.getRootListContentWordCount(.two_bytes));
    try testing.expect(try builder.rootListMatchesContentBytes(.two_bytes, 4));
    try testing.expect(try builder.rootListMatchesContentWords(.two_bytes, 1));
    const bools = try (try builder.getRootPointer()).initList(.bit, 5);
    try testing.expect(bools.matchesLen(5));
    try testing.expect(bools.matchesElementSize(.bit));
    try testing.expectEqual(@as(usize, 1), bools.elementBitCount());
    try testing.expectError(error.UnsupportedElementSize, bools.elementByteCount());
    try testing.expectError(error.UnsupportedElementSize, bools.elementWordCount());
    try testing.expectEqual(@as(usize, 5), try bools.contentBitCount());
    try testing.expectEqual(@as(usize, 1), try bools.contentByteCount());
    try testing.expectEqual(@as(usize, 1), try bools.contentWordCount());
    try testing.expect(bools.matchesElementBits(1));
    try testing.expect(!bools.matchesElementBytes(1));
    try testing.expect(bools.matchesContentBits(5));
    try testing.expect(bools.matchesContentBytes(1));
    try testing.expect(bools.matchesContentWords(1));
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
    try testing.expect(read_bools.matchesLen(5));
    try testing.expect(read_bools.matchesElementSize(.bit));
    try testing.expectEqual(@as(usize, 1), read_bools.elementBitCount());
    try testing.expectError(error.UnsupportedElementSize, read_bools.elementByteCount());
    try testing.expectError(error.UnsupportedElementSize, read_bools.elementWordCount());
    try testing.expectEqual(@as(usize, 5), try read_bools.contentBitCount());
    try testing.expectEqual(@as(usize, 1), try read_bools.contentByteCount());
    try testing.expectEqual(@as(usize, 1), try read_bools.contentWordCount());
    try testing.expect(read_bools.matchesElementBits(1));
    try testing.expect(!read_bools.matchesElementBytes(1));
    try testing.expect(read_bools.matchesContentBits(5));
    try testing.expect(read_bools.matchesContentBytes(1));
    try testing.expect(read_bools.matchesContentWords(1));
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
    try testing.expectEqual(@as(usize, 2), try root_ptr_builder.getListLen(.two_bytes));
    try testing.expect(try root_ptr_builder.listMatchesLen(.two_bytes, 2));
    try testing.expect(!try root_ptr_builder.listIsEmpty(.two_bytes));
    try testing.expect(try root_ptr_builder.listHasIndex(.two_bytes, 1));
    try testing.expect(!try root_ptr_builder.listHasIndex(.two_bytes, 2));
    try testing.expectEqual(@as(usize, 0), try root_ptr_builder.getListFirstIndex(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try root_ptr_builder.getListLastIndex(.two_bytes));
    try testing.expectEqual(wire.ElementSize.two_bytes, try root_ptr_builder.getListElementSize(.two_bytes));
    try testing.expect(try root_ptr_builder.listMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try root_ptr_builder.getListElementBitCount(.two_bytes));
    try testing.expect(try root_ptr_builder.listMatchesElementBits(.two_bytes, 16));
    try testing.expectEqual(@as(usize, 2), try root_ptr_builder.getListElementByteCount(.two_bytes));
    try testing.expect(try root_ptr_builder.listMatchesElementBytes(.two_bytes, 2));
    try testing.expectError(error.UnsupportedElementSize, root_ptr_builder.getListElementWordCount(.two_bytes));
    try testing.expect(!try root_ptr_builder.listMatchesElementWords(.two_bytes, 1));
    try testing.expectEqual(@as(usize, 32), try root_ptr_builder.getListContentBitCount(.two_bytes));
    try testing.expect(try root_ptr_builder.listMatchesContentBits(.two_bytes, 32));
    try testing.expectEqual(@as(usize, 4), try root_ptr_builder.getListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try root_ptr_builder.getListContentWordCount(.two_bytes));
    try testing.expect(try root_ptr_builder.listMatchesContentBytes(.two_bytes, 4));
    try testing.expect(try root_ptr_builder.listMatchesContentWords(.two_bytes, 1));

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
    try testing.expectEqual(@as(usize, 2), try reader.getRootListLen(.two_bytes));
    try testing.expect(try reader.rootListMatchesLen(.two_bytes, 2));
    try testing.expect(!try reader.rootListIsEmpty(.two_bytes));
    try testing.expect(try reader.rootListHasIndex(.two_bytes, 1));
    try testing.expect(!try reader.rootListHasIndex(.two_bytes, 2));
    try testing.expectEqual(@as(usize, 0), try reader.getRootListFirstIndex(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try reader.getRootListLastIndex(.two_bytes));
    try testing.expectEqual(wire.ElementSize.two_bytes, try reader.getRootListElementSize(.two_bytes));
    try testing.expect(try reader.rootListMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try reader.getRootListElementBitCount(.two_bytes));
    try testing.expect(try reader.rootListMatchesElementBits(.two_bytes, 16));
    try testing.expectEqual(@as(usize, 2), try reader.getRootListElementByteCount(.two_bytes));
    try testing.expect(try reader.rootListMatchesElementBytes(.two_bytes, 2));
    try testing.expectError(error.UnsupportedElementSize, reader.getRootListElementWordCount(.two_bytes));
    try testing.expect(!try reader.rootListMatchesElementWords(.two_bytes, 1));
    try testing.expectEqual(@as(usize, 32), try reader.getRootListContentBitCount(.two_bytes));
    try testing.expect(try reader.rootListMatchesContentBits(.two_bytes, 32));
    try testing.expectEqual(@as(usize, 4), try reader.getRootListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try reader.getRootListContentWordCount(.two_bytes));
    try testing.expect(try reader.rootListMatchesContentBytes(.two_bytes, 4));
    try testing.expect(try reader.rootListMatchesContentWords(.two_bytes, 1));
    const read_nums = try root_ptr.getList(.two_bytes);
    try testing.expectEqual(@as(u16, 111), read_nums.getUInt16(0));
    try testing.expectEqual(@as(u16, 222), read_nums.getUInt16(1));
    try testing.expectEqual(@as(usize, 2), try root_ptr.getListLen(.two_bytes));
    try testing.expect(try root_ptr.listMatchesLen(.two_bytes, 2));
    try testing.expect(!try root_ptr.listIsEmpty(.two_bytes));
    try testing.expect(try root_ptr.listHasIndex(.two_bytes, 1));
    try testing.expect(!try root_ptr.listHasIndex(.two_bytes, 2));
    try testing.expectEqual(@as(usize, 0), try root_ptr.getListFirstIndex(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try root_ptr.getListLastIndex(.two_bytes));
    try testing.expectEqual(wire.ElementSize.two_bytes, try root_ptr.getListElementSize(.two_bytes));
    try testing.expect(try root_ptr.listMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try root_ptr.getListElementBitCount(.two_bytes));
    try testing.expect(try root_ptr.listMatchesElementBits(.two_bytes, 16));
    try testing.expectEqual(@as(usize, 2), try root_ptr.getListElementByteCount(.two_bytes));
    try testing.expect(try root_ptr.listMatchesElementBytes(.two_bytes, 2));
    try testing.expectError(error.UnsupportedElementSize, root_ptr.getListElementWordCount(.two_bytes));
    try testing.expect(!try root_ptr.listMatchesElementWords(.two_bytes, 1));
    try testing.expectEqual(@as(usize, 32), try root_ptr.getListContentBitCount(.two_bytes));
    try testing.expect(try root_ptr.listMatchesContentBits(.two_bytes, 32));
    try testing.expectEqual(@as(usize, 4), try root_ptr.getListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try root_ptr.getListContentWordCount(.two_bytes));
    try testing.expect(try root_ptr.listMatchesContentBytes(.two_bytes, 4));
    try testing.expect(try root_ptr.listMatchesContentWords(.two_bytes, 1));
    const flat_nums = try builder.toFlatBytes();
    defer testing.allocator.free(flat_nums);
    var owned_nums = try OwnedMessageReader.initFlat(testing.allocator, flat_nums, .{});
    defer owned_nums.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), try owned_nums.getRootListLen(.two_bytes));
    try testing.expect(try owned_nums.rootListMatchesLen(.two_bytes, 2));
    try testing.expect(!try owned_nums.rootListIsEmpty(.two_bytes));
    try testing.expect(try owned_nums.rootListHasIndex(.two_bytes, 1));
    try testing.expect(!try owned_nums.rootListHasIndex(.two_bytes, 2));
    try testing.expectEqual(@as(usize, 0), try owned_nums.getRootListFirstIndex(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try owned_nums.getRootListLastIndex(.two_bytes));
    try testing.expectEqual(wire.ElementSize.two_bytes, try owned_nums.getRootListElementSize(.two_bytes));
    try testing.expect(try owned_nums.rootListMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try owned_nums.getRootListElementBitCount(.two_bytes));
    try testing.expect(try owned_nums.rootListMatchesElementBits(.two_bytes, 16));
    try testing.expectEqual(@as(usize, 2), try owned_nums.getRootListElementByteCount(.two_bytes));
    try testing.expect(try owned_nums.rootListMatchesElementBytes(.two_bytes, 2));
    try testing.expectError(error.UnsupportedElementSize, owned_nums.getRootListElementWordCount(.two_bytes));
    try testing.expect(!try owned_nums.rootListMatchesElementWords(.two_bytes, 1));
    try testing.expectEqual(@as(usize, 32), try owned_nums.getRootListContentBitCount(.two_bytes));
    try testing.expect(try owned_nums.rootListMatchesContentBits(.two_bytes, 32));
    try testing.expectEqual(@as(usize, 4), try owned_nums.getRootListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try owned_nums.getRootListContentWordCount(.two_bytes));
    try testing.expect(try owned_nums.rootListMatchesContentBytes(.two_bytes, 4));
    try testing.expect(try owned_nums.rootListMatchesContentWords(.two_bytes, 1));
    var view_nums = try MessageReaderView.initFlat(testing.allocator, flat_nums, .{});
    defer view_nums.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), try view_nums.getRootListLen(.two_bytes));
    try testing.expect(try view_nums.rootListMatchesLen(.two_bytes, 2));
    try testing.expect(!try view_nums.rootListIsEmpty(.two_bytes));
    try testing.expect(try view_nums.rootListHasIndex(.two_bytes, 1));
    try testing.expect(!try view_nums.rootListHasIndex(.two_bytes, 2));
    try testing.expectEqual(@as(usize, 0), try view_nums.getRootListFirstIndex(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try view_nums.getRootListLastIndex(.two_bytes));
    try testing.expectEqual(wire.ElementSize.two_bytes, try view_nums.getRootListElementSize(.two_bytes));
    try testing.expect(try view_nums.rootListMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try view_nums.getRootListElementBitCount(.two_bytes));
    try testing.expect(try view_nums.rootListMatchesElementBits(.two_bytes, 16));
    try testing.expectEqual(@as(usize, 2), try view_nums.getRootListElementByteCount(.two_bytes));
    try testing.expect(try view_nums.rootListMatchesElementBytes(.two_bytes, 2));
    try testing.expectError(error.UnsupportedElementSize, view_nums.getRootListElementWordCount(.two_bytes));
    try testing.expect(!try view_nums.rootListMatchesElementWords(.two_bytes, 1));
    try testing.expectEqual(@as(usize, 32), try view_nums.getRootListContentBitCount(.two_bytes));
    try testing.expect(try view_nums.rootListMatchesContentBits(.two_bytes, 32));
    try testing.expectEqual(@as(usize, 4), try view_nums.getRootListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try view_nums.getRootListContentWordCount(.two_bytes));
    try testing.expect(try view_nums.rootListMatchesContentBytes(.two_bytes, 4));
    try testing.expect(try view_nums.rootListMatchesContentWords(.two_bytes, 1));
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
    const people_root_pointer = try builder.getRootPointer();
    try testing.expectEqual(@as(usize, 1), try builder.getRootListLen(.composite));
    try testing.expect(try builder.rootListMatchesLen(.composite, 1));
    try testing.expectEqual(wire.ElementSize.composite, try builder.getRootListElementSize(.composite));
    try testing.expect(try builder.rootListMatchesElementSize(.composite, .composite));
    try testing.expectEqual(@as(usize, 128), try builder.getRootListElementBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try builder.getRootListElementByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try builder.getRootListElementWordCount(.composite));
    try testing.expectEqual(@as(usize, 128), try builder.getRootListContentBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try builder.getRootListContentByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try builder.getRootListContentWordCount(.composite));
    try testing.expect(try builder.rootListMatchesContentBytes(.composite, 16));
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, try builder.getRootListStructElementSize(.composite));
    try testing.expectEqual(@as(u16, 1), try builder.getRootListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try builder.getRootListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 2), try builder.getRootListStructElementTotalWords(.composite));
    try testing.expectEqual(@as(usize, 8), try builder.getRootListStructElementDataByteCount(.composite));
    try testing.expectEqual(@as(usize, 8), try builder.getRootListStructElementPointerByteCount(.composite));
    try testing.expectEqual(@as(usize, 16), try builder.getRootListStructElementTotalByteCount(.composite));
    try testing.expect(try builder.rootListMatchesStructElementSize(.composite, .{ .data_words = 1, .pointer_count = 1 }));
    try testing.expect(try builder.rootListMatchesStructElementDataWords(.composite, 1));
    try testing.expect(try builder.rootListMatchesStructElementPointerCount(.composite, 1));
    try testing.expect(try builder.rootListMatchesStructElementTotalWords(.composite, 2));
    try testing.expect(try builder.rootListMatchesStructElementDataBytes(.composite, 8));
    try testing.expect(try builder.rootListMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(try builder.rootListMatchesStructElementTotalBytes(.composite, 16));
    try testing.expectEqual(@as(usize, 1), try people_root_pointer.getListLen(.composite));
    try testing.expect(try people_root_pointer.listMatchesLen(.composite, 1));
    try testing.expectEqual(wire.ElementSize.composite, try people_root_pointer.getListElementSize(.composite));
    try testing.expect(try people_root_pointer.listMatchesElementSize(.composite, .composite));
    try testing.expectEqual(@as(usize, 128), try people_root_pointer.getListElementBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try people_root_pointer.getListElementByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try people_root_pointer.getListElementWordCount(.composite));
    try testing.expectEqual(@as(usize, 128), try people_root_pointer.getListContentBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try people_root_pointer.getListContentByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try people_root_pointer.getListContentWordCount(.composite));
    try testing.expect(try people_root_pointer.listMatchesContentBytes(.composite, 16));
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, try people_root_pointer.getListStructElementSize(.composite));
    try testing.expectEqual(@as(u16, 1), try people_root_pointer.getListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try people_root_pointer.getListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 2), try people_root_pointer.getListStructElementTotalWords(.composite));
    try testing.expectEqual(@as(usize, 8), try people_root_pointer.getListStructElementDataByteCount(.composite));
    try testing.expectEqual(@as(usize, 8), try people_root_pointer.getListStructElementPointerByteCount(.composite));
    try testing.expectEqual(@as(usize, 16), try people_root_pointer.getListStructElementTotalByteCount(.composite));
    try testing.expect(try people_root_pointer.listMatchesStructElementSize(.composite, .{ .data_words = 1, .pointer_count = 1 }));
    try testing.expect(try people_root_pointer.listMatchesStructElementDataWords(.composite, 1));
    try testing.expect(try people_root_pointer.listMatchesStructElementPointerCount(.composite, 1));
    try testing.expect(try people_root_pointer.listMatchesStructElementTotalWords(.composite, 2));
    try testing.expect(try people_root_pointer.listMatchesStructElementDataBytes(.composite, 8));
    try testing.expect(try people_root_pointer.listMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(try people_root_pointer.listMatchesStructElementTotalBytes(.composite, 16));
    const person = try people.getStructElement(0);
    try person.setUInt32(0, 123, 42);
    try person.setText(0, "drop struct element");
    try people.clearStructElement(0);
    try testing.expectError(error.PointerOutOfBounds, people.clearStructElement(1));

    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const read_people_pointer = try reader.getRootPointer();
    const read_people = try reader.getRootList(.composite);
    try testing.expectEqual(@as(usize, 1), try reader.getRootListLen(.composite));
    try testing.expect(try reader.rootListMatchesLen(.composite, 1));
    try testing.expectEqual(wire.ElementSize.composite, try reader.getRootListElementSize(.composite));
    try testing.expect(try reader.rootListMatchesElementSize(.composite, .composite));
    try testing.expectEqual(@as(usize, 128), try reader.getRootListElementBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try reader.getRootListElementByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try reader.getRootListElementWordCount(.composite));
    try testing.expectEqual(@as(usize, 128), try reader.getRootListContentBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try reader.getRootListContentByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try reader.getRootListContentWordCount(.composite));
    try testing.expect(try reader.rootListMatchesContentBytes(.composite, 16));
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, try reader.getRootListStructElementSize(.composite));
    try testing.expectEqual(@as(u16, 1), try reader.getRootListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try reader.getRootListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 2), try reader.getRootListStructElementTotalWords(.composite));
    try testing.expectEqual(@as(usize, 8), try reader.getRootListStructElementDataByteCount(.composite));
    try testing.expectEqual(@as(usize, 8), try reader.getRootListStructElementPointerByteCount(.composite));
    try testing.expectEqual(@as(usize, 16), try reader.getRootListStructElementTotalByteCount(.composite));
    try testing.expect(try reader.rootListMatchesStructElementSize(.composite, .{ .data_words = 1, .pointer_count = 1 }));
    try testing.expect(try reader.rootListMatchesStructElementDataWords(.composite, 1));
    try testing.expect(try reader.rootListMatchesStructElementPointerCount(.composite, 1));
    try testing.expect(try reader.rootListMatchesStructElementTotalWords(.composite, 2));
    try testing.expect(try reader.rootListMatchesStructElementDataBytes(.composite, 8));
    try testing.expect(try reader.rootListMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(try reader.rootListMatchesStructElementTotalBytes(.composite, 16));
    try testing.expectEqual(@as(usize, 1), try read_people_pointer.getListLen(.composite));
    try testing.expect(try read_people_pointer.listMatchesLen(.composite, 1));
    try testing.expectEqual(wire.ElementSize.composite, try read_people_pointer.getListElementSize(.composite));
    try testing.expect(try read_people_pointer.listMatchesElementSize(.composite, .composite));
    try testing.expectEqual(@as(usize, 128), try read_people_pointer.getListElementBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try read_people_pointer.getListElementByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try read_people_pointer.getListElementWordCount(.composite));
    try testing.expectEqual(@as(usize, 128), try read_people_pointer.getListContentBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try read_people_pointer.getListContentByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try read_people_pointer.getListContentWordCount(.composite));
    try testing.expect(try read_people_pointer.listMatchesContentBytes(.composite, 16));
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, try read_people_pointer.getListStructElementSize(.composite));
    try testing.expectEqual(@as(u16, 1), try read_people_pointer.getListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try read_people_pointer.getListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 2), try read_people_pointer.getListStructElementTotalWords(.composite));
    try testing.expectEqual(@as(usize, 8), try read_people_pointer.getListStructElementDataByteCount(.composite));
    try testing.expectEqual(@as(usize, 8), try read_people_pointer.getListStructElementPointerByteCount(.composite));
    try testing.expectEqual(@as(usize, 16), try read_people_pointer.getListStructElementTotalByteCount(.composite));
    try testing.expect(try read_people_pointer.listMatchesStructElementSize(.composite, .{ .data_words = 1, .pointer_count = 1 }));
    try testing.expect(try read_people_pointer.listMatchesStructElementDataWords(.composite, 1));
    try testing.expect(try read_people_pointer.listMatchesStructElementPointerCount(.composite, 1));
    try testing.expect(try read_people_pointer.listMatchesStructElementTotalWords(.composite, 2));
    try testing.expect(try read_people_pointer.listMatchesStructElementDataBytes(.composite, 8));
    try testing.expect(try read_people_pointer.listMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(try read_people_pointer.listMatchesStructElementTotalBytes(.composite, 16));
    const read_person = try read_people.getStructElement(0);
    try testing.expectEqual(@as(u32, 42), read_person.getUInt32(0, 42));
    try testing.expect(read_person.getPointerField(0).isNull());
    try testing.expectError(error.NullPointer, read_person.getPointerField(0).getText());

    const flat_people = try builder.toFlatBytes();
    defer testing.allocator.free(flat_people);
    var owned_people = try OwnedMessageReader.initFlat(testing.allocator, flat_people, .{});
    defer owned_people.deinit(testing.allocator);
    try testing.expectEqual(@as(u16, 1), try owned_people.getRootListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try owned_people.getRootListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 16), try owned_people.getRootListStructElementTotalByteCount(.composite));
    try testing.expect(try owned_people.rootListMatchesStructElementDataWords(.composite, 1));
    try testing.expect(try owned_people.rootListMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(try owned_people.rootListMatchesStructElementTotalBytes(.composite, 16));
    var viewed_people = try MessageReaderView.initFlat(testing.allocator, flat_people, .{});
    defer viewed_people.deinit(testing.allocator);
    try testing.expectEqual(@as(u16, 1), try viewed_people.getRootListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try viewed_people.getRootListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 16), try viewed_people.getRootListStructElementTotalByteCount(.composite));
    try testing.expect(try viewed_people.rootListMatchesStructElementDataWords(.composite, 1));
    try testing.expect(try viewed_people.rootListMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(try viewed_people.rootListMatchesStructElementTotalBytes(.composite, 16));
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
    try testing.expect(try pointers.elementMatchesPointerType(0, .list));
    try testing.expect(try pointers.elementIsListPointer(0));
    try testing.expect(try pointers.elementIsNearPointer(0));
    try testing.expect(!try pointers.elementIsStructPointer(0));
    try testing.expect(!try pointers.elementIsFarPointer(0));
    try testing.expect(!try pointers.elementIsOtherPointer(0));
    try testing.expect(!try pointers.elementIsCapabilityPointer(0));
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
    const read_pointers = try read_root.getPointerField(2).getList(.pointer);
    try testing.expect((try read_pointers.getPointerElement(0)).isNull());
    try testing.expect(!try read_pointers.elementMatchesPointerType(0, .list));
    try testing.expect(!try read_pointers.elementIsListPointer(0));
    try testing.expect(!try read_pointers.elementIsNearPointer(0));
    try testing.expect(!try read_pointers.elementIsStructPointer(0));
    try testing.expect(!try read_pointers.elementIsFarPointer(0));
    try testing.expect(!try read_pointers.elementIsOtherPointer(0));
    try testing.expect(!try read_pointers.elementIsCapabilityPointer(0));
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

    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 3 });
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

    const bits = try (try root.getPointerField(2)).initList(.bit, 4);
    try bits.setBool(0, true);
    try bits.setBool(1, false);
    try bits.setBool(2, true);
    try bits.setBool(3, false);
    try bits.copyElementsFromBuilder(1, bits, 0, 3);
    try testing.expect(try bits.getBool(0));
    try testing.expect(try bits.getBool(1));
    try testing.expect(!try bits.getBool(2));
    try testing.expect(try bits.getBool(3));

    // The generic reader path can still alias the destination when callers
    // create a reader view over the same builder.  Treat primitive range copies
    // like memmove rather than memcpy so this remains safe in debug/safe modes.
    var reader = MessageReader.init(try builder.segmentsConst(), .{});
    const forward_reader = forward.asReader(&reader);
    try forward.copyElementsFrom(0, forward_reader, 1, 3);
    try testing.expectEqual(@as(u32, 1), try forward.getUInt32(0));
    try testing.expectEqual(@as(u32, 2), try forward.getUInt32(1));
    try testing.expectEqual(@as(u32, 3), try forward.getUInt32(2));
    try testing.expectEqual(@as(u32, 3), try forward.getUInt32(3));
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
    try testing.expectEqualSlices(u8, "move me", try orphan.getText());
    try testing.expectEqual(@as(usize, "move me".len), try orphan.getTextByteCount());
    try testing.expect(orphan.textMatchesBytes("move me".len));
    try testing.expect(!orphan.textMatchesBytes("move me".len + 1));
    try testing.expectEqual(@as(usize, 8), try orphan.getListLen(.byte));
    try testing.expect(orphan.listMatchesLen(.byte, 8));
    try testing.expect(!orphan.listIsEmpty(.byte));
    try testing.expect(orphan.listHasIndex(.byte, 7));
    try testing.expect(!orphan.listHasIndex(.byte, 8));
    try testing.expectEqual(@as(usize, 0), try orphan.getListFirstIndex(.byte));
    try testing.expectEqual(@as(usize, 7), try orphan.getListLastIndex(.byte));
    try testing.expectEqual(wire.ElementSize.byte, try orphan.getListElementSize(.byte));
    try testing.expect(orphan.listMatchesElementSize(.byte, .byte));
    try testing.expectEqual(@as(usize, 8), try orphan.getListElementBitCount(.byte));
    try testing.expect(orphan.listMatchesElementBits(.byte, 8));
    try testing.expectEqual(@as(usize, 1), try orphan.getListElementByteCount(.byte));
    try testing.expect(orphan.listMatchesElementBytes(.byte, 1));
    try testing.expectError(error.UnsupportedElementSize, orphan.getListElementWordCount(.byte));
    try testing.expect(!orphan.listMatchesElementWords(.byte, 1));
    try testing.expectEqual(@as(usize, 64), try orphan.getListContentBitCount(.byte));
    try testing.expect(orphan.listMatchesContentBits(.byte, 64));
    try testing.expectEqual(@as(usize, 8), try orphan.getListContentByteCount(.byte));
    try testing.expectEqual(@as(usize, 1), try orphan.getListContentWordCount(.byte));
    try testing.expect(orphan.listMatchesContentBytes(.byte, 8));
    try testing.expect(orphan.listMatchesContentWords(.byte, 1));
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
    try testing.expectEqualSlices(u8, "first", try orphan.getText());
    try testing.expectEqualSlices(u8, "first", try orphan.getTextDefault("ignored"));
    try testing.expectEqual(@as(usize, "first".len), try orphan.getTextDefaultByteCount("ignored"));
    try testing.expect(orphan.textDefaultMatchesBytes("ignored", "first".len));
    try testing.expect(!orphan.textDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expectEqual(@as(usize, "first".len), try orphan.getTextByteCount());
    try testing.expect(orphan.textMatchesBytes("first".len));
    try testing.expect(!orphan.textMatchesBytes("first".len + 1));
    try testing.expectEqual(@as(usize, 6), try orphan.getListLen(.byte));
    try testing.expect(orphan.listMatchesLen(.byte, 6));
    try testing.expectEqual(@as(usize, 48), try orphan.getListContentBitCount(.byte));
    try testing.expectEqual(@as(usize, 6), try orphan.getListContentByteCount(.byte));
    try testing.expectEqual(@as(usize, 1), try orphan.getListContentWordCount(.byte));
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
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, try struct_orphan.structSize());
    try testing.expectEqual(@as(u16, 1), try struct_orphan.structDataWordCount());
    try testing.expectEqual(@as(u16, 1), try struct_orphan.structPointerCount());
    try testing.expectEqual(@as(usize, 2), try struct_orphan.structTotalWords());
    try testing.expectEqual(@as(usize, 8), try struct_orphan.structDataByteCount());
    try testing.expectEqual(@as(usize, 8), try struct_orphan.structPointerByteCount());
    try testing.expectEqual(@as(usize, 16), try struct_orphan.structTotalByteCount());
    try testing.expect(struct_orphan.structMatchesSize(.{ .data_words = 1, .pointer_count = 1 }));
    try testing.expect(struct_orphan.structMatchesDataWords(1));
    try testing.expect(struct_orphan.structMatchesPointerCount(1));
    try testing.expect(struct_orphan.structMatchesTotalWords(2));
    try testing.expect(struct_orphan.structMatchesTotalBytes(16));
    try testing.expect(!struct_orphan.structMatchesSize(.{ .data_words = 2, .pointer_count = 1 }));
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
    try testing.expectEqual(@as(usize, 2), try list_orphan.getListLen(.two_bytes));
    try testing.expect(list_orphan.listMatchesLen(.two_bytes, 2));
    try testing.expectEqual(wire.ElementSize.two_bytes, try list_orphan.getListElementSize(.two_bytes));
    try testing.expect(list_orphan.listMatchesElementSize(.two_bytes, .two_bytes));
    try testing.expectEqual(@as(usize, 16), try list_orphan.getListElementBitCount(.two_bytes));
    try testing.expectEqual(@as(usize, 2), try list_orphan.getListElementByteCount(.two_bytes));
    try testing.expectError(error.UnsupportedElementSize, list_orphan.getListElementWordCount(.two_bytes));
    try testing.expectEqual(@as(usize, 32), try list_orphan.getListContentBitCount(.two_bytes));
    try testing.expectEqual(@as(usize, 4), try list_orphan.getListContentByteCount(.two_bytes));
    try testing.expectEqual(@as(usize, 1), try list_orphan.getListContentWordCount(.two_bytes));
    try testing.expect(list_orphan.listMatchesContentBytes(.two_bytes, 4));
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

    var struct_list_orphan = try list_builder.newOrphanStructList(1, .{ .data_words = 1, .pointer_count = 1 });
    try testing.expectEqual(@as(usize, 1), try struct_list_orphan.getListLen(.composite));
    try testing.expect(struct_list_orphan.listMatchesLen(.composite, 1));
    try testing.expectEqual(wire.ElementSize.composite, try struct_list_orphan.getListElementSize(.composite));
    try testing.expect(struct_list_orphan.listMatchesElementSize(.composite, .composite));
    try testing.expectEqual(@as(usize, 128), try struct_list_orphan.getListElementBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try struct_list_orphan.getListElementByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try struct_list_orphan.getListElementWordCount(.composite));
    try testing.expectEqual(@as(usize, 128), try struct_list_orphan.getListContentBitCount(.composite));
    try testing.expectEqual(@as(usize, 16), try struct_list_orphan.getListContentByteCount(.composite));
    try testing.expectEqual(@as(usize, 2), try struct_list_orphan.getListContentWordCount(.composite));
    try testing.expect(struct_list_orphan.listMatchesContentBytes(.composite, 16));
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 1 }, try struct_list_orphan.getListStructElementSize(.composite));
    try testing.expectEqual(@as(u16, 1), try struct_list_orphan.getListStructElementDataWordCount(.composite));
    try testing.expectEqual(@as(u16, 1), try struct_list_orphan.getListStructElementPointerCount(.composite));
    try testing.expectEqual(@as(usize, 2), try struct_list_orphan.getListStructElementTotalWords(.composite));
    try testing.expectEqual(@as(usize, 8), try struct_list_orphan.getListStructElementDataByteCount(.composite));
    try testing.expectEqual(@as(usize, 8), try struct_list_orphan.getListStructElementPointerByteCount(.composite));
    try testing.expectEqual(@as(usize, 16), try struct_list_orphan.getListStructElementTotalByteCount(.composite));
    try testing.expect(struct_list_orphan.listMatchesStructElementSize(.composite, .{ .data_words = 1, .pointer_count = 1 }));
    try testing.expect(struct_list_orphan.listMatchesStructElementDataWords(.composite, 1));
    try testing.expect(struct_list_orphan.listMatchesStructElementPointerCount(.composite, 1));
    try testing.expect(struct_list_orphan.listMatchesStructElementTotalWords(.composite, 2));
    try testing.expect(struct_list_orphan.listMatchesStructElementDataBytes(.composite, 8));
    try testing.expect(struct_list_orphan.listMatchesStructElementPointerBytes(.composite, 8));
    try testing.expect(struct_list_orphan.listMatchesStructElementTotalBytes(.composite, 16));
    struct_list_orphan.release();
}

test "message builder allocates scalar orphans" {
    const testing = std.testing;

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer text_builder.deinit();
    var text_orphan = try text_builder.newOrphanText("allocated text");
    try testing.expectEqualSlices(u8, "allocated text", try text_orphan.getText());
    try testing.expectEqualSlices(u8, "allocated text", try text_orphan.getTextDefault("ignored"));
    try testing.expectEqual(@as(usize, "allocated text".len), try text_orphan.getTextDefaultByteCount("ignored"));
    try testing.expect(text_orphan.textDefaultMatchesBytes("ignored", "allocated text".len));
    try testing.expect(!text_orphan.textDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expectEqual(@as(usize, "allocated text".len), try text_orphan.getTextByteCount());
    try testing.expect(text_orphan.textMatchesBytes("allocated text".len));
    try testing.expect(!text_orphan.textMatchesBytes("allocated text".len + 1));
    try (try text_builder.getRootPointer()).adopt(&text_orphan);
    var text_reader = MessageReader.init(try text_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "allocated text", try text_reader.getRootText());

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer data_builder.deinit();
    var data_orphan = try data_builder.newOrphanData(&[_]u8{ 1, 3, 3, 7 });
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 3, 3, 7 }, try data_orphan.getData());
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 3, 3, 7 }, try data_orphan.getDataDefault(&[_]u8{ 9, 9 }));
    try testing.expectEqual(@as(usize, 4), try data_orphan.getDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(data_orphan.dataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 4));
    try testing.expect(!data_orphan.dataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    try testing.expectEqual(@as(usize, 4), try data_orphan.getDataByteCount());
    try testing.expect(data_orphan.dataMatchesBytes(4));
    try testing.expect(!data_orphan.dataMatchesBytes(5));
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

    var shared = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 64 });
    defer shared.deinit();
    const shared_root = try shared.initRoot(.{ .data_words = 0, .pointer_count = 2 });
    const shared_list = try (try shared_root.getPointerField(0)).initList(.eight_bytes, 10);
    for (0..10) |i| try shared_list.setUInt64(i, @intCast(i));
    var shared_reader_for_copy = MessageReader.init(try shared.segmentsConst(), .{});
    try (try shared_root.getPointerField(1)).copyFrom((try shared_root.getPointerField(0)).asReader(&shared_reader_for_copy));
    var shared_limited = MessageReader.init(try shared.segmentsConst(), .{ .traversal_limit_words = 12 });
    try testing.expectError(error.TraversalLimitExceeded, shared_limited.validate());

    var bad_words = [_]wire.Word{try wire.encodeStruct(10, 1, 0)};
    const bad_segments = [_]serialize.ConstSegment{std.mem.sliceAsBytes(&bad_words)};
    var invalid = MessageReader.init(&bad_segments, .{});
    try testing.expectError(error.PointerOutOfBounds, invalid.validate());

    const root_self_cycle = try wire.encodeStruct(0, 0, 1);
    const field_self_cycle = try wire.encodeStruct(-1, 0, 1);
    var cyclic_words = [_]wire.Word{ root_self_cycle, field_self_cycle };
    const cyclic_segments = [_]serialize.ConstSegment{std.mem.sliceAsBytes(&cyclic_words)};
    var cyclic = MessageReader.init(&cyclic_segments, .{ .nesting_limit = 4, .traversal_limit_words = 100 });
    try testing.expectError(error.NestingLimitExceeded, cyclic.validate());

    const misaligned_segment = [_]u8{ 0, 0, 0, 0 };
    var misaligned = MessageReader.init(&.{&misaligned_segment}, .{});
    try testing.expectError(error.SegmentNotWordAligned, misaligned.validate());
    try testing.expectError(error.SegmentNotWordAligned, misaligned.segmentWordLen(0));
}

test "message builder deep-copies from a reader" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer source.deinit();

    const root = try source.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try root.setUInt32(0, 77, 0);
    const source_root_pointer = try source.getRootPointer();
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 2 }, try source_root_pointer.getStructSize());
    try testing.expectEqual(@as(u16, 1), try source_root_pointer.getStructDataWordCount());
    try testing.expectEqual(@as(u16, 2), try source_root_pointer.getStructPointerCount());
    try testing.expectEqual(@as(usize, 3), try source_root_pointer.getStructTotalWords());
    try testing.expectEqual(@as(usize, 8), try source_root_pointer.getStructDataByteCount());
    try testing.expectEqual(@as(usize, 16), try source_root_pointer.getStructPointerByteCount());
    try testing.expectEqual(@as(usize, 24), try source_root_pointer.getStructTotalByteCount());
    try testing.expect(try source_root_pointer.structMatchesSize(.{ .data_words = 1, .pointer_count = 2 }));
    try testing.expect(try source_root_pointer.structMatchesDataWords(1));
    try testing.expect(try source_root_pointer.structMatchesPointerCount(2));
    try testing.expect(try source_root_pointer.structMatchesTotalWords(3));
    try testing.expect(try source_root_pointer.structMatchesTotalBytes(24));
    try testing.expect(!try source_root_pointer.structMatchesSize(.{ .data_words = 2, .pointer_count = 2 }));
    const names = try (try root.getPointerField(0)).initList(.pointer, 2);
    try (try names.getPointerElement(0)).setText("left");
    try (try names.getPointerElement(1)).setText("right");
    const people = try (try root.getPointerField(1)).initStructList(1, .{ .data_words = 1, .pointer_count = 1 });
    const person = try people.getStructElement(0);
    try person.setUInt32(0, 123, 0);
    try person.setText(0, "nested");

    var source_reader = MessageReader.init(try source.segmentsConst(), .{});
    const source_root_reader = try source_reader.getRootPointer();
    try testing.expectEqual(wire.StructSize{ .data_words = 1, .pointer_count = 2 }, try source_root_reader.getStructSize());
    try testing.expectEqual(@as(u16, 1), try source_root_reader.getStructDataWordCount());
    try testing.expectEqual(@as(u16, 2), try source_root_reader.getStructPointerCount());
    try testing.expectEqual(@as(usize, 3), try source_root_reader.getStructTotalWords());
    try testing.expectEqual(@as(usize, 8), try source_root_reader.getStructDataByteCount());
    try testing.expectEqual(@as(usize, 16), try source_root_reader.getStructPointerByteCount());
    try testing.expectEqual(@as(usize, 24), try source_root_reader.getStructTotalByteCount());
    try testing.expect(try source_root_reader.structMatchesSize(.{ .data_words = 1, .pointer_count = 2 }));
    try testing.expect(try source_root_reader.structMatchesDataWords(1));
    try testing.expect(try source_root_reader.structMatchesPointerCount(2));
    try testing.expect(try source_root_reader.structMatchesTotalWords(3));
    try testing.expect(try source_root_reader.structMatchesTotalBytes(24));
    try testing.expect(!try source_root_reader.structMatchesSize(.{ .data_words = 1, .pointer_count = 1 }));
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

    var builder_copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2, .next_segment_min_words = 2 });
    defer builder_copy.deinit();
    const copied_builder_root = try builder_copy.copyRootFromBuilder(root);
    try testing.expectEqual(@as(u32, 77), try copied_builder_root.getUInt32(0, 0));
    const copied_builder_names = try (try copied_builder_root.getPointerField(0)).getList(.pointer);
    try testing.expectEqualSlices(u8, "left", try (try copied_builder_names.getPointerElement(0)).getText());
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

    var builder_pointer_copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer builder_pointer_copy.deinit();
    _ = try builder_pointer_copy.copyRootPointerFromBuilder(try source.getRootPointer());
    var builder_pointer_copy_reader = MessageReader.init(try builder_pointer_copy.segmentsConst(), .{});
    const builder_copied_list = try (try builder_pointer_copy_reader.getRootPointer()).getList(.pointer);
    try testing.expectEqualSlices(u8, "root pointer copy", try (try builder_copied_list.getPointerElement(0)).getText());

    var builder_target_copy = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer builder_target_copy.deinit();
    _ = try source.copyRootToBuilder(&builder_target_copy);
    var builder_target_copy_reader = MessageReader.init(try builder_target_copy.segmentsConst(), .{});
    const builder_target_list = try (try builder_target_copy_reader.getRootPointer()).getList(.pointer);
    try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, try (try builder_target_list.getPointerElement(1)).getData());

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
    try testing.expectEqual(@as(usize, "default root".len), try empty_text_builder.getRootTextDefaultByteCount("default root"));
    try testing.expect(try empty_text_builder.rootTextDefaultMatchesBytes("default root", "default root".len));
    try testing.expect(!try empty_text_builder.rootTextDefaultMatchesBytes("default root", "default root".len + 1));
    var empty_text_reader = MessageReader.init(try empty_text_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "default root", try empty_text_reader.getRootTextDefault("default root"));
    try testing.expectEqual(@as(usize, "default root".len), try empty_text_reader.getRootTextDefaultByteCount("default root"));
    try testing.expect(try empty_text_reader.rootTextDefaultMatchesBytes("default root", "default root".len));
    try testing.expect(!try empty_text_reader.rootTextDefaultMatchesBytes("default root", "default root".len + 1));

    var text_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer text_builder.deinit();
    try text_builder.setRootText("root text");
    try testing.expectEqualSlices(u8, "root text", try text_builder.getRootText());
    try testing.expectEqualSlices(u8, "root text", try text_builder.getRootTextDefault("ignored"));
    try testing.expectEqual(@as(usize, "root text".len), try text_builder.getRootTextDefaultByteCount("ignored"));
    try testing.expect(try text_builder.rootTextDefaultMatchesBytes("ignored", "root text".len));
    try testing.expect(!try text_builder.rootTextDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expectEqual(@as(usize, "root text".len), try text_builder.getRootTextByteCount());
    try testing.expect(try text_builder.rootTextMatchesBytes("root text".len));
    try testing.expect(!try text_builder.rootTextMatchesBytes("root text".len + 1));
    var text_reader = MessageReader.init(try text_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, "root text", try text_reader.getRootText());
    try testing.expectEqualSlices(u8, "root text", try text_reader.getRootTextDefault("ignored"));
    try testing.expectEqual(@as(usize, "root text".len), try text_reader.getRootTextDefaultByteCount("ignored"));
    try testing.expect(try text_reader.rootTextDefaultMatchesBytes("ignored", "root text".len));
    try testing.expect(!try text_reader.rootTextDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expectEqual(@as(usize, "root text".len), try text_reader.getRootTextByteCount());
    try testing.expect(try text_reader.rootTextMatchesBytes("root text".len));
    try testing.expect(!try text_reader.rootTextMatchesBytes("root text".len + 1));
    try testing.expectError(error.TextContainsInteriorNul, empty_text_reader.getRootTextDefault("bad\x00default"));
    try testing.expectError(error.TextContainsInteriorNul, empty_text_reader.getRootTextDefaultByteCount("bad\x00default"));

    var empty_data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer empty_data_builder.deinit();
    try testing.expectEqualSlices(u8, &[_]u8{ 9, 9 }, try empty_data_builder.getRootDataDefault(&[_]u8{ 9, 9 }));
    try testing.expectEqual(@as(usize, 2), try empty_data_builder.getRootDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try empty_data_builder.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    try testing.expect(!try empty_data_builder.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    var empty_data_reader = MessageReader.init(try empty_data_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, &[_]u8{ 9, 9 }, try empty_data_reader.getRootDataDefault(&[_]u8{ 9, 9 }));
    try testing.expectEqual(@as(usize, 2), try empty_data_reader.getRootDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try empty_data_reader.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    try testing.expect(!try empty_data_reader.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));

    var data_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
    defer data_builder.deinit();
    try data_builder.setRootData(&[_]u8{ 3, 1, 4 });
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_builder.getRootData());
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_builder.getRootDataDefault(&[_]u8{ 9, 9 }));
    try testing.expectEqual(@as(usize, 3), try data_builder.getRootDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try data_builder.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    try testing.expect(!try data_builder.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    try testing.expectEqual(@as(usize, 3), try data_builder.getRootDataByteCount());
    try testing.expect(try data_builder.rootDataMatchesBytes(3));
    try testing.expect(!try data_builder.rootDataMatchesBytes(4));
    var data_reader = MessageReader.init(try data_builder.segmentsConst(), .{});
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_reader.getRootData());
    try testing.expectEqualSlices(u8, &[_]u8{ 3, 1, 4 }, try data_reader.getRootDataDefault(&[_]u8{ 9, 9 }));
    try testing.expectEqual(@as(usize, 3), try data_reader.getRootDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try data_reader.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    try testing.expect(!try data_reader.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    try testing.expectEqual(@as(usize, 3), try data_reader.getRootDataByteCount());
    try testing.expect(try data_reader.rootDataMatchesBytes(3));
    try testing.expect(!try data_reader.rootDataMatchesBytes(4));

    var cap_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer cap_builder.deinit();
    try cap_builder.setRootCapability(4242);
    try testing.expectEqual(@as(u32, 4242), try cap_builder.getRootCapability());
    var cap_reader = MessageReader.init(try cap_builder.segmentsConst(), .{});
    try testing.expectEqual(@as(u32, 4242), try cap_reader.getRootCapability());
    var cap_limit_ok = MessageReader.init(try cap_builder.segmentsConst(), .{ .capability_count_limit = 4243 });
    const cap_limit_stats = try cap_limit_ok.validate();
    try testing.expectEqual(@as(usize, 1), cap_limit_stats.capabilityCount());
    var cap_limit_bad = MessageReader.init(try cap_builder.segmentsConst(), .{ .capability_count_limit = 4242 });
    try testing.expectError(error.InvalidCapabilityPointer, cap_limit_bad.validate());

    const text_root_pointer = try text_builder.getRootPointer();
    try testing.expectEqual(@as(u32, 0), text_root_pointer.segmentId());
    try testing.expectEqual(@as(usize, 0), text_root_pointer.pointerWordIndex());
    try testing.expectEqual(@as(usize, "root text".len), try text_root_pointer.getTextByteCount());
    try testing.expect(try text_root_pointer.textMatchesBytes("root text".len));
    try testing.expect(!try text_root_pointer.textMatchesBytes("root text".len + 1));
    try testing.expectEqual(@as(usize, "root text".len), try text_root_pointer.getTextDefaultByteCount("ignored"));
    try testing.expect(try text_root_pointer.textDefaultMatchesBytes("ignored", "root text".len));
    try testing.expect(!try text_root_pointer.textDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expect(text_root_pointer.matchesLocation(0, 0));
    try testing.expect(text_root_pointer.matchesPointerType(.far));
    try testing.expect(text_root_pointer.isFarPointer());
    try testing.expect(!text_root_pointer.isNearPointer());
    try testing.expect(!text_root_pointer.isOtherPointer());
    try testing.expect(!text_root_pointer.isListPointer());
    try testing.expect(!text_root_pointer.isStructPointer());
    try testing.expect(!text_root_pointer.isCapabilityPointer());
    var text_pointer_reader_message = MessageReader.init(try text_builder.segmentsConst(), .{});
    const text_pointer_reader = try text_pointer_reader_message.getRootPointer();
    try testing.expectEqual(@as(u32, 0), text_pointer_reader.segmentId());
    try testing.expectEqual(@as(usize, 0), text_pointer_reader.pointerWordIndex());
    try testing.expectEqual(@as(usize, "root text".len), try text_pointer_reader.getTextByteCount());
    try testing.expect(try text_pointer_reader.textMatchesBytes("root text".len));
    try testing.expect(!try text_pointer_reader.textMatchesBytes("root text".len + 1));
    try testing.expectEqual(@as(usize, "root text".len), try text_pointer_reader.getTextDefaultByteCount("ignored"));
    try testing.expect(try text_pointer_reader.textDefaultMatchesBytes("ignored", "root text".len));
    try testing.expect(!try text_pointer_reader.textDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expect(text_pointer_reader.matchesLocation(0, 0));
    try testing.expect(text_pointer_reader.matchesPointerType(.list));
    try testing.expect(text_pointer_reader.isListPointer());
    try testing.expect(text_pointer_reader.isNearPointer());
    try testing.expect(!text_pointer_reader.isOtherPointer());
    try testing.expect(!text_pointer_reader.isStructPointer());
    try testing.expect(!text_pointer_reader.isFarPointer());
    try testing.expect(!text_pointer_reader.isCapabilityPointer());

    const cap_root_pointer = try cap_builder.getRootPointer();
    try testing.expect(cap_root_pointer.matchesPointerType(.other));
    try testing.expect(cap_root_pointer.isCapabilityPointer());
    try testing.expect(cap_root_pointer.isOtherPointer());
    try testing.expect(cap_root_pointer.isNearPointer());
    try testing.expect(!cap_root_pointer.isListPointer());
    try testing.expectEqual(@as(usize, 4243), try cap_root_pointer.maxCapabilityCount());
    try testing.expect(cap_root_pointer.matchesMaxCapabilityCount(4243));
    try testing.expect(!cap_root_pointer.matchesMaxCapabilityCount(4242));
    const cap_pointer_reader = try cap_reader.getRootPointer();
    try testing.expect(cap_pointer_reader.matchesPointerType(.other));
    try testing.expect(cap_pointer_reader.isCapabilityPointer());
    try testing.expect(cap_pointer_reader.isOtherPointer());
    try testing.expect(cap_pointer_reader.isNearPointer());
    try testing.expect(!cap_pointer_reader.isListPointer());
    try testing.expectEqual(@as(usize, 4243), try cap_pointer_reader.maxCapabilityCount());
    try testing.expect(cap_pointer_reader.matchesMaxCapabilityCount(4243));
    try testing.expect(!cap_pointer_reader.matchesMaxCapabilityCount(4242));

    try testing.expect(try text_builder.matchesRootPointerType(.far));
    try testing.expect(try text_builder.isRootFarPointer());
    try testing.expect(!try text_builder.isRootNearPointer());
    try testing.expect(!try text_builder.isRootOtherPointer());
    try testing.expect(try text_reader.matchesRootPointerType(.list));
    try testing.expect(try text_reader.isRootListPointer());
    try testing.expect(try text_reader.isRootNearPointer());
    try testing.expect(!try text_reader.isRootCapabilityPointer());

    const text_flat = try text_builder.toFlatBytes();
    defer testing.allocator.free(text_flat);
    var owned_text = try OwnedMessageReader.initFlat(testing.allocator, text_flat, .{});
    defer owned_text.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, "root text".len), try owned_text.getRootTextByteCount());
    try testing.expect(try owned_text.rootTextMatchesBytes("root text".len));
    try testing.expect(!try owned_text.rootTextMatchesBytes("root text".len + 1));
    try testing.expectEqual(@as(usize, "root text".len), try owned_text.getRootTextDefaultByteCount("ignored"));
    try testing.expect(try owned_text.rootTextDefaultMatchesBytes("ignored", "root text".len));
    try testing.expect(!try owned_text.rootTextDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expect(try owned_text.matchesRootPointerType(.list));
    try testing.expect(try owned_text.isRootListPointer());
    try testing.expect(try owned_text.isRootNearPointer());
    try testing.expect(!try owned_text.isRootOtherPointer());
    var viewed_text = try MessageReaderView.initFlat(testing.allocator, text_flat, .{});
    defer viewed_text.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, "root text".len), try viewed_text.getRootTextByteCount());
    try testing.expect(try viewed_text.rootTextMatchesBytes("root text".len));
    try testing.expect(!try viewed_text.rootTextMatchesBytes("root text".len + 1));
    try testing.expectEqual(@as(usize, "root text".len), try viewed_text.getRootTextDefaultByteCount("ignored"));
    try testing.expect(try viewed_text.rootTextDefaultMatchesBytes("ignored", "root text".len));
    try testing.expect(!try viewed_text.rootTextDefaultMatchesBytes("ignored", "ignored".len));
    try testing.expect(try viewed_text.matchesRootPointerType(.list));
    try testing.expect(try viewed_text.isRootListPointer());
    try testing.expect(try viewed_text.isRootNearPointer());
    try testing.expect(!try viewed_text.isRootCapabilityPointer());

    try testing.expect(try cap_builder.matchesRootPointerType(.other));
    try testing.expect(try cap_builder.isRootCapabilityPointer());
    try testing.expect(try cap_builder.isRootOtherPointer());
    try testing.expect(try cap_builder.isRootNearPointer());
    try testing.expect(try cap_reader.matchesRootPointerType(.other));
    try testing.expect(try cap_reader.isRootCapabilityPointer());
    try testing.expect(try cap_reader.isRootOtherPointer());
    try testing.expect(try cap_reader.isRootNearPointer());

    const data_root_pointer = try data_builder.getRootPointer();
    try testing.expectEqual(@as(usize, 3), try data_root_pointer.getDataByteCount());
    try testing.expect(try data_root_pointer.dataMatchesBytes(3));
    try testing.expect(!try data_root_pointer.dataMatchesBytes(4));
    try testing.expectEqual(@as(usize, 3), try data_root_pointer.getDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try data_root_pointer.dataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    try testing.expect(!try data_root_pointer.dataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    const data_pointer_reader = try data_reader.getRootPointer();
    try testing.expectEqual(@as(usize, 3), try data_pointer_reader.getDataByteCount());
    try testing.expect(try data_pointer_reader.dataMatchesBytes(3));
    try testing.expect(!try data_pointer_reader.dataMatchesBytes(4));
    try testing.expectEqual(@as(usize, 3), try data_pointer_reader.getDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try data_pointer_reader.dataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    try testing.expect(!try data_pointer_reader.dataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));

    const data_flat = try data_builder.toFlatBytes();
    defer testing.allocator.free(data_flat);
    var owned_data = try OwnedMessageReader.initFlat(testing.allocator, data_flat, .{});
    defer owned_data.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), try owned_data.getRootDataByteCount());
    try testing.expect(try owned_data.rootDataMatchesBytes(3));
    try testing.expect(!try owned_data.rootDataMatchesBytes(4));
    try testing.expectEqual(@as(usize, 3), try owned_data.getRootDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try owned_data.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    try testing.expect(!try owned_data.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
    var viewed_data = try MessageReaderView.initFlat(testing.allocator, data_flat, .{});
    defer viewed_data.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), try viewed_data.getRootDataByteCount());
    try testing.expect(try viewed_data.rootDataMatchesBytes(3));
    try testing.expect(!try viewed_data.rootDataMatchesBytes(4));
    try testing.expectEqual(@as(usize, 3), try viewed_data.getRootDataDefaultByteCount(&[_]u8{ 9, 9 }));
    try testing.expect(try viewed_data.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 3));
    try testing.expect(!try viewed_data.rootDataDefaultMatchesBytes(&[_]u8{ 9, 9 }, 2));
}

test "message builder can disown and adopt root pointers" {
    const testing = std.testing;

    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();
    try builder.setRootText("root orphan");

    var orphan = try builder.disownRoot();
    try testing.expectEqual(@as(u32, 0), orphan.segmentId());
    try testing.expectEqual(@as(usize, 0), orphan.pointerWordIndex());
    try testing.expect(orphan.matchesLocation(0, 0));
    try testing.expectEqual(wire.PointerType.list, orphan.pointerType().?);
    try testing.expect(orphan.matchesPointerType(.list));
    try testing.expect(orphan.isListPointer());
    try testing.expect(orphan.isNearPointer());
    try testing.expect(!orphan.isStructPointer());
    try testing.expect(!orphan.isFarPointer());
    try testing.expect(!orphan.isOtherPointer());
    try testing.expect(!orphan.isCapabilityPointer());
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
    try testing.expect(cap_orphan.matchesPointerType(.other));
    try testing.expect(cap_orphan.isOtherPointer());
    try testing.expect(cap_orphan.isCapabilityPointer());
    try testing.expect(cap_orphan.isNearPointer());
    try testing.expect(!cap_orphan.isListPointer());
    try testing.expectEqual(@as(usize, 5151), try cap_orphan.maxCapabilityCount());
    try testing.expect(cap_orphan.matchesMaxCapabilityCount(5151));
    try testing.expect(!cap_orphan.matchesMaxCapabilityCount(5150));
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

test "pointer builders copy any pointer values from builders" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 0, .pointer_count = 3 });
    try (try source_root.getPointerField(0)).setText("any builder");
    const source_struct = try (try source_root.getPointerField(1)).initStruct(.{ .data_words = 1, .pointer_count = 1 });
    try source_struct.setUInt32(0, 0xace0, 0);
    try source_struct.setText(0, "struct builder");
    const source_list = try (try source_root.getPointerField(2)).initList(.two_bytes, 2);
    try source_list.setUInt16(0, 123);
    try source_list.setUInt16(1, 456);

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer target.deinit();
    const target_root = try target.initRoot(.{ .data_words = 0, .pointer_count = 3 });
    try (try target_root.getPointerField(0)).copyFromBuilder(try source_root.getPointerField(0));
    try (try target_root.getPointerField(1)).copyFromBuilder(try source_root.getPointerField(1));
    try (try target_root.getPointerField(2)).copyFromBuilder(try source_root.getPointerField(2));

    var reader = MessageReader.init(try target.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    try testing.expectEqualSlices(u8, "any builder", try read_root.getPointerField(0).getText());
    const read_struct = try read_root.getPointerField(1).getStruct(null);
    try testing.expectEqual(@as(u32, 0xace0), read_struct.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "struct builder", try read_struct.getPointerField(0).getText());
    const read_list = try read_root.getPointerField(2).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 123), read_list.getUInt16(0));
    try testing.expectEqual(@as(u16, 456), read_list.getUInt16(1));
}

test "orphanages allocate copies from builders" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try source_root.setUInt32(0, 0xfacefeed, 0);
    try source_root.setText(0, "builder orphan");
    const source_list = try (try source_root.getPointerField(1)).initList(.two_bytes, 2);
    try source_list.setUInt16(0, 100);
    try source_list.setUInt16(1, 200);

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer target.deinit();
    var struct_orphan = try target.newOrphanCopyStructFromBuilder(source_root);
    var list_orphan = try target.newOrphanCopyListFromBuilder(source_list);
    var pointer_orphan = try target.newOrphanCopyPointerFromBuilder(try source_root.getPointerField(0));
    const orphanage = Orphanage.init(&target);
    var struct_orphan_from_orphanage = try orphanage.newCopyStructFromBuilder(source_root);
    var list_orphan_from_orphanage = try orphanage.newCopyListFromBuilder(source_list);
    var pointer_orphan_from_orphanage = try orphanage.newCopyPointerFromBuilder(try source_root.getPointerField(0));

    const target_root = try target.initRoot(.{ .data_words = 0, .pointer_count = 6 });
    try (try target_root.getPointerField(0)).adopt(&struct_orphan);
    try (try target_root.getPointerField(1)).adopt(&list_orphan);
    try (try target_root.getPointerField(2)).adopt(&pointer_orphan);
    try (try target_root.getPointerField(3)).adopt(&struct_orphan_from_orphanage);
    try (try target_root.getPointerField(4)).adopt(&list_orphan_from_orphanage);
    try (try target_root.getPointerField(5)).adopt(&pointer_orphan_from_orphanage);

    var reader = MessageReader.init(try target.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    const copied_struct = try read_root.getPointerField(0).getStruct(null);
    try testing.expectEqual(@as(u32, 0xfacefeed), copied_struct.getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "builder orphan", try copied_struct.getPointerField(0).getText());
    const copied_list = try read_root.getPointerField(1).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 200), copied_list.getUInt16(1));
    try testing.expectEqualSlices(u8, "builder orphan", try read_root.getPointerField(2).getText());
    const copied_struct_2 = try read_root.getPointerField(3).getStruct(null);
    try testing.expectEqual(@as(u32, 0xfacefeed), copied_struct_2.getUInt32(0, 0));
    const copied_list_2 = try read_root.getPointerField(4).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 100), copied_list_2.getUInt16(0));
    try testing.expectEqualSlices(u8, "builder orphan", try read_root.getPointerField(5).getText());
}

test "orphanages allocate canonical copies" {
    const testing = std.testing;
    var source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer source.deinit();
    const source_root = try source.initRoot(.{ .data_words = 2, .pointer_count = 2 });
    const source_list = try (try source_root.getPointerField(1)).initStructList(1, .{ .data_words = 2, .pointer_count = 2 });
    const source_item = try source_list.getStructElement(0);
    try source_item.setUInt32(0, 0x5150, 0);
    try source_item.setText(0, "canonical list orphan");
    var source_reader = MessageReader.init(try source.segmentsConst(), .{});
    const source_root_reader = try source_reader.getRoot();
    const source_root_pointer = try source_reader.getRootPointer();
    const source_list_reader = try source_root_reader.getPointerField(1).getList(.composite);

    var wide_source = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 16 });
    defer wide_source.deinit();
    const wide_source_root = try wide_source.initRoot(.{ .data_words = 2, .pointer_count = 2 });
    try wide_source_root.setUInt32(0, 0xc0ffee, 0);
    try wide_source_root.setText(0, "canonical orphan");
    var wide_source_reader = MessageReader.init(try wide_source.segmentsConst(), .{});
    const wide_source_root_reader = try wide_source_reader.getRoot();

    var target = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 32 });
    defer target.deinit();
    var struct_orphan = try target.newOrphanCopyStructCanonical(wide_source_root_reader);
    var list_orphan = try target.newOrphanCopyListCanonical(source_list_reader);
    var pointer_orphan = try target.newOrphanCopyPointerCanonical(source_root_pointer);
    const orphanage = Orphanage.init(&target);
    var struct_orphan_from_builder = try orphanage.newCopyStructCanonicalFromBuilder(wide_source_root);
    var list_orphan_from_builder = try orphanage.newCopyListCanonicalFromBuilder(source_list);
    var pointer_orphan_from_builder = try orphanage.newCopyPointerCanonicalFromBuilder(try source.getRootPointer());

    const target_root = try target.initRoot(.{ .data_words = 0, .pointer_count = 6 });
    try (try target_root.getPointerField(0)).adopt(&struct_orphan);
    try (try target_root.getPointerField(1)).adopt(&list_orphan);
    try (try target_root.getPointerField(2)).adopt(&pointer_orphan);
    try (try target_root.getPointerField(3)).adopt(&struct_orphan_from_builder);
    try (try target_root.getPointerField(4)).adopt(&list_orphan_from_builder);
    try (try target_root.getPointerField(5)).adopt(&pointer_orphan_from_builder);

    var reader = MessageReader.init(try target.segmentsConst(), .{});
    const read_root = try reader.getRoot();
    const copied_struct = try read_root.getPointerField(0).getStruct(null);
    try testing.expectEqual(@as(u16, 1), copied_struct.pointer_count);
    try testing.expectEqual(@as(u32, 0xc0ffee), copied_struct.getUInt32(0, 0));
    const copied_list = try read_root.getPointerField(1).getList(.composite);
    try testing.expectEqual(@as(u16, 1), copied_list.structElementSize().pointer_count);
    const copied_pointer_struct = try read_root.getPointerField(2).getStruct(null);
    try testing.expectEqual(@as(u16, 2), copied_pointer_struct.pointer_count);
    const copied_struct_from_builder = try read_root.getPointerField(3).getStruct(null);
    try testing.expectEqual(@as(u16, 1), copied_struct_from_builder.pointer_count);
    const copied_list_from_builder = try read_root.getPointerField(4).getList(.composite);
    try testing.expectEqual(@as(u16, 1), copied_list_from_builder.structElementSize().pointer_count);
    const copied_pointer_from_builder = try read_root.getPointerField(5).getStruct(null);
    try testing.expectEqual(@as(u16, 2), copied_pointer_from_builder.pointer_count);
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

test "accessors report oversized derived offsets instead of trapping" {
    const testing = std.testing;
    const max = std.math.maxInt(usize);

    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1 });
    defer builder.deinit();

    const huge_pointer_builder = PointerBuilder{
        .message = &builder,
        .segment_id = 0,
        .word_index = max,
    };
    try testing.expectEqual(@as(wire.Word, 0), huge_pointer_builder.raw());
    huge_pointer_builder.clear();
    const disowned = huge_pointer_builder.disown();
    try testing.expect(disowned.isNull());
    try testing.expectError(error.SegmentOutOfBounds, huge_pointer_builder.initStruct(.{ .data_words = 0, .pointer_count = 0 }));

    const huge_struct_builder = StructBuilder{
        .message = &builder,
        .segment_id = 0,
        .data_start = max,
        .pointer_start = max,
        .data_words = 1,
        .pointer_count = 2,
    };
    try testing.expectError(error.MessageTooLarge, huge_struct_builder.getPointerField(1));
    try testing.expectEqual(@as(usize, 0), huge_struct_builder.dataSectionBytes().len);
    try testing.expectError(error.PointerOutOfBounds, huge_struct_builder.setUInt8(0, 1, 0));
    try testing.expectError(error.PointerOutOfBounds, huge_struct_builder.getUInt8(0, 0));
    try testing.expectError(error.PointerOutOfBounds, huge_struct_builder.setBool(0, true, false));
    try testing.expectError(error.PointerOutOfBounds, huge_struct_builder.getBool(0, false));
    try testing.expectError(error.PointerOutOfBounds, (StructBuilder{
        .message = &builder,
        .segment_id = 0,
        .data_start = max,
        .pointer_start = 0,
        .data_words = 1,
        .pointer_count = 0,
    }).clear());
    try testing.expectEqual(@as(usize, 3), try structEndWord(0, 1, 2));
    try testing.expectError(error.MessageTooLarge, structEndWord(max, 1, 0));
    var same_segment_reader = MessageReader.init(try builder.segmentsConst(), .{});
    try testing.expectError(error.PointerOutOfBounds, huge_struct_builder.copyFromReader(.{
        .message = &same_segment_reader,
        .segment_id = 0,
        .data_start = 0,
        .pointer_start = 0,
        .data_words = 0,
        .pointer_count = 0,
        .nesting_left = 1,
    }));

    const huge_pointer_list_builder = ListBuilder{
        .message = &builder,
        .segment_id = 0,
        .start = max,
        .element_count = 2,
        .element_size = .pointer,
        .data_words = 0,
        .pointer_count = 1,
        .step_bits = wire.bits_per_word,
    };
    try testing.expectError(error.MessageTooLarge, huge_pointer_list_builder.getPointerElement(1));

    const huge_struct_list_builder = ListBuilder{
        .message = &builder,
        .segment_id = 0,
        .start = max,
        .element_count = 1,
        .element_size = .composite,
        .data_words = 1,
        .pointer_count = 0,
        .step_bits = wire.bits_per_word,
    };
    try testing.expectError(error.MessageTooLarge, huge_struct_list_builder.getStructElement(0));

    const huge_primitive_list_builder = ListBuilder{
        .message = &builder,
        .segment_id = 0,
        .start = 0,
        .element_count = max,
        .element_size = .eight_bytes,
        .data_words = 0,
        .pointer_count = 0,
        .step_bits = wire.bits_per_word,
    };
    const overflowing_u64_index = max / @sizeOf(u64) + 1;
    try testing.expectError(error.MessageTooLarge, huge_primitive_list_builder.getUInt64(overflowing_u64_index));
    try testing.expectError(error.MessageTooLarge, huge_primitive_list_builder.setUInt64(overflowing_u64_index, 1));

    const out_of_bounds_primitive_list_builder = ListBuilder{
        .message = &builder,
        .segment_id = 0,
        .start = max,
        .element_count = 1,
        .element_size = .eight_bytes,
        .data_words = 0,
        .pointer_count = 0,
        .step_bits = wire.bits_per_word,
    };
    try testing.expectEqual(@as(usize, 0), out_of_bounds_primitive_list_builder.bytes().len);
    try testing.expectError(error.PointerOutOfBounds, out_of_bounds_primitive_list_builder.getUInt64(0));
    try testing.expectError(error.PointerOutOfBounds, out_of_bounds_primitive_list_builder.setUInt64(0, 1));

    const huge_bit_list_builder = ListBuilder{
        .message = &builder,
        .segment_id = 0,
        .start = max,
        .element_count = 1,
        .element_size = .bit,
        .data_words = 0,
        .pointer_count = 0,
        .step_bits = 1,
    };
    try testing.expectError(error.MessageTooLarge, huge_bit_list_builder.getBool(0));
    try testing.expectError(error.MessageTooLarge, huge_bit_list_builder.setBool(0, true));

    const segment = [_]u8{0} ** wire.bytes_per_word;
    var reader = MessageReader.init(&.{&segment}, .{});

    var empty_reader = MessageReader.init(&.{}, .{});
    const huge_struct_reader = StructReader{
        .message = &empty_reader,
        .segment_id = 0,
        .data_start = max,
        .pointer_start = max,
        .data_words = 1,
        .pointer_count = 2,
        .nesting_left = 1,
    };
    try testing.expectEqual(true, huge_struct_reader.getBool(0, true));
    try testing.expectEqual(@as(u8, 77), huge_struct_reader.getUInt8(0, 77));
    try testing.expectEqual(@as(usize, 0), huge_struct_reader.dataSectionBytes().len);
    try testing.expect(huge_struct_reader.getPointerField(1).isNull());
    {
        var copy_builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 2 });
        defer copy_builder.deinit();
        const copy_destination = try copy_builder.initRoot(.{ .data_words = 1, .pointer_count = 0 });
        try testing.expectError(error.SegmentOutOfBounds, copy_destination.copyFromReader(huge_struct_reader));
    }

    const overflowing_data_canonical_struct_reader = StructReader{
        .message = &reader,
        .segment_id = 0,
        .data_start = max,
        .pointer_start = 0,
        .data_words = 2,
        .pointer_count = 0,
        .nesting_left = 1,
    };
    try testing.expectError(error.MessageTooLarge, canonicalStructSize(overflowing_data_canonical_struct_reader));

    const overflowing_pointer_canonical_struct_reader = StructReader{
        .message = &reader,
        .segment_id = 0,
        .data_start = 0,
        .pointer_start = max,
        .data_words = 0,
        .pointer_count = 2,
        .nesting_left = 1,
    };
    try testing.expectError(error.MessageTooLarge, canonicalStructSize(overflowing_pointer_canonical_struct_reader));

    const overflowing_pointer_canonical_struct_list_reader = ListReader{
        .message = &reader,
        .segment_id = 0,
        .start = max,
        .element_count = 1,
        .element_size = .composite,
        .data_words = 0,
        .pointer_count = 2,
        .step_bits = wire.bits_per_word * 2,
        .nesting_left = 1,
    };
    try testing.expectError(error.MessageTooLarge, canonicalStructListSize(overflowing_pointer_canonical_struct_list_reader));

    var two_segment_reader = MessageReader.init(&.{ &segment, &segment }, .{});
    const invalid_destination = StructBuilder{
        .message = &builder,
        .segment_id = 1,
        .data_start = 0,
        .pointer_start = 0,
        .data_words = 0,
        .pointer_count = 0,
    };
    try testing.expectError(error.SegmentOutOfBounds, invalid_destination.copyFromReader(.{
        .message = &two_segment_reader,
        .segment_id = 1,
        .data_start = 0,
        .pointer_start = 0,
        .data_words = 0,
        .pointer_count = 0,
        .nesting_left = 1,
    }));

    const huge_bit_list_reader = ListReader{
        .message = &reader,
        .segment_id = 0,
        .start = max,
        .element_count = 1,
        .element_size = .bit,
        .data_words = 0,
        .pointer_count = 0,
        .step_bits = 1,
        .nesting_left = 1,
    };
    try testing.expect(!huge_bit_list_reader.getBool(0));
    try testing.expectEqual(@as(usize, 0), huge_bit_list_reader.bytes().len);
    try testing.expectError(error.MessageTooLarge, huge_bit_list_reader.rawPrimitiveBytes());

    const huge_pointer_list_reader = ListReader{
        .message = &reader,
        .segment_id = 0,
        .start = max,
        .element_count = 2,
        .element_size = .pointer,
        .data_words = 0,
        .pointer_count = 1,
        .step_bits = wire.bits_per_word,
        .nesting_left = 1,
    };
    try testing.expectError(error.MessageTooLarge, huge_pointer_list_reader.getPointerElement(1));

    const huge_struct_list_reader = ListReader{
        .message = &reader,
        .segment_id = 0,
        .start = max,
        .element_count = 1,
        .element_size = .composite,
        .data_words = 1,
        .pointer_count = 0,
        .step_bits = wire.bits_per_word,
        .nesting_left = 1,
    };
    try testing.expectError(error.MessageTooLarge, huge_struct_list_reader.getStructElement(0));
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

    var builder_canonical = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer builder_canonical.deinit();
    const builder_canonical_root = try builder_canonical.copyRootCanonicalFromBuilder(root);
    try testing.expectEqual(@as(u16, 1), builder_canonical_root.data_words);
    try testing.expectEqual(@as(u16, 1), builder_canonical_root.pointer_count);
    try testing.expectEqualSlices(u8, "kept", try (try builder_canonical_root.getPointerField(0)).getText());

    var pointer_canonical = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer pointer_canonical.deinit();
    const pointer_canonical_root = try pointer_canonical.copyRootPointerCanonicalFromBuilder(try builder.getRootPointer());
    const pointer_canonical_struct = (try pointer_canonical_root.decode()).?.struct_ptr;
    try testing.expectEqual(@as(u16, 1), pointer_canonical_struct.data_words);
    try testing.expectEqual(@as(u16, 1), pointer_canonical_struct.pointer_count);

    var target_canonical = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 1, .next_segment_min_words = 1 });
    defer target_canonical.deinit();
    _ = try builder.copyRootCanonicalToBuilder(&target_canonical);
    const target_canonical_root = try target_canonical.getRoot();
    try testing.expectEqual(@as(u16, 1), target_canonical_root.data_words);
    try testing.expectEqual(@as(u16, 1), target_canonical_root.pointer_count);
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
    const half_words_as_bytes = try read_root.getPointerField(3).getList(.byte);
    try testing.expectEqual(@as(usize, 2), half_words_as_bytes.len());
    try testing.expectEqual(@as(u8, 0x55), half_words_as_bytes.getUInt8(0));
    try testing.expectEqual(@as(u8, 0x77), half_words_as_bytes.getUInt8(1));
    try testing.expectError(error.IncompatibleListShape, read_root.getPointerField(3).getList(.four_bytes));
    try testing.expectError(error.IncompatibleListShape, read_root.getPointerField(3).getList(.bit));

    const double_word_structs = try read_root.getPointerField(4).getList(.composite);
    try testing.expectEqual(@as(u32, 0x8899_aabb), (try double_word_structs.getStructElement(0)).getUInt32(0, 0));
    try testing.expectEqual(@as(u32, 0xccdd_eeff), (try double_word_structs.getStructElement(1)).getUInt32(0, 0));
    const double_words_as_half_words = try read_root.getPointerField(4).getList(.two_bytes);
    try testing.expectEqual(@as(usize, 2), double_words_as_half_words.len());
    try testing.expectEqual(@as(u16, 0xaabb), double_words_as_half_words.getUInt16(0));
    try testing.expectEqual(@as(u16, 0xeeff), double_words_as_half_words.getUInt16(1));
    const double_words_as_bytes = try read_root.getPointerField(4).getList(.byte);
    try testing.expectEqual(@as(u8, 0xbb), double_words_as_bytes.getUInt8(0));
    try testing.expectEqual(@as(u8, 0xff), double_words_as_bytes.getUInt8(1));
    try testing.expectError(error.IncompatibleListShape, read_root.getPointerField(4).getList(.eight_bytes));

    const bit_structs = try read_root.getPointerField(5).getList(.composite);
    try testing.expectEqual(@as(usize, 3), bit_structs.len());
    try testing.expect((try bit_structs.getStructElement(0)).getBool(0, false));
    try testing.expect(!(try bit_structs.getStructElement(1)).getBool(0, false));
    try testing.expect((try bit_structs.getStructElement(2)).getBool(0, false));
    try testing.expectEqual(@as(u8, 0xee), (try bit_structs.getStructElement(0)).getUInt8(0, 0xee));
    try testing.expectEqual(@as(usize, 1), (try bit_structs.totalSize()).word_count);

    const half_words_as_bytes_builder = try (try root.getPointerField(3)).getList(.byte);
    try testing.expectEqual(@as(usize, 2), half_words_as_bytes_builder.len());
    try testing.expectEqual(@as(usize, 16), half_words_as_bytes_builder.elementBitCount());
    try testing.expectEqual(@as(u8, 0x55), try half_words_as_bytes_builder.getUInt8(0));
    try testing.expectEqual(@as(u8, 0x77), try half_words_as_bytes_builder.getUInt8(1));
    try half_words_as_bytes_builder.setUInt8(1, 0x99);
    try testing.expectEqual(@as(u16, 0x6699), try half_words.getUInt16(1));

    const double_words_as_half_builder = try (try root.getPointerField(4)).getList(.two_bytes);
    try testing.expectEqual(@as(u16, 0xaabb), try double_words_as_half_builder.getUInt16(0));
    try testing.expectEqual(@as(u16, 0xeeff), try double_words_as_half_builder.getUInt16(1));
    try double_words_as_half_builder.setUInt16(0, 0x1234);
    try testing.expectEqual(@as(u32, 0x8899_1234), try double_words.getUInt32(0));

    const double_word_structs_builder = try (try root.getPointerField(4)).getList(.composite);
    try testing.expectEqual(@as(u32, 0x8899_1234), try (try double_word_structs_builder.getStructElement(0)).getUInt32(0, 0));
    try (try double_word_structs_builder.getStructElement(1)).setUInt16(0, 0x1357, 0);
    try testing.expectEqual(@as(u32, 0xccdd_1357), try double_words.getUInt32(1));

    const bit_structs_builder = try (try root.getPointerField(5)).getList(.composite);
    try (try bit_structs_builder.getStructElement(1)).setBool(0, true, false);
    try testing.expect(try bits.getBool(1));
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
