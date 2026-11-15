const std = @import("std");
const message = @import("../message.zig");
const serialize = @import("../serialize.zig");
const wire = @import("../wire.zig");
const zig_names = @import("zig_names.zig");
const zigNamesEqual = zig_names.zigNamesEqual;

/// Syntax, semantic, and allocation errors produced by schema parsing.
pub const Error = error{
    UnexpectedToken,
    InvalidToken,
    InvalidOrdinal,
    NameCollision,
    OrdinalCollision,
    UnsupportedType,
} || std.mem.Allocator.Error || std.fmt.ParseIntError;

/// Schema type expression as written in a `.capnp` file.
pub const Type = union(enum) {
    void,
    bool,
    int8,
    int16,
    int32,
    int64,
    uint8,
    uint16,
    uint32,
    uint64,
    float32,
    float64,
    text,
    data,
    any_pointer,
    any_struct,
    any_list,
    capability,
    list: *Type,
    optional: *Type,
    named: []const u8,

    pub fn deinit(self: *Type, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .list, .optional => |child| {
                child.deinit(allocator);
                allocator.destroy(child);
            },
            else => {},
        }
        self.* = undefined;
    }
};

pub fn typesEqual(lhs: Type, rhs: Type) bool {
    return switch (lhs) {
        .void => switch (rhs) {
            .void => true,
            else => false,
        },
        .bool => switch (rhs) {
            .bool => true,
            else => false,
        },
        .int8 => switch (rhs) {
            .int8 => true,
            else => false,
        },
        .int16 => switch (rhs) {
            .int16 => true,
            else => false,
        },
        .int32 => switch (rhs) {
            .int32 => true,
            else => false,
        },
        .int64 => switch (rhs) {
            .int64 => true,
            else => false,
        },
        .uint8 => switch (rhs) {
            .uint8 => true,
            else => false,
        },
        .uint16 => switch (rhs) {
            .uint16 => true,
            else => false,
        },
        .uint32 => switch (rhs) {
            .uint32 => true,
            else => false,
        },
        .uint64 => switch (rhs) {
            .uint64 => true,
            else => false,
        },
        .float32 => switch (rhs) {
            .float32 => true,
            else => false,
        },
        .float64 => switch (rhs) {
            .float64 => true,
            else => false,
        },
        .text => switch (rhs) {
            .text => true,
            else => false,
        },
        .data => switch (rhs) {
            .data => true,
            else => false,
        },
        .any_pointer => switch (rhs) {
            .any_pointer => true,
            else => false,
        },
        .any_struct => switch (rhs) {
            .any_struct => true,
            else => false,
        },
        .any_list => switch (rhs) {
            .any_list => true,
            else => false,
        },
        .capability => switch (rhs) {
            .capability => true,
            else => false,
        },
        .named => |name| switch (rhs) {
            .named => |other| std.mem.eql(u8, name, other),
            else => false,
        },
        .list => |child| switch (rhs) {
            .list => |other| typesEqual(child.*, other.*),
            else => false,
        },
        .optional => |child| switch (rhs) {
            .optional => |other| typesEqual(child.*, other.*),
            else => false,
        },
    };
}

/// A struct field, including its ordinal, type, default, and union metadata.
pub const Field = struct {
    name: []const u8,
    owns_name: bool = false,
    ordinal: u32,
    ty: Type,
    default_literal: ?[]const u8 = null,
    owns_default_literal: bool = false,
    default_is_hex_data: bool = false,
    default_expression: []const u8 = "",
    annotations: []const u8 = "",
    union_index: ?u32 = null,
    union_member_index: ?u32 = null,
    union_discriminant: u16 = 0,

    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        if (self.owns_default_literal) if (self.default_literal) |literal| allocator.free(literal);
        if (self.owns_name) allocator.free(self.name);
        self.* = undefined;
    }
};

/// A `using` alias declaration.
pub const AliasDecl = struct {
    name: []const u8,
    target: Type,

    pub fn deinit(self: *AliasDecl, allocator: std.mem.Allocator) void {
        self.target.deinit(allocator);
        self.* = undefined;
    }
};

pub const AliasMetadata = struct {
    index: usize = 0,
    name: []const u8,
    target: []const u8,
    resolved_target: []const u8 = "",

    pub fn matchesIndex(self: AliasMetadata, alias_index: usize) bool {
        return self.index == alias_index;
    }

    pub fn matchesName(self: AliasMetadata, alias_name: []const u8) bool {
        return std.mem.eql(u8, self.name, alias_name);
    }

    pub fn hasTarget(self: AliasMetadata) bool {
        return self.target.len != 0;
    }

    pub fn matchesTarget(self: AliasMetadata, target: []const u8) bool {
        return std.mem.eql(u8, self.target, target);
    }

    pub fn hasResolvedTarget(self: AliasMetadata) bool {
        return self.resolved_target.len != 0;
    }

    pub fn matchesResolvedTarget(self: AliasMetadata, target: []const u8) bool {
        return std.mem.eql(u8, self.resolved_target, target);
    }
};

/// A top-level, struct-local, or interface-local constant declaration.
pub const ConstDecl = struct {
    name: []const u8,
    id: ?u64 = null,
    ty: Type,
    literal: []const u8,
    owns_literal: bool = false,
    is_hex_data: bool = false,
    literal_is_string: bool = false,
    is_embed: bool = false,
    embed_path: []const u8 = "",
    embed_bytes: ?[]const u8 = null,
    owns_embed_bytes: bool = false,
    is_struct_literal: bool = false,
    emit_value: bool = true,
    annotations: []const u8 = "",
    list_items: ?[]ConstListItem = null,
    struct_fields: ?[]ConstStructField = null,

    pub fn deinit(self: *ConstDecl, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        if (self.owns_literal) allocator.free(self.literal);
        if (self.owns_embed_bytes) if (self.embed_bytes) |bytes| allocator.free(bytes);
        if (self.list_items) |items| {
            deinitConstListItems(allocator, items);
            allocator.free(items);
        }
        if (self.struct_fields) |fields| allocator.free(fields);
        self.* = undefined;
    }
};

pub const ConstListItem = struct {
    index: usize = 0,
    literal: []const u8,
    owns_literal: bool = false,
    is_hex_data: bool = false,
    annotations: []const u8 = "",
    struct_field_count: usize = 0,
    struct_fields: []const ConstStructField = &.{},
    owns_struct_fields: bool = false,

    pub fn matchesIndex(self: ConstListItem, item_index: usize) bool {
        return self.index == item_index;
    }

    pub fn matchesLiteral(self: ConstListItem, item_literal: []const u8) bool {
        return std.mem.eql(u8, self.literal, item_literal);
    }

    pub fn hasAnnotations(self: ConstListItem) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: ConstListItem, item_annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, item_annotations);
    }

    pub fn matchesHexData(self: ConstListItem, is_hex: bool) bool {
        return self.is_hex_data == is_hex;
    }

    pub fn hasStructFields(self: ConstListItem) bool {
        return self.struct_field_count != 0;
    }

    pub fn matchesStructFieldCount(self: ConstListItem, count: usize) bool {
        return self.struct_field_count == count;
    }

    pub fn structFieldByIndex(self: ConstListItem, field_index: usize) ?ConstStructField {
        if (field_index >= self.struct_fields.len) return null;
        return self.struct_fields[field_index];
    }

    pub fn structFieldByName(self: ConstListItem, field_name: []const u8) ?ConstStructField {
        for (self.struct_fields) |field| if (std.mem.eql(u8, field.name, field_name)) return field;
        return null;
    }

    pub fn structFieldByLiteral(self: ConstListItem, field_literal: []const u8) ?ConstStructField {
        for (self.struct_fields) |field| if (std.mem.eql(u8, field.literal, field_literal)) return field;
        return null;
    }
};

pub const ConstStructField = struct {
    index: usize = 0,
    name: []const u8,
    literal: []const u8,

    pub fn matchesIndex(self: ConstStructField, field_index: usize) bool {
        return self.index == field_index;
    }

    pub fn matchesName(self: ConstStructField, field_name: []const u8) bool {
        return std.mem.eql(u8, self.name, field_name);
    }

    pub fn matchesLiteral(self: ConstStructField, field_literal: []const u8) bool {
        return std.mem.eql(u8, self.literal, field_literal);
    }
};

pub const ConstMetadata = struct {
    index: usize = 0,
    name: []const u8,
    id: ?u64 = null,
    ty: []const u8,
    resolved_ty: []const u8 = "",
    literal: []const u8 = "",
    is_hex_data: bool = false,
    is_embed: bool = false,
    embed_path: []const u8 = "",
    embed_byte_count: usize = 0,
    is_struct_literal: bool = false,
    emitted: bool = true,
    annotations: []const u8 = "",
    list_item_count: usize = 0,
    list_items: []const ConstListItem = &.{},
    struct_field_count: usize = 0,
    struct_fields: []const ConstStructField = &.{},

    pub fn matchesIndex(self: ConstMetadata, const_index: usize) bool {
        return self.index == const_index;
    }

    pub fn matchesName(self: ConstMetadata, const_name: []const u8) bool {
        return std.mem.eql(u8, self.name, const_name);
    }

    pub fn hasId(self: ConstMetadata) bool {
        return self.id != null;
    }

    pub fn matchesId(self: ConstMetadata, const_id: u64) bool {
        return self.id != null and self.id.? == const_id;
    }

    pub fn matchesType(self: ConstMetadata, const_type: []const u8) bool {
        return std.mem.eql(u8, self.ty, const_type);
    }

    pub fn matchesResolvedType(self: ConstMetadata, const_type: []const u8) bool {
        return std.mem.eql(u8, self.resolved_ty, const_type);
    }

    pub fn matchesLiteral(self: ConstMetadata, const_literal: []const u8) bool {
        return std.mem.eql(u8, self.literal, const_literal);
    }

    pub fn hasAnnotations(self: ConstMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: ConstMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }

    pub fn matchesHexData(self: ConstMetadata, is_hex: bool) bool {
        return self.is_hex_data == is_hex;
    }

    pub fn matchesEmbed(self: ConstMetadata, is_embed: bool) bool {
        return self.is_embed == is_embed;
    }

    pub fn matchesEmbedPath(self: ConstMetadata, path: []const u8) bool {
        return std.mem.eql(u8, self.embed_path, path);
    }

    pub fn matchesEmbedByteCount(self: ConstMetadata, count: usize) bool {
        return self.embed_byte_count == count;
    }

    pub fn hasEmbedBytes(self: ConstMetadata) bool {
        return self.is_embed and self.emitted;
    }

    pub fn matchesStructLiteral(self: ConstMetadata, is_struct: bool) bool {
        return self.is_struct_literal == is_struct;
    }

    pub fn hasEmbedPath(self: ConstMetadata) bool {
        return self.embed_path.len != 0;
    }

    pub fn matchesEmitted(self: ConstMetadata, is_emitted: bool) bool {
        return self.emitted == is_emitted;
    }

    pub fn hasListItems(self: ConstMetadata) bool {
        return self.list_item_count != 0;
    }

    pub fn matchesListItemCount(self: ConstMetadata, count: usize) bool {
        return self.list_item_count == count;
    }

    pub fn listItemByIndex(self: ConstMetadata, item_index: usize) ?ConstListItem {
        if (item_index >= self.list_items.len) return null;
        return self.list_items[item_index];
    }

    pub fn listItemByLiteral(self: ConstMetadata, literal: []const u8) ?ConstListItem {
        for (self.list_items) |item| if (std.mem.eql(u8, item.literal, literal)) return item;
        return null;
    }

    pub fn listItemByHexData(self: ConstMetadata, is_hex: bool) ?ConstListItem {
        for (self.list_items) |item| if (item.is_hex_data == is_hex) return item;
        return null;
    }

    pub fn listItemByAnnotations(self: ConstMetadata, annotations: []const u8) ?ConstListItem {
        for (self.list_items) |item| if (std.mem.eql(u8, item.annotations, annotations)) return item;
        return null;
    }

    pub fn listItemByStructFieldCount(self: ConstMetadata, count: usize) ?ConstListItem {
        for (self.list_items) |item| if (item.struct_field_count == count) return item;
        return null;
    }

    pub fn listItemByStructFieldName(self: ConstMetadata, field_name: []const u8) ?ConstListItem {
        for (self.list_items) |item| if (item.structFieldByName(field_name) != null) return item;
        return null;
    }

    pub fn listItemByStructFieldLiteral(self: ConstMetadata, field_literal: []const u8) ?ConstListItem {
        for (self.list_items) |item| if (item.structFieldByLiteral(field_literal) != null) return item;
        return null;
    }

    pub fn hasStructFields(self: ConstMetadata) bool {
        return self.struct_field_count != 0;
    }

    pub fn matchesStructFieldCount(self: ConstMetadata, count: usize) bool {
        return self.struct_field_count == count;
    }

    pub fn structFieldByIndex(self: ConstMetadata, field_index: usize) ?ConstStructField {
        if (field_index >= self.struct_fields.len) return null;
        return self.struct_fields[field_index];
    }

    pub fn structFieldByName(self: ConstMetadata, field_name: []const u8) ?ConstStructField {
        for (self.struct_fields) |field| if (std.mem.eql(u8, field.name, field_name)) return field;
        return null;
    }

    pub fn structFieldByLiteral(self: ConstMetadata, field_literal: []const u8) ?ConstStructField {
        for (self.struct_fields) |field| if (std.mem.eql(u8, field.literal, field_literal)) return field;
        return null;
    }
};

pub fn deinitConstListItems(allocator: std.mem.Allocator, items: []const ConstListItem) void {
    for (items) |item| {
        if (item.owns_literal) allocator.free(item.literal);
        if (item.owns_struct_fields) allocator.free(item.struct_fields);
    }
}

pub fn parseConstStructFieldsAlloc(allocator: std.mem.Allocator, expression: []const u8) Error![]ConstStructField {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    var index = try skipTriviaIndex(source, 0);
    if (index >= source.len or source[index] != '(') return error.UnexpectedToken;
    index += 1;

    var fields = std.ArrayList(ConstStructField).empty;
    errdefer fields.deinit(allocator);
    var names = std.StringHashMap(void).init(allocator);
    defer names.deinit();

    while (true) {
        index = try skipTriviaIndex(source, index);
        if (index >= source.len) return error.UnexpectedToken;
        if (source[index] == ')') {
            index += 1;
            break;
        }
        if (!isIdentStart(source[index])) return error.UnexpectedToken;
        const name_start = index;
        index += 1;
        while (index < source.len and isIdentContinue(source[index])) index += 1;
        const name = source[name_start..index];
        const entry = try names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;

        index = try skipTriviaIndex(source, index);
        if (index >= source.len or source[index] != '=') return error.UnexpectedToken;
        index += 1;
        index = try skipTriviaIndex(source, index);
        const literal_start = index;
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
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) break;
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
        const literal = std.mem.trim(u8, source[literal_start..index], " \t\r\n");
        if (literal.len == 0) return error.UnexpectedToken;
        try fields.append(allocator, .{ .index = fields.items.len, .name = name, .literal = literal });

        index = try skipTriviaIndex(source, index);
        if (index >= source.len) return error.UnexpectedToken;
        if (source[index] == ',') {
            index += 1;
            index = try skipTriviaIndex(source, index);
            if (index >= source.len) return error.UnexpectedToken;
            if (source[index] == ')') {
                index += 1;
                break;
            }
            continue;
        }
        if (source[index] == ')') {
            index += 1;
            break;
        }
        return error.UnexpectedToken;
    }

    index = try skipTriviaIndex(source, index);
    if (index != source.len) return error.UnexpectedToken;
    return fields.toOwnedSlice(allocator);
}

/// A parsed import declaration. Imports are resolved by the embedding build.
pub const ImportDecl = struct {
    name: []const u8,
    path: []const u8,
    member: ?[]const u8 = null,
};

pub const ImportMetadata = struct {
    index: usize = 0,
    name: []const u8,
    path: []const u8,
    member: []const u8 = "",
    has_member: bool = false,

    pub fn matchesIndex(self: ImportMetadata, import_index: usize) bool {
        return self.index == import_index;
    }

    pub fn matchesName(self: ImportMetadata, import_name: []const u8) bool {
        return std.mem.eql(u8, self.name, import_name);
    }

    pub fn hasPath(self: ImportMetadata) bool {
        return self.path.len != 0;
    }

    pub fn matchesPath(self: ImportMetadata, import_path: []const u8) bool {
        return std.mem.eql(u8, self.path, import_path);
    }

    pub fn hasMember(self: ImportMetadata) bool {
        return self.has_member;
    }

    pub fn matchesMember(self: ImportMetadata, import_member: []const u8) bool {
        return self.has_member and std.mem.eql(u8, self.member, import_member);
    }

    pub fn matchesMemberFlag(self: ImportMetadata, has_member: bool) bool {
        return self.has_member == has_member;
    }

    pub fn matchesPathAndMember(self: ImportMetadata, import_path: []const u8, import_member: []const u8) bool {
        return self.has_member and std.mem.eql(u8, self.path, import_path) and std.mem.eql(u8, self.member, import_member);
    }

    pub fn matchesPathAndMemberFlag(self: ImportMetadata, import_path: []const u8, has_member: bool) bool {
        return self.has_member == has_member and std.mem.eql(u8, self.path, import_path);
    }
};

pub const UnionBuilder = struct {
    fields: std.ArrayList(Field) = .empty,
    field_names: std.StringHashMap(void),
    name: []const u8 = "",
    ordinal: ?u32 = null,
    annotations: []const u8 = "",
    next_member_index: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) UnionBuilder {
        return .{ .field_names = std.StringHashMap(void).init(allocator) };
    }

    pub fn deinit(self: *UnionBuilder, allocator: std.mem.Allocator) void {
        for (self.fields.items) |*field| field.deinit(allocator);
        self.fields.deinit(allocator);
        self.field_names.deinit();
    }
};

pub const UnionDecl = struct {
    name: []const u8 = "",
    ordinal: ?u32 = null,
    annotations: []const u8 = "",
};

pub const GroupDecl = struct {
    index: usize = 0,
    name: []const u8,
    ordinal: ?u32 = null,
    annotations: []const u8 = "",

    pub fn matchesIndex(self: GroupDecl, group_index: usize) bool {
        return self.index == group_index;
    }

    pub fn matchesName(self: GroupDecl, group_name: []const u8) bool {
        return std.mem.eql(u8, self.name, group_name);
    }

    pub fn hasOrdinal(self: GroupDecl) bool {
        return self.ordinal != null;
    }

    pub fn matchesOrdinal(self: GroupDecl, ordinal: u32) bool {
        return self.ordinal != null and self.ordinal.? == ordinal;
    }

    pub fn hasAnnotations(self: GroupDecl) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: GroupDecl, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }
};

/// A parsed struct declaration before layout planning.
pub const Struct = struct {
    name: []const u8,
    owns_name: bool = false,
    id: ?u64 = null,
    annotations: []const u8 = "",
    parameters: []const []const u8 = &.{},
    fields: []Field,
    unions: []UnionDecl = &.{},
    groups: []GroupDecl = &.{},
    consts: []ConstDecl,
    aliases: []AliasDecl,

    pub fn deinit(self: *Struct, allocator: std.mem.Allocator) void {
        for (self.fields) |*field| field.deinit(allocator);
        allocator.free(self.fields);
        allocator.free(self.unions);
        allocator.free(self.groups);
        for (self.consts) |*c| c.deinit(allocator);
        allocator.free(self.consts);
        for (self.aliases) |*a| a.deinit(allocator);
        allocator.free(self.aliases);
        allocator.free(self.parameters);
        if (self.owns_name) allocator.free(self.name);
        self.* = undefined;
    }
};

pub const EnumValue = struct {
    index: usize = 0,
    name: []const u8,
    ordinal: u16,
    annotations: []const u8 = "",
};

pub const EnumValueMetadata = struct {
    index: usize = 0,
    name: []const u8,
    ordinal: u16,
    annotations: []const u8 = "",

    pub fn matchesIndex(self: EnumValueMetadata, value_index: usize) bool {
        return self.index == value_index;
    }

    pub fn matchesName(self: EnumValueMetadata, value_name: []const u8) bool {
        return std.mem.eql(u8, self.name, value_name);
    }

    pub fn matchesRaw(self: EnumValueMetadata, raw: u16) bool {
        return self.ordinal == raw;
    }

    pub fn hasAnnotations(self: EnumValueMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: EnumValueMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }
};

