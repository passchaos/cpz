const std = @import("std");

const mod_parser = @import("parser.zig");
const mod_resolve = @import("resolve.zig");
const mod_types = @import("types.zig");

const Parser = mod_parser.Parser;
const parseConstStructFieldsAlloc = mod_parser.parseConstStructFieldsAlloc;
const skipTriviaIndex = mod_parser.skipTriviaIndex;
const annotationOwnerName = mod_resolve.annotationOwnerName;
const canonicalTypeNameAlloc = mod_resolve.canonicalTypeNameAlloc;
const constDeclOwnerName = mod_resolve.constDeclOwnerName;
const declHasParameter = mod_resolve.declHasParameter;
const defaultLiteralCanBeReference = mod_resolve.defaultLiteralCanBeReference;
const enumLiteralOrdinal = mod_resolve.enumLiteralOrdinal;
const findConstReference = mod_resolve.findConstReference;
const findEnum = mod_resolve.findEnum;
const findEnumRelative = mod_resolve.findEnumRelative;
const findInterface = mod_resolve.findInterface;
const findInterfaceDirect = mod_resolve.findInterfaceDirect;
const findInterfaceInOwnerScope = mod_resolve.findInterfaceInOwnerScope;
const findStructDirect = mod_resolve.findStructDirect;
const findStructInOwnerScope = mod_resolve.findStructInOwnerScope;
const firstTopLevelDot = mod_resolve.firstTopLevelDot;
const isAnnotationDirectInOwnerScope = mod_resolve.isAnnotationDirectInOwnerScope;
const isEnumDirectInOwnerScope = mod_resolve.isEnumDirectInOwnerScope;
const isImportedTypeName = mod_resolve.isImportedTypeName;
const isInterfaceDirectInOwnerScope = mod_resolve.isInterfaceDirectInOwnerScope;
const isStructDirectInOwnerScope = mod_resolve.isStructDirectInOwnerScope;
const isStructLikeName = mod_resolve.isStructLikeName;
const lastTopLevelDot = mod_resolve.lastTopLevelDot;
const matchingParen = mod_resolve.matchingParen;
const parseBoolLiteral = mod_resolve.parseBoolLiteral;
const parseFloatLiteral = mod_resolve.parseFloatLiteral;
const parseInlineConstListElementsAlloc = mod_resolve.parseInlineConstListElementsAlloc;
const parseTypeArgAlloc = mod_resolve.parseTypeArgAlloc;
const resolveConstDeclType = mod_resolve.resolveConstDeclType;
const resolveConstReferenceLiteral = mod_resolve.resolveConstReferenceLiteral;
const resolveNamedAliasInOwnerScope = mod_resolve.resolveNamedAliasInOwnerScope;
const resolveTypeScoped = mod_resolve.resolveTypeScoped;
const schemaTypeNameAlloc = mod_resolve.schemaTypeNameAlloc;
const splitTypeApplicationArgsAlloc = mod_resolve.splitTypeApplicationArgsAlloc;
const substituteGenericTypeAlloc = mod_resolve.substituteGenericTypeAlloc;
const typeAcceptsNullPointerDefault = mod_resolve.typeAcceptsNullPointerDefault;
const typeAcceptsVoidPointerDefault = mod_resolve.typeAcceptsVoidPointerDefault;
const typeApplicationOpen = mod_resolve.typeApplicationOpen;
const typeNameEqualsCanonical = mod_resolve.typeNameEqualsCanonical;
const validateMethodFieldTypeReference = mod_resolve.validateMethodFieldTypeReference;
const validateRawTypeApplicationArity = mod_resolve.validateRawTypeApplicationArity;
const validateTypeApplicationArity = mod_resolve.validateTypeApplicationArity;
const validateTypeReference = mod_resolve.validateTypeReference;
const AliasDecl = mod_types.AliasDecl;
const ConstDecl = mod_types.ConstDecl;
const Error = mod_types.Error;
const Field = mod_types.Field;
const File = mod_types.File;
const LayoutError = mod_types.LayoutError;
const MethodField = mod_types.MethodField;
const Struct = mod_types.Struct;
const Type = mod_types.Type;
const typesEqual = mod_types.typesEqual;

pub fn validateFileTypeApplications(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    try validateFileAliasCycles(allocator, file);

    for (file.aliases) |alias| try validateTypeApplicationArity(allocator, file, null, alias.target);
    for (file.consts) |decl| try validateTypeApplicationArity(allocator, file, null, decl.ty);
    for (file.annotations) |decl| {
        var empty_fields: [0]Field = .{};
        var annotation_scope_storage: Struct = undefined;
        const annotation_scope = ownerNameScope(file, annotationOwnerName(decl.name), empty_fields[0..], &annotation_scope_storage);
        try validateTypeApplicationArity(allocator, file, annotation_scope, decl.ty);
    }
    for (file.structs) |decl| {
        for (decl.fields) |field| {
            try validateTypeApplicationArity(allocator, file, &decl, field.ty);
            try validateFieldOptionalPointerType(file, &decl, field.ty);
        }
        for (decl.aliases) |alias| try validateTypeApplicationArity(allocator, file, &decl, alias.target);
        for (decl.consts) |const_decl| try validateTypeApplicationArity(allocator, file, &decl, const_decl.ty);
    }
    for (file.interfaces) |decl| {
        var empty_fields: [0]Field = .{};
        var interface_scope = Struct{
            .name = decl.name,
            .fields = empty_fields[0..],
            .consts = decl.consts,
            .aliases = decl.aliases,
        };
        for (decl.superclasses) |superclass| {
            try validateTypeApplicationArity(allocator, file, &interface_scope, superclass);
            try validateInterfaceSuperclass(file, &interface_scope, superclass);
        }
        for (decl.aliases) |alias| try validateTypeApplicationArity(allocator, file, &interface_scope, alias.target);
        for (decl.consts) |const_decl| try validateTypeApplicationArity(allocator, file, &interface_scope, const_decl.ty);
        for (decl.methods) |method| {
            try validateRawTypeApplicationArity(allocator, file, &interface_scope, method.params_type);
            try validateRawTypeApplicationArity(allocator, file, &interface_scope, method.results_type);
            for (method.param_fields) |field| try validateRawTypeApplicationArity(allocator, file, &interface_scope, field.ty);
            for (method.result_fields) |field| try validateRawTypeApplicationArity(allocator, file, &interface_scope, field.ty);
        }
    }
}

