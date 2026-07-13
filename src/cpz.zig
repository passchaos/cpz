//! cpz: a Zig runtime for the Cap'n Proto wire format.
//!
//! This package intentionally starts at the low-level runtime layer: words,
//! pointers, segments, packing, stream framing, and dynamic readers/builders.
//! Generated schema APIs can be layered on top while preserving these stable
//! primitives.

pub const wire = @import("wire.zig");
pub const serialize = @import("serialize.zig");
pub const packing = @import("packing.zig");
pub const message = @import("message.zig");
pub const schema = @import("schema.zig");

pub const Word = wire.Word;
pub const ElementSize = wire.ElementSize;
pub const StructSize = wire.StructSize;
pub const PointerType = wire.PointerType;
pub const StructPointer = wire.StructPointer;
pub const ListPointer = wire.ListPointer;
pub const FarPointer = wire.FarPointer;
pub const CapabilityPointer = wire.CapabilityPointer;
pub const DecodedPointer = wire.DecodedPointer;
pub const readWord = wire.readWord;
pub const readWordAt = wire.readWordAt;
pub const writeWordAt = wire.writeWordAt;
pub const pointerType = wire.pointerType;
pub const isNull = wire.isNull;
pub const decodePointer = wire.decode;
pub const decodeStructPointer = wire.decodeStruct;
pub const decodeListPointer = wire.decodeList;
pub const decodeFarPointer = wire.decodeFar;
pub const decodeCapabilityPointer = wire.decodeOther;
pub const encodeStructPointer = wire.encodeStruct;
pub const encodeListPointer = wire.encodeList;
pub const encodeFarPointer = wire.encodeFar;
pub const encodeCapabilityPointer = wire.encodeCapability;
pub const targetWordIndex = wire.targetWordIndex;
pub const offsetFromPointer = wire.offsetFromPointer;
pub const bitsPerElement = wire.bitsPerElement;
pub const wordsForBits = wire.wordsForBits;
pub const wordsForList = wire.wordsForList;
pub const wordsForStructList = wire.wordsForStructList;
pub const encodeStructListTag = wire.encodeStructListTag;
pub const decodeStructListTag = wire.decodeStructListTag;

pub const MessageBuilder = message.MessageBuilder;
pub const MessageReader = message.MessageReader;
pub const OwnedMessageReader = message.OwnedMessageReader;
pub const MessageReaderView = message.MessageReaderView;
pub const StructBuilder = message.StructBuilder;
pub const StructReader = message.StructReader;
pub const ListBuilder = message.ListBuilder;
pub const ListReader = message.ListReader;
pub const PointerBuilder = message.PointerBuilder;
pub const PointerReader = message.PointerReader;
pub const Orphan = message.Orphan;
pub const Orphanage = message.Orphanage;
pub const ReaderOptions = message.ReaderOptions;
pub const BuilderOptions = message.BuilderOptions;
pub const MessageStats = message.MessageStats;
pub const MessageSize = message.MessageSize;
pub const maxPackedSize = packing.maxPackedSize;
pub const unpackedSize = packing.unpackedSize;
pub const pack = packing.pack;
pub const packInto = packing.packInto;
pub const packToWriter = packing.packToWriter;
pub const unpack = packing.unpack;
pub const unpackInto = packing.unpackInto;
pub const Segment = serialize.Segment;
pub const ConstSegment = serialize.ConstSegment;
pub const FlatMessage = serialize.FlatMessage;
pub const FlatMessageView = serialize.FlatMessageView;
pub const max_segment_count = serialize.max_segment_count;
pub const computeSerializedSize = serialize.computeSerializedSize;
pub const computeSerializedSizeInWords = serialize.computeSerializedSizeInWords;
pub const segmentTableWords = serialize.segmentTableWords;
pub const segmentTableByteLen = serialize.segmentTableByteLen;
pub const writeSegmentTable = serialize.writeSegmentTable;
pub const serializeSegmentTable = serialize.serializeSegmentTable;
pub const messageToFlatBytes = serialize.messageToFlatBytes;
pub const messageToFlatBytesInto = serialize.messageToFlatBytesInto;
pub const writeMessageToWriter = serialize.writeMessageToWriter;
pub const messageToPackedBytes = serialize.messageToPackedBytes;
pub const messageToPackedBytesInto = serialize.messageToPackedBytesInto;
pub const writePackedMessageToWriter = serialize.writePackedMessageToWriter;
pub const writePackedMessageToWriterWithTableBuffer = serialize.writePackedMessageToWriterWithTableBuffer;
pub const readFlatMessage = serialize.readFlatMessage;
pub const readFlatMessageView = serialize.readFlatMessageView;
pub const readPackedMessage = serialize.readPackedMessage;
pub const readMessageFromReader = serialize.readMessageFromReader;
pub const readPackedMessageFromReader = serialize.readPackedMessageFromReader;
pub const toSingleSegmentFlatBytes = message.toSingleSegmentFlatBytes;
pub const toCanonicalSegmentBytes = message.toCanonicalSegmentBytes;
pub const expectedSize = serialize.expectedSize;
pub const expectedSizeInWordsFromPrefix = serialize.expectedSizeInWordsFromPrefix;