/// Runtime metadata describing a generated struct field.
pub const FieldMetadata = struct {
    index: usize = 0,
    name: []const u8,
    ordinal: u32,
    ty: []const u8,
    resolved_ty: []const u8 = "",
    slot: []const u8 = "",
    offset: usize = 0,
    default: []const u8 = "",
    has_explicit_default: bool = false,
    default_is_hex_data: bool = false,
    annotations: []const u8 = "",
    is_union_member: bool = false,
    union_index: ?u32 = null,
    union_discriminant: u16 = 0,

    pub fn matchesIndex(self: FieldMetadata, field_index: usize) bool {
        return self.index == field_index;
    }

    pub fn matchesName(self: FieldMetadata, field_name: []const u8) bool {
        return std.mem.eql(u8, self.name, field_name);
    }

    pub fn matchesOrdinal(self: FieldMetadata, field_ordinal: u32) bool {
        return self.ordinal == field_ordinal;
    }

    pub fn matchesType(self: FieldMetadata, field_type: []const u8) bool {
        return std.mem.eql(u8, self.ty, field_type);
    }

    pub fn matchesResolvedType(self: FieldMetadata, field_type: []const u8) bool {
        return std.mem.eql(u8, self.resolved_ty, field_type);
    }

    pub fn matchesSlot(self: FieldMetadata, slot: []const u8, offset: usize) bool {
        return std.mem.eql(u8, self.slot, slot) and self.offset == offset;
    }

    pub fn matchesDefault(self: FieldMetadata, default_value: []const u8) bool {
        return std.mem.eql(u8, self.default, default_value);
    }

    pub fn hasDefault(self: FieldMetadata) bool {
        return self.default.len != 0;
    }

    pub fn matchesExplicitDefault(self: FieldMetadata, has_default: bool) bool {
        return self.has_explicit_default == has_default;
    }

    pub fn matchesHexDefault(self: FieldMetadata, is_hex: bool) bool {
        return self.default_is_hex_data == is_hex;
    }

    pub fn hasAnnotations(self: FieldMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: FieldMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }

    pub fn matchesUnionMember(self: FieldMetadata, is_member: bool) bool {
        return self.is_union_member == is_member;
    }

    pub fn hasUnionIndex(self: FieldMetadata, index: u32) bool {
        return self.union_index != null and self.union_index.? == index;
    }

    pub fn hasUnionDiscriminant(self: FieldMetadata, discriminant: u16) bool {
        return self.is_union_member and self.union_discriminant == discriminant;
    }
};

pub const UnionMetadata = struct {
    index: u32,
    name: []const u8 = "",
    ordinal: ?u32 = null,
    annotations: []const u8 = "",
    discriminant_byte: usize,
    data_bit: usize = 0,
    data_bits: usize = 0,
    pointer: ?usize = null,
    field_count: usize = 0,
    fields: []const FieldMetadata = &.{},

    pub fn matchesIndex(self: UnionMetadata, union_index: u32) bool {
        return self.index == union_index;
    }

    pub fn matchesName(self: UnionMetadata, name: []const u8) bool {
        return std.mem.eql(u8, self.name, name);
    }

    pub fn hasName(self: UnionMetadata) bool {
        return self.name.len != 0;
    }

    pub fn hasOrdinal(self: UnionMetadata) bool {
        return self.ordinal != null;
    }

    pub fn matchesOrdinal(self: UnionMetadata, ordinal: u32) bool {
        return self.ordinal != null and self.ordinal.? == ordinal;
    }

    pub fn matchesDiscriminantByte(self: UnionMetadata, byte_offset: usize) bool {
        return self.discriminant_byte == byte_offset;
    }

    pub fn hasAnnotations(self: UnionMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: UnionMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }

    pub fn hasData(self: UnionMetadata) bool {
        return self.data_bits != 0;
    }

    pub fn matchesDataBit(self: UnionMetadata, bit: usize) bool {
        return self.data_bit == bit;
    }

    pub fn matchesDataBits(self: UnionMetadata, bits: usize) bool {
        return self.data_bits == bits;
    }

    pub fn hasPointerStorage(self: UnionMetadata) bool {
        return self.pointer != null;
    }

    pub fn matchesPointer(self: UnionMetadata, pointer_index: usize) bool {
        return self.pointer != null and self.pointer.? == pointer_index;
    }

    pub fn fieldByName(self: UnionMetadata, name: []const u8) ?FieldMetadata {
        for (self.fields) |field| if (std.mem.eql(u8, field.name, name)) return field;
        return null;
    }

    pub fn fieldByType(self: UnionMetadata, ty: []const u8) ?FieldMetadata {
        for (self.fields) |field| if (std.mem.eql(u8, field.ty, ty)) return field;
        return null;
    }

    pub fn fieldByResolvedType(self: UnionMetadata, ty: []const u8) ?FieldMetadata {
        for (self.fields) |field| if (std.mem.eql(u8, field.resolved_ty, ty)) return field;
        return null;
    }

    pub fn fieldBySlot(self: UnionMetadata, slot: []const u8, offset: usize) ?FieldMetadata {
        for (self.fields) |field| if (std.mem.eql(u8, field.slot, slot) and field.offset == offset) return field;
        return null;
    }

    pub fn fieldByDefault(self: UnionMetadata, default_value: []const u8) ?FieldMetadata {
        for (self.fields) |field| if (std.mem.eql(u8, field.default, default_value)) return field;
        return null;
    }

    pub fn fieldByExplicitDefault(self: UnionMetadata, has_default: bool) ?FieldMetadata {
        for (self.fields) |field| if (field.has_explicit_default == has_default) return field;
        return null;
    }

    pub fn fieldByHexDefault(self: UnionMetadata, is_hex: bool) ?FieldMetadata {
        for (self.fields) |field| if (field.default_is_hex_data == is_hex) return field;
        return null;
    }

    pub fn fieldByAnnotations(self: UnionMetadata, annotations: []const u8) ?FieldMetadata {
        for (self.fields) |field| if (std.mem.eql(u8, field.annotations, annotations)) return field;
        return null;
    }

    pub fn fieldByDiscriminant(self: UnionMetadata, discriminant: u16) ?FieldMetadata {
        for (self.fields) |field| if (field.union_discriminant == discriminant) return field;
        return null;
    }

    pub fn fieldByOrdinal(self: UnionMetadata, ordinal: u32) ?FieldMetadata {
        for (self.fields) |field| if (field.ordinal == ordinal) return field;
        return null;
    }

    pub fn fieldByIndex(self: UnionMetadata, field_index: usize) ?FieldMetadata {
        if (field_index >= self.fields.len) return null;
        return self.fields[field_index];
    }

    pub fn matchesFieldCount(self: UnionMetadata, count: usize) bool {
        return self.field_count == count;
    }

    pub fn hasFields(self: UnionMetadata) bool {
        return self.field_count != 0;
    }

    pub fn hasPointer(self: UnionMetadata, pointer_index: usize) bool {
        return self.matchesPointer(pointer_index);
    }

    pub fn containsDataBit(self: UnionMetadata, bit: usize) bool {
        return self.data_bits != 0 and bit >= self.data_bit and bit < self.data_bit + self.data_bits;
    }

    pub fn matchesDataRange(self: UnionMetadata, bit: usize, bits: usize) bool {
        return self.data_bit == bit and self.data_bits == bits;
    }
};

/// Declaration kinds exposed by generated metadata.
pub const DeclarationKind = enum {
    struct_decl,
    enum_decl,
    interface_decl,
    annotation_decl,
};

/// Runtime metadata describing a generated declaration.
pub const DeclarationMetadata = struct {
    index: usize = 0,
    name: []const u8,
    kind: DeclarationKind,
    id: ?u64 = null,
    annotations: []const u8 = "",
    parameter_count: usize = 0,
    parameters: []const []const u8 = &.{},

    pub fn matchesIndex(self: DeclarationMetadata, declaration_index: usize) bool {
        return self.index == declaration_index;
    }

    pub fn matchesName(self: DeclarationMetadata, declaration_name: []const u8) bool {
        return std.mem.eql(u8, self.name, declaration_name);
    }

    pub fn matchesKind(self: DeclarationMetadata, declaration_kind: DeclarationKind) bool {
        return self.kind == declaration_kind;
    }

    pub fn hasId(self: DeclarationMetadata) bool {
        return self.id != null;
    }

    pub fn matchesId(self: DeclarationMetadata, declaration_id: u64) bool {
        return self.id != null and self.id.? == declaration_id;
    }

    pub fn hasAnnotations(self: DeclarationMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: DeclarationMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }

    pub fn hasParameters(self: DeclarationMetadata) bool {
        return self.parameter_count != 0;
    }

    pub fn matchesParameterCount(self: DeclarationMetadata, count: usize) bool {
        return self.parameter_count == count;
    }

    pub fn matchesParameter(self: DeclarationMetadata, parameter: []const u8) bool {
        return self.parameterByName(parameter) != null;
    }

    pub fn parameterByName(self: DeclarationMetadata, parameter: []const u8) ?[]const u8 {
        for (self.parameters) |item| if (std.mem.eql(u8, item, parameter)) return item;
        return null;
    }

    pub fn parameterByIndex(self: DeclarationMetadata, parameter_index: usize) ?[]const u8 {
        if (parameter_index >= self.parameters.len) return null;
        return self.parameters[parameter_index];
    }
};

/// A parsed enum declaration and its enumerants.
pub const EnumDecl = struct {
    name: []const u8,
    owns_name: bool = false,
    id: ?u64 = null,
    annotations: []const u8 = "",
    values: []EnumValue,

    pub fn deinit(self: *EnumDecl, allocator: std.mem.Allocator) void {
        allocator.free(self.values);
        if (self.owns_name) allocator.free(self.name);
        self.* = undefined;
    }
};

pub const MethodField = struct {
    index: usize = 0,
    name: []const u8,
    ty: []const u8,
    resolved_ty: []const u8 = "",
    default_literal: ?[]const u8 = null,
    default_is_hex_data: bool = false,
    has_explicit_default: bool = false,
    annotations: []const u8 = "",

    pub fn matchesIndex(self: MethodField, field_index: usize) bool {
        return self.index == field_index;
    }

    pub fn matchesName(self: MethodField, field_name: []const u8) bool {
        return std.mem.eql(u8, self.name, field_name);
    }

    pub fn matchesType(self: MethodField, field_type: []const u8) bool {
        return std.mem.eql(u8, self.ty, field_type);
    }

    pub fn matchesResolvedType(self: MethodField, field_type: []const u8) bool {
        return std.mem.eql(u8, self.resolved_ty, field_type);
    }

    pub fn hasDefault(self: MethodField) bool {
        return self.default_literal != null;
    }

    pub fn matchesDefault(self: MethodField, default_value: []const u8) bool {
        return self.default_literal != null and std.mem.eql(u8, self.default_literal.?, default_value);
    }

    pub fn matchesExplicitDefault(self: MethodField, has_default: bool) bool {
        return self.has_explicit_default == has_default;
    }

    pub fn matchesHexDefault(self: MethodField, is_hex: bool) bool {
        return self.default_is_hex_data == is_hex;
    }

    pub fn hasAnnotations(self: MethodField) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: MethodField, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }
};

pub const InterfaceMethod = struct {
    name: []const u8,
    ordinal: u16,
    signature: []const u8 = "",
    params_signature: []const u8 = "",
    results_signature: []const u8 = "",
    annotation_signature: []const u8 = "",
    params_type: []const u8 = "",
    results_type: []const u8 = "",
    is_streaming: bool = false,
    parameters: []const []const u8 = &.{},
    param_fields: []const MethodField = &.{},
    result_fields: []const MethodField = &.{},
};

pub const InterfaceMethodMetadata = struct {
    index: usize = 0,
    name: []const u8,
    ordinal: u16,
    signature: []const u8 = "",
    params: []const u8 = "",
    results: []const u8 = "",
    params_type: []const u8 = "",
    results_type: []const u8 = "",
    resolved_params_type: []const u8 = "",
    resolved_results_type: []const u8 = "",
    annotations: []const u8 = "",
    streaming: bool = false,
    parameter_count: usize = 0,
    param_field_count: usize = 0,
    result_field_count: usize = 0,
    parameters: []const []const u8 = &.{},
    param_fields: []const MethodField = &.{},
    result_fields: []const MethodField = &.{},

    pub fn matchesIndex(self: InterfaceMethodMetadata, method_index: usize) bool {
        return self.index == method_index;
    }

    pub fn matchesName(self: InterfaceMethodMetadata, method_name: []const u8) bool {
        return std.mem.eql(u8, self.name, method_name);
    }

    pub fn matchesOrdinal(self: InterfaceMethodMetadata, method_ordinal: u16) bool {
        return self.ordinal == method_ordinal;
    }

    pub fn callMethod(self: InterfaceMethodMetadata, interface_id: u64) @import("../rpc.zig").CallMethod {
        return .{ .interface_id = interface_id, .method_id = self.ordinal };
    }

    pub fn matchesCallMethod(self: InterfaceMethodMetadata, interface_id: u64, method: @import("../rpc.zig").CallMethod) bool {
        return method.matches(interface_id, self.ordinal);
    }

    pub fn methodEntry(self: InterfaceMethodMetadata, interface_id: u64, handler: anytype) @import("../rpc.zig").CallMethodEntry(@TypeOf(handler)) {
        return self.callMethod(interface_id).methodEntry(handler);
    }

    pub fn callOptions(self: InterfaceMethodMetadata, interface_id: u64) @import("../rpc.zig").CallOptions {
        return self.callMethod(interface_id).callOptions();
    }

    pub fn matchesSignature(self: InterfaceMethodMetadata, method_signature: []const u8) bool {
        return std.mem.eql(u8, self.signature, method_signature);
    }

    pub fn matchesParamsType(self: InterfaceMethodMetadata, method_type: []const u8) bool {
        return std.mem.eql(u8, self.params_type, method_type);
    }

    pub fn matchesResultsType(self: InterfaceMethodMetadata, method_type: []const u8) bool {
        return std.mem.eql(u8, self.results_type, method_type);
    }

    pub fn matchesResolvedParamsType(self: InterfaceMethodMetadata, method_type: []const u8) bool {
        return std.mem.eql(u8, self.resolved_params_type, method_type);
    }

    pub fn matchesResolvedResultsType(self: InterfaceMethodMetadata, method_type: []const u8) bool {
        return std.mem.eql(u8, self.resolved_results_type, method_type);
    }

    pub fn hasAnnotations(self: InterfaceMethodMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: InterfaceMethodMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }

    pub fn matchesStreaming(self: InterfaceMethodMetadata, is_streaming: bool) bool {
        return self.streaming == is_streaming;
    }

    pub fn hasParameters(self: InterfaceMethodMetadata) bool {
        return self.parameter_count != 0;
    }

    pub fn matchesParameterCount(self: InterfaceMethodMetadata, count: usize) bool {
        return self.parameter_count == count;
    }

    pub fn hasParamFields(self: InterfaceMethodMetadata) bool {
        return self.param_field_count != 0;
    }

    pub fn matchesParamFieldCount(self: InterfaceMethodMetadata, count: usize) bool {
        return self.param_field_count == count;
    }

    pub fn hasResultFields(self: InterfaceMethodMetadata) bool {
        return self.result_field_count != 0;
    }

    pub fn matchesResultFieldCount(self: InterfaceMethodMetadata, count: usize) bool {
        return self.result_field_count == count;
    }

    pub fn matchesParameter(self: InterfaceMethodMetadata, parameter: []const u8) bool {
        return self.parameterByName(parameter) != null;
    }

    pub fn parameterByName(self: InterfaceMethodMetadata, parameter: []const u8) ?[]const u8 {
        for (self.parameters) |item| if (std.mem.eql(u8, item, parameter)) return item;
        return null;
    }

    pub fn parameterByIndex(self: InterfaceMethodMetadata, parameter_index: usize) ?[]const u8 {
        if (parameter_index >= self.parameters.len) return null;
        return self.parameters[parameter_index];
    }

    pub fn paramFieldByName(self: InterfaceMethodMetadata, field_name: []const u8) ?MethodField {
        return methodFieldByName(self.param_fields, field_name);
    }

    pub fn paramFieldByType(self: InterfaceMethodMetadata, ty: []const u8) ?MethodField {
        return methodFieldByType(self.param_fields, ty);
    }

    pub fn paramFieldByResolvedType(self: InterfaceMethodMetadata, ty: []const u8) ?MethodField {
        return methodFieldByResolvedType(self.param_fields, ty);
    }

    pub fn paramFieldByDefault(self: InterfaceMethodMetadata, default_value: []const u8) ?MethodField {
        return methodFieldByDefault(self.param_fields, default_value);
    }

    pub fn paramFieldByExplicitDefault(self: InterfaceMethodMetadata, has_default: bool) ?MethodField {
        return methodFieldByExplicitDefault(self.param_fields, has_default);
    }

    pub fn paramFieldByHexDefault(self: InterfaceMethodMetadata, is_hex: bool) ?MethodField {
        return methodFieldByHexDefault(self.param_fields, is_hex);
    }

    pub fn paramFieldByAnnotations(self: InterfaceMethodMetadata, annotations: []const u8) ?MethodField {
        return methodFieldByAnnotations(self.param_fields, annotations);
    }

    pub fn paramFieldByIndex(self: InterfaceMethodMetadata, field_index: usize) ?MethodField {
        return methodFieldByIndex(self.param_fields, field_index);
    }

    pub fn resultFieldByName(self: InterfaceMethodMetadata, field_name: []const u8) ?MethodField {
        return methodFieldByName(self.result_fields, field_name);
    }

    pub fn resultFieldByType(self: InterfaceMethodMetadata, ty: []const u8) ?MethodField {
        return methodFieldByType(self.result_fields, ty);
    }

    pub fn resultFieldByResolvedType(self: InterfaceMethodMetadata, ty: []const u8) ?MethodField {
        return methodFieldByResolvedType(self.result_fields, ty);
    }

    pub fn resultFieldByDefault(self: InterfaceMethodMetadata, default_value: []const u8) ?MethodField {
        return methodFieldByDefault(self.result_fields, default_value);
    }

    pub fn resultFieldByExplicitDefault(self: InterfaceMethodMetadata, has_default: bool) ?MethodField {
        return methodFieldByExplicitDefault(self.result_fields, has_default);
    }

    pub fn resultFieldByHexDefault(self: InterfaceMethodMetadata, is_hex: bool) ?MethodField {
        return methodFieldByHexDefault(self.result_fields, is_hex);
    }

    pub fn resultFieldByAnnotations(self: InterfaceMethodMetadata, annotations: []const u8) ?MethodField {
        return methodFieldByAnnotations(self.result_fields, annotations);
    }

    pub fn resultFieldByIndex(self: InterfaceMethodMetadata, field_index: usize) ?MethodField {
        return methodFieldByIndex(self.result_fields, field_index);
    }

    pub fn methodFieldByName(fields: []const MethodField, field_name: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.name, field_name)) return field;
        return null;
    }

    pub fn methodFieldByType(fields: []const MethodField, ty: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.ty, ty)) return field;
        return null;
    }

    pub fn methodFieldByResolvedType(fields: []const MethodField, ty: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.resolved_ty, ty)) return field;
        return null;
    }

    pub fn methodFieldByDefault(fields: []const MethodField, default_value: []const u8) ?MethodField {
        for (fields) |field| if (field.default_literal != null and std.mem.eql(u8, field.default_literal.?, default_value)) return field;
        return null;
    }

    pub fn methodFieldByExplicitDefault(fields: []const MethodField, has_default: bool) ?MethodField {
        for (fields) |field| if (field.has_explicit_default == has_default) return field;
        return null;
    }

    pub fn methodFieldByHexDefault(fields: []const MethodField, is_hex: bool) ?MethodField {
        for (fields) |field| if (field.default_is_hex_data == is_hex) return field;
        return null;
    }

    pub fn methodFieldByAnnotations(fields: []const MethodField, annotations: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.annotations, annotations)) return field;
        return null;
    }

    pub fn methodFieldByIndex(fields: []const MethodField, field_index: usize) ?MethodField {
        if (field_index >= fields.len) return null;
        return fields[field_index];
    }
};

