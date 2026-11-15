const std = @import("std");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const mod_const_emit = @import("const_emit.zig");
const mod_flat = @import("flat.zig");
const mod_interface = @import("interface.zig");
const mod_state = @import("state.zig");
const mod_text = @import("text.zig");

const ConstListItem = frontend.ConstListItem;
const Field = frontend.Field;
const FieldSlot = frontend.FieldSlot;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const StructLayout = frontend.StructLayout;
const Type = frontend.Type;
const findEnum = frontend.findEnum;
const findInterface = frontend.findInterface;
const findStructDirect = frontend.findStructDirect;
const isStructLikeName = frontend.isStructLikeName;
const parseConstStructFieldsAlloc = frontend.parseConstStructFieldsAlloc;
const parseInlineConstListElementsAlloc = frontend.parseInlineConstListElementsAlloc;
const planStructLayout = frontend.planStructLayout;
const resolveConstReferenceLiteral = frontend.resolveConstReferenceLiteral;
const resolveTypeScoped = frontend.resolveTypeScoped;
const typeAcceptsNullPointerDefault = frontend.typeAcceptsNullPointerDefault;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const emitFlatContainerSizeHelpers = mod_const_emit.emitFlatContainerSizeHelpers;
const emitNullPointerFlatContainer = mod_const_emit.emitNullPointerFlatContainer;
const emitScalarConstFlatContainer = mod_const_emit.emitScalarConstFlatContainer;
const appendByteListPointerAtWord = mod_flat.appendByteListPointerAtWord;
const appendOptionalAnyPointerListPointer = mod_flat.appendOptionalAnyPointerListPointer;
const appendOptionalStructListPointer = mod_flat.appendOptionalStructListPointer;
const appendScalarListPointer = mod_flat.appendScalarListPointer;
const appendStructListPointer = mod_flat.appendStructListPointer;
const emitEmbeddedStructConst = mod_flat.emitEmbeddedStructConst;
const fieldBlobDefaultBytesAlloc = mod_flat.fieldBlobDefaultBytesAlloc;
const flatByteLenForSegmentBytes = mod_flat.flatByteLenForSegmentBytes;
const inlineDataBytesAlloc = mod_flat.inlineDataBytesAlloc;
const inlineQuotedStringBytesAlloc = mod_flat.inlineQuotedStringBytesAlloc;
const referencedBlobBytesAlloc = mod_flat.referencedBlobBytesAlloc;
const rootPointerListElementWordIndex = mod_flat.rootPointerListElementWordIndex;
const structLiteralObjectBytesAlloc = mod_flat.structLiteralObjectBytesAlloc;
const wordByteLen = mod_flat.wordByteLen;
const writeWordBytes = mod_flat.writeWordBytes;
const defaultExpressionIsNullPointer = mod_interface.defaultExpressionIsNullPointer;
const defaultExpressionIsVoidPointer = mod_interface.defaultExpressionIsVoidPointer;
const emitMethodListDefaultGetters = mod_interface.emitMethodListDefaultGetters;
const methodAnyPointerDefaultFlatBytesAlloc = mod_interface.methodAnyPointerDefaultFlatBytesAlloc;
const methodListDefaultFlatBytesAlloc = mod_interface.methodListDefaultFlatBytesAlloc;
const AnyPointerDefaultKind = mod_state.AnyPointerDefaultKind;
const appendFmt = mod_text.appendFmt;
const zigRawStringLiteralAlloc = mod_text.zigRawStringLiteralAlloc;
const zigTypeRefAlloc = mod_text.zigTypeRefAlloc;

pub fn constListItemsFromInlineLiteralAlloc(allocator: std.mem.Allocator, literal: []const u8) LayoutError![]ConstListItem {
    const raw_items = try parseInlineConstListElementsAlloc(allocator, literal);
    defer allocator.free(raw_items);
    const items = try allocator.alloc(ConstListItem, raw_items.len);
    errdefer allocator.free(items);
    for (raw_items, 0..) |item, index| {
        items[index] = .{ .index = index, .literal = item };
    }
    return items;
}

