const std = @import("std");
const message = @import("../../message.zig");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const state = @import("state.zig");
const mod_const_emit = @import("const_emit.zig");
const mod_field_defaults = @import("field_defaults.zig");
const mod_flat = @import("flat.zig");
const mod_metadata = @import("metadata.zig");
const mod_state = @import("state.zig");
const mod_text = @import("text.zig");

const AnnotationDecl = frontend.AnnotationDecl;
const AnnotationTargets = frontend.AnnotationTargets;
const ConstDecl = frontend.ConstDecl;
const ConstListItem = frontend.ConstListItem;
const EnumDecl = frontend.EnumDecl;
const EnumValueMetadata = frontend.EnumValueMetadata;
const Field = frontend.Field;
const File = frontend.File;
const InterfaceDecl = frontend.InterfaceDecl;
const InterfaceMethod = frontend.InterfaceMethod;
const InterfaceMethodMetadata = frontend.InterfaceMethodMetadata;
const InterfaceSuperclassMetadata = frontend.InterfaceSuperclassMetadata;
const LayoutError = frontend.LayoutError;
const MethodField = frontend.MethodField;
const Struct = frontend.Struct;
const Type = frontend.Type;
const annotationOwnerName = frontend.annotationOwnerName;
const constDeclOwnerName = frontend.constDeclOwnerName;
const findConstReference = frontend.findConstReference;
const findEnum = frontend.findEnum;
const findInterface = frontend.findInterface;
const findStructDirect = frontend.findStructDirect;
const isStructLikeName = frontend.isStructLikeName;
const lastTopLevelDot = frontend.lastTopLevelDot;
const parse = frontend.parse;
const parseTypeArgAlloc = frontend.parseTypeArgAlloc;
const resolveConstDeclType = frontend.resolveConstDeclType;
const resolveConstReferenceLiteral = frontend.resolveConstReferenceLiteral;
const resolveTypeInOwnerScope = frontend.resolveTypeInOwnerScope;
const resolveTypeScoped = frontend.resolveTypeScoped;
const schemaTypeNameAlloc = frontend.schemaTypeNameAlloc;
const typeAcceptsNullPointerDefault = frontend.typeAcceptsNullPointerDefault;
const typeAcceptsVoidPointerDefault = frontend.typeAcceptsVoidPointerDefault;
const typeNameEqualsCanonical = frontend.typeNameEqualsCanonical;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const emitAlias = mod_const_emit.emitAlias;
const emitFlatContainerSizeHelpers = mod_const_emit.emitFlatContainerSizeHelpers;
const emitNestedConst = mod_const_emit.emitNestedConst;
const blobFieldDefaultFlatBytesAlloc = mod_field_defaults.blobFieldDefaultFlatBytesAlloc;
const constListItemsFromInlineLiteralAlloc = mod_field_defaults.constListItemsFromInlineLiteralAlloc;
const listNestedFieldDefaultFlatBytesAlloc = mod_field_defaults.listNestedFieldDefaultFlatBytesAlloc;
const listOptionalAnyPointerDefaultFlatBytesAlloc = mod_field_defaults.listOptionalAnyPointerDefaultFlatBytesAlloc;
const listOptionalStructFieldDefaultFlatBytesAlloc = mod_field_defaults.listOptionalStructFieldDefaultFlatBytesAlloc;
const listOptionalTextOrDataFieldDefaultFlatBytesAlloc = mod_field_defaults.listOptionalTextOrDataFieldDefaultFlatBytesAlloc;
const listStructFieldDefaultFlatBytesAlloc = mod_field_defaults.listStructFieldDefaultFlatBytesAlloc;
const listTextOrDataFieldDefaultFlatBytesAlloc = mod_field_defaults.listTextOrDataFieldDefaultFlatBytesAlloc;
const structFieldDefaultFlatBytesAlloc = mod_field_defaults.structFieldDefaultFlatBytesAlloc;
const constDeclResolutionScope = mod_flat.constDeclResolutionScope;
const flatByteLenForSegmentWords = mod_flat.flatByteLenForSegmentWords;
const inlineDataBytesAlloc = mod_flat.inlineDataBytesAlloc;
const inlineQuotedStringBytesAlloc = mod_flat.inlineQuotedStringBytesAlloc;
const listBoolFlatBytesAlloc = mod_flat.listBoolFlatBytesAlloc;
const listCapabilityFlatBytesAlloc = mod_flat.listCapabilityFlatBytesAlloc;
const listEnumFlatBytesAlloc = mod_flat.listEnumFlatBytesAlloc;
const listFloatFlatBytesAlloc = mod_flat.listFloatFlatBytesAlloc;
const listSignedFlatBytesAlloc = mod_flat.listSignedFlatBytesAlloc;
const listUnsignedFlatBytesAlloc = mod_flat.listUnsignedFlatBytesAlloc;
const listVoidFlatBytesAlloc = mod_flat.listVoidFlatBytesAlloc;
const referencedBlobBytesAlloc = mod_flat.referencedBlobBytesAlloc;
const scalarConstFlatBytesAlloc = mod_flat.scalarConstFlatBytesAlloc;
const emitAliasMetadataTable = mod_metadata.emitAliasMetadataTable;
const emitConstMetadataTable = mod_metadata.emitConstMetadataTable;
const emitScopedAnnotationMetadataTable = mod_metadata.emitScopedAnnotationMetadataTable;
const AnyPointerDefaultKind = mod_state.AnyPointerDefaultKind;
const appendFmt = mod_text.appendFmt;
const schemaResolvedTypeNameInOwnerScopeAlloc = mod_text.schemaResolvedTypeNameInOwnerScopeAlloc;
const zigRawStringLiteralAlloc = mod_text.zigRawStringLiteralAlloc;
const zigSchemaSyntaxLiteralAlloc = mod_text.zigSchemaSyntaxLiteralAlloc;
const zigStringLiteralAlloc = mod_text.zigStringLiteralAlloc;
const zigTypeRefAlloc = mod_text.zigTypeRefAlloc;

pub fn emitDeclarationAnnotations(allocator: std.mem.Allocator, out: *std.ArrayList(u8), annotations: []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    if (annotations.len == 0) return;
    const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.annotations": []const u8 = {s};
        \\
    , .{ indent, annotation_literal });
}

pub fn emitEnum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), decl: *const EnumDecl) LayoutError!void {
    const enum_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(enum_name);
    try appendFmt(allocator, out,
        \\pub const {s} = enum(u16) {{
        \\
    , .{enum_name});
    if (decl.id) |id| {
        try appendFmt(allocator, out,
            \\    pub const @"cpz.type_id": u64 = 0x{x};
            \\
        , .{id});
    }
    try emitDeclarationAnnotations(allocator, out, decl.annotations, "    ");
    for (decl.values) |value| {
        const value_name = try zigIdentAlloc(allocator, value.name);
        defer allocator.free(value_name);
        try appendFmt(allocator, out,
            \\    {s} = {},
            \\
        , .{ value_name, value.ordinal });
    }
    try appendFmt(allocator, out,
        \\}};
        \\
    , .{});
    try appendFmt(allocator, out,
        \\pub fn @"cpz.enum.{s}.fromRaw"(raw: u16) ?{s} {{
        \\    return std.enums.fromInt({s}, raw);
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.toRaw"(value: {s}) u16 {{
        \\    return @intFromEnum(value);
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.name"(value: {s}) []const u8 {{
        \\    const raw = @intFromEnum(value);
        \\    for (@"cpz.enum.{s}.values") |item| if (item.ordinal == raw) return item.name;
        \\    return @tagName(value);
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.nameFromRaw"(raw: u16) ?[]const u8 {{
        \\    const value = @"cpz.enum.{s}.fromRaw"(raw) orelse return null;
        \\    return @"cpz.enum.{s}.name"(value);
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.valueByName"(@"cpz.name": []const u8) ?{s} {{
        \\    for (@"cpz.enum.{s}.values") |item| if (std.mem.eql(u8, item.name, @"cpz.name")) return @"cpz.enum.{s}.fromRaw"(item.ordinal).?;
        \\    return null;
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.valueByRaw"(raw: u16) ?{s} {{
        \\    return @"cpz.enum.{s}.fromRaw"(raw);
        \\}}
        \\
        \\
        \\pub fn @"cpz.enum.{s}.valueByMetadata"(metadata: cpz.schema.EnumValueMetadata) ?{s} {{
        \\    return @"cpz.enum.{s}.fromRaw"(metadata.ordinal);
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.valueByAnnotations"(@"cpz.annotationFilter": []const u8) ?{s} {{
        \\    const metadata = @"cpz.enum.{s}.metadataByAnnotations"(@"cpz.annotationFilter") orelse return null;
        \\    return @"cpz.enum.{s}.valueByMetadata"(metadata);
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.valueByIndex"(@"cpz.index": usize) ?{s} {{
        \\    const metadata = @"cpz.enum.{s}.metadataByIndex"(@"cpz.index") orelse return null;
        \\    return @"cpz.enum.{s}.valueByMetadata"(metadata);
        \\}}
        \\
    , .{ enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name });
    try appendFmt(allocator, out,
        \\pub fn @"cpz.enum.{s}.metadataByName"(@"cpz.name": []const u8) ?cpz.schema.EnumValueMetadata {{
        \\    for (@"cpz.enum.{s}.values") |item| if (std.mem.eql(u8, item.name, @"cpz.name")) return item;
        \\    return null;
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.metadataByRaw"(raw: u16) ?cpz.schema.EnumValueMetadata {{
        \\    for (@"cpz.enum.{s}.values") |item| if (item.ordinal == raw) return item;
        \\    return null;
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.metadataByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.EnumValueMetadata {{
        \\    for (@"cpz.enum.{s}.values") |item| if (std.mem.eql(u8, item.annotations, @"cpz.annotationFilter")) return item;
        \\    return null;
        \\}}
        \\
        \\pub fn @"cpz.enum.{s}.metadataByIndex"(@"cpz.index": usize) ?cpz.schema.EnumValueMetadata {{
        \\    if (@"cpz.index" >= @"cpz.enum.{s}.values".len) return null;
        \\    return @"cpz.enum.{s}.values"[@"cpz.index"];
        \\}}
    , .{ enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name });
    try appendFmt(allocator, out,
        \\pub const @"cpz.enum.{s}.valueCount": usize = {};
        \\
    , .{ enum_name, decl.values.len });
    try appendFmt(allocator, out,
        \\pub const @"cpz.enum.{s}.values": []const cpz.schema.EnumValueMetadata = &[_]cpz.schema.EnumValueMetadata{{
    , .{enum_name});
    for (decl.values, 0..) |value, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const value_name_literal = try zigStringLiteralAlloc(allocator, value.name);
        defer allocator.free(value_name_literal);
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, value.annotations);
        defer allocator.free(annotation_literal);
        if (value.annotations.len != 0) {
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ordinal = {}, .annotations = {s} }}", .{ value.index, value_name_literal, value.ordinal, annotation_literal });
        } else {
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ordinal = {} }}", .{ value.index, value_name_literal, value.ordinal });
        }
    }
    try out.appendSlice(allocator, "};\n");
    for (decl.values) |value| {
        const enum_name_for_const = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(enum_name_for_const);
        const value_name = try zigIdentAlloc(allocator, value.name);
        defer allocator.free(value_name);
        const value_name_literal = try zigStringLiteralAlloc(allocator, value.name);
        defer allocator.free(value_name_literal);
        try appendFmt(allocator, out,
            \\pub const @"cpz.enumerant.{s}.{s}.index": usize = {};
            \\pub const @"cpz.enumerant.{s}.{s}.name": []const u8 = {s};
            \\pub const @"cpz.enumerant.{s}.{s}.ordinal": u16 = {};
            \\pub const @"cpz.enumerant.{s}.{s}.metadata": cpz.schema.EnumValueMetadata = @"cpz.enum.{s}.values"[{}];
        , .{ enum_name_for_const, value_name, value.index, enum_name_for_const, value_name, value_name_literal, enum_name_for_const, value_name, value.ordinal, enum_name_for_const, value_name, enum_name_for_const, value.index });
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, value.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out,
            \\pub const @"cpz.enumerant.{s}.{s}.annotations": []const u8 = {s};
            \\
        , .{ enum_name_for_const, value_name, annotation_literal });
    }
    try out.append(allocator, '\n');
}

