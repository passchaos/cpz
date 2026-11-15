const std = @import("std");
const serialize = @import("../../serialize.zig");
const wire = @import("../../wire.zig");

const mod_resolve = @import("resolve.zig");

const annotationTargetCount = mod_resolve.annotationTargetCount;

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

    pub fn callMethod(self: InterfaceMethodMetadata, interface_id: u64) @import("../../rpc.zig").CallMethod {
        return .{ .interface_id = interface_id, .method_id = self.ordinal };
    }

    pub fn matchesCallMethod(self: InterfaceMethodMetadata, interface_id: u64, method: @import("../../rpc.zig").CallMethod) bool {
        return method.matches(interface_id, self.ordinal);
    }

    pub fn methodEntry(self: InterfaceMethodMetadata, interface_id: u64, handler: anytype) @import("../../rpc.zig").CallMethodEntry(@TypeOf(handler)) {
        return self.callMethod(interface_id).methodEntry(handler);
    }

    pub fn callOptions(self: InterfaceMethodMetadata, interface_id: u64) @import("../../rpc.zig").CallOptions {
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
