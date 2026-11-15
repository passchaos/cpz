const std = @import("std");

const mod_parser = @import("parser.zig");
const mod_types = @import("types.zig");
const mod_validate = @import("validate.zig");

const Parser = mod_parser.Parser;
const skipLineCommentIndex = mod_parser.skipLineCommentIndex;
const skipRawSlashIndex = mod_parser.skipRawSlashIndex;
const skipRawStringOrCommentInPostLoop = mod_parser.skipRawStringOrCommentInPostLoop;
const skipTriviaIndex = mod_parser.skipTriviaIndex;
const AliasDecl = mod_types.AliasDecl;
const AnnotationDecl = mod_types.AnnotationDecl;
const AnnotationTargets = mod_types.AnnotationTargets;
const ConstDecl = mod_types.ConstDecl;
const EnumDecl = mod_types.EnumDecl;
const Error = mod_types.Error;
const File = mod_types.File;
const InterfaceDecl = mod_types.InterfaceDecl;
const LayoutError = mod_types.LayoutError;
const Struct = mod_types.Struct;
const Type = mod_types.Type;
const parameterNameInScope = mod_validate.parameterNameInScope;
const resolveAppliedAliasInScopeAlloc = mod_validate.resolveAppliedAliasInScopeAlloc;
const resolveQualifiedAliasSuffixAlloc = mod_validate.resolveQualifiedAliasSuffixAlloc;

pub const TypeClass = union(enum) {
    void,
    data: usize,
    pointer,
};

pub fn classify(file: *const File, ty: Type) LayoutError!TypeClass {
    return classifyScoped(file, null, ty);
}

pub fn classifyScoped(file: *const File, scope: ?*const Struct, ty: Type) LayoutError!TypeClass {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void => .void,
        .bool => .{ .data = 1 },
        .int8, .uint8 => .{ .data = 8 },
        .int16, .uint16 => .{ .data = 16 },
        .int32, .uint32, .float32 => .{ .data = 32 },
        .int64, .uint64, .float64 => .{ .data = 64 },
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => .pointer,
        .optional => .pointer,
        .named => |name| if (findEnumRelative(file, if (scope) |owner| owner.name else null, name) != null) .{ .data = 16 } else .pointer,
    };
}

pub fn findEnum(file: *const File, name: []const u8) ?*const EnumDecl {
    if (findEnumDirect(file, name)) |decl| return decl;
    const resolved = resolveNamedAlias(file, null, name, 0) orelse return null;
    return switch (resolved) {
        .named => |resolved_name| findEnumDirect(file, resolved_name),
        else => null,
    };
}

pub fn findEnumRelative(file: *const File, owner_name: ?[]const u8, name: []const u8) ?*const EnumDecl {
    if (findEnum(file, name)) |decl| return decl;
    var current = owner_name;
    while (current) |owner| {
        for (file.enums) |*decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + name.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], name))
            {
                return decl;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return null;
}

pub fn findEnumDirect(file: *const File, name: []const u8) ?*const EnumDecl {
    for (file.enums) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

pub fn findStructDirect(file: *const File, name: []const u8) ?*const Struct {
    for (file.structs) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

pub fn findStructInOwnerScope(file: *const File, owner_name: []const u8, name: []const u8) ?*const Struct {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.structs) |*decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + name.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], name))
            {
                return decl;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return null;
}

pub fn findInterface(file: *const File, name: []const u8) ?*const InterfaceDecl {
    if (findInterfaceDirect(file, name)) |decl| return decl;
    const resolved = resolveNamedAlias(file, null, name, 0) orelse return null;
    return switch (resolved) {
        .named => |resolved_name| findInterfaceDirect(file, resolved_name),
        .capability => &builtin_capability_interface,
        else => null,
    };
}

pub const builtin_capability_interface = InterfaceDecl{ .name = "Capability" };

pub fn findInterfaceDirect(file: *const File, name: []const u8) ?*const InterfaceDecl {
    for (file.interfaces) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

pub fn findInterfaceInOwnerScope(file: *const File, owner_name: []const u8, name: []const u8) ?*const InterfaceDecl {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.interfaces) |*decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + name.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], name))
            {
                return decl;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return null;
}