pub fn emitInterface(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, decl: *const InterfaceDecl) LayoutError!void {
    const interface_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(interface_name);
    try appendFmt(allocator, out,
        \\pub const {s} = struct {{
        \\
    , .{interface_name});
    if (decl.id) |id| {
        try appendFmt(allocator, out,
            \\    pub const @"cpz.type_id": u64 = 0x{x};
            \\
        , .{id});
    }
    try emitDeclarationAnnotations(allocator, out, decl.annotations, "    ");
    try emitParameterMetadata(allocator, out, decl.parameters, "    ");
    try emitInterfaceSuperclassMetadata(allocator, out, file, decl, decl.superclasses, "    ");
    for (decl.superclasses, 0..) |superclass, index| {
        switch (resolveTypeInOwnerScope(file, decl.name, superclass)) {
            .named => |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\    pub const Superclass{} = {s};
                    \\
                , .{ index, zig_type });
            },
            else => return error.UnsupportedType,
        }
    }
    var empty_fields: [0]Field = .{};
    var alias_scope = Struct{
        .name = decl.name,
        .fields = empty_fields[0..],
        .consts = decl.consts,
        .aliases = decl.aliases,
    };
    for (decl.aliases, 0..) |*alias, alias_index| {
        try emitAlias(allocator, out, file, &alias_scope, alias_index, alias, "    ");
    }
    try emitAliasMetadataTable(allocator, out, file, &alias_scope, decl.aliases, "    ");
    for (decl.consts, 0..) |*nested_const, const_index| {
        try emitNestedConst(allocator, out, file, &alias_scope, const_index, nested_const);
    }
    try emitConstMetadataTable(allocator, out, file, &alias_scope, decl.consts, "    ");
    try emitScopedAnnotationMetadataTable(allocator, out, file, decl.name, "    ");
    try appendInterfaceMethodTable(allocator, out, file, decl, decl.methods, "    ");
    for (decl.methods, 0..) |method, method_index| {
        const method_name = try zigIdentAlloc(allocator, method.name);
        defer allocator.free(method_name);
        const method_name_literal = try zigStringLiteralAlloc(allocator, method.name);
        defer allocator.free(method_name_literal);
        try appendFmt(allocator, out,
            \\    pub const {s}: u16 = {};
            \\    pub const @"cpz.method.{s}.index": usize = {};
            \\    pub const @"cpz.method.{s}.name": []const u8 = {s};
            \\    pub const @"cpz.method.{s}.ordinal": u16 = {};
            \\    pub const @"cpz.method.{s}.metadata": cpz.schema.InterfaceMethodMetadata = @This().@"cpz.methods"[{}];
            \\
        , .{ method_name, method.ordinal, method_name, method_index, method_name, method_name_literal, method_name, method.ordinal, method_name, method_index });
        if (decl.id) |_| {
            try appendFmt(allocator, out,
                \\    pub const @"cpz.method.{s}.callMethod": cpz.rpc.CallMethod = .{{ .interface_id = @This().@"cpz.type_id", .method_id = {} }};
                \\    pub const @"cpz.method.{s}.callOptions": cpz.rpc.CallOptions = @This().@"cpz.method.{s}.callMethod".callOptions();
                \\    pub fn @"cpz.method.{s}.entry"(handler: anytype) cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
                \\        return @This().@"cpz.method.{s}.callMethod".methodEntry(handler);
                \\    }}
                \\
            , .{ method_name, method.ordinal, method_name, method_name, method_name, method_name });
        }
        const signature_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.signature);
        defer allocator.free(signature_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.signature": []const u8 = {s};
            \\
        , .{ method_name, signature_literal });
        const params_signature_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.params_signature);
        defer allocator.free(params_signature_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.params": []const u8 = {s};
            \\
        , .{ method_name, params_signature_literal });
        const params_type_literal = try zigStringLiteralAlloc(allocator, method.params_type);
        defer allocator.free(params_type_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.paramsType": []const u8 = {s};
            \\
        , .{ method_name, params_type_literal });
        const resolved_params_type = if (method.params_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, decl, method.parameters, method.params_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_params_type);
        const resolved_params_type_literal = try zigStringLiteralAlloc(allocator, resolved_params_type);
        defer allocator.free(resolved_params_type_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.resolvedParamsType": []const u8 = {s};
            \\
        , .{ method_name, resolved_params_type_literal });
        const results_signature_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.results_signature);
        defer allocator.free(results_signature_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.results": []const u8 = {s};
            \\
        , .{ method_name, results_signature_literal });
        const results_type_literal = try zigStringLiteralAlloc(allocator, method.results_type);
        defer allocator.free(results_type_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.resultsType": []const u8 = {s};
            \\
        , .{ method_name, results_type_literal });
        const resolved_results_type = if (method.results_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, decl, method.parameters, method.results_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_results_type);
        const resolved_results_type_literal = try zigStringLiteralAlloc(allocator, resolved_results_type);
        defer allocator.free(resolved_results_type_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.resolvedResultsType": []const u8 = {s};
            \\
        , .{ method_name, resolved_results_type_literal });
        const annotation_signature_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.annotation_signature);
        defer allocator.free(annotation_signature_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.annotations": []const u8 = {s};
            \\
        , .{ method_name, annotation_signature_literal });
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.streaming": bool = {};
            \\
        , .{ method_name, method.is_streaming });
        try appendMethodParameterMetadata(allocator, out, method_name, method.parameters, "    ");
        try appendMethodFieldMetadata(allocator, out, file, decl, method_name, method.parameters, "params", method.param_fields, "    ");
        try appendMethodFieldMetadata(allocator, out, file, decl, method_name, method.parameters, "results", method.result_fields, "    ");
        for (method.param_fields) |field| try emitMethodFieldDefaultFlatContainer(allocator, out, file, &alias_scope, method_name, "params", field, "    ");
        for (method.result_fields) |field| try emitMethodFieldDefaultFlatContainer(allocator, out, file, &alias_scope, method_name, "results", field, "    ");
    }
    if (decl.id != null and decl.methods.len != 0) {
        try appendFmt(allocator, out,
            \\    pub const @"cpz.callMethods": []const cpz.rpc.CallMethod = &[_]cpz.rpc.CallMethod{{
            \\
        , .{});
        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            try appendFmt(allocator, out,
                \\        @This().@"cpz.method.{s}.callMethod",
                \\
            , .{method_name});
        }
        try appendFmt(allocator, out,
            \\    }};
            \\
            \\    pub const @"cpz.callOptions": []const cpz.rpc.CallOptions = &[_]cpz.rpc.CallOptions{{
            \\
        , .{});
        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            try appendFmt(allocator, out,
                \\        @This().@"cpz.method.{s}.callOptions",
                \\
            , .{method_name});
        }
        try appendFmt(allocator, out,
            \\    }};
            \\
            \\    pub fn @"cpz.callMethodByIndex"(@"cpz.index": usize) ?cpz.rpc.CallMethod {{
            \\        if (@"cpz.index" >= @This().@"cpz.callMethods".len) return null;
            \\        return @This().@"cpz.callMethods"[@"cpz.index"];
            \\    }}
            \\
            \\    pub fn @"cpz.callOptionsByIndex"(@"cpz.index": usize) ?cpz.rpc.CallOptions {{
            \\        if (@"cpz.index" >= @This().@"cpz.callOptions".len) return null;
            \\        return @This().@"cpz.callOptions"[@"cpz.index"];
            \\    }}
            \\
            \\    pub fn @"cpz.callMethodByName"(@"cpz.name": []const u8) ?cpz.rpc.CallMethod {{
            \\        const @"cpz.method" = @This().@"cpz.methodByName"(@"cpz.name") orelse return null;
            \\        return @This().@"cpz.callMethodByIndex"(@"cpz.method".index);
            \\    }}
            \\
            \\    pub fn @"cpz.callOptionsByName"(@"cpz.name": []const u8) ?cpz.rpc.CallOptions {{
            \\        const @"cpz.method" = @This().@"cpz.methodByName"(@"cpz.name") orelse return null;
            \\        return @This().@"cpz.callOptionsByIndex"(@"cpz.method".index);
            \\    }}
            \\
            \\    pub fn @"cpz.callMethodByOrdinal"(@"cpz.ordinal": u16) ?cpz.rpc.CallMethod {{
            \\        const @"cpz.method" = @This().@"cpz.methodByOrdinal"(@"cpz.ordinal") orelse return null;
            \\        return @This().@"cpz.callMethodByIndex"(@"cpz.method".index);
            \\    }}
            \\
            \\    pub fn @"cpz.callOptionsByOrdinal"(@"cpz.ordinal": u16) ?cpz.rpc.CallOptions {{
            \\        const @"cpz.method" = @This().@"cpz.methodByOrdinal"(@"cpz.ordinal") orelse return null;
            \\        return @This().@"cpz.callOptionsByIndex"(@"cpz.method".index);
            \\    }}
            \\
            \\    pub fn @"cpz.callMethodByCallMethod"(@"cpz.callMethod": cpz.rpc.CallMethod) ?cpz.rpc.CallMethod {{
            \\        const @"cpz.method" = @This().@"cpz.methodByCallMethod"(@"cpz.callMethod") orelse return null;
            \\        return @This().@"cpz.callMethodByIndex"(@"cpz.method".index);
            \\    }}
            \\
            \\    pub fn @"cpz.callOptionsByCallMethod"(@"cpz.callMethod": cpz.rpc.CallMethod) ?cpz.rpc.CallOptions {{
            \\        const @"cpz.method" = @This().@"cpz.methodByCallMethod"(@"cpz.callMethod") orelse return null;
            \\        return @This().@"cpz.callOptionsByIndex"(@"cpz.method".index);
            \\    }}
            \\
            \\    pub fn @"cpz.methodByWireCall"(@"cpz.call": anytype) ?cpz.schema.InterfaceMethodMetadata {{
            \\        return @This().@"cpz.methodByCallMethod"(cpz.rpc.callMethodFromWireCall(@"cpz.call"));
            \\    }}
            \\
            \\    pub fn @"cpz.callMethodByWireCall"(@"cpz.call": anytype) ?cpz.rpc.CallMethod {{
            \\        return @This().@"cpz.callMethodByCallMethod"(cpz.rpc.callMethodFromWireCall(@"cpz.call"));
            \\    }}
            \\
            \\    pub fn @"cpz.callOptionsByWireCall"(@"cpz.call": anytype) ?cpz.rpc.CallOptions {{
            \\        return @This().@"cpz.callOptionsByCallMethod"(cpz.rpc.callMethodFromWireCall(@"cpz.call"));
            \\    }}
            \\
            \\    pub fn @"cpz.methodByWireMessage"(@"cpz.message": anytype) !?cpz.schema.InterfaceMethodMetadata {{
            \\        const @"cpz.callMethod" = (try cpz.rpc.callMethodFromWireMessage(@"cpz.message")) orelse return null;
            \\        return @This().@"cpz.methodByCallMethod"(@"cpz.callMethod");
            \\    }}
            \\
            \\    pub fn @"cpz.callMethodByWireMessage"(@"cpz.message": anytype) !?cpz.rpc.CallMethod {{
            \\        const @"cpz.callMethod" = (try cpz.rpc.callMethodFromWireMessage(@"cpz.message")) orelse return null;
            \\        return @This().@"cpz.callMethodByCallMethod"(@"cpz.callMethod");
            \\    }}
            \\
            \\    pub fn @"cpz.callOptionsByWireMessage"(@"cpz.message": anytype) !?cpz.rpc.CallOptions {{
            \\        const @"cpz.callMethod" = (try cpz.rpc.callMethodFromWireMessage(@"cpz.message")) orelse return null;
            \\        return @This().@"cpz.callOptionsByCallMethod"(@"cpz.callMethod");
            \\    }}
            \\
            \\    pub fn @"cpz.methodEntryByIndex"(@"cpz.index": usize, handler: anytype) ?cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
            \\        const @"cpz.callMethod" = @This().@"cpz.callMethodByIndex"(@"cpz.index") orelse return null;
            \\        return @"cpz.callMethod".methodEntry(handler);
            \\    }}
            \\
            \\    pub fn @"cpz.methodEntryByName"(@"cpz.name": []const u8, handler: anytype) ?cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
            \\        const @"cpz.callMethod" = @This().@"cpz.callMethodByName"(@"cpz.name") orelse return null;
            \\        return @"cpz.callMethod".methodEntry(handler);
            \\    }}
            \\
            \\    pub fn @"cpz.methodEntryByOrdinal"(@"cpz.ordinal": u16, handler: anytype) ?cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
            \\        const @"cpz.callMethod" = @This().@"cpz.callMethodByOrdinal"(@"cpz.ordinal") orelse return null;
            \\        return @"cpz.callMethod".methodEntry(handler);
            \\    }}
            \\
            \\    pub fn @"cpz.methodEntryByCallMethod"(@"cpz.callMethod": cpz.rpc.CallMethod, handler: anytype) ?cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
            \\        const @"cpz.canonicalCallMethod" = @This().@"cpz.callMethodByCallMethod"(@"cpz.callMethod") orelse return null;
            \\        return @"cpz.canonicalCallMethod".methodEntry(handler);
            \\    }}
            \\
            \\    pub fn @"cpz.methodEntryByWireCall"(@"cpz.call": anytype, handler: anytype) ?cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
            \\        return @This().@"cpz.methodEntryByCallMethod"(cpz.rpc.callMethodFromWireCall(@"cpz.call"), handler);
            \\    }}
            \\
            \\    pub fn @"cpz.methodEntryByWireMessage"(@"cpz.message": anytype, handler: anytype) !?cpz.rpc.CallMethodEntry(@TypeOf(handler)) {{
            \\        const @"cpz.callMethod" = (try cpz.rpc.callMethodFromWireMessage(@"cpz.message")) orelse return null;
            \\        return @This().@"cpz.methodEntryByCallMethod"(@"cpz.callMethod", handler);
            \\    }}
            \\
        , .{});
        try appendFmt(allocator, out,
            \\    pub fn @"cpz.methodEntries"(handlers: anytype) @TypeOf(.{{
            \\
        , .{});
        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            try appendFmt(allocator, out,
                \\        @This().@"cpz.method.{s}.entry"(handlers[@This().@"cpz.method.{s}.index"]),
                \\
            , .{ method_name, method_name });
        }
        try appendFmt(allocator, out,
            \\    }}) {{
            \\        return .{{
            \\
        , .{});
        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            try appendFmt(allocator, out,
                \\            @This().@"cpz.method.{s}.entry"(handlers[@This().@"cpz.method.{s}.index"]),
                \\
            , .{ method_name, method_name });
        }
        try appendFmt(allocator, out,
            \\        }};
            \\    }}
            \\
        , .{});
        try appendFmt(allocator, out,
            \\    pub fn @"cpz.methodEntriesFromFields"(handlers: anytype) @TypeOf(.{{
            \\
        , .{});
        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            const method_name_literal = try zigStringLiteralAlloc(allocator, method.name);
            defer allocator.free(method_name_literal);
            try appendFmt(allocator, out,
                \\        @This().@"cpz.method.{s}.entry"(@field(handlers, {s})),
                \\
            , .{ method_name, method_name_literal });
        }
        try appendFmt(allocator, out,
            \\    }}) {{
            \\        return .{{
            \\
        , .{});
        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            const method_name_literal = try zigStringLiteralAlloc(allocator, method.name);
            defer allocator.free(method_name_literal);
            try appendFmt(allocator, out,
                \\            @This().@"cpz.method.{s}.entry"(@field(handlers, {s})),
                \\
            , .{ method_name, method_name_literal });
        }
        try appendFmt(allocator, out,
            \\        }};
            \\    }}
            \\
        , .{});
    }
    try appendFmt(allocator, out,
        \\}};
        \\
        \\
    , .{});
}

pub fn emitInterfaceSuperclassMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const InterfaceDecl, superclasses: []const Type, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.superclassCount": usize = {};
        \\
    , .{ indent, superclasses.len });
    for (superclasses, 0..) |superclass, index| {
        const superclass_name = try schemaTypeNameAlloc(allocator, superclass);
        defer allocator.free(superclass_name);
        const superclass_literal = try zigStringLiteralAlloc(allocator, superclass_name);
        defer allocator.free(superclass_literal);
        const owner_name = if (scope) |decl| decl.name else null;
        const resolved_superclass_name = try schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, superclass);
        defer allocator.free(resolved_superclass_name);
        const resolved_superclass_literal = try zigStringLiteralAlloc(allocator, resolved_superclass_name);
        defer allocator.free(resolved_superclass_literal);
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.superclass.{}.index": usize = {};
            \\{s}pub const @"cpz.superclass.{}.name": []const u8 = {s};
            \\{s}pub const @"cpz.superclass.{}.resolvedName": []const u8 = {s};
            \\{s}pub const @"cpz.superclass.{}.metadata": cpz.schema.InterfaceSuperclassMetadata = @This().@"cpz.superclasses"[{}];
            \\
        , .{ indent, index, index, indent, index, superclass_literal, indent, index, resolved_superclass_literal, indent, index, index });
    }
    try appendFmt(allocator, out, "{s}pub const @\"cpz.superclasses\": []const cpz.schema.InterfaceSuperclassMetadata = &[_]cpz.schema.InterfaceSuperclassMetadata{{", .{indent});
    const owner_name = if (scope) |decl| decl.name else null;
    for (superclasses, 0..) |superclass, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const superclass_name = try schemaTypeNameAlloc(allocator, superclass);
        defer allocator.free(superclass_name);
        const superclass_literal = try zigStringLiteralAlloc(allocator, superclass_name);
        defer allocator.free(superclass_literal);
        const resolved_superclass_name = try schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, superclass);
        defer allocator.free(resolved_superclass_name);
        const resolved_superclass_literal = try zigStringLiteralAlloc(allocator, resolved_superclass_name);
        defer allocator.free(resolved_superclass_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .resolved_name = {s} }}", .{ index, superclass_literal, resolved_superclass_literal });
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.superclassByName"(@"cpz.name": []const u8) ?cpz.schema.InterfaceSuperclassMetadata {{
        \\{s}    for (@This().@"cpz.superclasses") |@"cpz.superclass"| if (std.mem.eql(u8, @"cpz.superclass".name, @"cpz.name")) return @"cpz.superclass";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.superclassByResolvedName"(@"cpz.name": []const u8) ?cpz.schema.InterfaceSuperclassMetadata {{
        \\{s}    for (@This().@"cpz.superclasses") |@"cpz.superclass"| if (std.mem.eql(u8, @"cpz.superclass".resolved_name, @"cpz.name")) return @"cpz.superclass";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.superclassByIndex"(@"cpz.index": usize) ?cpz.schema.InterfaceSuperclassMetadata {{
        \\{s}    for (@This().@"cpz.superclasses") |@"cpz.superclass"| if (@"cpz.superclass".index == @"cpz.index") return @"cpz.superclass";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (superclasses.len != 0) try out.append(allocator, '\n');
}

pub fn appendInterfaceMethodTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const InterfaceDecl, methods: []const InterfaceMethod, indent: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.methodCount": usize = {};
        \\
    , .{ indent, methods.len });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.methods\": []const cpz.schema.InterfaceMethodMetadata = &[_]cpz.schema.InterfaceMethodMetadata{{", .{indent});
    for (methods, 0..) |method, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, method.name);
        defer allocator.free(name_literal);
        const signature_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.signature);
        defer allocator.free(signature_literal);
        const params_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.params_signature);
        defer allocator.free(params_literal);
        const results_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.results_signature);
        defer allocator.free(results_literal);
        const params_type_literal = try zigStringLiteralAlloc(allocator, method.params_type);
        defer allocator.free(params_type_literal);
        const results_type_literal = try zigStringLiteralAlloc(allocator, method.results_type);
        defer allocator.free(results_type_literal);
        const resolved_params_type = if (method.params_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method.parameters, method.params_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_params_type);
        const resolved_params_type_literal = try zigStringLiteralAlloc(allocator, resolved_params_type);
        defer allocator.free(resolved_params_type_literal);
        const resolved_results_type = if (method.results_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method.parameters, method.results_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_results_type);
        const resolved_results_type_literal = try zigStringLiteralAlloc(allocator, resolved_results_type);
        defer allocator.free(resolved_results_type_literal);
        const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, method.annotation_signature);
        defer allocator.free(annotations_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ordinal = {}, .signature = {s}, .params = {s}, .results = {s}", .{
            index,
            name_literal,
            method.ordinal,
            signature_literal,
            params_literal,
            results_literal,
        });
        try appendFmt(allocator, out, ", .parameter_count = {}, .param_field_count = {}, .result_field_count = {}", .{
            method.parameters.len,
            method.param_fields.len,
            method.result_fields.len,
        });
        if (method.params_type.len != 0) {
            try appendFmt(allocator, out, ", .params_type = {s}, .resolved_params_type = {s}", .{ params_type_literal, resolved_params_type_literal });
        }
        if (method.results_type.len != 0) {
            try appendFmt(allocator, out, ", .results_type = {s}, .resolved_results_type = {s}", .{ results_type_literal, resolved_results_type_literal });
        }
        if (method.annotation_signature.len != 0) {
            try appendFmt(allocator, out, ", .annotations = {s}", .{annotations_literal});
        }
        if (method.is_streaming) {
            try out.appendSlice(allocator, ", .streaming = true");
        }
        if (method.parameters.len != 0) {
            try out.appendSlice(allocator, ", .parameters = ");
            try appendParameterListLiteral(allocator, out, method.parameters);
        }
        if (method.param_fields.len != 0) {
            try out.appendSlice(allocator, ", .param_fields = ");
            try appendMethodFieldListLiteral(allocator, out, file, scope, method.parameters, method.param_fields);
        }
        if (method.result_fields.len != 0) {
            try out.appendSlice(allocator, ", .result_fields = ");
            try appendMethodFieldListLiteral(allocator, out, file, scope, method.parameters, method.result_fields);
        }
        try out.appendSlice(allocator, " }");
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.methodByName"(@"cpz.name": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".name, @"cpz.name")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByOrdinal"(@"cpz.ordinal": u16) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (@"cpz.method".ordinal == @"cpz.ordinal") return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByCallMethod"(@"cpz.callMethod": cpz.rpc.CallMethod) ?cpz.schema.InterfaceMethodMetadata {{
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (scope != null and scope.?.id != null) {
        try appendFmt(allocator, out,
            \\{s}    if (@"cpz.callMethod".interface_id != @This().@"cpz.type_id") return null;
            \\{s}    return @"cpz.methodByOrdinal"(@"cpz.callMethod".method_id);
            \\{s}}}
            \\
        , .{ indent, indent, indent });
    } else {
        try appendFmt(allocator, out,
            \\{s}    _ = @"cpz.callMethod";
            \\{s}    return null;
            \\{s}}}
            \\
        , .{ indent, indent, indent });
    }
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.methodByParamsType"(@"cpz.type": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".params_type, @"cpz.type")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByResultsType"(@"cpz.type": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".results_type, @"cpz.type")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByResolvedParamsType"(@"cpz.type": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".resolved_params_type, @"cpz.type")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByResolvedResultsType"(@"cpz.type": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".resolved_results_type, @"cpz.type")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByStreaming"(@"cpz.streaming": bool) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (@"cpz.method".streaming == @"cpz.streaming") return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByIndex"(@"cpz.index": usize) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    if (@"cpz.index" >= @"cpz.methods".len) return null;
        \\{s}    return @"cpz.methods"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.methodByParameter"(@"cpz.parameter": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| for (@"cpz.method".parameters) |@"cpz.methodParam"| if (std.mem.eql(u8, @"cpz.methodParam", @"cpz.parameter")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByParameterCount"(@"cpz.count": usize) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (@"cpz.method".parameter_count == @"cpz.count") return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByParamFieldCount"(@"cpz.count": usize) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (@"cpz.method".param_field_count == @"cpz.count") return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByResultFieldCount"(@"cpz.count": usize) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (@"cpz.method".result_field_count == @"cpz.count") return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".annotations, @"cpz.annotationFilter")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (methods.len != 0) try out.append(allocator, '\n');
}

