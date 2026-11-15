const std = @import("std");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const state = @import("state.zig");
const mod_field_defaults = @import("field_defaults.zig");
const mod_interface = @import("interface.zig");
const mod_text = @import("text.zig");

const AliasDecl = frontend.AliasDecl;
const AliasMetadata = frontend.AliasMetadata;
const AnnotationDecl = frontend.AnnotationDecl;
const AnnotationMetadata = frontend.AnnotationMetadata;
const AnnotationTargets = frontend.AnnotationTargets;
const ConstDecl = frontend.ConstDecl;
const ConstListItem = frontend.ConstListItem;
const ConstMetadata = frontend.ConstMetadata;
const ConstStructField = frontend.ConstStructField;
const DeclarationKind = frontend.DeclarationKind;
const DeclarationMetadata = frontend.DeclarationMetadata;
const Error = frontend.Error;
const FieldMetadata = frontend.FieldMetadata;
const File = frontend.File;
const FileAnnotationMetadata = frontend.FileAnnotationMetadata;
const GroupDecl = frontend.GroupDecl;
const ImportDecl = frontend.ImportDecl;
const ImportMetadata = frontend.ImportMetadata;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const StructLayout = frontend.StructLayout;
const UnionMetadata = frontend.UnionMetadata;
const annotationOwnerName = frontend.annotationOwnerName;
const annotationTargetCount = frontend.annotationTargetCount;
const annotationTargetsHas = frontend.annotationTargetsHas;
const schemaTypeNameAlloc = frontend.schemaTypeNameAlloc;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const fieldSlotMetadata = mod_field_defaults.fieldSlotMetadata;
const appendParameterListLiteral = mod_interface.appendParameterListLiteral;
const emitParameterLookupHelpers = mod_interface.emitParameterLookupHelpers;
const appendFmt = mod_text.appendFmt;
const schemaResolvedTypeNameAlloc = mod_text.schemaResolvedTypeNameAlloc;
const schemaResolvedTypeNameInOwnerScopeAlloc = mod_text.schemaResolvedTypeNameInOwnerScopeAlloc;
const zigSchemaSyntaxLiteralAlloc = mod_text.zigSchemaSyntaxLiteralAlloc;
const zigStringLiteralAlloc = mod_text.zigStringLiteralAlloc;

pub fn emitFileAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), annotations_raw: []const []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.fileAnnotationCount": usize = {};
        \\
    , .{ indent, annotations_raw.len });
    for (annotations_raw, 0..) |annotation_raw, index| {
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotation_raw);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.fileAnnotation.{}.index": usize = {};
            \\{s}pub const @"cpz.fileAnnotation.{}.metadata": cpz.schema.FileAnnotationMetadata = @This().@"cpz.file_annotations"[{}];
            \\{s}pub const @"cpz.fileAnnotation.{}.raw": []const u8 = {s};
            \\
        , .{ indent, index, index, indent, index, index, indent, index, annotation_literal });
    }
    try appendFmt(allocator, out, "{s}pub const @\"cpz.file_annotations\": []const cpz.schema.FileAnnotationMetadata = &[_]cpz.schema.FileAnnotationMetadata{{", .{indent});
    for (annotations_raw, 0..) |annotation_raw, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotation_raw);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .raw = {s} }}", .{ index, annotation_literal });
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.fileAnnotationByIndex"(@"cpz.index": usize) ?cpz.schema.FileAnnotationMetadata {{
        \\{s}    for (@This().@"cpz.file_annotations") |@"cpz.annotation"| if (@"cpz.annotation".index == @"cpz.index") return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.fileAnnotationByRaw"(@"cpz.raw": []const u8) ?cpz.schema.FileAnnotationMetadata {{
        \\{s}    for (@This().@"cpz.file_annotations") |@"cpz.annotation"| if (std.mem.eql(u8, @"cpz.annotation".raw, @"cpz.raw")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent });
    if (annotations_raw.len != 0) try out.append(allocator, '\n');
}