pub fn findAnnotationDirect(file: *const File, name: []const u8) ?*const AnnotationDecl {
    for (file.annotations) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

pub fn firstTopLevelDot(raw: []const u8) ?usize {
    var depth: usize = 0;
    var index: usize = 0;
    while (index < raw.len) {
        if (skipRawStringOrCommentInPostLoop(raw, &index) catch false) {
            index += 1;
            continue;
        }
        switch (raw[index]) {
            '(' => depth += 1,
            ')' => {
                if (depth != 0) depth -= 1;
            },
            '.' => {
                if (depth == 0) return index;
            },
            else => {},
        }
        index += 1;
    }
    return null;
}

pub fn lastTopLevelDot(raw: []const u8) ?usize {
    var depth: usize = 0;
    var found: ?usize = null;
    var index: usize = 0;
    while (index < raw.len) {
        if (skipRawStringOrCommentInPostLoop(raw, &index) catch false) {
            index += 1;
            continue;
        }
        switch (raw[index]) {
            '(' => depth += 1,
            ')' => {
                if (depth != 0) depth -= 1;
            },
            '.' => {
                if (depth == 0) found = index;
            },
            else => {},
        }
        index += 1;
    }
    return found;
}

pub fn typeNameEqualsCanonical(raw: []const u8, canonical: []const u8) bool {
    var canonical_index: usize = 0;
    var depth: usize = 0;
    var index: usize = 0;
    while (index < raw.len) {
        if (skipRawStringOrCommentInPostLoop(raw, &index) catch false) {
            index += 1;
            continue;
        }
        switch (raw[index]) {
            '(' => {
                depth += 1;
                index += 1;
                continue;
            },
            ')' => {
                if (depth == 0) return false;
                depth -= 1;
                index += 1;
                continue;
            },
            else => {},
        }
        if (depth != 0 or std.ascii.isWhitespace(raw[index])) {
            index += 1;
            continue;
        }
        if (canonical_index >= canonical.len or canonical[canonical_index] != raw[index]) return false;
        canonical_index += 1;
        index += 1;
    }
    return depth == 0 and canonical_index == canonical.len;
}

pub fn typeApplicationOpen(raw: []const u8) ?usize {
    var depth: usize = 0;
    var index: usize = 0;
    while (index < raw.len) {
        if (skipRawStringOrCommentInPostLoop(raw, &index) catch return null) {
            index += 1;
            continue;
        }
        switch (raw[index]) {
            '(' => {
                if (depth == 0) return index;
                depth += 1;
            },
            ')' => {
                if (depth != 0) depth -= 1;
            },
            else => {},
        }
        index += 1;
    }
    return null;
}

pub fn declarationParameterCount(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8) LayoutError!?usize {
    const open = typeApplicationOpen(type_name) orelse return null;
    const raw_base = std.mem.trim(u8, type_name[0..open], " \t\r\n");
    const base = try canonicalTypeNameAlloc(allocator, raw_base);
    defer allocator.free(base);
    const owner_name = if (scope) |owner| owner.name else null;
    if (resolveNamedAliasInOwnerScope(file, owner_name, base, 0)) |resolved| switch (resolved) {
        .named => |resolved_name| {
            // Aliases that already include type arguments are fully bound.  A
            // later `Alias(...)` application would otherwise append a second
            // argument list and silently use the original binding.
            if (typeApplicationOpen(resolved_name) != null) return 0;
            const suffix = type_name[open..];
            const expanded = try std.fmt.allocPrint(allocator, "{s}{s}", .{ resolved_name, suffix });
            defer allocator.free(expanded);
            if (try declarationParameterCount(allocator, file, scope, expanded)) |count| return count;
        },
        else => return 0,
    };
    if (owner_name) |owner| {
        if (declarationParameterCountInOwnerScope(file, owner, base)) |count| return count;
    }
    for (file.structs) |decl| {
        if (std.mem.eql(u8, base, decl.name)) return decl.parameters.len;
    }
    for (file.interfaces) |decl| {
        if (std.mem.eql(u8, base, decl.name)) return decl.parameters.len;
    }
    return null;
}

pub fn declarationParameterCountInOwnerScope(file: *const File, owner_name: []const u8, base: []const u8) ?usize {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.structs) |decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + base.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], base))
            {
                return decl.parameters.len;
            }
        }
        for (file.interfaces) |decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + base.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], base))
            {
                return decl.parameters.len;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return null;
}

pub fn validateRawTypeApplicationArity(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, raw: []const u8) LayoutError!void {
    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0) return;
    if (std.mem.startsWith(u8, trimmed, "?")) return validateRawTypeApplicationArity(allocator, file, scope, trimmed[1..]);
    const open = typeApplicationOpen(trimmed) orelse return;

    const args = (try splitTypeApplicationArgsAlloc(allocator, trimmed)) orelse return error.UnsupportedType;
    defer {
        for (args) |*arg| arg.deinit(allocator);
        allocator.free(args);
    }
    const raw_base = std.mem.trim(u8, trimmed[0..open], " \t\r\n");
    const base = try canonicalTypeNameAlloc(allocator, raw_base);
    defer allocator.free(base);
    if (std.mem.eql(u8, base, "List")) {
        if (args.len != 1) return error.UnsupportedType;
    } else if (isBuiltinTypeApplicationBase(base)) {
        return error.UnsupportedType;
    }
    if (isEnumTypeApplicationBase(file, scope, base)) return error.UnsupportedType;
    if (try declarationParameterCount(allocator, file, scope, trimmed)) |parameter_count| {
        if (args.len != parameter_count) return error.UnsupportedType;
    }
    for (args) |arg| try validateTypeApplicationArity(allocator, file, scope, arg);
}

pub fn isBuiltinTypeApplicationBase(name: []const u8) bool {
    return isBuiltinSchemaTypeName(name);
}

pub fn isBuiltinSchemaTypeName(name: []const u8) bool {
    return std.mem.eql(u8, name, "Void") or
        std.mem.eql(u8, name, "Bool") or
        std.mem.eql(u8, name, "Int8") or
        std.mem.eql(u8, name, "Int16") or
        std.mem.eql(u8, name, "Int32") or
        std.mem.eql(u8, name, "Int64") or
        std.mem.eql(u8, name, "UInt8") or
        std.mem.eql(u8, name, "UInt16") or
        std.mem.eql(u8, name, "UInt32") or
        std.mem.eql(u8, name, "UInt64") or
        std.mem.eql(u8, name, "Float32") or
        std.mem.eql(u8, name, "Float64") or
        std.mem.eql(u8, name, "Text") or
        std.mem.eql(u8, name, "Data") or
        std.mem.eql(u8, name, "AnyPointer") or
        std.mem.eql(u8, name, "AnyStruct") or
        std.mem.eql(u8, name, "AnyList") or
        std.mem.eql(u8, name, "Capability");
}

pub fn isEnumTypeApplicationBase(file: *const File, scope: ?*const Struct, base: []const u8) bool {
    if (findEnumDirect(file, base) != null) return true;
    if (scope) |owner| {
        if (isEnumDirectInOwnerScope(file, owner.name, base)) return true;
    }
    const owner_name = if (scope) |owner| owner.name else null;
    const resolved = resolveNamedAliasInOwnerScope(file, owner_name, base, 0) orelse return false;
    return switch (resolved) {
        .named => |name| findEnumDirect(file, name) != null,
        else => false,
    };
}

pub fn isEnumDirectInOwnerScope(file: *const File, owner_name: []const u8, base: []const u8) bool {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.enums) |decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + base.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], base))
            {
                return true;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return false;
}

pub fn isStructDirectInOwnerScope(file: *const File, owner_name: []const u8, base: []const u8) bool {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.structs) |decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + base.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], base))
            {
                return true;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return false;
}