pub const InterfaceSuperclassMetadata = struct {
    index: usize,
    name: []const u8,
    resolved_name: []const u8 = "",

    pub fn matchesIndex(self: InterfaceSuperclassMetadata, superclass_index: usize) bool {
        return self.index == superclass_index;
    }

    pub fn matchesName(self: InterfaceSuperclassMetadata, superclass_name: []const u8) bool {
        return std.mem.eql(u8, self.name, superclass_name);
    }

    pub fn matchesResolvedName(self: InterfaceSuperclassMetadata, superclass_name: []const u8) bool {
        return std.mem.eql(u8, self.resolved_name, superclass_name);
    }
};

/// A parsed interface declaration, methods, superclasses, and nested declarations.
pub const InterfaceDecl = struct {
    name: []const u8,
    owns_name: bool = false,
    id: ?u64 = null,
    annotations: []const u8 = "",
    parameters: []const []const u8 = &.{},
    methods: []InterfaceMethod = &.{},
    superclasses: []Type = &.{},
    consts: []ConstDecl = &.{},
    aliases: []AliasDecl = &.{},

    pub fn deinit(self: *InterfaceDecl, allocator: std.mem.Allocator) void {
        for (self.methods) |method| {
            allocator.free(method.parameters);
            allocator.free(method.param_fields);
            allocator.free(method.result_fields);
        }
        allocator.free(self.methods);
        for (self.superclasses) |*superclass| superclass.deinit(allocator);
        allocator.free(self.superclasses);
        for (self.consts) |*c| c.deinit(allocator);
        allocator.free(self.consts);
        for (self.aliases) |*a| a.deinit(allocator);
        allocator.free(self.aliases);
        allocator.free(self.parameters);
        if (self.owns_name) allocator.free(self.name);
        self.* = undefined;
    }
};

pub const AnnotationTargets = struct {
    file: bool = false,
    const_decl: bool = false,
    enum_decl: bool = false,
    enumerant: bool = false,
    struct_decl: bool = false,
    field: bool = false,
    union_decl: bool = false,
    group: bool = false,
    interface_decl: bool = false,
    method: bool = false,
    param: bool = false,
    annotation_decl: bool = false,

    pub fn hasTarget(self: AnnotationTargets, name: []const u8) bool {
        return annotationTargetsHas(self, name);
    }

    pub fn count(self: AnnotationTargets) usize {
        return annotationTargetCount(self);
    }
};

/// Return whether an annotation target set contains `name`.
pub fn annotationTargetsHas(targets: AnnotationTargets, name: []const u8) bool {
    if (std.mem.eql(u8, name, "file")) return targets.file;
    if (std.mem.eql(u8, name, "const")) return targets.const_decl;
    if (std.mem.eql(u8, name, "const_decl")) return targets.const_decl;
    if (std.mem.eql(u8, name, "enum")) return targets.enum_decl;
    if (std.mem.eql(u8, name, "enum_decl")) return targets.enum_decl;
    if (std.mem.eql(u8, name, "enumerant")) return targets.enumerant;
    if (std.mem.eql(u8, name, "struct")) return targets.struct_decl;
    if (std.mem.eql(u8, name, "struct_decl")) return targets.struct_decl;
    if (std.mem.eql(u8, name, "field")) return targets.field;
    if (std.mem.eql(u8, name, "union")) return targets.union_decl;
    if (std.mem.eql(u8, name, "union_decl")) return targets.union_decl;
    if (std.mem.eql(u8, name, "group")) return targets.group;
    if (std.mem.eql(u8, name, "interface")) return targets.interface_decl;
    if (std.mem.eql(u8, name, "interface_decl")) return targets.interface_decl;
    if (std.mem.eql(u8, name, "method")) return targets.method;
    if (std.mem.eql(u8, name, "param")) return targets.param;
    if (std.mem.eql(u8, name, "annotation")) return targets.annotation_decl;
    if (std.mem.eql(u8, name, "annotation_decl")) return targets.annotation_decl;
    return false;
}

pub fn allAnnotationTargets() AnnotationTargets {
    return .{
        .file = true,
        .const_decl = true,
        .enum_decl = true,
        .enumerant = true,
        .struct_decl = true,
        .field = true,
        .union_decl = true,
        .group = true,
        .interface_decl = true,
        .method = true,
        .param = true,
        .annotation_decl = true,
    };
}

/// A parsed annotation declaration and its allowed targets.
pub const AnnotationDecl = struct {
    name: []const u8,
    owns_name: bool = false,
    id: ?u64 = null,
    annotations: []const u8 = "",
    ty: Type,
    targets: AnnotationTargets,

    pub fn deinit(self: *AnnotationDecl, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        if (self.owns_name) allocator.free(self.name);
        self.* = undefined;
    }
};

pub const AnnotationMetadata = struct {
    index: usize = 0,
    name: []const u8,
    id: ?u64 = null,
    ty: []const u8,
    resolved_ty: []const u8 = "",
    annotations: []const u8 = "",
    target_count: usize = 0,
    targets: AnnotationTargets = .{},

    pub fn matchesIndex(self: AnnotationMetadata, annotation_index: usize) bool {
        return self.index == annotation_index;
    }

    pub fn hasId(self: AnnotationMetadata) bool {
        return self.id != null;
    }

    pub fn hasTarget(self: AnnotationMetadata, name: []const u8) bool {
        return self.targets.hasTarget(name);
    }

    pub fn computedTargetCount(self: AnnotationMetadata) usize {
        return self.targets.count();
    }

    pub fn matchesTargetCount(self: AnnotationMetadata, count: usize) bool {
        return self.target_count == count;
    }

    pub fn matchesName(self: AnnotationMetadata, annotation_name: []const u8) bool {
        return std.mem.eql(u8, self.name, annotation_name);
    }

    pub fn matchesId(self: AnnotationMetadata, annotation_id: u64) bool {
        return self.id != null and self.id.? == annotation_id;
    }

    pub fn matchesType(self: AnnotationMetadata, annotation_type: []const u8) bool {
        return std.mem.eql(u8, self.ty, annotation_type);
    }

    pub fn matchesResolvedType(self: AnnotationMetadata, annotation_type: []const u8) bool {
        return std.mem.eql(u8, self.resolved_ty, annotation_type);
    }

    pub fn hasAnnotations(self: AnnotationMetadata) bool {
        return self.annotations.len != 0;
    }

    pub fn matchesAnnotations(self: AnnotationMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
    }
};

pub const FileAnnotationMetadata = struct {
    index: usize,
    raw: []const u8,

    pub fn matchesIndex(self: FileAnnotationMetadata, annotation_index: usize) bool {
        return self.index == annotation_index;
    }

    pub fn hasRaw(self: FileAnnotationMetadata) bool {
        return self.raw.len != 0;
    }

    pub fn matchesRaw(self: FileAnnotationMetadata, annotation_raw: []const u8) bool {
        return std.mem.eql(u8, self.raw, annotation_raw);
    }
};

/// A parsed schema file: file ID, declarations, imports, aliases, and annotations.
pub const File = struct {
    id: ?u64,
    annotations_raw: []const []const u8 = &.{},
    structs: []Struct,
    enums: []EnumDecl,
    aliases: []AliasDecl,
    consts: []ConstDecl,
    imports: []ImportDecl,
    interfaces: []InterfaceDecl,
    annotations: []AnnotationDecl,

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        for (self.structs) |*s| s.deinit(allocator);
        allocator.free(self.structs);
        for (self.enums) |*e| e.deinit(allocator);
        allocator.free(self.enums);
        for (self.aliases) |*a| a.deinit(allocator);
        allocator.free(self.aliases);
        for (self.consts) |*c| c.deinit(allocator);
        allocator.free(self.consts);
        allocator.free(self.imports);
        allocator.free(self.annotations_raw);
        for (self.interfaces) |*i| i.deinit(allocator);
        allocator.free(self.interfaces);
        for (self.annotations) |*a| a.deinit(allocator);
        allocator.free(self.annotations);
        self.* = undefined;
    }
};

/// Errors produced by layout planning and code generation.
pub const LayoutError = Error || serialize.Error || wire.Error || error{
    UnsupportedInlineComposite,
};

/// The physical storage slot assigned to a field by the layout planner.
pub const FieldSlot = union(enum) {
    void,
    data_bit: usize,
    data_byte: usize,
    pointer: usize,
};

pub const FieldLayout = struct {
    field: *const Field,
    slot: FieldSlot,
};

pub const UnionLayout = struct {
    discriminant_byte: usize,
    name: []const u8 = "",
    ordinal: ?u32 = null,
    annotations: []const u8 = "",
    data_bit: usize = 0,
    data_bits: usize = 0,
    pointer: ?usize = null,
    pointer_count: usize = 0,
};

/// Planned data/pointer layout for one struct declaration.
pub const StructLayout = struct {
    decl: *const Struct,
    data_words: u16,
    pointer_count: u16,
    fields: []FieldLayout,
    unions: []UnionLayout,

    pub fn deinit(self: *StructLayout, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
        allocator.free(self.unions);
        self.* = undefined;
    }
};

/// Layout plans for every struct in a schema file.
pub const LayoutFile = struct {
    structs: []StructLayout,

    pub fn deinit(self: *LayoutFile, allocator: std.mem.Allocator) void {
        for (self.structs) |*layout| layout.deinit(allocator);
        allocator.free(self.structs);
        self.* = undefined;
    }
};

pub const TokenTag = enum {
    identifier,
    at,
    colon,
    semicolon,
    l_brace,
    r_brace,
    l_paren,
    r_paren,
    l_bracket,
    r_bracket,
    equal,
    dollar,
    dot,
    comma,
    question,
    bang,
    arrow,
    star,
    integer,
    string,
    eof,
};

pub const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    start: usize = 0,
    end: usize = 0,
};

pub fn skipLineCommentIndex(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n') index += 1;
    return index;
}

pub fn skipBlockCommentIndexOrNull(source: []const u8, start: usize) ?usize {
    var index = start + 2;
    while (index + 1 < source.len) : (index += 1) {
        if (source[index] == '*' and source[index + 1] == '/') return index + 2;
    }
    return null;
}

pub fn skipBlockCommentIndex(source: []const u8, start: usize) Error!usize {
    return skipBlockCommentIndexOrNull(source, start) orelse error.InvalidToken;
}

pub fn skipRawSlashIndex(source: []const u8, start: usize) Error!usize {
    if (start + 1 < source.len and source[start + 1] == '/') return skipLineCommentIndex(source, start + 2);
    if (start + 1 < source.len and source[start + 1] == '*') return try skipBlockCommentIndex(source, start);
    return start + 1;
}

pub fn skipRawStringIndex(source: []const u8, start: usize) Error!usize {
    if (start + 2 < source.len and source[start + 1] == '"' and source[start + 2] == '"') {
        var index = start + 3;
        while (index + 2 < source.len and !(source[index] == '"' and source[index + 1] == '"' and source[index + 2] == '"')) : (index += 1) {}
        if (index + 2 >= source.len) return error.UnexpectedToken;
        return index + 3;
    }

    var index = start + 1;
    while (index < source.len) {
        if (source[index] == '\\') {
            index += 2;
        } else if (source[index] == '"') {
            return index + 1;
        } else {
            index += 1;
        }
    }
    return error.UnexpectedToken;
}

pub fn skipRawStringOrCommentIndex(source: []const u8, start: usize) Error!?usize {
    return switch (source[start]) {
        '`' => skipLineCommentIndex(source, start),
        '"' => try skipRawStringIndex(source, start),
        '#' => skipLineCommentIndex(source, start),
        '/' => if (start + 1 < source.len and (source[start + 1] == '/' or source[start + 1] == '*'))
            try skipRawSlashIndex(source, start)
        else
            null,
        else => null,
    };
}

pub fn skipRawStringOrCommentInPostLoop(source: []const u8, index: *usize) Error!bool {
    if (try skipRawStringOrCommentIndex(source, index.*)) |next| {
        index.* = if (next == 0) 0 else next - 1;
        return true;
    }
    return false;
}

pub fn skipTriviaIndex(source: []const u8, start: usize) Error!usize {
    var index = start;
    while (index < source.len) {
        switch (source[index]) {
            ' ', '\t', '\r', '\n' => index += 1,
            '#' => index = skipLineCommentIndex(source, index),
            '/' => {
                if (index + 1 < source.len and source[index + 1] == '/') {
                    index = skipLineCommentIndex(source, index + 2);
                } else if (index + 1 < source.len and source[index + 1] == '*') {
                    index = try skipBlockCommentIndex(source, index);
                } else {
                    return index;
                }
            },
            else => return index,
        }
    }
    return index;
}

pub fn skipTriviaIndexOrNull(source: []const u8, start: usize) ?usize {
    var index = start;
    while (index < source.len) {
        switch (source[index]) {
            ' ', '\t', '\r', '\n' => index += 1,
            '#' => index = skipLineCommentIndex(source, index),
            '/' => {
                if (index + 1 < source.len and source[index + 1] == '/') {
                    index = skipLineCommentIndex(source, index + 2);
                } else if (index + 1 < source.len and source[index + 1] == '*') {
                    index = skipBlockCommentIndexOrNull(source, index) orelse return null;
                } else {
                    return index;
                }
            },
            else => return index,
        }
    }
    return index;
}

pub const Lexer = struct {
    source: []const u8,
    index: usize = 0,

    pub fn next(self: *Lexer) Error!Token {
        try self.skipSpaceAndComments();
        if (self.index >= self.source.len) return .{ .tag = .eof, .lexeme = "", .start = self.index, .end = self.index };
        const start = self.index;
        const c = self.source[self.index];
        self.index += 1;
        return switch (c) {
            '@' => .{ .tag = .at, .lexeme = self.source[start..self.index] },
            ':' => .{ .tag = .colon, .lexeme = self.source[start..self.index] },
            ';' => .{ .tag = .semicolon, .lexeme = self.source[start..self.index] },
            '{' => .{ .tag = .l_brace, .lexeme = self.source[start..self.index] },
            '}' => .{ .tag = .r_brace, .lexeme = self.source[start..self.index] },
            '(' => .{ .tag = .l_paren, .lexeme = self.source[start..self.index] },
            ')' => .{ .tag = .r_paren, .lexeme = self.source[start..self.index] },
            '[' => .{ .tag = .l_bracket, .lexeme = self.source[start..self.index] },
            ']' => .{ .tag = .r_bracket, .lexeme = self.source[start..self.index] },
            '=' => .{ .tag = .equal, .lexeme = self.source[start..self.index] },
            '$' => .{ .tag = .dollar, .lexeme = self.source[start..self.index] },
            '.' => .{ .tag = .dot, .lexeme = self.source[start..self.index] },
            ',' => .{ .tag = .comma, .lexeme = self.source[start..self.index] },
            '?' => .{ .tag = .question, .lexeme = self.source[start..self.index] },
            '!' => .{ .tag = .bang, .lexeme = self.source[start..self.index] },
            '*' => .{ .tag = .star, .lexeme = self.source[start..self.index] },
            '-' => blk: {
                if (self.index < self.source.len and self.source[self.index] == '>') {
                    self.index += 1;
                    break :blk .{ .tag = .arrow, .lexeme = self.source[start..self.index] };
                }
                if (self.index >= self.source.len) return error.InvalidToken;
                if (std.ascii.isDigit(self.source[self.index])) {
                    while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
                }
                if (isIdentStart(self.source[self.index])) {
                    self.index += 1;
                    while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index], .start = start, .end = self.index };
                }
                return error.InvalidToken;
            },
            '+' => blk: {
                if (self.index >= self.source.len) return error.InvalidToken;
                if (std.ascii.isDigit(self.source[self.index])) {
                    while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
                }
                if (isIdentStart(self.source[self.index])) {
                    self.index += 1;
                    while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index], .start = start, .end = self.index };
                }
                return error.InvalidToken;
            },
            '"' => blk: {
                const content_start = self.index;
                while (self.index < self.source.len) {
                    switch (self.source[self.index]) {
                        '"' => {
                            const content = self.source[content_start..self.index];
                            self.index += 1;
                            break :blk .{ .tag = .string, .lexeme = content, .start = start, .end = self.index };
                        },
                        '\\' => {
                            self.index += 1;
                            if (self.index >= self.source.len) return error.InvalidToken;
                            self.index += 1;
                        },
                        '\n', '\r' => return error.InvalidToken,
                        else => self.index += 1,
                    }
                }
                return error.InvalidToken;
            },
            '0'...'9' => blk: {
                while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
            },
            'A'...'Z', 'a'...'z', '_' => blk: {
                while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index], .start = start, .end = self.index };
            },
            else => error.InvalidToken,
        };
    }

    pub fn skipSpaceAndComments(self: *Lexer) Error!void {
        self.index = try skipTriviaIndex(self.source, self.index);
    }
};

