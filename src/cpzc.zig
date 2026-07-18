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
    var raw_args = std.ArrayList([]const u8).empty;
    defer raw_args.deinit(allocator);
    while (args.next()) |arg| try raw_args.append(allocator, arg);

    const parsed = parseCliArgs(raw_args.items);
    const options = switch (parsed) {
        .run => |options| options,
        .help => {
            try std.Io.File.stdout().writeStreamingAll(io, usage);
            return 0;
        },
        .usage_error => {
            std.debug.print("{s}", .{usage});
            return 2;
        },
    };
    const input = options.input_path.?;

    const source = try std.Io.Dir.cwd().readFileAlloc(io, input, allocator, .limited(64 * 1024 * 1024));
    defer allocator.free(source);

    var file = try cpz.schema.parse(allocator, source);
    defer file.deinit(allocator);
    const embed_base_dir = std.fs.path.dirname(input) orelse ".";
    try cpz.schema.loadEmbeddedConstValues(allocator, io, &file, embed_base_dir);
    var layouts = try cpz.schema.planLayouts(allocator, &file);
    defer layouts.deinit(allocator);
    const code = try cpz.schema.generateZigWithOptions(allocator, &file, &layouts, .{
        .runtime_import_name = options.runtime_import_name,
        .raw_schema_comment = if (options.emit_raw_schema_comments) source else null,
        .namespace = options.namespace,
    });
    defer allocator.free(code);

    if (options.check) return 0;

    if (options.output_path) |path| {
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

const CliOptions = struct {
    runtime_import_name: []const u8 = "cpz",
    namespace: ?[]const u8 = null,
    check: bool = false,
    emit_raw_schema_comments: bool = false,
    input_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
};

const CliParseResult = union(enum) {
    run: CliOptions,
    help,
    usage_error,
};

fn parseCliArgs(raw_args: []const []const u8) CliParseResult {
    var options: CliOptions = .{};
    var parse_options = true;
    var index: usize = 0;
    while (index < raw_args.len) {
        const arg = raw_args[index];
        index += 1;
        if (parse_options and std.mem.eql(u8, arg, "--")) {
            parse_options = false;
        } else if (parse_options and optionValue(arg, "--runtime-import") != null) {
            options.runtime_import_name = optionValue(arg, "--runtime-import").?;
        } else if (parse_options and std.mem.eql(u8, arg, "--runtime-import")) {
            if (index >= raw_args.len) return .usage_error;
            options.runtime_import_name = raw_args[index];
            index += 1;
        } else if (parse_options and optionValue(arg, "--namespace") != null) {
            options.namespace = optionValue(arg, "--namespace").?;
        } else if (parse_options and std.mem.eql(u8, arg, "--namespace")) {
            if (index >= raw_args.len) return .usage_error;
            options.namespace = raw_args[index];
            index += 1;
        } else if (parse_options and std.mem.eql(u8, arg, "--check")) {
            options.check = true;
        } else if (parse_options and (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h"))) {
            return .help;
        } else if (parse_options and std.mem.eql(u8, arg, "--emit-raw-schema-comments")) {
            options.emit_raw_schema_comments = true;
        } else if (parse_options and std.mem.startsWith(u8, arg, "-")) {
            return .usage_error;
        } else if (options.input_path == null) {
            options.input_path = arg;
        } else if (options.output_path == null) {
            options.output_path = arg;
        } else {
            return .usage_error;
        }
    }
    if (options.input_path == null) return .usage_error;
    return .{ .run = options };
}

fn optionValue(arg: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name) or arg.len <= name.len or arg[name.len] != '=') return null;
    const value = arg[name.len + 1 ..];
    return if (value.len == 0) null else value;
}

test "cpzc CLI parser handles help and option values" {
    try std.testing.expect(switch (parseCliArgs(&.{"--help"})) {
        .help => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{"-h"})) {
        .help => true,
        else => false,
    });

    const parsed = parseCliArgs(&.{
        "--check",
        "--runtime-import=runtime",
        "--namespace",
        "api",
        "--emit-raw-schema-comments",
        "schema.capnp",
        "out.zig",
    });
    const options = switch (parsed) {
        .run => |options| options,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expect(options.check);
    try std.testing.expect(options.emit_raw_schema_comments);
    try std.testing.expectEqualStrings("runtime", options.runtime_import_name);
    try std.testing.expectEqualStrings("api", options.namespace.?);
    try std.testing.expectEqualStrings("schema.capnp", options.input_path.?);
    try std.testing.expectEqualStrings("out.zig", options.output_path.?);
}

test "cpzc CLI parser rejects bad options and honors terminator" {
    try std.testing.expect(switch (parseCliArgs(&.{"--unknown"})) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{"--namespace"})) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--namespace=", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });

    const parsed = parseCliArgs(&.{ "--check", "--", "-dash.capnp" });
    const options = switch (parsed) {
        .run => |options| options,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expect(options.check);
    try std.testing.expectEqualStrings("-dash.capnp", options.input_path.?);
}