pub fn isInterfaceDirectInOwnerScope(file: *const File, owner_name: []const u8, base: []const u8) bool {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.interfaces) |decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + base.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], base))
            {
                return true;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return false;
}

pub fn isAnnotationDirectInOwnerScope(file: *const File, owner_name: []const u8, base: []const u8) bool {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        for (file.annotations) |decl| {
            if (std.mem.startsWith(u8, decl.name, owner) and
                decl.name.len == owner.len + 1 + base.len and
                decl.name[owner.len] == '.' and
                std.mem.eql(u8, decl.name[owner.len + 1 ..], base))
            {
                return true;
            }
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return false;
}

pub fn validateTypeReference(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type) LayoutError!void {
    switch (ty) {
        .named => |name| try validateRawTypeReference(allocator, file, scope, name),
        .list, .optional => |child| try validateTypeReference(allocator, file, scope, child.*),
        else => {},
    }
}

pub fn validateTypeApplicationArity(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type) LayoutError!void {
    switch (ty) {
        .named => |name| try validateRawTypeApplicationArity(allocator, file, scope, name),
        .list, .optional => |child| try validateTypeApplicationArity(allocator, file, scope, child.*),
        else => {},
    }
}

pub fn validateRawTypeReference(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, raw: []const u8) LayoutError!void {
    try validateRawTypeApplicationArity(allocator, file, scope, raw);
    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0) return;
    if (std.mem.startsWith(u8, trimmed, "?")) return validateRawTypeReference(allocator, file, scope, trimmed[1..]);
    if (std.mem.startsWith(u8, trimmed, "import")) return;
    if (typeApplicationOpen(trimmed)) |open| {
        const raw_base = std.mem.trim(u8, trimmed[0..open], " \t\r\n");
        const base = try canonicalTypeNameAlloc(allocator, raw_base);
        defer allocator.free(base);
        if (!std.mem.eql(u8, base, "List") and !isBuiltinTypeApplicationBase(base) and !isEnumTypeApplicationBase(file, scope, base)) {
            try validateSimpleNamedTypeExists(allocator, file, scope, base);
        }
        const args = (try splitTypeApplicationArgsAlloc(allocator, trimmed)) orelse return error.UnsupportedType;
        defer {
            for (args) |*arg| arg.deinit(allocator);
            allocator.free(args);
        }
        for (args) |arg| try validateTypeReference(allocator, file, scope, arg);
        return;
    }
    const canonical = try canonicalTypeNameAlloc(allocator, trimmed);
    defer allocator.free(canonical);
    try validateSimpleNamedTypeExists(allocator, file, scope, canonical);
}

pub fn validateMethodFieldTypeReference(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, method_parameters: []const []const u8, raw: []const u8) LayoutError!void {
    try validateRawTypeApplicationArity(allocator, file, scope, raw);
    const trimmed = std.mem.trim(u8, raw, " \t\r\n");
    if (trimmed.len == 0) return;
    if (std.mem.startsWith(u8, trimmed, "?")) return validateMethodFieldTypeReference(allocator, file, scope, method_parameters, trimmed[1..]);
    if (std.mem.startsWith(u8, trimmed, "import")) return;
    if (typeApplicationOpen(trimmed)) |open| {
        const raw_base = std.mem.trim(u8, trimmed[0..open], " \t\r\n");
        const base = try canonicalTypeNameAlloc(allocator, raw_base);
        defer allocator.free(base);
        if (!std.mem.eql(u8, base, "List") and !isBuiltinTypeApplicationBase(base) and !isEnumTypeApplicationBase(file, scope, base)) {
            try validateSimpleNamedTypeExists(allocator, file, scope, base);
        }
        const args = (try splitTypeApplicationArgsAlloc(allocator, trimmed)) orelse return error.UnsupportedType;
        defer {
            for (args) |*arg| arg.deinit(allocator);
            allocator.free(args);
        }
        for (args) |arg| try validateMethodTypeReference(allocator, file, scope, method_parameters, arg);
        return;
    }
    const canonical = try canonicalTypeNameAlloc(allocator, trimmed);
    defer allocator.free(canonical);
    for (method_parameters) |parameter| {
        if (std.mem.eql(u8, parameter, canonical)) return;
    }
    try validateSimpleNamedTypeExists(allocator, file, scope, canonical);
}

pub fn validateMethodTypeReference(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, method_parameters: []const []const u8, ty: Type) LayoutError!void {
    switch (ty) {
        .named => |name| try validateMethodFieldTypeReference(allocator, file, scope, method_parameters, name),
        .list, .optional => |child| try validateMethodTypeReference(allocator, file, scope, method_parameters, child.*),
        else => {},
    }
}

pub fn validateSimpleNamedTypeExists(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, name: []const u8) LayoutError!void {
    if (isBuiltinSchemaTypeName(name)) return;
    if (isImportedTypeName(file, name)) return;
    if (isImportedAliasName(file, name)) return;
    if (scope) |owner| {
        if (declHasParameter(owner.parameters, name)) return;
        if (parameterNameInScope(file, scope, name)) return;
        if (findStructDirect(file, owner.name) != null) {
            if (isStructDirectInOwnerScope(file, owner.name, name)) return;
            if (isEnumDirectInOwnerScope(file, owner.name, name)) return;
            if (isInterfaceDirectInOwnerScope(file, owner.name, name)) return;
            if (isAnnotationDirectInOwnerScope(file, owner.name, name)) return;
        }
        if (findInterfaceDirect(file, owner.name) != null) {
            if (isStructDirectInOwnerScope(file, owner.name, name)) return;
            if (isEnumDirectInOwnerScope(file, owner.name, name)) return;
            if (isInterfaceDirectInOwnerScope(file, owner.name, name)) return;
            if (isAnnotationDirectInOwnerScope(file, owner.name, name)) return;
        }
    }
    if (findStructDirect(file, name) != null) return;
    if (findEnumDirect(file, name) != null) return;
    if (findInterfaceDirect(file, name) != null) return;
    if (findAnnotationDirect(file, name) != null) return;
    if (resolveNamedAlias(file, scope, name, 0) != null) return;
    var owned_names = std.ArrayList([]const u8).empty;
    defer {
        for (owned_names.items) |owned_name| allocator.free(owned_name);
        owned_names.deinit(allocator);
    }
    if (try resolveAppliedAliasInScopeAlloc(allocator, file, scope, name, &owned_names)) |resolved_ty_const| {
        var resolved_ty = resolved_ty_const;
        defer resolved_ty.deinit(allocator);
        try validateTypeReference(allocator, file, scope, resolved_ty);
        return;
    }
    if (try resolveQualifiedAliasSuffixAlloc(allocator, file, scope, name, &owned_names)) |resolved_ty_const| {
        var resolved_ty = resolved_ty_const;
        defer resolved_ty.deinit(allocator);
        try validateTypeReference(allocator, file, scope, resolved_ty);
        return;
    }
    return error.UnsupportedType;
}