/// Recursive-descent parser for the supported Cap'n Proto schema subset.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    lookahead: Token,
    parsed_structs: ?*std.ArrayList(Struct) = null,
    parsed_enums: ?*std.ArrayList(EnumDecl) = null,
    parsed_interfaces: ?*std.ArrayList(InterfaceDecl) = null,
    parsed_annotations: ?*std.ArrayList(AnnotationDecl) = null,
    parsed_imports: ?*std.ArrayList(ImportDecl) = null,
    parsed_decl_names: ?*std.StringHashMap(void) = null,
    parsed_decl_ids: ?*std.AutoHashMap(u64, void) = null,
    literal_scratch: std.ArrayList([]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Error!Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .lookahead = first };
    }

    pub fn deinitLiteralScratch(self: *Parser) void {
        for (self.literal_scratch.items) |literal| self.allocator.free(literal);
        self.literal_scratch.deinit(self.allocator);
    }

    pub fn takeOwnedLiteral(self: *Parser, literal: []const u8) bool {
        for (self.literal_scratch.items, 0..) |owned, index| {
            if (owned.ptr == literal.ptr and owned.len == literal.len) {
                _ = self.literal_scratch.swapRemove(index);
                return true;
            }
        }
        return false;
    }

    pub fn ownsScratchLiteral(self: *const Parser, literal: []const u8) bool {
        for (self.literal_scratch.items) |owned| {
            if (owned.ptr == literal.ptr and owned.len == literal.len) return true;
        }
        return false;
    }

    pub fn parse(self: *Parser) Error!File {
        var structs = std.ArrayList(Struct).empty;
        errdefer {
            for (structs.items) |*s| s.deinit(self.allocator);
            structs.deinit(self.allocator);
        }
        var enums = std.ArrayList(EnumDecl).empty;
        errdefer {
            for (enums.items) |*e| e.deinit(self.allocator);
            enums.deinit(self.allocator);
        }
        var aliases = std.ArrayList(AliasDecl).empty;
        errdefer {
            for (aliases.items) |*a| a.deinit(self.allocator);
            aliases.deinit(self.allocator);
        }
        var consts = std.ArrayList(ConstDecl).empty;
        errdefer {
            for (consts.items) |*c| c.deinit(self.allocator);
            consts.deinit(self.allocator);
        }
        var imports = std.ArrayList(ImportDecl).empty;
        errdefer imports.deinit(self.allocator);
        var interfaces = std.ArrayList(InterfaceDecl).empty;
        errdefer {
            for (interfaces.items) |*i| i.deinit(self.allocator);
            interfaces.deinit(self.allocator);
        }
        var annotations = std.ArrayList(AnnotationDecl).empty;
        errdefer {
            for (annotations.items) |*a| a.deinit(self.allocator);
            annotations.deinit(self.allocator);
        }
        var raw_file_annotations = std.ArrayList([]const u8).empty;
        errdefer raw_file_annotations.deinit(self.allocator);
        var decl_names = std.StringHashMap(void).init(self.allocator);
        defer decl_names.deinit();
        var decl_ids = std.AutoHashMap(u64, void).init(self.allocator);
        defer decl_ids.deinit();
        var file_id: ?u64 = null;
        var saw_top_level_declaration = false;
        self.parsed_structs = &structs;
        self.parsed_enums = &enums;
        self.parsed_interfaces = &interfaces;
        self.parsed_annotations = &annotations;
        self.parsed_imports = &imports;
        self.parsed_decl_names = &decl_names;
        self.parsed_decl_ids = &decl_ids;
        defer {
            self.parsed_structs = null;
            self.parsed_enums = null;
            self.parsed_interfaces = null;
            self.parsed_annotations = null;
            self.parsed_imports = null;
            self.parsed_decl_names = null;
            self.parsed_decl_ids = null;
        }

        while (self.lookahead.tag != .eof) {
            if (try self.eatKeyword("struct")) {
                saw_top_level_declaration = true;
                var decl = try self.parseStruct(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedStruct(decl);
                keep = true;
            } else if (try self.eatKeyword("enum")) {
                saw_top_level_declaration = true;
                var decl = try self.parseEnum(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedEnum(decl);
                keep = true;
            } else if (try self.eatKeyword("interface")) {
                saw_top_level_declaration = true;
                var decl = try self.parseInterfaceDeclaration(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedInterface(decl);
                keep = true;
            } else if (try self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, &imports, &decl_names);
            } else if (try self.eatKeyword("const")) {
                saw_top_level_declaration = true;
                try self.parseConstOrSkip(&consts, &decl_names);
            } else if (try self.eatKeyword("annotation")) {
                saw_top_level_declaration = true;
                var decl = try self.parseAnnotationDeclaration(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedAnnotation(decl);
                keep = true;
            } else if (self.lookahead.tag == .dollar) {
                saw_top_level_declaration = true;
                try raw_file_annotations.append(self.allocator, try self.takeAnnotationSuffixUntilSemicolon());
            } else if (self.lookahead.tag == .at) {
                if (saw_top_level_declaration) return error.UnexpectedToken;
                if (file_id != null) return error.OrdinalCollision;
                file_id = try self.parseFileId();
                try self.registerDeclarationId(file_id);
            } else {
                return error.UnexpectedToken;
            }
        }

        return .{
            .id = file_id,
            .annotations_raw = try raw_file_annotations.toOwnedSlice(self.allocator),
            .structs = try structs.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
            .consts = try consts.toOwnedSlice(self.allocator),
            .imports = try imports.toOwnedSlice(self.allocator),
            .interfaces = try interfaces.toOwnedSlice(self.allocator),
            .annotations = try annotations.toOwnedSlice(self.allocator),
        };
    }

    const QualifiedName = struct {
        name: []const u8,
        owns_name: bool = false,
    };

    pub fn parseInterfaceDeclaration(self: *Parser, name_prefix: ?[]const u8) Error!InterfaceDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const parameters = try self.parseDeclarationParameters(local_name);
        errdefer self.allocator.free(parameters);
        const superclasses = try self.parseInterfaceExtendsOrEmpty();
        errdefer {
            for (superclasses) |*superclass| superclass.deinit(self.allocator);
            self.allocator.free(superclasses);
        }
        const annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        var aliases = std.ArrayList(AliasDecl).empty;
        errdefer {
            for (aliases.items) |*a| a.deinit(self.allocator);
            aliases.deinit(self.allocator);
        }
        var consts = std.ArrayList(ConstDecl).empty;
        errdefer {
            for (consts.items) |*c| c.deinit(self.allocator);
            consts.deinit(self.allocator);
        }
        var member_names = std.StringHashMap(void).init(self.allocator);
        defer member_names.deinit();
        try reserveParameterNames(parameters, &member_names);

        const methods = try self.parseInterfaceBody(qualified.name, &aliases, &consts, &member_names);
        errdefer self.allocator.free(methods);
        return .{
            .name = qualified.name,
            .owns_name = qualified.owns_name,
            .id = decl_id,
            .annotations = annotations,
            .parameters = parameters,
            .methods = methods,
            .superclasses = superclasses,
            .consts = try consts.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
        };
    }

    pub fn parseAnnotationDeclaration(self: *Parser, name_prefix: ?[]const u8) Error!AnnotationDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const targets = try self.parseAnnotationTargets();
        try self.expect(.colon);
        var ty = try self.parseType();
        errdefer ty.deinit(self.allocator);
        const annotations = try self.takeAnnotationSuffixUntilSemicolon();
        return .{ .name = qualified.name, .owns_name = qualified.owns_name, .id = decl_id, .annotations = annotations, .ty = ty, .targets = targets };
    }

    pub fn parseAnnotationTargets(self: *Parser) Error!AnnotationTargets {
        try self.expect(.l_paren);
        var targets: AnnotationTargets = .{};
        var saw_target = false;
        var saw_wildcard = false;
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if (self.lookahead.tag == .star) {
                if (saw_wildcard) return error.UnexpectedToken;
                if (saw_target) return error.UnexpectedToken;
                try self.expect(.star);
                targets = allAnnotationTargets();
                saw_wildcard = true;
            } else {
                if (saw_wildcard) return error.UnexpectedToken;
                const target = try self.expectIdentifier();
                if (!setAnnotationTarget(&targets, target)) return error.UnexpectedToken;
                saw_target = true;
            }

            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        if (!saw_target and !saw_wildcard) return error.UnexpectedToken;
        try self.expect(.r_paren);
        return targets;
    }

    pub fn setAnnotationTarget(targets: *AnnotationTargets, target: []const u8) bool {
        if (std.mem.eql(u8, target, "file")) return setAnnotationTargetFlag(&targets.file);
        if (std.mem.eql(u8, target, "const")) return setAnnotationTargetFlag(&targets.const_decl);
        if (std.mem.eql(u8, target, "enum")) return setAnnotationTargetFlag(&targets.enum_decl);
        if (std.mem.eql(u8, target, "enumerant")) return setAnnotationTargetFlag(&targets.enumerant);
        if (std.mem.eql(u8, target, "struct")) return setAnnotationTargetFlag(&targets.struct_decl);
        if (std.mem.eql(u8, target, "field")) return setAnnotationTargetFlag(&targets.field);
        if (std.mem.eql(u8, target, "union")) return setAnnotationTargetFlag(&targets.union_decl);
        if (std.mem.eql(u8, target, "group")) return setAnnotationTargetFlag(&targets.group);
        if (std.mem.eql(u8, target, "interface")) return setAnnotationTargetFlag(&targets.interface_decl);
        if (std.mem.eql(u8, target, "method")) return setAnnotationTargetFlag(&targets.method);
        if (std.mem.eql(u8, target, "param")) return setAnnotationTargetFlag(&targets.param);
        if (std.mem.eql(u8, target, "annotation")) return setAnnotationTargetFlag(&targets.annotation_decl);
        return false;
    }

    pub fn setAnnotationTargetFlag(flag: *bool) bool {
        if (flag.*) return false;
        flag.* = true;
        return true;
    }

    pub fn parseInterfaceExtendsOrEmpty(self: *Parser) Error![]Type {
        if (!self.isKeyword("extends")) return try self.allocator.alloc(Type, 0);
        try self.advance();
        try self.expect(.l_paren);
        var superclasses = std.ArrayList(Type).empty;
        errdefer {
            for (superclasses.items) |*superclass| superclass.deinit(self.allocator);
            superclasses.deinit(self.allocator);
        }
        if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            var superclass = try self.parseType();
            var keep_superclass = false;
            errdefer if (!keep_superclass) superclass.deinit(self.allocator);
            for (superclasses.items) |existing| {
                if (typesEqual(existing, superclass)) return error.NameCollision;
            }
            try superclasses.append(self.allocator, superclass);
            keep_superclass = true;
            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return superclasses.toOwnedSlice(self.allocator);
    }

    pub fn parseDeclarationParameters(self: *Parser, declaration_name: []const u8) Error![]const []const u8 {
        if (self.lookahead.tag != .l_paren) return try self.allocator.alloc([]const u8, 0);
        try self.expect(.l_paren);
        var parameters = std.ArrayList([]const u8).empty;
        errdefer parameters.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();
        if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const name = try self.expectIdentifier();
            if (std.mem.eql(u8, name, declaration_name)) return error.NameCollision;
            if (isBuiltinSchemaTypeName(name)) return error.NameCollision;
            const entry = try names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            for (parameters.items) |existing| {
                if (try zigNamesEqual(self.allocator, existing, name)) return error.NameCollision;
            }
            try parameters.append(self.allocator, name);
            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return parameters.toOwnedSlice(self.allocator);
    }

    pub fn reserveParameterNames(parameters: []const []const u8, names: *std.StringHashMap(void)) Error!void {
        for (parameters) |parameter| {
            const entry = try names.getOrPut(parameter);
            if (entry.found_existing) return error.NameCollision;
        }
    }

    pub fn parseInterfaceBody(self: *Parser, interface_name: []const u8, aliases: *std.ArrayList(AliasDecl), consts: *std.ArrayList(ConstDecl), member_names: *std.StringHashMap(void)) Error![]InterfaceMethod {
        try self.skipUntil(.l_brace);
        try self.expect(.l_brace);

        var methods = std.ArrayList(InterfaceMethod).empty;
        errdefer {
            for (methods.items) |method| {
                self.allocator.free(method.parameters);
                self.allocator.free(method.param_fields);
                self.allocator.free(method.result_fields);
            }
            methods.deinit(self.allocator);
        }
        var method_names = std.StringHashMap(void).init(self.allocator);
        defer method_names.deinit();
        var occupied_ordinals = std.AutoHashMap(u16, void).init(self.allocator);
        defer occupied_ordinals.deinit();

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if (self.isKeyword("struct") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseStruct(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedStruct(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("enum") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseEnum(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedEnum(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("interface") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseInterfaceDeclaration(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedInterface(decl);
                keep = true;
                continue;
            }
            if (try self.eatKeyword("annotation")) {
                var decl = try self.parseAnnotationDeclaration(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedAnnotation(decl);
                keep = true;
                continue;
            }
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.eatKeyword("using")) {
                try self.parseUsingOrSkip(aliases, self.parsed_imports, member_names);
                continue;
            }
            if (try self.eatKeyword("const")) {
                try self.parseConstOrSkip(consts, member_names);
                continue;
            }
            if (self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            if (self.lookahead.tag != .identifier) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            if ((try self.peekNext()).tag != .at) return error.UnexpectedToken;
            const name = try self.expectIdentifier();
            try self.expect(.at);
            const ordinal_u64 = try self.expectInteger();
            if (ordinal_u64 > std.math.maxInt(u16)) return error.InvalidOrdinal;
            const ordinal: u16 = @intCast(ordinal_u64);
            const member_entry = try member_names.getOrPut(name);
            if (member_entry.found_existing) return error.NameCollision;
            const name_entry = try method_names.getOrPut(name);
            if (name_entry.found_existing) return error.NameCollision;
            const ordinal_entry = try occupied_ordinals.getOrPut(ordinal);
            if (ordinal_entry.found_existing) return error.OrdinalCollision;
            const signature = try self.takeRawUntilSemicolon();
            const parts = try splitMethodSignature(signature);
            try validateAnnotationSuffix(parts.annotations);
            try self.validateMethodEndpointType(parts.params, false);
            try self.validateMethodEndpointType(parts.results, true);
            const parameters = try self.parseMethodSignatureParameters(name, member_names, signature);
            var keep_parameters = false;
            errdefer if (!keep_parameters) self.allocator.free(parameters);
            const param_fields = try self.parseMethodFields(parts.params);
            var keep_param_fields = false;
            errdefer if (!keep_param_fields) self.allocator.free(param_fields);
            try validateMethodParameterFieldNames(self.allocator, parameters, param_fields);
            const result_fields = try self.parseMethodFields(parts.results);
            var keep_result_fields = false;
            errdefer if (!keep_result_fields) self.allocator.free(result_fields);
            try validateMethodParameterFieldNames(self.allocator, parameters, result_fields);
            try methods.append(self.allocator, .{
                .name = name,
                .ordinal = ordinal,
                .signature = signature,
                .params_signature = parts.params,
                .results_signature = parts.results,
                .annotation_signature = parts.annotations,
                .params_type = methodSignatureTypeName(parts.params),
                .results_type = methodSignatureTypeName(parts.results),
                .is_streaming = std.mem.eql(u8, parts.results, "stream"),
                .parameters = parameters,
                .param_fields = param_fields,
                .result_fields = result_fields,
            });
            keep_parameters = true;
            keep_param_fields = true;
            keep_result_fields = true;
        }
        try self.expect(.r_brace);
        return methods.toOwnedSlice(self.allocator);
    }

    pub fn parseMethodSignatureParameters(self: *Parser, method_name: []const u8, member_names: *const std.StringHashMap(void), signature: []const u8) Error![]const []const u8 {
        var index = try skipTriviaIndex(signature, 0);
        if (index >= signature.len or signature[index] != '[') return try self.allocator.alloc([]const u8, 0);
        var parameters = std.ArrayList([]const u8).empty;
        errdefer parameters.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();

        index += 1;
        while (true) {
            index = try skipTriviaIndex(signature, index);
            if (index >= signature.len) return error.UnexpectedToken;
            if (signature[index] == ']' and parameters.items.len == 0) return error.UnexpectedToken;
            if (signature[index] == ']') return parameters.toOwnedSlice(self.allocator);
            if (!isIdentStart(signature[index])) return error.UnexpectedToken;
            const start = index;
            index += 1;
            while (index < signature.len and isIdentContinue(signature[index])) index += 1;
            const name = signature[start..index];
            if (std.mem.eql(u8, name, method_name)) return error.NameCollision;
            if (isBuiltinSchemaTypeName(name)) return error.NameCollision;
            if (member_names.contains(name)) return error.NameCollision;
            const entry = try names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            for (parameters.items) |existing| {
                if (try zigNamesEqual(self.allocator, existing, name)) return error.NameCollision;
            }
            try parameters.append(self.allocator, name);
            index = try skipTriviaIndex(signature, index);
            if (index >= signature.len) return error.UnexpectedToken;
            if (signature[index] == ',') {
                index += 1;
                index = try skipTriviaIndex(signature, index);
                if (index < signature.len and signature[index] == ']') return error.UnexpectedToken;
                continue;
            }
            if (signature[index] == ']') {
                return parameters.toOwnedSlice(self.allocator);
            }
            return error.UnexpectedToken;
        }
    }

    pub fn parseMethodFields(self: *Parser, raw: []const u8) Error![]const MethodField {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "stream")) return try self.allocator.alloc(MethodField, 0);
        if (trimmed[0] != '(') return try self.allocator.alloc(MethodField, 0);
        var end = trimmed.len;
        var scan: usize = 1;
        var list_depth: usize = 1;
        while (scan < trimmed.len) : (scan += 1) {
            if (try skipRawStringOrCommentInPostLoop(trimmed, &scan)) continue;
            switch (trimmed[scan]) {
                '(' => list_depth += 1,
                ')' => {
                    list_depth -= 1;
                    if (list_depth == 0) {
                        end = scan;
                        break;
                    }
                },
                else => {},
            }
        }
        if (list_depth != 0) return error.UnexpectedToken;
        // `splitMethodSignature()` hands us the whole endpoint slice before the
        // arrow.  Once the outer field-list parens close, only trivia may
        // remain; otherwise syntax like `(value :UInt32) junk -> ()` would be
        // accepted after silently ignoring `junk`.
        if (try skipTriviaIndex(trimmed, end + 1) != trimmed.len) return error.UnexpectedToken;
        var index: usize = 1;
        var fields = std.ArrayList(MethodField).empty;
        errdefer fields.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();

        while (index < end) {
            index = try skipTriviaIndex(trimmed, index);
            if (index >= end) break;
            if (trimmed[index] == ',') return error.UnexpectedToken;
            if (!isIdentStart(trimmed[index])) return error.UnexpectedToken;
            const name_start = index;
            index += 1;
            while (index < end and isIdentContinue(trimmed[index])) index += 1;
            const field_name = trimmed[name_start..index];
            const entry = try names.getOrPut(field_name);
            if (entry.found_existing) return error.NameCollision;
            index = try skipTriviaIndex(trimmed, index);
            if (index >= end or trimmed[index] != ':') return error.UnexpectedToken;
            index += 1;
            index = try skipTriviaIndex(trimmed, index);
            const type_start = index;
            var paren_depth: usize = 0;
            while (index < end) : (index += 1) {
                if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                switch (trimmed[index]) {
                    '(' => paren_depth += 1,
                    ')' => {
                        if (paren_depth != 0) {
                            paren_depth -= 1;
                        } else {
                            break;
                        }
                    },
                    ',' => if (paren_depth == 0) break,
                    '=' => if (paren_depth == 0) break,
                    '$' => if (paren_depth == 0) break,
                    else => {},
                }
            }
            const field_type_end = index;
            var default_literal: ?[]const u8 = null;
            var default_is_hex_data = false;
            var has_explicit_default = false;
            var annotations: []const u8 = "";
            if (index < end and trimmed[index] != ',' and trimmed[index] != '=') {
                const annotation_start = index;
                var annotation_paren_depth: usize = 0;
                var annotation_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
                    if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                    switch (trimmed[index]) {
                        '(' => annotation_paren_depth += 1,
                        ')' => {
                            if (annotation_paren_depth != 0) annotation_paren_depth -= 1;
                        },
                        '[' => annotation_bracket_depth += 1,
                        ']' => {
                            if (annotation_bracket_depth != 0) annotation_bracket_depth -= 1;
                        },
                        ',' => if (annotation_paren_depth == 0 and annotation_bracket_depth == 0) break,
                        '=' => if (annotation_paren_depth == 0 and annotation_bracket_depth == 0) break,
                        else => {},
                    }
                }
                annotations = std.mem.trim(u8, trimmed[annotation_start..index], " \t\r\n");
            }
            // Method field syntax mirrors regular fields: defaults belong before
            // annotations.  Reject `$ann = value` instead of silently treating
            // it as an annotation followed by a default.
            if (annotations.len != 0 and index < end and trimmed[index] == '=') return error.UnexpectedToken;
            const field_type = std.mem.trim(u8, trimmed[type_start..field_type_end], " \t\r\n");
            if (field_type.len == 0) return error.UnexpectedToken;
            var parsed_field_type = try self.parseRawTypeSyntax(field_type);
            defer parsed_field_type.deinit(self.allocator);
            if (index < end and trimmed[index] == '=') {
                has_explicit_default = true;
                index += 1;
                index = try skipTriviaIndex(trimmed, index);
                const default_start = index;
                var default_paren_depth: usize = 0;
                var default_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
                    if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                    switch (trimmed[index]) {
                        '(' => default_paren_depth += 1,
                        ')' => {
                            if (default_paren_depth != 0) {
                                default_paren_depth -= 1;
                            } else if (default_bracket_depth == 0) {
                                break;
                            }
                        },
                        '[' => default_bracket_depth += 1,
                        ']' => {
                            if (default_bracket_depth != 0) default_bracket_depth -= 1;
                        },
                        ',' => if (default_paren_depth == 0 and default_bracket_depth == 0) break,
                        '$' => if (default_paren_depth == 0 and default_bracket_depth == 0) break,
                        else => {},
                    }
                }
                default_literal = std.mem.trim(u8, trimmed[default_start..index], " \t\r\n");
                if (default_literal.?.len == 0) return error.UnexpectedToken;
                try self.validateDefaultLiteralForTypeSyntax(parsed_field_type, default_literal.?);
                if (parsed_field_type == .data) {
                    if (default_literal) |literal| {
                        default_is_hex_data = std.mem.startsWith(u8, literal, "0x\"");
                    }
                }
            }
            if (index < end and trimmed[index] != ',' and annotations.len == 0) {
                const annotation_start = index;
                var annotation_paren_depth: usize = 0;
                var annotation_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
                    if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                    switch (trimmed[index]) {
                        '(' => annotation_paren_depth += 1,
                        ')' => {
                            if (annotation_paren_depth != 0) annotation_paren_depth -= 1;
                        },
                        '[' => annotation_bracket_depth += 1,
                        ']' => {
                            if (annotation_bracket_depth != 0) annotation_bracket_depth -= 1;
                        },
                        ',' => if (annotation_paren_depth == 0 and annotation_bracket_depth == 0) break,
                        else => {},
                    }
                }
                annotations = std.mem.trim(u8, trimmed[annotation_start..index], " \t\r\n");
            }
            try validateAnnotationSuffix(annotations);
            try fields.append(self.allocator, .{ .index = fields.items.len, .name = field_name, .ty = field_type, .default_literal = default_literal, .default_is_hex_data = default_is_hex_data, .has_explicit_default = has_explicit_default, .annotations = annotations });
            index = try skipTriviaIndex(trimmed, index);
            if (index < end) {
                if (trimmed[index] != ',') return error.UnexpectedToken;
                index += 1;
                index = try skipTriviaIndex(trimmed, index);
                if (index >= end or trimmed[index] == ',') return error.UnexpectedToken;
            }
        }
        return fields.toOwnedSlice(self.allocator);
    }

    pub fn parseRawTypeSyntax(self: *Parser, raw: []const u8) Error!Type {
        var parser = try Parser.init(self.allocator, raw);
        defer parser.deinitLiteralScratch();
        parser.parsed_imports = self.parsed_imports;
        parser.parsed_decl_names = self.parsed_decl_names;
        var ty = try parser.parseType();
        errdefer ty.deinit(self.allocator);
        if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
        return ty;
    }

    pub fn validateRawTypeSyntax(self: *Parser, raw: []const u8) Error!void {
        var ty = try self.parseRawTypeSyntax(raw);
        defer ty.deinit(self.allocator);
    }

    pub fn validateDefaultLiteralSyntax(self: *Parser, expression: []const u8) Error!void {
        const raw = std.mem.trim(u8, expression, " \t\r\n");
        if (raw.len == 0) return error.UnexpectedToken;
        if (raw[0] == '(' or raw[0] == '[') return self.validateInlineAggregateDefaultSyntax(raw);
        if (std.mem.startsWith(u8, raw, "0x\"")) {
            const next = try skipRawStringIndex(raw, 2);
            if (next != raw.len) return error.UnexpectedToken;
            return;
        }

        var parser = try Parser.init(self.allocator, raw);
        defer parser.deinitLiteralScratch();
        _ = (try parser.expectDefaultLiteral()) orelse return error.UnexpectedToken;
        if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
    }

    pub fn validateDefaultLiteralForTypeSyntax(self: *Parser, ty: Type, expression: []const u8) Error!void {
        try self.validateDefaultLiteralSyntax(expression);
        const raw = std.mem.trim(u8, expression, " \t\r\n");
        if (raw.len == 0) return error.UnexpectedToken;

        switch (ty) {
            .optional => |child| {
                if (std.mem.eql(u8, raw, "null")) return;
                return self.validateDefaultLiteralForTypeSyntax(child.*, raw);
            },
            .void => {
                if (std.mem.eql(u8, raw, "void")) return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .bool => {
                if (std.mem.eql(u8, raw, "true") or std.mem.eql(u8, raw, "false")) return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .int8 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i8, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .int16 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i16, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .int32 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i32, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .int64 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i64, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint8 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u8, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint16 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u16, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint32 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u32, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint64 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u64, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .float32 => if (parseFloatLiteral(f32, raw) == null and !defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .float64 => if (parseFloatLiteral(f64, raw) == null and !defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .text => {
                if (raw[0] == '"') return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .data => {
                if (std.mem.startsWith(u8, raw, "0x\"")) {
                    const decoded = hexBytesAlloc(self.allocator, raw[3 .. raw.len - 1]) catch |err| switch (err) {
                        error.OutOfMemory => return error.OutOfMemory,
                        error.InvalidToken => return error.UnexpectedToken,
                        else => return error.UnexpectedToken,
                    };
                    self.allocator.free(decoded);
                    return;
                }
                if (raw[0] == '"') return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .list => |child| {
                if (raw[0] == '[') {
                    try self.validateInlineListDefaultForTypeSyntax(child.*, raw);
                    return;
                }
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .named => |type_name| {
                if (raw[0] == '(') {
                    try self.validateStructDefaultForTypeSyntax(type_name, raw);
                    return;
                }
            },
            .any_pointer, .any_struct, .any_list, .capability => {},
        }
    }

    pub fn validateInlineListDefaultForTypeSyntax(self: *Parser, child_ty: Type, expression: []const u8) Error!void {
        const items = parseInlineConstListElementsAlloc(self.allocator, expression) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnexpectedToken => return error.UnexpectedToken,
            error.InvalidToken => return error.InvalidToken,
            else => return error.UnexpectedToken,
        };
        defer self.allocator.free(items);
        for (items) |item| {
            const split = splitDefaultExpressionAndAnnotations(item);
            try Parser.validateAnnotationSuffix(split.annotations);
            try self.validateDefaultLiteralForTypeSyntax(child_ty, split.default_expression);
        }
    }

    pub fn validateStructDefaultForTypeSyntax(self: *Parser, type_name: []const u8, expression: []const u8) Error!void {
        const struct_fields = try parseConstStructFieldsAlloc(self.allocator, expression);
        defer self.allocator.free(struct_fields);
        const struct_decl = self.parsedStructDirect(type_name) orelse {
            for (struct_fields) |field| try self.validateDefaultLiteralSyntax(field.literal);
            return;
        };

        for (struct_fields) |const_field| {
            if (structFieldByName(struct_decl, const_field.name)) |schema_field| {
                try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
                continue;
            }
            if (structHasFlattenedGroupName(struct_decl, const_field.name) and std.mem.trim(u8, const_field.literal, " \t\r\n")[0] == '(') {
                try self.validateFlattenedGroupDefaultForTypeSyntax(struct_decl, const_field.name, const_field.literal);
                continue;
            }
            const schema_field = structFieldByNameOrGroupFirst(struct_decl, const_field.name) orelse return error.UnexpectedToken;
            try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
        }
    }

    pub fn validateFlattenedGroupDefaultForTypeSyntax(self: *Parser, struct_decl: *const Struct, group_name: []const u8, expression: []const u8) Error!void {
        const struct_fields = try parseConstStructFieldsAlloc(self.allocator, expression);
        defer self.allocator.free(struct_fields);
        for (struct_fields) |const_field| {
            const flattened_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_name, const_field.name });
            defer self.allocator.free(flattened_name);
            if (structFieldByName(struct_decl, flattened_name)) |schema_field| {
                try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
                continue;
            }
            if (structHasFlattenedGroupName(struct_decl, flattened_name) and std.mem.trim(u8, const_field.literal, " \t\r\n")[0] == '(') {
                try self.validateFlattenedGroupDefaultForTypeSyntax(struct_decl, flattened_name, const_field.literal);
                continue;
            }
            const schema_field = structFieldByNameOrGroupFirst(struct_decl, flattened_name) orelse return error.UnexpectedToken;
            try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
        }
    }

    pub fn parsedStructDirect(self: *const Parser, type_name: []const u8) ?*const Struct {
        const structs = self.parsed_structs orelse return null;
        for (structs.items) |*decl| {
            if (typeNameEqualsCanonical(type_name, decl.name)) return decl;
        }
        return null;
    }

    pub fn structFieldByName(decl: *const Struct, name: []const u8) ?*const Field {
        for (decl.fields) |*field| {
            if (std.mem.eql(u8, field.name, name)) return field;
        }
        return null;
    }

    pub fn structHasFlattenedGroupName(decl: *const Struct, name: []const u8) bool {
        for (decl.fields) |field| {
            if (field.name.len > name.len + 1 and
                std.mem.startsWith(u8, field.name, name) and
                field.name[name.len] == '_')
            {
                return true;
            }
        }
        return false;
    }

    pub fn structFieldByNameOrGroupFirst(decl: *const Struct, name: []const u8) ?*const Field {
        if (structFieldByName(decl, name)) |field| return field;
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

    pub fn validateInlineAggregateDefaultSyntax(self: *Parser, expression: []const u8) Error!void {
        const raw = std.mem.trim(u8, expression, " \t\r\n");
        if (raw.len == 0) return error.UnexpectedToken;
        switch (raw[0]) {
            '(' => {
                const fields = try parseConstStructFieldsAlloc(self.allocator, raw);
                defer self.allocator.free(fields);
                for (fields) |field| try self.validateInlineAggregateDefaultSyntax(field.literal);
            },
            '[' => {
                const items = parseInlineConstListElementsAlloc(self.allocator, raw) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.UnexpectedToken => return error.UnexpectedToken,
                    error.InvalidToken => return error.InvalidToken,
                    else => return error.UnexpectedToken,
                };
                defer self.allocator.free(items);
                for (items) |item| try self.validateInlineAggregateDefaultSyntax(item);
            },
            else => {},
        }
    }

    pub fn validateMethodParameterFieldNames(allocator: std.mem.Allocator, parameters: []const []const u8, fields: []const MethodField) Error!void {
        for (fields, 0..) |field, index| {
            for (fields[index + 1 ..]) |other| {
                if (try zigNamesEqual(allocator, field.name, other.name)) return error.NameCollision;
            }
            for (parameters) |parameter| {
                if (std.mem.eql(u8, parameter, field.name)) return error.NameCollision;
                if (try zigNamesEqual(allocator, parameter, field.name)) return error.NameCollision;
            }
        }
    }

    pub fn methodSignatureTypeName(raw: []const u8) []const u8 {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '(' or std.mem.eql(u8, trimmed, "stream")) return "";
        return trimmed;
    }

    pub fn validateMethodEndpointType(self: *Parser, raw: []const u8, allow_stream: bool) Error!void {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '(') return;
        if (std.mem.eql(u8, trimmed, "stream")) {
            if (allow_stream) return;
            return error.UnexpectedToken;
        }
        var parser = try Parser.init(self.allocator, trimmed);
        defer parser.deinitLiteralScratch();
        var ty = try parser.parseType();
        defer ty.deinit(self.allocator);
        if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
    }

    const MethodSignatureParts = struct {
        params: []const u8,
        results: []const u8,
        annotations: []const u8,
    };

    pub fn splitMethodSignature(signature: []const u8) Error!MethodSignatureParts {
        var index = try skipTriviaIndex(signature, 0);
        if (index < signature.len and signature[index] == '[') {
            var bracket_depth: usize = 1;
            index += 1;
            while (index < signature.len and bracket_depth != 0) : (index += 1) {
                if (try skipRawStringOrCommentInPostLoop(signature, &index)) continue;
                switch (signature[index]) {
                    '[' => bracket_depth += 1,
                    ']' => bracket_depth -= 1,
                    else => {},
                }
            }
            index = try skipTriviaIndex(signature, index);
        }
        const params_start = index;
        var paren_depth: usize = 0;
        while (index < signature.len) : (index += 1) {
            if (try skipRawStringOrCommentInPostLoop(signature, &index)) continue;
            switch (signature[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '-' => if (paren_depth == 0 and index + 1 < signature.len and signature[index + 1] == '>') {
                    const params = std.mem.trim(u8, signature[params_start..index], " \t\r\n");
                    if (params.len == 0) return error.UnexpectedToken;
                    const result_parts = try splitResultAndAnnotations(signature[index + 2 ..]);
                    if (result_parts.results.len == 0) return error.UnexpectedToken;
                    return .{ .params = params, .results = result_parts.results, .annotations = result_parts.annotations };
                },
                else => {},
            }
        }
        return splitNoResultMethodSignature(signature, params_start);
    }

    pub fn splitNoResultMethodSignature(signature: []const u8, params_start: usize) Error!MethodSignatureParts {
        // Cap'n Proto allows methods whose return type is implicit Void to omit
        // the `-> ()` suffix entirely (`done @0 ();`).  Treat this as an empty
        // result struct while still requiring the parameter endpoint to be a
        // normal parenthesized field list, so malformed `method @0 Type;`
        // remains rejected rather than becoming a new endpoint shorthand.
        var index = try skipTriviaIndex(signature, params_start);
        if (index >= signature.len or signature[index] != '(') return error.UnexpectedToken;
        var paren_depth: usize = 1;
        index += 1;
        while (index < signature.len and paren_depth != 0) : (index += 1) {
            if (try skipRawStringOrCommentInPostLoop(signature, &index)) continue;
            switch (signature[index]) {
                '(' => paren_depth += 1,
                ')' => paren_depth -= 1,
                else => {},
            }
        }
        if (paren_depth != 0) return error.UnexpectedToken;
        const params = std.mem.trim(u8, signature[params_start..index], " \t\r\n");
        if (params.len == 0) return error.UnexpectedToken;
        const annotations_start = try skipTriviaIndex(signature, index);
        return .{
            .params = params,
            .results = "()",
            .annotations = if (annotations_start >= signature.len) "" else std.mem.trim(u8, signature[annotations_start..], " \t\r\n"),
        };
    }

    pub fn splitResultAndAnnotations(raw: []const u8) Error!struct { results: []const u8, annotations: []const u8 } {
        const start = try skipTriviaIndex(raw, 0);
        if (start >= raw.len) return .{ .results = "", .annotations = "" };
        var index: usize = start;
        if (raw[index] == '(') {
            var paren_depth: usize = 1;
            index += 1;
            while (index < raw.len and paren_depth != 0) : (index += 1) {
                if (try skipRawStringOrCommentInPostLoop(raw, &index)) continue;
                switch (raw[index]) {
                    '(' => paren_depth += 1,
                    ')' => paren_depth -= 1,
                    else => {},
                }
            }
            const result_end = index;
            const annotations_start = try skipTriviaIndex(raw, result_end);
            return .{
                .results = std.mem.trim(u8, raw[start..result_end], " \t\r\n"),
                .annotations = std.mem.trim(u8, raw[annotations_start..], " \t\r\n"),
            };
        }
        var paren_depth: usize = 0;
        while (index < raw.len) {
            if (paren_depth == 0) {
                const next = try skipTriviaIndex(raw, index);
                if (next != index) {
                    if (next >= raw.len or raw[next] == '$') {
                        return .{
                            .results = std.mem.trim(u8, raw[start..index], " \t\r\n"),
                            .annotations = if (next >= raw.len) "" else std.mem.trim(u8, raw[next..], " \t\r\n"),
                        };
                    }
                    index = next;
                    continue;
                }
            } else if (try skipRawStringOrCommentInPostLoop(raw, &index)) {
                index += 1;
                continue;
            }
            switch (raw[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '$' => if (paren_depth == 0) {
                    return .{
                        .results = std.mem.trim(u8, raw[start..index], " \t\r\n"),
                        .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
                    };
                },
                else => {},
            }
            index += 1;
        }
        return .{
            .results = std.mem.trim(u8, raw[start..index], " \t\r\n"),
            .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
        };
    }

    pub fn qualifiedDeclName(self: *Parser, prefix: ?[]const u8, local_name: []const u8) std.mem.Allocator.Error!QualifiedName {
        if (prefix) |parent| {
            return .{
                .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, local_name }),
                .owns_name = true,
            };
        }
        return .{ .name = local_name };
    }

    pub fn appendParsedStruct(self: *Parser, decl: Struct) Error!void {
        const structs = self.parsed_structs.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try structs.append(self.allocator, decl);
    }

    pub fn appendParsedEnum(self: *Parser, decl: EnumDecl) Error!void {
        const enums = self.parsed_enums.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try enums.append(self.allocator, decl);
    }

    pub fn appendParsedInterface(self: *Parser, decl: InterfaceDecl) Error!void {
        const interfaces = self.parsed_interfaces.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try interfaces.append(self.allocator, decl);
    }

    pub fn appendParsedAnnotation(self: *Parser, decl: AnnotationDecl) Error!void {
        const annotations = self.parsed_annotations.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try annotations.append(self.allocator, decl);
    }

    pub fn registerDeclarationId(self: *Parser, id: ?u64) Error!void {
        const value = id orelse return;
        const decl_ids = self.parsed_decl_ids orelse return;
        const entry = try decl_ids.getOrPut(value);
        if (entry.found_existing) return error.OrdinalCollision;
    }

    pub fn addLocalTypeAlias(self: *Parser, aliases: *std.ArrayList(AliasDecl), decl_names: *std.StringHashMap(void), local_name: []const u8, target_name: []const u8) Error!void {
        const entry = try decl_names.getOrPut(local_name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = local_name, .target = .{ .named = target_name } });
    }

    pub fn parseConstOrSkip(self: *Parser, consts: *std.ArrayList(ConstDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        const name = try self.expectIdentifier();
        const decl_id = try self.parseOptionalDeclarationId();
        if (self.lookahead.tag != .colon) return error.UnexpectedToken;
        try self.expect(.colon);
        var ty = try self.parseType();
        errdefer ty.deinit(self.allocator);

        if (self.lookahead.tag != .equal) return error.UnexpectedToken;
        const block_text_literal = typeAcceptsTextLiteral(ty) and self.constLiteralFirstByte() == '`';
        const list_literal = !block_text_literal and self.constLiteralStartsList();
        if (!block_text_literal and self.constLiteralStartsUnsupported(list_literal)) {
            try self.expect(.equal);
            const raw_tail = try self.takeRawUntilSemicolon();
            const split = splitDefaultExpressionAndAnnotations(raw_tail);
            try Parser.validateAnnotationSuffix(split.annotations);
            const is_embed = std.mem.startsWith(u8, split.default_expression, "embed");
            const embed_path = if (is_embed) embedPathFromExpression(split.default_expression) orelse "" else "";
            const is_struct_literal = std.mem.startsWith(u8, split.default_expression, "(");
            var struct_fields: ?[]ConstStructField = null;
            errdefer if (struct_fields) |fields| self.allocator.free(fields);
            if (is_struct_literal) {
                try self.validateDefaultLiteralForTypeSyntax(ty, split.default_expression);
                struct_fields = try parseConstStructFieldsAlloc(self.allocator, split.default_expression);
            } else if (std.mem.startsWith(u8, split.default_expression, "[")) {
                try self.validateDefaultLiteralForTypeSyntax(ty, split.default_expression);
            }
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) {
                return error.NameCollision;
            }
            try self.registerDeclarationId(decl_id);
            try consts.append(self.allocator, .{
                .name = name,
                .id = decl_id,
                .ty = ty,
                .literal = split.default_expression,
                .is_embed = is_embed,
                .embed_path = embed_path,
                .is_struct_literal = is_struct_literal,
                .emit_value = false,
                .annotations = split.annotations,
                .struct_fields = struct_fields,
            });
            return;
        }

        var is_hex_data = false;
        var list_items: ?[]ConstListItem = null;
        var list_has_aggregate_items = false;
        errdefer if (list_items) |items| {
            deinitConstListItems(self.allocator, items);
            self.allocator.free(items);
        };
        var owns_literal = false;
        var literal_is_string = false;
        const literal: []const u8 = if (block_text_literal) blk: {
            literal_is_string = true;
            break :blk try self.parseBlockTextLiteralAfterEqual();
        } else blk: {
            try self.expect(.equal);
            break :blk if (list_literal) list_blk: {
                const list_start = self.currentTokenStart();
                list_items = try self.parseConstListItems(&list_has_aggregate_items);
                const list_end = self.currentTokenStart();
                break :list_blk std.mem.trim(u8, self.lexer.source[list_start..list_end], " \t\r\n");
            } else if (typeAcceptsDataLiteral(ty) and self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) data_blk: {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) return error.UnexpectedToken;
                const value = self.lookahead.lexeme;
                try self.advance();
                is_hex_data = true;
                break :data_blk value;
            } else value_blk: {
                literal_is_string = self.lookahead.tag == .string;
                const value = (try self.expectDefaultLiteral()) orelse return error.UnexpectedToken;
                owns_literal = self.ownsScratchLiteral(value);
                break :value_blk value;
            };
        };
        if (!block_text_literal) {
            if (is_hex_data) {
                const decoded = hexBytesAlloc(self.allocator, literal) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.InvalidToken => return error.UnexpectedToken,
                    else => return error.UnexpectedToken,
                };
                self.allocator.free(decoded);
            } else if (literal_is_string and (typeAcceptsTextLiteral(ty) or typeAcceptsDataLiteral(ty))) {
                // Const Text/Data literals are stored decoded rather than as raw
                // quoted syntax, so the token stream has already validated their
                // string grammar.  Re-parsing the decoded bytes would reject
                // perfectly valid text such as adjacent strings or C-style
                // escapes after they have been normalized.
            } else {
                try self.validateDefaultLiteralForTypeSyntax(ty, literal);
            }
        }

        if (!isSimpleConstType(ty) and list_items == null) {
            ty.deinit(self.allocator);
            try self.skipRawUntilSemicolon();
            return;
        }
        const const_annotations = try self.takeAnnotationSuffixUntilSemicolon();

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) {
            return error.NameCollision;
        }
        try self.registerDeclarationId(decl_id);
        try consts.append(self.allocator, .{
            .name = name,
            .id = decl_id,
            .ty = ty,
            .literal = literal,
            .owns_literal = owns_literal,
            .is_hex_data = is_hex_data,
            .literal_is_string = literal_is_string,
            .annotations = const_annotations,
            .list_items = list_items,
            .emit_value = !list_has_aggregate_items,
        });
        if (owns_literal) _ = self.takeOwnedLiteral(literal);
    }

    pub fn parseConstListItems(self: *Parser, has_aggregate_items: *bool) Error![]ConstListItem {
        var items = std.ArrayList(ConstListItem).empty;
        errdefer {
            deinitConstListItems(self.allocator, items.items);
            items.deinit(self.allocator);
        }

        try self.expect(.l_bracket);
        while (self.lookahead.tag != .r_bracket) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;

            var is_hex_data = false;
            var owns_literal = false;
            var annotations: []const u8 = "";
            var struct_fields: ?[]ConstStructField = null;
            errdefer if (struct_fields) |fields| self.allocator.free(fields);
            const literal = if (self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) blk: {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) return error.UnexpectedToken;
                const value = self.lookahead.lexeme;
                try self.advance();
                is_hex_data = true;
                break :blk value;
            } else if (self.lookahead.tag == .l_paren or self.lookahead.tag == .l_bracket) blk: {
                has_aggregate_items.* = true;
                const raw_item = try self.takeRawUntilConstListItemEnd();
                const split = splitDefaultExpressionAndAnnotations(raw_item);
                annotations = split.annotations;
                try validateAnnotationSuffix(annotations);
                try self.validateDefaultLiteralSyntax(split.default_expression);
                if (std.mem.startsWith(u8, split.default_expression, "(")) {
                    struct_fields = try parseConstStructFieldsAlloc(self.allocator, split.default_expression);
                }
                break :blk split.default_expression;
            } else blk: {
                const value = (try self.expectDefaultLiteral()) orelse return error.UnexpectedToken;
                owns_literal = self.ownsScratchLiteral(value);
                break :blk value;
            };
            if (annotations.len == 0 and self.lookahead.tag == .dollar) {
                annotations = try self.takeRawUntilConstListItemEnd();
            }
            try validateAnnotationSuffix(annotations);
            try items.append(self.allocator, .{
                .index = items.items.len,
                .literal = literal,
                .owns_literal = owns_literal,
                .is_hex_data = is_hex_data,
                .annotations = annotations,
                .struct_field_count = if (struct_fields) |fields| fields.len else 0,
                .struct_fields = struct_fields orelse &.{},
                .owns_struct_fields = struct_fields != null,
            });
            struct_fields = null;
            if (owns_literal) _ = self.takeOwnedLiteral(literal);

            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_bracket) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_bracket) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_bracket);
        return items.toOwnedSlice(self.allocator);
    }

    pub fn takeRawUntilConstListItemEnd(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        const start = self.currentTokenStart();
        var index = start;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
                '"' => {
                    index += 1;
                    while (index < source.len) : (index += 1) {
                        if (source[index] == '\\') {
                            index += 1;
                        } else if (source[index] == '"') {
                            break;
                        }
                    }
                    if (index >= source.len) return error.UnexpectedToken;
                },
                '#' => index = skipLineCommentIndex(source, index),
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index = skipLineCommentIndex(source, index + 2);
                    } else if (index + 1 < source.len and source[index + 1] == '*') {
                        index = (try skipBlockCommentIndex(source, index)) - 1;
                    } else {
                        index += 1;
                    }
                },
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '[' => bracket_depth += 1,
                ']' => {
                    if (paren_depth == 0 and bracket_depth == 0) break;
                    if (bracket_depth != 0) bracket_depth -= 1;
                },
                ',' => if (paren_depth == 0 and bracket_depth == 0) break,
                else => {},
            }
            index += 1;
        }
        if (index >= source.len) return error.UnexpectedToken;
        self.lexer.index = index;
        try self.advance();
        return std.mem.trim(u8, source[start..index], " \t\r\n");
    }

    pub fn constLiteralStartsList(self: *const Parser) bool {
        return self.constLiteralFirstByte() == '[';
    }

    pub fn constLiteralStartsUnsupported(self: *const Parser, allow_list: bool) bool {
        if (self.constLiteralStartsKeyword("embed")) return true;
        const first = self.constLiteralFirstByte() orelse return true;
        return switch (first) {
            '(' => true,
            '[' => !allow_list,
            else => false,
        };
    }

    pub fn constLiteralFirstByte(self: *const Parser) ?u8 {
        const source = self.lexer.source;
        const index = self.constLiteralStartIndex() orelse return null;
        return source[index];
    }

    pub fn constLiteralStartsKeyword(self: *const Parser, keyword: []const u8) bool {
        const source = self.lexer.source;
        const start = self.constLiteralStartIndex() orelse return false;
        if (start + keyword.len > source.len) return false;
        if (!std.mem.eql(u8, source[start .. start + keyword.len], keyword)) return false;
        const end = start + keyword.len;
        return end == source.len or !isIdentContinue(source[end]);
    }

    pub fn embedPathFromExpression(expression: []const u8) ?[]const u8 {
        const first_quote = std.mem.indexOfScalar(u8, expression, '"') orelse return null;
        var index = first_quote + 1;
        while (index < expression.len) : (index += 1) {
            if (expression[index] == '\\') {
                index += 1;
            } else if (expression[index] == '"') {
                return expression[first_quote + 1 .. index];
            }
        }
        return null;
    }

    pub fn constLiteralStartIndex(self: *const Parser) ?usize {
        const source = self.lexer.source;
        const index = skipTriviaIndexOrNull(source, self.lexer.index) orelse return null;
        if (index >= source.len) return null;
        return index;
    }

    pub fn parseUsingOrSkip(self: *Parser, aliases: *std.ArrayList(AliasDecl), imports: ?*std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.isKeyword("import")) {
            if (imports) |imports_list| try self.parseAnonymousImport(imports_list, decl_names) else try self.skipRawUntilSemicolon();
            return;
        }
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        if ((try self.peekNext()).tag != .equal) {
            var target = try self.parseType();
            var keep_target = false;
            defer if (!keep_target) target.deinit(self.allocator);
            if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
            try self.expect(.semicolon);

            const name = anonymousAliasName(target) orelse {
                return;
            };
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) {
                return error.NameCollision;
            }
            try aliases.append(self.allocator, .{ .name = name, .target = target });
            keep_target = true;
            return;
        }

        const name = try self.expectIdentifier();
        try self.expect(.equal);
        if (self.isKeyword("import")) {
            try self.advance();
            if (self.lookahead.tag != .string) return error.UnexpectedToken;
            const path = self.lookahead.lexeme;
            if (path.len == 0) return error.UnexpectedToken;
            try self.advance();
            var member: ?[]const u8 = null;
            if (self.lookahead.tag == .dot) {
                try self.expect(.dot);
                const first = self.lookahead;
                _ = try self.expectIdentifier();
                var end = first.end;
                if (try self.skipTypeApplications()) |app_end| end = app_end;
                while (self.lookahead.tag == .dot) {
                    try self.expect(.dot);
                    const part = self.lookahead;
                    _ = try self.expectIdentifier();
                    end = part.end;
                    if (try self.skipTypeApplications()) |app_end| end = app_end;
                }
                member = self.lexer.source[first.start..end];
            }
            if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
            try self.expect(.semicolon);

            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            if (imports) |imports_list| try imports_list.append(self.allocator, .{ .name = name, .path = path, .member = member });
            return;
        }

        var target = try self.parseType();
        var keep_target = false;
        defer if (!keep_target) target.deinit(self.allocator);
        if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
        try self.expect(.semicolon);

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = name, .target = target });
        keep_target = true;
    }

    pub fn parseAnonymousImport(self: *Parser, imports: *std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        try self.advance();
        if (self.lookahead.tag != .string) return error.UnexpectedToken;
        const path = self.lookahead.lexeme;
        if (path.len == 0) return error.UnexpectedToken;
        try self.advance();
        if (self.lookahead.tag != .dot) {
            if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
            try self.expect(.semicolon);
            const name = importNameFromPath(path);
            if (name.len == 0) return error.UnexpectedToken;
            try self.reserveBareImportName(decl_names, name);
            try imports.append(self.allocator, .{ .name = name, .path = path });
            return;
        }
        try self.expect(.dot);
        const first = self.lookahead;
        _ = try self.expectIdentifier();
        var end = first.end;
        if (try self.skipTypeApplications()) |app_end| end = app_end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
        }
        if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
        try self.expect(.semicolon);

        const member = self.lexer.source[first.start..end];
        const name = anonymousAliasNameFromRaw(member);
        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
    }

    pub fn reserveBareImportName(self: *Parser, decl_names: *std.StringHashMap(void), name: []const u8) Error!void {
        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;

        // Bare imports use the file stem as a schema-visible namespace.  File
        // stems are often lower-case (`foo.capnp`) while declarations normally
        // use UpperCamelCase (`Foo`), so reserve the leading-capital spelling as
        // well to prevent an imported namespace and a declaration from claiming
        // the same natural schema name in either declaration order.
        const capitalized = try capitalizedImportNameAlloc(self.allocator, name) orelse return;
        errdefer self.allocator.free(capitalized);
        const capitalized_entry = try decl_names.getOrPut(capitalized);
        if (capitalized_entry.found_existing) return error.NameCollision;
        try self.literal_scratch.append(self.allocator, capitalized);
    }

    pub fn parseFileId(self: *Parser) Error!u64 {
        try self.expect(.at);
        const id = try self.expectInteger();
        try self.expect(.semicolon);
        return id;
    }

    pub fn parseOptionalDeclarationId(self: *Parser) Error!?u64 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        const value = try self.expectInteger();
        if (self.lookahead.tag == .at) return error.UnexpectedToken;
        return value;
    }

    pub fn parseStruct(self: *Parser, name_prefix: ?[]const u8) Error!Struct {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const parameters = try self.parseDeclarationParameters(local_name);
        errdefer self.allocator.free(parameters);
        const annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try self.expect(.l_brace);

        var fields = std.ArrayList(Field).empty;
        errdefer {
            for (fields.items) |*field| field.deinit(self.allocator);
            fields.deinit(self.allocator);
        }
        var consts = std.ArrayList(ConstDecl).empty;
        errdefer {
            for (consts.items) |*c| c.deinit(self.allocator);
            consts.deinit(self.allocator);
        }
        var aliases = std.ArrayList(AliasDecl).empty;
        errdefer {
            for (aliases.items) |*a| a.deinit(self.allocator);
            aliases.deinit(self.allocator);
        }
        var groups = std.ArrayList(GroupDecl).empty;
        errdefer groups.deinit(self.allocator);
        var field_names = std.StringHashMap(void).init(self.allocator);
        defer field_names.deinit();
        var member_names = std.StringHashMap(void).init(self.allocator);
        defer member_names.deinit();
        try reserveParameterNames(parameters, &member_names);
        var unions = std.ArrayList(UnionBuilder).empty;
        errdefer {
            for (unions.items) |*u| u.deinit(self.allocator);
            unions.deinit(self.allocator);
        }

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if (self.isKeyword("struct") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseStruct(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedStruct(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("enum") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseEnum(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedEnum(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("interface") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseInterfaceDeclaration(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedInterface(decl);
                keep = true;
                continue;
            }
            if (try self.eatKeyword("annotation")) {
                var decl = try self.parseAnnotationDeclaration(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedAnnotation(decl);
                keep = true;
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(&fields, &field_names, &member_names, &unions, &groups, null);
                continue;
            }
            if (try self.isAnonymousUnionStart()) {
                try self.advance();
                const union_index = try checkedUnionIndex(unions.items.len);
                try unions.append(self.allocator, UnionBuilder.init(self.allocator));
                try self.parseAnonymousUnion(&unions.items[union_index], &member_names, union_index, &groups);
                continue;
            }
            if (try self.eatKeyword("const")) {
                try self.parseConstOrSkip(&consts, &member_names);
                continue;
            }
            if (try self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, self.parsed_imports, &member_names);
                continue;
            }
            if (self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (try putFieldName(&field_names, field.name)) return error.NameCollision;
            const member_entry = try member_names.getOrPut(field.name);
            if (member_entry.found_existing) return error.NameCollision;
            try fields.append(self.allocator, field);
            keep_field = true;
        }
        try self.expect(.r_brace);
        for (unions.items) |*u| try appendUnionFields(self.allocator, &fields, &field_names, u);
        // Group and union lowering appends synthetic fields after their bodies are
        // parsed.  Validate ordinals once the flattened field list is complete so
        // every schema-visible struct member shares the same collision rules.
        try validateStructMemberOrdinals(self.allocator, fields.items, groups.items, unions.items);
        const union_decls = try unionDeclsFromBuilders(self.allocator, unions.items);
        errdefer self.allocator.free(union_decls);
        for (unions.items) |*u| u.deinit(self.allocator);
        unions.deinit(self.allocator);
        return .{
            .name = qualified.name,
            .owns_name = qualified.owns_name,
            .id = decl_id,
            .annotations = annotations,
            .parameters = parameters,
            .fields = try fields.toOwnedSlice(self.allocator),
            .unions = union_decls,
            .groups = try groups.toOwnedSlice(self.allocator),
            .consts = try consts.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
        };
    }

    pub fn parseAnonymousUnion(self: *Parser, union_builder: *UnionBuilder, member_names: *std.StringHashMap(void), union_index: u32, groups: *std.ArrayList(GroupDecl)) Error!void {
        union_builder.name = "";
        union_builder.ordinal = null;
        union_builder.annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try self.expect(.l_brace);
        try self.parseAnonymousUnionBody("", union_builder, member_names, union_index, groups);
    }

    pub fn parseNamedAggregate(
        self: *Parser,
        fields: *std.ArrayList(Field),
        field_names: *std.StringHashMap(void),
        member_names: *std.StringHashMap(void),
        unions: *std.ArrayList(UnionBuilder),
        groups: *std.ArrayList(GroupDecl),
        parent_prefix: ?[]const u8,
    ) Error!void {
        const name = try self.expectIdentifier();
        const ordinal = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (std.mem.eql(u8, kind, "group")) {
            const group_entry = try member_names.getOrPut(name);
            if (group_entry.found_existing) return error.NameCollision;
            const group_prefix = if (parent_prefix) |prefix|
                try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ prefix, name })
            else
                try self.allocator.dupe(u8, name);
            defer self.allocator.free(group_prefix);
            const group_annotations = try self.takeAnnotationSuffixUntilLeftBrace();
            try groups.append(self.allocator, .{
                .index = groups.items.len,
                .name = name,
                .ordinal = ordinal,
                .annotations = group_annotations,
            });
            try self.parseNamedGroupBody(group_prefix, fields, field_names, member_names, unions, groups);
            return;
        }
        if (std.mem.eql(u8, kind, "union")) {
            const union_entry = try member_names.getOrPut(name);
            if (union_entry.found_existing) return error.NameCollision;
            const union_prefix = if (parent_prefix) |prefix|
                try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ prefix, name })
            else
                try self.allocator.dupe(u8, name);
            defer self.allocator.free(union_prefix);
            const union_index = try checkedUnionIndex(unions.items.len);
            try unions.append(self.allocator, UnionBuilder.init(self.allocator));
            unions.items[union_index].name = name;
            unions.items[union_index].ordinal = ordinal;
            unions.items[union_index].annotations = try self.takeAnnotationSuffixUntilLeftBrace();
            try self.parseNamedUnionBody(union_prefix, &unions.items[union_index], member_names, union_index, groups);
            return;
        }
        return error.UnexpectedToken;
    }

    pub fn parseNamedUnionBody(self: *Parser, union_prefix: []const u8, union_builder: *UnionBuilder, member_names: *std.StringHashMap(void), union_index: u32, groups: *std.ArrayList(GroupDecl)) Error!void {
        try self.expect(.l_brace);
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                if (try self.isNamedGroupStart()) {
                    try self.parseUnionGroupMember(union_prefix, union_builder, member_names, union_index, groups);
                    saw_field = true;
                } else {
                    try self.skipNamedAggregate();
                }
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (union_builder.field_names.contains(field.name) or member_names.contains(field.name)) return error.NameCollision;
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ union_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            field.union_index = union_index;
            field.union_member_index = try takeUnionMemberIndex(union_builder);
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    pub fn parseNamedGroupBody(
        self: *Parser,
        group_prefix: []const u8,
        fields: *std.ArrayList(Field),
        field_names: *std.StringHashMap(void),
        member_names: *std.StringHashMap(void),
        unions: *std.ArrayList(UnionBuilder),
        groups: *std.ArrayList(GroupDecl),
    ) Error!void {
        try self.expect(.l_brace);
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(fields, field_names, member_names, unions, groups, group_prefix);
                saw_field = true;
                continue;
            }
            if (try self.isAnonymousUnionStart()) {
                try self.advance();
                _ = try self.takeAnnotationSuffixUntilLeftBrace();
                try self.skipCurrentBracedBody();
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (member_names.contains(field.name)) return error.NameCollision;
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            if (try putFieldName(field_names, field.name)) return error.NameCollision;
            const member_entry = try member_names.getOrPut(field.name);
            if (member_entry.found_existing) return error.NameCollision;
            try fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
    }

    pub fn appendSyntheticVoidField(self: *Parser, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), member_names: *std.StringHashMap(void), name: []const u8, ordinal: u32) Error!void {
        var field = Field{ .name = name, .ordinal = ordinal, .ty = .void };
        if (try putFieldName(field_names, field.name)) {
            field.deinit(self.allocator);
            return error.NameCollision;
        }
        const member_entry = try member_names.getOrPut(field.name);
        if (member_entry.found_existing) {
            field.deinit(self.allocator);
            return error.NameCollision;
        }
        try fields.append(self.allocator, field);
    }

    pub fn skipNamedAggregate(self: *Parser) Error!void {
        _ = try self.expectIdentifier();
        _ = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (!std.mem.eql(u8, kind, "union") and !std.mem.eql(u8, kind, "group")) return error.UnexpectedToken;
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    pub fn parseOptionalOrdinalBang(self: *Parser) Error!?u32 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        return @intCast(ordinal_u64);
    }

    pub fn parseUnionGroupMember(
        self: *Parser,
        parent_prefix: []const u8,
        union_builder: *UnionBuilder,
        member_names: *std.StringHashMap(void),
        union_index: u32,
        groups: *std.ArrayList(GroupDecl),
    ) Error!void {
        const group_name = try self.expectIdentifier();
        const ordinal = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (!std.mem.eql(u8, kind, "group")) return error.UnexpectedToken;
        if (member_names.contains(group_name)) return error.NameCollision;
        const group_entry = try union_builder.field_names.getOrPut(group_name);
        if (group_entry.found_existing) return error.NameCollision;
        const group_prefix = if (parent_prefix.len != 0)
            try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ parent_prefix, group_name })
        else
            try self.allocator.dupe(u8, group_name);
        defer self.allocator.free(group_prefix);
        const group_annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try groups.append(self.allocator, .{
            .index = groups.items.len,
            .name = group_name,
            .ordinal = ordinal,
            .annotations = group_annotations,
        });
        const member_index = try takeUnionMemberIndex(union_builder);

        try self.expect(.l_brace);
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.skipNamedAggregate();
                continue;
            }
            if (try self.isAnonymousUnionStart()) {
                try self.advance();
                _ = try self.takeAnnotationSuffixUntilLeftBrace();
                try self.skipCurrentBracedBody();
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            field.union_index = union_index;
            field.union_member_index = member_index;
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
    }

    pub fn parseAnonymousUnionBody(self: *Parser, union_prefix: []const u8, union_builder: *UnionBuilder, member_names: *std.StringHashMap(void), union_index: u32, groups: *std.ArrayList(GroupDecl)) Error!void {
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                if (try self.isNamedGroupStart()) {
                    try self.parseUnionGroupMember(union_prefix, union_builder, member_names, union_index, groups);
                    saw_field = true;
                } else {
                    try self.skipNamedAggregate();
                }
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (union_builder.field_names.contains(field.name) or member_names.contains(field.name)) return error.NameCollision;
            field.union_index = union_index;
            field.union_member_index = try takeUnionMemberIndex(union_builder);
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    pub fn assignUnionDiscriminants(self: *Parser, fields: []Field) Error!void {
        _ = self;
        for (fields) |*field| {
            const member_index = field.union_member_index orelse return error.InvalidOrdinal;
            if (member_index > std.math.maxInt(u16)) return error.InvalidOrdinal;
            field.union_discriminant = @intCast(member_index);
        }
    }

    pub fn takeUnionMemberIndex(union_builder: *UnionBuilder) Error!u32 {
        const member_index = union_builder.next_member_index;
        if (member_index > std.math.maxInt(u16)) return error.InvalidOrdinal;
        union_builder.next_member_index = std.math.add(u32, union_builder.next_member_index, 1) catch return error.InvalidOrdinal;
        return member_index;
    }

    pub fn parseEnum(self: *Parser, name_prefix: ?[]const u8) Error!EnumDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try self.expect(.l_brace);

        var values = std.ArrayList(EnumValue).empty;
        errdefer values.deinit(self.allocator);
        var occupied_ordinals = std.AutoHashMap(u16, void).init(self.allocator);
        defer occupied_ordinals.deinit();
        var value_names = std.StringHashMap(void).init(self.allocator);
        defer value_names.deinit();

        if (self.lookahead.tag == .r_brace) return error.UnexpectedToken;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const value_name = try self.expectIdentifier();
            const name_entry = try value_names.getOrPut(value_name);
            if (name_entry.found_existing) return error.NameCollision;
            try self.expect(.at);
            const ordinal_u64 = try self.expectInteger();
            if (ordinal_u64 > std.math.maxInt(u16)) return error.InvalidOrdinal;
            const ordinal: u16 = @intCast(ordinal_u64);
            const entry = try occupied_ordinals.getOrPut(ordinal);
            if (entry.found_existing) return error.OrdinalCollision;
            const value_annotations = try self.takeAnnotationSuffixUntilSemicolon();
            try values.append(self.allocator, .{ .index = values.items.len, .name = value_name, .ordinal = ordinal, .annotations = value_annotations });
        }
        try self.expect(.r_brace);
        return .{ .name = qualified.name, .owns_name = qualified.owns_name, .id = decl_id, .annotations = annotations, .values = try values.toOwnedSlice(self.allocator) };
    }

    pub fn parseField(self: *Parser) Error!Field {
        const name = try self.expectIdentifier();
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        try self.expect(.colon);
        var ty = try self.parseType();
        var keep_ty = false;
        errdefer if (!keep_ty) ty.deinit(self.allocator);
        if (isGroupType(ty) and self.lookahead.tag == .l_brace) {
            try self.skipCurrentBracedBody();
            ty.deinit(self.allocator);
            return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = .void };
        }

        var default_literal: ?[]const u8 = null;
        var owns_default_literal = false;
        var default_is_hex_data = false;
        var default_expression: []const u8 = "";
        var annotations: []const u8 = "";
        var default_is_block_text = false;

        if (self.lookahead.tag == .equal) {
            if (ty == .text and self.constLiteralFirstByte() == '`') {
                const literal = try self.parseBlockTextLiteralAfterEqual();
                default_literal = literal;
                default_expression = literal;
                default_is_block_text = true;
                annotations = try self.takeAnnotationSuffixUntilSemicolon();
            } else {
                try self.expect(.equal);
                if (self.lookahead.tag == .l_paren or self.lookahead.tag == .l_bracket) {
                    const raw_tail = try self.takeRawUntilSemicolon();
                    const split = splitDefaultExpressionAndAnnotations(raw_tail);
                    default_expression = split.default_expression;
                    annotations = split.annotations;
                    try validateAnnotationSuffix(annotations);
                    try self.validateInlineAggregateDefaultSyntax(default_expression);
                } else {
                    const default_start = self.currentTokenStart();
                    if (ty == .data and self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) {
                        try self.expect(.integer);
                        if (self.lookahead.tag != .string) return error.UnexpectedToken;
                        default_literal = self.lookahead.lexeme;
                        try self.advance();
                        default_is_hex_data = true;
                    } else {
                        default_literal = try self.expectDefaultLiteral();
                        if (default_literal) |literal| owns_default_literal = self.ownsScratchLiteral(literal);
                    }
                    const default_end = self.currentTokenStart();
                    default_expression = std.mem.trim(u8, self.lexer.source[default_start..default_end], " \t\r\n");
                    annotations = try self.takeAnnotationSuffixUntilSemicolon();
                }
            }
        } else {
            annotations = try self.takeAnnotationSuffixUntilSemicolon();
        }

        if (default_expression.len != 0 and !default_is_block_text) try self.validateDefaultLiteralForTypeSyntax(ty, default_expression);
        if (owns_default_literal) _ = self.takeOwnedLiteral(default_literal.?);
        keep_ty = true;
        return .{
            .name = name,
            .ordinal = @intCast(ordinal_u64),
            .ty = ty,
            .default_literal = default_literal,
            .owns_default_literal = owns_default_literal,
            .default_is_hex_data = default_is_hex_data,
            .default_expression = default_expression,
            .annotations = annotations,
        };
    }

    pub fn parseType(self: *Parser) Error!Type {
        if (self.lookahead.tag == .question) {
            try self.expect(.question);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            return .{ .optional = child };
        }
        if (self.isKeyword("import")) {
            return self.parseInlineImportType();
        }
        if (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const first = self.lookahead;
            _ = try self.expectIdentifier();
            var end = first.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
            while (self.lookahead.tag == .dot) {
                try self.expect(.dot);
                const part = self.lookahead;
                _ = try self.expectIdentifier();
                end = part.end;
                if (try self.skipTypeApplications()) |app_end| end = app_end;
            }
            return .{ .named = self.lexer.source[first.start..end] };
        }
        const first = self.lookahead;
        const name = try self.expectIdentifier();
        if (std.mem.eql(u8, name, "List")) {
            try self.expect(.l_paren);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            errdefer child.deinit(self.allocator);
            try self.expect(.r_paren);
            return .{ .list = child };
        }
        if (std.mem.eql(u8, name, "AnyList")) return .any_list;
        if (std.mem.endsWith(u8, name, "List") and name.len > "List".len) {
            const base_name = name[0 .. name.len - "List".len];
            const child = try self.allocator.create(Type);
            errdefer {
                child.deinit(self.allocator);
                self.allocator.destroy(child);
            }
            child.* = scalarOrNamed(base_name);
            return .{ .list = child };
        }
        var end = first.end;
        if (try self.skipTypeApplications()) |app_end| end = app_end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
        }
        if (end != first.end) return .{ .named = self.lexer.source[first.start..end] };
        return scalarOrNamed(name);
    }

    pub fn skipTypeApplications(self: *Parser) Error!?usize {
        var last_end: ?usize = null;
        var saw_application = false;
        while (self.lookahead.tag == .l_paren) {
            if (saw_application) return error.UnexpectedToken;
            saw_application = true;
            try self.expect(.l_paren);
            if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            while (true) {
                var arg = try self.parseType();
                defer arg.deinit(self.allocator);
                switch (self.lookahead.tag) {
                    .comma => {
                        try self.expect(.comma);
                        if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
                    },
                    .r_paren => {
                        last_end = self.lexer.index;
                        try self.expect(.r_paren);
                        break;
                    },
                    else => return error.UnexpectedToken,
                }
            }
        }
        return last_end;
    }

    pub fn parseInlineImportType(self: *Parser) Error!Type {
        try self.advance();
        if (self.lookahead.tag != .string) return error.UnexpectedToken;
        const path = self.lookahead.lexeme;
        if (path.len == 0) return error.UnexpectedToken;
        try self.advance();
        try self.expect(.dot);

        const first = self.lookahead;
        _ = try self.expectIdentifier();
        var end = first.end;
        if (try self.skipTypeApplications()) |app_end| end = app_end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
        }

        const member = self.lexer.source[first.start..end];
        const name = anonymousAliasName(.{ .named = member }) orelse return error.UnexpectedToken;
        try self.recordInlineImport(name, path, member);
        return .{ .named = name };
    }

    pub fn recordInlineImport(self: *Parser, name: []const u8, path: []const u8, member: []const u8) Error!void {
        const imports = self.parsed_imports orelse return;
        for (imports.items) |import_decl| {
            if (!std.mem.eql(u8, import_decl.name, name)) continue;
            if (std.mem.eql(u8, import_decl.path, path) and import_decl.member != null and std.mem.eql(u8, import_decl.member.?, member)) return;
            return error.NameCollision;
        }
        if (self.parsed_decl_names) |decl_names| {
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
        }
        try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
    }

    pub fn scalarOrNamed(name: []const u8) Type {
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

    pub fn isNamedAggregateStart(self: *const Parser) Error!bool {
        if (self.lookahead.tag != .identifier) return false;
        var lexer = self.lexer;
        var token = try lexer.next();
        if (token.tag == .at) {
            token = try lexer.next();
            if (token.tag != .integer) return false;
            token = try lexer.next();
            if (token.tag == .bang) token = try lexer.next();
        }
        if (token.tag != .colon) return false;
        token = try lexer.next();
        if (token.tag != .identifier) return false;
        if (!std.mem.eql(u8, token.lexeme, "union") and !std.mem.eql(u8, token.lexeme, "group")) return false;
        while (token.tag != .eof and token.tag != .semicolon and token.tag != .r_brace) : (token = try lexer.next()) {
            if (token.tag == .l_brace) return true;
        }
        return false;
    }

    pub fn isNamedGroupStart(self: *const Parser) Error!bool {
        if (self.lookahead.tag != .identifier) return false;
        var lexer = self.lexer;
        var token = try lexer.next();
        if (token.tag == .at) {
            token = try lexer.next();
            if (token.tag != .integer) return false;
            token = try lexer.next();
            if (token.tag == .bang) token = try lexer.next();
        }
        if (token.tag != .colon) return false;
        token = try lexer.next();
        return token.tag == .identifier and std.mem.eql(u8, token.lexeme, "group");
    }

    pub fn isAnonymousUnionStart(self: *const Parser) Error!bool {
        if (!self.isKeyword("union")) return false;
        var lexer = self.lexer;
        var token = try lexer.next();
        while (token.tag != .eof and token.tag != .semicolon and token.tag != .r_brace) : (token = try lexer.next()) {
            if (token.tag == .l_brace) return true;
        }
        return false;
    }

    pub fn eatKeyword(self: *Parser, keyword: []const u8) Error!bool {
        if (self.isKeyword(keyword)) {
            try self.advance();
            return true;
        }
        return false;
    }

    pub fn isKeyword(self: *const Parser, keyword: []const u8) bool {
        return self.lookahead.tag == .identifier and std.mem.eql(u8, self.lookahead.lexeme, keyword);
    }

    pub fn peekNext(self: *const Parser) Error!Token {
        var lexer = self.lexer;
        return lexer.next();
    }

    pub fn expectIdentifier(self: *Parser) Error![]const u8 {
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        const value = self.lookahead.lexeme;
        if (!isSchemaIdentifier(value)) return error.UnexpectedToken;
        try self.advance();
        return value;
    }

    pub fn expectInteger(self: *Parser) Error!u64 {
        if (self.lookahead.tag != .integer) return error.UnexpectedToken;
        if (std.mem.startsWith(u8, self.lookahead.lexeme, "+") or std.mem.startsWith(u8, self.lookahead.lexeme, "-")) return error.UnexpectedToken;
        const value = try parseInteger(self.lookahead.lexeme);
        try self.advance();
        return value;
    }

    pub fn parseBlockTextLiteralAfterEqual(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        var index = try skipTriviaIndex(source, self.lexer.index);
        if (index >= source.len or source[index] != '`') return error.UnexpectedToken;
        index += 1;
        const start = index;
        while (index < source.len and source[index] != ';') : (index += 1) {}
        if (index >= source.len) return error.UnexpectedToken;
        var end = index;
        while (end > start and (source[end - 1] == ' ' or source[end - 1] == '\t' or source[end - 1] == '\r' or source[end - 1] == '\n')) end -= 1;
        self.lexer.index = index;
        try self.advance();
        return source[start..end];
    }

    pub fn currentTokenStart(self: *const Parser) usize {
        if (self.lookahead.start != 0 or self.lookahead.end != 0) return self.lookahead.start;
        return if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
    }

    pub fn expectDefaultLiteral(self: *Parser) Error!?[]const u8 {
        switch (self.lookahead.tag) {
            .dot => {
                const start = self.currentTokenStart();
                try self.expect(.dot);
                const first = self.lookahead;
                _ = try self.expectIdentifier();
                var end = first.end;
                while (self.lookahead.tag == .dot) {
                    try self.expect(.dot);
                    const part = self.lookahead;
                    _ = try self.expectIdentifier();
                    end = part.end;
                }
                return self.lexer.source[start..end];
            },
            .identifier => {
                const first = self.lookahead;
                const value = self.lookahead.lexeme;
                try self.advance();
                var end = first.end;
                while (self.lookahead.tag == .dot) {
                    try self.expect(.dot);
                    const part = self.lookahead;
                    _ = try self.expectIdentifier();
                    end = part.end;
                }
                if (end != first.end) return self.lexer.source[first.start..end];
                return value;
            },
            .integer => {
                const value = self.lookahead.lexeme;
                try self.advance();
                return value;
            },
            .string => return try self.expectStringDefaultLiteral(),
            .l_paren, .l_bracket => return null,
            else => return error.UnexpectedToken,
        }
    }

    pub fn expectStringDefaultLiteral(self: *Parser) Error![]const u8 {
        const first = self.lookahead.lexeme;
        try self.expect(.string);
        if (self.lookahead.tag != .string) return first;

        var joined = std.ArrayList(u8).empty;
        errdefer joined.deinit(self.allocator);
        try joined.appendSlice(self.allocator, first);
        while (self.lookahead.tag == .string) {
            try joined.appendSlice(self.allocator, self.lookahead.lexeme);
            try self.expect(.string);
        }
        const owned = try joined.toOwnedSlice(self.allocator);
        errdefer self.allocator.free(owned);
        try self.literal_scratch.append(self.allocator, owned);
        return owned;
    }

    pub fn splitDefaultExpressionAndAnnotations(raw: []const u8) struct { default_expression: []const u8, annotations: []const u8 } {
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var index: usize = 0;
        while (index < raw.len) : (index += 1) {
            switch (raw[index]) {
                '"' => {
                    index += 1;
                    while (index < raw.len) : (index += 1) {
                        if (raw[index] == '\\') {
                            index += 1;
                        } else if (raw[index] == '"') {
                            break;
                        }
                    }
                },
                '#' => index = skipLineCommentIndex(raw, index),
                '/' => {
                    if (index + 1 < raw.len and raw[index + 1] == '/') {
                        index = skipLineCommentIndex(raw, index + 2);
                    } else if (index + 1 < raw.len and raw[index + 1] == '*') {
                        index = skipBlockCommentIndexOrNull(raw, index) orelse raw.len;
                        if (index != 0) index -= 1;
                    }
                },
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '[' => bracket_depth += 1,
                ']' => {
                    if (bracket_depth != 0) bracket_depth -= 1;
                },
                '$' => if (paren_depth == 0 and bracket_depth == 0) {
                    return .{
                        .default_expression = std.mem.trim(u8, raw[0..index], " \t\r\n"),
                        .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
                    };
                },
                else => {},
            }
        }
        return .{ .default_expression = std.mem.trim(u8, raw, " \t\r\n"), .annotations = "" };
    }

    pub fn parseAnnotationIdentifierIndex(raw: []const u8, start: usize) Error!usize {
        if (start >= raw.len or !isIdentStart(raw[start])) return error.UnexpectedToken;
        var index = start + 1;
        while (index < raw.len and isIdentContinue(raw[index])) index += 1;
        return index;
    }

    pub fn parseAnnotationNameIndex(raw: []const u8, start: usize) Error!usize {
        var index = try parseAnnotationIdentifierIndex(raw, start);
        while (true) {
            if (try skipAnnotationTypeApplicationBeforeDotIndex(raw, index)) |after_app| {
                index = after_app;
            }
            if (index >= raw.len or raw[index] != '.') break;
            index += 1;
            index = try skipTriviaIndex(raw, index);
            index = try parseAnnotationIdentifierIndex(raw, index);
        }
        return index;
    }

    pub fn skipAnnotationTypeApplicationBeforeDotIndex(raw: []const u8, start: usize) Error!?usize {
        const index = try skipTriviaIndex(raw, start);
        if (index >= raw.len or raw[index] != '(') return null;
        const after_args = try skipAnnotationArgumentListIndex(raw, index);
        const after_trivia = try skipTriviaIndex(raw, after_args);
        return if (after_trivia < raw.len and raw[after_trivia] == '.') after_trivia else null;
    }

    pub fn parseAnnotationImportNameIndex(raw: []const u8, start: usize) Error!?usize {
        const import_keyword = "import";
        if (!std.mem.startsWith(u8, raw[start..], import_keyword)) return null;
        const after_keyword = start + import_keyword.len;
        if (after_keyword < raw.len and isIdentContinue(raw[after_keyword])) return null;

        const path_start = try skipTriviaIndex(raw, after_keyword);
        if (path_start >= raw.len or raw[path_start] != '"') return null;
        const path_end = try skipRawStringIndex(raw, path_start);
        // This branch models Cap'n Proto's inline import expression used in
        // annotation references, e.g. `$import "c++.capnp".namespace(...)`.
        // Keep the same non-empty path invariant as `parseInlineImportType()`
        // instead of accepting a syntactically well-balanced but unusable
        // import designator.
        if (path_end == path_start + 2) return error.UnexpectedToken;

        var index = try skipTriviaIndex(raw, path_end);
        if (index >= raw.len or raw[index] != '.') return error.UnexpectedToken;
        index += 1;
        index = try skipTriviaIndex(raw, index);
        return try parseAnnotationNameIndex(raw, index);
    }

    pub fn parseAnnotationDesignatorIndex(raw: []const u8, start: usize) Error!usize {
        if (try parseAnnotationImportNameIndex(raw, start)) |index| return index;
        return parseAnnotationNameIndex(raw, start);
    }

    pub fn skipAnnotationArgumentListIndex(raw: []const u8, start: usize) Error!usize {
        var index = start;
        var paren_depth: usize = 0;
        while (index < raw.len) {
            if (try skipRawStringOrCommentIndex(raw, index)) |next| {
                index = next;
                continue;
            }
            switch (raw[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth == 0) return error.UnexpectedToken;
                    paren_depth -= 1;
                    index += 1;
                    if (paren_depth == 0) return index;
                    continue;
                },
                else => {},
            }
            index += 1;
        }
        return error.UnexpectedToken;
    }

    pub fn validateAnnotationSuffix(raw: []const u8) Error!void {
        var index = try skipTriviaIndex(raw, 0);
        while (index < raw.len) {
            if (raw[index] != '$') return error.UnexpectedToken;
            index += 1;

            index = try skipTriviaIndex(raw, index);
            index = try parseAnnotationDesignatorIndex(raw, index);

            index = try skipTriviaIndex(raw, index);
            if (index < raw.len and raw[index] == '(') {
                index = try skipAnnotationArgumentListIndex(raw, index);
            }

            index = try skipTriviaIndex(raw, index);
        }
    }

    pub fn takeAnnotationSuffixUntilSemicolon(self: *Parser) Error![]const u8 {
        const annotations = try self.takeRawUntilSemicolon();
        try validateAnnotationSuffix(annotations);
        return annotations;
    }

    pub fn takeAnnotationSuffixUntilLeftBrace(self: *Parser) Error![]const u8 {
        const annotations = try self.takeRawUntilLeftBrace();
        try validateAnnotationSuffix(annotations);
        return annotations;
    }

    pub fn skipUntilSemicolon(self: *Parser) Error!void {
        try self.skipUntil(.semicolon);
        try self.expect(.semicolon);
    }

    pub fn skipRawUntilSemicolon(self: *Parser) Error!void {
        const source = self.lexer.source;
        var index = self.lexer.index;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var brace_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
                '`' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '"' => {
                    if (index + 2 < source.len and source[index + 1] == '"' and source[index + 2] == '"') {
                        index += 3;
                        while (index + 2 < source.len and !(source[index] == '"' and source[index + 1] == '"' and source[index + 2] == '"')) : (index += 1) {}
                        if (index + 2 >= source.len) return error.UnexpectedToken;
                        index += 3;
                    } else {
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
                    }
                },
                '#' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '/' => index = try skipRawSlashIndex(source, index),
                '(' => {
                    paren_depth += 1;
                    index += 1;
                },
                ')' => {
                    if (paren_depth > 0) paren_depth -= 1;
                    index += 1;
                },
                '[' => {
                    bracket_depth += 1;
                    index += 1;
                },
                ']' => {
                    if (bracket_depth > 0) bracket_depth -= 1;
                    index += 1;
                },
                '{' => {
                    brace_depth += 1;
                    index += 1;
                },
                '}' => {
                    if (brace_depth > 0) brace_depth -= 1;
                    index += 1;
                },
                ';' => {
                    index += 1;
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) {
                        self.lexer.index = index;
                        try self.advance();
                        return;
                    }
                },
                else => index += 1,
            }
        }
        return error.UnexpectedToken;
    }

    pub fn takeRawUntilSemicolon(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        const start = if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
        var index = start;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var brace_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
                '`' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '"' => {
                    if (index + 2 < source.len and source[index + 1] == '"' and source[index + 2] == '"') {
                        index += 3;
                        while (index + 2 < source.len and !(source[index] == '"' and source[index + 1] == '"' and source[index + 2] == '"')) : (index += 1) {}
                        if (index + 2 >= source.len) return error.UnexpectedToken;
                        index += 3;
                    } else {
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
                    }
                },
                '#' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '/' => index = try skipRawSlashIndex(source, index),
                '(' => {
                    paren_depth += 1;
                    index += 1;
                },
                ')' => {
                    if (paren_depth > 0) paren_depth -= 1;
                    index += 1;
                },
                '[' => {
                    bracket_depth += 1;
                    index += 1;
                },
                ']' => {
                    if (bracket_depth > 0) bracket_depth -= 1;
                    index += 1;
                },
                '{' => {
                    brace_depth += 1;
                    index += 1;
                },
                '}' => {
                    if (brace_depth > 0) brace_depth -= 1;
                    index += 1;
                },
                ';' => {
                    const end = index;
                    index += 1;
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) {
                        self.lexer.index = index;
                        try self.advance();
                        return std.mem.trim(u8, source[start..end], " \t\r\n");
                    }
                },
                else => index += 1,
            }
        }
        return error.UnexpectedToken;
    }

    pub fn takeRawUntilLeftBrace(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        const start = if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
        var index = start;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
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
                },
                '#' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '/' => index = try skipRawSlashIndex(source, index),
                '(' => {
                    paren_depth += 1;
                    index += 1;
                },
                ')' => {
                    if (paren_depth > 0) paren_depth -= 1;
                    index += 1;
                },
                '[' => {
                    bracket_depth += 1;
                    index += 1;
                },
                ']' => {
                    if (bracket_depth > 0) bracket_depth -= 1;
                    index += 1;
                },
                '{' => {
                    if (paren_depth == 0 and bracket_depth == 0) {
                        self.lexer.index = index;
                        try self.advance();
                        return std.mem.trim(u8, source[start..index], " \t\r\n");
                    }
                    index += 1;
                },
                else => index += 1,
            }
        }
        return error.UnexpectedToken;
    }

    pub fn skipUntil(self: *Parser, tag: TokenTag) Error!void {
        var depth: usize = 0;
        while (self.lookahead.tag != tag or depth != 0) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            switch (self.lookahead.tag) {
                .l_paren, .l_bracket => depth += 1,
                .r_paren, .r_bracket => {
                    if (depth > 0) depth -= 1;
                },
                else => {},
            }
            try self.advance();
        }
    }

    pub fn skipBracedDeclaration(self: *Parser) Error!void {
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    pub fn skipCurrentBracedBody(self: *Parser) Error!void {
        try self.expect(.l_brace);
        var depth: usize = 1;
        while (depth != 0) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            switch (self.lookahead.tag) {
                .l_brace => depth += 1,
                .r_brace => depth -= 1,
                else => {},
            }
            try self.advance();
        }
    }

    pub fn expect(self: *Parser, tag: TokenTag) Error!void {
        if (self.lookahead.tag != tag) return error.UnexpectedToken;
        try self.advance();
    }

    pub fn advance(self: *Parser) Error!void {
        self.lookahead = try self.lexer.next();
    }
};

