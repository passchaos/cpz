const std = @import("std");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const mod_flat = @import("flat.zig");

const EnumDecl = frontend.EnumDecl;
const Error = frontend.Error;
const Field = frontend.Field;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const Type = frontend.Type;
const canonicalTypeNameAlloc = frontend.canonicalTypeNameAlloc;
const enumLiteralOrdinal = frontend.enumLiteralOrdinal;
const findEnum = frontend.findEnum;
const findEnumDirect = frontend.findEnumDirect;
const findInterface = frontend.findInterface;
const findInterfaceDirect = frontend.findInterfaceDirect;
const firstTopLevelDot = frontend.firstTopLevelDot;
const hexBytesAlloc = frontend.hexBytesAlloc;
const isStructLikeName = frontend.isStructLikeName;
const resolveTypeInOwnerScope = frontend.resolveTypeInOwnerScope;
const resolveTypeScoped = frontend.resolveTypeScoped;
const schemaTypeNameAlloc = frontend.schemaTypeNameAlloc;
const typeNameEqualsCanonical = frontend.typeNameEqualsCanonical;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const resolveScalarConstLiteral = mod_flat.resolveScalarConstLiteral;

pub fn listElementSizeLiteral(file: *const File, scope: ?*const Struct, ty: Type) LayoutError![]const u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void => ".void",
        .bool => ".bit",
        .int8, .uint8 => ".byte",
        .int16, .uint16 => ".two_bytes",
        .int32, .uint32, .float32 => ".four_bytes",
        .int64, .uint64, .float64 => ".eight_bytes",
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => ".pointer",
        .optional => ".pointer",
        .named => |name| if (findEnum(file, name) != null) ".two_bytes" else if (findInterface(file, name) != null or !isStructLikeName(file, name)) ".pointer" else ".composite",
    };
}

pub fn isPointerListElement(file: *const File, scope: ?*const Struct, ty: Type) bool {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => true,
        .optional => |child| isPointerListElement(file, scope, child.*),
        .named => |name| findEnum(file, name) == null and (findInterface(file, name) != null or !isStructLikeName(file, name)),
        else => false,
    };
}

pub fn isStructListElement(file: *const File, scope: ?*const Struct, ty: Type) ?[]const u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .named => |name| if (findEnumDirect(file, name) == null and findInterfaceDirect(file, name) == null and isStructLikeName(file, name)) name else null,
        else => null,
    };
}

pub fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) std.mem.Allocator.Error!void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

pub fn zigTypeRefAlloc(allocator: std.mem.Allocator, file: *const File, raw: []const u8) std.mem.Allocator.Error![]u8 {
    if (try importedTypeRefAlloc(allocator, file, raw)) |imported| return imported;
    const canonical = try canonicalTypeNameAlloc(allocator, raw);
    defer allocator.free(canonical);
    const ident = try zigIdentAlloc(allocator, canonical);
    defer allocator.free(ident);
    return std.fmt.allocPrint(allocator, "@\"cpz.schema\".{s}", .{ident});
}

pub fn importedTypeRefAlloc(allocator: std.mem.Allocator, file: *const File, raw: []const u8) std.mem.Allocator.Error!?[]u8 {
    const dot = firstTopLevelDot(raw);
    const head = if (dot) |index| raw[0..index] else raw;
    const tail = if (dot) |index| raw[index + 1 ..] else null;
    for (file.imports) |import_decl| {
        if (!typeNameEqualsCanonical(head, import_decl.name)) continue;

        const imported_raw = if (import_decl.member) |member| blk: {
            if (tail) |suffix| {
                break :blk try std.fmt.allocPrint(allocator, "{s}.{s}", .{ member, suffix });
            }
            break :blk try allocator.dupe(u8, member);
        } else blk: {
            const suffix = tail orelse return null;
            break :blk try allocator.dupe(u8, suffix);
        };
        defer allocator.free(imported_raw);

        const canonical_imported_raw = try canonicalTypeNameAlloc(allocator, imported_raw);
        defer allocator.free(canonical_imported_raw);
        const module_literal = try zigStringLiteralAlloc(allocator, import_decl.name);
        defer allocator.free(module_literal);
        const imported_ident = try zigIdentAlloc(allocator, canonical_imported_raw);
        defer allocator.free(imported_ident);
        return try std.fmt.allocPrint(allocator, "@import({s}).{s}", .{ module_literal, imported_ident });
    }
    return null;
}