pub fn canonicalTypeNameAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var depth: usize = 0;
    var index: usize = 0;
    while (index < raw.len) {
        if (skipRawStringOrCommentInPostLoop(raw, &index) catch false) {
            index += 1;
            continue;
        }
        switch (raw[index]) {
            '(' => {
                depth += 1;
                index += 1;
                continue;
            },
            ')' => {
                if (depth != 0) depth -= 1;
                index += 1;
                continue;
            },
            else => {},
        }
        if (depth == 0 and !std.ascii.isWhitespace(raw[index])) try out.append(allocator, raw[index]);
        index += 1;
    }
    return try out.toOwnedSlice(allocator);
}

pub fn isImportedTypeName(file: *const File, name: []const u8) bool {
    const dot = firstTopLevelDot(name);
    const head = if (dot) |index| name[0..index] else name;
    const has_tail = dot != null;
    for (file.imports) |import_decl| {
        if (!typeNameEqualsCanonical(head, import_decl.name)) continue;
        if (import_decl.member != null) return true;
        return has_tail;
    }
    return false;
}

pub fn isImportedAliasName(file: *const File, name: []const u8) bool {
    for (file.imports) |import_decl| {
        if (typeNameEqualsCanonical(name, import_decl.name)) return true;
    }
    return false;
}

pub fn isStructLikeName(file: *const File, name: []const u8) bool {
    return findStructDirect(file, name) != null or
        isImportedTypeName(file, name) or
        std.mem.indexOfScalar(u8, name, '.') != null;
}

pub fn resolveType(file: *const File, ty: Type) Type {
    return resolveTypeScoped(file, null, ty);
}

pub fn resolveTypeScoped(file: *const File, scope: ?*const Struct, ty: Type) Type {
    return switch (ty) {
        .named => resolveTypeInOwnerScope(file, if (scope) |decl| decl.name else null, ty),
        else => ty,
    };
}

pub fn resolveNamedAlias(file: *const File, scope: ?*const Struct, name: []const u8, depth: usize) ?Type {
    const owner_name = if (scope) |decl| decl.name else null;
    return resolveNamedAliasInOwnerScope(file, owner_name, name, depth);
}

pub fn isSimpleConstType(ty: Type) bool {
    return switch (ty) {
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64, .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list, .named => true,
        .optional => |child| isSimpleConstType(child.*),
    };
}

pub fn typeAcceptsTextLiteral(ty: Type) bool {
    return switch (ty) {
        .text => true,
        .optional => |child| typeAcceptsTextLiteral(child.*),
        else => false,
    };
}

pub fn typeAcceptsDataLiteral(ty: Type) bool {
    return switch (ty) {
        .data => true,
        .optional => |child| typeAcceptsDataLiteral(child.*),
        else => false,
    };
}

pub fn anonymousAliasName(ty: Type) ?[]const u8 {
    return switch (ty) {
        .named => |name| anonymousAliasNameFromRaw(name),
        else => null,
    };
}

pub fn anonymousAliasNameFromRaw(raw: []const u8) []const u8 {
    const local_with_args = if (lastTopLevelDot(raw)) |dot| raw[dot + 1 ..] else raw;
    return if (typeApplicationOpen(local_with_args)) |open| local_with_args[0..open] else local_with_args;
}

pub fn importNameFromPath(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfAny(u8, path, "/\\");
    const base = if (slash) |index| path[index + 1 ..] else path;
    return if (std.mem.endsWith(u8, base, ".capnp")) base[0 .. base.len - ".capnp".len] else base;
}