pub fn listTextOrDataFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool) LayoutError![]u8 {
    const items = try parseInlineConstListElementsAlloc(allocator, literal);
    defer allocator.free(items);

    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items, 0..) |item, index| {
        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item, is_text)) orelse if (is_text)
            try inlineQuotedStringBytesAlloc(allocator, item)
        else
            try inlineDataBytesAlloc(allocator, item);
        defer allocator.free(bytes);
        try appendByteListPointerAtWord(allocator, &segment, try rootPointerListElementWordIndex(index), bytes, is_text);
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listOptionalTextOrDataFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool) LayoutError![]u8 {
    const items = try parseInlineConstListElementsAlloc(allocator, literal);
    defer allocator.free(items);

    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items, 0..) |item, index| {
        // Optional blob-list elements encode absent values as null pointer slots.
        // Resolve const references before the null check so `List(?Text)` and
        // `List(?Data)` defaults can reuse `?Text = null` / `?Data = null`
        // constants without accidentally treating the spelling "null" as bytes.
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;

        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item, is_text)) orelse if (is_text)
            try inlineQuotedStringBytesAlloc(allocator, resolved_item)
        else
            try inlineDataBytesAlloc(allocator, resolved_item);
        defer allocator.free(bytes);
        try appendByteListPointerAtWord(allocator, &segment, try rootPointerListElementWordIndex(index), bytes, is_text);
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listStructFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, literal: []const u8) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendStructListPointer(allocator, file, scope, &segment, 0, 0, 0, type_name, literal);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listOptionalStructFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, literal: []const u8) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendOptionalStructListPointer(allocator, file, scope, &segment, 0, 0, 0, type_name, literal);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listOptionalAnyPointerDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime want: AnyPointerDefaultKind) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendOptionalAnyPointerListPointer(allocator, file, scope, &segment, 0, 0, 0, literal, want);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listNestedFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, child: Type, literal: []const u8) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendScalarListPointer(allocator, file, scope, &segment, 0, 0, 0, child, literal);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn blobFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, bytes: []const u8, comptime is_text: bool) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendByteListPointerAtWord(allocator, &segment, 0, bytes, is_text);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn emitBlobFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_name: []const u8, bytes: []const u8, comptime is_text: bool) LayoutError!void {
    const flat = try blobFieldDefaultFlatBytesAlloc(allocator, bytes, is_text);
    defer allocator.free(flat);
    const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
    defer allocator.free(flat_literal);
    const get_method = if (is_text) "getRootText" else "getRootData";
    try appendFmt(allocator, out,
        \\{s}pub const {s}Flat = struct {{
        \\{s}    pub const flatBytes: []const u8 = {s};
        \\{s}    pub const segment0: []const u8 = flatBytes[8..];
        \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
        \\
        \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
        \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
        \\{s}    }}
        \\
        \\{s}    pub fn get(message_reader: *cpz.MessageReader) ![]const u8 {{
        \\{s}        return message_reader.{s}();
        \\{s}    }}
        \\
        \\{s}    pub fn getByteCount(message_reader: *cpz.MessageReader) !usize {{
        \\{s}        return (try @This().get(message_reader)).len;
        \\{s}    }}
        \\
    , .{ indent, container_name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, get_method, indent, indent, indent, indent });
    try emitFlatContainerSizeHelpers(allocator, out, indent);
    try appendFmt(allocator, out,
        \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\{s}        var @"cpz.reader" = reader(@"cpz.options");
        \\{s}        return @"cpz.reader".validate();
        \\{s}    }}
        \\{s}}};
        \\
    , .{ indent, indent, indent, indent, indent });
}

pub fn structFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, default_expression: []const u8) LayoutError!?[]u8 {
    const struct_decl = findStructDirect(file, type_name) orelse return null;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const fields = parseConstStructFieldsAlloc(allocator, default_expression) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return null,
        else => return err,
    };
    defer allocator.free(fields);
    const object = try structLiteralObjectBytesAlloc(allocator, file, scope, &layout, fields, true) orelse return null;
    defer allocator.free(object);
    const segment_words = object.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(object.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], object);
    return flat;
}

pub fn emitBlobFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, field_name: []const u8, bytes: []const u8, comptime is_text: bool) LayoutError!void {
    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(container_name);
    try emitBlobFlatContainer(allocator, out, indent, container_name, bytes, is_text);
}

