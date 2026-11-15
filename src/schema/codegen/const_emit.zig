const std = @import("std");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const mod_field_defaults = @import("field_defaults.zig");
const mod_flat = @import("flat.zig");
const mod_interface = @import("interface.zig");
const mod_metadata = @import("metadata.zig");
const mod_state = @import("state.zig");
const mod_text = @import("text.zig");

const AliasDecl = frontend.AliasDecl;
const AliasMetadata = frontend.AliasMetadata;
const ConstDecl = frontend.ConstDecl;
const ConstListItem = frontend.ConstListItem;
const ConstMetadata = frontend.ConstMetadata;
const ConstStructField = frontend.ConstStructField;
const EnumDecl = frontend.EnumDecl;
const Error = frontend.Error;
const Field = frontend.Field;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const Type = frontend.Type;
const aliasReferenceHeadAlloc = frontend.aliasReferenceHeadAlloc;
const anonymousAliasName = frontend.anonymousAliasName;
const findConstReference = frontend.findConstReference;
const findEnum = frontend.findEnum;
const findInterface = frontend.findInterface;
const findInterfaceInOwnerScope = frontend.findInterfaceInOwnerScope;
const findStructDirect = frontend.findStructDirect;
const findStructInOwnerScope = frontend.findStructInOwnerScope;
const hexBytesAlloc = frontend.hexBytesAlloc;
const isAnnotationDirectInOwnerScope = frontend.isAnnotationDirectInOwnerScope;
const isEnumDirectInOwnerScope = frontend.isEnumDirectInOwnerScope;
const isStructLikeName = frontend.isStructLikeName;
const parameterNameInScope = frontend.parameterNameInScope;
const parseBoolLiteral = frontend.parseBoolLiteral;
const resolveConstReferenceLiteral = frontend.resolveConstReferenceLiteral;
const resolveNamedAlias = frontend.resolveNamedAlias;
const resolveTypeScoped = frontend.resolveTypeScoped;
const schemaTypeNameAlloc = frontend.schemaTypeNameAlloc;
const typeAcceptsVoidPointerDefault = frontend.typeAcceptsVoidPointerDefault;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const emitBlobFlatContainer = mod_field_defaults.emitBlobFlatContainer;
const emitListFieldDefaultFlatContainerFromBytes = mod_field_defaults.emitListFieldDefaultFlatContainerFromBytes;
const listStructFieldDefaultFlatBytesAlloc = mod_field_defaults.listStructFieldDefaultFlatBytesAlloc;
const structFieldDefaultFlatBytesAlloc = mod_field_defaults.structFieldDefaultFlatBytesAlloc;
const appendScalarListPointer = mod_flat.appendScalarListPointer;
const constBlobBytesAlloc = mod_flat.constBlobBytesAlloc;
const constDeclResolutionScope = mod_flat.constDeclResolutionScope;
const decodedStringBytesAlloc = mod_flat.decodedStringBytesAlloc;
const emitEmbeddedStructConst = mod_flat.emitEmbeddedStructConst;
const flatByteLenForSegmentBytes = mod_flat.flatByteLenForSegmentBytes;
const listBoolFlatBytesAlloc = mod_flat.listBoolFlatBytesAlloc;
const listCapabilityFlatBytesAlloc = mod_flat.listCapabilityFlatBytesAlloc;
const listEnumFlatBytesAlloc = mod_flat.listEnumFlatBytesAlloc;
const listFloatFlatBytesAlloc = mod_flat.listFloatFlatBytesAlloc;
const listOptionalAnyPointerConstFlatBytesAlloc = mod_flat.listOptionalAnyPointerConstFlatBytesAlloc;
const listOptionalStructConstFlatBytesAlloc = mod_flat.listOptionalStructConstFlatBytesAlloc;
const listOptionalTextOrDataFlatBytesAlloc = mod_flat.listOptionalTextOrDataFlatBytesAlloc;
const listSignedFlatBytesAlloc = mod_flat.listSignedFlatBytesAlloc;
const listStructItemsFlatBytesAlloc = mod_flat.listStructItemsFlatBytesAlloc;
const listTextOrDataFlatBytesAlloc = mod_flat.listTextOrDataFlatBytesAlloc;
const listUnsignedFlatBytesAlloc = mod_flat.listUnsignedFlatBytesAlloc;
const listVoidFlatBytesAlloc = mod_flat.listVoidFlatBytesAlloc;
const referencedBlobBytesAlloc = mod_flat.referencedBlobBytesAlloc;
const resolveScalarConstListItem = mod_flat.resolveScalarConstListItem;
const resolveScalarConstLiteral = mod_flat.resolveScalarConstLiteral;
const scalarConstFlatBytesAlloc = mod_flat.scalarConstFlatBytesAlloc;
const structListLiteralFlatBytesAlloc = mod_flat.structListLiteralFlatBytesAlloc;
const structLiteralFlatBytesAlloc = mod_flat.structLiteralFlatBytesAlloc;
const structLiteralTypeName = mod_flat.structLiteralTypeName;
const supportsScalarConstFlatContainer = mod_flat.supportsScalarConstFlatContainer;
const methodAnyPointerDefaultFlatBytesAlloc = mod_interface.methodAnyPointerDefaultFlatBytesAlloc;
const nullPointerFlatBytesAlloc = mod_interface.nullPointerFlatBytesAlloc;
const appendConstListItemsLiteral = mod_metadata.appendConstListItemsLiteral;
const appendConstStructFieldsLiteral = mod_metadata.appendConstStructFieldsLiteral;
const AnyPointerDefaultKind = mod_state.AnyPointerDefaultKind;
const appendFmt = mod_text.appendFmt;
const boolConstLiteral = mod_text.boolConstLiteral;
const floatConstLiteral = mod_text.floatConstLiteral;
const resolvedEnumDefaultOrdinal = mod_text.resolvedEnumDefaultOrdinal;
const schemaResolvedTypeNameAlloc = mod_text.schemaResolvedTypeNameAlloc;
const zigDataLiteralAlloc = mod_text.zigDataLiteralAlloc;
const zigRawStringLiteralAlloc = mod_text.zigRawStringLiteralAlloc;
const zigSchemaSyntaxLiteralAlloc = mod_text.zigSchemaSyntaxLiteralAlloc;
const zigStringLiteralAlloc = mod_text.zigStringLiteralAlloc;
const zigTypeRefAlloc = mod_text.zigTypeRefAlloc;

pub fn emitAlias(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const AliasDecl, indent: []const u8) LayoutError!void {
    const alias_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(alias_name);
    const name_literal = try zigStringLiteralAlloc(allocator, decl.name);
    defer allocator.free(name_literal);
    const target_name = try schemaTypeNameAlloc(allocator, decl.target);
    defer allocator.free(target_name);
    const target_literal = try zigStringLiteralAlloc(allocator, target_name);
    defer allocator.free(target_literal);
    const resolved_target_name = try schemaResolvedTypeNameAlloc(allocator, file, scope, decl.target);
    defer allocator.free(resolved_target_name);
    const resolved_target_literal = try zigStringLiteralAlloc(allocator, resolved_target_name);
    defer allocator.free(resolved_target_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.alias.{s}.index": usize = {};
        \\{s}pub const @"cpz.alias.{s}.name": []const u8 = {s};
        \\{s}pub const @"cpz.alias.{s}.metadata": cpz.schema.AliasMetadata = @This().@"cpz.aliases"[{}];
        \\{s}pub const @"cpz.alias.{s}.target": []const u8 = {s};
        \\{s}pub const @"cpz.alias.{s}.resolvedTarget": []const u8 = {s};
        \\
    , .{ indent, alias_name, index, indent, alias_name, name_literal, indent, alias_name, index, indent, alias_name, target_literal, indent, alias_name, resolved_target_literal });
    try emitAliasTarget(allocator, out, file, scope, indent, alias_name, decl.target);
}

pub fn aliasLine(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, alias_name: []const u8, value: []const u8) std.mem.Allocator.Error!void {
    return appendFmt(allocator, out, "{s}pub const {s} = {s};\n\n", .{ indent, alias_name, value });
}

pub fn nestedTypeNameInScopeAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8) LayoutError![]const u8 {
    const owner = scope orelse return allocator.dupe(u8, type_name);
    const head = try aliasReferenceHeadAlloc(allocator, type_name);
    defer allocator.free(head);
    if (findStructInOwnerScope(file, owner.name, head) == null and
        findInterfaceInOwnerScope(file, owner.name, head) == null and
        !isEnumDirectInOwnerScope(file, owner.name, head) and
        !isAnnotationDirectInOwnerScope(file, owner.name, head))
    {
        return allocator.dupe(u8, type_name);
    }
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ owner.name, type_name });
}

pub fn aliasValueTypeAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type) LayoutError![]u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void => allocator.dupe(u8, "void"),
        .bool => allocator.dupe(u8, "bool"),
        .int8 => allocator.dupe(u8, "i8"),
        .int16 => allocator.dupe(u8, "i16"),
        .int32 => allocator.dupe(u8, "i32"),
        .int64 => allocator.dupe(u8, "i64"),
        .uint8 => allocator.dupe(u8, "u8"),
        .uint16 => allocator.dupe(u8, "u16"),
        .uint32 => allocator.dupe(u8, "u32"),
        .uint64 => allocator.dupe(u8, "u64"),
        .float32 => allocator.dupe(u8, "f32"),
        .float64 => allocator.dupe(u8, "f64"),
        .text, .data => allocator.dupe(u8, "[]const u8"),
        .capability => allocator.dupe(u8, "u32"),
        .any_pointer => allocator.dupe(u8, "cpz.PointerReader"),
        .any_struct => allocator.dupe(u8, "cpz.StructReader"),
        .any_list => allocator.dupe(u8, "cpz.ListReader"),
        .named => |type_name| {
            if (parameterNameInScope(file, scope, type_name)) return allocator.dupe(u8, "cpz.PointerReader");
            if (findInterface(file, type_name) != null) return allocator.dupe(u8, "u32");
            const effective_name = try nestedTypeNameInScopeAlloc(allocator, file, scope, type_name);
            defer allocator.free(effective_name);
            return zigTypeRefAlloc(allocator, file, effective_name);
        },
        .list => |child| {
            const child_type = try aliasValueTypeAlloc(allocator, file, scope, child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "[]const {s}", .{child_type});
        },
        .optional => |child| {
            const child_type = try aliasValueTypeAlloc(allocator, file, scope, child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "?{s}", .{child_type});
        },
    };
}

