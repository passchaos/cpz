const std = @import("std");
const cpz = @import("cpz");

const usage =
    \\usage: cpzc [--runtime-import name] [--namespace name] [--emit-raw-schema-comments] <schema.capnp> [output.zig]
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
    var runtime_import_name: []const u8 = "cpz";
    var namespace: ?[]const u8 = null;
    var emit_raw_schema_comments = false;
    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--runtime-import")) {
            runtime_import_name = args.next() orelse {
                std.debug.print("{s}", .{usage});
                return 2;
            };
        } else if (std.mem.eql(u8, arg, "--namespace")) {
            namespace = args.next() orelse {
                std.debug.print("{s}", .{usage});
                return 2;
            };
        } else if (std.mem.eql(u8, arg, "--emit-raw-schema-comments")) {
            emit_raw_schema_comments = true;
        } else if (input_path == null) {
            input_path = arg;
        } else if (output_path == null) {
            output_path = arg;
        } else {
            std.debug.print("{s}", .{usage});
            return 2;
        }
    }
    const input = input_path orelse {
        std.debug.print("{s}", .{usage});
        return 2;
    };

    const source = try std.Io.Dir.cwd().readFileAlloc(io, input, allocator, .limited(64 * 1024 * 1024));
    defer allocator.free(source);

    var file = try cpz.schema.parse(allocator, source);
    defer file.deinit(allocator);
    var layouts = try cpz.schema.planLayouts(allocator, &file);
    defer layouts.deinit(allocator);
    const code = try cpz.schema.generateZigWithOptions(allocator, &file, &layouts, .{
        .runtime_import_name = runtime_import_name,
        .raw_schema_comment = if (emit_raw_schema_comments) source else null,
        .namespace = namespace,
    });
    defer allocator.free(code);

    if (output_path) |path| {
        if (std.fs.path.dirname(path)) |parent| {
            if (parent.len != 0 and !std.mem.eql(u8, parent, ".")) {
                try std.Io.Dir.cwd().createDirPath(io, parent);
            }
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = code });
    } else {
        try std.Io.File.stdout().writeStreamingAll(io, code);
    }
    return 0;
}
