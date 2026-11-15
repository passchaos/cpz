const std = @import("std");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");

const mod_const_emit = @import("const_emit.zig");
const mod_interface = @import("interface.zig");
const mod_state = @import("state.zig");
const mod_text = @import("text.zig");

const ConstDecl = frontend.ConstDecl;
const ConstListItem = frontend.ConstListItem;
const ConstStructField = frontend.ConstStructField;
const EnumDecl = frontend.EnumDecl;
const Field = frontend.Field;
const FieldLayout = frontend.FieldLayout;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const StructLayout = frontend.StructLayout;
const Type = frontend.Type;
const constDeclOwnerName = frontend.constDeclOwnerName;
const embeddedFlatSegmentRangesAlloc = frontend.embeddedFlatSegmentRangesAlloc;
const findConstInOwner = frontend.findConstInOwner;
const findConstReference = frontend.findConstReference;
const findEnum = frontend.findEnum;
const findInterface = frontend.findInterface;
const findInterfaceDirect = frontend.findInterfaceDirect;
const findStructDirect = frontend.findStructDirect;
const hexBytesAlloc = frontend.hexBytesAlloc;
const lastTopLevelDot = frontend.lastTopLevelDot;
const parseBoolLiteral = frontend.parseBoolLiteral;
const parseConstStructFieldsAlloc = frontend.parseConstStructFieldsAlloc;
const parseFloatLiteral = frontend.parseFloatLiteral;
const parseInlineConstListElementsAlloc = frontend.parseInlineConstListElementsAlloc;
const parseSignedLiteral = frontend.parseSignedLiteral;
const parseUnsignedLiteral = frontend.parseUnsignedLiteral;
const planStructLayout = frontend.planStructLayout;
const resolveConstDeclType = frontend.resolveConstDeclType;
const resolveConstReferenceLiteral = frontend.resolveConstReferenceLiteral;
const resolveTypeScoped = frontend.resolveTypeScoped;
const skipTriviaIndex = frontend.skipTriviaIndex;
const splitTypeApplicationArgsAlloc = frontend.splitTypeApplicationArgsAlloc;
const substituteGenericTypeAlloc = frontend.substituteGenericTypeAlloc;
const optionalBlobConstItemBytesAlloc = mod_const_emit.optionalBlobConstItemBytesAlloc;
const methodOptionalDefaultChildOrNullForDecl = mod_interface.methodOptionalDefaultChildOrNullForDecl;
const resolveConstDeclChildType = mod_interface.resolveConstDeclChildType;
const AnyPointerDefaultKind = mod_state.AnyPointerDefaultKind;
const appendFmt = mod_text.appendFmt;
const octalValue = mod_text.octalValue;
const resolvedEnumDefaultOrdinal = mod_text.resolvedEnumDefaultOrdinal;
const resolvedEnumLiteralOrdinal = mod_text.resolvedEnumLiteralOrdinal;
const zigRawStringLiteralAlloc = mod_text.zigRawStringLiteralAlloc;

pub const LayoutSpecialization = struct {
    fields: []Field = &.{},
    field_layouts: []FieldLayout = &.{},
    owned_names: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *LayoutSpecialization, allocator: std.mem.Allocator) void {
        for (self.fields) |*field| field.ty.deinit(allocator);
        allocator.free(self.fields);
        allocator.free(self.field_layouts);
        for (self.owned_names.items) |name| allocator.free(name);
        self.owned_names.deinit(allocator);
        self.* = undefined;
    }
};

pub fn scalarOrNamedType(name: []const u8) Type {
    if (std.mem.eql(u8, name, "Void")) return .void;
    if (std.mem.eql(u8, name, "Bool")) return .bool;
    if (std.mem.eql(u8, name, "Int8")) return .int8;
    if (std.mem.eql(u8, name, "Int16")) return .int16;
    if (std.mem.eql(u8, name, "Int32")) return .int32;
    if (std.mem.eql(u8, name, "Int64")) return .int64;
    if (std.mem.eql(u8, name, "UInt8")) return .uint8;
    if (std.mem.eql(u8, name, "UInt16")) return .uint16;
    if (std.mem.eql(u8, name, "UInt32")) return .uint32;
    if (std.mem.eql(u8, name, "UInt64")) return .uint64;
    if (std.mem.eql(u8, name, "Float32")) return .float32;
    if (std.mem.eql(u8, name, "Float64")) return .float64;
    if (std.mem.eql(u8, name, "Text")) return .text;
    if (std.mem.eql(u8, name, "Data")) return .data;
    if (std.mem.eql(u8, name, "AnyPointer")) return .any_pointer;
    if (std.mem.eql(u8, name, "AnyStruct")) return .any_struct;
    if (std.mem.eql(u8, name, "AnyList")) return .any_list;
    if (std.mem.eql(u8, name, "Capability")) return .capability;
    return .{ .named = name };
}

pub fn specializeLayoutForTypeApplicationAlloc(allocator: std.mem.Allocator, type_name: []const u8, layout: *StructLayout) LayoutError!?LayoutSpecialization {
    if (layout.decl.parameters.len == 0) return null;
    const args = (try splitTypeApplicationArgsAlloc(allocator, type_name)) orelse return null;
    defer {
        for (args) |*arg| arg.deinit(allocator);
        allocator.free(args);
    }
    if (args.len == 0) return null;
    var specialization = LayoutSpecialization{};
    errdefer specialization.deinit(allocator);
    specialization.fields = try allocator.alloc(Field, layout.fields.len);
    specialization.field_layouts = try allocator.alloc(FieldLayout, layout.fields.len);
    for (layout.fields, 0..) |field_layout, index| {
        specialization.fields[index] = field_layout.field.*;
        specialization.fields[index].ty = try substituteGenericTypeAlloc(allocator, &specialization.owned_names, field_layout.field.ty, layout.decl.parameters, args);
        specialization.field_layouts[index] = field_layout;
        specialization.field_layouts[index].field = &specialization.fields[index];
    }
    layout.fields = specialization.field_layouts;
    return specialization;
}

pub fn structListLiteralFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl) LayoutError!?[]u8 {
    const items = decl.list_items orelse return null;
    const child = switch (resolveTypeScoped(file, scope, decl.ty)) {
        .list => |list_child| list_child.*,
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .list => |list_child| list_child.*,
            else => return null,
        },
        else => return null,
    };
    const type_name = switch (resolveTypeScoped(file, scope, child)) {
        .named => |name| name,
        else => return null,
    };
    return listStructItemsFlatBytesAlloc(allocator, file, scope, type_name, items) catch |err| switch (err) {
        error.UnsupportedType => return null,
        else => return err,
    };
}