pub fn capitalizedImportNameAlloc(allocator: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error!?[]u8 {
    if (name.len == 0 or name[0] < 'a' or name[0] > 'z') return null;
    const capitalized = try allocator.dupe(u8, name);
    capitalized[0] = capitalized[0] - 'a' + 'A';
    return capitalized;
}

pub fn isGroupType(ty: Type) bool {
    return switch (ty) {
        .named => |name| std.mem.eql(u8, name, "group"),
        else => false,
    };
}

pub fn alignForwardChecked(value: usize, alignment: usize) Error!usize {
    if (alignment == 0) return value;
    const biased = std.math.add(usize, value, alignment - 1) catch return error.InvalidOrdinal;
    return std.math.mul(usize, biased / alignment, alignment) catch return error.InvalidOrdinal;
}

pub fn parseInteger(text: []const u8) (std.fmt.ParseIntError || error{InvalidToken})!u64 {
    if (text.len > 2 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X')) {
        return std.fmt.parseInt(u64, text[2..], 16);
    }
    if (text.len > 2 and text[0] == '0' and (text[1] == 'b' or text[1] == 'B')) {
        return std.fmt.parseInt(u64, text[2..], 2);
    }
    if (text.len > 2 and text[0] == '0' and (text[1] == 'o' or text[1] == 'O')) {
        return std.fmt.parseInt(u64, text[2..], 8);
    }
    return std.fmt.parseInt(u64, text, 10);
}

pub fn isIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

pub fn isSchemaIdentifier(name: []const u8) bool {
    if (name.len == 0 or !isIdentStart(name[0])) return false;
    for (name[1..]) |c| {
        if (!isIdentContinue(c)) return false;
    }
    return true;
}

pub fn isIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

pub fn defaultLiteralCanBeReference(raw: []const u8) bool {
    if (raw.len == 0) return false;
    var index: usize = 0;
    if (raw[index] == '.') index += 1;
    if (index >= raw.len or !isIdentStart(raw[index])) return false;
    index += 1;
    while (index < raw.len and isIdentContinue(raw[index])) index += 1;
    while (index < raw.len and raw[index] == '.') {
        index += 1;
        if (index >= raw.len or !isIdentStart(raw[index])) return false;
        index += 1;
        while (index < raw.len and isIdentContinue(raw[index])) index += 1;
    }
    return index == raw.len;
}

pub fn defaultLiteralIsSignedNumber(raw: []const u8) bool {
    if (raw.len == 0) return false;
    const first_digit: usize = if (raw[0] == '+' or raw[0] == '-') 1 else 0;
    return first_digit < raw.len and std.ascii.isDigit(raw[first_digit]);
}

pub fn isNumberContinue(c: u8) bool {
    return switch (c) {
        '0'...'9', 'a'...'f', 'A'...'F', 'o', 'O', 'x', 'X', '_', '.', '+', '-' => true,
        else => false,
    };
}

/// Literal parsing, const resolution, and type-name helpers shared with the
/// code generator. These live in the frontend so the parser, layout planner,
/// and validators do not depend on generated-source emission.
pub fn parseFloatLiteral(comptime T: type, raw_literal: []const u8) ?T {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    const unsigned = if (std.mem.startsWith(u8, raw, "+")) raw[1..] else raw;
    if (std.mem.eql(u8, unsigned, "inf")) return std.math.inf(T);
    if (std.mem.eql(u8, unsigned, "-inf")) return -std.math.inf(T);
    if (std.mem.eql(u8, unsigned, "nan")) return std.math.nan(T);
    return std.fmt.parseFloat(T, unsigned) catch null;
}

pub fn parseBoolLiteral(raw_literal: []const u8) ?bool {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    if (std.mem.eql(u8, raw, "true")) return true;
    if (std.mem.eql(u8, raw, "false")) return false;
    return null;
}

pub fn enumLiteralOrdinal(decl: *const EnumDecl, raw_literal: []const u8) ?u16 {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    const unqualified = if (std.mem.startsWith(u8, raw, ".")) raw[1..] else raw;
    const literal = if (lastTopLevelDot(unqualified)) |dot| unqualified[dot + 1 ..] else unqualified;
    if (literal.len == 0) return null;
    for (decl.values) |value| if (std.mem.eql(u8, value.name, literal)) return value.ordinal;
    return null;
}

pub fn parseUnsignedLiteral(comptime T: type, raw_literal: []const u8) ?T {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    if (raw.len == 0 or raw[0] == '.') return null;
    const digits = if (raw[0] == '+') raw[1..] else raw;
    if (digits.len == 0) return null;
    const value = parseInteger(digits) catch return null;
    if (value > std.math.maxInt(T)) return null;
    return @intCast(value);
}

pub fn resolveConstDeclType(file: *const File, scope: ?*const Struct, decl: *const ConstDecl) Type {
    if (constDeclOwnerName(file, decl)) |owner_name| {
        return resolveTypeInOwnerScope(file, owner_name, decl.ty);
    }
    return resolveTypeScoped(file, scope, decl.ty);
}

pub fn typeAcceptsVoidPointerDefault(file: *const File, ty: Type) bool {
    return switch (ty) {
        .any_pointer, .any_struct, .any_list, .capability => true,
        .named => |type_name| findInterface(file, type_name) != null,
        else => false,
    };
}

pub fn resolveConstReferenceLiteral(file: *const File, scope: ?*const Struct, literal: []const u8) []const u8 {
    return resolveConstReferenceLiteralDepth(file, scope, literal, 0);
}

pub fn schemaTypeNameAlloc(allocator: std.mem.Allocator, ty: Type) LayoutError![]u8 {
    return switch (ty) {
        .void => allocator.dupe(u8, "Void"),
        .bool => allocator.dupe(u8, "Bool"),
        .int8 => allocator.dupe(u8, "Int8"),
        .int16 => allocator.dupe(u8, "Int16"),
        .int32 => allocator.dupe(u8, "Int32"),
        .int64 => allocator.dupe(u8, "Int64"),
        .uint8 => allocator.dupe(u8, "UInt8"),
        .uint16 => allocator.dupe(u8, "UInt16"),
        .uint32 => allocator.dupe(u8, "UInt32"),
        .uint64 => allocator.dupe(u8, "UInt64"),
        .float32 => allocator.dupe(u8, "Float32"),
        .float64 => allocator.dupe(u8, "Float64"),
        .text => allocator.dupe(u8, "Text"),
        .data => allocator.dupe(u8, "Data"),
        .any_pointer => allocator.dupe(u8, "AnyPointer"),
        .any_struct => allocator.dupe(u8, "AnyStruct"),
        .any_list => allocator.dupe(u8, "AnyList"),
        .capability => allocator.dupe(u8, "Capability"),
        .named => |name| allocator.dupe(u8, name),
        .list => |child| {
            const child_name = try schemaTypeNameAlloc(allocator, child.*);
            defer allocator.free(child_name);
            return std.fmt.allocPrint(allocator, "List({s})", .{child_name});
        },
        .optional => |child| {
            const child_name = try schemaTypeNameAlloc(allocator, child.*);
            defer allocator.free(child_name);
            return std.fmt.allocPrint(allocator, "?{s}", .{child_name});
        },
    };
}

pub fn annotationOwnerName(annotation_name: []const u8) ?[]const u8 {
    const dot = lastTopLevelDot(annotation_name) orelse return null;
    return annotation_name[0..dot];
}

pub fn annotationTargetCount(targets: AnnotationTargets) usize {
    var count: usize = 0;
    if (targets.file) count += 1;
    if (targets.const_decl) count += 1;
    if (targets.enum_decl) count += 1;
    if (targets.enumerant) count += 1;
    if (targets.struct_decl) count += 1;
    if (targets.field) count += 1;
    if (targets.union_decl) count += 1;
    if (targets.group) count += 1;
    if (targets.interface_decl) count += 1;
    if (targets.method) count += 1;
    if (targets.param) count += 1;
    if (targets.annotation_decl) count += 1;
    return count;
}

pub fn constDeclOwnerName(file: *const File, decl: *const ConstDecl) ?[]const u8 {
    for (file.structs) |*owner| {
        for (owner.consts) |*candidate| {
            if (candidate == decl) return owner.name;
        }
    }
    for (file.interfaces) |*owner| {
        for (owner.consts) |*candidate| {
            if (candidate == decl) return owner.name;
        }
    }
    return null;
}

pub fn declHasParameter(parameters: []const []const u8, name: []const u8) bool {
    for (parameters) |parameter| {
        if (std.mem.eql(u8, parameter, name)) return true;
    }
    return false;
}

pub fn findConstReference(file: *const File, scope: ?*const Struct, literal: []const u8) ?*const ConstDecl {
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    const name = if (lastTopLevelDot(raw)) |dot| raw[dot + 1 ..] else raw;
    const owner = if (lastTopLevelDot(raw)) |dot| raw[0..dot] else null;
    if (owner) |owner_name| {
        if (scope) |decl| {
            if (typeNameEqualsCanonical(owner_name, decl.name)) {
                for (decl.consts) |*const_decl| {
                    if (std.mem.eql(u8, const_decl.name, name)) return const_decl;
                }
            }
        }
        if (findConstInOwner(file, scope, owner_name, name)) |decl| {
            return decl;
        }
    } else if (scope) |decl| {
        if (findConstInOwnerScope(file, scope, decl.name, name)) |const_decl| return const_decl;
    }
    for (file.consts) |*const_decl| {
        if (std.mem.eql(u8, const_decl.name, name)) return const_decl;
    }
    return null;
}

pub fn hexBytesAlloc(allocator: std.mem.Allocator, raw: []const u8) LayoutError![]u8 {
    var bytes = std.ArrayList(u8).empty;
    errdefer bytes.deinit(allocator);
    var high_nibble: ?u8 = null;
    for (raw) |c| {
        switch (c) {
            ' ', '\t', '\n', '\r' => continue,
            else => {},
        }
        const value = hexValue(c) orelse return error.InvalidToken;
        if (high_nibble) |high| {
            try bytes.append(allocator, (high << 4) | value);
            high_nibble = null;
        } else {
            high_nibble = value;
        }
    }
    if (high_nibble != null) return error.InvalidToken;
    return bytes.toOwnedSlice(allocator);
}

pub fn matchingParen(raw: []const u8, open_index: usize) Error!?usize {
    var depth: usize = 0;
    var index = open_index;
    while (index < raw.len) {
        if (try skipRawStringOrCommentInPostLoop(raw, &index)) {
            index += 1;
            continue;
        }
        if (raw[index] == '(') depth += 1;
        if (raw[index] == ')') {
            if (depth == 0) return null;
            depth -= 1;
            if (depth == 0) return index;
        }
        index += 1;
    }
    return null;
}

pub fn parseInlineConstListElementsAlloc(allocator: std.mem.Allocator, expression: []const u8) LayoutError![]const []const u8 {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    var index = try skipTriviaIndex(source, 0);
    if (index >= source.len or source[index] != '[') return error.UnsupportedType;
    index += 1;

    var items = std.ArrayList([]const u8).empty;
    errdefer items.deinit(allocator);
    while (true) {
        index = try skipTriviaIndex(source, index);
        if (index >= source.len) return error.UnexpectedToken;
        if (source[index] == ']') {
            index += 1;
            break;
        }

        const item_start = index;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var brace_depth: usize = 0;
        while (index < source.len) {
            switch (source[index]) {
                '"' => {
                    index += 1;
                    while (index < source.len) {
                        if (source[index] == '\\') {
                            index += 2;
                        } else if (source[index] == '"') {
                            index += 1;
                            break;
                        } else {
                            index += 1;
                        }
                    }
                    if (index > source.len) return error.UnexpectedToken;
                    continue;
                },
                '#' => {
                    index = skipLineCommentIndex(source, index);
                    continue;
                },
                '/' => {
                    const next = try skipRawSlashIndex(source, index);
                    if (next != index + 1) {
                        index = next;
                        continue;
                    }
                    index = next;
                    continue;
                },
                '(' => {
                    paren_depth += 1;
                    index += 1;
                    continue;
                },
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                    index += 1;
                    continue;
                },
                '[' => {
                    bracket_depth += 1;
                    index += 1;
                    continue;
                },
                ']' => {
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) break;
                    if (bracket_depth != 0) bracket_depth -= 1;
                    index += 1;
                    continue;
                },
                '{' => {
                    brace_depth += 1;
                    index += 1;
                    continue;
                },
                '}' => {
                    if (brace_depth != 0) brace_depth -= 1;
                    index += 1;
                    continue;
                },
                ',' => if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) break,
                else => {},
            }
            index += 1;
        }
        if (index >= source.len) return error.UnexpectedToken;
        const item = std.mem.trim(u8, source[item_start..index], " \t\r\n");
        if (item.len == 0) return error.UnexpectedToken;
        try items.append(allocator, item);

        index = try skipTriviaIndex(source, index);
        if (index >= source.len) return error.UnexpectedToken;
        if (source[index] == ',') {
            index += 1;
            index = try skipTriviaIndex(source, index);
            if (index >= source.len or source[index] == ']') return error.UnexpectedToken;
            continue;
        }
        if (source[index] == ']') {
            index += 1;
            break;
        }
        return error.UnexpectedToken;
    }

    index = try skipTriviaIndex(source, index);
    if (index != source.len) return error.UnexpectedToken;
    return items.toOwnedSlice(allocator);
}