pub fn emitParameterMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), parameters: []const []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try emitParameterConstants(allocator, out, "cpz.parameter", parameters, indent);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.parameterCount": usize = {};
        \\
    , .{ indent, parameters.len });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.parameters\": []const []const u8 = ", .{indent});
    try appendParameterListLiteral(allocator, out, parameters);
    try out.appendSlice(allocator, ";\n");
    try emitParameterLookupHelpers(allocator, out, "cpz.parameters", indent);
    if (parameters.len != 0) try out.append(allocator, '\n');
}

pub fn emitParameterLookupHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), metadata_name: []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    const metadata_ident = try zigStringLiteralAlloc(allocator, metadata_name);
    defer allocator.free(metadata_ident);
    const by_name = try std.fmt.allocPrint(allocator, "{s}.parameterByName", .{metadata_name});
    defer allocator.free(by_name);
    const by_name_ident = try zigStringLiteralAlloc(allocator, by_name);
    defer allocator.free(by_name_ident);
    const by_index = try std.fmt.allocPrint(allocator, "{s}.parameterByIndex", .{metadata_name});
    defer allocator.free(by_index);
    const by_index_ident = try zigStringLiteralAlloc(allocator, by_index);
    defer allocator.free(by_index_ident);
    try appendFmt(allocator, out,
        \\{s}pub fn @{s}(@"cpz.name": []const u8) ?[]const u8 {{
        \\{s}    for (@This().@{s}) |@"cpz.parameter"| if (std.mem.eql(u8, @"cpz.parameter", @"cpz.name")) return @"cpz.parameter";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.index": usize) ?[]const u8 {{
        \\{s}    if (@"cpz.index" >= @This().@{s}.len) return null;
        \\{s}    return @This().@{s}[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, by_name_ident, indent, metadata_ident, indent, indent, indent, by_index_ident, indent, metadata_ident, indent, metadata_ident, indent });
}

pub fn emitParameterConstants(allocator: std.mem.Allocator, out: *std.ArrayList(u8), prefix: []const u8, parameters: []const []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    for (parameters, 0..) |parameter, index| {
        const parameter_name = try zigIdentAlloc(allocator, parameter);
        defer allocator.free(parameter_name);
        const parameter_literal = try zigStringLiteralAlloc(allocator, parameter);
        defer allocator.free(parameter_literal);
        try appendFmt(allocator, out,
            \\{s}pub const @"{s}.{s}.index": usize = {};
            \\{s}pub const @"{s}.{s}.name": []const u8 = {s};
            \\
        , .{ indent, prefix, parameter_name, index, indent, prefix, parameter_name, parameter_literal });
    }
}

pub fn appendParameterListLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), parameters: []const []const u8) LayoutError!void {
    try out.appendSlice(allocator, "&[_][]const u8{");
    for (parameters, 0..) |parameter, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const literal = try zigStringLiteralAlloc(allocator, parameter);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "}");
}

pub fn appendMethodParameterMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), method_name: []const u8, parameters: []const []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    const method_parameter_prefix = try std.fmt.allocPrint(allocator, "cpz.method.{s}.parameter", .{method_name});
    defer allocator.free(method_parameter_prefix);
    try emitParameterConstants(allocator, out, method_parameter_prefix, parameters, indent);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.method.{s}.parameterCount": usize = {};
        \\
    , .{ indent, method_name, parameters.len });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.method.{s}.parameters\": []const []const u8 = ", .{ indent, method_name });
    try appendParameterListLiteral(allocator, out, parameters);
    try out.appendSlice(allocator, ";\n");
    const method_parameters_name = try std.fmt.allocPrint(allocator, "cpz.method.{s}.parameters", .{method_name});
    defer allocator.free(method_parameters_name);
    try emitParameterLookupHelpers(allocator, out, method_parameters_name, indent);
}

pub fn emitMethodScalarDefaultGet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, zig_type: []const u8, get_method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}    pub fn get(message_reader: *cpz.MessageReader) !{s} {{
        \\{s}        return (try message_reader.getRoot()).{s}(0, 0);
        \\{s}    }}
        \\
    , .{ indent, zig_type, indent, get_method, indent });
}

pub fn methodListDefaultItemsAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, default_literal: []const u8) LayoutError![]ConstListItem {
    return constListItemsFromInlineLiteralAlloc(allocator, resolveConstReferenceLiteral(file, scope, default_literal));
}

pub fn methodListDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, child: Type, default_literal: []const u8) LayoutError![]u8 {
    const resolved_literal = resolveConstReferenceLiteral(file, scope, default_literal);
    switch (resolveTypeScoped(file, scope, child)) {
        .void => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listVoidFlatBytesAlloc(allocator, file, scope, items);
        },
        .bool => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listBoolFlatBytesAlloc(allocator, file, scope, items);
        },
        .int8 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listSignedFlatBytesAlloc(i8, u8, allocator, file, scope, items, .byte);
        },
        .int16 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listSignedFlatBytesAlloc(i16, u16, allocator, file, scope, items, .two_bytes);
        },
        .int32 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listSignedFlatBytesAlloc(i32, u32, allocator, file, scope, items, .four_bytes);
        },
        .int64 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listSignedFlatBytesAlloc(i64, u64, allocator, file, scope, items, .eight_bytes);
        },
        .uint8 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listUnsignedFlatBytesAlloc(u8, allocator, file, scope, items, .byte);
        },
        .uint16 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listUnsignedFlatBytesAlloc(u16, allocator, file, scope, items, .two_bytes);
        },
        .uint32 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listUnsignedFlatBytesAlloc(u32, allocator, file, scope, items, .four_bytes);
        },
        .uint64 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listUnsignedFlatBytesAlloc(u64, allocator, file, scope, items, .eight_bytes);
        },
        .float32 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listFloatFlatBytesAlloc(f32, u32, allocator, file, scope, items, .four_bytes);
        },
        .float64 => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listFloatFlatBytesAlloc(f64, u64, allocator, file, scope, items, .eight_bytes);
        },
        .capability => {
            const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
            defer allocator.free(items);
            return listCapabilityFlatBytesAlloc(allocator, file, scope, items);
        },
        .any_pointer => return listOptionalAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, .any),
        .any_struct => return listOptionalAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, .struct_ptr),
        .any_list => return listOptionalAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, .list),
        .text => return listTextOrDataFieldDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, true),
        .data => return listTextOrDataFieldDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, false),
        .list => return listNestedFieldDefaultFlatBytesAlloc(allocator, file, scope, child, resolved_literal),
        .named => |type_name| {
            if (findEnum(file, type_name)) |enum_decl| {
                const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
                defer allocator.free(items);
                return listEnumFlatBytesAlloc(allocator, file, scope, enum_decl, items);
            }
            if (findInterface(file, type_name) != null) {
                const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
                defer allocator.free(items);
                return listCapabilityFlatBytesAlloc(allocator, file, scope, items);
            }
            if (findStructDirect(file, type_name) != null) return listStructFieldDefaultFlatBytesAlloc(allocator, file, scope, type_name, resolved_literal);
            return error.UnsupportedType;
        },
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .text => return listOptionalTextOrDataFieldDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, true),
            .data => return listOptionalTextOrDataFieldDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, false),
            .any_pointer => return listOptionalAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, .any),
            .any_struct => return listOptionalAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, .struct_ptr),
            .any_list => return listOptionalAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, resolved_literal, .list),
            .capability => {
                const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
                defer allocator.free(items);
                return listCapabilityFlatBytesAlloc(allocator, file, scope, items);
            },
            .named => |type_name| {
                if (findInterface(file, type_name) != null) {
                    const items = try methodListDefaultItemsAlloc(allocator, file, scope, default_literal);
                    defer allocator.free(items);
                    return listCapabilityFlatBytesAlloc(allocator, file, scope, items);
                }
                if (findStructDirect(file, type_name) != null) {
                    return listOptionalStructFieldDefaultFlatBytesAlloc(allocator, file, scope, type_name, resolved_literal);
                }
                return error.UnsupportedType;
            },
            else => return error.UnsupportedType,
        },
    }
}

pub fn methodStructDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, default_literal: []const u8) LayoutError!?[]u8 {
    return structFieldDefaultFlatBytesAlloc(allocator, file, scope, type_name, resolveConstReferenceLiteral(file, scope, default_literal));
}

pub fn methodAnyPointerDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, default_literal: []const u8, comptime want: AnyPointerDefaultKind) LayoutError![]u8 {
    const decl = findConstReference(file, scope, default_literal) orelse return error.UnsupportedType;
    const resolved_ty = switch (resolveConstDeclType(file, scope, decl)) {
        .optional => |child| methodOptionalDefaultChildOrNullForDecl(file, scope, decl, child.*, decl.literal) orelse return error.UnsupportedType,
        else => |resolved| resolved,
    };
    switch (resolved_ty) {
        .named => |type_name| {
            if (want == .list) return error.UnsupportedType;
            if (findStructDirect(file, type_name) == null) return error.UnsupportedType;
            var decl_scope_fields: [0]Field = .{};
            var decl_scope_storage: Struct = undefined;
            const decl_scope = constDeclResolutionScope(file, scope, decl, decl_scope_fields[0..], &decl_scope_storage);
            return (try structFieldDefaultFlatBytesAlloc(allocator, file, decl_scope, type_name, decl.literal)) orelse error.UnsupportedType;
        },
        .list => |child| {
            if (want == .struct_ptr) return error.UnsupportedType;
            var decl_scope_fields: [0]Field = .{};
            var decl_scope_storage: Struct = undefined;
            const decl_scope = constDeclResolutionScope(file, scope, decl, decl_scope_fields[0..], &decl_scope_storage);
            return methodListDefaultFlatBytesAlloc(allocator, file, decl_scope, child.*, decl.literal);
        },
        .any_pointer, .any_struct, .any_list => {
            if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), std.mem.trim(u8, default_literal, " \t\r\n"))) return error.UnsupportedType;
            const next_literal = std.mem.trim(u8, decl.literal, " \t\r\n");
            if (lastTopLevelDot(next_literal) == null) {
                if (constDeclOwnerName(file, decl)) |owner| {
                    const qualified_literal = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ owner, next_literal });
                    defer allocator.free(qualified_literal);
                    if (!std.mem.eql(u8, qualified_literal, std.mem.trim(u8, default_literal, " \t\r\n"))) {
                        return methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, qualified_literal, want);
                    }
                }
            }
            return methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, decl.literal, want);
        },
        else => return error.UnsupportedType,
    }
}