pub fn writeStructListItemIntoSegment(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    struct_decl: *const Struct,
    layout: *const StructLayout,
    item: ConstListItem,
    segment: *std.ArrayList(u8),
    object_start_words: usize,
    depth: usize,
) LayoutError!void {
    if (depth >= 32) return error.UnsupportedType;
    if (item.struct_fields.len != 0) {
        try writeStructLiteralFieldsIntoSegment(allocator, file, scope, layout, item.struct_fields, segment, object_start_words);
        return;
    }

    if (findConstReference(file, scope, item.literal)) |decl| {
        var decl_scope_fields: [0]Field = .{};
        var decl_scope_storage: Struct = undefined;
        const decl_scope = constDeclResolutionScope(file, scope, decl, decl_scope_fields[0..], &decl_scope_storage);
        if (decl.struct_fields) |fields| {
            try writeStructLiteralFieldsIntoSegment(allocator, file, decl_scope, layout, fields, segment, object_start_words);
            return;
        }
        try writeStructListItemIntoSegment(
            allocator,
            file,
            decl_scope,
            struct_decl,
            layout,
            .{ .index = item.index, .literal = decl.literal },
            segment,
            object_start_words,
            depth + 1,
        );
        return;
    }

    const fields = try parseStructLiteralOrImpliedFirstFieldAlloc(allocator, struct_decl, item.literal);
    defer allocator.free(fields);
    try writeStructLiteralFieldsIntoSegment(allocator, file, scope, layout, fields, segment, object_start_words);
}

pub fn listStructItemsFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, items: []const ConstListItem) LayoutError![]u8 {
    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const element_words = @as(usize, layout.data_words) + @as(usize, layout.pointer_count);
    if (element_words == 0) return error.UnsupportedType;
    const content_words = std.math.mul(usize, element_words, items.len) catch return error.SerializedSizeOverflow;

    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    const total_words = std.math.add(usize, content_words, 2) catch return error.SerializedSizeOverflow;
    const total_bytes = std.math.mul(usize, total_words, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
    try segment.appendNTimes(allocator, 0, total_bytes);
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .composite, content_words));
    writeWordBytes(segment.items[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeStructListTag(items.len, .{ .data_words = layout.data_words, .pointer_count = layout.pointer_count }));

    for (items) |item| {
        const element_offset = std.math.mul(usize, item.index, element_words) catch return error.SerializedSizeOverflow;
        const element_target = std.math.add(usize, 2, element_offset) catch return error.SerializedSizeOverflow;
        try writeStructListItemIntoSegment(allocator, file, scope, struct_decl, &layout, item, &segment, element_target, 0);
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

pub fn appendStructListItemPointer(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    segment: *std.ArrayList(u8),
    element_index: usize,
    list_start_words: usize,
    type_name: []const u8,
    item: ConstListItem,
) LayoutError!void {
    var item_segment = std.ArrayList(u8).empty;
    defer item_segment.deinit(allocator);

    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const object_words = @as(usize, layout.data_words) + @as(usize, layout.pointer_count);
    if (object_words == 0) return error.UnsupportedType;
    try item_segment.appendNTimes(allocator, 0, try wordByteLen(object_words));
    try writeStructListItemIntoSegment(allocator, file, scope, struct_decl, &layout, item, &item_segment, 0, 0);

    const pointer_word_index = try pointerListElementWordIndex(list_start_words, element_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    try segment.appendSlice(allocator, item_segment.items);
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeStruct(offset, layout.data_words, layout.pointer_count));
}

pub fn structLiteralTypeName(file: *const File, scope: ?*const Struct, ty: Type) ?[]const u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .named => |name| name,
        .optional => |child| switch (resolveTypeScoped(file, scope, child.*)) {
            .named => |name| name,
            else => null,
        },
        else => null,
    };
}

pub fn structLiteralFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl) LayoutError!?[]u8 {
    if (!decl.is_struct_literal) return null;
    const type_name = structLiteralTypeName(file, scope, decl.ty) orelse return null;
    const struct_decl = findStructDirect(file, type_name) orelse return null;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const original_layout_fields = layout.fields;
    var specialization = try specializeLayoutForTypeApplicationAlloc(allocator, type_name, &layout) orelse LayoutSpecialization{};
    defer {
        layout.fields = original_layout_fields;
        specialization.deinit(allocator);
    }
    const fields = decl.struct_fields orelse return null;

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

pub fn appendInlineListPointer(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, element_size: wire.ElementSize, element_count: usize) LayoutError![]u8 {
    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    const list_words = try wire.wordsForList(element_size, element_count);
    try segment.appendNTimes(allocator, 0, try wordByteLen(list_words));
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    const raw = try wire.encodeList(offset, element_size, element_count);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], raw);
    return segment.items[try wordByteOffset(target_word_index)..][0..try wordByteLen(list_words)];
}

pub fn inlineQuotedStringBytesAlloc(allocator: std.mem.Allocator, expression: []const u8) LayoutError![]u8 {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    var index: usize = 0;
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var saw_string = false;

    while (true) {
        index = try skipTriviaIndex(source, index);
        if (index >= source.len) break;
        if (source[index] != '"') return error.UnsupportedType;
        index += 1;
        const content_start = index;
        while (index < source.len) {
            if (source[index] == '\\') {
                index += 2;
            } else if (source[index] == '"') {
                break;
            } else {
                index += 1;
            }
        }
        if (index >= source.len) return error.UnexpectedToken;
        const decoded = try decodedStringBytesAlloc(allocator, source[content_start..index]);
        defer allocator.free(decoded);
        try out.appendSlice(allocator, decoded);
        saw_string = true;
        index += 1;
    }

    if (!saw_string) return error.UnsupportedType;
    return out.toOwnedSlice(allocator);
}

pub fn inlineDataBytesAlloc(allocator: std.mem.Allocator, expression: []const u8) LayoutError![]u8 {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    if (std.mem.startsWith(u8, source, "0x\"") and source.len >= 4 and source[source.len - 1] == '"') {
        return try hexBytesAlloc(allocator, source[3 .. source.len - 1]);
    }
    return inlineQuotedStringBytesAlloc(allocator, source);
}

pub fn appendPointerListPointer(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, element_count: usize) LayoutError!usize {
    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    const list_words = try wire.wordsForList(.pointer, element_count);
    try segment.appendNTimes(allocator, 0, try wordByteLen(list_words));
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    const raw = try wire.encodeList(offset, .pointer, element_count);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], raw);
    return target_word_index;
}

pub fn appendPointerListOfByteLists(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, items: []const []const u8, comptime text_items: bool) LayoutError!void {
    const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
    for (items, 0..) |item, index| {
        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item, text_items)) orelse ((if (text_items)
            inlineQuotedStringBytesAlloc(allocator, item)
        else
            inlineDataBytesAlloc(allocator, item)) catch |err| switch (err) {
            error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
            else => return err,
        });
        defer allocator.free(bytes);
        try appendByteListPointerAtWord(allocator, segment, try pointerListElementWordIndex(list_start_words, index), bytes, text_items);
    }
}