pub fn validateFileSimpleNamedTypes(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    for (file.aliases) |alias| try validateTypeReference(allocator, file, null, alias.target);
    for (file.consts) |decl| try validateTypeReference(allocator, file, null, decl.ty);
    for (file.annotations) |decl| {
        var empty_fields: [0]Field = .{};
        var annotation_scope_storage: Struct = undefined;
        const annotation_scope = ownerNameScope(file, annotationOwnerName(decl.name), empty_fields[0..], &annotation_scope_storage);
        try validateTypeReference(allocator, file, annotation_scope, decl.ty);
    }
    for (file.structs) |decl| {
        for (decl.fields) |field| try validateTypeReference(allocator, file, &decl, field.ty);
        for (decl.aliases) |alias| try validateTypeReference(allocator, file, &decl, alias.target);
        for (decl.consts) |const_decl| try validateTypeReference(allocator, file, &decl, const_decl.ty);
    }
    for (file.interfaces) |decl| {
        var empty_fields: [0]Field = .{};
        var interface_scope = Struct{
            .name = decl.name,
            .fields = empty_fields[0..],
            .consts = decl.consts,
            .aliases = decl.aliases,
        };
        for (decl.aliases) |alias| try validateTypeReference(allocator, file, &interface_scope, alias.target);
        for (decl.consts) |const_decl| try validateTypeReference(allocator, file, &interface_scope, const_decl.ty);
        for (decl.methods) |method| {
            for (method.param_fields) |field| try validateMethodFieldTypeReference(allocator, file, &interface_scope, method.parameters, field.ty);
            for (method.result_fields) |field| try validateMethodFieldTypeReference(allocator, file, &interface_scope, method.parameters, field.ty);
        }
    }
}

pub fn validateFieldOptionalPointerType(file: *const File, scope: ?*const Struct, ty: Type) LayoutError!void {
    switch (resolveTypeScoped(file, scope, ty)) {
        .optional => |child| if (!typeCanBeOptionalPointerField(file, scope, child.*)) return error.UnsupportedType,
        .list => |child| try validateFieldOptionalPointerType(file, scope, child.*),
        else => {},
    }
}

pub fn typeCanBeOptionalPointerField(file: *const File, scope: ?*const Struct, ty: Type) bool {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => true,
        .named => |name| findEnum(file, name) == null,
        else => false,
    };
}

pub fn validateFileConstReferenceCycles(file: *const File) LayoutError!void {
    for (file.consts) |*decl| {
        try validateConstReferenceCycleDecl(file, null, null, decl.name, decl, 0);
    }
    for (file.structs) |*owner| {
        for (owner.consts) |*decl| {
            try validateConstReferenceCycleDecl(file, owner.name, owner.name, decl.name, decl, 0);
        }
    }
    for (file.interfaces) |*owner| {
        for (owner.consts) |*decl| {
            try validateConstReferenceCycleDecl(file, owner.name, owner.name, decl.name, decl, 0);
        }
    }
}

pub fn validateConstReferenceCycleDecl(file: *const File, owner_name: ?[]const u8, root_owner: ?[]const u8, root_name: []const u8, decl: *const ConstDecl, depth: usize) LayoutError!void {
    if (depth >= 32) return error.UnsupportedType;

    var empty_fields: [0]Field = .{};
    var scope_storage: Struct = undefined;
    const scope = ownerNameScope(file, owner_name, empty_fields[0..], &scope_storage);
    if (!constDeclLiteralCanBeReference(file, scope, decl)) return;

    const raw = std.mem.trim(u8, decl.literal, " \t\r\n");
    const next_decl = findConstReference(file, scope, raw) orelse return;
    const next_owner = constDeclOwnerName(file, next_decl);
    if (std.mem.eql(u8, next_decl.name, root_name) and sameOptionalTypeName(next_owner, root_owner)) return error.UnsupportedType;
    try validateConstReferenceCycleDecl(file, next_owner, root_owner, root_name, next_decl, depth + 1);
}

pub fn constDeclLiteralCanBeReference(file: *const File, scope: ?*const Struct, decl: *const ConstDecl) bool {
    if (decl.is_embed) return false;
    const literal = std.mem.trim(u8, decl.literal, " \t\r\n");
    if (literal.len == 0) return false;
    const resolved_ty = nonNullResolvedDefaultType(file, scope, decl.ty);
    if (decl.literal_is_string and (resolved_ty == .text or resolved_ty == .data)) return false;
    if (decl.is_hex_data and resolved_ty == .data) return false;
    if (defaultLiteralIsValidBareLiteral(file, scope, decl.ty, literal)) return false;
    return defaultLiteralCanBeReference(literal);
}

pub fn ownerNameScope(file: *const File, owner_name: ?[]const u8, empty_fields: []Field, storage: *Struct) ?*const Struct {
    const owner = owner_name orelse return null;
    if (findStructDirect(file, owner)) |decl| return decl;
    if (findInterfaceDirect(file, owner)) |decl| {
        storage.* = .{ .name = decl.name, .fields = empty_fields, .consts = decl.consts, .aliases = decl.aliases };
        return storage;
    }
    return null;
}

pub fn sameOptionalTypeName(lhs: ?[]const u8, rhs: ?[]const u8) bool {
    if (lhs == null and rhs == null) return true;
    if (lhs) |l| if (rhs) |r| return typeNameEqualsCanonical(l, r);
    return false;
}

