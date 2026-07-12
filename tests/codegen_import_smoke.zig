const std = @import("std");
const cpz = @import("cpz");
const Base = @import("Base");
const generated = @import("generated_import_use");

test "generated schemas reference imported modules" {
    var source_builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 8 });
    defer source_builder.deinit();
    const source_child_builder = try Base.Child.initRootTyped(&source_builder);
    try source_child_builder.set_id(777);
    try source_child_builder.set_name("Copied import");
    var source_reader = cpz.MessageReader.init(try source_builder.segmentsConst(), .{});
    const source_child = try Base.Child.getRoot(&source_reader);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();
    const holder_builder = try generated.Holder.initRootTyped(&builder);
    const child_builder = try holder_builder.init_child();
    try child_builder.set_id(123);
    try child_builder.set_name("Imported child");
    const children_builder = try holder_builder.init_children(1);
    const list_child = try children_builder.get(0);
    try list_child.set_id(456);
    try list_child.set_name("Imported list child");
    try holder_builder.set_shared_from(source_child);

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const holder = try generated.Holder.getRoot(&reader);
    const child = try holder.child();
    try std.testing.expectEqual(@as(u32, 123), child.id());
    try std.testing.expectEqualSlices(u8, "Imported child", try child.name());
    const children = try holder.children();
    const read_list_child = try children.get(0);
    try std.testing.expectEqual(@as(u32, 456), read_list_child.id());
    try std.testing.expectEqualSlices(u8, "Imported list child", try read_list_child.name());
    const shared = try holder.shared();
    try std.testing.expectEqual(@as(u32, 777), shared.id());
    try std.testing.expectEqualSlices(u8, "Copied import", try shared.name());
}