pub fn parseStructLiteralOrImpliedFirstFieldAlloc(allocator: std.mem.Allocator, struct_decl: *const Struct, literal: []const u8) LayoutError![]ConstStructField {
    return parseConstStructFieldsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => {
            const raw = std.mem.trim(u8, literal, " \t\r\n");
            if (raw.len == 0 or raw[0] == '(') return error.UnsupportedType;
            if (struct_decl.fields.len == 0) return error.UnsupportedType;
            const fields = try allocator.alloc(ConstStructField, 1);
            fields[0] = .{ .index = 0, .name = struct_decl.fields[0].name, .literal = raw };
            return fields;
        },
        else => return err,
    };
}

pub fn appendStructLiteralPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, type_name: []const u8, literal: []const u8) LayoutError!void {
    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var nested_layout = try planStructLayout(allocator, file, struct_decl);
    defer nested_layout.deinit(allocator);
    const original_nested_layout_fields = nested_layout.fields;
    var nested_specialization = try specializeLayoutForTypeApplicationAlloc(allocator, type_name, &nested_layout) orelse LayoutSpecialization{};
    defer {
        nested_layout.fields = original_nested_layout_fields;
        nested_specialization.deinit(allocator);
    }
    const fields = try parseStructLiteralOrImpliedFirstFieldAlloc(allocator, struct_decl, literal);
    defer allocator.free(fields);

    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const object_words = @as(usize, nested_layout.data_words) + @as(usize, nested_layout.pointer_count);
    if (object_words == 0) {
        if (fields.len != 0) return error.UnsupportedType;
        writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeStruct(-1, 0, 0));
        return;
    }

    const target_word_index = segment.items.len / @sizeOf(u64);
    try segment.appendNTimes(allocator, 0, try wordByteLen(object_words));
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeStruct(offset, nested_layout.data_words, nested_layout.pointer_count));
    try writeStructLiteralFieldsIntoSegment(allocator, file, scope, &nested_layout, fields, segment, target_word_index);
}

pub fn appendStructListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, type_name: []const u8, literal: []const u8) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);
    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var element_layout = try planStructLayout(allocator, file, struct_decl);
    defer element_layout.deinit(allocator);
    const original_element_layout_fields = element_layout.fields;
    var element_specialization = try specializeLayoutForTypeApplicationAlloc(allocator, type_name, &element_layout) orelse LayoutSpecialization{};
    defer {
        element_layout.fields = original_element_layout_fields;
        element_specialization.deinit(allocator);
    }
    const element_words = @as(usize, element_layout.data_words) + @as(usize, element_layout.pointer_count);
    if (element_words == 0) return error.UnsupportedType;
    const content_words = std.math.mul(usize, element_words, items.len) catch return error.SerializedSizeOverflow;

    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    const appended_words = std.math.add(usize, content_words, 1) catch return error.SerializedSizeOverflow;
    const appended_bytes = std.math.mul(usize, appended_words, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
    try segment.appendNTimes(allocator, 0, appended_bytes);
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeList(offset, .composite, content_words));
    writeWordBytes(segment.items[try wordByteOffset(target_word_index)..][0..@sizeOf(u64)], try wire.encodeStructListTag(items.len, .{ .data_words = element_layout.data_words, .pointer_count = element_layout.pointer_count }));

    for (items, 0..) |item, index| {
        const fields = try parseStructLiteralOrImpliedFirstFieldAlloc(allocator, struct_decl, item);
        defer allocator.free(fields);
        const element_offset = std.math.mul(usize, index, element_words) catch return error.SerializedSizeOverflow;
        const elements_start = std.math.add(usize, target_word_index, 1) catch return error.SerializedSizeOverflow;
        const element_target = std.math.add(usize, elements_start, element_offset) catch return error.SerializedSizeOverflow;
        try writeStructLiteralFieldsIntoSegment(allocator, file, scope, &element_layout, fields, segment, element_target);
    }
}

pub fn appendScalarListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, child_ty: Type, literal: []const u8) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);
    switch (resolveTypeScoped(file, scope, child_ty)) {
        .void => {
            _ = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .void, items.len);
            for (items) |item| if (!std.mem.eql(u8, resolveScalarConstLiteral(file, scope, item), "void")) return error.UnsupportedType;
        },
        .bool => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .bit, items.len);
            for (items, 0..) |item, index| {
                const value = parseBoolLiteral(resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                if (value) setBit(data, index);
            }
        },
        .int8 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .byte, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i8, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                data[index] = @bitCast(value);
            }
        },
        .int16 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .two_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i16, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u16, data[index * @sizeOf(u16) ..][0..@sizeOf(u16)], @bitCast(value), .little);
            }
        },
        .int32 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .four_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i32, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u32, data[index * @sizeOf(u32) ..][0..@sizeOf(u32)], @bitCast(value), .little);
            }
        },
        .int64 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .eight_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i64, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u64, data[try wordByteOffset(index)..][0..@sizeOf(u64)], @bitCast(value), .little);
            }
        },
        .uint8 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .byte, items.len);
            for (items, 0..) |item, index| {
                data[index] = parseUnsignedLiteral(u8, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
            }
        },
        .uint16 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .two_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseUnsignedLiteral(u16, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u16, data[index * @sizeOf(u16) ..][0..@sizeOf(u16)], value, .little);
            }
        },
        .uint32 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .four_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseUnsignedLiteral(u32, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u32, data[index * @sizeOf(u32) ..][0..@sizeOf(u32)], value, .little);
            }
        },
        .uint64 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .eight_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseUnsignedLiteral(u64, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u64, data[try wordByteOffset(index)..][0..@sizeOf(u64)], value, .little);
            }
        },
        .float32 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .four_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseFloatLiteral(f32, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u32, data[index * @sizeOf(u32) ..][0..@sizeOf(u32)], @bitCast(value), .little);
            }
        },
        .float64 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .eight_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseFloatLiteral(f64, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u64, data[try wordByteOffset(index)..][0..@sizeOf(u64)], @bitCast(value), .little);
            }
        },
        .text => try appendPointerListOfByteLists(allocator, file, scope, segment, pointer_index, data_words, object_start_words, items, true),
        .data => try appendPointerListOfByteLists(allocator, file, scope, segment, pointer_index, data_words, object_start_words, items, false),
        .list => |child| {
            const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
            for (items, 0..) |item, index| {
                try appendScalarListPointer(allocator, file, scope, segment, 0, 0, try pointerListElementWordIndex(list_start_words, index), child.*, item);
            }
        },
        .named => |type_name| {
            if (findEnum(file, type_name)) |enum_decl| {
                const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .two_bytes, items.len);
                for (items, 0..) |item, index| {
                    const value = resolvedEnumLiteralOrdinal(file, scope, enum_decl, item) orelse return error.UnsupportedType;
                    std.mem.writeInt(u16, data[index * @sizeOf(u16) ..][0..@sizeOf(u16)], value, .little);
                }
            } else {
                try appendStructListPointer(allocator, file, scope, segment, pointer_index, data_words, object_start_words, type_name, literal);
            }
        },
        else => return error.UnsupportedType,
    }
}