pub fn resolveConstDeclChildType(file: *const File, scope: ?*const Struct, decl: *const ConstDecl, child: Type) Type {
    if (constDeclOwnerName(file, decl)) |owner_name| {
        return resolveTypeInOwnerScope(file, owner_name, child);
    }
    return resolveTypeScoped(file, scope, child);
}

pub fn methodOptionalDefaultChildOrNull(file: *const File, scope: ?*const Struct, child: Type, default_literal: []const u8) ?Type {
    const resolved_literal = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, default_literal), " \t\r\n");
    if (std.mem.eql(u8, resolved_literal, "null")) return null;
    return resolveTypeScoped(file, scope, child);
}

pub fn methodOptionalDefaultChildOrNullForDecl(file: *const File, scope: ?*const Struct, decl: *const ConstDecl, child: Type, default_literal: []const u8) ?Type {
    const resolved_literal = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, default_literal), " \t\r\n");
    if (std.mem.eql(u8, resolved_literal, "null")) return null;
    return resolveConstDeclChildType(file, scope, decl, child);
}

pub fn methodDefaultIsNull(file: *const File, scope: ?*const Struct, default_literal: []const u8) bool {
    return std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, default_literal), " \t\r\n"), "null");
}

pub fn methodDefaultIsVoidOrNull(file: *const File, scope: ?*const Struct, default_literal: []const u8) bool {
    const raw = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, default_literal), " \t\r\n");
    return std.mem.eql(u8, raw, "null") or std.mem.eql(u8, raw, "void");
}

pub fn methodDefaultTypeAcceptsNullPointer(file: *const File, ty: Type) bool {
    return typeAcceptsNullPointerDefault(file, ty);
}

pub fn defaultExpressionIsNullPointer(file: *const File, scope: ?*const Struct, expression: []const u8) bool {
    return std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, expression), " \t\r\n"), "null");
}

pub fn defaultExpressionIsVoidPointer(file: *const File, scope: ?*const Struct, expression: []const u8, ty: Type) bool {
    return std.mem.eql(u8, std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, expression), " \t\r\n"), "void") and typeAcceptsVoidPointerDefault(file, ty);
}

pub fn nullPointerFlatBytesAlloc(allocator: std.mem.Allocator) LayoutError![]u8 {
    const segment_words: usize = 1;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    return flat;
}

pub fn emitMethodListDefaultList(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, element_size_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}    pub fn list(message_reader: *cpz.MessageReader) !cpz.ListReader {{
        \\{s}        return message_reader.getRootList({s});
        \\{s}    }}
        \\
    , .{ indent, indent, element_size_literal, indent });
}

pub fn emitMethodListDefaultScalarGet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, zig_type: []const u8, get_method: ?[]const u8) LayoutError!void {
    if (get_method) |method| {
        try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
            \\{s}        const @"cpz.list" = try @This().list(message_reader);
            \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
            \\{s}        return @"cpz.list".{s}(@"cpz.index");
            \\{s}    }}
            \\
        , .{ indent, zig_type, indent, indent, indent, method, indent });
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

pub fn emitMethodListDefaultCapabilityGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    try emitMethodListDefaultList(allocator, out, indent, ".pointer");
    try appendFmt(allocator, out,
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
        indent, indent, indent, indent, indent,
        indent, indent, indent, indent, indent,
        indent, indent, indent, indent, indent,
        indent, indent,
    });
}

pub fn emitMethodListDefaultOptionalBlobGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, accessor: []const u8) LayoutError!void {
    try emitMethodListDefaultList(allocator, out, indent, ".pointer");
    try appendFmt(allocator, out,
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
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) ![]const u8 {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).{s}();
        \\{s}    }}
        \\
        \\{s}    pub fn getOrNull(message_reader: *cpz.MessageReader, @"cpz.index": usize) !?[]const u8 {{
        \\{s}        const @"cpz.pointer" = try @This().pointer(message_reader, @"cpz.index");
        \\{s}        if (@"cpz.pointer".isNull()) return null;
        \\{s}        return try @"cpz.pointer".{s}();
        \\{s}    }}
        \\
        \\{s}    pub fn getByteCount(message_reader: *cpz.MessageReader, @"cpz.index": usize) !usize {{
        \\{s}        return (try @This().get(message_reader, @"cpz.index")).len;
        \\{s}    }}
        \\
    , .{
        indent,   indent,   indent, indent, indent,
        indent,   indent,   indent, indent, indent,
        accessor, indent,   indent, indent, indent,
        indent,   accessor, indent, indent, indent,
        indent,
    });
}

pub fn emitMethodListDefaultOptionalStructGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, indent: []const u8, type_name: []const u8) LayoutError!void {
    const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
    defer allocator.free(zig_type);
    try emitMethodListDefaultList(allocator, out, indent, ".pointer");
    try appendFmt(allocator, out,
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
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
        \\{s}        return {s}.fromReader(try (try @This().pointer(message_reader, @"cpz.index")).getStruct(null));
        \\{s}    }}
        \\
        \\{s}    pub fn getOrNull(message_reader: *cpz.MessageReader, @"cpz.index": usize) !?{s} {{
        \\{s}        const @"cpz.pointer" = try @This().pointer(message_reader, @"cpz.index");
        \\{s}        if (@"cpz.pointer".isNull()) return null;
        \\{s}        return {s}.fromReader(try @"cpz.pointer".getStruct(null));
        \\{s}    }}
        \\
    , .{
        indent,   indent, indent,   indent, indent,
        indent,   indent, indent,   indent, indent,
        indent,   indent, indent,   indent, indent,
        zig_type, indent, zig_type, indent, indent,
        zig_type, indent, indent,   indent, zig_type,
        indent,
    });
}

pub fn emitMethodListDefaultOptionalAnyPointerCommonGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    try emitMethodListDefaultList(allocator, out, indent, ".pointer");
    try appendFmt(allocator, out,
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
    , .{
        indent, indent, indent, indent, indent,
        indent, indent, indent, indent, indent,
        indent, indent, indent, indent,
    });
}

pub fn emitMethodListDefaultOptionalAnyPointerGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    try emitMethodListDefaultOptionalAnyPointerCommonGetters(allocator, out, indent);
    try appendFmt(allocator, out,
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}        return @This().pointer(message_reader, @"cpz.index");
        \\{s}    }}
        \\
        \\{s}    pub fn getOrNull(message_reader: *cpz.MessageReader, @"cpz.index": usize) !?cpz.PointerReader {{
        \\{s}        const @"cpz.pointer" = try @This().pointer(message_reader, @"cpz.index");
        \\{s}        if (@"cpz.pointer".isNull()) return null;
        \\{s}        return @"cpz.pointer";
        \\{s}    }}
        \\
        \\{s}    pub fn asStruct(message_reader: *cpz.MessageReader, @"cpz.index": usize) !cpz.StructReader {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).getStruct(null);
        \\{s}    }}
        \\
        \\{s}    pub fn asList(message_reader: *cpz.MessageReader, @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).getList(@"cpz.expected");
        \\{s}    }}
        \\
    , .{
        indent, indent, indent,
        indent, indent, indent,
        indent, indent, indent,
        indent, indent, indent,
        indent, indent,
    });
}

pub fn emitMethodListDefaultOptionalAnyStructGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    try emitMethodListDefaultOptionalAnyPointerCommonGetters(allocator, out, indent);
    try appendFmt(allocator, out,
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !cpz.StructReader {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).getStruct(null);
        \\{s}    }}
        \\
        \\{s}    pub fn getOrNull(message_reader: *cpz.MessageReader, @"cpz.index": usize) !?cpz.StructReader {{
        \\{s}        const @"cpz.pointer" = try @This().pointer(message_reader, @"cpz.index");
        \\{s}        if (@"cpz.pointer".isNull()) return null;
        \\{s}        return try @"cpz.pointer".getStruct(null);
        \\{s}    }}
        \\
    , .{
        indent, indent, indent,
        indent, indent, indent,
        indent, indent,
    });
}

pub fn emitMethodListDefaultOptionalAnyListGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    try emitMethodListDefaultOptionalAnyPointerCommonGetters(allocator, out, indent);
    try appendFmt(allocator, out,
        \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\{s}        return (try @This().pointer(message_reader, @"cpz.index")).getList(@"cpz.expected");
        \\{s}    }}
        \\
        \\{s}    pub fn getOrNull(message_reader: *cpz.MessageReader, @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !?cpz.ListReader {{
        \\{s}        const @"cpz.pointer" = try @This().pointer(message_reader, @"cpz.index");
        \\{s}        if (@"cpz.pointer".isNull()) return null;
        \\{s}        return try @"cpz.pointer".getList(@"cpz.expected");
        \\{s}    }}
        \\
    , .{
        indent, indent, indent,
        indent, indent, indent,
        indent, indent,
    });
}