pub fn zigDataLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8, is_hex: bool) LayoutError![]u8 {
    if (!is_hex) return zigStringLiteralAlloc(allocator, raw);

    const decoded = try hexBytesAlloc(allocator, raw);
    defer allocator.free(decoded);
    return zigRawStringLiteralAlloc(allocator, decoded);
}

pub fn octalValue(c: u8) ?u8 {
    return switch (c) {
        '0'...'7' => c - '0',
        else => null,
    };
}

pub fn zigStringLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '"');

    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        i += 1;
        if (c == '\\' and i < raw.len) {
            const escaped = raw[i];
            i += 1;
            switch (escaped) {
                'a' => try appendZigStringChar(allocator, &out, 0x07),
                'b' => try appendZigStringChar(allocator, &out, 0x08),
                'f' => try appendZigStringChar(allocator, &out, 0x0c),
                'n' => try appendZigStringChar(allocator, &out, '\n'),
                'r' => try appendZigStringChar(allocator, &out, '\r'),
                't' => try appendZigStringChar(allocator, &out, '\t'),
                'v' => try appendZigStringChar(allocator, &out, 0x0b),
                '\'' => try appendZigStringChar(allocator, &out, '\''),
                '"' => try appendZigStringChar(allocator, &out, '"'),
                '\\' => try appendZigStringChar(allocator, &out, '\\'),
                '?' => try appendZigStringChar(allocator, &out, '?'),
                'x' => {
                    if (i + 2 <= raw.len) {
                        if (std.fmt.parseInt(u8, raw[i .. i + 2], 16)) |value| {
                            i += 2;
                            try appendZigStringChar(allocator, &out, value);
                        } else |_| {
                            try appendZigStringChar(allocator, &out, escaped);
                        }
                    } else {
                        try appendZigStringChar(allocator, &out, escaped);
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
                    try appendZigStringChar(allocator, &out, @truncate(value));
                },
                else => try appendZigStringChar(allocator, &out, escaped),
            }
        } else {
            try appendZigStringChar(allocator, &out, c);
        }
    }
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

pub fn zigSchemaSyntaxLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    // Schema metadata fields store source syntax, not decoded Text/Data values.
    // Preserve backslash escape spelling so annotation/signature/default lookup
    // helpers round-trip the parser's raw slices exactly.
    return zigRawStringLiteralAlloc(allocator, raw);
}

pub fn zigRawStringLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '"');
    for (raw) |c| try appendZigStringChar(allocator, &out, c);
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

pub fn appendZigStringChar(allocator: std.mem.Allocator, out: *std.ArrayList(u8), c: u8) std.mem.Allocator.Error!void {
    switch (c) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '"' => try out.appendSlice(allocator, "\\\""),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        else => if (c < 0x20 or c >= 0x7f) {
            try appendFmt(allocator, out, "\\x{X:0>2}", .{c});
        } else {
            try out.append(allocator, c);
        },
    }
}

pub fn defaultScalarLiteral(field: *const Field) []const u8 {
    const literal = field.default_literal orelse return "0";
    return if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal;
}

pub fn resolvedFieldDefaultScalarLiteral(file: *const File, scope: ?*const Struct, field: *const Field) []const u8 {
    const literal = field.default_literal orelse return "0";
    const resolved = resolveScalarConstLiteral(file, scope, literal);
    return if (std.mem.startsWith(u8, resolved, "+")) resolved[1..] else resolved;
}

pub fn schemaResolvedTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type) LayoutError![]u8 {
    return switch (ty) {
        .named => |name| {
            const resolved = resolveTypeScoped(file, scope, ty);
            if (resolved == .named and std.mem.eql(u8, resolved.named, name)) {
                return allocator.dupe(u8, name);
            }
            return schemaResolvedTypeNameAlloc(allocator, file, scope, resolved);
        },
        .list => |child| {
            const child_name = try schemaResolvedTypeNameAlloc(allocator, file, scope, child.*);
            defer allocator.free(child_name);
            return std.fmt.allocPrint(allocator, "List({s})", .{child_name});
        },
        .optional => |child| {
            const child_name = try schemaResolvedTypeNameAlloc(allocator, file, scope, child.*);
            defer allocator.free(child_name);
            return std.fmt.allocPrint(allocator, "?{s}", .{child_name});
        },
        else => schemaTypeNameAlloc(allocator, ty),
    };
}