pub fn emitDeclarationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    var constant_index: usize = 0;
    for (file.structs) |decl| {
        try emitDeclarationMetadataConstants(allocator, out, constant_index, decl.name, "struct_decl", decl.id, decl.annotations, decl.parameters, indent);
        constant_index += 1;
    }
    for (file.enums) |decl| {
        try emitDeclarationMetadataConstants(allocator, out, constant_index, decl.name, "enum_decl", decl.id, decl.annotations, &.{}, indent);
        constant_index += 1;
    }
    for (file.interfaces) |decl| {
        try emitDeclarationMetadataConstants(allocator, out, constant_index, decl.name, "interface_decl", decl.id, decl.annotations, decl.parameters, indent);
        constant_index += 1;
    }
    for (file.annotations) |decl| {
        try emitDeclarationMetadataConstants(allocator, out, constant_index, decl.name, "annotation_decl", decl.id, decl.annotations, &.{}, indent);
        constant_index += 1;
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.structCount": usize = {};
        \\{s}pub const @"cpz.enumCount": usize = {};
        \\{s}pub const @"cpz.interfaceCount": usize = {};
        \\{s}pub const @"cpz.annotationDeclCount": usize = {};
        \\
    , .{ indent, file.structs.len, indent, file.enums.len, indent, file.interfaces.len, indent, file.annotations.len });
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.declarationCount": usize = {};
        \\
    , .{ indent, constant_index });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.declarations\": []const cpz.schema.DeclarationMetadata = &[_]cpz.schema.DeclarationMetadata{{", .{indent});
    var count: usize = 0;
    for (file.structs) |decl| {
        if (count != 0) try out.appendSlice(allocator, ", ");
        try appendDeclarationMetadataLiteral(allocator, out, count, decl.name, "struct_decl", decl.id, decl.annotations, decl.parameters);
        count += 1;
    }
    for (file.enums) |decl| {
        if (count != 0) try out.appendSlice(allocator, ", ");
        try appendDeclarationMetadataLiteral(allocator, out, count, decl.name, "enum_decl", decl.id, decl.annotations, &.{});
        count += 1;
    }
    for (file.interfaces) |decl| {
        if (count != 0) try out.appendSlice(allocator, ", ");
        try appendDeclarationMetadataLiteral(allocator, out, count, decl.name, "interface_decl", decl.id, decl.annotations, decl.parameters);
        count += 1;
    }
    for (file.annotations) |decl| {
        if (count != 0) try out.appendSlice(allocator, ", ");
        try appendDeclarationMetadataLiteral(allocator, out, count, decl.name, "annotation_decl", decl.id, decl.annotations, &.{});
        count += 1;
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.declarationByName"(@"cpz.name": []const u8) ?cpz.schema.DeclarationMetadata {{
        \\{s}    for (@This().@"cpz.declarations") |@"cpz.decl"| if (std.mem.eql(u8, @"cpz.decl".name, @"cpz.name")) return @"cpz.decl";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.declarationById"(@"cpz.id": u64) ?cpz.schema.DeclarationMetadata {{
        \\{s}    for (@This().@"cpz.declarations") |@"cpz.decl"| if (@"cpz.decl".id != null and @"cpz.decl".id.? == @"cpz.id") return @"cpz.decl";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.declarationByKind"(@"cpz.kind": cpz.schema.DeclarationKind) ?cpz.schema.DeclarationMetadata {{
        \\{s}    for (@This().@"cpz.declarations") |@"cpz.decl"| if (@"cpz.decl".kind == @"cpz.kind") return @"cpz.decl";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.declarationByParameter"(@"cpz.parameter": []const u8) ?cpz.schema.DeclarationMetadata {{
        \\{s}    for (@This().@"cpz.declarations") |@"cpz.decl"| for (@"cpz.decl".parameters) |@"cpz.declParam"| if (std.mem.eql(u8, @"cpz.declParam", @"cpz.parameter")) return @"cpz.decl";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.declarationByParameterCount"(@"cpz.count": usize) ?cpz.schema.DeclarationMetadata {{
        \\{s}    for (@This().@"cpz.declarations") |@"cpz.decl"| if (@"cpz.decl".parameter_count == @"cpz.count") return @"cpz.decl";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.declarationByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.DeclarationMetadata {{
        \\{s}    for (@This().@"cpz.declarations") |@"cpz.decl"| if (std.mem.eql(u8, @"cpz.decl".annotations, @"cpz.annotationFilter")) return @"cpz.decl";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.declarationByIndex"(@"cpz.index": usize) ?cpz.schema.DeclarationMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.declarations".len) return null;
        \\{s}    return @This().@"cpz.declarations"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (count != 0) try out.append(allocator, '\n');
}

pub fn emitDeclarationMetadataConstants(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    index: usize,
    name: []const u8,
    kind: []const u8,
    id: ?u64,
    annotations: []const u8,
    parameters: []const []const u8,
    indent: []const u8,
) LayoutError!void {
    const decl_name = try zigIdentAlloc(allocator, name);
    defer allocator.free(decl_name);
    const name_literal = try zigStringLiteralAlloc(allocator, name);
    defer allocator.free(name_literal);
    const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotations);
    defer allocator.free(annotations_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.declaration.{s}.index": usize = {};
        \\{s}pub const @"cpz.declaration.{s}.name": []const u8 = {s};
        \\{s}pub const @"cpz.declaration.{s}.kind": cpz.schema.DeclarationKind = .{s};
        \\{s}pub const @"cpz.declaration.{s}.metadata": cpz.schema.DeclarationMetadata = @This().@"cpz.declarations"[{}];
        \\{s}pub const @"cpz.declaration.{s}.id": ?u64 = 
    , .{ indent, decl_name, index, indent, decl_name, name_literal, indent, decl_name, kind, indent, decl_name, index, indent, decl_name });
    if (id) |value| {
        try appendFmt(allocator, out, "0x{x};\n", .{value});
    } else {
        try out.appendSlice(allocator, "null;\n");
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.declaration.{s}.annotations": []const u8 = {s};
        \\{s}pub const @"cpz.declaration.{s}.parameterCount": usize = {};
        \\{s}pub const @"cpz.declaration.{s}.parameters": []const []const u8 = 
    , .{ indent, decl_name, annotations_literal, indent, decl_name, parameters.len, indent, decl_name });
    try appendParameterListLiteral(allocator, out, parameters);
    try out.appendSlice(allocator, ";\n");
    const declaration_parameters_name = try std.fmt.allocPrint(allocator, "cpz.declaration.{s}.parameters", .{decl_name});
    defer allocator.free(declaration_parameters_name);
    try emitParameterLookupHelpers(allocator, out, declaration_parameters_name, indent);
    try out.append(allocator, '\n');
}

pub fn appendDeclarationMetadataLiteral(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    index: usize,
    name: []const u8,
    kind: []const u8,
    id: ?u64,
    annotations: []const u8,
    parameters: []const []const u8,
) LayoutError!void {
    const name_literal = try zigStringLiteralAlloc(allocator, name);
    defer allocator.free(name_literal);
    const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotations);
    defer allocator.free(annotations_literal);
    try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .kind = .{s}", .{ index, name_literal, kind });
    if (id) |value| try appendFmt(allocator, out, ", .id = 0x{x}", .{value});
    if (annotations.len != 0) try appendFmt(allocator, out, ", .annotations = {s}", .{annotations_literal});
    if (parameters.len != 0) try appendFmt(allocator, out, ", .parameter_count = {}", .{parameters.len});
    if (parameters.len != 0) {
        try out.appendSlice(allocator, ", .parameters = ");
        try appendParameterListLiteral(allocator, out, parameters);
    }
    try out.appendSlice(allocator, " }");
}