pub fn appendStructPointerFieldLiteral(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, layout: *const StructLayout, segment: *std.ArrayList(u8), pointer_index: usize, object_start_words: usize, ty: Type, literal: []const u8) LayoutError!void {
    const literal_scope = scope orelse layout.decl;
    const const_ref = findConstReference(file, literal_scope, literal);
    const resolved_literal = resolveConstReferenceLiteral(file, literal_scope, literal);
    switch (resolveTypeScoped(file, layout.decl, ty)) {
        .text => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, layout.decl, decl) == .text) {
                    const text = try constBlobBytesAlloc(allocator, file, literal_scope, decl, true);
                    defer allocator.free(text);
                    try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, text, true, object_start_words);
                    return;
                }
            }
            const text = inlineQuotedStringBytesAlloc(allocator, resolved_literal) catch |err| switch (err) {
                error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
                else => return err,
            };
            defer allocator.free(text);
            try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, text, true, object_start_words);
        },
        .data => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, layout.decl, decl) == .data) {
                    const data = try constBlobBytesAlloc(allocator, file, literal_scope, decl, false);
                    defer allocator.free(data);
                    try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, data, false, object_start_words);
                    return;
                }
            }
            const data = inlineDataBytesAlloc(allocator, resolved_literal) catch |err| switch (err) {
                error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
                else => return err,
            };
            defer allocator.free(data);
            try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, data, false, object_start_words);
        },
        .list => |child| try appendScalarListPointer(allocator, file, literal_scope, segment, pointer_index, layout.data_words, object_start_words, child.*, resolved_literal),
        .any_pointer => {
            if (const_ref) |decl| {
                return appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, decl.ty, decl.literal);
            }
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .any_struct => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, literal_scope, decl) == .named) {
                    return appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, decl.ty, decl.literal);
                }
            }
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .any_list => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, literal_scope, decl) == .list) {
                    return appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, decl.ty, decl.literal);
                }
            }
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .capability => {
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .named => |type_name| {
            if (findInterface(file, type_name) != null) {
                const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
                if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
                return error.UnsupportedType;
            }
            try appendStructLiteralPointer(allocator, file, literal_scope, segment, pointer_index, layout.data_words, object_start_words, type_name, resolved_literal);
        },
        .optional => |child| {
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "null")) return;
            try appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, child.*, resolved_literal);
        },
        else => return error.UnsupportedType,
    }
}

pub fn writeStructLiteralFieldsIntoSegment(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, layout: *const StructLayout, fields: []const ConstStructField, segment: *std.ArrayList(u8), object_start_words: usize) LayoutError!void {
    const object_start_bytes = try wordByteLen(object_start_words);
    for (fields) |const_field| {
        const field_layout = findFieldLayoutByNameOrGroupFirst(layout, const_field.name) orelse return error.UnsupportedType;
        const field = field_layout.field;
        const literal_scope = scope orelse layout.decl;
        const const_literal = resolveScalarConstLiteral(file, literal_scope, const_field.literal);
        const default_literal = if (field.default_literal) |literal| resolveScalarConstLiteral(file, layout.decl, literal) else null;
        if (field.union_index) |union_index| {
            const union_layout = layout.unions[@intCast(union_index)];
            std.mem.writeInt(u16, segment.items[object_start_bytes + union_layout.discriminant_byte ..][0..@sizeOf(u16)], field.union_discriminant, .little);
        }
        switch (field_layout.slot) {
            .void => {
                if (!std.mem.eql(u8, const_literal, "void")) return error.UnsupportedType;
            },
            .data_bit => |bit_offset| switch (resolveTypeScoped(file, layout.decl, field.ty)) {
                .bool => {
                    const value = parseBoolLiteral(const_literal) orelse return error.UnsupportedType;
                    const default_value = parseBoolLiteral(default_literal orelse "false") orelse return error.UnsupportedType;
                    if (value != default_value) setBit(segment.items[object_start_bytes..], bit_offset);
                },
                else => return error.UnsupportedType,
            },
            .data_byte => |byte_offset| switch (resolveTypeScoped(file, layout.decl, field.ty)) {
                .int8 => {
                    const value = parseSignedLiteral(i8, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i8, default_literal orelse "0") orelse return error.UnsupportedType;
                    segment.items[object_start_bytes + byte_offset] = @as(u8, @bitCast(value)) ^ @as(u8, @bitCast(default_value));
                },
                .int16 => {
                    const value = parseSignedLiteral(i16, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i16, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u16 = @as(u16, @bitCast(value)) ^ @as(u16, @bitCast(default_value));
                    std.mem.writeInt(u16, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u16)], stored, .little);
                },
                .int32 => {
                    const value = parseSignedLiteral(i32, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i32, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u32 = @as(u32, @bitCast(value)) ^ @as(u32, @bitCast(default_value));
                    std.mem.writeInt(u32, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u32)], stored, .little);
                },
                .int64 => {
                    const value = parseSignedLiteral(i64, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i64, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u64 = @as(u64, @bitCast(value)) ^ @as(u64, @bitCast(default_value));
                    std.mem.writeInt(u64, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u64)], stored, .little);
                },
                .uint8 => {
                    const value = parseUnsignedLiteral(u8, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u8, default_literal orelse "0") orelse return error.UnsupportedType;
                    segment.items[object_start_bytes + byte_offset] = value ^ default_value;
                },
                .uint16 => {
                    const value = parseUnsignedLiteral(u16, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u16, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u16 = value ^ default_value;
                    std.mem.writeInt(u16, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u16)], stored, .little);
                },
                .uint32 => {
                    const value = parseUnsignedLiteral(u32, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u32, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u32 = value ^ default_value;
                    std.mem.writeInt(u32, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u32)], stored, .little);
                },
                .uint64 => {
                    const value = parseUnsignedLiteral(u64, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u64, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u64 = value ^ default_value;
                    std.mem.writeInt(u64, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u64)], stored, .little);
                },
                .float32 => {
                    const value = parseFloatLiteral(f32, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseFloatLiteral(f32, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u32 = @as(u32, @bitCast(value)) ^ @as(u32, @bitCast(default_value));
                    std.mem.writeInt(u32, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u32)], stored, .little);
                },
                .float64 => {
                    const value = parseFloatLiteral(f64, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseFloatLiteral(f64, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u64 = @as(u64, @bitCast(value)) ^ @as(u64, @bitCast(default_value));
                    std.mem.writeInt(u64, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u64)], stored, .little);
                },
                .named => |field_type_name| {
                    const enum_decl = findEnum(file, field_type_name) orelse return error.UnsupportedType;
                    const value = resolvedEnumLiteralOrdinal(file, literal_scope, enum_decl, const_field.literal) orelse return error.UnsupportedType;
                    const default_value = if (field.default_literal) |literal|
                        try resolvedEnumDefaultOrdinal(file, layout.decl, enum_decl, literal)
                    else
                        0;
                    const stored: u16 = value ^ default_value;
                    std.mem.writeInt(u16, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u16)], stored, .little);
                },
                else => return error.UnsupportedType,
            },
            .pointer => |pointer_index| try appendStructPointerFieldLiteral(allocator, file, scope, layout, segment, pointer_index, object_start_words, field.ty, const_field.literal),
        }
    }
}