pub fn emitAliasTarget(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, alias_name: []const u8, target: Type) LayoutError!void {
    switch (resolveTypeScoped(file, scope, target)) {
        .void => try aliasLine(allocator, out, indent, alias_name, "void"),
        .bool => try aliasLine(allocator, out, indent, alias_name, "bool"),
        .int8 => try aliasLine(allocator, out, indent, alias_name, "i8"),
        .int16 => try aliasLine(allocator, out, indent, alias_name, "i16"),
        .int32 => try aliasLine(allocator, out, indent, alias_name, "i32"),
        .int64 => try aliasLine(allocator, out, indent, alias_name, "i64"),
        .uint8 => try aliasLine(allocator, out, indent, alias_name, "u8"),
        .uint16 => try aliasLine(allocator, out, indent, alias_name, "u16"),
        .uint32 => try aliasLine(allocator, out, indent, alias_name, "u32"),
        .uint64 => try aliasLine(allocator, out, indent, alias_name, "u64"),
        .float32 => try aliasLine(allocator, out, indent, alias_name, "f32"),
        .float64 => try aliasLine(allocator, out, indent, alias_name, "f64"),
        .text, .data => try aliasLine(allocator, out, indent, alias_name, "[]const u8"),
        .any_pointer => try aliasLine(allocator, out, indent, alias_name, "cpz.PointerReader"),
        .any_struct => try aliasLine(allocator, out, indent, alias_name, "cpz.StructReader"),
        .any_list => try aliasLine(allocator, out, indent, alias_name, "cpz.ListReader"),
        .capability => try aliasLine(allocator, out, indent, alias_name, "u32"),
        .named => |type_name| {
            if (parameterNameInScope(file, scope, type_name)) {
                try aliasLine(allocator, out, indent, alias_name, "cpz.PointerReader");
                return;
            }
            if (findInterface(file, type_name) != null) {
                const local_name = anonymousAliasName(.{ .named = type_name }) orelse type_name;
                const local_ident = try zigIdentAlloc(allocator, local_name);
                defer allocator.free(local_ident);
                if (!std.mem.eql(u8, alias_name, local_ident)) {
                    try aliasLine(allocator, out, indent, alias_name, "u32");
                    return;
                }
            }
            const effective_name = try nestedTypeNameInScopeAlloc(allocator, file, scope, type_name);
            defer allocator.free(effective_name);
            const zig_type = try zigTypeRefAlloc(allocator, file, effective_name);
            defer allocator.free(zig_type);
            try aliasLine(allocator, out, indent, alias_name, zig_type);
        },
        .list => |child| {
            const child_type = try aliasValueTypeAlloc(allocator, file, scope, child.*);
            defer allocator.free(child_type);
            const list_type = try std.fmt.allocPrint(allocator, "[]const {s}", .{child_type});
            defer allocator.free(list_type);
            try aliasLine(allocator, out, indent, alias_name, list_type);
        },
        .optional => |child| {
            // Preserve the nullable marker for direct aliases such as
            // `using MaybeName = ?Text`; recursing into the child would emit
            // the non-optional value type and silently change the public API.
            const child_type = try aliasValueTypeAlloc(allocator, file, scope, child.*);
            defer allocator.free(child_type);
            const optional_type = try std.fmt.allocPrint(allocator, "?{s}", .{child_type});
            defer allocator.free(optional_type);
            try aliasLine(allocator, out, indent, alias_name, optional_type);
        },
    }
}

pub fn emitConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, index: usize, decl: *const ConstDecl) LayoutError!void {
    return emitConstWithIndent(allocator, out, file, null, index, decl, "");
}

pub fn emitNestedConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const ConstDecl) LayoutError!void {
    return emitConstWithIndent(allocator, out, file, scope, index, decl, "    ");
}

pub fn constNullPointerValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, const_name: []const u8, zig_type: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = null;
        \\
        \\
    , .{ indent, const_name, zig_type });
    try emitNullPointerFlatContainer(allocator, out, indent, const_name);
}

pub fn constZigValueTypeAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type) LayoutError![]u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void => allocator.dupe(u8, "void"),
        .bool => allocator.dupe(u8, "bool"),
        .int8 => allocator.dupe(u8, "i8"),
        .int16 => allocator.dupe(u8, "i16"),
        .int32 => allocator.dupe(u8, "i32"),
        .int64 => allocator.dupe(u8, "i64"),
        .uint8 => allocator.dupe(u8, "u8"),
        .uint16 => allocator.dupe(u8, "u16"),
        .uint32 => allocator.dupe(u8, "u32"),
        .uint64 => allocator.dupe(u8, "u64"),
        .float32 => allocator.dupe(u8, "f32"),
        .float64 => allocator.dupe(u8, "f64"),
        .text, .data => allocator.dupe(u8, "[]const u8"),
        .list => |list_child| {
            const child_type = try constZigValueTypeAlloc(allocator, file, scope, list_child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "[]const {s}", .{child_type});
        },
        .named => |type_name| {
            if (findInterface(file, type_name) != null) return allocator.dupe(u8, "u32");
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            return allocator.dupe(u8, zig_type);
        },
        .any_pointer => allocator.dupe(u8, "cpz.PointerReader"),
        .any_struct => allocator.dupe(u8, "cpz.StructReader"),
        .any_list => allocator.dupe(u8, "cpz.ListReader"),
        .capability => allocator.dupe(u8, "u32"),
        .optional => |nested_child| {
            const child_type = try constZigValueTypeAlloc(allocator, file, scope, nested_child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "?{s}", .{child_type});
        },
    };
}

pub fn optionalConstZigTypeAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, child: Type) LayoutError![]u8 {
    const child_type = try constZigValueTypeAlloc(allocator, file, scope, child);
    defer allocator.free(child_type);
    return std.fmt.allocPrint(allocator, "?{s}", .{child_type});
}