/// Parse schema source into an AST. The caller owns the returned `File`.
pub fn parse(allocator: std.mem.Allocator, source: []const u8) Error!File {
    var parser = try Parser.init(allocator, source);
    defer parser.deinitLiteralScratch();
    return parser.parse();
}

/// Errors produced while loading `embed` constant payloads from disk.
pub const EmbedError = std.Io.Dir.ReadFileAllocError || std.mem.Allocator.Error || serialize.Error || message.Error;

/// Load `embed` constant payloads relative to `base_dir`.
pub fn loadEmbeddedConstValues(allocator: std.mem.Allocator, io: std.Io, file: *File, base_dir: []const u8) EmbedError!void {
    try loadEmbeddedConstValuesInScope(allocator, io, file, null, file.consts, base_dir);
    for (file.structs) |*decl| {
        try loadEmbeddedConstValuesInScope(allocator, io, file, decl, decl.consts, base_dir);
    }
    for (file.interfaces) |*decl| {
        var empty_fields: [0]Field = .{};
        var alias_scope = Struct{
            .name = decl.name,
            .fields = empty_fields[0..],
            .consts = decl.consts,
            .aliases = decl.aliases,
        };
        try loadEmbeddedConstValuesInScope(allocator, io, file, &alias_scope, decl.consts, base_dir);
    }
}

