const std = @import("std");
const cpz = @import("cpz");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var builder = try cpz.MessageBuilder.init(allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    // A tiny hand-written layout similar to an address-book root:
    // root.people @0 :List(Person)
    // Person.id   @0 :UInt32 (data byte offset 0)
    // Person.name @1 :Text   (pointer index 0)
    const root = try builder.initRoot(.{ .data_words = 0, .pointer_count = 1 });
    const people = try (try root.getPointerField(0)).initStructList(2, .{ .data_words = 1, .pointer_count = 1 });

    const alice = try people.getStructElement(0);
    try alice.setUInt32(0, 1001, 0);
    try alice.setText(0, "Alice");

    const bob = try people.getStructElement(1);
    try bob.setUInt32(0, 1002, 0);
    try bob.setText(0, "Bob");

    const flat = try cpz.serialize.messageToFlatBytes(allocator, try builder.segmentsConst());
    defer allocator.free(flat);

    std.debug.print("serialized {} bytes\n", .{flat.len});

    var parsed = try cpz.serialize.readFlatMessage(allocator, flat);
    defer parsed.deinit(allocator);

    var reader = cpz.MessageReader.init(parsed.segments, .{});
    const read_root = try reader.getRoot();
    const read_people = try read_root.getPointerField(0).getList(.composite);
    for (0..read_people.len()) |i| {
        const person = try read_people.getStructElement(i);
        std.debug.print("{}: {s}\n", .{ person.getUInt32(0, 0), try person.getPointerField(0).getText() });
    }
}
