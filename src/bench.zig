const std = @import("std");
const cpz = @import("cpz");

const Iterations = 100_000;

pub fn main() !void {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var builder = try cpz.MessageBuilder.init(allocator, .{ .first_segment_words = 4096 });
    defer builder.deinit();
    const root = try builder.initRoot(.{ .data_words = 1, .pointer_count = 2 });
    try root.setUInt32(0, 42, 0);
    try root.setText(0, "benchmark payload");
    const nums = try (try root.getPointerField(1)).initList(.four_bytes, 1024);
    for (0..nums.len()) |i| try nums.setUInt32(i, @intCast(i));

    const flat = try cpz.serialize.messageToFlatBytes(allocator, try builder.segmentsConst());
    defer allocator.free(flat);
    var parsed = try cpz.serialize.readFlatMessage(allocator, flat);
    defer parsed.deinit(allocator);

    var reader = cpz.MessageReader.init(parsed.segments, .{ .traversal_limit_words = Iterations * 4096 });
    const io = std.Io.Threaded.global_single_threaded.io();
    const start = std.Io.Clock.awake.now(io);
    var checksum: u64 = 0;
    for (0..Iterations) |_| {
        const r = try reader.getRoot();
        checksum +%= r.getUInt32(0, 0);
        const list = try r.getPointerField(1).getList(.four_bytes);
        checksum +%= list.getUInt32(17);
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    std.debug.print("{} iterations, {} ns, checksum {}\n", .{ Iterations, elapsed, checksum });
}
