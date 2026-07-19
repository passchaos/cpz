const std = @import("std");
const cpz = @import("cpz");

test "top-level pointer encode decode aliases match wire helpers" {
    const struct_raw = try cpz.encodeStructPointer(0, 2, 3);
    try std.testing.expectEqual(cpz.wire.PointerType.struct_ptr, cpz.pointerType(struct_raw));
    try std.testing.expectEqual(cpz.decodeStructPointer(struct_raw), cpz.wire.decodeStruct(struct_raw));
    try std.testing.expectEqual((try cpz.decodePointer(struct_raw)).struct_ptr, cpz.decodeStructPointer(struct_raw));

    const list_raw = try cpz.encodeListPointer(1, .two_bytes, 7);
    try std.testing.expectEqual(cpz.wire.PointerType.list, cpz.pointerType(list_raw));
    try std.testing.expectEqual(try cpz.decodeListPointer(list_raw), try cpz.wire.decodeList(list_raw));
    try std.testing.expectEqual((try cpz.decodePointer(list_raw)).list, try cpz.decodeListPointer(list_raw));

    const far_raw = try cpz.encodeFarPointer(true, 5, 9);
    try std.testing.expectEqual(cpz.wire.PointerType.far, cpz.pointerType(far_raw));
    try std.testing.expectEqual(cpz.decodeFarPointer(far_raw), cpz.wire.decodeFar(far_raw));
    try std.testing.expectEqual((try cpz.decodePointer(far_raw)).far, cpz.decodeFarPointer(far_raw));

    const cap_raw = cpz.encodeCapabilityPointer(123);
    try std.testing.expectEqual(cpz.wire.PointerType.other, cpz.pointerType(cap_raw));
    try std.testing.expectEqual(try cpz.decodeCapabilityPointer(cap_raw), try cpz.wire.decodeOther(cap_raw));
    try std.testing.expectEqual((try cpz.decodePointer(cap_raw)).other, try cpz.decodeCapabilityPointer(cap_raw));
}

test "top-level capability table resolves capability pointers" {
    const handles = [_]u32{ 10, 20, 30 };
    const table = cpz.CapabilityTable(u32).init(&handles);
    try std.testing.expectEqual(@as(usize, 3), table.maxCount());
    try std.testing.expectEqual(@as(u32, 30), try table.get(2));

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{});
    defer builder.deinit();
    try builder.setRootCapability(1);
    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    try std.testing.expectEqual(@as(u32, 20), try table.getPointer(try reader.getRootPointer()));
    try std.testing.expect(table.satisfiesStats(try reader.validate()));

    const list = try (try builder.getRootPointer()).initList(.pointer, 1);
    (try list.getPointerElement(0)).setCapability(2);
    try std.testing.expectEqual(@as(u32, 30), try table.getListBuilderElement(list, 0));
    var list_reader_message = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const read_list = try (try list_reader_message.getRootPointer()).getList(.pointer);
    try std.testing.expectEqual(@as(u32, 30), try table.getListElement(read_list, 0));

    var null_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{});
    defer null_builder.deinit();
    var null_reader = cpz.MessageReader.init(try null_builder.segmentsConst(), .{});
    try std.testing.expectEqual(@as(?u32, null), try table.getPointerOrNull(try null_reader.getRootPointer()));
}

test "top-level capability registry assigns indexes" {
    var registry: cpz.CapabilityRegistry([]const u8) = .{};
    defer registry.deinit(std.testing.allocator);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{});
    defer builder.deinit();
    try std.testing.expectEqual(@as(u32, 0), try registry.registerRoot(std.testing.allocator, &builder, "root"));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    try std.testing.expectEqualStrings("root", try registry.asTable().getPointer(try reader.getRootPointer()));
}
