const std = @import("std");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const mod_interface = @import("interface.zig");
const mod_pointer = @import("pointer.zig");

const ConstDecl = frontend.ConstDecl;
const EnumDecl = frontend.EnumDecl;
const Field = frontend.Field;
const File = frontend.File;
const ImportDecl = frontend.ImportDecl;
const InterfaceDecl = frontend.InterfaceDecl;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const Type = frontend.Type;
const findEnum = frontend.findEnum;
const findInterface = frontend.findInterface;
const isStructLikeName = frontend.isStructLikeName;
const resolveConstReferenceLiteral = frontend.resolveConstReferenceLiteral;
const resolveTypeScoped = frontend.resolveTypeScoped;
const typeAcceptsVoidPointerDefault = frontend.typeAcceptsVoidPointerDefault;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const zigNamesEqual = zig_names.zigNamesEqual;
const methodDefaultIsNull = mod_interface.methodDefaultIsNull;
const methodDefaultIsVoidOrNull = mod_interface.methodDefaultIsVoidOrNull;
const emitPointerGetter = mod_pointer.emitPointerGetter;

pub fn validateZigNameCollisions(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    try validateImportZigNames(allocator, file.imports);
    try validateTopLevelFixedHelperZigNames(allocator, file);
    try validateTopLevelConstFlatZigNames(allocator, file);
    try validateTopLevelConstStructMemberZigNames(allocator, file);

    for (file.structs, 0..) |lhs, i| {
        for (file.structs[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.enums) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.consts) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.interfaces) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.annotations) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        try validateFieldZigNames(allocator, file, &lhs);
    }
    for (file.enums, 0..) |lhs, i| {
        for (file.enums[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.consts) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.interfaces) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.annotations) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        try validateEnumValueZigNames(allocator, &lhs);
    }
    for (file.consts, 0..) |lhs, i| {
        for (file.consts[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.interfaces) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.annotations) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
    for (file.aliases, 0..) |lhs, i| {
        for (file.aliases[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.interfaces) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.annotations) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
    for (file.interfaces, 0..) |lhs, i| {
        for (file.interfaces[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.annotations) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        try validateInterfaceMethodZigNames(allocator, file, &lhs);
    }
    for (file.annotations, 0..) |lhs, i| {
        for (file.annotations[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

pub fn validateTopLevelFixedHelperZigNames(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    const fixed_names = [_][]const u8{
        "initRoot",
        "getRoot",
        "getRootTyped",
        "newOrphan",
        "newOrphanIn",
        "newOrphanCopy",
        "newOrphanCopyCanonical",
        "newOrphanCopyFromBuilder",
        "newOrphanCopyCanonicalFromBuilder",
        "newOrphanCopyIn",
        "newOrphanCopyCanonicalIn",
        "newOrphanCopyFromBuilderIn",
        "newOrphanCopyCanonicalFromBuilderIn",
    };
    for (fixed_names) |name| {
        for (file.structs) |decl| {
            const struct_name = try zigIdentAlloc(allocator, decl.name);
            defer allocator.free(struct_name);
            if (std.mem.eql(u8, name, struct_name)) return error.NameCollision;
        }
    }
}

pub fn validateImportZigNames(allocator: std.mem.Allocator, imports: []const ImportDecl) LayoutError!void {
    for (imports, 0..) |lhs, i| {
        for (imports[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

pub fn validateFieldZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!void {
    try validateStructFixedMemberZigNames(allocator, decl);
    try validateBuilderFieldHelperZigNames(allocator, file, decl);
    try validateStructGroupZigNames(allocator, decl);
    for (decl.fields, 0..) |*lhs, i| {
        for (decl.fields[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.consts) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        try validateFieldDefaultHelperZigName(allocator, decl, lhs);
        try validateEnumFieldRawHelperZigName(allocator, file, decl, lhs);
        try validatePointerFieldHelperZigNames(allocator, file, decl, lhs);
        try validateListFieldWrapperZigNames(allocator, file, decl, lhs);
    }
    try validateStructConstFlatZigNames(allocator, file, decl);
    for (decl.consts, 0..) |lhs, i| {
        for (decl.consts[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
    for (decl.aliases, 0..) |lhs, i| {
        for (decl.aliases[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

pub fn validateStructGroupZigNames(allocator: std.mem.Allocator, decl: *const Struct) LayoutError!void {
    for (decl.groups, 0..) |lhs, i| {
        for (decl.groups[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

pub fn validateBuilderFieldHelperZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!void {
    var names = std.StringHashMap(void).init(allocator);
    var owned_names = std.ArrayList([]const u8).empty;
    defer names.deinit();
    defer {
        for (owned_names.items) |name| allocator.free(name);
        owned_names.deinit(allocator);
    }

    for (decl.fields) |*field| {
        try appendBuilderFieldHelperZigNames(allocator, file, decl, field, &names, &owned_names);
    }
}

pub fn appendBuilderFieldHelperZigNames(
    allocator: std.mem.Allocator,
    file: *const File,
    decl: *const Struct,
    field: *const Field,
    names: *std.StringHashMap(void),
    owned_names: *std.ArrayList([]const u8),
) LayoutError!void {
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);

    switch (resolveTypeScoped(file, decl, field.ty)) {
        .void => {
            try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}", .{field_name});
            return;
        },
        .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => {
            try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
            try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}", .{field_name});
            return;
        },
        .named => |type_name| if (findEnum(file, type_name) != null) {
            try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
            try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}_raw", .{field_name});
            try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}", .{field_name});
            try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}_raw", .{field_name});
            return;
        },
        else => {},
    }

    if (!fieldEmitsPointerHelpers(file, decl, field)) return;
    try appendCommonPointerBuilderHelperNames(allocator, field_name, names, owned_names);
    try appendTypedPointerBuilderHelperNames(allocator, file, decl, field, field_name, names, owned_names);
}

pub fn addBuilderHelperNameFmt(
    allocator: std.mem.Allocator,
    names: *std.StringHashMap(void),
    owned_names: *std.ArrayList([]const u8),
    comptime fmt: []const u8,
    args: anytype,
) LayoutError!void {
    const name = try std.fmt.allocPrint(allocator, fmt, args);
    errdefer allocator.free(name);
    const entry = try names.getOrPut(name);
    if (entry.found_existing) return error.NameCollision;
    errdefer _ = names.remove(name);
    try owned_names.append(allocator, name);
}

pub fn appendCommonPointerBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "has_{s}", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "clear_{s}", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "disown_{s}", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "adopt_{s}", .{field_name});

    const suffixes = [_][]const u8{
        "AsPointer",
        "AsReader",
        "PointerKind",
        "PointerSegmentId",
        "PointerWordIndex",
        "PointerMatchesLocation",
        "MatchesPointerKind",
        "PointerIsStruct",
        "PointerIsList",
        "PointerIsFar",
        "PointerIsOther",
        "PointerIsCapability",
        "PointerIsNear",
        "RawPointer",
        "DecodedPointer",
        "MaxCapabilityCount",
        "MatchesMaxCapabilityCount",
        "Stats",
        "StatsWithOptions",
        "TotalSize",
        "TotalSizeWithOptions",
    };
    for (suffixes) |suffix| {
        try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}{s}", .{ field_name, suffix });
    }
}

pub fn appendTypedPointerBuilderHelperNames(
    allocator: std.mem.Allocator,
    file: *const File,
    decl: *const Struct,
    field: *const Field,
    field_name: []const u8,
    names: *std.StringHashMap(void),
    owned_names: *std.ArrayList([]const u8),
) LayoutError!void {
    const field_is_optional = field.ty == .optional;
    switch (pointerFieldPayloadType(file, decl, field)) {
        .text, .data => {
            try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{ "", "OrNull", "ByteCount", "MatchesBytes" });
            try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "", "OrNull" });
            try addBuilderHelperNameFmt(allocator, names, owned_names, "new_{s}_orphan", .{field_name});
        },
        .list => try appendListBuilderHelperNames(allocator, field_name, field_is_optional, names, owned_names),
        .any_pointer => try appendAnyPointerBuilderHelperNames(allocator, field_name, field_is_optional, names, owned_names),
        .any_struct => try appendAnyStructBuilderHelperNames(allocator, field_name, field_is_optional, names, owned_names),
        .any_list => try appendAnyListBuilderHelperNames(allocator, field_name, field_is_optional, names, owned_names),
        .capability => try appendCapabilityBuilderHelperNames(allocator, field_name, names, owned_names),
        .named => |type_name| {
            if (findInterface(file, type_name) != null) {
                try appendCapabilityBuilderHelperNames(allocator, field_name, names, owned_names);
            } else if (!isStructLikeName(file, type_name)) {
                try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
                try appendPointerCopyBuilderHelperNames(allocator, field_name, names, owned_names);
            } else {
                try appendStructBuilderHelperNames(allocator, field_name, field_is_optional, names, owned_names);
            }
        },
        else => {},
    }
}

pub fn appendBuilderGetSuffixes(allocator: std.mem.Allocator, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8), field_name: []const u8, suffixes: []const []const u8) LayoutError!void {
    for (suffixes) |suffix| try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}{s}", .{ field_name, suffix });
}

pub fn appendBuilderSetSuffixes(allocator: std.mem.Allocator, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8), field_name: []const u8, suffixes: []const []const u8) LayoutError!void {
    for (suffixes) |suffix| try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}{s}", .{ field_name, suffix });
}

pub fn appendPointerCopyBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "_from", "_canonicalFrom", "_fromBuilder", "_canonicalFromBuilder" });
    const new_suffixes = [_][]const u8{ "_copyOrphan", "_copyOrphanCanonical", "_copyOrphanFromBuilder", "_copyOrphanCanonicalFromBuilder" };
    for (new_suffixes) |suffix| try addBuilderHelperNameFmt(allocator, names, owned_names, "new_{s}{s}", .{ field_name, suffix });
}

pub fn appendListBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, field_is_optional: bool, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
    if (field_is_optional) try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{"OrNull"});
    if (field_is_optional) try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{"OrNull"});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "init_{s}", .{field_name});
    try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "_from", "_canonicalFrom", "_fromBuilder", "_canonicalFromBuilder" });
    try addBuilderHelperNameFmt(allocator, names, owned_names, "disown_{s}_typed", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "adopt_{s}_typed", .{field_name});
}