pub fn validateFileAggregateDefaults(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    for (file.consts) |decl| try validateConstAggregateDefault(allocator, file, null, decl);
    for (file.structs) |decl| {
        for (decl.fields) |field| try validateFieldDefaultValue(allocator, file, &decl, field);
        for (decl.consts) |const_decl| try validateConstAggregateDefault(allocator, file, &decl, const_decl);
    }
    for (file.interfaces) |decl| {
        var empty_fields: [0]Field = .{};
        var interface_scope = Struct{
            .name = decl.name,
            .fields = empty_fields[0..],
            .consts = decl.consts,
            .aliases = decl.aliases,
        };
        for (decl.consts) |const_decl| try validateConstAggregateDefault(allocator, file, &interface_scope, const_decl);
        for (decl.methods) |method| {
            for (method.param_fields) |field| try validateMethodFieldDefaultValue(allocator, file, &interface_scope, field);
            for (method.result_fields) |field| try validateMethodFieldDefaultValue(allocator, file, &interface_scope, field);
        }
    }
}

pub fn validateFieldDefaultValue(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, field: Field) LayoutError!void {
    const literal = std.mem.trim(u8, field.default_expression, " \t\r\n");
    if (literal.len == 0) return;
    if (defaultLiteralIsValidBareLiteral(file, scope, field.ty, literal)) {
        // Bare enum value names share the same namespace as const references in
        // generated defaults.  Prefer the literal interpretation so a const
        // named `blue` does not shadow enum value `blue` for a `Color` field.
    } else if (findConstReference(file, scope, literal)) |decl| {
        const field_ty = nonNullDefaultType(resolveTypeScoped(file, scope, field.ty));
        const const_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
        const field_owner = if (scope) |owner| owner.name else null;
        if (!defaultConstTypeCompatibleScoped(file, field_owner, constDeclOwnerName(file, decl), field_ty, const_ty)) return error.UnexpectedToken;
    } else if (defaultLiteralCanBeReference(literal)) {
        return error.UnexpectedToken;
    }
    try validateTypeAggregateDefault(allocator, file, scope, field.ty, field.default_expression);
}

pub fn defaultLiteralIsValidBareLiteral(file: *const File, scope: ?*const Struct, ty: Type, literal: []const u8) bool {
    const resolved_ty = nonNullResolvedDefaultType(file, scope, ty);
    if (std.mem.eql(u8, literal, "null") and typeAcceptsNullPointerDefault(file, resolved_ty)) return true;
    if (std.mem.eql(u8, literal, "void") and typeAcceptsVoidPointerDefault(file, resolved_ty)) return true;
    return switch (resolved_ty) {
        .void => std.mem.eql(u8, literal, "void"),
        .bool => parseBoolLiteral(literal) != null,
        .float32 => parseFloatLiteral(f32, literal) != null,
        .float64 => parseFloatLiteral(f64, literal) != null,
        .named => |type_name| if (findEnumRelative(file, if (scope) |owner| owner.name else null, type_name)) |enum_decl| enumLiteralOrdinal(enum_decl, literal) != null else false,
        else => false,
    };
}

pub fn defaultConstTypeCompatibleScoped(file: *const File, field_owner: ?[]const u8, const_owner: ?[]const u8, field_ty: Type, const_ty: Type) bool {
    return defaultConstTypeCompatibleScopedDepth(file, field_owner, const_owner, field_ty, const_ty, 0);
}

pub fn defaultConstTypeCompatibleScopedDepth(file: *const File, field_owner: ?[]const u8, const_owner: ?[]const u8, field_ty: Type, const_ty: Type, depth: usize) bool {
    if (depth >= 32) return false;
    const non_null_field_ty = nonNullDefaultType(field_ty);
    const non_null_const_ty = nonNullDefaultType(const_ty);

    if (non_null_field_ty == .named) {
        if (resolveNamedAliasInOwnerScope(file, field_owner, non_null_field_ty.named, 0)) |resolved| {
            if (!typesEqual(resolved, non_null_field_ty)) {
                return defaultConstTypeCompatibleScopedDepth(file, field_owner, const_owner, resolved, non_null_const_ty, depth + 1);
            }
        }
    }
    if (non_null_const_ty == .named) {
        if (resolveNamedAliasInOwnerScope(file, const_owner, non_null_const_ty.named, 0)) |resolved| {
            if (!typesEqual(resolved, non_null_const_ty)) {
                return defaultConstTypeCompatibleScopedDepth(file, field_owner, const_owner, non_null_field_ty, resolved, depth + 1);
            }
        }
    }

    if (typesEqual(non_null_field_ty, non_null_const_ty)) return true;
    return switch (non_null_field_ty) {
        .named => |field_name| switch (non_null_const_ty) {
            .named => |const_name| blk: {
                if (isEnumLikeNameRelative(file, field_owner, field_name) and isEnumLikeNameRelative(file, const_owner, const_name)) break :blk true;
                if (isInterfaceLikeNameRelative(file, field_owner, field_name) and isInterfaceLikeNameRelative(file, const_owner, const_name)) break :blk true;
                if (isStructLikeNameRelative(file, field_owner, field_name) and isStructLikeNameRelative(file, const_owner, const_name)) break :blk true;
                break :blk false;
            },
            .capability => isInterfaceLikeNameRelative(file, field_owner, field_name),
            .any_pointer, .any_struct, .any_list => isStructLikeNameRelative(file, field_owner, field_name) or isInterfaceLikeNameRelative(file, field_owner, field_name),
            else => false,
        },
        .any_pointer => true,
        .any_struct => switch (non_null_const_ty) {
            .any_struct => true,
            .named => |name| isStructLikeNameRelative(file, const_owner, name),
            else => false,
        },
        .any_list => switch (non_null_const_ty) {
            .any_list, .list => true,
            else => false,
        },
        .capability => switch (non_null_const_ty) {
            .capability => true,
            .named => |name| isInterfaceLikeNameRelative(file, const_owner, name),
            else => false,
        },
        .list => |field_child| switch (non_null_const_ty) {
            .list => |const_child| defaultConstTypeCompatibleScopedDepth(file, field_owner, const_owner, field_child.*, const_child.*, depth + 1),
            else => false,
        },
        else => false,
    };
}