pub fn emitAnyPointerFieldDefaultFlatContainerFromBytes(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    flat: []const u8,
    comptime kind: enum { any, struct_ptr, list },
) LayoutError!void {
    const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
    defer allocator.free(flat_literal);
    try appendFmt(allocator, out,
        \\{s}pub const {s}Flat = struct {{
        \\{s}    pub const flatBytes: []const u8 = {s};
        \\{s}    pub const segment0: []const u8 = flatBytes[8..];
        \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
        \\
        \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
        \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
        \\{s}    }}
        \\
        \\{s}    pub fn pointer(message_reader: *cpz.MessageReader) !cpz.PointerReader {{
        \\{s}        return message_reader.getRootPointer();
        \\{s}    }}
        \\
        \\{s}    pub fn pointerKind(message_reader: *cpz.MessageReader) !?cpz.wire.PointerType {{
        \\{s}        return (try @This().pointer(message_reader)).pointerType();
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    switch (kind) {
        .any => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !cpz.PointerReader {{
            \\{s}        return @This().pointer(message_reader);
            \\{s}    }}
            \\
            \\{s}    pub fn asStruct(message_reader: *cpz.MessageReader) !cpz.StructReader {{
            \\{s}        return (try @This().pointer(message_reader)).getStruct(null);
            \\{s}    }}
            \\
            \\{s}    pub fn asList(message_reader: *cpz.MessageReader, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}        return (try @This().pointer(message_reader)).getList(@"cpz.expected");
            \\{s}    }}
            \\
        , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent }),
        .struct_ptr => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !cpz.StructReader {{
            \\{s}        return (try @This().pointer(message_reader)).getStruct(null);
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .list => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}        return (try @This().pointer(message_reader)).getList(@"cpz.expected");
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
    }
    try emitFlatContainerSizeHelpers(allocator, out, indent);
    try appendFmt(allocator, out,
        \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\{s}        var @"cpz.reader" = reader(@"cpz.options");
        \\{s}        return @"cpz.reader".validate();
        \\{s}    }}
        \\{s}}};
        \\
    , .{ indent, indent, indent, indent, indent });
}

pub fn emitScalarFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, field_name: []const u8, ty: Type, literal: []const u8) LayoutError!void {
    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(container_name);
    emitScalarConstFlatContainer(allocator, out, file, scope, indent, container_name, ty, literal) catch |err| switch (err) {
        error.InvalidToken, error.UnsupportedType => return,
        else => return err,
    };
}

pub fn emitListFieldDefaultFlatContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, container_name: []const u8, child: Type, flat: []const u8) LayoutError!void {
    const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
    defer allocator.free(flat_literal);
    try appendFmt(allocator, out,
        \\{s}pub const {s}Flat = struct {{
        \\{s}    pub const flatBytes: []const u8 = {s};
        \\{s}    pub const segment0: []const u8 = flatBytes[8..];
        \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
        \\
        \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
        \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
        \\{s}    }}
        \\
    , .{ indent, container_name, indent, flat_literal, indent, indent, indent, indent, indent });
    try emitMethodListDefaultGetters(allocator, out, file, scope, indent, child);
    try emitFlatContainerSizeHelpers(allocator, out, indent);
    try appendFmt(allocator, out,
        \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\{s}        var @"cpz.reader" = reader(@"cpz.options");
        \\{s}        return @"cpz.reader".validate();
        \\{s}    }}
        \\{s}}};
        \\
    , .{ indent, indent, indent, indent, indent });
}

pub fn emitListFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, field_name: []const u8, child: Type, default_expression: []const u8) LayoutError!void {
    const flat = methodListDefaultFlatBytesAlloc(allocator, file, scope, child, default_expression) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
        else => return err,
    };
    defer allocator.free(flat);
    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(container_name);
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, container_name, child, flat);
}