pub fn appendAnyPointerBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, field_is_optional: bool, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
    if (field_is_optional) try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{"OrNull"});
    if (field_is_optional) try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "OrNull", "OrNullFromBuilder" });
    try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{ "PointerType", "AsStruct", "AsList", "AsText", "AsTextByteCount", "AsTextMatchesBytes", "AsData", "AsDataByteCount", "AsDataMatchesBytes", "AsCapability" });
    try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}", .{field_name});
    try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "_canonicalFrom", "_fromBuilder", "_canonicalFromBuilder", "_text", "_data", "_capability" });
    const init_suffixes = [_][]const u8{ "_struct", "_list", "_structList" };
    for (init_suffixes) |suffix| try addBuilderHelperNameFmt(allocator, names, owned_names, "init_{s}{s}", .{ field_name, suffix });
}

pub fn appendAnyStructBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, field_is_optional: bool, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
    if (field_is_optional) try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{"OrNull"});
    if (field_is_optional) try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "OrNullFrom", "OrNullFromBuilder" });
    try addBuilderHelperNameFmt(allocator, names, owned_names, "init_{s}", .{field_name});
    try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "_from", "_canonicalFrom", "_fromBuilder", "_canonicalFromBuilder" });
    try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{ "PointerSection", "DataSection" });
}