pub fn structLiteralObjectBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, layout: *const StructLayout, fields: []const ConstStructField, comptime include_root_pointer: bool) LayoutError!?[]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    const object_words = @as(usize, layout.data_words) + @as(usize, layout.pointer_count);
    const object_start_words: usize = if (include_root_pointer) 1 else 0;
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, object_start_words, object_words)));
    if (include_root_pointer) {
        writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeStruct(0, layout.data_words, layout.pointer_count));
    }
    writeStructLiteralFieldsIntoSegment(allocator, file, scope, layout, fields, &segment, object_start_words) catch |err| switch (err) {
        error.UnsupportedType => return null,
        else => return err,
    };
    return try segment.toOwnedSlice(allocator);
}

pub fn findFieldLayoutByName(layout: *const StructLayout, name: []const u8) ?FieldLayout {
    for (layout.fields) |field_layout| {
        if (std.mem.eql(u8, field_layout.field.name, name)) return field_layout;
    }
    return null;
}

pub fn findFieldLayoutByNameOrGroupFirst(layout: *const StructLayout, name: []const u8) ?FieldLayout {
    if (findFieldLayoutByName(layout, name)) |field_layout| return field_layout;
    for (layout.fields) |field_layout| {
        if (field_layout.field.name.len > name.len + 1 and
            std.mem.startsWith(u8, field_layout.field.name, name) and
            field_layout.field.name[name.len] == '_')
        {
            return field_layout;
        }
    }
    return null;
}

pub fn appendByteListPointer(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, bytes: []const u8, nul_terminated: bool, object_start_words: usize) LayoutError!void {
    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    return appendByteListPointerAtWord(allocator, segment, pointer_word_index, bytes, nul_terminated);
}

pub fn appendByteListPointerAtWord(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_word_index: usize, bytes: []const u8, nul_terminated: bool) LayoutError!void {
    const target_word_index = segment.items.len / @sizeOf(u64);
    const list_len = std.math.add(usize, bytes.len, @intFromBool(nul_terminated)) catch return error.SerializedSizeOverflow;
    const padded_len = try byteListPaddedLen(list_len);
    try segment.appendNTimes(allocator, 0, padded_len);
    const data_start = try wordByteOffset(target_word_index);
    @memcpy(segment.items[data_start..][0..bytes.len], bytes);
    if (nul_terminated) segment.items[data_start + bytes.len] = 0;
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    const raw = try wire.encodeList(offset, .byte, list_len);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], raw);
}

pub fn setBit(bytes: []u8, bit_offset: usize) void {
    bytes[bit_offset / 8] |= @as(u8, 1) << @as(u3, @intCast(bit_offset % 8));
}

pub fn flatByteLenForSegmentWords(segment_words: usize) LayoutError!usize {
    return flatByteLenForSegmentBytes(try wordByteLen(segment_words));
}

pub fn rootListSegmentWords(data_words: usize) LayoutError!usize {
    return std.math.add(usize, 1, data_words) catch return error.SerializedSizeOverflow;
}

pub fn flatByteLenForSegmentBytes(segment_bytes: usize) LayoutError!usize {
    return std.math.add(usize, @sizeOf(u64), segment_bytes) catch return error.SerializedSizeOverflow;
}

pub fn wordByteLen(word_count: usize) LayoutError!usize {
    return std.math.mul(usize, word_count, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
}

pub fn wordByteOffset(word_index: usize) LayoutError!usize {
    return wordByteLen(word_index);
}

pub fn structPointerWordIndex(object_start_words: usize, data_words: u16, pointer_index: usize) LayoutError!usize {
    const pointer_section_start = std.math.add(usize, object_start_words, data_words) catch return error.SerializedSizeOverflow;
    return std.math.add(usize, pointer_section_start, pointer_index) catch return error.SerializedSizeOverflow;
}

pub fn rootPointerListElementWordIndex(index: usize) LayoutError!usize {
    return std.math.add(usize, 1, index) catch return error.SerializedSizeOverflow;
}

pub fn pointerListElementWordIndex(list_start_words: usize, index: usize) LayoutError!usize {
    return std.math.add(usize, list_start_words, index) catch return error.SerializedSizeOverflow;
}

pub fn byteListPaddedLen(list_len: usize) LayoutError!usize {
    const padded_words = std.math.divCeil(usize, list_len, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
    return std.math.mul(usize, padded_words, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
}

pub fn simpleQuotedTextLiteralAlloc(allocator: std.mem.Allocator, literal: []const u8) LayoutError!?[]u8 {
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (raw.len < 2 or raw[0] != '"' or raw[raw.len - 1] != '"') return null;
    const inner = raw[1 .. raw.len - 1];
    if (std.mem.indexOfScalar(u8, inner, '\\') != null) return null;
    return try allocator.dupe(u8, inner);
}

pub fn simpleDataLiteralAlloc(allocator: std.mem.Allocator, literal: []const u8) LayoutError!?[]u8 {
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (std.mem.startsWith(u8, raw, "0x\"") and raw.len >= 4 and raw[raw.len - 1] == '"') {
        return try hexBytesAlloc(allocator, raw[3 .. raw.len - 1]);
    }
    return simpleQuotedTextLiteralAlloc(allocator, raw);
}

pub fn writeWordBytes(dest: []u8, value: u64) void {
    std.mem.writeInt(u64, dest[0..@sizeOf(u64)], value, .little);
}

pub fn emitEmbeddedStructConst(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    zig_type: []const u8,
    bytes: []const u8,
) LayoutError!void {
    const literal = try zigRawStringLiteralAlloc(allocator, bytes);
    defer allocator.free(literal);
    const ranges = try embeddedFlatSegmentRangesAlloc(allocator, bytes);
    defer allocator.free(ranges);

    try appendFmt(allocator, out,
        \\{s}pub const {s} = struct {{
        \\{s}    pub const flatBytes: []const u8 = {s};
        \\{s}    pub const segmentCount: usize = {};
        \\{s}    pub const serializedSize: usize = flatBytes.len;
        \\
    , .{ indent, name, indent, literal, indent, ranges.len, indent });

    for (ranges, 0..) |range, index| {
        try appendFmt(allocator, out,
            \\{s}    pub const segment{}: []const u8 = flatBytes[{}..{}];
            \\
        , .{ indent, index, range.start, range.end });
    }

    try appendFmt(allocator, out,
        \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{
    , .{indent});
    for (ranges, 0..) |_, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        try appendFmt(allocator, out, "segment{}", .{index});
    }
    try out.appendSlice(allocator, "};\n");

    try appendFmt(allocator, out,
        \\{s}
        \\{s}    pub const Reader = struct {{
        \\{s}        reader: cpz.MessageReader,
        \\
        \\{s}        pub fn init(@"cpz.options": cpz.ReaderOptions) @This() {{
        \\{s}            return .{{ .reader = cpz.MessageReader.init({s}.segments, @"cpz.options") }};
        \\{s}        }}
        \\
        \\{s}        pub fn asReader(self: *@This()) *cpz.MessageReader {{
        \\{s}            return &self.reader;
        \\{s}        }}
        \\
        \\{s}        pub fn root(self: *@This()) !{s} {{
        \\{s}            return {s}.getRoot(&self.reader);
        \\{s}        }}
        \\
        \\{s}        pub fn typedRoot(self: *@This()) !{s} {{
        \\{s}            return self.root();
        \\{s}        }}
        \\
    , .{
        indent,
        indent,
        indent,
        indent,
        indent,
        name,
        indent,
        indent,
        indent,
        indent,
        indent,
        zig_type,
        indent,
        zig_type,
        indent,
        indent,
        zig_type,
        indent,
        indent,
    });
    try appendFmt(allocator, out,
        \\{s}        pub fn validate(self: *@This()) !cpz.MessageStats {{
        \\{s}            return self.reader.validate();
        \\{s}        }}
        \\
        \\{s}        pub fn totalSize(self: *@This()) !cpz.MessageSize {{
        \\{s}            return self.reader.totalSize();
        \\{s}        }}
        \\{s}    }};
        \\
        \\{s}    pub fn init(@"cpz.options": cpz.ReaderOptions) Reader {{
        \\{s}        return Reader.init(@"cpz.options");
        \\{s}    }}
        \\
        \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
        \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
        \\{s}    }}
        \\
    , .{
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
    });
    try appendFmt(allocator, out,
        \\{s}    pub fn root(message_reader: *cpz.MessageReader) !{s} {{
        \\{s}        return {s}.getRoot(message_reader);
        \\{s}    }}
        \\
        \\{s}    pub fn typedRoot(message_reader: *cpz.MessageReader) !{s} {{
        \\{s}        return @This().root(message_reader);
        \\{s}    }}
        \\
        \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\{s}        var @"cpz.reader" = reader(@"cpz.options");
        \\{s}        return @"cpz.reader".validate();
        \\{s}    }}
        \\
        \\{s}    pub fn matchesSerializedSize(@"cpz.count": usize) bool {{
        \\{s}        return serializedSize == @"cpz.count";
        \\{s}    }}
        \\
        \\{s}    pub fn matchesSegmentCount(@"cpz.count": usize) bool {{
        \\{s}        return segmentCount == @"cpz.count";
        \\{s}    }}
        \\{s}}};
        \\
    , .{
        indent,
        zig_type,
        indent,
        zig_type,
        indent,
        indent,
        zig_type,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
    });
}