pub fn emitImportMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), imports: []const ImportDecl, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.importCount": usize = {};
        \\
    , .{ indent, imports.len });
    for (imports, 0..) |import_decl, index| {
        const name_literal = try zigStringLiteralAlloc(allocator, import_decl.name);
        defer allocator.free(name_literal);
        const path_literal = try zigStringLiteralAlloc(allocator, import_decl.path);
        defer allocator.free(path_literal);
        const member_literal = try zigStringLiteralAlloc(allocator, import_decl.member orelse "");
        defer allocator.free(member_literal);
        const import_name = try zigIdentAlloc(allocator, import_decl.name);
        defer allocator.free(import_name);
        try appendFmt(allocator, out,
            \\{s}pub const @"cpz.import.{s}.index": usize = {};
            \\{s}pub const @"cpz.import.{s}.name": []const u8 = {s};
            \\{s}pub const @"cpz.import.{s}.metadata": cpz.schema.ImportMetadata = @This().@"cpz.imports"[{}];
            \\{s}pub const @"cpz.import.{s}.path": []const u8 = {s};
            \\{s}pub const @"cpz.import.{s}.member": []const u8 = {s};
            \\{s}pub const @"cpz.import.{s}.hasMember": bool = {};
            \\
        , .{ indent, import_name, index, indent, import_name, name_literal, indent, import_name, index, indent, import_name, path_literal, indent, import_name, member_literal, indent, import_name, import_decl.member != null });
    }
    try appendFmt(allocator, out, "{s}pub const @\"cpz.imports\": []const cpz.schema.ImportMetadata = &[_]cpz.schema.ImportMetadata{{", .{indent});
    for (imports, 0..) |import_decl, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, import_decl.name);
        defer allocator.free(name_literal);
        const path_literal = try zigStringLiteralAlloc(allocator, import_decl.path);
        defer allocator.free(path_literal);
        const member_literal = try zigStringLiteralAlloc(allocator, import_decl.member orelse "");
        defer allocator.free(member_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .path = {s}", .{ index, name_literal, path_literal });
        if (import_decl.member != null) {
            try appendFmt(allocator, out, ", .member = {s}, .has_member = true", .{member_literal});
        }
        try out.appendSlice(allocator, " }");
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.importByName"(@"cpz.name": []const u8) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (std.mem.eql(u8, @"cpz.import".name, @"cpz.name")) return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByMember"(@"cpz.member": []const u8) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (std.mem.eql(u8, @"cpz.import".member, @"cpz.member")) return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByPath"(@"cpz.path": []const u8) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (std.mem.eql(u8, @"cpz.import".path, @"cpz.path")) return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByPathAndMember"(@"cpz.path": []const u8, @"cpz.member": []const u8) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (@"cpz.import".has_member and std.mem.eql(u8, @"cpz.import".path, @"cpz.path") and std.mem.eql(u8, @"cpz.import".member, @"cpz.member")) return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByMemberFlag"(@"cpz.hasMember": bool) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (@"cpz.import".has_member == @"cpz.hasMember") return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByPathAndMemberFlag"(@"cpz.path": []const u8, @"cpz.hasMember": bool) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (std.mem.eql(u8, @"cpz.import".path, @"cpz.path") and @"cpz.import".has_member == @"cpz.hasMember") return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByIndex"(@"cpz.index": usize) ?cpz.schema.ImportMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.imports".len) return null;
        \\{s}    return @This().@"cpz.imports"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (imports.len != 0) try out.append(allocator, '\n');
}

pub fn emitAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, annotations: []const AnnotationDecl, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.annotationCount": usize = {};
        \\
    , .{ indent, annotations.len });
    for (annotations, 0..) |annotation, index| {
        try emitAnnotationMetadataConstants(allocator, out, file, index, &annotation, indent);
    }
    try appendFmt(allocator, out, "{s}pub const @\"cpz.annotation_decls\": []const cpz.schema.AnnotationMetadata = &[_]cpz.schema.AnnotationMetadata{{", .{indent});
    for (annotations, 0..) |annotation, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        try appendAnnotationMetadataLiteral(allocator, out, file, index, &annotation);
    }
    try out.appendSlice(allocator, "};\n");
    try emitAnnotationLookupHelpers(allocator, out, indent);
    if (annotations.len != 0) try out.append(allocator, '\n');
}

pub fn emitScopedAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    var count: usize = 0;
    for (file.annotations) |annotation| {
        if (!std.mem.eql(u8, annotationOwnerName(annotation.name) orelse continue, owner_name)) continue;
        try emitAnnotationMetadataConstants(allocator, out, file, count, &annotation, indent);
        count += 1;
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.annotationCount": usize = {};
        \\
    , .{ indent, count });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.annotation_decls\": []const cpz.schema.AnnotationMetadata = &[_]cpz.schema.AnnotationMetadata{{", .{indent});
    count = 0;
    for (file.annotations) |annotation| {
        if (!std.mem.eql(u8, annotationOwnerName(annotation.name) orelse continue, owner_name)) continue;
        if (count != 0) try out.appendSlice(allocator, ", ");
        try appendAnnotationMetadataLiteral(allocator, out, file, count, &annotation);
        count += 1;
    }
    try out.appendSlice(allocator, "};\n");
    try emitAnnotationLookupHelpers(allocator, out, indent);
    if (count != 0) try out.append(allocator, '\n');
}

pub fn emitAnnotationLookupHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.annotationByName"(@"cpz.name": []const u8) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (std.mem.eql(u8, @"cpz.annotation".name, @"cpz.name")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationById"(@"cpz.id": u64) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (@"cpz.annotation".id != null and @"cpz.annotation".id.? == @"cpz.id") return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByType"(@"cpz.type": []const u8) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (std.mem.eql(u8, @"cpz.annotation".ty, @"cpz.type")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByResolvedType"(@"cpz.type": []const u8) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (std.mem.eql(u8, @"cpz.annotation".resolved_ty, @"cpz.type")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (std.mem.eql(u8, @"cpz.annotation".annotations, @"cpz.annotationFilter")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByTarget"(@"cpz.target": []const u8) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (cpz.schema.annotationTargetsHas(@"cpz.annotation".targets, @"cpz.target")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByTargetCount"(@"cpz.count": usize) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (@"cpz.annotation".target_count == @"cpz.count") return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByIndex"(@"cpz.index": usize) ?cpz.schema.AnnotationMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.annotation_decls".len) return null;
        \\{s}    return @This().@"cpz.annotation_decls"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
}