pub fn appendAnyListBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, field_is_optional: bool, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
    if (field_is_optional) try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{"OrNull"});
    if (field_is_optional) try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "OrNullFrom", "OrNullFromBuilder" });
    try addBuilderHelperNameFmt(allocator, names, owned_names, "init_{s}", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "init_{s}_structList", .{field_name});
    try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "_from", "_canonicalFrom", "_fromBuilder", "_canonicalFromBuilder" });
}

pub fn appendCapabilityBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}OrNull", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}FromTable", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}OrNullFromTable", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "set_{s}OrNull", .{field_name});
}

pub fn appendStructBuilderHelperNames(allocator: std.mem.Allocator, field_name: []const u8, field_is_optional: bool, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8)) LayoutError!void {
    try addBuilderHelperNameFmt(allocator, names, owned_names, "get_{s}", .{field_name});
    if (field_is_optional) try appendBuilderGetSuffixes(allocator, names, owned_names, field_name, &.{"OrNull"});
    if (field_is_optional) try appendBuilderSetSuffixes(allocator, names, owned_names, field_name, &.{ "OrNull", "OrNullFromBuilder" });
    try addBuilderHelperNameFmt(allocator, names, owned_names, "init_{s}", .{field_name});
    try appendPointerCopyBuilderHelperNames(allocator, field_name, names, owned_names);
    try addBuilderHelperNameFmt(allocator, names, owned_names, "new_{s}_orphan", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "disown_{s}_typed", .{field_name});
    try addBuilderHelperNameFmt(allocator, names, owned_names, "adopt_{s}_typed", .{field_name});
}