pub fn loadEmbeddedConstValuesInScope(allocator: std.mem.Allocator, io: std.Io, file: *const File, scope: ?*const Struct, consts: []ConstDecl, base_dir: []const u8) EmbedError!void {
    for (consts) |*decl| {
        if (!decl.is_embed or decl.embed_path.len == 0 or decl.embed_bytes != null) continue;
        const is_struct_embed = switch (resolveTypeScoped(file, scope, decl.ty)) {
            .text, .data => false,
            .named => |type_name| findEnum(file, type_name) == null and findInterface(file, type_name) == null and isStructLikeName(file, type_name),
            else => continue,
        };
        const path = try embeddedConstPathAlloc(allocator, base_dir, decl.embed_path);
        defer allocator.free(path);
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64 * 1024 * 1024));
        if (is_struct_embed) try validateEmbeddedStructBytes(allocator, bytes);
        decl.embed_bytes = bytes;
        decl.owns_embed_bytes = true;
        decl.emit_value = true;
    }
}

pub fn embeddedConstPathAlloc(allocator: std.mem.Allocator, base_dir: []const u8, embed_path: []const u8) std.mem.Allocator.Error![]u8 {
    if (std.fs.path.isAbsolute(embed_path) or base_dir.len == 0 or std.mem.eql(u8, base_dir, ".")) {
        return allocator.dupe(u8, embed_path);
    }
    return std.fs.path.join(allocator, &.{ base_dir, embed_path });
}