pub fn emitStructFieldDefaultFlats(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    for (layout.fields) |field_layout| {
        const field = field_layout.field;
        if (field.default_expression.len == 0) continue;
        const field_name = try zigIdentAlloc(allocator, field.name);
        defer allocator.free(field_name);
        const resolved_ty = switch (resolveTypeScoped(file, layout.decl, field.ty)) {
            .optional => |child| blk: {
                const child_ty = resolveTypeScoped(file, layout.decl, child.*);
                if (defaultExpressionIsNullPointer(file, layout.decl, field.default_expression) or defaultExpressionIsVoidPointer(file, layout.decl, field.default_expression, child_ty)) {
                    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                    defer allocator.free(container_name);
                    try emitNullPointerFlatContainer(allocator, out, "    ", container_name);
                    continue;
                }
                break :blk child_ty;
            },
            else => |resolved| resolved,
        };
        if ((defaultExpressionIsNullPointer(file, layout.decl, field.default_expression) and typeAcceptsNullPointerDefault(file, resolved_ty)) or defaultExpressionIsVoidPointer(file, layout.decl, field.default_expression, resolved_ty)) {
            const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
            defer allocator.free(container_name);
            try emitNullPointerFlatContainer(allocator, out, "    ", container_name);
            continue;
        }
        switch (resolved_ty) {
            .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => {
                if (!mod_state.emit_introspection_enabled) continue;
                const literal = field.default_literal orelse continue;
                try emitScalarFieldDefaultFlatContainer(allocator, out, file, layout.decl, "    ", field_name, resolved_ty, literal);
            },
            .text => {
                if (!mod_state.emit_introspection_enabled) continue;
                const bytes = try fieldBlobDefaultBytesAlloc(allocator, file, layout.decl, field, true) orelse continue;
                defer allocator.free(bytes);
                try emitBlobFieldDefaultFlatContainer(allocator, out, "    ", field_name, bytes, true);
            },
            .data => {
                if (!mod_state.emit_introspection_enabled) continue;
                const bytes = try fieldBlobDefaultBytesAlloc(allocator, file, layout.decl, field, false) orelse continue;
                defer allocator.free(bytes);
                try emitBlobFieldDefaultFlatContainer(allocator, out, "    ", field_name, bytes, false);
            },
            .list => |list_child| try emitListFieldDefaultFlatContainer(allocator, out, file, layout.decl, "    ", field_name, list_child.*, resolveConstReferenceLiteral(file, layout.decl, field.default_expression)),
            .any_pointer => {
                const flat = methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .any) catch |err| switch (err) {
                    error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => continue,
                    else => return err,
                };
                defer allocator.free(flat);
                const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                defer allocator.free(container_name);
                try emitAnyPointerFieldDefaultFlatContainerFromBytes(allocator, out, "    ", container_name, flat, .any);
            },
            .any_struct => {
                const flat = methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .struct_ptr) catch |err| switch (err) {
                    error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => continue,
                    else => return err,
                };
                defer allocator.free(flat);
                const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                defer allocator.free(container_name);
                try emitAnyPointerFieldDefaultFlatContainerFromBytes(allocator, out, "    ", container_name, flat, .struct_ptr);
            },
            .any_list => {
                const flat = methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .list) catch |err| switch (err) {
                    error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => continue,
                    else => return err,
                };
                defer allocator.free(flat);
                const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                defer allocator.free(container_name);
                try emitAnyPointerFieldDefaultFlatContainerFromBytes(allocator, out, "    ", container_name, flat, .list);
            },
            .named => |type_name| {
                if (findEnum(file, type_name) != null) {
                    if (!mod_state.emit_introspection_enabled) continue;
                    const literal = field.default_literal orelse continue;
                    try emitScalarFieldDefaultFlatContainer(allocator, out, file, layout.decl, "    ", field_name, resolved_ty, literal);
                    continue;
                }
                if (findInterface(file, type_name) != null or !isStructLikeName(file, type_name)) continue;
                const flat = (try structFieldDefaultFlatBytesAlloc(allocator, file, layout.decl, type_name, resolveConstReferenceLiteral(file, layout.decl, field.default_expression))) orelse continue;
                defer allocator.free(flat);
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                const container_name = try std.fmt.allocPrint(allocator, "{s}DefaultFlat", .{field_name});
                defer allocator.free(container_name);
                try emitEmbeddedStructConst(allocator, out, "    ", container_name, zig_type, flat);
            },
            else => continue,
        }
    }
}

pub fn structFieldDefaultFlatIsEmitted(allocator: std.mem.Allocator, file: *const File, layout: *const StructLayout, field: *const Field, type_name: []const u8) LayoutError!bool {
    if (field.default_expression.len == 0) return false;
    if (defaultExpressionIsNullPointer(file, layout.decl, field.default_expression)) return false;
    if (findInterface(file, type_name) != null or !isStructLikeName(file, type_name)) return false;
    const flat = (try structFieldDefaultFlatBytesAlloc(allocator, file, layout.decl, type_name, resolveConstReferenceLiteral(file, layout.decl, field.default_expression))) orelse return false;
    defer allocator.free(flat);
    return true;
}

pub fn listFieldDefaultFlatIsEmitted(allocator: std.mem.Allocator, file: *const File, layout: *const StructLayout, field: *const Field, child: Type) LayoutError!bool {
    if (field.default_expression.len == 0) return false;
    const flat = methodListDefaultFlatBytesAlloc(allocator, file, layout.decl, child, field.default_expression) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return false,
        else => return err,
    };
    defer allocator.free(flat);
    return true;
}

pub fn anyPointerFieldDefaultFlatIsEmitted(allocator: std.mem.Allocator, file: *const File, layout: *const StructLayout, field: *const Field, comptime want: enum { any, struct_ptr, list }) LayoutError!bool {
    if (field.default_expression.len == 0) return false;
    const flat = switch (want) {
        .any => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .any),
        .struct_ptr => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .struct_ptr),
        .list => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .list),
    } catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return false,
        else => return err,
    };
    defer allocator.free(flat);
    return true;
}

pub fn fieldSlotMetadata(slot: FieldSlot) struct { name: []const u8, offset: usize } {
    return switch (slot) {
        .void => .{ .name = "void", .offset = 0 },
        .data_bit => |bit| .{ .name = "data_bit", .offset = bit },
        .data_byte => |byte| .{ .name = "data_byte", .offset = byte },
        .pointer => |index| .{ .name = "pointer", .offset = index },
    };
}