pub fn validateTopLevelConstFlatZigNames(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    for (file.consts) |*decl| {
        const generated_name = (try constFlatContainerNameAlloc(allocator, file, null, decl)) orelse continue;
        defer allocator.free(generated_name);
        try validateGeneratedTopLevelZigName(allocator, file, generated_name);
    }
}

pub fn validateStructConstFlatZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!void {
    for (decl.consts) |*constant| {
        try validateConstStructMemberZigNames(allocator, constant);
        const generated_name = (try constFlatContainerNameAlloc(allocator, file, decl, constant)) orelse continue;
        defer allocator.free(generated_name);
        try validateGeneratedStructMemberZigName(allocator, decl, null, generated_name);
    }
}

pub fn validateTopLevelConstStructMemberZigNames(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    for (file.consts) |*decl| {
        try validateConstStructMemberZigNames(allocator, decl);
    }
}

pub fn validateConstStructMemberZigNames(allocator: std.mem.Allocator, decl: *const ConstDecl) LayoutError!void {
    const fields = decl.struct_fields orelse return;
    var names = std.StringHashMap(void).init(allocator);
    defer names.deinit();
    var owned_names = std.ArrayList([]const u8).empty;
    defer {
        for (owned_names.items) |name| allocator.free(name);
        owned_names.deinit(allocator);
    }

    const fixed_names = [_][]const u8{
        "fieldCount",
        "fields",
        "flatBytes",
        "segment0",
        "segments",
        "reader",
        "root",
        "typedRoot",
        "validate",
        "totalSize",
        "fieldByIndex",
        "fieldByName",
        "fieldByLiteral",
    };
    for (fixed_names) |name| try addUniqueGeneratedName(allocator, &names, &owned_names, name);

    for (fields) |field| {
        const field_name = try zigIdentAlloc(allocator, field.name);
        defer allocator.free(field_name);
        try addUniqueGeneratedName(allocator, &names, &owned_names, field_name);
    }
}

pub fn addUniqueGeneratedName(allocator: std.mem.Allocator, names: *std.StringHashMap(void), owned_names: *std.ArrayList([]const u8), raw_name: []const u8) LayoutError!void {
    const name = try allocator.dupe(u8, raw_name);
    errdefer allocator.free(name);
    const entry = try names.getOrPut(name);
    if (entry.found_existing) return error.NameCollision;
    errdefer _ = names.remove(name);
    try owned_names.append(allocator, name);
}

pub fn validateGeneratedTopLevelZigName(allocator: std.mem.Allocator, file: *const File, generated_name: []const u8) LayoutError!void {
    for (file.structs) |decl| {
        const name = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(name);
        if (std.mem.eql(u8, generated_name, name)) return error.NameCollision;
    }
    for (file.enums) |decl| {
        const name = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(name);
        if (std.mem.eql(u8, generated_name, name)) return error.NameCollision;
    }
    for (file.consts) |decl| {
        const name = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(name);
        if (std.mem.eql(u8, generated_name, name)) return error.NameCollision;
    }
    for (file.aliases) |decl| {
        const name = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(name);
        if (std.mem.eql(u8, generated_name, name)) return error.NameCollision;
    }
    for (file.interfaces) |decl| {
        const name = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(name);
        if (std.mem.eql(u8, generated_name, name)) return error.NameCollision;
    }
    for (file.annotations) |decl| {
        const name = try zigIdentAlloc(allocator, decl.name);
        defer allocator.free(name);
        if (std.mem.eql(u8, generated_name, name)) return error.NameCollision;
    }
}

