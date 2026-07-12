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
    const extra_builder = try holder_builder.init_extra();
    try extra_builder.set_code(321);
    try extra_builder.set_label("Anonymous import extra");
    const extras_builder = try holder_builder.init_extras(1);
    const list_extra = try extras_builder.get(0);
    try list_extra.set_code(654);
    try list_extra.set_label("Anonymous import list extra");

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
    const extra = try holder.extra();
    try std.testing.expectEqual(@as(u16, 321), extra.code());
    try std.testing.expectEqualSlices(u8, "Anonymous import extra", try extra.label());
    const extras = try holder.extras();
    const read_list_extra = try extras.get(0);
    try std.testing.expectEqual(@as(u16, 654), read_list_extra.code());
    try std.testing.expectEqualSlices(u8, "Anonymous import list extra", try read_list_extra.label());
}

test "generated schemas reference scoped imported modules" {
    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    const holder_builder = try generated.ScopedImportHolder.initRootTyped(&builder);
    const child_builder = try holder_builder.init_child();
    try child_builder.set_id(910);
    try child_builder.set_name("Scoped import child");
    const children_builder = try holder_builder.init_children(1);
    const list_child = try children_builder.get(0);
    try list_child.set_id(911);
    try list_child.set_name("Scoped import list child");
    const extra_builder = try holder_builder.init_extra();
    try extra_builder.set_code(912);
    try extra_builder.set_label("Scoped import extra");
    const extras_builder = try holder_builder.init_extras(1);
    const list_extra = try extras_builder.get(0);
    try list_extra.set_code(913);
    try list_extra.set_label("Scoped import list extra");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const holder = try generated.ScopedImportHolder.getRoot(&reader);
    const child = try holder.child();
    try std.testing.expectEqual(@as(u32, 910), child.id());
    try std.testing.expectEqualSlices(u8, "Scoped import child", try child.name());
    const children = try holder.children();
    const read_child = try children.get(0);
    try std.testing.expectEqual(@as(u32, 911), read_child.id());
    try std.testing.expectEqualSlices(u8, "Scoped import list child", try read_child.name());
    const extra = try holder.extra();
    try std.testing.expectEqual(@as(u16, 912), extra.code());
    try std.testing.expectEqualSlices(u8, "Scoped import extra", try extra.label());
    const extras = try holder.extras();
    const read_extra = try extras.get(0);
    try std.testing.expectEqual(@as(u16, 913), read_extra.code());
    try std.testing.expectEqualSlices(u8, "Scoped import list extra", try read_extra.label());
}