pub fn emitOptionalConstValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, const_name: []const u8, child: Type, decl: *const ConstDecl) LayoutError!void {
    const raw = std.mem.trim(u8, decl.literal, " \t\r\n");
    const resolved_child = resolveTypeScoped(file, scope, child);
    const resolved_raw = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, raw), " \t\r\n");
    if (std.mem.eql(u8, resolved_raw, "null") or (std.mem.eql(u8, resolved_raw, "void") and typeAcceptsVoidPointerDefault(file, resolved_child))) {
        const zig_type = try optionalConstZigTypeAlloc(allocator, file, scope, child);
        defer allocator.free(zig_type);
        try constNullPointerValue(allocator, out, indent, const_name, zig_type);
        return;
    }

    switch (resolved_child) {
        .void => {
            try appendFmt(allocator, out,
                \\{s}pub const {s}: ?void = {{}};
                \\
                \\
            , .{ indent, const_name });
            try emitScalarConstFlatContainer(allocator, out, file, scope, indent, const_name, child, raw);
        },
        .bool => {
            const value = parseBoolLiteral(resolveScalarConstLiteral(file, scope, raw)) orelse return;
            try appendFmt(allocator, out,
                \\{s}pub const {s}: ?bool = {};
                \\
                \\
            , .{ indent, const_name, value });
            try emitScalarConstFlatContainer(allocator, out, file, scope, indent, const_name, child, raw);
        },
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => {
            const resolved = resolveScalarConstLiteral(file, scope, raw);
            const literal = if (std.mem.startsWith(u8, resolved, "+")) resolved[1..] else resolved;
            const zig_type = try optionalConstZigTypeAlloc(allocator, file, scope, child);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: {s} = {s};
                \\
                \\
            , .{ indent, const_name, zig_type, literal });
            try emitScalarConstFlatContainer(allocator, out, file, scope, indent, const_name, child, raw);
        },
        .text => {
            const referenced_bytes = if (decl.is_embed) null else try referencedBlobBytesAlloc(allocator, file, scope, decl.literal, true);
            defer if (referenced_bytes) |bytes| allocator.free(bytes);
            const bytes = if (decl.is_embed)
                decl.embed_bytes orelse return
            else
                referenced_bytes orelse try decodedStringBytesAlloc(allocator, decl.literal);
            defer if (!decl.is_embed and referenced_bytes == null) allocator.free(bytes);
            const literal = try zigRawStringLiteralAlloc(allocator, bytes);
            defer allocator.free(literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: ?[]const u8 = {s};
                \\
                \\
            , .{ indent, const_name, literal });
            try emitBlobFlatContainer(allocator, out, indent, const_name, bytes, true);
        },
        .data => {
            const referenced_bytes = if (decl.is_embed) null else try referencedBlobBytesAlloc(allocator, file, scope, decl.literal, false);
            defer if (referenced_bytes) |bytes| allocator.free(bytes);
            const bytes = if (decl.is_embed)
                decl.embed_bytes orelse return
            else
                referenced_bytes orelse if (decl.is_hex_data)
                    try hexBytesAlloc(allocator, decl.literal)
                else
                    try decodedStringBytesAlloc(allocator, decl.literal);
            defer if (!decl.is_embed and referenced_bytes == null) allocator.free(bytes);
            const literal = try zigRawStringLiteralAlloc(allocator, bytes);
            defer allocator.free(literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: ?[]const u8 = {s};
                \\
                \\
            , .{ indent, const_name, literal });
            try emitBlobFlatContainer(allocator, out, indent, const_name, bytes, false);
        },
        .any_pointer, .any_struct, .any_list => {
            const flat = switch (resolved_child) {
                .any_pointer => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, raw, .any),
                .any_struct => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, raw, .struct_ptr),
                .any_list => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, raw, .list),
                else => return error.UnsupportedType,
            } catch |err| switch (err) {
                error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
                else => return err,
            };
            defer allocator.free(flat);
            const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
            defer allocator.free(flat_literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s} = struct {{
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
            , .{ indent, const_name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent });
            switch (resolved_child) {
                .any_pointer => try appendFmt(allocator, out,
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader) !cpz.PointerReader {{
                    \\{s}        return @This().pointer(message_reader);
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent }),
                .any_struct => try appendFmt(allocator, out,
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader) !cpz.StructReader {{
                    \\{s}        return (try @This().pointer(message_reader)).getStruct(null);
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent }),
                .any_list => try appendFmt(allocator, out,
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
                    \\{s}        return (try @This().pointer(message_reader)).getList(@"cpz.expected");
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent }),
                else => return error.UnsupportedType,
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
        },
        .list => |list_child| {
            const referenced = if (decl.list_items == null) findConstReference(file, scope, raw) else null;
            var ref_scope_fields: [0]Field = .{};
            var ref_scope_storage: Struct = undefined;
            const item_scope = if (referenced) |ref_decl|
                constDeclResolutionScope(file, scope, ref_decl, ref_scope_fields[0..], &ref_scope_storage)
            else
                scope;
            if (referenced) |ref_decl| {
                switch (resolveTypeScoped(file, scope, list_child.*)) {
                    .named => |type_name| if (findEnum(file, type_name) == null and findInterface(file, type_name) == null and isStructLikeName(file, type_name)) {
                        const flat = try listStructFieldDefaultFlatBytesAlloc(allocator, file, item_scope, type_name, ref_decl.literal);
                        defer allocator.free(flat);
                        const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                        defer allocator.free(zig_type);
                        try emitStructListFlatContainerFromBytes(allocator, out, indent, const_name, zig_type, flat);
                        return;
                    },
                    else => {},
                }
            }
            const items = decl.list_items orelse if (referenced) |ref_decl| ref_decl.list_items orelse return else return;
            try emitListConst(allocator, out, file, item_scope, indent, const_name, list_child.*, items, true);
        },
        .named => |type_name| {
            if (decl.is_embed) {
                if (findEnum(file, type_name) != null or findInterface(file, type_name) != null or !isStructLikeName(file, type_name)) return;
                const bytes = decl.embed_bytes orelse return;
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try emitEmbeddedStructConst(allocator, out, indent, const_name, zig_type, bytes);
            } else if (decl.struct_fields) |fields| {
                try appendFmt(allocator, out,
                    \\{s}pub const {s} = struct {{
                    \\{s}    pub const fieldCount: usize = {};
                    \\{s}    pub const fields: []const cpz.schema.ConstStructField = @"cpz.const.{s}.structFields";
                    \\
                , .{ indent, const_name, indent, fields.len, indent, const_name });
                const flat = (try structFieldDefaultFlatBytesAlloc(allocator, file, scope, type_name, decl.literal)) orelse return;
                defer allocator.free(flat);
                const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
                defer allocator.free(flat_literal);
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}    pub const flatBytes: []const u8 = {s};
                    \\{s}    pub const segment0: []const u8 = flatBytes[8..];
                    \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
                    \\
                    \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
                    \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
                    \\{s}    }}
                    \\
                    \\{s}    pub fn root(message_reader: *cpz.MessageReader) !cpz.StructReader {{
                    \\{s}        return message_reader.getRoot();
                    \\{s}    }}
                    \\
                    \\{s}    pub fn typedRoot(message_reader: *cpz.MessageReader) !{s} {{
                    \\{s}        return {s}.fromReader(try @This().root(message_reader));
                    \\{s}    }}
                    \\
                , .{ indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, zig_type, indent, zig_type, indent });
                try emitFlatContainerSizeHelpers(allocator, out, indent);
                try appendFmt(allocator, out,
                    \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
                    \\{s}        var @"cpz.reader" = reader(@"cpz.options");
                    \\{s}        return @"cpz.reader".validate();
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent, indent });
                for (fields) |field| {
                    const field_name = try zigIdentAlloc(allocator, field.name);
                    defer allocator.free(field_name);
                    const field_literal = try zigStringLiteralAlloc(allocator, field.literal);
                    defer allocator.free(field_literal);
                    try appendFmt(allocator, out,
                        \\{s}    pub const {s}: []const u8 = {s};
                        \\
                    , .{ indent, field_name, field_literal });
                }
                try appendFmt(allocator, out,
                    \\{s}}};
                    \\
                , .{indent});
            } else if (findEnum(file, type_name)) |enum_decl| {
                const zig_type = try optionalConstZigTypeAlloc(allocator, file, scope, child);
                defer allocator.free(zig_type);
                const enum_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(enum_type);
                try appendFmt(allocator, out,
                    \\{s}pub const {s}: {s} = @as({s}, @enumFromInt({}));
                    \\
                    \\
                , .{ indent, const_name, zig_type, enum_type, try resolvedEnumDefaultOrdinal(file, scope, enum_decl, raw) });
                try emitScalarConstFlatContainer(allocator, out, file, scope, indent, const_name, child, raw);
            }
        },
        else => return,
    }
}

pub fn emitNullPointerFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_name: []const u8) LayoutError!void {
    const flat = try nullPointerFlatBytesAlloc(allocator);
    defer allocator.free(flat);
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
        \\{s}    pub fn isNull(message_reader: *cpz.MessageReader) !bool {{
        \\{s}        return (try @This().pointer(message_reader)).isNull();
        \\{s}    }}
        \\
        \\{s}    pub fn rawPointer(message_reader: *cpz.MessageReader) !cpz.Word {{
        \\{s}        return (try @This().pointer(message_reader)).raw();
        \\{s}    }}
        \\
        \\{s}    pub fn pointerKind(message_reader: *cpz.MessageReader) !?cpz.wire.PointerType {{
        \\{s}        return (try @This().pointer(message_reader)).pointerType();
        \\{s}    }}
        \\
    , .{ indent, container_name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
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

pub fn constListChildTypeOrNull(file: *const File, scope: ?*const Struct, ty: Type) ?Type {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .list => |list_child| list_child.*,
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .list => |list_child| list_child.*,
            else => null,
        },
        else => null,
    };
}

