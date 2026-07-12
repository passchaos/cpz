const std = @import("std");
const cpz = @import("cpz");

const usage =
    \\usage: cpzc <schema.capnp> [output.zig]
    \\
    \\Parses a supported subset of Cap'n Proto schemas and emits Zig accessor skeletons.
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const io = init.io;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    _ = args.skip(); // executable name
    const input_path = args.next() orelse {
        std.debug.print("{s}", .{usage});
        return 2;
    };
    const output_path = args.next();
    if (args.next() != null) {
        std.debug.print("{s}", .{usage});
        return 2;
    }

    const source = try std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(64 * 1024 * 1024));
    defer allocator.free(source);

    var file = try cpz.schema.parse(allocator, source);
    defer file.deinit(allocator);
    var layouts = try cpz.schema.planLayouts(allocator, &file);
    defer layouts.deinit(allocator);
    const code = try cpz.schema.generateZig(allocator, &file, &layouts);
    defer allocator.free(code);

    if (output_path) |path| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = code });
    } else {
        try std.Io.File.stdout().writeStreamingAll(io, code);
    }
    return 0;
}
