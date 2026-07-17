const std = @import("std");
const cpz = @import("cpz");

const usage =
    \\usage: cpzc [--help] [--runtime-import name] [--namespace name] [--check] [--emit-raw-schema-comments] <schema.capnp> [output.zig]
    \\
    \\Parses a supported subset of Cap'n Proto schemas and emits Zig accessor skeletons.
    \\Use --check to validate parse/layout/codegen without writing generated output.
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
    var check = false;
    var emit_raw_schema_comments = false;
    var parse_options = true;
    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (parse_options and std.mem.eql(u8, arg, "--")) {
            parse_options = false;
        } else if (parse_options and optionValue(arg, "--runtime-import") != null) {
            runtime_import_name = optionValue(arg, "--runtime-import").?;
        } else if (parse_options and std.mem.eql(u8, arg, "--runtime-import")) {
            runtime_import_name = args.next() orelse {
                std.debug.print("{s}", .{usage});
                return 2;
            };
        } else if (parse_options and optionValue(arg, "--namespace") != null) {
            namespace = optionValue(arg, "--namespace").?;
        } else if (parse_options and std.mem.eql(u8, arg, "--namespace")) {
            namespace = args.next() orelse {
                std.debug.print("{s}", .{usage});
                return 2;
            };
        } else if (parse_options and std.mem.eql(u8, arg, "--check")) {
            check = true;
        } else if (parse_options and (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h"))) {
            try std.Io.File.stdout().writeStreamingAll(io, usage);
            return 0;
        } else if (parse_options and std.mem.eql(u8, arg, "--emit-raw-schema-comments")) {
            emit_raw_schema_comments = true;
        } else if (parse_options and std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("{s}", .{usage});
            return 2;
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
    const embed_base_dir = std.fs.path.dirname(input) orelse ".";
    try cpz.schema.loadEmbeddedConstValues(allocator, io, &file, embed_base_dir);
    var layouts = try cpz.schema.planLayouts(allocator, &file);
    defer layouts.deinit(allocator);
    const code = try cpz.schema.generateZigWithOptions(allocator, &file, &layouts, .{
        .runtime_import_name = runtime_import_name,
        .raw_schema_comment = if (emit_raw_schema_comments) source else null,
        .namespace = namespace,
    });
    defer allocator.free(code);

    if (check) return 0;

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

fn optionValue(arg: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name) or arg.len <= name.len or arg[name.len] != '=') return null;
    const value = arg[name.len + 1 ..];
    return if (value.len == 0) null else value;
}
