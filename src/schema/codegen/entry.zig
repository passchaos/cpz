const std = @import("std");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const state = @import("state.zig");
const mod_const_emit = @import("const_emit.zig");
const mod_interface = @import("interface.zig");
const mod_metadata = @import("metadata.zig");
const mod_struct = @import("struct.zig");
const mod_text = @import("text.zig");
const mod_validate = @import("validate.zig");

const Error = frontend.Error;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const LayoutFile = frontend.LayoutFile;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const emitAlias = mod_const_emit.emitAlias;
const emitConst = mod_const_emit.emitConst;
const emitAnnotation = mod_interface.emitAnnotation;
const emitEnum = mod_interface.emitEnum;
const emitInterface = mod_interface.emitInterface;
const emitAliasMetadataTable = mod_metadata.emitAliasMetadataTable;
const emitAnnotationMetadataTable = mod_metadata.emitAnnotationMetadataTable;
const emitConstMetadataTable = mod_metadata.emitConstMetadataTable;
const emitDeclarationMetadataTable = mod_metadata.emitDeclarationMetadataTable;
const emitFileAnnotationMetadataTable = mod_metadata.emitFileAnnotationMetadataTable;
const emitImportMetadataTable = mod_metadata.emitImportMetadataTable;
const emitStruct = mod_struct.emitStruct;
const appendFmt = mod_text.appendFmt;
const zigRawStringLiteralAlloc = mod_text.zigRawStringLiteralAlloc;
const zigSchemaSyntaxLiteralAlloc = mod_text.zigSchemaSyntaxLiteralAlloc;
const validateZigNameCollisions = mod_validate.validateZigNameCollisions;

pub const CodegenOptions = struct {
    runtime_import_name: []const u8 = "cpz",
    raw_schema_comment: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    /// Emit schema introspection tables and `@"cpz.*"` lookup helpers.
    /// Disable this for a lean generated API that only contains wire accessors.
    emit_metadata: bool = true,
    /// Emit per-pointer-field introspection helpers such as pointer kind,
    /// location, decoded pointer, struct/list shape, stats, and match
    /// predicates. Disable this to keep only the accessors needed to read and
    /// build data.
    emit_introspection: bool = true,
};

/// Generate Zig accessors with default options. The caller owns the result.
pub fn generateZig(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile) LayoutError![]u8 {
    return generateZigWithOptions(allocator, file, layouts, .{});
}

/// Generate Zig accessors with explicit options. The caller owns the result.
pub fn generateZigWithOptions(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile, options: CodegenOptions) LayoutError![]u8 {
    try validateZigNameCollisions(allocator, file);

    const previous_emit_metadata = state.emit_metadata_enabled;
    state.emit_metadata_enabled = options.emit_metadata;
    defer state.emit_metadata_enabled = previous_emit_metadata;

    const previous_emit_introspection = state.emit_introspection_enabled;
    state.emit_introspection_enabled = options.emit_introspection;
    defer state.emit_introspection_enabled = previous_emit_introspection;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (options.raw_schema_comment) |source| {
        try appendRawSchemaComment(allocator, &out, source);
    }
    const runtime_import_literal = try zigRawStringLiteralAlloc(allocator, options.runtime_import_name);
    defer allocator.free(runtime_import_literal);
    if (options.namespace == null) {
        try appendFmt(allocator, &out,
            \\const std = @import("std");
            \\const cpz = @import({s});
            \\const @"cpz.schema" = @This();
            \\
            \\
        , .{runtime_import_literal});
    } else {
        try appendFmt(allocator, &out,
            \\const std = @import("std");
            \\const cpz = @import({s});
            \\
            \\
        , .{runtime_import_literal});
    }
    if (options.namespace) |raw_namespace| {
        const namespace = try zigIdentAlloc(allocator, raw_namespace);
        defer allocator.free(namespace);
        try appendFmt(allocator, &out,
            \\pub const {s} = struct {{
            \\    const @"cpz.schema" = @This();
            \\
        , .{namespace});
    }
    if (file.id) |id| {
        const indent = if (options.namespace != null) "    " else "";
        try appendFmt(allocator, &out,
            \\{s}pub const @"cpz.file_id": u64 = 0x{x};
            \\
            \\
        , .{ indent, id });
    }
    for (file.annotations_raw, 0..) |annotation_raw, index| {
        const indent = if (options.namespace != null) "    " else "";
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotation_raw);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, &out,
            \\{s}pub const @"cpz.file_annotation.{}": []const u8 = {s};
            \\
        , .{ indent, index, annotation_literal });
    }
    if (file.annotations_raw.len != 0) try out.append(allocator, '\n');
    try emitFileAnnotationMetadataTable(allocator, &out, file.annotations_raw, if (options.namespace != null) "    " else "");
    try emitDeclarationMetadataTable(allocator, &out, file, if (options.namespace != null) "    " else "");
    try emitImportMetadataTable(allocator, &out, file.imports, if (options.namespace != null) "    " else "");
    try emitAliasMetadataTable(allocator, &out, file, null, file.aliases, if (options.namespace != null) "    " else "");
    try emitConstMetadataTable(allocator, &out, file, null, file.consts, if (options.namespace != null) "    " else "");
    for (file.consts, 0..) |*decl, const_index| {
        try emitConst(allocator, &out, file, const_index, decl);
    }
    for (file.enums) |*decl| {
        try emitEnum(allocator, &out, decl);
    }
    for (file.interfaces) |*decl| {
        try emitInterface(allocator, &out, file, decl);
    }
    try emitAnnotationMetadataTable(allocator, &out, file, file.annotations, if (options.namespace != null) "    " else "");
    for (file.annotations) |*decl| {
        try emitAnnotation(allocator, &out, file, decl);
    }
    for (file.aliases, 0..) |*decl, alias_index| {
        try emitAlias(allocator, &out, file, null, alias_index, decl, "");
    }
    for (layouts.structs) |*layout| {
        try emitStruct(allocator, &out, file, layout);
    }
    if (options.namespace != null) {
        try out.appendSlice(allocator, "};\n");
    }
    if (!state.emit_metadata_enabled) stripRootHelperBlocks(&out);
    return out.toOwnedSlice(allocator);
}

pub fn stripRootHelperBlocks(out: *std.ArrayList(u8)) void {
    const start_marker = "    pub fn @\"cpz.root.isNull\"";
    const end_marker = "    pub fn fromReader(@\"cpz.reader\": cpz.StructReader)";
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, out.items, search_start, start_marker)) |start| {
        const end = std.mem.indexOfPos(u8, out.items, start, end_marker) orelse break;
        const remove_len = end - start;
        std.mem.copyForwards(u8, out.items[start..], out.items[end..]);
        out.items.len -= remove_len;
        search_start = start;
    }
}

pub fn appendRawSchemaComment(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8) std.mem.Allocator.Error!void {
    try out.appendSlice(allocator, "// cpz source schema begin\n");
    var start: usize = 0;
    while (start <= source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        try out.appendSlice(allocator, "// ");
        try out.appendSlice(allocator, source[start..end]);
        try out.append(allocator, '\n');
        if (end == source.len) break;
        start = end + 1;
    }
    try out.appendSlice(allocator, "// cpz source schema end\n\n");
}