pub fn parseSignedLiteral(comptime T: type, raw_literal: []const u8) ?T {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    if (raw.len == 0 or raw[0] == '.') return null;
    const negative = raw[0] == '-';
    const positive = raw[0] == '+';
    const digits = if (negative or positive) raw[1..] else raw;
    if (digits.len == 0) return null;
    const unsigned = parseInteger(digits) catch return null;
    if (negative) {
        const min_abs = @as(u64, @intCast(-(std.math.minInt(T) + 1))) + 1;
        if (unsigned > min_abs) return null;
        if (unsigned == min_abs) return std.math.minInt(T);
        const positive_value: T = @intCast(unsigned);
        return -positive_value;
    }
    if (unsigned > std.math.maxInt(T)) return null;
    return @intCast(unsigned);
}

pub fn parseTypeArgAlloc(allocator: std.mem.Allocator, raw_arg: []const u8) LayoutError!Type {
    const raw = std.mem.trim(u8, raw_arg, " \t\r\n");
    if (raw.len == 0) return error.UnexpectedToken;
    var parser = try Parser.init(allocator, raw);
    defer parser.deinitLiteralScratch();
    var ty = try parser.parseType();
    errdefer ty.deinit(allocator);
    if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
    return ty;
}

pub fn resolveNamedAliasInOwnerScope(file: *const File, owner_name: ?[]const u8, name: []const u8, depth: usize) ?Type {
    if (depth >= 32) return null;
    var current = owner_name;
    while (current) |owner| {
        if (findStructDirect(file, owner)) |decl| {
            if (resolveNamedAliasInList(decl.aliases, file, owner, name, depth)) |resolved| return resolved;
            if (declHasParameter(decl.parameters, name)) return null;
        }
        if (findInterfaceDirect(file, owner)) |decl| {
            if (resolveNamedAliasInList(decl.aliases, file, owner, name, depth)) |resolved| return resolved;
            if (declHasParameter(decl.parameters, name)) return null;
        }
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return resolveNamedAliasInList(file.aliases, file, null, name, depth);
}

pub fn resolveTypeInOwnerScope(file: *const File, owner_name: ?[]const u8, ty: Type) Type {
    return switch (ty) {
        .named => |name| resolveNamedAliasInOwnerScope(file, owner_name, name, 0) orelse ty,
        else => ty,
    };
}

pub fn splitTypeApplicationArgsAlloc(allocator: std.mem.Allocator, type_name: []const u8) LayoutError!?[]Type {
    const open = typeApplicationOpen(type_name) orelse return null;
    const close = (try matchingParen(type_name, open)) orelse return null;
    const raw_args = type_name[open + 1 .. close];
    var args = std.ArrayList(Type).empty;
    errdefer {
        for (args.items) |*arg| arg.deinit(allocator);
        args.deinit(allocator);
    }
    var start: usize = 0;
    var depth: usize = 0;
    var index: usize = 0;
    while (index < raw_args.len) {
        if (try skipRawStringOrCommentInPostLoop(raw_args, &index)) {
            index += 1;
            continue;
        }
        switch (raw_args[index]) {
            '(' => depth += 1,
            ')' => {
                if (depth != 0) depth -= 1;
            },
            ',' => if (depth == 0) {
                if (std.mem.trim(u8, raw_args[start..index], " \t\r\n").len == 0) return error.UnexpectedToken;
                try args.append(allocator, try parseTypeArgAlloc(allocator, raw_args[start..index]));
                start = index + 1;
            },
            else => {},
        }
        index += 1;
    }
    if (std.mem.trim(u8, raw_args[start..], " \t\r\n").len != 0) {
        try args.append(allocator, try parseTypeArgAlloc(allocator, raw_args[start..]));
    }
    return try args.toOwnedSlice(allocator);
}

pub fn substituteGenericTypeAlloc(allocator: std.mem.Allocator, owned_names: *std.ArrayList([]const u8), ty: Type, parameters: []const []const u8, args: []const Type) LayoutError!Type {
    switch (ty) {
        .named => |name| {
            for (parameters, 0..) |parameter, index| {
                if (index < args.len and typeNameEqualsCanonical(name, parameter)) return cloneTypeAlloc(allocator, args[index]);
            }
            if (try substituteGenericNameAlloc(allocator, name, parameters, args)) |substituted_name| {
                try owned_names.append(allocator, substituted_name);
                return .{ .named = substituted_name };
            }
            return ty;
        },
        .list => |child| {
            const cloned = try allocator.create(Type);
            errdefer allocator.destroy(cloned);
            cloned.* = try substituteGenericTypeAlloc(allocator, owned_names, child.*, parameters, args);
            return .{ .list = cloned };
        },
        .optional => |child| {
            const cloned = try allocator.create(Type);
            errdefer allocator.destroy(cloned);
            cloned.* = try substituteGenericTypeAlloc(allocator, owned_names, child.*, parameters, args);
            return .{ .optional = cloned };
        },
        else => return ty,
    }
}

pub fn typeAcceptsNullPointerDefault(file: *const File, ty: Type) bool {
    return switch (ty) {
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => true,
        .named => |type_name| findEnum(file, type_name) == null,
        else => false,
    };
}

pub fn cloneTypeAlloc(allocator: std.mem.Allocator, ty: Type) LayoutError!Type {
    return switch (ty) {
        .list => |child| blk: {
            const cloned = try allocator.create(Type);
            errdefer allocator.destroy(cloned);
            cloned.* = try cloneTypeAlloc(allocator, child.*);
            break :blk .{ .list = cloned };
        },
        .optional => |child| blk: {
            const cloned = try allocator.create(Type);
            errdefer allocator.destroy(cloned);
            cloned.* = try cloneTypeAlloc(allocator, child.*);
            break :blk .{ .optional = cloned };
        },
        else => ty,
    };
}

pub fn substituteGenericNameAlloc(allocator: std.mem.Allocator, raw: []const u8, parameters: []const []const u8, args: []const Type) LayoutError!?[]const u8 {
    const open = typeApplicationOpen(raw) orelse return null;
    const close = (try matchingParen(raw, open)) orelse return null;
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, raw[0 .. open + 1]);
    const inner = raw[open + 1 .. close];
    var start: usize = 0;
    var depth: usize = 0;
    var first = true;
    var index: usize = 0;
    while (index < inner.len) {
        if (try skipRawStringOrCommentInPostLoop(inner, &index)) {
            index += 1;
            continue;
        }
        switch (inner[index]) {
            '(' => depth += 1,
            ')' => {
                if (depth != 0) depth -= 1;
            },
            ',' => if (depth == 0) {
                if (!first) try out.appendSlice(allocator, ", ");
                first = false;
                const arg = std.mem.trim(u8, inner[start..index], " \t\r\n");
                var substituted = false;
                for (parameters, 0..) |parameter, parameter_index| {
                    if (parameter_index < args.len and typeNameEqualsCanonical(arg, parameter)) {
                        const arg_name = try schemaTypeNameAlloc(allocator, args[parameter_index]);
                        defer allocator.free(arg_name);
                        try out.appendSlice(allocator, arg_name);
                        substituted = true;
                        break;
                    }
                }
                if (!substituted) {
                    if (try substituteGenericNameAlloc(allocator, arg, parameters, args)) |nested| {
                        defer allocator.free(nested);
                        try out.appendSlice(allocator, nested);
                    } else {
                        try out.appendSlice(allocator, arg);
                    }
                }
                start = index + 1;
            },
            else => {},
        }
        index += 1;
    }
    if (!first) try out.appendSlice(allocator, ", ");
    const arg = std.mem.trim(u8, inner[start..], " \t\r\n");
    var substituted = false;
    for (parameters, 0..) |parameter, parameter_index| {
        if (parameter_index < args.len and typeNameEqualsCanonical(arg, parameter)) {
            const arg_name = try schemaTypeNameAlloc(allocator, args[parameter_index]);
            defer allocator.free(arg_name);
            try out.appendSlice(allocator, arg_name);
            substituted = true;
            break;
        }
    }
    if (!substituted) {
        if (try substituteGenericNameAlloc(allocator, arg, parameters, args)) |nested| {
            defer allocator.free(nested);
            try out.appendSlice(allocator, nested);
        } else {
            try out.appendSlice(allocator, arg);
        }
    }
    try out.append(allocator, ')');
    try out.appendSlice(allocator, raw[close + 1 ..]);
    return try out.toOwnedSlice(allocator);
}