pub fn emitMethodListDefaultGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, child: Type) LayoutError!void {
    switch (resolveTypeScoped(file, scope, child)) {
        .void => {
            try emitMethodListDefaultList(allocator, out, indent, ".void");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "void", null);
        },
        .bool => {
            try emitMethodListDefaultList(allocator, out, indent, ".bit");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "bool", "getBool");
        },
        .int8 => {
            try emitMethodListDefaultList(allocator, out, indent, ".byte");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "i8", "getInt8");
        },
        .int16 => {
            try emitMethodListDefaultList(allocator, out, indent, ".two_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "i16", "getInt16");
        },
        .int32 => {
            try emitMethodListDefaultList(allocator, out, indent, ".four_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "i32", "getInt32");
        },
        .int64 => {
            try emitMethodListDefaultList(allocator, out, indent, ".eight_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "i64", "getInt64");
        },
        .uint8 => {
            try emitMethodListDefaultList(allocator, out, indent, ".byte");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "u8", "getUInt8");
        },
        .uint16 => {
            try emitMethodListDefaultList(allocator, out, indent, ".two_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "u16", "getUInt16");
        },
        .uint32 => {
            try emitMethodListDefaultList(allocator, out, indent, ".four_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "u32", "getUInt32");
        },
        .uint64 => {
            try emitMethodListDefaultList(allocator, out, indent, ".eight_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "u64", "getUInt64");
        },
        .float32 => {
            try emitMethodListDefaultList(allocator, out, indent, ".four_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "f32", "getFloat32");
        },
        .float64 => {
            try emitMethodListDefaultList(allocator, out, indent, ".eight_bytes");
            try emitMethodListDefaultScalarGet(allocator, out, indent, "f64", "getFloat64");
        },
        .capability => try emitMethodListDefaultCapabilityGetters(allocator, out, indent),
        .any_pointer => try emitMethodListDefaultOptionalAnyPointerGetters(allocator, out, indent),
        .any_struct => try emitMethodListDefaultOptionalAnyStructGetters(allocator, out, indent),
        .any_list => try emitMethodListDefaultOptionalAnyListGetters(allocator, out, indent),
        .text => {
            try emitMethodListDefaultList(allocator, out, indent, ".pointer");
            try appendFmt(allocator, out,
                \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) ![]const u8 {{
                \\{s}        const @"cpz.list" = try @This().list(message_reader);
                \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
                \\{s}        return (try @"cpz.list".getPointerElement(@"cpz.index")).{s}();
                \\{s}    }}
                \\
                \\{s}    pub fn getByteCount(message_reader: *cpz.MessageReader, @"cpz.index": usize) !usize {{
                \\{s}        return (try @This().get(message_reader, @"cpz.index")).len;
                \\{s}    }}
                \\
            , .{ indent, indent, indent, indent, "getText", indent, indent, indent, indent });
        },
        .data => {
            try emitMethodListDefaultList(allocator, out, indent, ".pointer");
            try appendFmt(allocator, out,
                \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) ![]const u8 {{
                \\{s}        const @"cpz.list" = try @This().list(message_reader);
                \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
                \\{s}        return (try @"cpz.list".getPointerElement(@"cpz.index")).{s}();
                \\{s}    }}
                \\
                \\{s}    pub fn getByteCount(message_reader: *cpz.MessageReader, @"cpz.index": usize) !usize {{
                \\{s}        return (try @This().get(message_reader, @"cpz.index")).len;
                \\{s}    }}
                \\
            , .{ indent, indent, indent, indent, "getData", indent, indent, indent, indent });
        },
        .list => {
            try emitMethodListDefaultList(allocator, out, indent, ".pointer");
            try appendFmt(allocator, out,
                \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
                \\{s}        const @"cpz.list" = try @This().list(message_reader);
                \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
                \\{s}        return (try @"cpz.list".getPointerElement(@"cpz.index")).getList(@"cpz.expected");
                \\{s}    }}
                \\
            , .{ indent, indent, indent, indent, indent });
        },
        .named => |type_name| {
            if (findEnum(file, type_name) != null) {
                try emitMethodListDefaultList(allocator, out, indent, ".two_bytes");
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}    pub fn getRaw(message_reader: *cpz.MessageReader, @"cpz.index": usize) !u16 {{
                    \\{s}        const @"cpz.list" = try @This().list(message_reader);
                    \\{s}        if (!@"cpz.list".hasIndex(@"cpz.index")) return error.PointerOutOfBounds;
                    \\{s}        return @"cpz.list".getUInt16(@"cpz.index");
                    \\{s}    }}
                    \\
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
                    \\{s}        return std.enums.fromInt({s}, try @This().getRaw(message_reader, @"cpz.index")) orelse error.InvalidEnumValue;
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent, indent, indent, indent, zig_type, indent, zig_type, indent });
            } else if (findStructDirect(file, type_name) != null) {
                try emitMethodListDefaultList(allocator, out, indent, ".composite");
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.index": usize) !{s} {{
                    \\{s}        return {s}.fromReader(try (try @This().list(message_reader)).getStructElement(@"cpz.index"));
                    \\{s}    }}
                    \\
                , .{ indent, zig_type, indent, zig_type, indent });
            } else if (findInterface(file, type_name) != null) {
                try emitMethodListDefaultCapabilityGetters(allocator, out, indent);
            }
        },
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .text => try emitMethodListDefaultOptionalBlobGetters(allocator, out, indent, "getText"),
            .data => try emitMethodListDefaultOptionalBlobGetters(allocator, out, indent, "getData"),
            .any_pointer => try emitMethodListDefaultOptionalAnyPointerGetters(allocator, out, indent),
            .any_struct => try emitMethodListDefaultOptionalAnyStructGetters(allocator, out, indent),
            .any_list => try emitMethodListDefaultOptionalAnyListGetters(allocator, out, indent),
            .capability => try emitMethodListDefaultCapabilityGetters(allocator, out, indent),
            .named => |type_name| {
                if (findInterface(file, type_name) != null) {
                    try emitMethodListDefaultCapabilityGetters(allocator, out, indent);
                } else if (findStructDirect(file, type_name) != null) {
                    try emitMethodListDefaultOptionalStructGetters(allocator, out, file, indent, type_name);
                }
            },
            else => {},
        },
    }
}

pub fn emitMethodDefaultReaderValueGet(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_literal: []const u8, zig_type: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn get(self: *@This()) !{s} {{
        \\{s}            return @{s}.get(&self.reader);
        \\{s}        }}
        \\
    , .{ indent, zig_type, indent, container_literal, indent });
}

pub fn emitMethodDefaultReaderListGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, container_literal: []const u8, child: Type) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn list(self: *@This()) !cpz.ListReader {{
        \\{s}            return @{s}.list(&self.reader);
        \\{s}        }}
        \\
    , .{ indent, indent, container_literal, indent });
    switch (resolveTypeScoped(file, scope, child)) {
        .void => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !void {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .bool => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !bool {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .int8 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !i8 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .int16 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !i16 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .int32 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !i32 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .int64 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !i64 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .uint8 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u8 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .uint16 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u16 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .uint32 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u32 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .uint64 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u64 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .float32 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !f32 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .float64 => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !f64 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .text, .data => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) ![]const u8 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
            \\{s}        pub fn getByteCount(self: *@This(), @"cpz.index": usize) !usize {{
            \\{s}            return @{s}.getByteCount(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent, indent, indent, container_literal, indent }),
        .list => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index", @"cpz.expected");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .capability => try appendFmt(allocator, out,
            \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
            \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
            \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
            \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
            \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
            \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
            \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
            \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
            \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u32 {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.index");
            \\{s}        }}
            \\
        , .{
            indent, indent, container_literal, indent,
            indent, indent, container_literal, indent,
            indent, indent, container_literal, indent,
            indent, indent, container_literal, indent,
            indent, indent, container_literal, indent,
        }),
        .named => |type_name| {
            if (findEnum(file, type_name) != null) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}        pub fn getRaw(self: *@This(), @"cpz.index": usize) !u16 {{
                    \\{s}            return @{s}.getRaw(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                    \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !{s} {{
                    \\{s}            return @{s}.get(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                , .{ indent, indent, container_literal, indent, indent, zig_type, indent, container_literal, indent });
            } else if (findStructDirect(file, type_name) != null) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !{s} {{
                    \\{s}            return @{s}.get(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                , .{ indent, zig_type, indent, container_literal, indent });
            } else if (findInterface(file, type_name) != null) {
                try appendFmt(allocator, out,
                    \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
                    \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                    \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
                    \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                    \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
                    \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                    \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
                    \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                    \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u32 {{
                    \\{s}            return @{s}.get(&self.reader, @"cpz.index");
                    \\{s}        }}
                    \\
                , .{
                    indent, indent, container_literal, indent,
                    indent, indent, container_literal, indent,
                    indent, indent, container_literal, indent,
                    indent, indent, container_literal, indent,
                    indent, indent, container_literal, indent,
                });
            }
        },
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .text => try emitMethodDefaultReaderOptionalBlobElementGetters(allocator, out, indent, container_literal),
            .data => try emitMethodDefaultReaderOptionalBlobElementGetters(allocator, out, indent, container_literal),
            .any_pointer => try emitMethodDefaultReaderOptionalAnyPointerElementGetters(allocator, out, indent, container_literal),
            .any_struct => try emitMethodDefaultReaderOptionalAnyStructElementGetters(allocator, out, indent, container_literal),
            .any_list => try emitMethodDefaultReaderOptionalAnyListElementGetters(allocator, out, indent, container_literal),
            .capability => try emitMethodDefaultReaderCapabilityElementGetters(allocator, out, indent, container_literal),
            .named => |type_name| {
                if (findInterface(file, type_name) != null) {
                    try emitMethodDefaultReaderCapabilityElementGetters(allocator, out, indent, container_literal);
                } else if (findStructDirect(file, type_name) != null) {
                    try emitMethodDefaultReaderOptionalStructElementGetters(allocator, out, file, indent, container_literal, type_name);
                }
            },
            else => {},
        },
        else => {},
    }
}

pub fn emitMethodDefaultReaderOptionalBlobElementGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
        \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) ![]const u8 {{
        \\{s}            return @{s}.get(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn getOrNull(self: *@This(), @"cpz.index": usize) !?[]const u8 {{
        \\{s}            return @{s}.getOrNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn getByteCount(self: *@This(), @"cpz.index": usize) !usize {{
        \\{s}            return @{s}.getByteCount(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
    , .{
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
    });
}

pub fn emitMethodDefaultReaderOptionalAnyPointerElementGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
        \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
        \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.get(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn getOrNull(self: *@This(), @"cpz.index": usize) !?cpz.PointerReader {{
        \\{s}            return @{s}.getOrNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn asStruct(self: *@This(), @"cpz.index": usize) !cpz.StructReader {{
        \\{s}            return @{s}.asStruct(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn asList(self: *@This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\{s}            return @{s}.asList(&self.reader, @"cpz.index", @"cpz.expected");
        \\{s}        }}
        \\
    , .{
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
    });
}

pub fn emitMethodDefaultReaderOptionalAnyStructElementGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
        \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
        \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !cpz.StructReader {{
        \\{s}            return @{s}.get(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn getOrNull(self: *@This(), @"cpz.index": usize) !?cpz.StructReader {{
        \\{s}            return @{s}.getOrNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
    , .{
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
    });
}

pub fn emitMethodDefaultReaderOptionalAnyListElementGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
        \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
        \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn get(self: *@This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\{s}            return @{s}.get(&self.reader, @"cpz.index", @"cpz.expected");
        \\{s}        }}
        \\
        \\{s}        pub fn getOrNull(self: *@This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !?cpz.ListReader {{
        \\{s}            return @{s}.getOrNull(&self.reader, @"cpz.index", @"cpz.expected");
        \\{s}        }}
        \\
    , .{
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
    });
}

pub fn emitMethodDefaultReaderOptionalStructElementGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, indent: []const u8, container_literal: []const u8, type_name: []const u8) LayoutError!void {
    const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
    defer allocator.free(zig_type);
    try appendFmt(allocator, out,
        \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
        \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
        \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !{s} {{
        \\{s}            return @{s}.get(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn getOrNull(self: *@This(), @"cpz.index": usize) !?{s} {{
        \\{s}            return @{s}.getOrNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
    , .{
        indent,            indent,   container_literal, indent,
        indent,            indent,   container_literal, indent,
        indent,            indent,   container_literal, indent,
        indent,            indent,   container_literal, indent,
        indent,            zig_type, indent,            container_literal,
        indent,            indent,   zig_type,          indent,
        container_literal, indent,
    });
}

pub fn emitMethodDefaultReaderCapabilityElementGetters(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_literal: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}        pub fn pointer(self: *@This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\{s}            return @{s}.pointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementIsNull(self: *@This(), @"cpz.index": usize) !bool {{
        \\{s}            return @{s}.elementIsNull(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn elementPointerKind(self: *@This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\{s}            return @{s}.elementPointerKind(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn rawPointer(self: *@This(), @"cpz.index": usize) !cpz.Word {{
        \\{s}            return @{s}.rawPointer(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
        \\{s}        pub fn get(self: *@This(), @"cpz.index": usize) !u32 {{
        \\{s}            return @{s}.get(&self.reader, @"cpz.index");
        \\{s}        }}
        \\
    , .{
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
        indent, indent, container_literal, indent,
    });
}

pub fn emitMethodDefaultReaderWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, container_literal: []const u8, resolved_ty: Type, is_null_default: bool) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}    pub const Reader = struct {{
        \\{s}        reader: cpz.MessageReader,
        \\
        \\{s}        pub fn init(@"cpz.options": cpz.ReaderOptions) @This() {{
        \\{s}            return .{{ .reader = @{s}.reader(@"cpz.options") }};
        \\{s}        }}
        \\
        \\{s}        pub fn asReader(self: *@This()) *cpz.MessageReader {{
        \\{s}            return &self.reader;
        \\{s}        }}
        \\
    , .{ indent, indent, indent, indent, container_literal, indent, indent, indent, indent });
    if (is_null_default) {
        try appendFmt(allocator, out,
            \\{s}        pub fn pointer(self: *@This()) !cpz.PointerReader {{
            \\{s}            return @{s}.pointer(&self.reader);
            \\{s}        }}
            \\
            \\{s}        pub fn isNull(self: *@This()) !bool {{
            \\{s}            return @{s}.isNull(&self.reader);
            \\{s}        }}
            \\
            \\{s}        pub fn rawPointer(self: *@This()) !cpz.Word {{
            \\{s}            return @{s}.rawPointer(&self.reader);
            \\{s}        }}
            \\
            \\{s}        pub fn pointerKind(self: *@This()) !?cpz.wire.PointerType {{
            \\{s}            return @{s}.pointerKind(&self.reader);
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent, indent, indent, container_literal, indent, indent, indent, container_literal, indent, indent, indent, container_literal, indent });
    } else switch (resolved_ty) {
        .void => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "void"),
        .bool => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "bool"),
        .int8 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "i8"),
        .int16 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "i16"),
        .int32 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "i32"),
        .int64 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "i64"),
        .uint8 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "u8"),
        .uint16 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "u16"),
        .uint32 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "u32"),
        .uint64 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "u64"),
        .float32 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "f32"),
        .float64 => try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "f64"),
        .text, .data => {
            try emitMethodDefaultReaderValueGet(allocator, out, indent, container_literal, "[]const u8");
            try appendFmt(allocator, out,
                \\{s}        pub fn getByteCount(self: *@This()) !usize {{
                \\{s}            return (try self.get()).len;
                \\{s}        }}
                \\
            , .{ indent, indent, indent });
        },
        .named => |type_name| {
            if (findEnum(file, type_name) != null) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}        pub fn getRaw(self: *@This()) !u16 {{
                    \\{s}            return @{s}.getRaw(&self.reader);
                    \\{s}        }}
                    \\
                    \\{s}        pub fn get(self: *@This()) !{s} {{
                    \\{s}            return @{s}.get(&self.reader);
                    \\{s}        }}
                    \\
                , .{ indent, indent, container_literal, indent, indent, zig_type, indent, container_literal, indent });
            } else if (findStructDirect(file, type_name) != null) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}        pub fn root(self: *@This()) !cpz.StructReader {{
                    \\{s}            return @{s}.root(&self.reader);
                    \\{s}        }}
                    \\
                    \\{s}        pub fn get(self: *@This()) !{s} {{
                    \\{s}            return @{s}.get(&self.reader);
                    \\{s}        }}
                    \\
                , .{ indent, indent, container_literal, indent, indent, zig_type, indent, container_literal, indent });
            }
        },
        .list => |child| try emitMethodDefaultReaderListGetters(allocator, out, file, scope, indent, container_literal, child.*),
        .any_pointer => try appendFmt(allocator, out,
            \\{s}        pub fn pointer(self: *@This()) !cpz.PointerReader {{
            \\{s}            return @{s}.pointer(&self.reader);
            \\{s}        }}
            \\
            \\{s}        pub fn get(self: *@This()) !cpz.PointerReader {{
            \\{s}            return @{s}.get(&self.reader);
            \\{s}        }}
            \\
            \\{s}        pub fn asStruct(self: *@This()) !cpz.StructReader {{
            \\{s}            return @{s}.asStruct(&self.reader);
            \\{s}        }}
            \\
            \\{s}        pub fn asList(self: *@This(), @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}            return @{s}.asList(&self.reader, @"cpz.expected");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent, indent, indent, container_literal, indent, indent, indent, container_literal, indent, indent, indent, container_literal, indent }),
        .any_struct => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This()) !cpz.StructReader {{
            \\{s}            return @{s}.get(&self.reader);
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        .any_list => try appendFmt(allocator, out,
            \\{s}        pub fn get(self: *@This(), @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}            return @{s}.get(&self.reader, @"cpz.expected");
            \\{s}        }}
            \\
        , .{ indent, indent, container_literal, indent }),
        else => {},
    }
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
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
}

pub fn emitMethodFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, method_name: []const u8, kind: []const u8, field: MethodField, indent: []const u8) LayoutError!void {
    const default_literal = field.default_literal orelse return;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    const container_name = try std.fmt.allocPrint(allocator, "cpz.method.{s}.{s}.field.{s}.defaultFlat", .{ method_name, kind, field_name });
    defer allocator.free(container_name);
    const container_literal = try zigStringLiteralAlloc(allocator, container_name);
    defer allocator.free(container_literal);
    var ty = try parseTypeArgAlloc(allocator, field.ty);
    defer ty.deinit(allocator);
    const resolved_ty = switch (resolveTypeScoped(file, scope, ty)) {
        .optional => |child| methodOptionalDefaultChildOrNull(file, scope, child.*, default_literal) orelse child.*,
        else => |resolved| resolved,
    };
    const is_null_pointer_default = methodDefaultIsVoidOrNull(file, scope, default_literal) and methodDefaultTypeAcceptsNullPointer(file, resolved_ty);
    const flat = if (is_null_pointer_default) try nullPointerFlatBytesAlloc(allocator) else switch (resolved_ty) {
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => try scalarConstFlatBytesAlloc(allocator, file, scope, resolved_ty, default_literal),
        .named => |type_name| blk: {
            if (findEnum(file, type_name) != null) {
                break :blk try scalarConstFlatBytesAlloc(allocator, file, scope, resolved_ty, default_literal);
            }
            if (findStructDirect(file, type_name) != null) {
                break :blk (try methodStructDefaultFlatBytesAlloc(allocator, file, scope, type_name, default_literal)) orelse return;
            }
            return;
        },
        .text => blk: {
            const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, default_literal, true)) orelse try inlineQuotedStringBytesAlloc(allocator, default_literal);
            defer allocator.free(bytes);
            break :blk try blobFieldDefaultFlatBytesAlloc(allocator, bytes, true);
        },
        .data => blk: {
            const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, default_literal, false)) orelse try inlineDataBytesAlloc(allocator, default_literal);
            defer allocator.free(bytes);
            break :blk try blobFieldDefaultFlatBytesAlloc(allocator, bytes, false);
        },
        .list => |child| methodListDefaultFlatBytesAlloc(allocator, file, scope, child.*, default_literal) catch |err| switch (err) {
            error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
            else => return err,
        },
        .any_pointer => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, default_literal, .any) catch |err| switch (err) {
            error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
            else => return err,
        },
        .any_struct => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, default_literal, .struct_ptr) catch |err| switch (err) {
            error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
            else => return err,
        },
        .any_list => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, scope, default_literal, .list) catch |err| switch (err) {
            error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
            else => return err,
        },
        else => return,
    };
    defer allocator.free(flat);
    const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
    defer allocator.free(flat_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @{s} = struct {{
        \\{s}    pub const flatBytes: []const u8 = {s};
        \\{s}    pub const segment0: []const u8 = flatBytes[8..];
        \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{segment0}};
        \\
        \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
        \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
        \\{s}    }}
        \\
    , .{ indent, container_literal, indent, flat_literal, indent, indent, indent, indent, indent });
    if (is_null_pointer_default) {
        try appendFmt(allocator, out,
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
        , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    } else switch (resolved_ty) {
        .void => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !void {{
            \\{s}        _ = try message_reader.getRoot();
            \\{s}        return {{}};
            \\{s}    }}
            \\
        , .{ indent, indent, indent, indent }),
        .bool => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !bool {{
            \\{s}        return (try message_reader.getRoot()).getBool(0, false);
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .int8 => try emitMethodScalarDefaultGet(allocator, out, indent, "i8", "getInt8"),
        .int16 => try emitMethodScalarDefaultGet(allocator, out, indent, "i16", "getInt16"),
        .int32 => try emitMethodScalarDefaultGet(allocator, out, indent, "i32", "getInt32"),
        .int64 => try emitMethodScalarDefaultGet(allocator, out, indent, "i64", "getInt64"),
        .uint8 => try emitMethodScalarDefaultGet(allocator, out, indent, "u8", "getUInt8"),
        .uint16 => try emitMethodScalarDefaultGet(allocator, out, indent, "u16", "getUInt16"),
        .uint32 => try emitMethodScalarDefaultGet(allocator, out, indent, "u32", "getUInt32"),
        .uint64 => try emitMethodScalarDefaultGet(allocator, out, indent, "u64", "getUInt64"),
        .float32 => try emitMethodScalarDefaultGet(allocator, out, indent, "f32", "getFloat32"),
        .float64 => try emitMethodScalarDefaultGet(allocator, out, indent, "f64", "getFloat64"),
        .text => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) ![]const u8 {{
            \\{s}        return message_reader.getRootText();
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .data => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) ![]const u8 {{
            \\{s}        return message_reader.getRootData();
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .named => |type_name| {
            if (findEnum(file, type_name) != null) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}    pub fn getRaw(message_reader: *cpz.MessageReader) !u16 {{
                    \\{s}        return (try message_reader.getRoot()).getUInt16(0, 0);
                    \\{s}    }}
                    \\
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader) !{s} {{
                    \\{s}        return std.enums.fromInt({s}, try @This().getRaw(message_reader)) orelse error.InvalidEnumValue;
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent, indent, zig_type, indent, zig_type, indent });
            } else if (findStructDirect(file, type_name) != null) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}    pub fn root(message_reader: *cpz.MessageReader) !cpz.StructReader {{
                    \\{s}        return message_reader.getRoot();
                    \\{s}    }}
                    \\
                    \\{s}    pub fn get(message_reader: *cpz.MessageReader) !{s} {{
                    \\{s}        return {s}.fromReader(try @This().root(message_reader));
                    \\{s}    }}
                    \\
                , .{ indent, indent, indent, indent, zig_type, indent, zig_type, indent });
            }
        },
        .list => |child| try emitMethodListDefaultGetters(allocator, out, file, scope, indent, child.*),
        .any_pointer => try appendFmt(allocator, out,
            \\{s}    pub fn pointer(message_reader: *cpz.MessageReader) !cpz.PointerReader {{
            \\{s}        return message_reader.getRootPointer();
            \\{s}    }}
            \\
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
        , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent }),
        .any_struct => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !cpz.StructReader {{
            \\{s}        return (try message_reader.getRootPointer()).getStruct(null);
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .any_list => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}        return (try message_reader.getRootPointer()).getList(@"cpz.expected");
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        else => {},
    }
    try emitMethodDefaultReaderWrapper(allocator, out, file, scope, indent, container_literal, resolved_ty, is_null_pointer_default);
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