pub fn schemaResolvedTypeNameInOwnerScopeAlloc(allocator: std.mem.Allocator, file: *const File, owner_name: ?[]const u8, ty: Type) LayoutError![]u8 {
    return switch (ty) {
        .named => |name| {
            const resolved = resolveTypeInOwnerScope(file, owner_name, ty);
            if (resolved == .named and std.mem.eql(u8, resolved.named, name)) {
                return allocator.dupe(u8, name);
            }
            return schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, resolved);
        },
        .list => |child| {
            const child_name = try schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, child.*);
            defer allocator.free(child_name);
            return std.fmt.allocPrint(allocator, "List({s})", .{child_name});
        },
        .optional => |child| {
            const child_name = try schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, child.*);
            defer allocator.free(child_name);
            return std.fmt.allocPrint(allocator, "?{s}", .{child_name});
        },
        else => schemaTypeNameAlloc(allocator, ty),
    };
}

pub fn defaultFloatLiteral(field: *const Field, comptime zig_type: []const u8) []const u8 {
    const literal = field.default_literal orelse return "0";
    return floatConstLiteral(literal, zig_type);
}

pub fn resolvedFieldDefaultFloatLiteral(file: *const File, scope: ?*const Struct, field: *const Field, comptime zig_type: []const u8) []const u8 {
    const literal = field.default_literal orelse return "0";
    return floatConstLiteral(resolveScalarConstLiteral(file, scope, literal), zig_type);
}

pub fn floatConstLiteral(literal: []const u8, comptime zig_type: []const u8) []const u8 {
    const unsigned = if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal;
    if (std.mem.eql(u8, unsigned, "inf")) return if (std.mem.eql(u8, zig_type, "f32")) "std.math.inf(f32)" else "std.math.inf(f64)";
    if (std.mem.eql(u8, unsigned, "-inf")) return if (std.mem.eql(u8, zig_type, "f32")) "-std.math.inf(f32)" else "-std.math.inf(f64)";
    if (std.mem.eql(u8, unsigned, "nan")) return if (std.mem.eql(u8, zig_type, "f32")) "std.math.nan(f32)" else "std.math.nan(f64)";
    return unsigned;
}

pub fn boolConstLiteral(literal: []const u8) LayoutError![]const u8 {
    if (std.mem.eql(u8, literal, "true") or std.mem.eql(u8, literal, "false")) return literal;
    return error.InvalidToken;
}

pub fn defaultBoolLiteral(field: *const Field) LayoutError![]const u8 {
    const literal = field.default_literal orelse return "false";
    return boolConstLiteral(literal);
}

pub fn resolvedFieldDefaultBoolLiteral(file: *const File, scope: ?*const Struct, field: *const Field) LayoutError![]const u8 {
    const literal = field.default_literal orelse return "false";
    return boolConstLiteral(resolveScalarConstLiteral(file, scope, literal));
}

pub fn enumDefaultOrdinal(decl: *const EnumDecl, literal: ?[]const u8) LayoutError!u16 {
    const raw_name = literal orelse return 0;
    const name = if (std.mem.lastIndexOfScalar(u8, raw_name, '.')) |dot| raw_name[dot + 1 ..] else raw_name;
    for (decl.values) |value| {
        if (std.mem.eql(u8, value.name, name)) return value.ordinal;
    }
    return error.InvalidToken;
}

pub fn resolvedEnumLiteralOrdinal(file: *const File, scope: ?*const Struct, decl: *const EnumDecl, literal: []const u8) ?u16 {
    return enumLiteralOrdinal(decl, literal) orelse enumLiteralOrdinal(decl, resolveScalarConstLiteral(file, scope, literal));
}

pub fn resolvedEnumDefaultOrdinal(file: *const File, scope: ?*const Struct, decl: *const EnumDecl, literal: ?[]const u8) LayoutError!u16 {
    const raw = literal orelse return enumDefaultOrdinal(decl, null);
    return resolvedEnumLiteralOrdinal(file, scope, decl, raw) orelse error.InvalidToken;
}

pub fn resolvedFieldDefaultEnumOrdinal(file: *const File, scope: ?*const Struct, decl: *const EnumDecl, field: *const Field) LayoutError!u16 {
    const literal = field.default_literal orelse return enumDefaultOrdinal(decl, null);
    return resolvedEnumDefaultOrdinal(file, scope, decl, literal);
}