pub fn validateStructFixedMemberZigNames(allocator: std.mem.Allocator, decl: *const Struct) LayoutError!void {
    // These members are emitted for every generated struct before schema field
    // accessors and nested user declarations.  Validating them here turns what
    // would otherwise be a generated Zig duplicate-declaration error into the
    // same deterministic NameCollision reported for user-visible schema names.
    const fixed_names = [_][]const u8{
        "size",
        "Orphan",
        "initRoot",
        "getRoot",
        "getRootTyped",
        "newOrphan",
        "newOrphanIn",
        "newOrphanCopy",
        "newOrphanCopyCanonical",
        "newOrphanCopyFromBuilder",
        "newOrphanCopyCanonicalFromBuilder",
        "newOrphanCopyIn",
        "newOrphanCopyCanonicalIn",
        "newOrphanCopyFromBuilderIn",
        "newOrphanCopyCanonicalFromBuilderIn",
        "fromReader",
        "validate",
        "validateWithOptions",
        "totalSize",
        "totalSizeWithOptions",
        "actualSize",
        "actualDataWordCount",
        "actualPointerCount",
        "actualTotalWords",
        "actualDataByteCount",
        "actualPointerByteCount",
        "actualTotalByteCount",
        "matchesActualSize",
        "matchesActualDataWords",
        "matchesActualPointerCount",
        "matchesActualTotalWords",
        "matchesActualDataBytes",
        "matchesActualPointerBytes",
        "matchesActualTotalBytes",
        "dataSection",
        "pointerSection",
        "initRootTyped",
        "Builder",
    };
    for (fixed_names) |name| {
        try validateGeneratedStructMemberZigName(allocator, decl, null, name);
    }

    for (decl.unions, 0..) |_, union_index| {
        try validateGeneratedStructMemberZigNameFmt(allocator, decl, null, "Union{}", .{union_index});
        try validateGeneratedStructMemberZigNameFmt(allocator, decl, null, "union{}Discriminant", .{union_index});
        try validateGeneratedStructMemberZigNameFmt(allocator, decl, null, "union{}", .{union_index});
        try validateGeneratedStructMemberZigNameFmt(allocator, decl, null, "union{}Is", .{union_index});
        try validateGeneratedStructMemberZigNameFmt(allocator, decl, null, "union{}MatchesDiscriminant", .{union_index});
        try validateGeneratedStructMemberZigNameFmt(allocator, decl, null, "union{}Field", .{union_index});
    }
    if (decl.unions.len == 1) {
        const which_names = [_][]const u8{
            "whichDiscriminant",
            "which",
            "whichIs",
            "whichMatchesDiscriminant",
            "whichField",
        };
        for (which_names) |name| {
            try validateGeneratedStructMemberZigName(allocator, decl, null, name);
        }
    }
}

pub fn constFlatContainerNameAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl) LayoutError!?[]u8 {
    if (!constEmitsFlatContainer(file, scope, decl)) return null;
    const const_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(const_name);
    return try std.fmt.allocPrint(allocator, "{s}Flat", .{const_name});
}

pub fn constEmitsFlatContainer(file: *const File, scope: ?*const Struct, decl: *const ConstDecl) bool {
    if (!decl.emit_value) return false;
    return constTypeEmitsFlatContainer(file, scope, decl, resolveTypeScoped(file, scope, decl.ty));
}

pub fn constTypeEmitsFlatContainer(file: *const File, scope: ?*const Struct, decl: *const ConstDecl, ty: Type) bool {
    const raw = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, decl.literal), " \t\r\n");
    return switch (ty) {
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => true,
        .text, .data, .list => true,
        .capability, .any_pointer, .any_struct, .any_list => methodDefaultIsVoidOrNull(file, scope, raw),
        .named => |type_name| if (findEnum(file, type_name) != null)
            true
        else if (findInterface(file, type_name) != null)
            methodDefaultIsVoidOrNull(file, scope, raw)
        else if (isStructLikeName(file, type_name))
            methodDefaultIsNull(file, scope, raw)
        else
            false,
        .optional => |child| if (std.mem.eql(u8, raw, "null") or (std.mem.eql(u8, raw, "void") and typeAcceptsVoidPointerDefault(file, resolveTypeScoped(file, scope, child.*))))
            true
        else
            constTypeEmitsFlatContainer(file, scope, decl, resolveTypeScoped(file, scope, child.*)),
    };
}