pub fn listUnsignedFlatBytesAlloc(comptime T: type, allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, element_size: wire.ElementSize) LayoutError![]u8 {
    const data_words = try wire.wordsForList(element_size, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, element_size, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseUnsignedLiteral(T, resolved_item.literal) orelse return error.InvalidToken;
        std.mem.writeInt(T, data[item.index * @sizeOf(T) ..][0..@sizeOf(T)], value, .little);
    }
    return flat;
}

pub fn listSignedFlatBytesAlloc(comptime T: type, comptime U: type, allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, element_size: wire.ElementSize) LayoutError![]u8 {
    const data_words = try wire.wordsForList(element_size, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, element_size, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseSignedLiteral(T, resolved_item.literal) orelse return error.InvalidToken;
        std.mem.writeInt(U, data[item.index * @sizeOf(U) ..][0..@sizeOf(U)], @bitCast(value), .little);
    }
    return flat;
}

pub fn listFloatFlatBytesAlloc(comptime T: type, comptime U: type, allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, element_size: wire.ElementSize) LayoutError![]u8 {
    const data_words = try wire.wordsForList(element_size, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, element_size, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseFloatLiteral(T, resolved_item.literal) orelse return error.InvalidToken;
        std.mem.writeInt(U, data[item.index * @sizeOf(U) ..][0..@sizeOf(U)], @bitCast(value), .little);
    }
    return flat;
}

pub fn listBoolFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem) LayoutError![]u8 {
    const data_words = try wire.wordsForList(.bit, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .bit, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseBoolLiteral(resolved_item.literal) orelse return error.InvalidToken;
        if (value) setBit(data, item.index);
    }
    return flat;
}

pub fn listCapabilityFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem) LayoutError![]u8 {
    const data_words = try wire.wordsForList(.pointer, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));
    for (items) |item| {
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const raw = std.mem.trim(u8, resolved_item.literal, " \t\r\n");
        if (item.index >= items.len or (!std.mem.eql(u8, raw, "void") and !std.mem.eql(u8, raw, "null"))) return error.InvalidToken;
    }
    return flat;
}

pub fn listVoidFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem) LayoutError![]u8 {
    const segment_words: usize = 1;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .void, items.len));
    for (items) |item| {
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        if (item.index >= items.len or !std.mem.eql(u8, resolved_item.literal, "void")) return error.InvalidToken;
    }
    return flat;
}

pub fn decodedStringBytesAlloc(allocator: std.mem.Allocator, raw: []const u8) LayoutError![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        i += 1;
        if (c == '\\' and i < raw.len) {
            const escaped = raw[i];
            i += 1;
            switch (escaped) {
                'a' => try out.append(allocator, 0x07),
                'b' => try out.append(allocator, 0x08),
                'f' => try out.append(allocator, 0x0c),
                'n' => try out.append(allocator, '\n'),
                'r' => try out.append(allocator, '\r'),
                't' => try out.append(allocator, '\t'),
                'v' => try out.append(allocator, 0x0b),
                '\'', '"', '\\', '?' => try out.append(allocator, escaped),
                'x' => {
                    if (i + 2 <= raw.len) {
                        if (std.fmt.parseInt(u8, raw[i .. i + 2], 16)) |value| {
                            i += 2;
                            try out.append(allocator, value);
                        } else |_| {
                            try out.append(allocator, escaped);
                        }
                    } else {
                        try out.append(allocator, escaped);
                    }
                },
                '0'...'7' => {
                    var value: u16 = escaped - '0';
                    var consumed: usize = 0;
                    while (consumed < 2 and i < raw.len) : (consumed += 1) {
                        const digit = octalValue(raw[i]) orelse break;
                        value = (value << 3) | digit;
                        i += 1;
                    }
                    try out.append(allocator, @truncate(value));
                },
                else => try out.append(allocator, escaped),
            }
        } else {
            try out.append(allocator, c);
        }
    }
    return out.toOwnedSlice(allocator);
}