pub fn emitConstWithIndent(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const ConstDecl, indent: []const u8) LayoutError!void {
    const const_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(const_name);
    const name_literal = try zigStringLiteralAlloc(allocator, decl.name);
    defer allocator.free(name_literal);
    const const_type_name = try schemaTypeNameAlloc(allocator, decl.ty);
    defer allocator.free(const_type_name);
    const type_literal = try zigStringLiteralAlloc(allocator, const_type_name);
    defer allocator.free(type_literal);
    const resolved_const_type_name = try schemaResolvedTypeNameAlloc(allocator, file, scope, decl.ty);
    defer allocator.free(resolved_const_type_name);
    const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_const_type_name);
    defer allocator.free(resolved_type_literal);
    const literal_value = try zigStringLiteralAlloc(allocator, decl.literal);
    defer allocator.free(literal_value);
    const embed_path_literal = try zigStringLiteralAlloc(allocator, decl.embed_path);
    defer allocator.free(embed_path_literal);
    const effective_list_items = decl.list_items orelse blk: {
        _ = constListChildTypeOrNull(file, scope, decl.ty) orelse break :blk null;
        const referenced = findConstReference(file, scope, decl.literal) orelse break :blk null;
        break :blk referenced.list_items;
    };
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.const.{s}.index": usize = {};
        \\{s}pub const @"cpz.const.{s}.name": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.metadata": cpz.schema.ConstMetadata = @This().@"cpz.consts"[{}];
        \\{s}pub const @"cpz.const.{s}.type": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.resolvedType": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.literal": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.isHexData": bool = {};
    , .{ indent, const_name, index, indent, const_name, name_literal, indent, const_name, index, indent, const_name, type_literal, indent, const_name, resolved_type_literal, indent, const_name, literal_value, indent, const_name, decl.is_hex_data });
    if (decl.id) |id| {
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.const.{s}.id": ?u64 = 0x{x};
        , .{ indent, const_name, id });
    } else {
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.const.{s}.id": ?u64 = null;
        , .{ indent, const_name });
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.const.{s}.isEmbed": bool = {};
        \\{s}pub const @"cpz.const.{s}.embedPath": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.embedByteCount": usize = {};
        \\{s}pub const @"cpz.const.{s}.isStructLiteral": bool = {};
        \\{s}pub const @"cpz.const.{s}.emitted": bool = {};
        \\{s}pub const @"cpz.const.{s}.listItemCount": usize = {};
        \\{s}pub const @"cpz.const.{s}.listItems": []const cpz.schema.ConstListItem = 
    , .{ indent, const_name, decl.is_embed, indent, const_name, embed_path_literal, indent, const_name, if (decl.embed_bytes) |bytes| bytes.len else 0, indent, const_name, decl.is_struct_literal, indent, const_name, decl.emit_value, indent, const_name, if (effective_list_items) |items| items.len else 0, indent, const_name });
    if (effective_list_items) |items| {
        try appendConstListItemsLiteral(allocator, out, items);
    } else {
        try out.appendSlice(allocator, "&[_]cpz.schema.ConstListItem{}");
    }
    try out.appendSlice(allocator, ";\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.const.{s}.listItemByIndex"(@"cpz.index": usize) ?cpz.schema.ConstListItem {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.const.{s}.listItems".len) return null;
        \\{s}    return @This().@"cpz.const.{s}.listItems"[@"cpz.index"];
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.listItemByLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstListItem {{
        \\{s}    for (@This().@"cpz.const.{s}.listItems") |@"cpz.item"| if (std.mem.eql(u8, @"cpz.item".literal, @"cpz.literal")) return @"cpz.item";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.listItemByHexData"(@"cpz.isHex": bool) ?cpz.schema.ConstListItem {{
        \\{s}    for (@This().@"cpz.const.{s}.listItems") |@"cpz.item"| if (@"cpz.item".is_hex_data == @"cpz.isHex") return @"cpz.item";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.listItemByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.ConstListItem {{
        \\{s}    for (@This().@"cpz.const.{s}.listItems") |@"cpz.item"| if (std.mem.eql(u8, @"cpz.item".annotations, @"cpz.annotationFilter")) return @"cpz.item";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, const_name, indent, const_name, indent, const_name, indent, indent, const_name, indent, const_name, indent, indent, indent, const_name, indent, const_name, indent, indent, indent, const_name, indent, const_name, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.const.{s}.listItemByStructFieldCount"(@"cpz.count": usize) ?cpz.schema.ConstListItem {{
        \\{s}    for (@This().@"cpz.const.{s}.listItems") |@"cpz.item"| if (@"cpz.item".struct_field_count == @"cpz.count") return @"cpz.item";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.listItemByStructFieldName"(@"cpz.name": []const u8) ?cpz.schema.ConstListItem {{
        \\{s}    for (@This().@"cpz.const.{s}.listItems") |@"cpz.item"| if (@"cpz.item".structFieldByName(@"cpz.name") != null) return @"cpz.item";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.listItemByStructFieldLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstListItem {{
        \\{s}    for (@This().@"cpz.const.{s}.listItems") |@"cpz.item"| if (@"cpz.item".structFieldByLiteral(@"cpz.literal") != null) return @"cpz.item";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, const_name, indent, const_name, indent, indent, indent, const_name, indent, const_name, indent, indent, indent, const_name, indent, const_name, indent, indent });
    if (effective_list_items) |items| {
        if (!decl.emit_value) {
            try appendFmt(allocator, out,
                \\{s}pub const {s} = struct {{
                \\{s}    pub const itemCount: usize = {};
                \\{s}    pub const items: []const cpz.schema.ConstListItem = @"cpz.const.{s}.listItems";
                \\
            , .{ indent, const_name, indent, items.len, indent, const_name });
            if (try structListLiteralFlatBytesAlloc(allocator, file, scope, decl)) |flat_bytes| {
                defer allocator.free(flat_bytes);
                const flat_literal = try zigRawStringLiteralAlloc(allocator, flat_bytes);
                defer allocator.free(flat_literal);
                const child = constListChildTypeOrNull(file, scope, decl.ty) orelse return error.UnsupportedType;
                const item_type_name = switch (resolveTypeScoped(file, scope, child)) {
                    .named => |name| try zigTypeRefAlloc(allocator, file, name),
                    else => return error.UnsupportedType,
                };
                defer allocator.free(item_type_name);
                try appendFmt(allocator, out,
                    \\{s}    pub const flatBytes: []const u8 = {s};
                    \\{s}    pub const segment0: []const u8 = flatBytes[8..];
                    \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
                    \\
                    \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
                    \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
                    \\{s}    }}
                    \\
                    \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
                    \\{s}        return message_reader.getRootList(.composite);
                    \\{s}    }}
                    \\
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
                    \\{s}        return {s}.fromReader(try (try @This().list(message_reader)).getStructElement(@"cpz.index"));
                    \\{s}    }}
                    \\
                , .{ indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, item_type_name, indent, item_type_name, indent });
                try emitFlatContainerSizeHelpers(allocator, out, indent);
                try appendFmt(allocator, out,
                    \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
                    \\{s}        var @"cpz.reader" = reader(@"cpz.options");
                    \\{s}        return @"cpz.reader".validate();
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent, indent });
            }
            if (try nestedListLiteralFlatBytesAlloc(allocator, file, scope, decl)) |flat_bytes| {
                defer allocator.free(flat_bytes);
                const flat_literal = try zigRawStringLiteralAlloc(allocator, flat_bytes);
                defer allocator.free(flat_literal);
                try appendFmt(allocator, out,
                    \\{s}    pub const flatBytes: []const u8 = {s};
                    \\{s}    pub const segment0: []const u8 = flatBytes[8..];
                    \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
                    \\
                    \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
                    \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
                    \\{s}    }}
                    \\
                    \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
                    \\{s}        return message_reader.getRootList(.pointer);
                    \\{s}    }}
                    \\
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
                    \\{s}        return (try (try @This().list(message_reader)).getPointerElement(@"cpz.index")).getList(@"cpz.expected");
                    \\{s}    }}
                    \\
                , .{ indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
                try emitFlatContainerSizeHelpers(allocator, out, indent);
                try appendFmt(allocator, out,
                    \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
                    \\{s}        var @"cpz.reader" = reader(@"cpz.options");
                    \\{s}        return @"cpz.reader".validate();
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent, indent });
            }
            for (items) |item| {
                const item_literal = try zigStringLiteralAlloc(allocator, item.literal);
                defer allocator.free(item_literal);
                try appendFmt(allocator, out,
                    \\{s}    pub const item{}: []const u8 = {s};
                    \\
                , .{ indent, item.index, item_literal });
            }
            try appendFmt(allocator, out,
                \\{s}    pub fn itemByIndex(@"cpz.index": usize) ?cpz.schema.ConstListItem {{
                \\{s}        if (@"cpz.index" >= @This().items.len) return null;
                \\{s}        return @This().items[@"cpz.index"];
                \\{s}    }}
                \\
                \\{s}    pub fn itemByLiteral(@"cpz.literal": []const u8) ?cpz.schema.ConstListItem {{
                \\{s}        for (@This().items) |@"cpz.item"| if (std.mem.eql(u8, @"cpz.item".literal, @"cpz.literal")) return @"cpz.item";
                \\{s}        return null;
                \\{s}    }}
                \\
                \\{s}    pub fn itemByStructFieldName(@"cpz.name": []const u8) ?cpz.schema.ConstListItem {{
                \\{s}        for (@This().items) |@"cpz.item"| if (@"cpz.item".structFieldByName(@"cpz.name") != null) return @"cpz.item";
                \\{s}        return null;
                \\{s}    }}
                \\
                \\{s}    pub fn itemByStructFieldLiteral(@"cpz.literal": []const u8) ?cpz.schema.ConstListItem {{
                \\{s}        for (@This().items) |@"cpz.item"| if (@"cpz.item".structFieldByLiteral(@"cpz.literal") != null) return @"cpz.item";
                \\{s}        return null;
                \\{s}    }}
                \\{s}}};
                \\
            , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
        }
        for (items) |item| {
            const item_literal = try zigStringLiteralAlloc(allocator, item.literal);
            defer allocator.free(item_literal);
            const item_annotations = try zigSchemaSyntaxLiteralAlloc(allocator, item.annotations);
            defer allocator.free(item_annotations);
            try appendFmt(allocator, out,
                \\{s}pub const @"cpz.const.{s}.listItem.{}.index": usize = {};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.metadata": cpz.schema.ConstListItem = @This().@"cpz.const.{s}.listItems"[{}];
                \\{s}pub const @"cpz.const.{s}.listItem.{}.literal": []const u8 = {s};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.isHexData": bool = {};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.annotations": []const u8 = {s};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.structFieldCount": usize = {};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.structFields": []const cpz.schema.ConstStructField =
            , .{ indent, const_name, item.index, item.index, indent, const_name, item.index, const_name, item.index, indent, const_name, item.index, item_literal, indent, const_name, item.index, item.is_hex_data, indent, const_name, item.index, item_annotations, indent, const_name, item.index, item.struct_fields.len, indent, const_name, item.index });
            if (item.struct_fields.len != 0) {
                try appendConstStructFieldsLiteral(allocator, out, item.struct_fields);
            } else {
                try out.appendSlice(allocator, "&[_]cpz.schema.ConstStructField{}");
            }
            try out.appendSlice(allocator, ";\n");
            try appendFmt(allocator, out,
                \\{s}pub fn @"cpz.const.{s}.listItem.{}.structFieldByIndex"(@"cpz.index": usize) ?cpz.schema.ConstStructField {{
                \\{s}    if (@"cpz.index" >= @This().@"cpz.const.{s}.listItem.{}.structFields".len) return null;
                \\{s}    return @This().@"cpz.const.{s}.listItem.{}.structFields"[@"cpz.index"];
                \\{s}}}
                \\
                \\{s}pub fn @"cpz.const.{s}.listItem.{}.structFieldByName"(@"cpz.name": []const u8) ?cpz.schema.ConstStructField {{
                \\{s}    for (@This().@"cpz.const.{s}.listItem.{}.structFields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".name, @"cpz.name")) return @"cpz.field";
                \\{s}    return null;
                \\{s}}}
                \\
            , .{ indent, const_name, item.index, indent, const_name, item.index, indent, const_name, item.index, indent, indent, const_name, item.index, indent, const_name, item.index, indent, indent });
            try appendFmt(allocator, out,
                \\{s}pub fn @"cpz.const.{s}.listItem.{}.structFieldByLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstStructField {{
                \\{s}    for (@This().@"cpz.const.{s}.listItem.{}.structFields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".literal, @"cpz.literal")) return @"cpz.field";
                \\{s}    return null;
                \\{s}}}
                \\
            , .{ indent, const_name, item.index, indent, const_name, item.index, indent, indent });
            for (item.struct_fields) |field| {
                const field_name_literal = try zigStringLiteralAlloc(allocator, field.name);
                defer allocator.free(field_name_literal);
                const field_literal = try zigStringLiteralAlloc(allocator, field.literal);
                defer allocator.free(field_literal);
                try appendFmt(allocator, out,
                    \\{s}pub const @"cpz.const.{s}.listItem.{}.structField.{}.index": usize = {};
                    \\{s}pub const @"cpz.const.{s}.listItem.{}.structField.{}.metadata": cpz.schema.ConstStructField = @This().@"cpz.const.{s}.listItem.{}.structFields"[{}];
                    \\{s}pub const @"cpz.const.{s}.listItem.{}.structField.{}.name": []const u8 = {s};
                    \\{s}pub const @"cpz.const.{s}.listItem.{}.structField.{}.literal": []const u8 = {s};
                    \\
                , .{ indent, const_name, item.index, field.index, field.index, indent, const_name, item.index, field.index, const_name, item.index, field.index, indent, const_name, item.index, field.index, field_name_literal, indent, const_name, item.index, field.index, field_literal });
            }
        }
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.const.{s}.structFieldCount": usize = {};
        \\{s}pub const @"cpz.const.{s}.structFields": []const cpz.schema.ConstStructField =
    , .{ indent, const_name, if (decl.struct_fields) |fields| fields.len else 0, indent, const_name });
    if (decl.struct_fields) |fields| {
        try appendConstStructFieldsLiteral(allocator, out, fields);
    } else {
        try out.appendSlice(allocator, "&[_]cpz.schema.ConstStructField{}");
    }
    try out.appendSlice(allocator, ";\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.const.{s}.structFieldByIndex"(@"cpz.index": usize) ?cpz.schema.ConstStructField {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.const.{s}.structFields".len) return null;
        \\{s}    return @This().@"cpz.const.{s}.structFields"[@"cpz.index"];
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.structFieldByName"(@"cpz.name": []const u8) ?cpz.schema.ConstStructField {{
        \\{s}    for (@This().@"cpz.const.{s}.structFields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".name, @"cpz.name")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.const.{s}.structFieldByLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstStructField {{
        \\{s}    for (@This().@"cpz.const.{s}.structFields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".literal, @"cpz.literal")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, const_name, indent, const_name, indent, const_name, indent, indent, const_name, indent, const_name, indent, indent, indent, const_name, indent, const_name, indent, indent });
    if (decl.struct_fields) |fields| {
        for (fields) |field| {
            const field_name_literal = try zigStringLiteralAlloc(allocator, field.name);
            defer allocator.free(field_name_literal);
            const field_literal = try zigStringLiteralAlloc(allocator, field.literal);
            defer allocator.free(field_literal);
            try appendFmt(allocator, out,
                \\{s}pub const @"cpz.const.{s}.structField.{}.index": usize = {};
                \\{s}pub const @"cpz.const.{s}.structField.{}.metadata": cpz.schema.ConstStructField = @This().@"cpz.const.{s}.structFields"[{}];
                \\{s}pub const @"cpz.const.{s}.structField.{}.name": []const u8 = {s};
                \\{s}pub const @"cpz.const.{s}.structField.{}.literal": []const u8 = {s};
                \\
            , .{ indent, const_name, field.index, field.index, indent, const_name, field.index, const_name, field.index, indent, const_name, field.index, field_name_literal, indent, const_name, field.index, field_literal });
        }
        try appendFmt(allocator, out,
            \\{s}pub const {s} = struct {{
            \\{s}    pub const fieldCount: usize = {};
            \\{s}    pub const fields: []const cpz.schema.ConstStructField = @"cpz.const.{s}.structFields";
            \\
        , .{ indent, const_name, indent, fields.len, indent, const_name });
        if (try structLiteralFlatBytesAlloc(allocator, file, scope, decl)) |flat_bytes| {
            defer allocator.free(flat_bytes);
            const flat_literal = try zigRawStringLiteralAlloc(allocator, flat_bytes);
            defer allocator.free(flat_literal);
            const struct_name_from_const_type = try zigTypeRefAlloc(allocator, file, structLiteralTypeName(file, scope, decl.ty) orelse return error.UnsupportedType);
            defer allocator.free(struct_name_from_const_type);
            try appendFmt(allocator, out,
                \\{s}    pub const flatBytes: []const u8 = {s};
                \\{s}    pub const segment0: []const u8 = flatBytes[8..];
                \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
                \\
                \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
                \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
                \\{s}    }}
                \\
                \\{s}    pub fn root(message_reader: *cpz.MessageReader) !cpz.StructReader {{
                \\{s}        return message_reader.getRoot();
                \\{s}    }}
                \\
                \\{s}    pub fn typedRoot(message_reader: *cpz.MessageReader) !{s} {{
                \\{s}        return {s}.fromReader(try @This().root(message_reader));
                \\{s}    }}
                \\
            , .{ indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, struct_name_from_const_type, indent, struct_name_from_const_type, indent });
            try emitFlatContainerSizeHelpers(allocator, out, indent);
            try appendFmt(allocator, out,
                \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
                \\{s}        var @"cpz.reader" = reader(@"cpz.options");
                \\{s}        return @"cpz.reader".validate();
                \\{s}    }}
                \\
            , .{ indent, indent, indent, indent });
        }
        for (fields) |field| {
            const field_name = try zigIdentAlloc(allocator, field.name);
            defer allocator.free(field_name);
            const field_literal = try zigStringLiteralAlloc(allocator, field.literal);
            defer allocator.free(field_literal);
            try appendFmt(allocator, out,
                \\{s}    pub const {s}: []const u8 = {s};
                \\
            , .{ indent, field_name, field_literal });
        }
        try appendFmt(allocator, out,
            \\{s}    pub fn fieldByIndex(@"cpz.index": usize) ?cpz.schema.ConstStructField {{
            \\{s}        if (@"cpz.index" >= @This().fields.len) return null;
            \\{s}        return @This().fields[@"cpz.index"];
            \\{s}    }}
            \\
            \\{s}    pub fn fieldByName(@"cpz.name": []const u8) ?cpz.schema.ConstStructField {{
            \\{s}        for (@This().fields) |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".name, @"cpz.name")) return @"cpz.field";
            \\{s}        return null;
            \\{s}    }}
            \\
            \\{s}    pub fn fieldByLiteral(@"cpz.literal": []const u8) ?cpz.schema.ConstStructField {{
            \\{s}        for (@This().fields) |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".literal, @"cpz.literal")) return @"cpz.field";
            \\{s}        return null;
            \\{s}    }}
            \\{s}}};
            \\
        , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    }
    try out.appendSlice(allocator,
        \\
    );
    const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, decl.annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.const.{s}.annotations": []const u8 = {s};
        \\
    , .{ indent, const_name, annotation_literal });
    if (!decl.emit_value) return;
    if (supportsScalarConstFlatContainer(file, scope, decl.ty)) {
        try emitScalarConstFlatContainer(allocator, out, file, scope, indent, const_name, decl.ty, decl.literal);
    }
    switch (resolveTypeScoped(file, scope, decl.ty)) {
        .void => try appendFmt(allocator, out,
            \\{s}pub const {s}: void = {{}};
            \\
            \\
        , .{ indent, const_name }),
        .bool => try appendFmt(allocator, out,
            \\{s}pub const {s}: bool = {s};
            \\
            \\
        , .{ indent, const_name, try boolConstLiteral(resolveScalarConstLiteral(file, scope, decl.literal)) }),
        .int8 => try emitNumericConst(allocator, out, indent, const_name, "i8", resolveScalarConstLiteral(file, scope, decl.literal)),
        .int16 => try emitNumericConst(allocator, out, indent, const_name, "i16", resolveScalarConstLiteral(file, scope, decl.literal)),
        .int32 => try emitNumericConst(allocator, out, indent, const_name, "i32", resolveScalarConstLiteral(file, scope, decl.literal)),
        .int64 => try emitNumericConst(allocator, out, indent, const_name, "i64", resolveScalarConstLiteral(file, scope, decl.literal)),
        .uint8 => try emitNumericConst(allocator, out, indent, const_name, "u8", resolveScalarConstLiteral(file, scope, decl.literal)),
        .uint16 => try emitNumericConst(allocator, out, indent, const_name, "u16", resolveScalarConstLiteral(file, scope, decl.literal)),
        .uint32 => try emitNumericConst(allocator, out, indent, const_name, "u32", resolveScalarConstLiteral(file, scope, decl.literal)),
        .uint64 => try emitNumericConst(allocator, out, indent, const_name, "u64", resolveScalarConstLiteral(file, scope, decl.literal)),
        .float32 => try emitNumericConst(allocator, out, indent, const_name, "f32", floatConstLiteral(resolveScalarConstLiteral(file, scope, decl.literal), "f32")),
        .float64 => try emitNumericConst(allocator, out, indent, const_name, "f64", floatConstLiteral(resolveScalarConstLiteral(file, scope, decl.literal), "f64")),
        .capability => {
            const raw = std.mem.trim(u8, resolveScalarConstLiteral(file, scope, decl.literal), " \t\r\n");
            if (!std.mem.eql(u8, raw, "void") and !std.mem.eql(u8, raw, "null")) return;
            try constNullPointerValue(allocator, out, indent, const_name, "?u32");
        },
        .any_pointer, .any_struct, .any_list => try emitOptionalConstValue(allocator, out, file, scope, indent, const_name, decl.ty, decl),
        .text => {
            if (std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, decl.literal), " \t\r\n"), "null")) {
                try constNullPointerValue(allocator, out, indent, const_name, "?[]const u8");
                return;
            }
            const bytes = try constBlobBytesAlloc(allocator, file, scope, decl, true);
            defer allocator.free(bytes);
            const literal = try zigRawStringLiteralAlloc(allocator, bytes);
            defer allocator.free(literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: []const u8 = {s};
                \\
                \\
            , .{ indent, const_name, literal });
            try emitBlobFlatContainer(allocator, out, indent, const_name, bytes, true);
        },
        .data => {
            if (std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, decl.literal), " \t\r\n"), "null")) {
                try constNullPointerValue(allocator, out, indent, const_name, "?[]const u8");
                return;
            }
            const bytes = try constBlobBytesAlloc(allocator, file, scope, decl, false);
            defer allocator.free(bytes);
            const literal = try zigRawStringLiteralAlloc(allocator, bytes);
            defer allocator.free(literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: []const u8 = {s};
                \\
                \\
            , .{ indent, const_name, literal });
            try emitBlobFlatContainer(allocator, out, indent, const_name, bytes, false);
        },
        .named => |type_name| {
            if (decl.is_embed) {
                if (findEnum(file, type_name) != null or findInterface(file, type_name) != null or !isStructLikeName(file, type_name)) return;
                const bytes = decl.embed_bytes orelse return;
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try emitEmbeddedStructConst(allocator, out, indent, const_name, zig_type, bytes);
            } else if (decl.list_items) |items| {
                const resolved = resolveNamedAlias(file, scope, type_name, 0) orelse return;
                if (resolved != .list) return;
                try emitListConst(allocator, out, file, scope, indent, const_name, resolved.list.*, items, false);
            } else {
                if (findInterface(file, type_name) != null) {
                    const raw = std.mem.trim(u8, resolveScalarConstLiteral(file, scope, decl.literal), " \t\r\n");
                    if (!std.mem.eql(u8, raw, "void") and !std.mem.eql(u8, raw, "null")) return;
                    try constNullPointerValue(allocator, out, indent, const_name, "?u32");
                    return;
                }
                if (isStructLikeName(file, type_name) and std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, decl.literal), " \t\r\n"), "null")) {
                    const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                    defer allocator.free(zig_type);
                    const optional_type = try std.fmt.allocPrint(allocator, "?{s}", .{zig_type});
                    defer allocator.free(optional_type);
                    try constNullPointerValue(allocator, out, indent, const_name, optional_type);
                    return;
                }
                if (isStructLikeName(file, type_name)) {
                    const literal = resolveConstReferenceLiteral(file, scope, decl.literal);
                    const flat = (try structFieldDefaultFlatBytesAlloc(allocator, file, scope, type_name, literal)) orelse return;
                    defer allocator.free(flat);
                    const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                    defer allocator.free(zig_type);
                    try emitEmbeddedStructConst(allocator, out, indent, const_name, zig_type, flat);
                    return;
                }
                const enum_decl = findEnum(file, type_name) orelse return;
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}pub const {s}: {s} = @enumFromInt({});
                    \\
                    \\
                , .{ indent, const_name, zig_type, try resolvedEnumDefaultOrdinal(file, scope, enum_decl, decl.literal) });
            }
        },
        .list => |child| {
            if (decl.list_items == null and std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, decl.literal), " \t\r\n"), "null")) {
                const list_type = try constZigValueTypeAlloc(allocator, file, scope, decl.ty);
                defer allocator.free(list_type);
                const optional_list_type = try std.fmt.allocPrint(allocator, "?{s}", .{list_type});
                defer allocator.free(optional_list_type);
                try constNullPointerValue(allocator, out, indent, const_name, optional_list_type);
                return;
            }
            const referenced = if (decl.list_items == null) findConstReference(file, scope, decl.literal) else null;
            var ref_scope_fields: [0]Field = .{};
            var ref_scope_storage: Struct = undefined;
            const item_scope = if (referenced) |ref_decl|
                constDeclResolutionScope(file, scope, ref_decl, ref_scope_fields[0..], &ref_scope_storage)
            else
                scope;
            const items = decl.list_items orelse if (referenced) |ref_decl|
                ref_decl.list_items orelse return
            else
                return;
            if (referenced) |ref_decl| {
                switch (resolveTypeScoped(file, scope, child.*)) {
                    .list => {
                        if (try nestedListLiteralFlatBytesAlloc(allocator, file, item_scope, ref_decl)) |flat| {
                            defer allocator.free(flat);
                            try emitNestedListConstFlatContainerFromBytes(allocator, out, indent, const_name, flat);
                            return;
                        }
                    },
                    .named => |type_name| if (findEnum(file, type_name) == null and findInterface(file, type_name) == null and isStructLikeName(file, type_name)) {
                        const flat = try listStructFieldDefaultFlatBytesAlloc(allocator, file, item_scope, type_name, ref_decl.literal);
                        defer allocator.free(flat);
                        const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                        defer allocator.free(zig_type);
                        try emitStructListFlatContainerFromBytes(allocator, out, indent, const_name, zig_type, flat);
                        return;
                    },
                    else => {},
                }
            }
            try emitListConst(allocator, out, file, item_scope, indent, const_name, child.*, items, false);
        },
        .optional => |child| try emitOptionalConstValue(allocator, out, file, scope, indent, const_name, child.*, decl),
    }
}