pub fn validateFieldDefaultHelperZigName(allocator: std.mem.Allocator, decl: *const Struct, field: *const Field) LayoutError!void {
    if (field.default_expression.len == 0) return;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    const default_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(default_name);
    const default_flat_name = try std.fmt.allocPrint(allocator, "{s}DefaultFlat", .{field_name});
    defer allocator.free(default_flat_name);

    try validateGeneratedStructMemberZigName(allocator, decl, field, default_name);
    try validateGeneratedStructMemberZigName(allocator, decl, field, default_flat_name);
}

pub fn validateEnumFieldRawHelperZigName(allocator: std.mem.Allocator, file: *const File, decl: *const Struct, field: *const Field) LayoutError!void {
    const type_name = switch (resolveTypeScoped(file, decl, field.ty)) {
        .named => |name| name,
        else => return,
    };
    if (findEnum(file, type_name) == null) return;

    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    const raw_name = try std.fmt.allocPrint(allocator, "{s}_raw", .{field_name});
    defer allocator.free(raw_name);

    try validateGeneratedStructMemberZigName(allocator, decl, field, raw_name);
}

pub fn validateListFieldWrapperZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const Struct, field: *const Field) LayoutError!void {
    if (!fieldEmitsListWrappers(file, decl, field)) return;

    const owner_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(owner_name);
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);

    const reader_name = try std.fmt.allocPrint(allocator, "{s}_{s}_List", .{ owner_name, field_name });
    defer allocator.free(reader_name);
    const builder_name = try std.fmt.allocPrint(allocator, "{s}_{s}_BuilderList", .{ owner_name, field_name });
    defer allocator.free(builder_name);
    const orphan_name = try std.fmt.allocPrint(allocator, "{s}_{s}_Orphan", .{ owner_name, field_name });
    defer allocator.free(orphan_name);

    try validateGeneratedStructMemberZigName(allocator, decl, field, reader_name);
    try validateGeneratedStructMemberZigName(allocator, decl, field, builder_name);
    try validateGeneratedStructMemberZigName(allocator, decl, field, orphan_name);
}