pub fn emitAnnotationMetadataConstants(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, index: usize, decl: *const AnnotationDecl, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    const annotation_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(annotation_name);
    const name_literal = try zigStringLiteralAlloc(allocator, decl.name);
    defer allocator.free(name_literal);
    const type_name = try schemaTypeNameAlloc(allocator, decl.ty);
    defer allocator.free(type_name);
    const type_literal = try zigStringLiteralAlloc(allocator, type_name);
    defer allocator.free(type_literal);
    const owner_name = annotationOwnerName(decl.name);
    const resolved_type_name = try schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, decl.ty);
    defer allocator.free(resolved_type_name);
    const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
    defer allocator.free(resolved_type_literal);
    const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, decl.annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.annotationDecl.{s}.index": usize = {};
        \\{s}pub const @"cpz.annotationDecl.{s}.name": []const u8 = {s};
        \\{s}pub const @"cpz.annotationDecl.{s}.id": ?u64 = 
    , .{ indent, annotation_name, index, indent, annotation_name, name_literal, indent, annotation_name });
    if (decl.id) |id| {
        try appendFmt(allocator, out, "0x{x};\n", .{id});
    } else {
        try out.appendSlice(allocator, "null;\n");
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.annotationDecl.{s}.metadata": cpz.schema.AnnotationMetadata = @This().@"cpz.annotation_decls"[{}];
        \\{s}pub const @"cpz.annotationDecl.{s}.type": []const u8 = {s};
        \\{s}pub const @"cpz.annotationDecl.{s}.resolvedType": []const u8 = {s};
        \\{s}pub const @"cpz.annotationDecl.{s}.annotations": []const u8 = {s};
        \\{s}pub const @"cpz.annotationDecl.{s}.targetCount": usize = {};
        \\{s}pub const @"cpz.annotationDecl.{s}.targets": cpz.schema.AnnotationTargets = 
    , .{ indent, annotation_name, index, indent, annotation_name, type_literal, indent, annotation_name, resolved_type_literal, indent, annotation_name, annotation_literal, indent, annotation_name, annotationTargetCount(decl.targets), indent, annotation_name });
    try appendAnnotationTargetsLiteral(allocator, out, decl.targets);
    try out.appendSlice(allocator, ";\n\n");
}

pub fn appendAnnotationMetadataLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, index: usize, decl: *const AnnotationDecl) LayoutError!void {
    const name_literal = try zigStringLiteralAlloc(allocator, decl.name);
    defer allocator.free(name_literal);
    const type_name = try schemaTypeNameAlloc(allocator, decl.ty);
    defer allocator.free(type_name);
    const type_literal = try zigStringLiteralAlloc(allocator, type_name);
    defer allocator.free(type_literal);
    const owner_name = annotationOwnerName(decl.name);
    const resolved_type_name = try schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, decl.ty);
    defer allocator.free(resolved_type_name);
    const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
    defer allocator.free(resolved_type_literal);
    const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, decl.annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, ", .{ index, name_literal });
    if (decl.id) |id| try appendFmt(allocator, out, ".id = 0x{x}, ", .{id});
    try appendFmt(allocator, out, ".ty = {s}, .resolved_ty = {s}", .{ type_literal, resolved_type_literal });
    if (decl.annotations.len != 0) {
        try appendFmt(allocator, out, ", .annotations = {s}", .{annotation_literal});
    }
    try appendFmt(allocator, out, ", .target_count = {}, .targets = ", .{annotationTargetCount(decl.targets)});
    try appendAnnotationTargetsLiteral(allocator, out, decl.targets);
    try out.appendSlice(allocator, " }");
}

pub fn appendAnnotationTargetsLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), targets: AnnotationTargets) std.mem.Allocator.Error!void {
    try out.appendSlice(allocator, ".{");
    if (targets.file) try out.appendSlice(allocator, " .file = true,");
    if (targets.const_decl) try out.appendSlice(allocator, " .const_decl = true,");
    if (targets.enum_decl) try out.appendSlice(allocator, " .enum_decl = true,");
    if (targets.enumerant) try out.appendSlice(allocator, " .enumerant = true,");
    if (targets.struct_decl) try out.appendSlice(allocator, " .struct_decl = true,");
    if (targets.field) try out.appendSlice(allocator, " .field = true,");
    if (targets.union_decl) try out.appendSlice(allocator, " .union_decl = true,");
    if (targets.group) try out.appendSlice(allocator, " .group = true,");
    if (targets.interface_decl) try out.appendSlice(allocator, " .interface_decl = true,");
    if (targets.method) try out.appendSlice(allocator, " .method = true,");
    if (targets.param) try out.appendSlice(allocator, " .param = true,");
    if (targets.annotation_decl) try out.appendSlice(allocator, " .annotation_decl = true,");
    try out.appendSlice(allocator, " }");
}

pub fn emitAliasMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, aliases: []const AliasDecl, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.aliasCount": usize = {};
        \\
    , .{ indent, aliases.len });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.aliases\": []const cpz.schema.AliasMetadata = &[_]cpz.schema.AliasMetadata{{", .{indent});
    for (aliases, 0..) |alias, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, alias.name);
        defer allocator.free(name_literal);
        const target_name = try schemaTypeNameAlloc(allocator, alias.target);
        defer allocator.free(target_name);
        const target_literal = try zigStringLiteralAlloc(allocator, target_name);
        defer allocator.free(target_literal);
        const resolved_target_name = try schemaResolvedTypeNameAlloc(allocator, file, scope, alias.target);
        defer allocator.free(resolved_target_name);
        const resolved_target_literal = try zigStringLiteralAlloc(allocator, resolved_target_name);
        defer allocator.free(resolved_target_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .target = {s}, .resolved_target = {s} }}", .{ index, name_literal, target_literal, resolved_target_literal });
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.aliasByName"(@"cpz.name": []const u8) ?cpz.schema.AliasMetadata {{
        \\{s}    for (@This().@"cpz.aliases") |@"cpz.alias"| if (std.mem.eql(u8, @"cpz.alias".name, @"cpz.name")) return @"cpz.alias";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.aliasByTarget"(@"cpz.target": []const u8) ?cpz.schema.AliasMetadata {{
        \\{s}    for (@This().@"cpz.aliases") |@"cpz.alias"| if (std.mem.eql(u8, @"cpz.alias".target, @"cpz.target")) return @"cpz.alias";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.aliasByResolvedTarget"(@"cpz.target": []const u8) ?cpz.schema.AliasMetadata {{
        \\{s}    for (@This().@"cpz.aliases") |@"cpz.alias"| if (std.mem.eql(u8, @"cpz.alias".resolved_target, @"cpz.target")) return @"cpz.alias";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.aliasByIndex"(@"cpz.index": usize) ?cpz.schema.AliasMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.aliases".len) return null;
        \\{s}    return @This().@"cpz.aliases"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (aliases.len != 0) try out.append(allocator, '\n');
}