pub fn nestedListLiteralFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl) LayoutError!?[]u8 {
    _ = decl.list_items orelse return null;
    const child = switch (resolveTypeScoped(file, scope, decl.ty)) {
        .list => |list_child| list_child.*,
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .list => |list_child| list_child.*,
            else => return null,
        },
        else => return null,
    };
    if (resolveTypeScoped(file, scope, child) != .list) return null;
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    appendScalarListPointer(allocator, file, scope, &segment, 0, 0, 0, child, decl.literal) catch |err| switch (err) {
        error.UnsupportedType => return null,
        else => return err,
    };
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn emitFlatContainerSizeHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}    pub const serializedSize: usize = flatBytes.len;
        \\{s}    pub const segmentCount: usize = 1;
        \\
        \\{s}    pub fn matchesSerializedSize(@"cpz.count": usize) bool {{
        \\{s}        return serializedSize == @"cpz.count";
        \\{s}    }}
        \\
        \\{s}    pub fn matchesSegmentCount(@"cpz.count": usize) bool {{
        \\{s}        return segmentCount == @"cpz.count";
        \\{s}    }}
        \\
        \\{s}    pub fn totalSize(@"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\{s}        return (try @This().validate(@"cpz.options")).size();
        \\{s}    }}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
}

pub fn emitFlatListContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, flat: []const u8, element_size_literal: []const u8, get_type: ?[]const u8, get_method: ?[]const u8) LayoutError!void {
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
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList({s});
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, element_size_literal, indent });
    if (get_type) |ty| {
        if (get_method) |method| {
            try appendFmt(allocator, out,
                \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
                \\{s}        const @"cpz.list" = try @This().list(message_reader);
                \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
                \\{s}        return @"cpz.list".{s}(@"cpz.index");
                \\{s}    }}
                \\
            , .{ indent, ty, indent, indent, indent, method, indent });
        } else {
            try appendFmt(allocator, out,
                \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !void {{
                \\{s}        const @"cpz.list" = try @This().list(message_reader);
                \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
                \\{s}        return {{}};
                \\{s}    }}
                \\
            , .{ indent, indent, indent, indent, indent });
        }
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

