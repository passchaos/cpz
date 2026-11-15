const std = @import("std");
const cpz = @import("cpz");
const generated = @import("generated_addressbook");

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer std.debug.assert(gpa_state.deinit() == .ok);
    const allocator = gpa_state.allocator();

    var builder = try cpz.MessageBuilder.init(allocator, .{ .first_segment_words = 32 });
    defer builder.deinit();

    _ = try builder.initRoot(generated.AddressBook.size);
    const book = try generated.AddressBook.getRootTyped(&builder);
    const people = try book.init_people(2);

    const alice = try people.get(0);
    try alice.set_id(1001);
    try alice.set_name("Alice");

    const bob = try people.get(1);
    try bob.set_id(1002);
    try bob.set_name("Bob");

    var reader = cpz.MessageReader.init(try builder.segmentsConst(), .{});
    const view = try generated.AddressBook.getRoot(&reader);
    const read_people = try view.people();
    for (0..read_people.len()) |i| {
        const person = try read_people.get(i);
        std.debug.print("{d}: {s}\n", .{ person.id(), try person.name() });
    }
}