pub fn emitConstMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, consts: []const ConstDecl, indent: []const u8) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.constCount": usize = {};
        \\
    , .{ indent, consts.len });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.consts\": []const cpz.schema.ConstMetadata = &[_]cpz.schema.ConstMetadata{{", .{indent});
    for (consts, 0..) |decl, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        try appendConstMetadataLiteral(allocator, out, file, scope, index, &decl);
    }
    try out.appendSlice(allocator, "};\n");
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.constByName"(@"cpz.name": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (std.mem.eql(u8, @"cpz.const".name, @"cpz.name")) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByType"(@"cpz.type": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (std.mem.eql(u8, @"cpz.const".ty, @"cpz.type")) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByResolvedType"(@"cpz.type": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (std.mem.eql(u8, @"cpz.const".resolved_ty, @"cpz.type")) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (std.mem.eql(u8, @"cpz.const".literal, @"cpz.literal")) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByHexData"(@"cpz.isHex": bool) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_hex_data == @"cpz.isHex") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.constById"(@"cpz.id": u64) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".id != null and @"cpz.const".id.? == @"cpz.id") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.constByEmbed"(@"cpz.isEmbed": bool) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_embed == @"cpz.isEmbed") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByEmbedPath"(@"cpz.path": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (std.mem.eql(u8, @"cpz.const".embed_path, @"cpz.path")) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByEmbedByteCount"(@"cpz.count": usize) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_embed and @"cpz.const".embed_byte_count == @"cpz.count") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByStructLiteral"(@"cpz.isStruct": bool) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_struct_literal == @"cpz.isStruct") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByEmitted"(@"cpz.emitted": bool) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".emitted == @"cpz.emitted") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (std.mem.eql(u8, @"cpz.const".annotations, @"cpz.annotationFilter")) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByListItemCount"(@"cpz.count": usize) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".list_item_count == @"cpz.count") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByIndex"(@"cpz.index": usize) ?cpz.schema.ConstMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.consts".len) return null;
        \\{s}    return @This().@"cpz.consts"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.constByStructFieldCount"(@"cpz.count": usize) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_struct_literal and @"cpz.const".struct_field_count == @"cpz.count") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByStructFieldName"(@"cpz.name": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_struct_literal and @"cpz.const".structFieldByName(@"cpz.name") != null) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByStructFieldLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| if (@"cpz.const".is_struct_literal and @"cpz.const".structFieldByLiteral(@"cpz.literal") != null) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.constByListItemStructFieldCount"(@"cpz.count": usize) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| for (@"cpz.const".list_items) |@"cpz.item"| if (@"cpz.item".struct_field_count == @"cpz.count") return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByListItemStructFieldName"(@"cpz.name": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| for (@"cpz.const".list_items) |@"cpz.item"| if (@"cpz.item".structFieldByName(@"cpz.name") != null) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.constByListItemStructFieldLiteral"(@"cpz.literal": []const u8) ?cpz.schema.ConstMetadata {{
        \\{s}    for (@This().@"cpz.consts") |@"cpz.const"| for (@"cpz.const".list_items) |@"cpz.item"| if (@"cpz.item".structFieldByLiteral(@"cpz.literal") != null) return @"cpz.const";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (consts.len != 0) try out.append(allocator, '\n');
}

pub fn appendConstMetadataLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const ConstDecl) LayoutError!void {
    const name_literal = try zigStringLiteralAlloc(allocator, decl.name);
    defer allocator.free(name_literal);
    const type_name = try schemaTypeNameAlloc(allocator, decl.ty);
    defer allocator.free(type_name);
    const type_literal = try zigStringLiteralAlloc(allocator, type_name);
    defer allocator.free(type_literal);
    const resolved_type_name = try schemaResolvedTypeNameAlloc(allocator, file, scope, decl.ty);
    defer allocator.free(resolved_type_name);
    const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
    defer allocator.free(resolved_type_literal);
    const value_literal = try zigStringLiteralAlloc(allocator, decl.literal);
    defer allocator.free(value_literal);
    const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, decl.annotations);
    defer allocator.free(annotations_literal);
    try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}", .{ index, name_literal });
    if (decl.id) |id| {
        try appendFmt(allocator, out, ", .id = 0x{x}", .{id});
    }
    try appendFmt(allocator, out, ", .ty = {s}, .resolved_ty = {s}", .{ type_literal, resolved_type_literal });
    if (decl.literal.len != 0) {
        try appendFmt(allocator, out, ", .literal = {s}", .{value_literal});
    }
    if (decl.is_hex_data) {
        try out.appendSlice(allocator, ", .is_hex_data = true");
    }
    if (decl.is_embed) {
        const embed_path_literal = try zigStringLiteralAlloc(allocator, decl.embed_path);
        defer allocator.free(embed_path_literal);
        try appendFmt(allocator, out, ", .is_embed = true, .embed_path = {s}", .{embed_path_literal});
        if (decl.embed_bytes) |bytes| try appendFmt(allocator, out, ", .embed_byte_count = {}", .{bytes.len});
    }
    if (decl.is_struct_literal) {
        try out.appendSlice(allocator, ", .is_struct_literal = true");
    }
    if (!decl.emit_value) {
        try out.appendSlice(allocator, ", .emitted = false");
    }
    if (decl.annotations.len != 0) {
        try appendFmt(allocator, out, ", .annotations = {s}", .{annotations_literal});
    }
    if (decl.list_items) |items| {
        try appendFmt(allocator, out, ", .list_item_count = {}", .{items.len});
        try out.appendSlice(allocator, ", .list_items = ");
        try appendConstListItemsLiteral(allocator, out, items);
    }
    if (decl.struct_fields) |fields| {
        try appendFmt(allocator, out, ", .struct_field_count = {}", .{fields.len});
        try out.appendSlice(allocator, ", .struct_fields = ");
        try appendConstStructFieldsLiteral(allocator, out, fields);
    }
    try out.appendSlice(allocator, " }");
}