pub fn emitCapabilityListFlatContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, flat: []const u8) LayoutError!void {
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
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList(.pointer);
        \\{s}    }}
        \\
        \\{s}    pub fn pointer(message_reader: *cpz.MessageReader, @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}        const @"cpz.list" = try @This().list(message_reader);
        \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
        \\{s}        return @"cpz.list".getPointerElement(@"cpz.index");
        \\{s}    }}
        \\
        \\{s}    pub fn elementIsNull(message_reader: *cpz.MessageReader, @"cpz.index": usize) !bool {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).isNull();
        \\{s}    }}
        \\
        \\{s}    pub fn elementPointerKind(message_reader: *cpz.MessageReader, @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).pointerType();
        \\{s}    }}
        \\
        \\{s}    pub fn rawPointer(message_reader: *cpz.MessageReader, @"cpz.index": usize) !cpz.Word {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).raw();
        \\{s}    }}
        \\
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !u32 {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).getCapabilityIndex();
        \\{s}    }}
        \\
    , .{
        indent, name,   indent, flat_literal, indent, indent,
        indent, indent, indent, indent,       indent, indent,
        indent, indent, indent, indent,       indent, indent,
        indent, indent, indent, indent,       indent, indent,
        indent, indent, indent, indent,       indent,
    });
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

pub fn emitScalarConstFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, ty: Type, literal: []const u8) LayoutError!void {
    const flat = try scalarConstFlatBytesAlloc(allocator, file, scope, ty, literal);
    defer allocator.free(flat);
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
        \\{s}    pub fn root(message_reader: *cpz.MessageReader) !cpz.StructReader {{
        \\{s}        return message_reader.getRoot();
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent });
    switch (resolveTypeScoped(file, scope, ty)) {
        .void => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !void {{
            \\{s}        _ = try @This().root(message_reader);
            \\{s}        return {{}};
            \\{s}    }}
            \\
        , .{ indent, indent, indent, indent }),
        .bool => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !bool {{
            \\{s}        return (try @This().root(message_reader)).getBool(0, false);
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .int8 => try emitScalarConstFlatGet(allocator, out, indent, "i8", "getInt8", "0"),
        .int16 => try emitScalarConstFlatGet(allocator, out, indent, "i16", "getInt16", "0"),
        .int32 => try emitScalarConstFlatGet(allocator, out, indent, "i32", "getInt32", "0"),
        .int64 => try emitScalarConstFlatGet(allocator, out, indent, "i64", "getInt64", "0"),
        .uint8 => try emitScalarConstFlatGet(allocator, out, indent, "u8", "getUInt8", "0"),
        .uint16 => try emitScalarConstFlatGet(allocator, out, indent, "u16", "getUInt16", "0"),
        .uint32 => try emitScalarConstFlatGet(allocator, out, indent, "u32", "getUInt32", "0"),
        .uint64 => try emitScalarConstFlatGet(allocator, out, indent, "u64", "getUInt64", "0"),
        .float32 => try emitScalarConstFlatGet(allocator, out, indent, "f32", "getFloat32", "0"),
        .float64 => try emitScalarConstFlatGet(allocator, out, indent, "f64", "getFloat64", "0"),
        .named => |type_name| {
            if (findEnum(file, type_name) == null) return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\{s}    pub fn getRaw(message_reader: *cpz.MessageReader) !u16 {{
                \\{s}        return (try @This().root(message_reader)).getUInt16(0, 0);
                \\{s}    }}
                \\
                \\{s}    pub fn get(message_reader: *cpz.MessageReader) !{s} {{
                \\{s}        return std.enums.fromInt({s}, try getRaw(message_reader)) orelse error.InvalidEnumValue;
                \\{s}    }}
                \\
            , .{ indent, indent, indent, indent, zig_type, indent, zig_type, indent });
        },
        else => return error.UnsupportedType,
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

pub fn emitScalarConstFlatGet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, zig_type: []const u8, get_method: []const u8, default_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}    pub fn get(message_reader: *cpz.MessageReader) !{s} {{
        \\{s}        return (try @This().root(message_reader)).{s}(0, {s});
        \\{s}    }}
        \\
    , .{ indent, zig_type, indent, get_method, default_literal, indent });
}

pub fn emitUnsignedListFlatContainer(comptime T: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, element_size: wire.ElementSize, element_size_literal: []const u8, get_method: []const u8) LayoutError!void {
    const flat = try listUnsignedFlatBytesAlloc(T, allocator, file, scope, items, element_size);
    defer allocator.free(flat);
    try emitFlatListContainerFromBytes(allocator, out, indent, name, flat, element_size_literal, @typeName(T), get_method);
}

pub fn emitSignedListFlatContainer(comptime T: type, comptime U: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, element_size: wire.ElementSize, element_size_literal: []const u8, get_method: []const u8) LayoutError!void {
    const flat = try listSignedFlatBytesAlloc(T, U, allocator, file, scope, items, element_size);
    defer allocator.free(flat);
    try emitFlatListContainerFromBytes(allocator, out, indent, name, flat, element_size_literal, @typeName(T), get_method);
}

pub fn emitFloatListFlatContainer(comptime T: type, comptime U: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, element_size: wire.ElementSize, element_size_literal: []const u8, get_method: []const u8) LayoutError!void {
    const flat = try listFloatFlatBytesAlloc(T, U, allocator, file, scope, items, element_size);
    defer allocator.free(flat);
    try emitFlatListContainerFromBytes(allocator, out, indent, name, flat, element_size_literal, @typeName(T), get_method);
}