pub fn isEnumLikeNameRelative(file: *const File, owner_name: ?[]const u8, name: []const u8) bool {
    if (findEnum(file, name) != null) return true;
    if (owner_name) |owner| return isEnumDirectInOwnerScope(file, owner, name);
    return false;
}

pub fn isInterfaceLikeNameRelative(file: *const File, owner_name: ?[]const u8, name: []const u8) bool {
    if (findInterface(file, name) != null) return true;
    if (owner_name) |owner| return isInterfaceDirectInOwnerScope(file, owner, name);
    return false;
}

pub fn isStructLikeNameRelative(file: *const File, owner_name: ?[]const u8, name: []const u8) bool {
    if (isStructLikeName(file, name)) return true;
    if (owner_name) |owner| return isStructDirectInOwnerScope(file, owner, name);
    return false;
}

pub fn defaultConstTypeCompatible(file: *const File, field_ty: Type, const_ty: Type) bool {
    return defaultConstTypeCompatibleScoped(file, null, null, field_ty, const_ty);
}

pub fn validateInterfaceSuperclass(file: *const File, scope: *const Struct, superclass: Type) LayoutError!void {
    return switch (resolveTypeScoped(file, scope, superclass)) {
        .capability => error.UnsupportedType,
        .named => |name| {
            if (findInterfaceDirect(file, name) != null) return;
            if (isImportedTypeName(file, name)) return;
            return error.UnsupportedType;
        },
        else => error.UnsupportedType,
    };
}

pub fn validateFileAliasCycles(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    for (file.aliases) |alias| {
        if (try aliasTargetReferencesAlias(allocator, file, null, alias.name, alias.target, 0)) return error.UnsupportedType;
    }
    for (file.structs) |decl| {
        for (decl.aliases) |alias| {
            if (try aliasTargetReferencesAlias(allocator, file, decl.name, alias.name, alias.target, 0)) return error.UnsupportedType;
        }
    }
    for (file.interfaces) |decl| {
        for (decl.aliases) |alias| {
            if (try aliasTargetReferencesAlias(allocator, file, decl.name, alias.name, alias.target, 0)) return error.UnsupportedType;
        }
    }
}

pub fn aliasTargetReferencesAlias(allocator: std.mem.Allocator, file: *const File, owner_name: ?[]const u8, alias_name: []const u8, target: Type, depth: usize) LayoutError!bool {
    if (depth >= 32) return error.UnsupportedType;
    switch (target) {
        .named => |raw| {
            const trimmed = std.mem.trim(u8, raw, " \t\r\n");
            const head = try aliasReferenceHeadAlloc(allocator, trimmed);
            defer allocator.free(head);
            if (std.mem.eql(u8, head, alias_name)) return true;

            if (typeApplicationOpen(trimmed) != null) {
                const args = (try splitTypeApplicationArgsAlloc(allocator, trimmed)) orelse return false;
                defer {
                    for (args) |*arg| arg.deinit(allocator);
                    allocator.free(args);
                }
                for (args) |arg| {
                    if (try aliasTargetReferencesAlias(allocator, file, owner_name, alias_name, arg, depth + 1)) return true;
                }
            }

            if (findAliasTargetInOwnerScope(file, owner_name, head)) |next_target| {
                return aliasTargetReferencesAlias(allocator, file, owner_name, alias_name, next_target, depth + 1);
            }
        },
        .list, .optional => |child| return aliasTargetReferencesAlias(allocator, file, owner_name, alias_name, child.*, depth + 1),
        else => {},
    }
    return false;
}

pub fn aliasReferenceHeadAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    const absolute = if (std.mem.startsWith(u8, raw, ".")) raw[1..] else raw;
    const without_args = if (typeApplicationOpen(absolute)) |open| absolute[0..open] else absolute;
    const head = if (firstTopLevelDot(without_args)) |dot| without_args[0..dot] else without_args;
    return canonicalTypeNameAlloc(allocator, head);
}