pub const EmbeddedSegmentRange = struct {
    start: usize,
    end: usize,
};

pub fn embeddedFlatSegmentRangesAlloc(allocator: std.mem.Allocator, bytes: []const u8) (std.mem.Allocator.Error || serialize.Error)![]EmbeddedSegmentRange {
    const expected_len = try serialize.expectedSize(bytes);
    if (bytes.len < expected_len) return error.MessageTruncated;
    const table = try serialize.parseSegmentTable(bytes[0..expected_len]);
    const ranges = try allocator.alloc(EmbeddedSegmentRange, table.segment_count);
    errdefer allocator.free(ranges);

    var offset = table.table_len;
    for (ranges, 0..) |*range, index| {
        const word_count = std.mem.readInt(u32, bytes[4 + index * 4 ..][0..4], .little);
        const byte_count = std.math.mul(usize, word_count, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
        range.* = .{ .start = offset, .end = offset + byte_count };
        offset += byte_count;
    }
    return ranges;
}

pub fn validateEmbeddedStructBytes(allocator: std.mem.Allocator, bytes: []const u8) EmbedError!void {
    const ranges = try embeddedFlatSegmentRangesAlloc(allocator, bytes);
    defer allocator.free(ranges);
    const segments = try allocator.alloc(serialize.ConstSegment, ranges.len);
    defer allocator.free(segments);
    for (ranges, 0..) |range, index| {
        segments[index] = bytes[range.start..range.end];
    }
    var root_reader = message.MessageReader.init(segments, .{
        .traversal_limit_words = std.math.maxInt(usize),
        .nesting_limit = std.math.maxInt(u16),
    });
    _ = try (try root_reader.getRootPointer()).getStruct(null);
    var validate_reader = message.MessageReader.init(segments, .{
        .traversal_limit_words = std.math.maxInt(usize),
        .nesting_limit = std.math.maxInt(u16),
    });
    _ = try validate_reader.validate();
}

pub fn putFieldName(names: *std.StringHashMap(void), name: []const u8) std.mem.Allocator.Error!bool {
    const entry = try names.getOrPut(name);
    return entry.found_existing;
}

pub fn appendUnionFields(allocator: std.mem.Allocator, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), union_builder: *UnionBuilder) Error!void {
    var appended: usize = 0;
    errdefer {
        var i = fields.items.len - appended;
        while (i < fields.items.len) : (i += 1) fields.items[i].deinit(allocator);
        fields.shrinkRetainingCapacity(fields.items.len - appended);
    }
    try fields.ensureUnusedCapacity(allocator, union_builder.fields.items.len);
    const additional_field_names = try hashMapCapacityCount(union_builder.fields.items.len);
    try field_names.ensureUnusedCapacity(additional_field_names);
    for (union_builder.fields.items) |field| {
        if (field_names.contains(field.name)) return error.NameCollision;
    }
    for (union_builder.fields.items) |field| {
        field_names.putAssumeCapacityNoClobber(field.name, {});
        fields.appendAssumeCapacity(field);
        appended += 1;
    }
    union_builder.fields.clearRetainingCapacity();
}