pub fn resolveConstReferenceLiteralDepth(file: *const File, scope: ?*const Struct, literal: []const u8, depth: usize) []const u8 {
    if (depth >= 32) return literal;
    const decl = findConstReference(file, scope, literal) orelse return literal;
    if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), std.mem.trim(u8, literal, " \t\r\n"))) return decl.literal;
    if (constDeclOwnerName(file, decl)) |owner_name| {
        return resolveConstReferenceLiteralInOwnerDepth(file, scope, owner_name, decl.literal, depth + 1);
    }
    return resolveConstReferenceLiteralDepth(file, scope, decl.literal, depth + 1);
}

pub fn resolveConstReferenceLiteralInOwnerDepth(file: *const File, scope: ?*const Struct, owner_name: []const u8, literal: []const u8, depth: usize) []const u8 {
    if (depth >= 32) return literal;
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (lastTopLevelDot(raw) == null) {
        if (findConstInOwner(file, scope, owner_name, raw)) |decl| {
            if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), raw)) return decl.literal;
            return resolveConstReferenceLiteralInOwnerDepth(file, scope, constDeclOwnerName(file, decl) orelse owner_name, decl.literal, depth + 1);
        }
    }
    return resolveConstReferenceLiteralDepth(file, scope, literal, depth);
}