pub fn appendConstListItemsLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), items: []const ConstListItem) LayoutError!void {
    try out.appendSlice(allocator, "&[_]cpz.schema.ConstListItem{");
    for (items, 0..) |item, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const literal = try zigStringLiteralAlloc(allocator, item.literal);
        defer allocator.free(literal);
        const annotations = try zigSchemaSyntaxLiteralAlloc(allocator, item.annotations);
        defer allocator.free(annotations);
        try appendFmt(allocator, out, ".{{ .index = {}, .literal = {s}", .{ item.index, literal });
        if (item.is_hex_data) {
            try out.appendSlice(allocator, ", .is_hex_data = true");
        }
        if (item.annotations.len != 0) {
            try appendFmt(allocator, out, ", .annotations = {s}", .{annotations});
        }
        if (item.struct_fields.len != 0) {
            try appendFmt(allocator, out, ", .struct_field_count = {}", .{item.struct_fields.len});
            try out.appendSlice(allocator, ", .struct_fields = ");
            try appendConstStructFieldsLiteral(allocator, out, item.struct_fields);
        }
        try out.appendSlice(allocator, " }");
    }
    try out.appendSlice(allocator, "}");
}

pub fn appendConstStructFieldsLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), fields: []const ConstStructField) LayoutError!void {
    try out.appendSlice(allocator, "&[_]cpz.schema.ConstStructField{");
    for (fields, 0..) |field, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(name_literal);
        const literal = try zigStringLiteralAlloc(allocator, field.literal);
        defer allocator.free(literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .literal = {s} }}", .{ field.index, name_literal, literal });
    }
    try out.appendSlice(allocator, "}");
}

pub fn emitStructUnionMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\    pub const @"cpz.unionCount": usize = {};
        \\
    , .{layout.unions.len});
    for (layout.unions, 0..) |union_layout, index| {
        const field_count = unionFieldCount(layout, @intCast(index));
        const name_literal = try zigStringLiteralAlloc(allocator, union_layout.name);
        defer allocator.free(name_literal);
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, union_layout.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.union.{}.index": u32 = {};
            \\    pub const @"cpz.union.{}.name": []const u8 = {s};
            \\    pub const @"cpz.union.{}.ordinal": ?u32 =
        , .{ index, index, index, name_literal, index });
        if (union_layout.ordinal) |ordinal| {
            try appendFmt(allocator, out, "{};\n", .{ordinal});
        } else {
            try out.appendSlice(allocator, "null;\n");
        }
        try appendFmt(allocator, out,
            \\    pub const @"cpz.union.{}.discriminantByte": usize = {};
            \\    pub const @"cpz.union.{}.annotations": []const u8 = {s};
            \\    pub const @"cpz.union.{}.dataBit": usize = {};
            \\    pub const @"cpz.union.{}.dataBits": usize = {};
            \\    pub const @"cpz.union.{}.fieldCount": usize = {};
            \\    pub const @"cpz.union.{}.pointer": ?usize = 
        , .{ index, union_layout.discriminant_byte, index, annotation_literal, index, union_layout.data_bit, index, union_layout.data_bits, index, field_count, index });
        if (union_layout.pointer) |pointer| {
            try appendFmt(allocator, out, "{};\n", .{pointer});
        } else {
            try out.appendSlice(allocator, "null;\n");
        }
        try appendFmt(allocator, out, "    pub const @\"cpz.union.{}.fields\": []const cpz.schema.FieldMetadata = ", .{index});
        try appendUnionFieldMetadataLiteral(allocator, out, file, layout, @intCast(index));
        try appendFmt(allocator, out,
            \\;
            \\    pub fn @"cpz.union.{}.fieldByName"(@"cpz.name": []const u8) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".name, @"cpz.name")) return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByType"(@"cpz.type": []const u8) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".ty, @"cpz.type")) return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByResolvedType"(@"cpz.type": []const u8) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".resolved_ty, @"cpz.type")) return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldBySlot"(@"cpz.slot": []const u8, @"cpz.offset": usize) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".slot, @"cpz.slot") and @"cpz.field".offset == @"cpz.offset") return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByDefault"(@"cpz.default": []const u8) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".default, @"cpz.default")) return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByExplicitDefault"(@"cpz.hasDefault": bool) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (@"cpz.field".has_explicit_default == @"cpz.hasDefault") return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByHexDefault"(@"cpz.isHex": bool) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (@"cpz.field".default_is_hex_data == @"cpz.isHex") return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".annotations, @"cpz.annotationFilter")) return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByDiscriminant"(@"cpz.discriminant": u16) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (@"cpz.field".union_discriminant == @"cpz.discriminant") return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByOrdinal"(@"cpz.ordinal": u32) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (@"cpz.field".ordinal == @"cpz.ordinal") return @"cpz.field";
            \\        return null;
            \\    }}
            \\
            \\    pub fn @"cpz.union.{}.fieldByIndex"(@"cpz.index": usize) ?cpz.schema.FieldMetadata {{
            \\        if (@"cpz.index" >= @This().@"cpz.union.{}.fields".len) return null;
            \\        return @This().@"cpz.union.{}.fields"[@"cpz.index"];
            \\    }}
            \\
            \\
        , .{ index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index });
    }
    try out.appendSlice(allocator, "    pub const @\"cpz.unions\": []const cpz.schema.UnionMetadata = &[_]cpz.schema.UnionMetadata{");
    for (layout.unions, 0..) |union_layout, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, union_layout.name);
        defer allocator.free(name_literal);
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, union_layout.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}", .{ index, name_literal });
        if (union_layout.ordinal) |ordinal| {
            try appendFmt(allocator, out, ", .ordinal = {}", .{ordinal});
        }
        try appendFmt(allocator, out, ", .annotations = {s}, .discriminant_byte = {}, .field_count = {}, .fields = ", .{ annotation_literal, union_layout.discriminant_byte, unionFieldCount(layout, @intCast(index)) });
        try appendUnionFieldMetadataLiteral(allocator, out, file, layout, @intCast(index));
        if (union_layout.data_bits != 0) {
            try appendFmt(allocator, out, ", .data_bit = {}, .data_bits = {}", .{ union_layout.data_bit, union_layout.data_bits });
        }
        if (union_layout.pointer) |pointer| {
            try appendFmt(allocator, out, ", .pointer = {}", .{pointer});
        }
        try out.appendSlice(allocator, " }");
    }
    try out.appendSlice(allocator, "};\n");
    try out.appendSlice(allocator,
        \\    pub fn @"cpz.unionByDiscriminantByte"(@"cpz.byte": usize) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".discriminant_byte == @"cpz.byte") return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByPointer"(@"cpz.pointer": usize) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".pointer != null and @"cpz.union".pointer.? == @"cpz.pointer") return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByDataBit"(@"cpz.bit": usize) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".data_bits != 0 and @"cpz.bit" >= @"cpz.union".data_bit and @"cpz.bit" < @"cpz.union".data_bit + @"cpz.union".data_bits) return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByDataRange"(@"cpz.bit": usize, @"cpz.bits": usize) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".data_bits == @"cpz.bits" and @"cpz.union".data_bit == @"cpz.bit") return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByFieldCount"(@"cpz.count": usize) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".field_count == @"cpz.count") return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByName"(@"cpz.name": []const u8) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (std.mem.eql(u8, @"cpz.union".name, @"cpz.name")) return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByOrdinal"(@"cpz.ordinal": u32) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".ordinal != null and @"cpz.union".ordinal.? == @"cpz.ordinal") return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (std.mem.eql(u8, @"cpz.union".annotations, @"cpz.annotationFilter")) return @"cpz.union";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.unionByIndex"(@"cpz.index": u32) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".index == @"cpz.index") return @"cpz.union";
        \\        return null;
        \\    }
        \\
    );
}

pub fn appendUnionFieldMetadataLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, union_index: u32) LayoutError!void {
    try out.appendSlice(allocator, "&[_]cpz.schema.FieldMetadata{");
    var emitted: usize = 0;
    for (layout.fields, 0..) |field_layout, index| {
        const field = field_layout.field;
        if (field.union_index == null or field.union_index.? != union_index) continue;
        if (emitted != 0) try out.appendSlice(allocator, ", ");
        emitted += 1;
        const field_name = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(field_name);
        const type_name = try schemaTypeNameAlloc(allocator, field.ty);
        defer allocator.free(type_name);
        const type_literal = try zigStringLiteralAlloc(allocator, type_name);
        defer allocator.free(type_literal);
        const resolved_type_name = try schemaResolvedTypeNameAlloc(allocator, file, layout.decl, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        const default_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.default_expression);
        defer allocator.free(default_literal);
        const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        const slot = fieldSlotMetadata(field_layout.slot);
        const slot_literal = try zigStringLiteralAlloc(allocator, slot.name);
        defer allocator.free(slot_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ordinal = {}, .ty = {s}, .resolved_ty = {s}, .slot = {s}, .offset = {}", .{ index, field_name, field.ordinal, type_literal, resolved_type_literal, slot_literal, slot.offset });
        if (field.default_expression.len != 0) {
            try appendFmt(allocator, out, ", .default = {s}, .has_explicit_default = true", .{default_literal});
        }
        if (field.default_is_hex_data) {
            try out.appendSlice(allocator, ", .default_is_hex_data = true");
        }
        if (field.annotations.len != 0) {
            try appendFmt(allocator, out, ", .annotations = {s}", .{annotations_literal});
        }
        try appendFmt(allocator, out, ", .is_union_member = true, .union_index = {}, .union_discriminant = {} }}", .{ union_index, field.union_discriminant });
    }
    try out.appendSlice(allocator, "}");
}

pub fn unionFieldCount(layout: *const StructLayout, union_index: u32) usize {
    var count: usize = 0;
    for (layout.fields) |field_layout| {
        if (field_layout.field.union_index) |current| {
            if (current == union_index) count += 1;
        }
    }
    return count;
}

pub fn emitStructFieldMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\    pub const @"cpz.fieldCount": usize = {};
        \\
    , .{layout.fields.len});
    try out.appendSlice(allocator, "    pub const @\"cpz.fields\": []const cpz.schema.FieldMetadata = &[_]cpz.schema.FieldMetadata{");
    for (layout.fields, 0..) |field_layout, index| {
        const field = field_layout.field;
        if (index != 0) try out.appendSlice(allocator, ", ");
        const field_name = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(field_name);
        const type_name = try schemaTypeNameAlloc(allocator, field.ty);
        defer allocator.free(type_name);
        const type_literal = try zigStringLiteralAlloc(allocator, type_name);
        defer allocator.free(type_literal);
        const resolved_type_name = try schemaResolvedTypeNameAlloc(allocator, file, layout.decl, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        const default_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.default_expression);
        defer allocator.free(default_literal);
        const annotations_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        const slot = fieldSlotMetadata(field_layout.slot);
        const slot_literal = try zigStringLiteralAlloc(allocator, slot.name);
        defer allocator.free(slot_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ordinal = {}, .ty = {s}, .resolved_ty = {s}, .slot = {s}, .offset = {}", .{ index, field_name, field.ordinal, type_literal, resolved_type_literal, slot_literal, slot.offset });
        if (field.default_expression.len != 0) {
            try appendFmt(allocator, out, ", .default = {s}", .{default_literal});
            try out.appendSlice(allocator, ", .has_explicit_default = true");
        }
        if (field.default_is_hex_data) {
            try out.appendSlice(allocator, ", .default_is_hex_data = true");
        }
        if (field.annotations.len != 0) {
            try appendFmt(allocator, out, ", .annotations = {s}", .{annotations_literal});
        }
        if (field.union_index) |union_index| {
            try appendFmt(allocator, out, ", .is_union_member = true, .union_index = {}, .union_discriminant = {}", .{ union_index, field.union_discriminant });
        }
        try out.appendSlice(allocator, " }");
    }
    try out.appendSlice(allocator, "};\n\n");
    try out.appendSlice(allocator,
        \\    pub fn @"cpz.fieldByName"(@"cpz.name": []const u8) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".name, @"cpz.name")) return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByType"(@"cpz.type": []const u8) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".ty, @"cpz.type")) return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByResolvedType"(@"cpz.type": []const u8) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".resolved_ty, @"cpz.type")) return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldBySlot"(@"cpz.slot": []const u8, @"cpz.offset": usize) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".slot, @"cpz.slot") and @"cpz.field".offset == @"cpz.offset") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByUnionDiscriminant"(@"cpz.unionIndex": u32, @"cpz.discriminant": u16) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (@"cpz.field".union_index != null and @"cpz.field".union_index.? == @"cpz.unionIndex" and @"cpz.field".union_discriminant == @"cpz.discriminant") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByDefault"(@"cpz.default": []const u8) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".default, @"cpz.default")) return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByExplicitDefault"(@"cpz.hasDefault": bool) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (@"cpz.field".has_explicit_default == @"cpz.hasDefault") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByHexDefault"(@"cpz.isHex": bool) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (@"cpz.field".default_is_hex_data == @"cpz.isHex") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (std.mem.eql(u8, @"cpz.field".annotations, @"cpz.annotationFilter")) return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByUnionMember"(@"cpz.isUnionMember": bool) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (@"cpz.field".is_union_member == @"cpz.isUnionMember") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByUnionIndex"(@"cpz.unionIndex": u32) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (@"cpz.field".union_index != null and @"cpz.field".union_index.? == @"cpz.unionIndex") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByOrdinal"(@"cpz.ordinal": u32) ?cpz.schema.FieldMetadata {
        \\        for (@"cpz.fields") |@"cpz.field"| if (@"cpz.field".ordinal == @"cpz.ordinal") return @"cpz.field";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.fieldByIndex"(@"cpz.index": usize) ?cpz.schema.FieldMetadata {
        \\        if (@"cpz.index" >= @"cpz.fields".len) return null;
        \\        return @"cpz.fields"[@"cpz.index"];
        \\    }
        \\
    );
}