pub fn validatePointerFieldHelperZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const Struct, field: *const Field) LayoutError!void {
    if (!fieldEmitsPointerHelpers(file, decl, field)) return;

    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);

    // Keep this list aligned with the reader-side helpers emitted
    // unconditionally near the top of emitPointerGetter().  These helper names
    // share the same generated struct namespace as field accessors, nested
    // constants, and aliases, so accepting a schema-visible member with the
    // same sanitized Zig name would only defer the failure until Zig compiles
    // the generated source.
    try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "has_{s}", .{field_name});
    const common_suffixes = [_][]const u8{
        "AsPointer",
        "PointerKind",
        "PointerSegmentId",
        "PointerWordIndex",
        "PointerMatchesLocation",
        "MatchesPointerKind",
        "PointerIsStruct",
        "PointerIsList",
        "PointerIsFar",
        "PointerIsOther",
        "PointerIsCapability",
        "PointerIsNear",
        "RawPointer",
        "DecodedPointer",
        "MaxCapabilityCount",
        "MatchesMaxCapabilityCount",
        "Stats",
        "StatsWithOptions",
        "TotalSize",
        "TotalSizeWithOptions",
        "StructSize",
        "StructDataWordCount",
        "StructPointerCount",
        "StructTotalWords",
        "StructDataByteCount",
        "StructPointerByteCount",
        "StructTotalByteCount",
        "StructMatchesSize",
        "StructMatchesDataWords",
        "StructMatchesPointerCount",
        "StructMatchesTotalWords",
        "StructMatchesTotalBytes",
        "ListLen",
        "ListMatchesLen",
        "ListElementSize",
        "ListMatchesElementSize",
        "ListElementBitCount",
        "ListElementByteCount",
        "ListElementWordCount",
        "ListContentBitCount",
        "ListContentByteCount",
        "ListContentWordCount",
        "ListMatchesContentBytes",
        "ListStructElementSize",
        "ListMatchesStructElementSize",
        "ListIsEmpty",
        "ListHasIndex",
        "ListFirstIndex",
        "ListLastIndex",
        "ListMatchesElementBits",
        "ListMatchesElementBytes",
        "ListMatchesElementWords",
        "ListMatchesContentBits",
        "ListMatchesContentWords",
        "ListStructElementDataWordCount",
        "ListStructElementPointerCount",
        "ListStructElementTotalWords",
        "ListStructElementDataByteCount",
        "ListStructElementPointerByteCount",
        "ListStructElementTotalByteCount",
        "ListMatchesStructElementDataWords",
        "ListMatchesStructElementPointerCount",
        "ListMatchesStructElementTotalWords",
        "ListMatchesStructElementDataBytes",
        "ListMatchesStructElementPointerBytes",
        "ListMatchesStructElementTotalBytes",
    };
    for (common_suffixes) |suffix| {
        try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}{s}", .{ field_name, suffix });
    }

    const field_is_optional = field.ty == .optional;
    switch (pointerFieldPayloadType(file, decl, field)) {
        .text, .data => {
            const suffixes = [_][]const u8{ "OrNull", "ByteCount", "MatchesBytes" };
            for (suffixes) |suffix| {
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}{s}", .{ field_name, suffix });
            }
        },
        .any_pointer => {
            const suffixes = [_][]const u8{
                "PointerType",
                "AsStruct",
                "AsList",
                "AsText",
                "AsTextByteCount",
                "AsTextMatchesBytes",
                "AsData",
                "AsDataByteCount",
                "AsDataMatchesBytes",
                "AsCapability",
            };
            for (suffixes) |suffix| {
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}{s}", .{ field_name, suffix });
            }
            if (field_is_optional) try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNull", .{field_name});
        },
        .any_struct => {
            const suffixes = [_][]const u8{ "PointerSection", "DataSection" };
            for (suffixes) |suffix| {
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}{s}", .{ field_name, suffix });
            }
            if (field_is_optional) try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNull", .{field_name});
        },
        .any_list, .list => if (field_is_optional) {
            try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNull", .{field_name});
        },
        .capability => {
            try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNull", .{field_name});
            try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}FromTable", .{field_name});
            try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNullFromTable", .{field_name});
        },
        .named => |type_name| {
            if (findInterface(file, type_name) != null) {
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNull", .{field_name});
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}FromTable", .{field_name});
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNullFromTable", .{field_name});
            } else if (field_is_optional and isStructLikeName(file, type_name)) {
                try validatePointerFieldHelperZigNameFmt(allocator, decl, field, "{s}OrNull", .{field_name});
            }
        },
        else => {},
    }
}

pub fn fieldEmitsPointerHelpers(file: *const File, decl: *const Struct, field: *const Field) bool {
    return switch (resolveTypeScoped(file, decl, field.ty)) {
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list, .optional => true,
        .named => |name| findEnum(file, name) == null,
        else => false,
    };
}

pub fn fieldEmitsListWrappers(file: *const File, decl: *const Struct, field: *const Field) bool {
    return switch (resolveTypeScoped(file, decl, field.ty)) {
        .list => true,
        .optional => |child| resolveTypeScoped(file, decl, child.*) == .list,
        else => false,
    };
}

pub fn pointerFieldPayloadType(file: *const File, decl: *const Struct, field: *const Field) Type {
    return if (field.ty == .optional)
        resolveTypeScoped(file, decl, field.ty.optional.*)
    else
        resolveTypeScoped(file, decl, field.ty);
}

pub fn validatePointerFieldHelperZigNameFmt(allocator: std.mem.Allocator, decl: *const Struct, field: *const Field, comptime fmt: []const u8, args: anytype) LayoutError!void {
    const name = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(name);
    try validateGeneratedStructMemberZigName(allocator, decl, field, name);
}

