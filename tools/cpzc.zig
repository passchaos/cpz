const std = @import("std");
const cpz = @import("cpz");

const usage =
    \\usage: cpzc [--help] [--runtime-import name] [--namespace name] [--check] [--no-metadata] [--no-introspection] [--no-orphans] [--minimal] [--emit-raw-schema-comments] [--output-dir dir] <schema.capnp> [output.zig]
    \\
    \\Parses a supported subset of Cap'n Proto schemas and emits Zig accessor skeletons.
    \\Use --check to validate parse/layout/codegen without writing generated output.
    \\Use --no-metadata to omit schema introspection tables and @"cpz.*" lookup helpers.
    \\Use --no-introspection to omit per-field pointer introspection helpers.
    \\Use --no-orphans to omit Orphan wrapper types and copy/orphan helpers.
    \\Use --minimal to enable both metadata/introspection lean modes.
    \\Use --output-dir to write <schema-stem>.zig into a directory.
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
        .emit_metadata = options.emit_metadata,
        .emit_introspection = options.emit_introspection,
        .emit_orphan_helpers = options.emit_orphan_helpers,
    });
    defer allocator.free(code);

    if (options.check) return 0;

    var derived_output: ?[]u8 = null;
    defer if (derived_output) |path| allocator.free(path);
    const output_path = if (options.output_dir) |dir| blk: {
        const filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{std.fs.path.stem(input)});
        defer allocator.free(filename);
        derived_output = try std.fs.path.join(allocator, &.{ dir, filename });
        break :blk derived_output.?;
    } else options.output_path;

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

const CliOptions = struct {
    runtime_import_name: []const u8 = "cpz",
    namespace: ?[]const u8 = null,
    check: bool = false,
    emit_metadata: bool = true,
    emit_introspection: bool = true,
    emit_orphan_helpers: bool = true,
    emit_raw_schema_comments: bool = false,
    input_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
    output_dir: ?[]const u8 = null,
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
            const value = optionValue(arg, "--runtime-import").?;
            if (looksLikeOption(value)) return .usage_error;
            options.runtime_import_name = value;
        } else if (parse_options and std.mem.eql(u8, arg, "--runtime-import")) {
            if (index >= raw_args.len) return .usage_error;
            if (raw_args[index].len == 0 or looksLikeOption(raw_args[index])) return .usage_error;
            options.runtime_import_name = raw_args[index];
            index += 1;
        } else if (parse_options and optionValue(arg, "--namespace") != null) {
            const value = optionValue(arg, "--namespace").?;
            if (looksLikeOption(value)) return .usage_error;
            options.namespace = value;
        } else if (parse_options and std.mem.eql(u8, arg, "--namespace")) {
            if (index >= raw_args.len) return .usage_error;
            if (raw_args[index].len == 0 or looksLikeOption(raw_args[index])) return .usage_error;
            options.namespace = raw_args[index];
            index += 1;
        } else if (parse_options and optionValue(arg, "--output-dir") != null) {
            const value = optionValue(arg, "--output-dir").?;
            if (looksLikeOption(value)) return .usage_error;
            options.output_dir = value;
        } else if (parse_options and std.mem.eql(u8, arg, "--output-dir")) {
            if (index >= raw_args.len) return .usage_error;
            if (raw_args[index].len == 0 or looksLikeOption(raw_args[index])) return .usage_error;
            options.output_dir = raw_args[index];
            index += 1;
        } else if (parse_options and std.mem.eql(u8, arg, "--check")) {
            options.check = true;
        } else if (parse_options and (std.mem.eql(u8, arg, "--no-metadata") or std.mem.eql(u8, arg, "--lean"))) {
            options.emit_metadata = false;
        } else if (parse_options and std.mem.eql(u8, arg, "--emit-metadata")) {
            options.emit_metadata = true;
        } else if (parse_options and std.mem.eql(u8, arg, "--no-introspection")) {
            options.emit_introspection = false;
        } else if (parse_options and std.mem.eql(u8, arg, "--emit-introspection")) {
            options.emit_introspection = true;
        } else if (parse_options and std.mem.eql(u8, arg, "--no-orphans")) {
            options.emit_orphan_helpers = false;
        } else if (parse_options and std.mem.eql(u8, arg, "--emit-orphans")) {
            options.emit_orphan_helpers = true;
        } else if (parse_options and std.mem.eql(u8, arg, "--minimal")) {
            options.emit_metadata = false;
            options.emit_introspection = false;
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
    if (options.output_dir != null and options.output_path != null) return .usage_error;
    return .{ .run = options };
}

fn optionValue(arg: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name) or arg.len <= name.len or arg[name.len] != '=') return null;
    const value = arg[name.len + 1 ..];
    return if (value.len == 0) null else value;
}

fn looksLikeOption(value: []const u8) bool {
    return std.mem.startsWith(u8, value, "-");
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
        "--no-metadata",
        "--emit-raw-schema-comments",
        "schema.capnp",
        "out.zig",
    });
    const options = switch (parsed) {
        .run => |options| options,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expect(options.check);
    try std.testing.expect(!options.emit_metadata);
    try std.testing.expect(options.emit_raw_schema_comments);
    try std.testing.expectEqualStrings("runtime", options.runtime_import_name);
    try std.testing.expectEqualStrings("api", options.namespace.?);
    try std.testing.expectEqualStrings("schema.capnp", options.input_path.?);
    try std.testing.expectEqualStrings("out.zig", options.output_path.?);

    const lean = switch (parseCliArgs(&.{ "--lean", "schema.capnp" })) {
        .run => |lean_options| lean_options,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expect(!lean.emit_metadata);

    const metadata = switch (parseCliArgs(&.{ "--no-metadata", "--emit-metadata", "schema.capnp" })) {
        .run => |metadata_options| metadata_options,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expect(metadata.emit_metadata);

    const output_dir = switch (parseCliArgs(&.{ "--output-dir", "generated", "schema.capnp" })) {
        .run => |dir_options| dir_options,
        else => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqualStrings("generated", output_dir.output_dir.?);
    try std.testing.expect(output_dir.output_path == null);

    try std.testing.expect(switch (parseCliArgs(&.{ "--output-dir=generated", "schema.capnp", "out.zig" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{"--output-dir"})) {
        .usage_error => true,
        else => false,
    });
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
    try std.testing.expect(switch (parseCliArgs(&.{ "--runtime-import", "--check", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--namespace", "--check", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--namespace=", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--runtime-import=--bad", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--namespace=--bad", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--runtime-import", "", "schema.capnp" })) {
        .usage_error => true,
        else => false,
    });
    try std.testing.expect(switch (parseCliArgs(&.{ "--namespace", "", "schema.capnp" })) {
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