pub fn findConstInOwnerScope(file: *const File, scope: ?*const Struct, owner_name: []const u8, const_name: []const u8) ?*const ConstDecl {
    var current: ?[]const u8 = owner_name;
    while (current) |owner| {
        if (findConstInOwner(file, scope, owner, const_name)) |decl| return decl;
        current = if (lastTopLevelDot(owner)) |dot| owner[0..dot] else null;
    }
    return null;
}

pub fn findConstInOwner(file: *const File, scope: ?*const Struct, owner_name: []const u8, const_name: []const u8) ?*const ConstDecl {
    if (findStructDirect(file, owner_name)) |decl| {
        for (decl.consts) |*const_decl| {
            if (std.mem.eql(u8, const_decl.name, const_name)) return const_decl;
        }
    }
    if (findInterfaceDirect(file, owner_name)) |decl| {
        for (decl.consts) |*const_decl| {
            if (std.mem.eql(u8, const_decl.name, const_name)) return const_decl;
        }
    }
    // Qualified references may use a public alias as the owner
    // (`Alias.localConst`). Resolve that owner alias before looking for consts
    // on the underlying struct/interface declaration.
    const resolved_owner = resolveNamedAlias(file, scope, owner_name, 0) orelse return null;
    return switch (resolved_owner) {
        .named => |resolved_name| if (std.mem.eql(u8, resolved_name, owner_name))
            null
        else
            findConstInOwner(file, scope, resolved_name, const_name),
        else => null,
    };
}

pub fn resolveNamedAliasInList(aliases: []const AliasDecl, file: *const File, owner_name: ?[]const u8, name: []const u8, depth: usize) ?Type {
    for (aliases) |alias| {
        if (!std.mem.eql(u8, alias.name, name)) continue;
        return switch (alias.target) {
            .named => |target_name| resolveNamedAliasInOwnerScope(file, owner_name, target_name, depth + 1) orelse alias.target,
            else => alias.target,
        };
    }
    return null;
}

pub fn hexValue(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}