test "top-level stream framing helpers round-trip" {
    const std = @import("std");
    const testing = std.testing;

    var builder = try MessageBuilder.init(testing.allocator, .{ .first_segment_words = 8 });
    defer builder.deinit();

    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 1 });
    try root.setUInt32(0, 2026, 0);
    try root.setText(0, "top-level");

    const segments = try builder.segmentsConst();
    const flat = try messageToFlatBytes(testing.allocator, segments);
    defer testing.allocator.free(flat);
    try testing.expectEqual(flat.len, try computeSerializedSize(segments));
    try testing.expectEqual(flat.len / wire.bytes_per_word, try computeSerializedSizeInWords(segments));
    try testing.expectEqual(flat.len, try expectedSize(flat[0..wire.bytes_per_word]));
    try testing.expectEqual(flat.len / wire.bytes_per_word, try expectedSizeInWordsFromPrefix(flat[0..wire.bytes_per_word]));
    var flat_into_buffer: [128]u8 = undefined;
    const flat_into_len = try messageToFlatBytesInto(&flat_into_buffer, segments);
    try testing.expectEqualSlices(u8, flat, flat_into_buffer[0..flat_into_len]);

    var parsed = try readFlatMessage(testing.allocator, flat);
    defer parsed.deinit(testing.allocator);
    var reader = MessageReader.init(parsed.segments, .{});
    try testing.expectEqual(@as(u32, 2026), (try reader.getRoot()).getUInt32(0, 0));
    try testing.expectEqualSlices(u8, "top-level", try (try reader.getRoot()).getPointerField(0).getText());

    var view = try readFlatMessageView(testing.allocator, flat);
    defer view.deinit(testing.allocator);
    var view_reader = MessageReader.init(view.segments, .{});
    try testing.expectEqual(@as(u32, 2026), (try view_reader.getRoot()).getUInt32(0, 0));

    const packed_bytes = try messageToPackedBytes(testing.allocator, segments);
    defer testing.allocator.free(packed_bytes);
    var packed_into_table_buffer: [8]u8 = undefined;
    var packed_into_buffer: [128]u8 = undefined;
    const packed_into_len = try messageToPackedBytesInto(&packed_into_table_buffer, &packed_into_buffer, segments);
    var packed_into_reader = try readPackedMessage(testing.allocator, packed_into_buffer[0..packed_into_len]);
    defer packed_into_reader.deinit(testing.allocator);
    try testing.expectEqualSlices(u8, flat, packed_into_reader.bytes);
    var parsed_packed = try readPackedMessage(testing.allocator, packed_bytes);
    defer parsed_packed.deinit(testing.allocator);
    var packed_reader = MessageReader.init(parsed_packed.segments, .{});
    try testing.expectEqualSlices(u8, "top-level", try (try packed_reader.getRoot()).getPointerField(0).getText());

    const packed_flat = try pack(testing.allocator, flat);
    defer testing.allocator.free(packed_flat);
    const unpacked_flat = try unpack(testing.allocator, packed_flat);
    defer testing.allocator.free(unpacked_flat);
    try testing.expectEqualSlices(u8, flat, unpacked_flat);
    try testing.expectEqual(flat.len, try unpackedSize(packed_flat));
    const packed_flat_buffer = try testing.allocator.alloc(u8, try maxPackedSize(flat.len));
    defer testing.allocator.free(packed_flat_buffer);
    const packed_flat_len = try packInto(packed_flat_buffer, flat);
    try testing.expectEqualSlices(u8, packed_flat, packed_flat_buffer[0..packed_flat_len]);
    const unpacked_flat_buffer = try testing.allocator.alloc(u8, try unpackedSize(packed_flat));
    defer testing.allocator.free(unpacked_flat_buffer);
    const unpacked_flat_len = try unpackInto(unpacked_flat_buffer, packed_flat);
    try testing.expectEqualSlices(u8, flat, unpacked_flat_buffer[0..unpacked_flat_len]);
    var packed_flat_writer_buffer: [256]u8 = undefined;
    var packed_flat_writer = std.Io.Writer.fixed(&packed_flat_writer_buffer);
    try packToWriter(&packed_flat_writer, flat);
    try testing.expectEqualSlices(u8, packed_flat, std.Io.Writer.buffered(&packed_flat_writer));

    var flat_buffer: [128]u8 = undefined;
    var flat_writer = std.Io.Writer.fixed(&flat_buffer);
    try writeMessageToWriter(&flat_writer, segments);
    var flat_stream = std.Io.Reader.fixed(std.Io.Writer.buffered(&flat_writer));
    var streamed = try readMessageFromReader(testing.allocator, &flat_stream);
    defer streamed.deinit(testing.allocator);
    try testing.expectEqual(flat.len, streamed.consumed_len);

    var packed_buffer: [128]u8 = undefined;
    var packed_writer = std.Io.Writer.fixed(&packed_buffer);
    try writePackedMessageToWriter(testing.allocator, &packed_writer, segments);
    var packed_table_buffer: [8]u8 = undefined;
    var packed_buffer_no_alloc: [128]u8 = undefined;
    var packed_writer_no_alloc = std.Io.Writer.fixed(&packed_buffer_no_alloc);
    try writePackedMessageToWriterWithTableBuffer(&packed_table_buffer, &packed_writer_no_alloc, segments);
    try testing.expectEqualSlices(u8, std.Io.Writer.buffered(&packed_writer), std.Io.Writer.buffered(&packed_writer_no_alloc));
    var packed_stream = std.Io.Reader.fixed(std.Io.Writer.buffered(&packed_writer));
    var streamed_packed = try readPackedMessageFromReader(testing.allocator, &packed_stream);
    defer streamed_packed.deinit(testing.allocator);
    try testing.expectEqual(flat.len, streamed_packed.consumed_len);

    const table = try serializeSegmentTable(testing.allocator, segments);
    defer testing.allocator.free(table);
    try testing.expectEqual(segmentTableWords(segments.len) * wire.bytes_per_word, table.len);
    try testing.expectEqual(table.len, try segmentTableByteLen(segments.len));
    var stack_table: [16]u8 = undefined;
    const stack_table_len = try writeSegmentTable(&stack_table, segments);
    try testing.expectEqual(table.len, stack_table_len);
    try testing.expectEqualSlices(u8, table, stack_table[0..stack_table_len]);
}