pub fn findAliasTargetInOwnerScope(file: *const File, owner_name: ?[]const u8, name: []const u8) ?Type {
    var current = owner_name;
    while (current) |owner| {
        if (findStructDirect(file, owner)) |decl| {
            if (declHasParameter(decl.parameters, name)) return null;
            if (findAliasTargetInList(decl.aliases, name)) |target| return target;
        }
        if (findInterfaceDirect(file, owner)) |decl| {
            if (declHasParameter(decl.parameters, name)) return null;
            if (findAliasTargetInList(decl.aliases, name)) |target| return target;
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return findAliasTargetInList(file.aliases, name);
}

pub fn findAliasTargetInList(aliases: []const AliasDecl, name: []const u8) ?Type {
    for (aliases) |alias| {
        if (std.mem.eql(u8, alias.name, name)) return alias.target;
    }
    return null;
}

pub fn validateConstAggregateDefault(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: ConstDecl) LayoutError!void {
    if (decl.is_embed) return;
    try validateConstReferenceDefaultValue(file, scope, decl);
    try validateTypeAggregateDefault(allocator, file, scope, decl.ty, decl.literal);
}

pub fn validateConstReferenceDefaultValue(file: *const File, scope: ?*const Struct, decl: ConstDecl) LayoutError!void {
    const literal = std.mem.trim(u8, decl.literal, " \t\r\n");
    if (literal.len == 0) return;
    const resolved_ty = nonNullResolvedDefaultType(file, scope, decl.ty);
    if (decl.literal_is_string and (resolved_ty == .text or resolved_ty == .data)) return;
    if (decl.is_hex_data and resolved_ty == .data) return;
    if (std.mem.eql(u8, literal, "null") and typeAcceptsNullPointerDefault(file, resolved_ty)) return;
    if (std.mem.eql(u8, literal, "void") and typeAcceptsVoidPointerDefault(file, resolved_ty)) return;
    try validateReferenceLikeDefaultLiteral(file, scope, decl.ty, literal);
}

pub fn validateReferenceLikeDefaultLiteral(file: *const File, scope: ?*const Struct, ty: Type, literal: []const u8) LayoutError!void {
    if (defaultLiteralIsValidBareLiteral(file, scope, ty, literal)) return;
    const resolved_ty = nonNullResolvedDefaultType(file, scope, ty);
    if (findConstReference(file, scope, literal)) |referenced_decl| {
        const referenced_ty = nonNullDefaultType(resolveConstDeclType(file, scope, referenced_decl));
        const owner_name = if (scope) |owner| owner.name else null;
        if (!defaultConstTypeCompatibleScoped(file, owner_name, constDeclOwnerName(file, referenced_decl), resolved_ty, referenced_ty)) return error.UnexpectedToken;
        return;
    }
    if (defaultLiteralCanBeReference(literal)) return error.UnexpectedToken;
}

pub fn validateMethodFieldDefaultValue(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, field: MethodField) LayoutError!void {
    const literal = field.default_literal orelse return;
    var ty = try parseTypeArgAlloc(allocator, field.ty);
    defer ty.deinit(allocator);
    if (defaultLiteralIsValidBareLiteral(file, scope, ty, literal)) {
        // Match struct-field default resolution: bare enum values and scalar
        // literals should not be interpreted as const references with the same
        // spelling.
    } else if (findConstReference(file, scope, literal)) |decl| {
        const field_ty = nonNullDefaultType(resolveTypeScoped(file, scope, ty));
        const const_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
        const field_owner = if (scope) |owner| owner.name else null;
        if (!defaultConstTypeCompatibleScoped(file, field_owner, constDeclOwnerName(file, decl), field_ty, const_ty)) return error.UnexpectedToken;
    } else if (defaultLiteralCanBeReference(literal)) {
        return error.UnexpectedToken;
    }
    try validateTypeAggregateDefault(allocator, file, scope, ty, literal);
}

pub fn validateTypeAggregateDefault(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type, literal: []const u8) LayoutError!void {
    const literal_raw = std.mem.trim(u8, literal, " \t\r\n");
    if (literal_raw.len == 0) return;
    const const_ref = findConstReference(file, scope, literal_raw);
    const raw = std.mem.trim(u8, if (const_ref != null) resolveConstReferenceLiteral(file, scope, literal_raw) else literal_raw, " \t\r\n");
    if (raw.len == 0) return;

    switch (resolveTypeScoped(file, scope, ty)) {
        .optional => |child| {
            if (std.mem.eql(u8, raw, "null")) return;
            try validateTypeAggregateDefault(allocator, file, scope, child.*, if (const_ref != null) literal_raw else raw);
        },
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => try validateReferenceLikeDefaultLiteral(file, scope, ty, raw),
        .text, .data => {},
        .list => |child| {
            if (raw[0] != '[') {
                if (const_ref) |decl| {
                    const resolved_decl_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
                    if (resolved_decl_ty != .list) return error.UnexpectedToken;
                }
                return;
            }
            const items = parseInlineConstListElementsAlloc(allocator, raw) catch |err| switch (err) {
                error.UnexpectedToken, error.InvalidToken => return error.UnexpectedToken,
                else => return err,
            };
            defer allocator.free(items);
            for (items) |item| {
                const split = Parser.splitDefaultExpressionAndAnnotations(item);
                try Parser.validateAnnotationSuffix(split.annotations);
                try validateTypeAggregateDefault(allocator, file, scope, child.*, split.default_expression);
            }
        },
        .named => |type_name| {
            const owner_name = if (scope) |owner| owner.name else null;
            var owned_names = std.ArrayList([]const u8).empty;
            defer {
                for (owned_names.items) |name| allocator.free(name);
                owned_names.deinit(allocator);
            }
            if (findEnumRelative(file, owner_name, type_name)) |enum_decl| {
                if (enumLiteralOrdinal(enum_decl, raw) != null or enumLiteralOrdinal(enum_decl, literal_raw) != null) return;
                if (const_ref) |decl| {
                    const const_owner = constDeclOwnerName(file, decl);
                    const resolved_decl_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
                    if (resolved_decl_ty == .named and findEnumRelative(file, const_owner, resolved_decl_ty.named) != null) return;
                }
                if (std.mem.indexOfScalar(u8, type_name, '.') != null) return;
                return error.UnexpectedToken;
            }
            const struct_decl = findStructDirect(file, type_name) orelse {
                if (try resolveQualifiedAliasSuffixAlloc(allocator, file, scope, type_name, &owned_names)) |resolved_alias_ty_const| {
                    var resolved_alias_ty = resolved_alias_ty_const;
                    defer resolved_alias_ty.deinit(allocator);
                    try validateTypeAggregateDefault(allocator, file, scope, resolved_alias_ty, raw);
                    return;
                }
                if (try resolveAppliedAliasInScopeAlloc(allocator, file, scope, type_name, &owned_names)) |resolved_alias_ty_const| {
                    var resolved_alias_ty = resolved_alias_ty_const;
                    defer resolved_alias_ty.deinit(allocator);
                    try validateTypeAggregateDefault(allocator, file, scope, resolved_alias_ty, raw);
                    return;
                }
                if (try resolveTypeApplicationSuffixAliasAlloc(allocator, file, scope, type_name, &owned_names)) |resolved_alias_ty_const| {
                    var resolved_alias_ty = resolved_alias_ty_const;
                    defer resolved_alias_ty.deinit(allocator);
                    try validateTypeAggregateDefault(allocator, file, scope, resolved_alias_ty, raw);
                    return;
                }
                if (parameterNameInScope(file, scope, type_name)) {
                    if (std.mem.eql(u8, raw, "null") or std.mem.eql(u8, raw, "void") or raw[0] == '(' or raw[0] == '[' or const_ref != null) return;
                    return error.UnexpectedToken;
                }
                if (std.mem.eql(u8, raw, "null") or std.mem.eql(u8, raw, "void")) return;
                if (const_ref) |decl| {
                    const resolved_decl_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
                    if (resolved_decl_ty == .any_pointer or
                        resolved_decl_ty == .any_struct or
                        resolved_decl_ty == .any_list or
                        resolved_decl_ty == .capability)
                    {
                        return;
                    }
                }
                return error.UnexpectedToken;
            };
            var bindings = try typeApplicationBindingsAlloc(allocator, file, scope, type_name, struct_decl);
            defer bindings.deinit(allocator);
            const args = bindings.args;
            const parameters = bindings.parameters;
            if (std.mem.eql(u8, raw, "null")) return;
            var applied_scope_storage: Struct = undefined;
            const validation_scope: *const Struct = if (args.len != 0) blk: {
                applied_scope_storage = struct_decl.*;
                applied_scope_storage.name = type_name;
                break :blk &applied_scope_storage;
            } else struct_decl;
            if (raw[0] != '(') {
                if (const_ref) |decl| {
                    const resolved_decl_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
                    if (resolved_decl_ty != .named or findStructDirect(file, resolved_decl_ty.named) == null) return error.UnexpectedToken;
                    return;
                }
                if (struct_decl.fields.len == 0) return error.UnexpectedToken;
                var validation_ty = if (args.len != 0)
                    try substituteGenericTypeAlloc(allocator, &owned_names, struct_decl.fields[0].ty, parameters, args)
                else
                    struct_decl.fields[0].ty;
                defer if (args.len != 0) validation_ty.deinit(allocator);
                try validateTypeAggregateDefault(allocator, file, validation_scope, validation_ty, raw);
                return;
            }
            const fields = try parseConstStructFieldsAlloc(allocator, raw);
            defer allocator.free(fields);
            for (fields) |const_field| {
                const schema_field = findStructFieldByNameOrGroupFirst(struct_decl, const_field.name) orelse return error.UnexpectedToken;
                var validation_ty = if (args.len != 0)
                    try substituteGenericTypeAlloc(allocator, &owned_names, schema_field.ty, parameters, args)
                else
                    schema_field.ty;
                defer if (args.len != 0) validation_ty.deinit(allocator);
                try validateTypeAggregateDefault(allocator, file, validation_scope, validation_ty, const_field.literal);
            }
        },
        .any_pointer => try validateAnyPointerLikeDefault(file, scope, raw, const_ref, .any),
        .any_struct => try validateAnyPointerLikeDefault(file, scope, raw, const_ref, .struct_ptr),
        .any_list => try validateAnyPointerLikeDefault(file, scope, raw, const_ref, .list),
        .capability => try validateAnyPointerLikeDefault(file, scope, raw, const_ref, .capability),
    }
}

pub fn resolveTypeApplicationSuffixAliasAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    type_name: []const u8,
    owned_names: *std.ArrayList([]const u8),
) LayoutError!?Type {
    const open = typeApplicationOpen(type_name) orelse return null;
    const close = (try matchingParen(type_name, open)) orelse return null;
    var suffix_start = try skipTriviaIndex(type_name, close + 1);
    if (suffix_start >= type_name.len or type_name[suffix_start] != '.') return null;
    suffix_start += 1;
    suffix_start = try skipTriviaIndex(type_name, suffix_start);
    if (suffix_start >= type_name.len) return null;

    const raw_base = std.mem.trim(u8, type_name[0..open], " \t\r\n");
    const base = try canonicalTypeNameAlloc(allocator, raw_base);
    defer allocator.free(base);
    const owner_decl = findStructDirect(file, base) orelse blk: {
        if (scope) |owner| break :blk findStructInOwnerScope(file, owner.name, base);
        break :blk null;
    } orelse return null;
    const args = (try splitTypeApplicationArgsAlloc(allocator, type_name)) orelse return null;
    defer {
        for (args) |*arg| arg.deinit(allocator);
        allocator.free(args);
    }
    return resolveAliasSuffixAlloc(allocator, file, scope, owner_decl.name, type_name[0 .. close + 1], owner_decl.aliases, owner_decl.parameters, args, type_name[suffix_start..], owned_names);
}

pub fn resolveAppliedAliasInScopeAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    type_name: []const u8,
    owned_names: *std.ArrayList([]const u8),
) LayoutError!?Type {
    var current = if (scope) |owner| owner.name else return null;
    while (true) {
        const owner_decl = findStructDirect(file, current) orelse {
            current = if (lastTopLevelDot(current)) |dot| current[0..dot] else return null;
            continue;
        };
        if (try splitTypeApplicationArgsAlloc(allocator, current)) |args| {
            defer {
                for (args) |*arg| arg.deinit(allocator);
                allocator.free(args);
            }
            if (try resolveAliasSuffixAlloc(allocator, file, scope, owner_decl.name, current, owner_decl.aliases, owner_decl.parameters, args, type_name, owned_names)) |resolved| return resolved;
        } else {
            if (try resolveAliasSuffixAlloc(allocator, file, scope, owner_decl.name, current, owner_decl.aliases, owner_decl.parameters, &.{}, type_name, owned_names)) |resolved| return resolved;
        }
        current = if (lastTopLevelDot(current)) |dot| current[0..dot] else return null;
    }
}