pub fn validateStructMemberOrdinals(allocator: std.mem.Allocator, fields: []const Field, groups: []const GroupDecl, unions: []const UnionBuilder) Error!void {
    var occupied = std.AutoHashMap(u32, void).init(allocator);
    defer occupied.deinit();
    for (fields) |field| {
        const entry = try occupied.getOrPut(field.ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }
    for (groups) |group| {
        const ordinal = group.ordinal orelse continue;
        const entry = try occupied.getOrPut(ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }
    for (unions) |union_builder| {
        const ordinal = union_builder.ordinal orelse continue;
        const entry = try occupied.getOrPut(ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }
}

pub fn unionDeclsFromBuilders(allocator: std.mem.Allocator, builders: []const UnionBuilder) std.mem.Allocator.Error![]UnionDecl {
    const decls = try allocator.alloc(UnionDecl, builders.len);
    for (builders, 0..) |builder, index| {
        decls[index] = .{ .name = builder.name, .ordinal = builder.ordinal, .annotations = builder.annotations };
    }
    return decls;
}

/// Plan ordinal-aware data/pointer layouts for every struct in `file`.
pub fn planLayouts(allocator: std.mem.Allocator, file: *const File) LayoutError!LayoutFile {
    try validateFileTypeApplications(allocator, file);
    try validateFileConstReferenceCycles(file);
    try validateFileAggregateDefaults(allocator, file);
    try validateFileSimpleNamedTypes(allocator, file);

    var layouts = std.ArrayList(StructLayout).empty;
    errdefer {
        for (layouts.items) |*layout| layout.deinit(allocator);
        layouts.deinit(allocator);
    }

    for (file.structs) |*decl| {
        try layouts.append(allocator, try planStructLayout(allocator, file, decl));
    }
    return .{ .structs = try layouts.toOwnedSlice(allocator) };
}

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

/// Plan the physical layout for a single struct declaration.
pub fn planStructLayout(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!StructLayout {
    const fields = try allocator.alloc(FieldLayout, decl.fields.len);
    errdefer allocator.free(fields);
    const union_count = try countUnions(decl.fields);
    const unions = try allocator.alloc(UnionLayout, union_count);
    errdefer allocator.free(unions);
    for (unions, 0..) |*u, index| u.* = .{
        .discriminant_byte = 0,
        .name = if (index < decl.unions.len) decl.unions[index].name else "",
        .ordinal = if (index < decl.unions.len) decl.unions[index].ordinal else null,
        .annotations = if (index < decl.unions.len) decl.unions[index].annotations else "",
    };
    const union_requirements = try allocator.alloc(UnionRequirement, union_count);
    defer allocator.free(union_requirements);
    for (union_requirements) |*req| req.* = .{};
    const union_relative_slots = try computeUnionRelativeSlotsAlloc(allocator, file, decl, union_requirements);
    defer allocator.free(union_relative_slots);
    const union_allocated = try allocator.alloc(bool, union_count);
    defer allocator.free(union_allocated);
    @memset(union_allocated, false);

    var occupied_ordinals = std.AutoHashMap(u32, void).init(allocator);
    defer occupied_ordinals.deinit();
    var assigned = try allocator.alloc(bool, decl.fields.len);
    defer allocator.free(assigned);
    @memset(assigned, false);
    var data_ranges = std.ArrayList(BitRange).empty;
    defer data_ranges.deinit(allocator);

    var data_end_bit: usize = 0;
    var next_pointer: usize = 0;

    for (decl.fields) |*field| {
        const entry = try occupied_ordinals.getOrPut(field.ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }

    for (0..decl.fields.len) |_| {
        const field_index = try nextOrdinalFieldIndexChecked(decl.fields, assigned);
        assigned[field_index] = true;
        const field = &decl.fields[field_index];

        const slot: FieldSlot = if (field.union_index) |union_index| blk: {
            const index: usize = @intCast(union_index);
            if (!union_allocated[index]) {
                const discriminant_start = try allocateDataBits(allocator, &data_ranges, 16);
                data_end_bit = @max(data_end_bit, try dataRangeEnd(discriminant_start, 16));
                unions[index].discriminant_byte = discriminant_start / 8;
                if (union_requirements[index].data_bits != 0) {
                    const start = try allocateDataBits(allocator, &data_ranges, union_requirements[index].data_bits);
                    data_end_bit = @max(data_end_bit, try dataRangeEnd(start, union_requirements[index].data_bits));
                    unions[index].data_bit = start;
                    unions[index].data_bits = union_requirements[index].data_bits;
                }
                if (union_requirements[index].pointer_count != 0) {
                    unions[index].pointer = next_pointer;
                    unions[index].pointer_count = union_requirements[index].pointer_count;
                    next_pointer = std.math.add(usize, next_pointer, union_requirements[index].pointer_count) catch return error.InvalidOrdinal;
                }
                union_allocated[index] = true;
            }
            break :blk try absoluteUnionFieldSlot(union_relative_slots[field_index], unions[index]);
        } else switch (try classifyScoped(file, decl, field.ty)) {
            .void => .void,
            .data => |bits| blk: {
                const start = try allocateDataBits(allocator, &data_ranges, bits);
                data_end_bit = @max(data_end_bit, try dataRangeEnd(start, bits));
                if (bits == 1) break :blk .{ .data_bit = start };
                break :blk .{ .data_byte = start / 8 };
            },
            .pointer => blk: {
                const index = next_pointer;
                next_pointer += 1;
                break :blk .{ .pointer = index };
            },
        };
        fields[field_index] = .{ .field = field, .slot = slot };
    }

    if (data_end_bit > @as(usize, std.math.maxInt(u16)) * 64) return error.InvalidOrdinal;
    if (next_pointer > std.math.maxInt(u16)) return error.InvalidOrdinal;

    return .{
        .decl = decl,
        .data_words = @intCast((data_end_bit + 63) / 64),
        .pointer_count = @intCast(next_pointer),
        .fields = fields,
        .unions = unions,
    };
}

pub const UnionRequirement = struct {
    data_bits: usize = 0,
    pointer_count: usize = 0,
};

pub fn countUnions(fields: []const Field) Error!usize {
    var count: usize = 0;
    for (fields) |field| {
        if (field.union_index) |union_index| {
            const one_past = std.math.add(usize, @intCast(union_index), 1) catch return error.InvalidOrdinal;
            count = @max(count, one_past);
        }
    }
    return count;
}

pub fn dataRangeEnd(start: usize, bits: usize) Error!usize {
    return std.math.add(usize, start, bits) catch return error.InvalidOrdinal;
}

pub fn checkedUnionIndex(index: usize) Error!u32 {
    if (index > std.math.maxInt(u32)) return error.InvalidOrdinal;
    return @intCast(index);
}

pub fn hashMapCapacityCount(count: usize) Error!std.StringHashMap(void).Size {
    if (count > std.math.maxInt(std.StringHashMap(void).Size)) return error.InvalidOrdinal;
    return @intCast(count);
}

pub fn computeUnionRelativeSlotsAlloc(allocator: std.mem.Allocator, file: *const File, decl: *const Struct, union_requirements: []UnionRequirement) LayoutError![]FieldSlot {
    const slots = try allocator.alloc(FieldSlot, decl.fields.len);
    errdefer allocator.free(slots);
    @memset(slots, .void);

    for (0..union_requirements.len) |union_index| {
        const member_count = try countUnionMembers(decl.fields, @intCast(union_index));
        if (member_count == 0) continue;
        const member_data_offsets = try allocator.alloc(usize, member_count);
        defer allocator.free(member_data_offsets);
        const member_pointer_offsets = try allocator.alloc(usize, member_count);
        defer allocator.free(member_pointer_offsets);
        @memset(member_data_offsets, 0);
        @memset(member_pointer_offsets, 0);

        var assigned = try allocator.alloc(bool, decl.fields.len);
        defer allocator.free(assigned);
        @memset(assigned, false);
        for (0..decl.fields.len) |_| {
            const field_index = try nextOrdinalFieldIndexChecked(decl.fields, assigned);
            assigned[field_index] = true;
            const field = decl.fields[field_index];
            if (field.union_index == null or field.union_index.? != union_index) continue;
            const member_index = field.union_member_index orelse return error.InvalidOrdinal;
            slots[field_index] = try unionMemberRelativeSlot(file, decl, field.ty, &member_data_offsets[member_index], &member_pointer_offsets[member_index]);
        }
        for (member_data_offsets) |data_bits| {
            if (data_bits != 0) {
                union_requirements[union_index].data_bits = @max(union_requirements[union_index].data_bits, @max(data_bits, @as(usize, 8)));
            }
        }
        for (member_pointer_offsets) |pointer_count| {
            union_requirements[union_index].pointer_count = @max(union_requirements[union_index].pointer_count, pointer_count);
        }
    }

    return slots;
}

pub fn countUnionMembers(fields: []const Field, union_index: u32) Error!usize {
    var count: usize = 0;
    for (fields) |field| {
        if (field.union_index == null or field.union_index.? != union_index) continue;
        const member_index = field.union_member_index orelse return error.InvalidOrdinal;
        const one_past = std.math.add(usize, @intCast(member_index), 1) catch return error.InvalidOrdinal;
        count = @max(count, one_past);
    }
    return count;
}

pub fn unionMemberRelativeSlot(file: *const File, scope: ?*const Struct, ty: Type, next_data_bit: *usize, next_pointer: *usize) LayoutError!FieldSlot {
    return switch (try classifyScoped(file, scope, ty)) {
        .void => .void,
        .data => |bits| blk: {
            next_data_bit.* = try alignForwardChecked(next_data_bit.*, bits);
            const bit = next_data_bit.*;
            next_data_bit.* = try dataRangeEnd(next_data_bit.*, bits);
            break :blk if (bits == 1) .{ .data_bit = bit } else .{ .data_byte = bit / 8 };
        },
        .pointer => blk: {
            const index = next_pointer.*;
            next_pointer.* = std.math.add(usize, next_pointer.*, 1) catch return error.InvalidOrdinal;
            break :blk .{ .pointer = index };
        },
    };
}

pub fn absoluteUnionFieldSlot(relative: FieldSlot, layout: UnionLayout) LayoutError!FieldSlot {
    return switch (relative) {
        .void => .void,
        .data_bit => |bit| .{ .data_bit = try dataRangeEnd(layout.data_bit, bit) },
        .data_byte => |byte| .{ .data_byte = layout.data_bit / 8 + byte },
        .pointer => |index| .{ .pointer = (layout.pointer orelse return error.UnsupportedType) + index },
    };
}

pub const BitRange = struct {
    start: usize,
    end: usize,
};

pub fn allocateDataBits(allocator: std.mem.Allocator, ranges: *std.ArrayList(BitRange), bits: usize) LayoutError!usize {
    var start: usize = 0;
    while (true) {
        start = try alignForwardChecked(start, bits);
        const end = try dataRangeEnd(start, bits);
        var advanced = false;
        for (ranges.items) |range| {
            if (rangesOverlap(start, end, range.start, range.end)) {
                start = range.end;
                advanced = true;
                break;
            }
        }
        if (!advanced) {
            try ranges.append(allocator, .{ .start = start, .end = end });
            return start;
        }
    }
}

pub fn rangesOverlap(a_start: usize, a_end: usize, b_start: usize, b_end: usize) bool {
    return a_start < b_end and b_start < a_end;
}

pub fn nextOrdinalFieldIndex(fields: []const Field, assigned: []const bool) ?usize {
    var best: ?usize = null;
    for (fields, 0..) |field, index| {
        if (assigned[index]) continue;
        if (best) |best_index| {
            if (field.ordinal < fields[best_index].ordinal) best = index;
        } else {
            best = index;
        }
    }
    return best;
}

pub fn nextOrdinalFieldIndexChecked(fields: []const Field, assigned: []const bool) Error!usize {
    if (fields.len != assigned.len) return error.InvalidOrdinal;
    return nextOrdinalFieldIndex(fields, assigned) orelse error.InvalidOrdinal;
}

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