pub fn listTextOrDataFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, comptime nul_terminated: bool) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item.literal, nul_terminated)) orelse (if (item.is_hex_data)
            try hexBytesAlloc(allocator, item.literal)
        else
            try decodedStringBytesAlloc(allocator, item.literal));
        defer allocator.free(bytes);
        try appendByteListPointer(allocator, &segment, 0, 0, bytes, nul_terminated, try rootPointerListElementWordIndex(item.index));
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

pub fn listEnumFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, enum_decl: *const EnumDecl, items: []const ConstListItem) LayoutError![]u8 {
    const data_words = try wire.wordsForList(.two_bytes, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .two_bytes, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const ordinal = try resolvedEnumDefaultOrdinal(file, scope, enum_decl, item.literal);
        std.mem.writeInt(u16, data[item.index * @sizeOf(u16) ..][0..@sizeOf(u16)], ordinal, .little);
    }
    return flat;
}

pub fn supportsScalarConstFlatContainer(file: *const File, scope: ?*const Struct, ty: Type) bool {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => true,
        .named => |type_name| findEnum(file, type_name) != null,
        else => false,
    };
}

pub fn resolveScalarConstLiteral(file: *const File, scope: ?*const Struct, literal: []const u8) []const u8 {
    return resolveScalarConstLiteralDepth(file, scope, literal, 0);
}

pub fn resolveScalarConstLiteralDepth(file: *const File, scope: ?*const Struct, literal: []const u8, depth: usize) []const u8 {
    if (depth >= 32) return literal;
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    const decl = findConstReference(file, scope, raw) orelse return literal;
    if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), raw)) return decl.literal;
    if (constDeclOwnerName(file, decl)) |owner_name| {
        return resolveScalarConstLiteralInOwnerDepth(file, scope, owner_name, decl.literal, depth + 1);
    }
    return resolveScalarConstLiteralDepth(file, scope, decl.literal, depth + 1);
}

pub fn resolveScalarConstLiteralInOwnerDepth(file: *const File, scope: ?*const Struct, owner_name: []const u8, literal: []const u8, depth: usize) []const u8 {
    if (depth >= 32) return literal;
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (lastTopLevelDot(raw) == null) {
        if (findConstInOwner(file, scope, owner_name, raw)) |decl| {
            if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), raw)) return decl.literal;
            return resolveScalarConstLiteralInOwnerDepth(file, scope, constDeclOwnerName(file, decl) orelse owner_name, decl.literal, depth + 1);
        }
    }
    return resolveScalarConstLiteralDepth(file, scope, literal, depth);
}

pub fn referencedBlobBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool) LayoutError!?[]u8 {
    return referencedBlobBytesAllocDepth(allocator, file, scope, literal, is_text, 0);
}

pub fn referencedBlobBytesAllocDepth(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool, depth: usize) LayoutError!?[]u8 {
    if (depth >= 32) return error.UnsupportedType;
    const decl = findConstReference(file, scope, literal) orelse return null;
    return referencedBlobBytesFromDeclAlloc(allocator, file, scope, decl, literal, constDeclOwnerName(file, decl), is_text, depth);
}

pub fn constBlobBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl, comptime is_text: bool) LayoutError![]u8 {
    if (decl.is_embed) return try allocator.dupe(u8, decl.embed_bytes orelse return error.UnsupportedType);
    if (try referencedBlobBytesAlloc(allocator, file, scope, decl.literal, is_text)) |bytes| return bytes;
    return if (!is_text and decl.is_hex_data)
        try hexBytesAlloc(allocator, decl.literal)
    else
        try decodedStringBytesAlloc(allocator, decl.literal);
}

pub fn constDeclResolutionScope(file: *const File, fallback_scope: ?*const Struct, decl: *const ConstDecl, empty_fields: []Field, storage: *Struct) ?*const Struct {
    const owner_name = constDeclOwnerName(file, decl) orelse return fallback_scope;
    if (findStructDirect(file, owner_name)) |owner| return owner;
    if (findInterfaceDirect(file, owner_name)) |owner| {
        storage.* = .{
            .name = owner.name,
            .fields = empty_fields,
            .consts = owner.consts,
            .aliases = owner.aliases,
        };
        return storage;
    }
    return fallback_scope;
}

pub fn referencedBlobBytesFromDeclAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    decl: *const ConstDecl,
    original_literal: []const u8,
    owner_name: ?[]const u8,
    comptime is_text: bool,
    depth: usize,
) LayoutError!?[]u8 {
    if (depth >= 32) return error.UnsupportedType;
    const resolved_ty = switch (resolveConstDeclType(file, scope, decl)) {
        .optional => |child| resolveConstDeclChildType(file, scope, decl, child.*),
        else => |resolved| resolved,
    };
    if (is_text) {
        if (resolved_ty != .text) return null;
        if (decl.is_embed) return try allocator.dupe(u8, decl.embed_bytes orelse return error.UnsupportedType);
        if (try referencedBlobBytesFromNestedConstAlloc(allocator, file, scope, decl, original_literal, owner_name, true, depth + 1)) |bytes| return bytes;
        return try decodedStringBytesAlloc(allocator, decl.literal);
    }
    if (resolved_ty != .data) return null;
    if (decl.is_embed) return try allocator.dupe(u8, decl.embed_bytes orelse return error.UnsupportedType);
    if (try referencedBlobBytesFromNestedConstAlloc(allocator, file, scope, decl, original_literal, owner_name, false, depth + 1)) |bytes| return bytes;
    return if (decl.is_hex_data)
        try hexBytesAlloc(allocator, decl.literal)
    else
        try decodedStringBytesAlloc(allocator, decl.literal);
}

pub fn referencedBlobBytesFromNestedConstAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    decl: *const ConstDecl,
    original_literal: []const u8,
    owner_name: ?[]const u8,
    comptime is_text: bool,
    depth: usize,
) LayoutError!?[]u8 {
    if (depth >= 32) return error.UnsupportedType;
    const raw_literal = std.mem.trim(u8, decl.literal, " \t\r\n");
    if (std.mem.eql(u8, raw_literal, std.mem.trim(u8, original_literal, " \t\r\n"))) return null;
    if (lastTopLevelDot(raw_literal) == null) {
        if (owner_name) |owner| {
            if (findConstInOwner(file, scope, owner, raw_literal)) |nested_decl| {
                if (nested_decl != decl) {
                    if (try referencedBlobBytesFromDeclAlloc(allocator, file, scope, nested_decl, decl.literal, constDeclOwnerName(file, nested_decl) orelse owner, is_text, depth + 1)) |bytes| return bytes;
                }
            }
        }
    }
    return try referencedBlobBytesAllocDepth(allocator, file, scope, decl.literal, is_text, depth + 1);
}

pub fn fieldBlobDefaultBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, field: *const Field, comptime is_text: bool) LayoutError!?[]u8 {
    const literal = field.default_literal orelse return null;
    if (try referencedBlobBytesAlloc(allocator, file, scope, literal, is_text)) |bytes| return bytes;
    if (is_text) return try decodedStringBytesAlloc(allocator, literal);
    return if (field.default_is_hex_data)
        try hexBytesAlloc(allocator, literal)
    else
        try decodedStringBytesAlloc(allocator, literal);
}

pub fn fieldBlobDefaultLiteralAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, field: *const Field, comptime is_text: bool) LayoutError!?[]u8 {
    const bytes = try fieldBlobDefaultBytesAlloc(allocator, file, scope, field, is_text) orelse return null;
    defer allocator.free(bytes);
    return try zigRawStringLiteralAlloc(allocator, bytes);
}

pub fn resolveScalarConstListItem(file: *const File, scope: ?*const Struct, item: ConstListItem) ConstListItem {
    var resolved = item;
    resolved.literal = resolveScalarConstLiteral(file, scope, item.literal);
    return resolved;
}

pub fn scalarConstFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type, literal: []const u8) LayoutError![]u8 {
    const resolved_literal = resolveScalarConstLiteral(file, scope, literal);
    const segment_words: usize = 2;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeStruct(0, 1, 0));
    const data = flat[2 * @sizeOf(u64) ..][0..@sizeOf(u64)];
    switch (resolveTypeScoped(file, scope, ty)) {
        .void => {},
        .bool => {
            const value = parseBoolLiteral(resolved_literal) orelse return error.InvalidToken;
            if (value) setBit(data, 0);
        },
        .int8 => {
            const value = parseSignedLiteral(i8, resolved_literal) orelse return error.InvalidToken;
            data[0] = @bitCast(value);
        },
        .int16 => {
            const value = parseSignedLiteral(i16, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u16, data[0..@sizeOf(u16)], @bitCast(value), .little);
        },
        .int32 => {
            const value = parseSignedLiteral(i32, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u32, data[0..@sizeOf(u32)], @bitCast(value), .little);
        },
        .int64 => {
            const value = parseSignedLiteral(i64, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u64, data[0..@sizeOf(u64)], @bitCast(value), .little);
        },
        .uint8 => data[0] = parseUnsignedLiteral(u8, resolved_literal) orelse return error.InvalidToken,
        .uint16 => {
            const value = parseUnsignedLiteral(u16, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u16, data[0..@sizeOf(u16)], value, .little);
        },
        .uint32 => {
            const value = parseUnsignedLiteral(u32, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u32, data[0..@sizeOf(u32)], value, .little);
        },
        .uint64 => {
            const value = parseUnsignedLiteral(u64, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u64, data[0..@sizeOf(u64)], value, .little);
        },
        .float32 => {
            const value = parseFloatLiteral(f32, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u32, data[0..@sizeOf(u32)], @bitCast(value), .little);
        },
        .float64 => {
            const value = parseFloatLiteral(f64, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u64, data[0..@sizeOf(u64)], @bitCast(value), .little);
        },
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const ordinal = resolvedEnumLiteralOrdinal(file, scope, enum_decl, literal) orelse return error.InvalidToken;
            std.mem.writeInt(u16, data[0..@sizeOf(u16)], ordinal, .little);
        },
        else => return error.UnsupportedType,
    }
    return flat;
}

pub fn listOptionalTextOrDataFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, comptime is_text: bool) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const bytes = try optionalBlobConstItemBytesAlloc(allocator, file, scope, item, is_text) orelse continue;
        defer allocator.free(bytes);
        try appendByteListPointer(allocator, &segment, 0, 0, bytes, is_text, try rootPointerListElementWordIndex(item.index));
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

pub fn listOptionalStructConstFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, items: []const ConstListItem) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    const list_start_words = try appendPointerListPointer(allocator, &segment, 0, 0, 0, items.len);
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item.literal), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;
        try appendStructListItemPointer(allocator, file, scope, &segment, item.index, list_start_words, type_name, item);
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

pub fn appendAnyPointerConstDeclListElementPointer(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    segment: *std.ArrayList(u8),
    element_index: usize,
    list_start_words: usize,
    decl: *const ConstDecl,
    comptime want: AnyPointerDefaultKind,
    depth: usize,
) LayoutError!void {
    if (depth >= 32) return error.UnsupportedType;
    var decl_scope_fields: [0]Field = .{};
    var decl_scope_storage: Struct = undefined;
    const decl_scope = constDeclResolutionScope(file, scope, decl, decl_scope_fields[0..], &decl_scope_storage);
    const resolved_ty = switch (resolveConstDeclType(file, scope, decl)) {
        .optional => |child| methodOptionalDefaultChildOrNullForDecl(file, scope, decl, child.*, decl.literal) orelse return error.UnsupportedType,
        else => |resolved| resolved,
    };
    switch (resolved_ty) {
        .named => |type_name| {
            if (want == .list) return error.UnsupportedType;
            if (findStructDirect(file, type_name) == null) return error.UnsupportedType;
            try appendStructLiteralPointer(allocator, file, decl_scope, segment, element_index, 0, list_start_words, type_name, decl.literal);
        },
        .list => |child| {
            if (want == .struct_ptr) return error.UnsupportedType;
            try appendScalarListPointer(allocator, file, decl_scope, segment, element_index, 0, list_start_words, child.*, decl.literal);
        },
        .any_pointer, .any_struct, .any_list => {
            const next_decl = findConstReference(file, decl_scope, decl.literal) orelse return error.UnsupportedType;
            if (next_decl == decl) return error.UnsupportedType;
            try appendAnyPointerConstDeclListElementPointer(allocator, file, decl_scope, segment, element_index, list_start_words, next_decl, want, depth + 1);
        },
        else => return error.UnsupportedType,
    }
}

pub fn appendAnyPointerConstListElementPointer(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    segment: *std.ArrayList(u8),
    element_index: usize,
    list_start_words: usize,
    literal: []const u8,
    comptime want: AnyPointerDefaultKind,
) LayoutError!void {
    const decl = findConstReference(file, scope, literal) orelse return error.UnsupportedType;
    try appendAnyPointerConstDeclListElementPointer(allocator, file, scope, segment, element_index, list_start_words, decl, want, 0);
}

pub fn listOptionalAnyPointerConstFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, comptime want: AnyPointerDefaultKind) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    const list_start_words = try appendPointerListPointer(allocator, &segment, 0, 0, 0, items.len);

    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item.literal), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;

        try appendAnyPointerConstListElementPointer(allocator, file, scope, &segment, item.index, list_start_words, item.literal, want);
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

pub fn appendOptionalStructListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, type_name: []const u8, literal: []const u8) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);

    const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
    for (items, 0..) |item, index| {
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;
        try appendStructListItemPointer(allocator, file, scope, segment, index, list_start_words, type_name, .{ .index = index, .literal = item });
    }
}

pub fn appendOptionalAnyPointerListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, literal: []const u8, comptime want: AnyPointerDefaultKind) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);

    const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
    for (items, 0..) |item, index| {
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;

        try appendAnyPointerConstListElementPointer(allocator, file, scope, segment, index, list_start_words, item, want);
    }
}