pub fn appendMethodFieldMetadata(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    file: *const File,
    scope: ?*const InterfaceDecl,
    method_name: []const u8,
    method_parameters: []const []const u8,
    kind: []const u8,
    fields: []const MethodField,
    indent: []const u8,
) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.method.{s}.{s}.fieldCount": usize = {};
        \\
    , .{ indent, method_name, kind, fields.len });
    for (fields) |field| {
        const field_name = try zigIdentAlloc(allocator, field.name);
        defer allocator.free(field_name);
        const name_literal = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(name_literal);
        const type_literal = try zigStringLiteralAlloc(allocator, field.ty);
        defer allocator.free(type_literal);
        const resolved_type_name = try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method_parameters, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.index": usize = {};
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.name": []const u8 = {s};
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.metadata": cpz.schema.MethodField = @This().@"cpz.method.{s}.{s}.fields"[{}];
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.type": []const u8 = {s};
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.resolvedType": []const u8 = {s};
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.default": ?[]const u8 = 
        , .{ indent, method_name, kind, field_name, field.index, indent, method_name, kind, field_name, name_literal, indent, method_name, kind, field_name, method_name, kind, field.index, indent, method_name, kind, field_name, type_literal, indent, method_name, kind, field_name, resolved_type_literal, indent, method_name, kind, field_name });
        if (field.default_literal) |default_raw| {
            const default_literal = try zigSchemaSyntaxLiteralAlloc(allocator, default_raw);
            defer allocator.free(default_literal);
            try appendFmt(allocator, out, "{s};\n", .{default_literal});
        } else {
            try out.appendSlice(allocator, "null;\n");
        }
        const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.defaultIsHexData": bool = {};
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.hasExplicitDefault": bool = {};
            \\{s}pub const @"cpz.method.{s}.{s}.field.{s}.annotations": []const u8 = {s};
            \\
        , .{ indent, method_name, kind, field_name, field.default_is_hex_data, indent, method_name, kind, field_name, field.has_explicit_default, indent, method_name, kind, field_name, annotations_literal });
    }
    try appendFmt(allocator, out, "{s}pub const @\"cpz.method.{s}.{s}.fields\": []const cpz.schema.MethodField = &[_]cpz.schema.MethodField{{", .{ indent, method_name, kind });
    for (fields, 0..) |field, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(name_literal);
        const type_literal = try zigStringLiteralAlloc(allocator, field.ty);
        defer allocator.free(type_literal);
        const resolved_type_name = try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method_parameters, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        if (field.default_literal) |default_raw| {
            const default_literal = try zigSchemaSyntaxLiteralAlloc(allocator, default_raw);
            defer allocator.free(default_literal);
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}, .default_literal = {s}, .default_is_hex_data = {}, .has_explicit_default = {}, .annotations = {s} }}", .{ field.index, name_literal, type_literal, resolved_type_literal, default_literal, field.default_is_hex_data, field.has_explicit_default, annotations_literal });
        } else if (field.annotations.len != 0) {
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}, .has_explicit_default = {}, .annotations = {s} }}", .{ field.index, name_literal, type_literal, resolved_type_literal, field.has_explicit_default, annotations_literal });
        } else {
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}, .has_explicit_default = {} }}", .{ field.index, name_literal, type_literal, resolved_type_literal, field.has_explicit_default });
        }
    }
    try out.appendSlice(allocator, "};\n");
    const metadata_name = try std.fmt.allocPrint(allocator, "cpz.method.{s}.{s}.fields", .{ method_name, kind });
    defer allocator.free(metadata_name);
    try emitMethodFieldLookupHelpers(allocator, out, metadata_name, indent);
}

pub fn appendMethodFieldListLiteral(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    file: *const File,
    scope: ?*const InterfaceDecl,
    method_parameters: []const []const u8,
    fields: []const MethodField,
) LayoutError!void {
    try out.appendSlice(allocator, "&[_]cpz.schema.MethodField{");
    for (fields, 0..) |field, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(name_literal);
        const type_literal = try zigStringLiteralAlloc(allocator, field.ty);
        defer allocator.free(type_literal);
        const resolved_type_name = try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method_parameters, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        if (field.default_literal) |default_raw| {
            const default_literal = try zigSchemaSyntaxLiteralAlloc(allocator, default_raw);
            defer allocator.free(default_literal);
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}, .default_literal = {s}, .default_is_hex_data = {}, .has_explicit_default = {}, .annotations = {s} }}", .{ field.index, name_literal, type_literal, resolved_type_literal, default_literal, field.default_is_hex_data, field.has_explicit_default, annotations_literal });
        } else if (field.annotations.len != 0) {
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}, .has_explicit_default = {}, .annotations = {s} }}", .{ field.index, name_literal, type_literal, resolved_type_literal, field.has_explicit_default, annotations_literal });
        } else {
            try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}, .has_explicit_default = {} }}", .{ field.index, name_literal, type_literal, resolved_type_literal, field.has_explicit_default });
        }
    }
    try out.appendSlice(allocator, "}");
}

pub fn emitMethodFieldLookupHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), metadata_name: []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    const metadata_ident = try zigStringLiteralAlloc(allocator, metadata_name);
    defer allocator.free(metadata_ident);
    const by_name = try std.fmt.allocPrint(allocator, "{s}.fieldByName", .{metadata_name});
    defer allocator.free(by_name);
    const by_name_ident = try zigStringLiteralAlloc(allocator, by_name);
    defer allocator.free(by_name_ident);
    const by_type = try std.fmt.allocPrint(allocator, "{s}.fieldByType", .{metadata_name});
    defer allocator.free(by_type);
    const by_type_ident = try zigStringLiteralAlloc(allocator, by_type);
    defer allocator.free(by_type_ident);
    const by_resolved_type = try std.fmt.allocPrint(allocator, "{s}.fieldByResolvedType", .{metadata_name});
    defer allocator.free(by_resolved_type);
    const by_resolved_type_ident = try zigStringLiteralAlloc(allocator, by_resolved_type);
    defer allocator.free(by_resolved_type_ident);
    const by_default = try std.fmt.allocPrint(allocator, "{s}.fieldByDefault", .{metadata_name});
    defer allocator.free(by_default);
    const by_default_ident = try zigStringLiteralAlloc(allocator, by_default);
    defer allocator.free(by_default_ident);
    const by_explicit_default = try std.fmt.allocPrint(allocator, "{s}.fieldByExplicitDefault", .{metadata_name});
    defer allocator.free(by_explicit_default);
    const by_explicit_default_ident = try zigStringLiteralAlloc(allocator, by_explicit_default);
    defer allocator.free(by_explicit_default_ident);
    const by_hex_default = try std.fmt.allocPrint(allocator, "{s}.fieldByHexDefault", .{metadata_name});
    defer allocator.free(by_hex_default);
    const by_hex_default_ident = try zigStringLiteralAlloc(allocator, by_hex_default);
    defer allocator.free(by_hex_default_ident);
    const by_annotations = try std.fmt.allocPrint(allocator, "{s}.fieldByAnnotations", .{metadata_name});
    defer allocator.free(by_annotations);
    const by_annotations_ident = try zigSchemaSyntaxLiteralAlloc(allocator, by_annotations);
    defer allocator.free(by_annotations_ident);
    const by_index = try std.fmt.allocPrint(allocator, "{s}.fieldByIndex", .{metadata_name});
    defer allocator.free(by_index);
    const by_index_ident = try zigStringLiteralAlloc(allocator, by_index);
    defer allocator.free(by_index_ident);
    try appendFmt(allocator, out,
        \\{s}pub fn @{s}(@"cpz.name": []const u8) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".name, @"cpz.name")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.type": []const u8) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".ty, @"cpz.type")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.type": []const u8) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".resolved_ty, @"cpz.type")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, by_name_ident, indent, metadata_ident, indent, indent, indent, by_type_ident, indent, metadata_ident, indent, indent, indent, by_resolved_type_ident, indent, metadata_ident, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @{s}(@"cpz.default": []const u8) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (@"cpz.field".default_literal != null and std.mem.eql(u8, @"cpz.field".default_literal.?, @"cpz.default")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.hasDefault": bool) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (@"cpz.field".has_explicit_default == @"cpz.hasDefault") return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.isHex": bool) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (@"cpz.field".default_is_hex_data == @"cpz.isHex") return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.annotationFilter": []const u8) ?cpz.schema.MethodField {{
        \\{s}    for (@This().@{s}) |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".annotations, @"cpz.annotationFilter")) return @"cpz.field";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @{s}(@"cpz.index": usize) ?cpz.schema.MethodField {{
        \\{s}    if (@"cpz.index" >= @This().@{s}.len) return null;
        \\{s}    return @This().@{s}[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, by_default_ident, indent, metadata_ident, indent, indent, indent, by_explicit_default_ident, indent, metadata_ident, indent, indent, indent, by_hex_default_ident, indent, metadata_ident, indent, indent, indent, by_annotations_ident, indent, metadata_ident, indent, indent, indent, by_index_ident, indent, metadata_ident, indent, metadata_ident, indent });
}

pub fn emitAnnotation(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, decl: *const AnnotationDecl) LayoutError!void {
    const annotation_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(annotation_name);
    const owner_name = annotationOwnerName(decl.name);
    const zig_type = try annotationTypeNameAlloc(allocator, file, owner_name, decl.ty);
    defer allocator.free(zig_type);
    try appendFmt(allocator, out,
        \\pub const {s} = struct {{
        \\    pub const @"cpz.annotation" = true;
        \\    pub const Type = {s};
        \\
    , .{ annotation_name, zig_type });
    if (decl.id) |id| {
        try appendFmt(allocator, out,
            \\    pub const @"cpz.type_id": u64 = 0x{x};
            \\
        , .{id});
    }
    try appendFmt(allocator, out,
        \\    pub const targets: cpz.schema.AnnotationTargets = .{{
        \\        .file = {},
        \\        .const_decl = {},
        \\        .enum_decl = {},
        \\        .enumerant = {},
        \\        .struct_decl = {},
        \\        .field = {},
        \\        .union_decl = {},
        \\        .group = {},
        \\        .interface_decl = {},
        \\        .method = {},
        \\        .param = {},
        \\        .annotation_decl = {},
        \\    }};
        \\}};
        \\
        \\
    , .{
        decl.targets.file,
        decl.targets.const_decl,
        decl.targets.enum_decl,
        decl.targets.enumerant,
        decl.targets.struct_decl,
        decl.targets.field,
        decl.targets.union_decl,
        decl.targets.group,
        decl.targets.interface_decl,
        decl.targets.method,
        decl.targets.param,
        decl.targets.annotation_decl,
    });
}

pub fn methodFieldResolvedTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const InterfaceDecl, method_parameters: []const []const u8, raw: []const u8) LayoutError![]u8 {
    const source = try std.fmt.allocPrint(allocator, "struct T {{ f @0 :{s}; }}", .{raw});
    defer allocator.free(source);
    var parsed = try parse(allocator, source);
    defer parsed.deinit(allocator);
    if (parsed.structs.len == 0 or parsed.structs[0].fields.len == 0) return error.UnexpectedToken;
    if (methodParametersContain(method_parameters, parsed.structs[0].fields[0].ty)) {
        return schemaTypeNameAlloc(allocator, parsed.structs[0].fields[0].ty);
    }
    const owner_name = if (scope) |decl| decl.name else null;
    return schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, parsed.structs[0].fields[0].ty);
}

pub fn methodParametersContain(parameters: []const []const u8, ty: Type) bool {
    return switch (ty) {
        .named => |name| for (parameters) |parameter| {
            if (typeNameEqualsCanonical(name, parameter)) break true;
        } else false,
        .list, .optional => |child| methodParametersContain(parameters, child.*),
        else => false,
    };
}

pub fn annotationTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, owner_name: ?[]const u8, ty: Type) LayoutError![]u8 {
    return switch (resolveTypeInOwnerScope(file, owner_name, ty)) {
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
        .any_pointer => allocator.dupe(u8, "cpz.PointerReader"),
        .any_struct => allocator.dupe(u8, "cpz.StructReader"),
        .any_list => allocator.dupe(u8, "cpz.ListReader"),
        .capability => allocator.dupe(u8, "u32"),
        .named => |type_name| {
            // Interface annotation values are encoded as capability IDs in the
            // generated Zig API; the generated interface struct is metadata,
            // not the value representation accepted by annotation users.
            if (findInterface(file, type_name) != null) return allocator.dupe(u8, "u32");
            if (findEnum(file, type_name) != null or isStructLikeName(file, type_name)) {
                return zigTypeRefAlloc(allocator, file, type_name);
            }
            return allocator.dupe(u8, "cpz.PointerReader");
        },
        .list => |child| {
            const child_type = try annotationTypeNameAlloc(allocator, file, owner_name, child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "[]const {s}", .{child_type});
        },
        .optional => |child| {
            const child_type = try annotationTypeNameAlloc(allocator, file, owner_name, child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "?{s}", .{child_type});
        },
    };
}
