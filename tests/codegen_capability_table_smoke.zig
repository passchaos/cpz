const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_capability_table_schema");

test "generated capability table helpers map fields and list elements" {
    var handles = try std.ArrayList([]const u8).initCapacity(std.testing.allocator, 8);
    defer handles.deinit(std.testing.allocator);
    for (0..8) |index| {
        handles.appendAssumeCapacity(switch (index) {
            1 => "cap",
            2 => "maybe-cap",
            3 => "list-cap",
            4 => "service",
            5 => "maybe-list-cap",
            6 => "list-service",
            7 => "maybe-list-service",
            else => "unused",
        });
    }
    const table = cpz.CapabilityTable([]const u8).init(handles.items);

    var builder = try cpz.MessageBuilder.init(std.testing.allocator, .{ .first_segment_words = 16 });
    defer builder.deinit();
    const root = try generated.CapabilityTableBox.initRootTyped(&builder);
    try root.set_cap(1);
    try root.set_maybeCapOrNull(2);
    try root.set_service(4);

    const caps = try root.init_caps(1);
    try caps.set(0, 3);
    const maybe_caps = try root.init_maybeCaps(2);
    try maybe_caps.set(0, 5);
    try maybe_caps.setOrNull(1, null);
    const services = try root.init_services(1);
    try services.set(0, 6);
    const maybe_services = try root.init_maybeServices(2);
    try maybe_services.set(0, 7);
    try maybe_services.setOrNull(1, null);

    try std.testing.expectEqualStrings("cap", try root.get_capFromTable([]const u8, table));
    try std.testing.expectEqualStrings("maybe-cap", (try root.get_maybeCapOrNullFromTable([]const u8, table)).?);
    try std.testing.expectEqualStrings("service", try root.get_serviceFromTable([]const u8, table));
    try std.testing.expectEqualStrings("list-cap", try caps.getFromTable(0, []const u8, table));
    try std.testing.expectEqualStrings("maybe-list-cap", (try maybe_caps.getOrNullFromTable(0, []const u8, table)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try maybe_caps.getOrNullFromTable(1, []const u8, table));
    try std.testing.expectEqualStrings("list-service", try services.getFromTable(0, []const u8, table));
    try std.testing.expectEqualStrings("maybe-list-service", (try maybe_services.getOrNullFromTable(0, []const u8, table)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try maybe_services.getOrNullFromTable(1, []const u8, table));

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const read_root = try generated.CapabilityTableBox.getRoot(&reader);
    try std.testing.expectEqualStrings("cap", try read_root.capFromTable([]const u8, table));
    try std.testing.expectEqualStrings("maybe-cap", (try read_root.maybeCapOrNullFromTable([]const u8, table)).?);
    try std.testing.expectEqualStrings("service", try read_root.serviceFromTable([]const u8, table));
    const read_caps = try read_root.caps();
    try std.testing.expectEqualStrings("list-cap", try read_caps.getFromTable(0, []const u8, table));
    const read_maybe_caps = try read_root.maybeCaps();
    try std.testing.expectEqualStrings("maybe-list-cap", (try read_maybe_caps.getOrNullFromTable(0, []const u8, table)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try read_maybe_caps.getOrNullFromTable(1, []const u8, table));
    const read_services = try read_root.services();
    try std.testing.expectEqualStrings("list-service", try read_services.getFromTable(0, []const u8, table));
    const read_maybe_services = try read_root.maybeServices();
    try std.testing.expectEqualStrings("maybe-list-service", (try read_maybe_services.getOrNullFromTable(0, []const u8, table)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try read_maybe_services.getOrNullFromTable(1, []const u8, table));
}
