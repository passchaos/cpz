const std = @import("std");
const message = @import("../../message.zig");
const serialize = @import("../../serialize.zig");

const mod_resolve = @import("resolve.zig");
const mod_types = @import("types.zig");

const findEnum = mod_resolve.findEnum;
const findInterface = mod_resolve.findInterface;
const isStructLikeName = mod_resolve.isStructLikeName;
const resolveTypeScoped = mod_resolve.resolveTypeScoped;
const ConstDecl = mod_types.ConstDecl;
const Error = mod_types.Error;
const Field = mod_types.Field;
const File = mod_types.File;
const Struct = mod_types.Struct;

/// Errors produced while loading `embed` constant payloads from disk.
pub const EmbedError = std.Io.Dir.ReadFileAllocError || std.mem.Allocator.Error || serialize.Error || message.Error;

/// Load `embed` constant payloads relative to `base_dir`.
pub fn loadEmbeddedConstValues(allocator: std.mem.Allocator, io: std.Io, file: *File, base_dir: []const u8) EmbedError!void {
    try loadEmbeddedConstValuesInScope(allocator, io, file, null, file.consts, base_dir);
    for (file.structs) |*decl| {
        try loadEmbeddedConstValuesInScope(allocator, io, file, decl, decl.consts, base_dir);
    }
    for (file.interfaces) |*decl| {
        var empty_fields: [0]Field = .{};
        var alias_scope = Struct{
            .name = decl.name,
            .fields = empty_fields[0..],
            .consts = decl.consts,
            .aliases = decl.aliases,
        };
        try loadEmbeddedConstValuesInScope(allocator, io, file, &alias_scope, decl.consts, base_dir);
    }
}

pub fn loadEmbeddedConstValuesInScope(allocator: std.mem.Allocator, io: std.Io, file: *const File, scope: ?*const Struct, consts: []ConstDecl, base_dir: []const u8) EmbedError!void {
    for (consts) |*decl| {
        if (!decl.is_embed or decl.embed_path.len == 0 or decl.embed_bytes != null) continue;
        const is_struct_embed = switch (resolveTypeScoped(file, scope, decl.ty)) {
            .text, .data => false,
            .named => |type_name| findEnum(file, type_name) == null and findInterface(file, type_name) == null and isStructLikeName(file, type_name),
            else => continue,
        };
        const path = try embeddedConstPathAlloc(allocator, base_dir, decl.embed_path);
        defer allocator.free(path);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024));
        if (is_struct_embed) try validateEmbeddedStructBytes(allocator, bytes);
        decl.embed_bytes = bytes;
        decl.owns_embed_bytes = true;
        decl.emit_value = true;
    }
}

pub fn embeddedConstPathAlloc(allocator: std.mem.Allocator, base_dir: []const u8, embed_path: []const u8) std.mem.Allocator.Error![]u8 {
    if (std.fs.path.isAbsolute(embed_path) or base_dir.len == 0 or std.mem.eql(u8, base_dir, ".")) {
        return allocator.dupe(u8, embed_path);
    }
    return std.fs.path.join(allocator, &.{ base_dir, embed_path });
}

pub const EmbeddedSegmentRange = struct {
    start: usize,
    end: usize,
};

pub fn embeddedFlatSegmentRangesAlloc(allocator: std.mem.Allocator, bytes: []const u8) (std.mem.Allocator.Error || serialize.Error)![]EmbeddedSegmentRange {
    const expected_len = try serialize.expectedSize(bytes);
    if (bytes.len < expected_len) return error.MessageTruncated;
    const table = try serialize.parseSegmentTable(bytes[0..expected_len]);
    const ranges = try allocator.alloc(EmbeddedSegmentRange, table.segment_count);
    errdefer allocator.free(ranges);

    var offset = table.table_len;
    for (ranges, 0..) |*range, index| {
        const word_count = std.mem.readInt(u32, bytes[4 + index * 4 ..][0..4], .little);
        const byte_count = std.math.mul(usize, word_count, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
        range.* = .{ .start = offset, .end = offset + byte_count };
        offset += byte_count;
    }
    return ranges;
}

pub fn validateEmbeddedStructBytes(allocator: std.mem.Allocator, bytes: []const u8) EmbedError!void {
    const ranges = try embeddedFlatSegmentRangesAlloc(allocator, bytes);
    defer allocator.free(ranges);
    const segments = try allocator.alloc(serialize.ConstSegment, ranges.len);
    defer allocator.free(segments);
    for (ranges, 0..) |range, index| {
        segments[index] = bytes[range.start..range.end];
    }
    var root_reader = message.MessageReader.init(segments, .{
        .traversal_limit_words = std.math.maxInt(usize),
        .nesting_limit = std.math.maxInt(u16),
    });
    _ = try (try root_reader.getRootPointer()).getStruct(null);
    var validate_reader = message.MessageReader.init(segments, .{
        .traversal_limit_words = std.math.maxInt(usize),
        .nesting_limit = std.math.maxInt(u16),
    });
    _ = try validate_reader.validate();
}