pub fn emitStructGroupMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), groups: []const GroupDecl) LayoutError!void {
    if (!state.emit_metadata_enabled) return;
    try appendFmt(allocator, out,
        \\    pub const @"cpz.groupCount": usize = {};
        \\
    , .{groups.len});
    for (groups) |group| {
        const group_name = try zigIdentAlloc(allocator, group.name);
        defer allocator.free(group_name);
        const name_literal = try zigStringLiteralAlloc(allocator, group.name);
        defer allocator.free(name_literal);
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, group.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.group.{s}.index": usize = {};
            \\    pub const @"cpz.group.{s}.name": []const u8 = {s};
            \\    pub const @"cpz.group.{s}.ordinal": ?u32 =
        , .{ group_name, group.index, group_name, name_literal, group_name });
        if (group.ordinal) |ordinal| {
            try appendFmt(allocator, out, "{};\n", .{ordinal});
        } else {
            try out.appendSlice(allocator, "null;\n");
        }
        try appendFmt(allocator, out,
            \\    pub const @"cpz.group.{s}.annotations": []const u8 = {s};
            \\    pub const @"cpz.group.{s}.metadata": cpz.schema.GroupDecl = @"cpz.groups"[{}];
            \\
        , .{ group_name, annotation_literal, group_name, group.index });
    }
    try out.appendSlice(allocator, "    pub const @\"cpz.groups\": []const cpz.schema.GroupDecl = &[_]cpz.schema.GroupDecl{");
    for (groups, 0..) |group, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, group.name);
        defer allocator.free(name_literal);
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, group.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}", .{ group.index, name_literal });
        if (group.ordinal) |ordinal| {
            try appendFmt(allocator, out, ", .ordinal = {}", .{ordinal});
        }
        try appendFmt(allocator, out, ", .annotations = {s} }}", .{annotation_literal});
    }
    try out.appendSlice(allocator,
        \\};
        \\    pub fn @"cpz.groupByName"(@"cpz.name": []const u8) ?cpz.schema.GroupDecl {
        \\        for (@"cpz.groups") |@"cpz.group"| if (std.mem.eql(u8, @"cpz.group".name, @"cpz.name")) return @"cpz.group";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.groupByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.GroupDecl {
        \\        for (@"cpz.groups") |@"cpz.group"| if (std.mem.eql(u8, @"cpz.group".annotations, @"cpz.annotationFilter")) return @"cpz.group";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.groupByOrdinal"(@"cpz.ordinal": u32) ?cpz.schema.GroupDecl {
        \\        for (@"cpz.groups") |@"cpz.group"| if (@"cpz.group".ordinal != null and @"cpz.group".ordinal.? == @"cpz.ordinal") return @"cpz.group";
        \\        return null;
        \\    }
        \\
        \\    pub fn @"cpz.groupByIndex"(@"cpz.index": usize) ?cpz.schema.GroupDecl {
        \\        if (@"cpz.index" >= @"cpz.groups".len) return null;
        \\        return @"cpz.groups"[@"cpz.index"];
        \\    }
        \\
        \\
    );
}