pub fn emitBoolListFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem) LayoutError!void {
    const flat = try listBoolFlatBytesAlloc(allocator, file, scope, items);
    defer allocator.free(flat);
    try emitFlatListContainerFromBytes(allocator, out, indent, name, flat, ".bit", "bool", "getBool");
}

pub fn emitVoidListFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem) LayoutError!void {
    const flat = try listVoidFlatBytesAlloc(allocator, file, scope, items);
    defer allocator.free(flat);
    try emitFlatListContainerFromBytes(allocator, out, indent, name, flat, ".void", "void", null);
}

pub fn emitTextOrDataListFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, comptime is_text: bool) LayoutError!void {
    const flat = try listTextOrDataFlatBytesAlloc(allocator, file, scope, items, is_text);
    defer allocator.free(flat);
    try emitTextOrDataListFlatContainerFromBytes(allocator, out, indent, name, flat, is_text);
}

pub fn emitTextOrDataListFlatContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, flat: []const u8, comptime is_text: bool) LayoutError!void {
    const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
    defer allocator.free(flat_literal);
    const accessor = if (is_text) "getText" else "getData";
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
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList(.pointer);
        \\{s}    }}
        \\
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) ![]const u8 {{
        \\{s}        return (try (try @This().list(message_reader)).getPointerElement(@"cpz.index")).{s}();
        \\{s}    }}
        \\
        \\{s}    pub fn getByteCount(message_reader: *cpz.MessageReader, @"cpz.index": usize) !usize {{
        \\{s}        return (try @This().get(message_reader, @"cpz.index")).len;
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, accessor, indent, indent, indent, indent });
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

pub fn emitStructListFlatContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, item_type_name: []const u8, flat: []const u8) LayoutError!void {
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
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList(.composite);
        \\{s}    }}
        \\
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
        \\{s}        return {s}.fromReader(try (try @This().list(message_reader)).getStructElement(@"cpz.index"));
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, item_type_name, indent, item_type_name, indent });
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

pub fn emitNestedListConstFlatContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, flat: []const u8) LayoutError!void {
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
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList(.pointer);
        \\{s}    }}
        \\
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\{s}        return (try (try @This().list(message_reader)).getPointerElement(@"cpz.index")).getList(@"cpz.expected");
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
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

pub fn emitEnumListFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, zig_type: []const u8, enum_decl: *const EnumDecl, items: []const ConstListItem) LayoutError!void {
    const flat = try listEnumFlatBytesAlloc(allocator, file, scope, enum_decl, items);
    defer allocator.free(flat);
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
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList(.two_bytes);
        \\{s}    }}
        \\
        \\{s}    pub fn getRaw(message_reader: *cpz.MessageReader, @"cpz.index": usize) !u16 {{
        \\{s}        const @"cpz.list" = try @This().list(message_reader);
        \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
        \\{s}        return @"cpz.list".getUInt16(@"cpz.index");
        \\{s}    }}
        \\
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
        \\{s}        return std.enums.fromInt({s}, try getRaw(message_reader, @"cpz.index")) orelse error.InvalidEnumValue;
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, zig_type, indent, zig_type, indent });
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

pub fn emitNumericConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, zig_type: []const u8, literal: []const u8) std.mem.Allocator.Error!void {
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = {s};
        \\
        \\
    , .{ indent, name, zig_type, if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal });
}

pub fn emitListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, child: Type, items: []const ConstListItem, comptime optional_value: bool) LayoutError!void {
    switch (resolveTypeScoped(file, scope, child)) {
        .void => try emitListConstOfType(allocator, out, file, scope, indent, name, "void", items, voidConstItem, optional_value),
        .bool => try emitListConstOfType(allocator, out, file, scope, indent, name, "bool", items, boolConstItem, optional_value),
        .int8 => try emitListConstOfType(allocator, out, file, scope, indent, name, "i8", items, numericConstItem, optional_value),
        .int16 => try emitListConstOfType(allocator, out, file, scope, indent, name, "i16", items, numericConstItem, optional_value),
        .int32 => try emitListConstOfType(allocator, out, file, scope, indent, name, "i32", items, numericConstItem, optional_value),
        .int64 => try emitListConstOfType(allocator, out, file, scope, indent, name, "i64", items, numericConstItem, optional_value),
        .uint8 => try emitListConstOfType(allocator, out, file, scope, indent, name, "u8", items, numericConstItem, optional_value),
        .uint16 => try emitListConstOfType(allocator, out, file, scope, indent, name, "u16", items, numericConstItem, optional_value),
        .uint32 => try emitListConstOfType(allocator, out, file, scope, indent, name, "u32", items, numericConstItem, optional_value),
        .uint64 => try emitListConstOfType(allocator, out, file, scope, indent, name, "u64", items, numericConstItem, optional_value),
        .float32 => try emitListConstOfType(allocator, out, file, scope, indent, name, "f32", items, float32ConstItem, optional_value),
        .float64 => try emitListConstOfType(allocator, out, file, scope, indent, name, "f64", items, float64ConstItem, optional_value),
        .text => try emitTextOrDataListConst(allocator, out, file, scope, indent, name, items, true, optional_value),
        .data => try emitTextOrDataListConst(allocator, out, file, scope, indent, name, items, false, optional_value),
        .capability => try emitOptionalCapabilityListConst(allocator, out, file, scope, indent, name, items, optional_value),
        .any_pointer => try emitAnyPointerListConst(allocator, out, file, scope, indent, name, child, items, .any),
        .any_struct => try emitAnyPointerListConst(allocator, out, file, scope, indent, name, child, items, .struct_ptr),
        .any_list => try emitAnyPointerListConst(allocator, out, file, scope, indent, name, child, items, .list),
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .void => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "void", items, voidConstItem, optional_value),
            .bool => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "bool", items, boolConstItem, optional_value),
            .int8 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "i8", items, numericConstItem, optional_value),
            .int16 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "i16", items, numericConstItem, optional_value),
            .int32 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "i32", items, numericConstItem, optional_value),
            .int64 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "i64", items, numericConstItem, optional_value),
            .uint8 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "u8", items, numericConstItem, optional_value),
            .uint16 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "u16", items, numericConstItem, optional_value),
            .uint32 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "u32", items, numericConstItem, optional_value),
            .uint64 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "u64", items, numericConstItem, optional_value),
            .float32 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "f32", items, float32ConstItem, optional_value),
            .float64 => try emitOptionalListConstOfType(allocator, out, file, scope, indent, name, "f64", items, float64ConstItem, optional_value),
            .text => try emitOptionalTextOrDataListConst(allocator, out, file, scope, indent, name, items, true, optional_value),
            .data => try emitOptionalTextOrDataListConst(allocator, out, file, scope, indent, name, items, false, optional_value),
            .any_pointer => try emitOptionalAnyPointerListConst(allocator, out, file, scope, indent, name, child, items, .any),
            .any_struct => try emitOptionalAnyPointerListConst(allocator, out, file, scope, indent, name, child, items, .struct_ptr),
            .any_list => try emitOptionalAnyPointerListConst(allocator, out, file, scope, indent, name, child, items, .list),
            .capability => try emitOptionalCapabilityListConst(allocator, out, file, scope, indent, name, items, optional_value),
            .named => |type_name| {
                if (findInterface(file, type_name) != null) {
                    try emitOptionalCapabilityListConst(allocator, out, file, scope, indent, name, items, optional_value);
                } else if (findStructDirect(file, type_name) != null) {
                    try emitOptionalStructListConst(allocator, out, file, scope, indent, name, child, type_name, items);
                } else if (findEnum(file, type_name)) |enum_decl| {
                    try emitOptionalEnumListConst(allocator, out, file, scope, indent, name, type_name, enum_decl, items, optional_value);
                }
            },
            else => return,
        },
        .named => |type_name| {
            if (findStructDirect(file, type_name) != null) {
                try emitStructListConst(allocator, out, file, scope, indent, name, type_name, items);
                return;
            }
            if (findInterface(file, type_name) != null) {
                try emitOptionalCapabilityListConst(allocator, out, file, scope, indent, name, items, optional_value);
                return;
            }
            const enum_decl = findEnum(file, type_name) orelse return;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            const value_type = if (optional_value)
                try std.fmt.allocPrint(allocator, "?[]const {s}", .{zig_type})
            else
                try std.fmt.allocPrint(allocator, "[]const {s}", .{zig_type});
            defer allocator.free(value_type);
            try appendFmt(allocator, out, "{s}pub const {s}: {s} = &[_]{s}{{", .{ indent, name, value_type, zig_type });
            for (items, 0..) |item, i| {
                if (i != 0) try out.appendSlice(allocator, ", ");
                try appendFmt(allocator, out, "@enumFromInt({})", .{try resolvedEnumDefaultOrdinal(file, scope, enum_decl, item.literal)});
            }
            try out.appendSlice(allocator, "};\n\n");
            try emitEnumListFlatContainer(allocator, out, file, scope, indent, name, zig_type, enum_decl, items);
        },
        else => return,
    }
}

pub fn emitStructListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, type_name: []const u8, items: []const ConstListItem) LayoutError!void {
    const flat = try listStructItemsFlatBytesAlloc(allocator, file, scope, type_name, items);
    defer allocator.free(flat);
    const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
    defer allocator.free(zig_type);
    try emitStructListFlatContainerFromBytes(allocator, out, indent, name, zig_type, flat);
}

pub fn blobListConstItem(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, item: ConstListItem, comptime is_text: bool) LayoutError![]const u8 {
    const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item.literal, is_text)) orelse if (!is_text and item.is_hex_data)
        try hexBytesAlloc(allocator, item.literal)
    else
        try decodedStringBytesAlloc(allocator, item.literal);
    defer allocator.free(bytes);
    return zigRawStringLiteralAlloc(allocator, bytes);
}