test "top-level wire pointer type exports" {
    const std = @import("std");
    const testing = std.testing;

    const raw = try wire.encodeStruct(0, 1, 1);
    const decoded: DecodedPointer = try wire.decode(raw);
    try testing.expectEqual(PointerType.struct_ptr, decoded.kind());
    const ptr: StructPointer = decoded.asStruct().?;
    try testing.expectEqual(StructSize{ .data_words = 1, .pointer_count = 1 }, ptr.size());

    const list_raw = try wire.encodeList(0, .pointer, 2);
    const list: ListPointer = (try wire.decode(list_raw)).asList().?;
    try testing.expectEqual(ElementSize.pointer, list.elementSize());

    const far: FarPointer = wire.decodeFar(try wire.encodeFar(false, 4, 5));
    try testing.expect(far.isSingleFar());
    try testing.expectEqual(@as(u32, 5), far.landingPadSegmentId());

    const cap: CapabilityPointer = try wire.decodeOther(wire.encodeCapability(7));
    try testing.expect(cap.matchesIndex(7));
}

test "top-level wire helper exports" {
    const std = @import("std");
    const testing = std.testing;

    const raw = try encodeStructPointer(1, 2, 3);
    try testing.expectEqual(PointerType.struct_ptr, pointerType(raw));
    try testing.expect(!isNull(raw));
    const decoded = try decodePointer(raw);
    try testing.expectEqual(@as(u16, 2), decoded.asStruct().?.data_words);
    try testing.expectEqual(@as(i32, 1), decodeStructPointer(raw).offset_words);
    try testing.expectEqual(@as(usize, 4), try targetWordIndex(2, 1));
    try testing.expectEqual(@as(i32, 1), try offsetFromPointer(2, 4));

    const list_raw = try encodeListPointer(0, .byte, 9);
    try testing.expectEqual(@as(usize, 9), (try decodeListPointer(list_raw)).elementCountOrWordCount());
    try testing.expectEqual(@as(usize, 8), bitsPerElement(.byte));
    try testing.expectEqual(@as(usize, 1), wordsForBits(9));
    try testing.expectEqual(@as(usize, 2), try wordsForList(.two_bytes, 5));

    const tag_raw = try encodeStructListTag(4, .{ .data_words = 1, .pointer_count = 1 });
    const tag = try decodeStructListTag(tag_raw);
    try testing.expectEqual(@as(usize, 4), tag.element_count);
    try testing.expectEqual(@as(usize, 8), try wordsForStructList(4, tag.size));

    const far = decodeFarPointer(try encodeFarPointer(true, 6, 7));
    try testing.expect(far.isDoubleFar());
    try testing.expectEqual(@as(u32, 7), far.landingPadSegmentId());

    const cap = try decodeCapabilityPointer(encodeCapabilityPointer(11));
    try testing.expectEqual(@as(u32, 11), cap.capabilityIndex());

    var bytes: [wire.bytes_per_word]u8 = undefined;
    writeWordAt(&bytes, raw);
    try testing.expectEqual(raw, readWordAt(&bytes));
    try testing.expectEqual(raw, try readWord(&bytes, 0));
}

test {
    _ = wire;
    _ = serialize;
    _ = packing;
    _ = message;
    _ = schema;
}