pub fn resolveAliasSuffixAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    owner_decl_name: []const u8,
    applied_owner_name: []const u8,
    aliases: []const AliasDecl,
    parameters: []const []const u8,
    args: []const Type,
    suffix: []const u8,
    owned_names: *std.ArrayList([]const u8),
) LayoutError!?Type {
    const dot = firstTopLevelDot(suffix);
    const raw_head = if (dot) |index| suffix[0..index] else suffix;
    const head_open = typeApplicationOpen(raw_head);
    const head = std.mem.trim(u8, if (head_open) |index| raw_head[0..index] else raw_head, " \t\r\n");
    const head_app = if (head_open) |index| raw_head[index..] else "";
    const tail = if (dot) |index| suffix[index + 1 ..] else "";
    const alias = findAliasDeclInList(aliases, head) orelse return null;
    var target_ty = try substituteGenericTypeAlloc(allocator, owned_names, alias.target, parameters, args);
    errdefer target_ty.deinit(allocator);
    target_ty = try prefixRelativeAliasTargetAlloc(allocator, file, owner_decl_name, applied_owner_name, target_ty, owned_names);
    if (head_app.len != 0) {
        const target_name = try schemaTypeNameAlloc(allocator, target_ty);
        defer allocator.free(target_name);
        target_ty.deinit(allocator);
        const applied_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ target_name, head_app });
        errdefer allocator.free(applied_name);
        try owned_names.append(allocator, applied_name);
        target_ty = .{ .named = applied_name };
    }
    if (tail.len == 0) return target_ty;

    const target_name = try schemaTypeNameAlloc(allocator, target_ty);
    defer allocator.free(target_name);
    target_ty.deinit(allocator);
    const combined = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ target_name, tail });
    errdefer allocator.free(combined);
    try owned_names.append(allocator, combined);
    if (try resolveTypeApplicationSuffixAliasAlloc(allocator, file, scope, combined, owned_names)) |resolved| return resolved;
    return .{ .named = combined };
}

pub fn resolveQualifiedAliasSuffixAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    type_name: []const u8,
    owned_names: *std.ArrayList([]const u8),
) LayoutError!?Type {
    const dot = firstTopLevelDot(type_name) orelse return null;
    const raw_owner = std.mem.trim(u8, type_name[0..dot], " \t\r\n");
    const suffix = std.mem.trim(u8, type_name[dot + 1 ..], " \t\r\n");
    if (suffix.len == 0) return null;
    const open = typeApplicationOpen(raw_owner);
    const raw_base = if (open) |index| std.mem.trim(u8, raw_owner[0..index], " \t\r\n") else raw_owner;
    const base = try canonicalTypeNameAlloc(allocator, raw_base);
    defer allocator.free(base);
    const owner_decl = findStructDirect(file, base) orelse blk: {
        if (scope) |owner| break :blk findStructInOwnerScope(file, owner.name, base);
        break :blk null;
    } orelse return null;
    if (try splitTypeApplicationArgsAlloc(allocator, raw_owner)) |args| {
        defer {
            for (args) |*arg| arg.deinit(allocator);
            allocator.free(args);
        }
        return resolveAliasSuffixAlloc(allocator, file, scope, owner_decl.name, raw_owner, owner_decl.aliases, owner_decl.parameters, args, suffix, owned_names);
    }
    return resolveAliasSuffixAlloc(allocator, file, scope, owner_decl.name, raw_owner, owner_decl.aliases, owner_decl.parameters, &.{}, suffix, owned_names);
}

pub fn namedTypeResolvesToGenericParameter(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8) LayoutError!bool {
    var owned_names = std.ArrayList([]const u8).empty;
    defer {
        for (owned_names.items) |name| allocator.free(name);
        owned_names.deinit(allocator);
    }
    const resolved_const =
        (try resolveAppliedAliasInScopeAlloc(allocator, file, scope, type_name, &owned_names)) orelse
        (try resolveQualifiedAliasSuffixAlloc(allocator, file, scope, type_name, &owned_names)) orelse
        (try resolveTypeApplicationSuffixAliasAlloc(allocator, file, scope, type_name, &owned_names)) orelse
        return false;
    var resolved = resolved_const;
    defer resolved.deinit(allocator);
    return switch (resolved) {
        .named => |name| parameterNameInScope(file, scope, name) or
            (findEnumRelative(file, if (scope) |owner| owner.name else null, name) == null and
                findInterface(file, name) == null and
                !isStructLikeNameRelative(file, if (scope) |owner| owner.name else null, name)),
        else => true,
    };
}

pub fn effectiveNamedTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8) LayoutError![]const u8 {
    var owned_names = std.ArrayList([]const u8).empty;
    defer {
        for (owned_names.items) |name| allocator.free(name);
        owned_names.deinit(allocator);
    }
    const resolved_const =
        (try resolveAppliedAliasInScopeAlloc(allocator, file, scope, type_name, &owned_names)) orelse
        (try resolveQualifiedAliasSuffixAlloc(allocator, file, scope, type_name, &owned_names)) orelse
        (try resolveTypeApplicationSuffixAliasAlloc(allocator, file, scope, type_name, &owned_names)) orelse
        return allocator.dupe(u8, type_name);
    var resolved = resolved_const;
    defer resolved.deinit(allocator);
    return switch (resolved) {
        .named => |name| allocator.dupe(u8, name),
        else => allocator.dupe(u8, type_name),
    };
}

pub fn prefixRelativeAliasTargetAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    owner_decl_name: []const u8,
    applied_owner_name: []const u8,
    ty: Type,
    owned_names: *std.ArrayList([]const u8),
) LayoutError!Type {
    if (ty != .named) return ty;
    const name = ty.named;
    if (name.len == 0 or name[0] == '.') return ty;
    const head = try aliasReferenceHeadAlloc(allocator, name);
    defer allocator.free(head);
    if (findStructInOwnerScope(file, owner_decl_name, head) == null and
        findInterfaceInOwnerScope(file, owner_decl_name, head) == null and
        !isEnumDirectInOwnerScope(file, owner_decl_name, head) and
        !isAnnotationDirectInOwnerScope(file, owner_decl_name, head))
    {
        return ty;
    }
    const prefixed = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ applied_owner_name, name });
    errdefer allocator.free(prefixed);
    try owned_names.append(allocator, prefixed);
    return .{ .named = prefixed };
}