pub fn validateGeneratedStructMemberZigNameFmt(allocator: std.mem.Allocator, decl: *const Struct, source_field: ?*const Field, comptime fmt: []const u8, args: anytype) LayoutError!void {
    const name = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(name);
    try validateGeneratedStructMemberZigName(allocator, decl, source_field, name);
}

pub fn validateGeneratedStructMemberZigName(allocator: std.mem.Allocator, decl: *const Struct, source_field: ?*const Field, generated_name: []const u8) LayoutError!void {
    for (decl.fields) |*other| {
        if (source_field) |source| {
            if (source == other) continue;
        }
        const other_name = try zigIdentAlloc(allocator, other.name);
        defer allocator.free(other_name);
        if (std.mem.eql(u8, generated_name, other_name)) return error.NameCollision;
    }
    for (decl.consts) |constant| {
        const const_name = try zigIdentAlloc(allocator, constant.name);
        defer allocator.free(const_name);
        if (std.mem.eql(u8, generated_name, const_name)) return error.NameCollision;
    }
    for (decl.aliases) |alias| {
        const alias_name = try zigIdentAlloc(allocator, alias.name);
        defer allocator.free(alias_name);
        if (std.mem.eql(u8, generated_name, alias_name)) return error.NameCollision;
    }
}

pub fn validateEnumValueZigNames(allocator: std.mem.Allocator, decl: *const EnumDecl) LayoutError!void {
    for (decl.values, 0..) |lhs, i| {
        for (decl.values[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

pub fn validateInterfaceMethodZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const InterfaceDecl) LayoutError!void {
    try validateInterfaceSuperclassZigNames(allocator, decl);
    try validateInterfaceConstFlatZigNames(allocator, file, decl);
    for (decl.methods, 0..) |lhs, i| {
        for (decl.methods[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.consts) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
    for (decl.consts, 0..) |lhs, i| {
        for (decl.consts[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.aliases) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
    for (decl.aliases, 0..) |lhs, i| {
        for (decl.aliases[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

pub fn validateInterfaceConstFlatZigNames(allocator: std.mem.Allocator, file: *const File, decl: *const InterfaceDecl) LayoutError!void {
    var empty_fields: [0]Field = .{};
    const scope = Struct{
        .name = decl.name,
        .fields = empty_fields[0..],
        .consts = decl.consts,
        .aliases = decl.aliases,
    };
    for (decl.consts) |*constant| {
        try validateConstStructMemberZigNames(allocator, constant);
        const generated_name = (try constFlatContainerNameAlloc(allocator, file, &scope, constant)) orelse continue;
        defer allocator.free(generated_name);

        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            if (std.mem.eql(u8, generated_name, method_name)) return error.NameCollision;
        }
        for (decl.consts) |other| {
            const const_name = try zigIdentAlloc(allocator, other.name);
            defer allocator.free(const_name);
            if (std.mem.eql(u8, generated_name, const_name)) return error.NameCollision;
        }
        for (decl.aliases) |alias| {
            const alias_name = try zigIdentAlloc(allocator, alias.name);
            defer allocator.free(alias_name);
            if (std.mem.eql(u8, generated_name, alias_name)) return error.NameCollision;
        }
    }
}

pub fn validateInterfaceSuperclassZigNames(allocator: std.mem.Allocator, decl: *const InterfaceDecl) LayoutError!void {
    for (decl.superclasses, 0..) |_, index| {
        const generated_name = try std.fmt.allocPrint(allocator, "Superclass{}", .{index});
        defer allocator.free(generated_name);

        for (decl.methods) |method| {
            const method_name = try zigIdentAlloc(allocator, method.name);
            defer allocator.free(method_name);
            if (std.mem.eql(u8, generated_name, method_name)) return error.NameCollision;
        }
        for (decl.consts) |constant| {
            const const_name = try zigIdentAlloc(allocator, constant.name);
            defer allocator.free(const_name);
            if (std.mem.eql(u8, generated_name, const_name)) return error.NameCollision;
        }
        for (decl.aliases) |alias| {
            const alias_name = try zigIdentAlloc(allocator, alias.name);
            defer allocator.free(alias_name);
            if (std.mem.eql(u8, generated_name, alias_name)) return error.NameCollision;
        }
    }
}