pub fn emitTextOrDataListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, comptime is_text: bool, comptime optional_value: bool) LayoutError!void {
    const value_type = if (optional_value) "?[]const []const u8" else "[]const []const u8";
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = &[_][]const u8{{
    , .{ indent, name, value_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const literal = try blobListConstItem(allocator, file, scope, item, is_text);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "};\n\n");

    try emitTextOrDataListFlatContainer(allocator, out, file, scope, indent, name, items, is_text);
}

pub fn emitListConstOfType(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    file: *const File,
    scope: ?*const Struct,
    indent: []const u8,
    name: []const u8,
    zig_type: []const u8,
    items: []const ConstListItem,
    comptime itemLiteral: fn (std.mem.Allocator, ConstListItem) LayoutError![]const u8,
    comptime optional_value: bool,
) LayoutError!void {
    const value_type = if (optional_value)
        try std.fmt.allocPrint(allocator, "?[]const {s}", .{zig_type})
    else
        try std.fmt.allocPrint(allocator, "[]const {s}", .{zig_type});
    defer allocator.free(value_type);
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = &[_]{s}{{
    , .{ indent, name, value_type, zig_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const literal = try itemLiteral(allocator, resolved_item);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "};\n\n");
    if (std.mem.eql(u8, zig_type, "void")) {
        try emitVoidListFlatContainer(allocator, out, file, scope, indent, name, items);
    } else if (std.mem.eql(u8, zig_type, "bool")) {
        try emitBoolListFlatContainer(allocator, out, file, scope, indent, name, items);
    } else if (std.mem.eql(u8, zig_type, "i8")) {
        try emitSignedListFlatContainer(i8, u8, allocator, out, file, scope, indent, name, items, .byte, ".byte", "getInt8");
    } else if (std.mem.eql(u8, zig_type, "i16")) {
        try emitSignedListFlatContainer(i16, u16, allocator, out, file, scope, indent, name, items, .two_bytes, ".two_bytes", "getInt16");
    } else if (std.mem.eql(u8, zig_type, "i32")) {
        try emitSignedListFlatContainer(i32, u32, allocator, out, file, scope, indent, name, items, .four_bytes, ".four_bytes", "getInt32");
    } else if (std.mem.eql(u8, zig_type, "i64")) {
        try emitSignedListFlatContainer(i64, u64, allocator, out, file, scope, indent, name, items, .eight_bytes, ".eight_bytes", "getInt64");
    } else if (std.mem.eql(u8, zig_type, "u8")) {
        try emitUnsignedListFlatContainer(u8, allocator, out, file, scope, indent, name, items, .byte, ".byte", "getUInt8");
    } else if (std.mem.eql(u8, zig_type, "u16")) {
        try emitUnsignedListFlatContainer(u16, allocator, out, file, scope, indent, name, items, .two_bytes, ".two_bytes", "getUInt16");
    } else if (std.mem.eql(u8, zig_type, "u32")) {
        try emitUnsignedListFlatContainer(u32, allocator, out, file, scope, indent, name, items, .four_bytes, ".four_bytes", "getUInt32");
    } else if (std.mem.eql(u8, zig_type, "u64")) {
        try emitUnsignedListFlatContainer(u64, allocator, out, file, scope, indent, name, items, .eight_bytes, ".eight_bytes", "getUInt64");
    } else if (std.mem.eql(u8, zig_type, "f32")) {
        try emitFloatListFlatContainer(f32, u32, allocator, out, file, scope, indent, name, items, .four_bytes, ".four_bytes", "getFloat32");
    } else if (std.mem.eql(u8, zig_type, "f64")) {
        try emitFloatListFlatContainer(f64, u64, allocator, out, file, scope, indent, name, items, .eight_bytes, ".eight_bytes", "getFloat64");
    } else if (std.mem.eql(u8, zig_type, "[]const u8")) {
        if (itemLiteral == stringConstItem) {
            try emitTextOrDataListFlatContainer(allocator, out, file, scope, indent, name, items, true);
        } else if (itemLiteral == dataConstItem) {
            try emitTextOrDataListFlatContainer(allocator, out, file, scope, indent, name, items, false);
        }
    }
}

pub fn voidConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    if (!std.mem.eql(u8, item.literal, "void")) return error.InvalidToken;
    return allocator.dupe(u8, "{}");
}

pub fn boolConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return allocator.dupe(u8, try boolConstLiteral(item.literal));
}

pub fn numericConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    const literal = if (std.mem.startsWith(u8, item.literal, "+")) item.literal[1..] else item.literal;
    return allocator.dupe(u8, literal);
}

pub fn float32ConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return allocator.dupe(u8, floatConstLiteral(item.literal, "f32"));
}

pub fn float64ConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return allocator.dupe(u8, floatConstLiteral(item.literal, "f64"));
}

pub fn stringConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return zigStringLiteralAlloc(allocator, item.literal);
}

pub fn dataConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return zigDataLiteralAlloc(allocator, item.literal, item.is_hex_data);
}

pub fn optionalListConstItem(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    item: ConstListItem,
    comptime itemLiteral: fn (std.mem.Allocator, ConstListItem) LayoutError![]const u8,
) LayoutError![]const u8 {
    const resolved_item = resolveScalarConstListItem(file, scope, item);
    if (std.mem.eql(u8, std.mem.trim(u8, resolved_item.literal, " \t\r\n"), "null")) {
        return allocator.dupe(u8, "null");
    }
    return itemLiteral(allocator, resolved_item);
}

pub fn emitOptionalListConstOfType(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    file: *const File,
    scope: ?*const Struct,
    indent: []const u8,
    name: []const u8,
    zig_type: []const u8,
    items: []const ConstListItem,
    comptime itemLiteral: fn (std.mem.Allocator, ConstListItem) LayoutError![]const u8,
    comptime optional_value: bool,
) LayoutError!void {
    const value_type = if (optional_value)
        try std.fmt.allocPrint(allocator, "?[]const ?{s}", .{zig_type})
    else
        try std.fmt.allocPrint(allocator, "[]const ?{s}", .{zig_type});
    defer allocator.free(value_type);
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = &[_]?{s}{{
    , .{ indent, name, value_type, zig_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const literal = try optionalListConstItem(allocator, file, scope, item, itemLiteral);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "};\n\n");
}

pub fn emitOptionalEnumListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, type_name: []const u8, enum_decl: *const EnumDecl, items: []const ConstListItem, comptime optional_value: bool) LayoutError!void {
    const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
    defer allocator.free(zig_type);
    const value_type = if (optional_value)
        try std.fmt.allocPrint(allocator, "?[]const ?{s}", .{zig_type})
    else
        try std.fmt.allocPrint(allocator, "[]const ?{s}", .{zig_type});
    defer allocator.free(value_type);
    try appendFmt(allocator, out, "{s}pub const {s}: {s} = &[_]?{s}{{", .{ indent, name, value_type, zig_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        if (std.mem.eql(u8, std.mem.trim(u8, resolved_item.literal, " \t\r\n"), "null")) {
            try out.appendSlice(allocator, "null");
        } else {
            try appendFmt(allocator, out, "@enumFromInt({})", .{try resolvedEnumDefaultOrdinal(file, scope, enum_decl, item.literal)});
        }
    }
    try out.appendSlice(allocator, "};\n\n");
}

pub fn optionalBlobConstItemBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, item: ConstListItem, comptime is_text: bool) LayoutError!?[]u8 {
    const resolved_literal = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item.literal), " \t\r\n");
    if (std.mem.eql(u8, resolved_literal, "null")) return null;
    if (try referencedBlobBytesAlloc(allocator, file, scope, item.literal, is_text)) |bytes| return bytes;
    return if (item.is_hex_data)
        try hexBytesAlloc(allocator, item.literal)
    else
        try decodedStringBytesAlloc(allocator, resolved_literal);
}

pub fn optionalBlobConstItem(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, item: ConstListItem, comptime is_text: bool) LayoutError![]const u8 {
    const bytes = try optionalBlobConstItemBytesAlloc(allocator, file, scope, item, is_text) orelse return allocator.dupe(u8, "null");
    defer allocator.free(bytes);
    return zigRawStringLiteralAlloc(allocator, bytes);
}

pub fn emitOptionalStructListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, child: Type, type_name: []const u8, items: []const ConstListItem) LayoutError!void {
    const flat = try listOptionalStructConstFlatBytesAlloc(allocator, file, scope, type_name, items);
    defer allocator.free(flat);
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, name, child, flat);
}

pub fn emitOptionalAnyPointerListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, child: Type, items: []const ConstListItem, comptime want: AnyPointerDefaultKind) LayoutError!void {
    const flat = try listOptionalAnyPointerConstFlatBytesAlloc(allocator, file, scope, items, want);
    defer allocator.free(flat);
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, name, child, flat);
}

pub fn emitAnyPointerListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, child: Type, items: []const ConstListItem, comptime want: AnyPointerDefaultKind) LayoutError!void {
    const flat = try listOptionalAnyPointerConstFlatBytesAlloc(allocator, file, scope, items, want);
    defer allocator.free(flat);
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, name, child, flat);
}

pub fn emitOptionalTextOrDataListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, comptime is_text: bool, comptime optional_value: bool) LayoutError!void {
    const value_type = if (optional_value) "?[]const ?[]const u8" else "[]const ?[]const u8";
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = &[_]?[]const u8{{
    , .{ indent, name, value_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const literal = try optionalBlobConstItem(allocator, file, scope, item, is_text);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "};\n\n");

    const flat = try listOptionalTextOrDataFlatBytesAlloc(allocator, file, scope, items, is_text);
    defer allocator.free(flat);
    var text_type: Type = .text;
    var data_type: Type = .data;
    const child: Type = if (is_text) .{ .optional = &text_type } else .{ .optional = &data_type };
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, name, child, flat);
}

pub fn optionalCapabilityConstItem(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, item: ConstListItem) LayoutError![]const u8 {
    const resolved = std.mem.trim(u8, resolveScalarConstLiteral(file, scope, item.literal), " \t\r\n");
    if (std.mem.eql(u8, resolved, "void") or std.mem.eql(u8, resolved, "null")) return allocator.dupe(u8, "null");
    return error.InvalidToken;
}

pub fn emitOptionalCapabilityListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, items: []const ConstListItem, comptime optional_value: bool) LayoutError!void {
    const value_type = if (optional_value) "?[]const ?u32" else "[]const ?u32";
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = &[_]?u32{{
    , .{ indent, name, value_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const literal = try optionalCapabilityConstItem(allocator, file, scope, item);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "};\n\n");

    const flat = try listCapabilityFlatBytesAlloc(allocator, file, scope, items);
    defer allocator.free(flat);
    try emitCapabilityListFlatContainerFromBytes(allocator, out, indent, name, flat);
}