pub fn findAliasDeclInList(aliases: []const AliasDecl, name: []const u8) ?AliasDecl {
    for (aliases) |alias| {
        if (std.mem.eql(u8, alias.name, name)) return alias;
    }
    return null;
}

pub const TypeApplicationBindings = struct {
    parameters: []const []const u8,
    args: []Type,

    pub fn deinit(self: *TypeApplicationBindings, allocator: std.mem.Allocator) void {
        allocator.free(self.parameters);
        for (self.args) |*arg| arg.deinit(allocator);
        allocator.free(self.args);
        self.* = undefined;
    }
};

pub fn typeApplicationBindingsAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, fallback_decl: *const Struct) LayoutError!TypeApplicationBindings {
    var parameters = std.ArrayList([]const u8).empty;
    errdefer parameters.deinit(allocator);
    var args = std.ArrayList(Type).empty;
    errdefer {
        for (args.items) |*arg| arg.deinit(allocator);
        args.deinit(allocator);
    }

    var owner_name = if (scope) |owner| owner.name else null;
    var current_decl: ?*const Struct = null;
    var start: usize = 0;
    while (start < type_name.len) {
        const rest = type_name[start..];
        const dot = firstTopLevelDot(rest);
        const segment = std.mem.trim(u8, if (dot) |index| rest[0..index] else rest, " \t\r\n");
        const open = typeApplicationOpen(segment);
        const raw_base = if (open) |index| std.mem.trim(u8, segment[0..index], " \t\r\n") else segment;
        const base = try canonicalTypeNameAlloc(allocator, raw_base);
        defer allocator.free(base);

        const decl = if (current_decl) |owner_decl|
            findStructInOwnerScope(file, owner_decl.name, base)
        else
            findStructDirect(file, base) orelse if (owner_name) |owner| findStructInOwnerScope(file, owner, base) else null;
        if (decl) |resolved_decl| {
            if (open != null) {
                try parameters.appendSlice(allocator, resolved_decl.parameters);
                if (try splitTypeApplicationArgsAlloc(allocator, segment)) |segment_args| {
                    defer {
                        for (segment_args) |*arg| arg.deinit(allocator);
                        allocator.free(segment_args);
                    }
                    for (segment_args) |*arg| {
                        try args.append(allocator, arg.*);
                        arg.* = .void;
                    }
                }
            }
            current_decl = resolved_decl;
            owner_name = resolved_decl.name;
        }

        if (dot) |index| {
            start += index + 1;
        } else {
            break;
        }
    }

    if (parameters.items.len == 0 and args.items.len == 0 and fallback_decl.parameters.len != 0) {
        try parameters.appendSlice(allocator, fallback_decl.parameters);
    }
    return .{
        .parameters = try parameters.toOwnedSlice(allocator),
        .args = try args.toOwnedSlice(allocator),
    };
}

pub fn validateAnyPointerLikeDefault(file: *const File, scope: ?*const Struct, raw: []const u8, const_ref: ?*const ConstDecl, comptime want: enum { any, struct_ptr, list, capability }) LayoutError!void {
    if (std.mem.eql(u8, raw, "null")) return;
    if (std.mem.eql(u8, raw, "void") and want != .list and want != .struct_ptr) return;

    const decl = const_ref orelse return error.UnexpectedToken;
    const const_owner = constDeclOwnerName(file, decl);
    const resolved_ty = nonNullDefaultType(resolveConstDeclType(file, scope, decl));
    switch (want) {
        .any => switch (resolved_ty) {
            .any_pointer, .any_struct, .any_list, .capability, .list => return,
            .named => |type_name| if (findEnum(file, type_name) == null) return,
            else => {},
        },
        .struct_ptr => switch (resolved_ty) {
            .any_struct => return,
            .named => |type_name| if (findEnum(file, type_name) == null and
                findInterface(file, type_name) == null and
                (isStructLikeName(file, type_name) or (const_owner != null and isStructLikeNameRelative(file, const_owner, type_name)))) return,
            else => {},
        },
        .list => switch (resolved_ty) {
            .any_list, .list => return,
            else => {},
        },
        .capability => switch (resolved_ty) {
            .capability => return,
            .named => |type_name| if (findInterface(file, type_name) != null or
                (const_owner != null and isInterfaceLikeNameRelative(file, const_owner, type_name))) return,
            else => {},
        },
    }
    return error.UnexpectedToken;
}

pub fn parameterNameInScope(file: *const File, scope: ?*const Struct, name: []const u8) bool {
    var current = if (scope) |decl| decl.name else return false;
    while (true) {
        if (findStructDirect(file, current)) |decl| {
            if (declHasParameter(decl.parameters, name)) return true;
        }
        if (findInterfaceDirect(file, current)) |decl| {
            if (declHasParameter(decl.parameters, name)) return true;
        }
        current = if (lastTopLevelDot(current)) |dot| current[0..dot] else return false;
    }
}

pub fn nonNullDefaultType(ty: Type) Type {
    return switch (ty) {
        .optional => |child| child.*,
        else => ty,
    };
}

pub fn nonNullResolvedDefaultType(file: *const File, scope: ?*const Struct, ty: Type) Type {
    return switch (ty) {
        .optional => |child| nonNullResolvedDefaultType(file, scope, child.*),
        else => resolveTypeScoped(file, scope, ty),
    };
}

pub fn findStructFieldByNameOrGroupFirst(decl: *const Struct, name: []const u8) ?*const Field {
    for (decl.fields) |*field| if (std.mem.eql(u8, field.name, name)) return field;
    for (decl.fields) |*field| {
        if (field.name.len > name.len + 1 and
            std.mem.startsWith(u8, field.name, name) and
            field.name[name.len] == '_')
        {
            return field;
        }
    }
    return null;
}
