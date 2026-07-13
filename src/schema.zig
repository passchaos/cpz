const std = @import("std");

pub const Error = error{
    UnexpectedToken,
    InvalidToken,
    InvalidOrdinal,
    NameCollision,
    OrdinalCollision,
    UnsupportedType,
} || std.mem.Allocator.Error || std.fmt.ParseIntError;

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

pub const Field = struct {
    name: []const u8,
    owns_name: bool = false,
    ordinal: u32,
    ty: Type,
    default_literal: ?[]const u8 = null,
    default_is_hex_data: bool = false,
    default_expression: []const u8 = "",
    annotations: []const u8 = "",
    union_index: ?u32 = null,
    union_discriminant: u16 = 0,

    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        if (self.owns_name) allocator.free(self.name);
        self.* = undefined;
    }
};

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
};

pub const ConstDecl = struct {
    name: []const u8,
    ty: Type,
    literal: []const u8,
    is_hex_data: bool = false,
    emit_value: bool = true,
    annotations: []const u8 = "",
    list_items: ?[]ConstListItem = null,

    pub fn deinit(self: *ConstDecl, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        if (self.list_items) |items| allocator.free(items);
        self.* = undefined;
    }
};

pub const ConstListItem = struct {
    index: usize = 0,
    literal: []const u8,
    is_hex_data: bool = false,
    annotations: []const u8 = "",
};

pub const ConstMetadata = struct {
    index: usize = 0,
    name: []const u8,
    ty: []const u8,
    resolved_ty: []const u8 = "",
    literal: []const u8 = "",
    is_hex_data: bool = false,
    emitted: bool = true,
    annotations: []const u8 = "",
    list_item_count: usize = 0,
    list_items: []const ConstListItem = &.{},

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
};

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
};

const UnionBuilder = struct {
    fields: std.ArrayList(Field) = .empty,
    field_names: std.StringHashMap(void),
    next_discriminant: u16 = 0,

    fn init(allocator: std.mem.Allocator) UnionBuilder {
        return .{ .field_names = std.StringHashMap(void).init(allocator) };
    }

    fn deinit(self: *UnionBuilder, allocator: std.mem.Allocator) void {
        for (self.fields.items) |*field| field.deinit(allocator);
        self.fields.deinit(allocator);
        self.field_names.deinit();
    }
};

pub const Struct = struct {
    name: []const u8,
    owns_name: bool = false,
    id: ?u64 = null,
    annotations: []const u8 = "",
    parameters: []const []const u8 = &.{},
    fields: []Field,
    consts: []ConstDecl,
    aliases: []AliasDecl,

    pub fn deinit(self: *Struct, allocator: std.mem.Allocator) void {
        for (self.fields) |*field| field.deinit(allocator);
        allocator.free(self.fields);
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
};

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

    pub fn matchesName(self: FieldMetadata, field_name: []const u8) bool {
        return std.mem.eql(u8, self.name, field_name);
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

    pub fn matchesAnnotations(self: FieldMetadata, annotations: []const u8) bool {
        return std.mem.eql(u8, self.annotations, annotations);
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
    discriminant_byte: usize,
    data_bit: usize = 0,
    data_bits: usize = 0,
    pointer: ?usize = null,
    field_count: usize = 0,
    fields: []const FieldMetadata = &.{},

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
};

pub const DeclarationKind = enum {
    struct_decl,
    enum_decl,
    interface_decl,
    annotation_decl,
};

pub const DeclarationMetadata = struct {
    index: usize = 0,
    name: []const u8,
    kind: DeclarationKind,
    id: ?u64 = null,
    annotations: []const u8 = "",
    parameter_count: usize = 0,
    parameters: []const []const u8 = &.{},

    pub fn parameterByName(self: DeclarationMetadata, parameter: []const u8) ?[]const u8 {
        for (self.parameters) |item| if (std.mem.eql(u8, item, parameter)) return item;
        return null;
    }

    pub fn parameterByIndex(self: DeclarationMetadata, parameter_index: usize) ?[]const u8 {
        if (parameter_index >= self.parameters.len) return null;
        return self.parameters[parameter_index];
    }
};

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

    fn methodFieldByName(fields: []const MethodField, field_name: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.name, field_name)) return field;
        return null;
    }

    fn methodFieldByType(fields: []const MethodField, ty: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.ty, ty)) return field;
        return null;
    }

    fn methodFieldByResolvedType(fields: []const MethodField, ty: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.resolved_ty, ty)) return field;
        return null;
    }

    fn methodFieldByDefault(fields: []const MethodField, default_value: []const u8) ?MethodField {
        for (fields) |field| if (field.default_literal != null and std.mem.eql(u8, field.default_literal.?, default_value)) return field;
        return null;
    }

    fn methodFieldByExplicitDefault(fields: []const MethodField, has_default: bool) ?MethodField {
        for (fields) |field| if (field.has_explicit_default == has_default) return field;
        return null;
    }

    fn methodFieldByHexDefault(fields: []const MethodField, is_hex: bool) ?MethodField {
        for (fields) |field| if (field.default_is_hex_data == is_hex) return field;
        return null;
    }

    fn methodFieldByAnnotations(fields: []const MethodField, annotations: []const u8) ?MethodField {
        for (fields) |field| if (std.mem.eql(u8, field.annotations, annotations)) return field;
        return null;
    }

    fn methodFieldByIndex(fields: []const MethodField, field_index: usize) ?MethodField {
        if (field_index >= fields.len) return null;
        return fields[field_index];
    }
};

pub const InterfaceSuperclassMetadata = struct {
    index: usize,
    name: []const u8,
    resolved_name: []const u8 = "",
};

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

pub const AnnotationDecl = struct {
    name: []const u8,
    owns_name: bool = false,
    id: ?u64 = null,
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
    target_count: usize = 0,
    targets: AnnotationTargets = .{},

    pub fn hasTarget(self: AnnotationMetadata, name: []const u8) bool {
        return self.targets.hasTarget(name);
    }

    pub fn computedTargetCount(self: AnnotationMetadata) usize {
        return self.targets.count();
    }
};

pub const FileAnnotationMetadata = struct {
    index: usize,
    raw: []const u8,
};

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

pub const LayoutError = Error || error{
    UnsupportedInlineComposite,
};

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
    data_bit: usize = 0,
    data_bits: usize = 0,
    pointer: ?usize = null,
};

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

pub const LayoutFile = struct {
    structs: []StructLayout,

    pub fn deinit(self: *LayoutFile, allocator: std.mem.Allocator) void {
        for (self.structs) |*layout| layout.deinit(allocator);
        allocator.free(self.structs);
        self.* = undefined;
    }
};

const TokenTag = enum {
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
    integer,
    string,
    eof,
};

const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    start: usize = 0,
    end: usize = 0,
};

const Lexer = struct {
    source: []const u8,
    index: usize = 0,

    fn next(self: *Lexer) Error!Token {
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
                            break :blk .{ .tag = .string, .lexeme = content };
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

    fn skipSpaceAndComments(self: *Lexer) Error!void {
        while (self.index < self.source.len) {
            switch (self.source[self.index]) {
                ' ', '\t', '\r', '\n' => self.index += 1,
                '#' => {
                    while (self.index < self.source.len and self.source[self.index] != '\n') self.index += 1;
                },
                '/' => {
                    if (self.index + 1 < self.source.len and self.source[self.index + 1] == '/') {
                        self.index += 2;
                        while (self.index < self.source.len and self.source[self.index] != '\n') self.index += 1;
                    } else return;
                },
                else => return,
            }
        }
    }
};

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

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Error!Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .lookahead = first };
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
        var file_id: ?u64 = null;
        self.parsed_structs = &structs;
        self.parsed_enums = &enums;
        self.parsed_interfaces = &interfaces;
        self.parsed_annotations = &annotations;
        self.parsed_imports = &imports;
        self.parsed_decl_names = &decl_names;
        defer {
            self.parsed_structs = null;
            self.parsed_enums = null;
            self.parsed_interfaces = null;
            self.parsed_annotations = null;
            self.parsed_imports = null;
            self.parsed_decl_names = null;
        }

        while (self.lookahead.tag != .eof) {
            if (self.eatKeyword("struct")) {
                var decl = try self.parseStruct(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedStruct(decl);
                keep = true;
            } else if (self.eatKeyword("enum")) {
                var decl = try self.parseEnum(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedEnum(decl);
                keep = true;
            } else if (self.eatKeyword("interface")) {
                var decl = try self.parseInterfaceDeclaration(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedInterface(decl);
                keep = true;
            } else if (self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, &imports, &decl_names);
            } else if (self.eatKeyword("const")) {
                try self.parseConstOrSkip(&consts, &decl_names);
            } else if (self.eatKeyword("annotation")) {
                var decl = try self.parseAnnotationDeclaration(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedAnnotation(decl);
                keep = true;
            } else if (self.lookahead.tag == .dollar) {
                try raw_file_annotations.append(self.allocator, try self.takeRawUntilSemicolon());
            } else if (self.lookahead.tag == .at) {
                file_id = try self.parseFileId();
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

    fn parseInterfaceDeclaration(self: *Parser, name_prefix: ?[]const u8) Error!InterfaceDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const parameters = try self.parseDeclarationParameters();
        errdefer self.allocator.free(parameters);
        const superclasses = try self.parseInterfaceExtendsOrEmpty();
        errdefer {
            for (superclasses) |*superclass| superclass.deinit(self.allocator);
            self.allocator.free(superclasses);
        }
        const annotations = try self.takeRawUntilLeftBrace();
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

    fn parseAnnotationDeclaration(self: *Parser, name_prefix: ?[]const u8) Error!AnnotationDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const targets = try self.parseAnnotationTargets();
        try self.expect(.colon);
        var ty = try self.parseType();
        errdefer ty.deinit(self.allocator);
        try self.skipUntilSemicolon();
        return .{ .name = qualified.name, .owns_name = qualified.owns_name, .id = decl_id, .ty = ty, .targets = targets };
    }

    fn parseAnnotationTargets(self: *Parser) Error!AnnotationTargets {
        try self.expect(.l_paren);
        var targets: AnnotationTargets = .{};
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const target = try self.expectIdentifier();
            if (std.mem.eql(u8, target, "file")) {
                targets.file = true;
            } else if (std.mem.eql(u8, target, "const")) {
                targets.const_decl = true;
            } else if (std.mem.eql(u8, target, "enum")) {
                targets.enum_decl = true;
            } else if (std.mem.eql(u8, target, "enumerant")) {
                targets.enumerant = true;
            } else if (std.mem.eql(u8, target, "struct")) {
                targets.struct_decl = true;
            } else if (std.mem.eql(u8, target, "field")) {
                targets.field = true;
            } else if (std.mem.eql(u8, target, "union")) {
                targets.union_decl = true;
            } else if (std.mem.eql(u8, target, "group")) {
                targets.group = true;
            } else if (std.mem.eql(u8, target, "interface")) {
                targets.interface_decl = true;
            } else if (std.mem.eql(u8, target, "method")) {
                targets.method = true;
            } else if (std.mem.eql(u8, target, "param")) {
                targets.param = true;
            } else if (std.mem.eql(u8, target, "annotation")) {
                targets.annotation_decl = true;
            } else {
                return error.UnexpectedToken;
            }

            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return targets;
    }

    fn parseInterfaceExtendsOrEmpty(self: *Parser) Error![]Type {
        if (!self.isKeyword("extends")) return try self.allocator.alloc(Type, 0);
        try self.advance();
        try self.expect(.l_paren);
        var superclasses = std.ArrayList(Type).empty;
        errdefer {
            for (superclasses.items) |*superclass| superclass.deinit(self.allocator);
            superclasses.deinit(self.allocator);
        }
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            try superclasses.append(self.allocator, try self.parseType());
            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return superclasses.toOwnedSlice(self.allocator);
    }

    fn parseDeclarationParameters(self: *Parser) Error![]const []const u8 {
        if (self.lookahead.tag != .l_paren) return try self.allocator.alloc([]const u8, 0);
        try self.expect(.l_paren);
        var parameters = std.ArrayList([]const u8).empty;
        errdefer parameters.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const name = try self.expectIdentifier();
            const entry = try names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            try parameters.append(self.allocator, name);
            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return parameters.toOwnedSlice(self.allocator);
    }

    fn parseInterfaceBody(self: *Parser, interface_name: []const u8, aliases: *std.ArrayList(AliasDecl), consts: *std.ArrayList(ConstDecl), member_names: *std.StringHashMap(void)) Error![]InterfaceMethod {
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
            if (self.eatKeyword("annotation")) {
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
            if (self.eatKeyword("using")) {
                try self.parseUsingOrSkip(aliases, self.parsed_imports, member_names);
                continue;
            }
            if (self.eatKeyword("const")) {
                try self.parseConstOrSkip(consts, member_names);
                continue;
            }
            if (self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            if (self.lookahead.tag != .identifier or (try self.peekNext()).tag != .at) {
                try self.skipRawUntilSemicolon();
                continue;
            }
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
            const parts = splitMethodSignature(signature);
            const parameters = try self.parseMethodSignatureParameters(signature);
            var keep_parameters = false;
            errdefer if (!keep_parameters) self.allocator.free(parameters);
            const param_fields = try self.parseMethodFields(parts.params);
            var keep_param_fields = false;
            errdefer if (!keep_param_fields) self.allocator.free(param_fields);
            const result_fields = try self.parseMethodFields(parts.results);
            var keep_result_fields = false;
            errdefer if (!keep_result_fields) self.allocator.free(result_fields);
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

    fn parseMethodSignatureParameters(self: *Parser, signature: []const u8) Error![]const []const u8 {
        if (signature.len == 0 or signature[0] != '[') return try self.allocator.alloc([]const u8, 0);
        var parameters = std.ArrayList([]const u8).empty;
        errdefer parameters.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();

        var index: usize = 1;
        while (true) {
            while (index < signature.len and (signature[index] == ' ' or signature[index] == '\t' or signature[index] == '\r' or signature[index] == '\n')) index += 1;
            if (index >= signature.len) return error.UnexpectedToken;
            if (signature[index] == ']') {
                return parameters.toOwnedSlice(self.allocator);
            }
            if (!isIdentStart(signature[index])) return error.UnexpectedToken;
            const start = index;
            index += 1;
            while (index < signature.len and isIdentContinue(signature[index])) index += 1;
            const name = signature[start..index];
            const entry = try names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            try parameters.append(self.allocator, name);
            while (index < signature.len and (signature[index] == ' ' or signature[index] == '\t' or signature[index] == '\r' or signature[index] == '\n')) index += 1;
            if (index >= signature.len) return error.UnexpectedToken;
            if (signature[index] == ',') {
                index += 1;
                continue;
            }
            if (signature[index] == ']') {
                return parameters.toOwnedSlice(self.allocator);
            }
            return error.UnexpectedToken;
        }
    }

    fn parseMethodFields(self: *Parser, raw: []const u8) Error![]const MethodField {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "stream")) return try self.allocator.alloc(MethodField, 0);
        if (trimmed[0] != '(') return try self.allocator.alloc(MethodField, 0);
        var end = trimmed.len;
        var scan: usize = 1;
        var list_depth: usize = 1;
        while (scan < trimmed.len) : (scan += 1) {
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
        var index: usize = 1;
        var fields = std.ArrayList(MethodField).empty;
        errdefer fields.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();

        while (index < end) {
            while (index < end and (trimmed[index] == ' ' or trimmed[index] == '\t' or trimmed[index] == '\r' or trimmed[index] == '\n' or trimmed[index] == ',')) index += 1;
            if (index >= end) break;
            if (!isIdentStart(trimmed[index])) return error.UnexpectedToken;
            const name_start = index;
            index += 1;
            while (index < end and isIdentContinue(trimmed[index])) index += 1;
            const field_name = trimmed[name_start..index];
            const entry = try names.getOrPut(field_name);
            if (entry.found_existing) return error.NameCollision;
            while (index < end and (trimmed[index] == ' ' or trimmed[index] == '\t' or trimmed[index] == '\r' or trimmed[index] == '\n')) index += 1;
            if (index >= end or trimmed[index] != ':') return error.UnexpectedToken;
            index += 1;
            while (index < end and (trimmed[index] == ' ' or trimmed[index] == '\t' or trimmed[index] == '\r' or trimmed[index] == '\n')) index += 1;
            const type_start = index;
            var paren_depth: usize = 0;
            while (index < end) : (index += 1) {
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
            const field_type = std.mem.trim(u8, trimmed[type_start..field_type_end], " \t\r\n");
            if (index < end and trimmed[index] == '=') {
                has_explicit_default = true;
                index += 1;
                while (index < end and (trimmed[index] == ' ' or trimmed[index] == '\t' or trimmed[index] == '\r' or trimmed[index] == '\n')) index += 1;
                const default_start = index;
                var default_paren_depth: usize = 0;
                var default_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
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
                if (std.mem.eql(u8, field_type, "Data")) {
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
            try fields.append(self.allocator, .{ .index = fields.items.len, .name = field_name, .ty = field_type, .default_literal = default_literal, .default_is_hex_data = default_is_hex_data, .has_explicit_default = has_explicit_default, .annotations = annotations });
            if (index < end and trimmed[index] == ',') index += 1;
        }
        return fields.toOwnedSlice(self.allocator);
    }

    fn methodSignatureTypeName(raw: []const u8) []const u8 {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '(' or std.mem.eql(u8, trimmed, "stream")) return "";
        return trimmed;
    }

    fn splitMethodSignature(signature: []const u8) struct { params: []const u8, results: []const u8, annotations: []const u8 } {
        var index: usize = 0;
        if (signature.len != 0 and signature[0] == '[') {
            var bracket_depth: usize = 1;
            index = 1;
            while (index < signature.len and bracket_depth != 0) : (index += 1) {
                switch (signature[index]) {
                    '[' => bracket_depth += 1,
                    ']' => bracket_depth -= 1,
                    else => {},
                }
            }
            while (index < signature.len and (signature[index] == ' ' or signature[index] == '\t' or signature[index] == '\r' or signature[index] == '\n')) index += 1;
        }
        const params_start = index;
        var paren_depth: usize = 0;
        while (index < signature.len) : (index += 1) {
            switch (signature[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '-' => if (paren_depth == 0 and index + 1 < signature.len and signature[index + 1] == '>') {
                    const params = std.mem.trim(u8, signature[params_start..index], " \t\r\n");
                    const result_parts = splitResultAndAnnotations(std.mem.trim(u8, signature[index + 2 ..], " \t\r\n"));
                    return .{ .params = params, .results = result_parts.results, .annotations = result_parts.annotations };
                },
                else => {},
            }
        }
        return .{ .params = std.mem.trim(u8, signature[params_start..], " \t\r\n"), .results = "", .annotations = "" };
    }

    fn splitResultAndAnnotations(raw: []const u8) struct { results: []const u8, annotations: []const u8 } {
        if (raw.len == 0) return .{ .results = "", .annotations = "" };
        var index: usize = 0;
        if (raw[0] == '(') {
            var paren_depth: usize = 1;
            index = 1;
            while (index < raw.len and paren_depth != 0) : (index += 1) {
                switch (raw[index]) {
                    '(' => paren_depth += 1,
                    ')' => paren_depth -= 1,
                    else => {},
                }
            }
            const result_end = index;
            return .{
                .results = std.mem.trim(u8, raw[0..result_end], " \t\r\n"),
                .annotations = std.mem.trim(u8, raw[result_end..], " \t\r\n"),
            };
        }
        var paren_depth: usize = 0;
        while (index < raw.len) : (index += 1) {
            switch (raw[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                ' ', '\t', '\r', '\n' => if (paren_depth == 0) break,
                else => {},
            }
        }
        return .{
            .results = std.mem.trim(u8, raw[0..index], " \t\r\n"),
            .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
        };
    }

    fn qualifiedDeclName(self: *Parser, prefix: ?[]const u8, local_name: []const u8) std.mem.Allocator.Error!QualifiedName {
        if (prefix) |parent| {
            return .{
                .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, local_name }),
                .owns_name = true,
            };
        }
        return .{ .name = local_name };
    }

    fn appendParsedStruct(self: *Parser, decl: Struct) Error!void {
        const structs = self.parsed_structs.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try structs.append(self.allocator, decl);
    }

    fn appendParsedEnum(self: *Parser, decl: EnumDecl) Error!void {
        const enums = self.parsed_enums.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try enums.append(self.allocator, decl);
    }

    fn appendParsedInterface(self: *Parser, decl: InterfaceDecl) Error!void {
        const interfaces = self.parsed_interfaces.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try interfaces.append(self.allocator, decl);
    }

    fn appendParsedAnnotation(self: *Parser, decl: AnnotationDecl) Error!void {
        const annotations = self.parsed_annotations.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try annotations.append(self.allocator, decl);
    }

    fn addLocalTypeAlias(self: *Parser, aliases: *std.ArrayList(AliasDecl), decl_names: *std.StringHashMap(void), local_name: []const u8, target_name: []const u8) Error!void {
        const entry = try decl_names.getOrPut(local_name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = local_name, .target = .{ .named = target_name } });
    }

    fn parseConstOrSkip(self: *Parser, consts: *std.ArrayList(ConstDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.lookahead.tag != .identifier) {
            try self.skipRawUntilSemicolon();
            return;
        }
        const name = try self.expectIdentifier();
        if (self.lookahead.tag != .colon) {
            try self.skipRawUntilSemicolon();
            return;
        }
        try self.expect(.colon);
        var ty = self.parseType() catch {
            try self.skipRawUntilSemicolon();
            return;
        };
        errdefer ty.deinit(self.allocator);

        if (self.lookahead.tag != .equal) {
            ty.deinit(self.allocator);
            try self.skipRawUntilSemicolon();
            return;
        }
        const block_text_literal = ty == .text and self.constLiteralFirstByte() == '`';
        const list_literal = !block_text_literal and self.constLiteralStartsList();
        if (!block_text_literal and self.constLiteralStartsUnsupported(list_literal)) {
            try self.expect(.equal);
            const raw_tail = try self.takeRawUntilSemicolon();
            const split = splitDefaultExpressionAndAnnotations(raw_tail);
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) {
                ty.deinit(self.allocator);
                return error.NameCollision;
            }
            try consts.append(self.allocator, .{
                .name = name,
                .ty = ty,
                .literal = split.default_expression,
                .emit_value = false,
                .annotations = split.annotations,
            });
            return;
        }

        var is_hex_data = false;
        var list_items: ?[]ConstListItem = null;
        errdefer if (list_items) |items| self.allocator.free(items);
        const literal: []const u8 = if (block_text_literal) blk: {
            break :blk self.parseBlockTextLiteralAfterEqual() catch {
                ty.deinit(self.allocator);
                try self.skipRawUntilSemicolon();
                return;
            };
        } else blk: {
            try self.expect(.equal);
            break :blk if (list_literal) list_blk: {
                const list_start = self.currentTokenStart();
                list_items = self.parseConstListItems() catch {
                    ty.deinit(self.allocator);
                    try self.skipRawUntilSemicolon();
                    return;
                };
                const list_end = self.currentTokenStart();
                break :list_blk std.mem.trim(u8, self.lexer.source[list_start..list_end], " \t\r\n");
            } else if (ty == .data and self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) data_blk: {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) {
                    ty.deinit(self.allocator);
                    try self.skipRawUntilSemicolon();
                    return;
                }
                const value = self.lookahead.lexeme;
                try self.advance();
                is_hex_data = true;
                break :data_blk value;
            } else value_blk: {
                const value = (self.expectDefaultLiteral() catch {
                    ty.deinit(self.allocator);
                    try self.skipRawUntilSemicolon();
                    return;
                }) orelse {
                    ty.deinit(self.allocator);
                    try self.skipRawUntilSemicolon();
                    return;
                };
                break :value_blk value;
            };
        };

        if (!isSimpleConstType(ty) and list_items == null) {
            ty.deinit(self.allocator);
            try self.skipRawUntilSemicolon();
            return;
        }
        const const_annotations = try self.takeRawUntilSemicolon();

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) {
            ty.deinit(self.allocator);
            return error.NameCollision;
        }
        try consts.append(self.allocator, .{
            .name = name,
            .ty = ty,
            .literal = literal,
            .is_hex_data = is_hex_data,
            .annotations = const_annotations,
            .list_items = list_items,
        });
    }

    fn parseConstListItems(self: *Parser) Error![]ConstListItem {
        var items = std.ArrayList(ConstListItem).empty;
        errdefer items.deinit(self.allocator);

        try self.expect(.l_bracket);
        while (self.lookahead.tag != .r_bracket) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;

            var is_hex_data = false;
            const literal = if (self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) blk: {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) return error.UnexpectedToken;
                const value = self.lookahead.lexeme;
                try self.advance();
                is_hex_data = true;
                break :blk value;
            } else (try self.expectDefaultLiteral()) orelse return error.UnexpectedToken;
            try items.append(self.allocator, .{ .index = items.items.len, .literal = literal, .is_hex_data = is_hex_data });

            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
            } else if (self.lookahead.tag != .r_bracket) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_bracket);
        return items.toOwnedSlice(self.allocator);
    }

    fn constLiteralStartsList(self: *const Parser) bool {
        return self.constLiteralFirstByte() == '[';
    }

    fn constLiteralStartsUnsupported(self: *const Parser, allow_list: bool) bool {
        if (self.constLiteralStartsKeyword("embed")) return true;
        const first = self.constLiteralFirstByte() orelse return true;
        return switch (first) {
            '(' => true,
            '[' => !allow_list,
            else => false,
        };
    }

    fn constLiteralFirstByte(self: *const Parser) ?u8 {
        const source = self.lexer.source;
        const index = self.constLiteralStartIndex() orelse return null;
        return source[index];
    }

    fn constLiteralStartsKeyword(self: *const Parser, keyword: []const u8) bool {
        const source = self.lexer.source;
        const start = self.constLiteralStartIndex() orelse return false;
        if (start + keyword.len > source.len) return false;
        if (!std.mem.eql(u8, source[start .. start + keyword.len], keyword)) return false;
        const end = start + keyword.len;
        return end == source.len or !isIdentContinue(source[end]);
    }

    fn constLiteralStartIndex(self: *const Parser) ?usize {
        const source = self.lexer.source;
        var index = self.lexer.index;
        while (index < source.len) {
            switch (source[index]) {
                ' ', '\t', '\r', '\n' => index += 1,
                '#' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index += 2;
                        while (index < source.len and source[index] != '\n') index += 1;
                    } else {
                        return index;
                    }
                },
                else => return index,
            }
        }
        return null;
    }

    fn parseUsingOrSkip(self: *Parser, aliases: *std.ArrayList(AliasDecl), imports: ?*std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.isKeyword("import")) {
            if (imports) |imports_list| try self.parseAnonymousImport(imports_list, decl_names) else try self.skipRawUntilSemicolon();
            return;
        }
        if (self.lookahead.tag != .identifier) {
            try self.skipRawUntilSemicolon();
            return;
        }
        if ((try self.peekNext()).tag != .equal) {
            var target = self.parseType() catch {
                try self.skipRawUntilSemicolon();
                return;
            };
            var keep_target = false;
            defer if (!keep_target) target.deinit(self.allocator);
            if (self.lookahead.tag != .semicolon) {
                try self.skipRawUntilSemicolon();
                return;
            }
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
            if (self.lookahead.tag != .string) {
                try self.skipRawUntilSemicolon();
                return;
            }
            const path = self.lookahead.lexeme;
            try self.advance();
            var member: ?[]const u8 = null;
            if (self.lookahead.tag == .dot) {
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
                member = self.lexer.source[first.start..end];
            }
            if (self.lookahead.tag != .semicolon) {
                try self.skipRawUntilSemicolon();
                return;
            }
            try self.expect(.semicolon);

            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            if (imports) |imports_list| try imports_list.append(self.allocator, .{ .name = name, .path = path, .member = member });
            return;
        }

        var target = self.parseType() catch {
            try self.skipRawUntilSemicolon();
            return;
        };
        var keep_target = false;
        defer if (!keep_target) target.deinit(self.allocator);
        if (self.lookahead.tag != .semicolon) {
            try self.skipRawUntilSemicolon();
            return;
        }
        try self.expect(.semicolon);

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = name, .target = target });
        keep_target = true;
    }

    fn parseAnonymousImport(self: *Parser, imports: *std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        try self.advance();
        if (self.lookahead.tag != .string) {
            try self.skipRawUntilSemicolon();
            return;
        }
        const path = self.lookahead.lexeme;
        try self.advance();
        if (self.lookahead.tag != .dot) {
            try self.skipRawUntilSemicolon();
            return;
        }
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
        if (self.lookahead.tag != .semicolon) {
            try self.skipRawUntilSemicolon();
            return;
        }
        try self.expect(.semicolon);

        const member = self.lexer.source[first.start..end];
        const name = if (std.mem.lastIndexOfScalar(u8, member, '.')) |dot| member[dot + 1 ..] else member;
        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
    }

    fn parseFileId(self: *Parser) Error!u64 {
        try self.expect(.at);
        const id = try self.expectInteger();
        try self.expect(.semicolon);
        return id;
    }

    fn parseOptionalDeclarationId(self: *Parser) Error!?u64 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        return try self.expectInteger();
    }

    fn parseStruct(self: *Parser, name_prefix: ?[]const u8) Error!Struct {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const parameters = try self.parseDeclarationParameters();
        errdefer self.allocator.free(parameters);
        const annotations = try self.takeRawUntilLeftBrace();
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
        var field_names = std.StringHashMap(void).init(self.allocator);
        defer field_names.deinit();
        var member_names = std.StringHashMap(void).init(self.allocator);
        defer member_names.deinit();
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
            if (self.eatKeyword("annotation")) {
                var decl = try self.parseAnnotationDeclaration(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedAnnotation(decl);
                keep = true;
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(&fields, &field_names, &member_names, &unions, null);
                continue;
            }
            if (self.isKeyword("union") and (try self.peekNext()).tag == .l_brace) {
                try self.advance();
                const union_index: u32 = @intCast(unions.items.len);
                try unions.append(self.allocator, UnionBuilder.init(self.allocator));
                try self.parseAnonymousUnion(&unions.items[union_index], union_index);
                continue;
            }
            if (self.eatKeyword("const")) {
                try self.parseConstOrSkip(&consts, &member_names);
                continue;
            }
            if (self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, self.parsed_imports, &member_names);
                continue;
            }
            if (self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            if (try putFieldName(&field_names, field.name)) {
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
        try self.expect(.r_brace);
        for (unions.items) |*u| try appendUnionFields(self.allocator, &fields, &field_names, u);
        for (unions.items) |*u| u.deinit(self.allocator);
        unions.deinit(self.allocator);
        return .{
            .name = qualified.name,
            .owns_name = qualified.owns_name,
            .id = decl_id,
            .annotations = annotations,
            .parameters = parameters,
            .fields = try fields.toOwnedSlice(self.allocator),
            .consts = try consts.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
        };
    }

    fn parseAnonymousUnion(self: *Parser, union_builder: *UnionBuilder, union_index: u32) Error!void {
        try self.expect(.l_brace);
        try self.parseAnonymousUnionBody(union_builder, union_index);
    }

    fn parseNamedAggregate(self: *Parser, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), member_names: *std.StringHashMap(void), unions: *std.ArrayList(UnionBuilder), parent_prefix: ?[]const u8) Error!void {
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
            try self.skipUntil(.l_brace);
            try self.parseNamedGroupBody(group_prefix, fields, field_names, member_names, unions);
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
            try self.skipUntil(.l_brace);
            const union_index: u32 = @intCast(unions.items.len);
            try unions.append(self.allocator, UnionBuilder.init(self.allocator));
            _ = ordinal;
            try self.parseNamedUnionBody(union_prefix, &unions.items[union_index], union_index);
            return;
        }
        return error.UnexpectedToken;
    }

    fn parseNamedUnionBody(self: *Parser, union_prefix: []const u8, union_builder: *UnionBuilder, union_index: u32) Error!void {
        try self.expect(.l_brace);
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
            if (self.eatKeyword("using") or self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ union_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            field.union_index = union_index;
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
        }
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    fn parseNamedGroupBody(self: *Parser, group_prefix: []const u8, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), member_names: *std.StringHashMap(void), unions: *std.ArrayList(UnionBuilder)) Error!void {
        try self.expect(.l_brace);
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(fields, field_names, member_names, unions, group_prefix);
                continue;
            }
            if (self.isKeyword("union") and (try self.peekNext()).tag == .l_brace) {
                try self.advance();
                try self.skipCurrentBracedBody();
                continue;
            }
            if (self.eatKeyword("using") or self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            if (try putFieldName(field_names, field.name)) return error.NameCollision;
            const member_entry = try member_names.getOrPut(field.name);
            if (member_entry.found_existing) return error.NameCollision;
            try fields.append(self.allocator, field);
            keep_field = true;
        }
        try self.expect(.r_brace);
    }

    fn appendSyntheticVoidField(self: *Parser, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), member_names: *std.StringHashMap(void), name: []const u8, ordinal: u32) Error!void {
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

    fn skipNamedAggregate(self: *Parser) Error!void {
        _ = try self.expectIdentifier();
        _ = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (!std.mem.eql(u8, kind, "union") and !std.mem.eql(u8, kind, "group")) return error.UnexpectedToken;
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    fn parseOptionalOrdinalBang(self: *Parser) Error!?u32 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        return @intCast(ordinal_u64);
    }

    fn parseAnonymousUnionBody(self: *Parser, union_builder: *UnionBuilder, union_index: u32) Error!void {
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
            if (self.eatKeyword("using") or self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            field.union_index = union_index;
            if (try putFieldName(&union_builder.field_names, field.name)) {
                field.deinit(self.allocator);
                return error.NameCollision;
            }
            try union_builder.fields.append(self.allocator, field);
        }
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    fn assignUnionDiscriminants(self: *Parser, fields: []Field) Error!void {
        var assigned = try self.allocator.alloc(bool, fields.len);
        defer self.allocator.free(assigned);
        @memset(assigned, false);
        for (0..fields.len) |discriminant| {
            if (discriminant > std.math.maxInt(u16)) return error.InvalidOrdinal;
            const field_index = nextOrdinalFieldIndex(fields, assigned) orelse unreachable;
            assigned[field_index] = true;
            fields[field_index].union_discriminant = @intCast(discriminant);
        }
    }

    fn parseEnum(self: *Parser, name_prefix: ?[]const u8) Error!EnumDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const annotations = try self.takeRawUntilLeftBrace();
        try self.expect(.l_brace);

        var values = std.ArrayList(EnumValue).empty;
        errdefer values.deinit(self.allocator);
        var occupied_ordinals = std.AutoHashMap(u16, void).init(self.allocator);
        defer occupied_ordinals.deinit();
        var value_names = std.StringHashMap(void).init(self.allocator);
        defer value_names.deinit();

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
            const value_annotations = try self.takeRawUntilSemicolon();
            try values.append(self.allocator, .{ .index = values.items.len, .name = value_name, .ordinal = ordinal, .annotations = value_annotations });
        }
        try self.expect(.r_brace);
        return .{ .name = qualified.name, .owns_name = qualified.owns_name, .id = decl_id, .annotations = annotations, .values = try values.toOwnedSlice(self.allocator) };
    }

    fn parseField(self: *Parser) Error!Field {
        const name = try self.expectIdentifier();
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        try self.expect(.colon);
        const ty = try self.parseType();
        if (isGroupType(ty) and self.lookahead.tag == .l_brace) {
            try self.skipCurrentBracedBody();
            return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = .void };
        }

        var default_literal: ?[]const u8 = null;
        var default_is_hex_data = false;
        var default_expression: []const u8 = "";
        var annotations: []const u8 = "";

        if (self.lookahead.tag == .equal) {
            if (ty == .text and self.constLiteralFirstByte() == '`') {
                const literal = try self.parseBlockTextLiteralAfterEqual();
                default_literal = literal;
                default_expression = literal;
                annotations = try self.takeRawUntilSemicolon();
            } else {
                try self.expect(.equal);
                if (self.lookahead.tag == .l_paren or self.lookahead.tag == .l_bracket) {
                    const raw_tail = try self.takeRawUntilSemicolon();
                    const split = splitDefaultExpressionAndAnnotations(raw_tail);
                    default_expression = split.default_expression;
                    annotations = split.annotations;
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
                    }
                    const default_end = self.currentTokenStart();
                    default_expression = std.mem.trim(u8, self.lexer.source[default_start..default_end], " \t\r\n");
                    annotations = try self.takeRawUntilSemicolon();
                }
            }
        } else {
            annotations = try self.takeRawUntilSemicolon();
        }

        return .{
            .name = name,
            .ordinal = @intCast(ordinal_u64),
            .ty = ty,
            .default_literal = default_literal,
            .default_is_hex_data = default_is_hex_data,
            .default_expression = default_expression,
            .annotations = annotations,
        };
    }

    fn parseType(self: *Parser) Error!Type {
        if (self.lookahead.tag == .question) {
            try self.expect(.question);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            return .{ .optional = child };
        }
        const first = self.lookahead;
        const name = try self.expectIdentifier();
        if (std.mem.eql(u8, name, "List")) {
            try self.expect(.l_paren);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            try self.expect(.r_paren);
            return .{ .list = child };
        }
        if (std.mem.eql(u8, name, "AnyList")) return .any_list;
        if (std.mem.endsWith(u8, name, "List") and name.len > "List".len) {
            const base_name = name[0 .. name.len - "List".len];
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
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

    fn skipTypeApplications(self: *Parser) Error!?usize {
        var last_end: ?usize = null;
        while (self.lookahead.tag == .l_paren) {
            try self.expect(.l_paren);
            var depth: usize = 1;
            while (depth != 0) {
                if (self.lookahead.tag == .eof) return error.UnexpectedToken;
                switch (self.lookahead.tag) {
                    .l_paren => depth += 1,
                    .r_paren => {
                        depth -= 1;
                        last_end = self.lexer.index;
                    },
                    else => {},
                }
                try self.advance();
            }
        }
        return last_end;
    }

    fn scalarOrNamed(name: []const u8) Type {
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

    fn isNamedAggregateStart(self: *const Parser) Error!bool {
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

    fn eatKeyword(self: *Parser, keyword: []const u8) bool {
        if (self.isKeyword(keyword)) {
            self.advance() catch unreachable;
            return true;
        }
        return false;
    }

    fn isKeyword(self: *const Parser, keyword: []const u8) bool {
        return self.lookahead.tag == .identifier and std.mem.eql(u8, self.lookahead.lexeme, keyword);
    }

    fn peekNext(self: *const Parser) Error!Token {
        var lexer = self.lexer;
        return lexer.next();
    }

    fn expectIdentifier(self: *Parser) Error![]const u8 {
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        const value = self.lookahead.lexeme;
        try self.advance();
        return value;
    }

    fn expectInteger(self: *Parser) Error!u64 {
        if (self.lookahead.tag != .integer) return error.UnexpectedToken;
        const value = try parseInteger(self.lookahead.lexeme);
        try self.advance();
        return value;
    }

    fn parseBlockTextLiteralAfterEqual(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        var index = self.lexer.index;
        while (index < source.len and (source[index] == ' ' or source[index] == '\t' or source[index] == '\r' or source[index] == '\n')) : (index += 1) {}
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

    fn currentTokenStart(self: *const Parser) usize {
        return if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
    }

    fn expectDefaultLiteral(self: *Parser) Error!?[]const u8 {
        switch (self.lookahead.tag) {
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
            .integer, .string => {
                const value = self.lookahead.lexeme;
                try self.advance();
                return value;
            },
            .l_paren, .l_bracket => return null,
            else => return error.UnexpectedToken,
        }
    }

    fn splitDefaultExpressionAndAnnotations(raw: []const u8) struct { default_expression: []const u8, annotations: []const u8 } {
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

    fn skipUntilSemicolon(self: *Parser) Error!void {
        try self.skipUntil(.semicolon);
        try self.expect(.semicolon);
    }

    fn skipRawUntilSemicolon(self: *Parser) Error!void {
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
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index += 2;
                        while (index < source.len and source[index] != '\n') index += 1;
                    } else {
                        index += 1;
                    }
                },
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

    fn takeRawUntilSemicolon(self: *Parser) Error![]const u8 {
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
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index += 2;
                        while (index < source.len and source[index] != '\n') index += 1;
                    } else {
                        index += 1;
                    }
                },
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

    fn takeRawUntilLeftBrace(self: *Parser) Error![]const u8 {
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
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index += 2;
                        while (index < source.len and source[index] != '\n') index += 1;
                    } else {
                        index += 1;
                    }
                },
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

    fn skipUntil(self: *Parser, tag: TokenTag) Error!void {
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

    fn skipBracedDeclaration(self: *Parser) Error!void {
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    fn skipCurrentBracedBody(self: *Parser) Error!void {
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

    fn expect(self: *Parser, tag: TokenTag) Error!void {
        if (self.lookahead.tag != tag) return error.UnexpectedToken;
        try self.advance();
    }

    fn advance(self: *Parser) Error!void {
        self.lookahead = try self.lexer.next();
    }
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8) Error!File {
    var parser = try Parser.init(allocator, source);
    return parser.parse();
}

fn putFieldName(names: *std.StringHashMap(void), name: []const u8) std.mem.Allocator.Error!bool {
    const entry = try names.getOrPut(name);
    return entry.found_existing;
}

fn appendUnionFields(allocator: std.mem.Allocator, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), union_builder: *UnionBuilder) Error!void {
    var appended: usize = 0;
    errdefer {
        var i = fields.items.len - appended;
        while (i < fields.items.len) : (i += 1) fields.items[i].deinit(allocator);
        fields.shrinkRetainingCapacity(fields.items.len - appended);
    }
    try fields.ensureUnusedCapacity(allocator, union_builder.fields.items.len);
    try field_names.ensureUnusedCapacity(@intCast(union_builder.fields.items.len));
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

pub fn planLayouts(allocator: std.mem.Allocator, file: *const File) LayoutError!LayoutFile {
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

pub fn planStructLayout(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!StructLayout {
    const fields = try allocator.alloc(FieldLayout, decl.fields.len);
    errdefer allocator.free(fields);
    const union_count = countUnions(decl.fields);
    const unions = try allocator.alloc(UnionLayout, union_count);
    errdefer allocator.free(unions);
    for (unions) |*u| u.* = .{ .discriminant_byte = 0 };
    const union_requirements = try allocator.alloc(UnionRequirement, union_count);
    defer allocator.free(union_requirements);
    for (union_requirements) |*req| req.* = .{};
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
        if (field.union_index) |union_index| {
            try addUnionRequirement(file, decl, &union_requirements[@intCast(union_index)], field.ty);
        }
    }

    for (0..decl.fields.len) |_| {
        const field_index = nextOrdinalFieldIndex(decl.fields, assigned) orelse unreachable;
        assigned[field_index] = true;
        const field = &decl.fields[field_index];

        const slot: FieldSlot = if (field.union_index) |union_index| blk: {
            const index: usize = @intCast(union_index);
            if (!union_allocated[index]) {
                const discriminant_start = try allocateDataBits(allocator, &data_ranges, 16);
                data_end_bit = @max(data_end_bit, discriminant_start + 16);
                unions[index].discriminant_byte = discriminant_start / 8;
                if (union_requirements[index].data_bits != 0) {
                    const start = try allocateDataBits(allocator, &data_ranges, union_requirements[index].data_bits);
                    data_end_bit = @max(data_end_bit, start + union_requirements[index].data_bits);
                    unions[index].data_bit = start;
                    unions[index].data_bits = union_requirements[index].data_bits;
                }
                if (union_requirements[index].has_pointer) {
                    unions[index].pointer = next_pointer;
                    next_pointer += 1;
                }
                union_allocated[index] = true;
            }
            break :blk try unionFieldSlot(file, decl, field.ty, unions[index]);
        } else switch (try classifyScoped(file, decl, field.ty)) {
            .void => .void,
            .data => |bits| blk: {
                const start = try allocateDataBits(allocator, &data_ranges, bits);
                data_end_bit = @max(data_end_bit, start + bits);
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

const UnionRequirement = struct {
    data_bits: usize = 0,
    has_pointer: bool = false,
};

fn countUnions(fields: []const Field) usize {
    var count: usize = 0;
    for (fields) |field| {
        if (field.union_index) |union_index| count = @max(count, @as(usize, @intCast(union_index)) + 1);
    }
    return count;
}

fn addUnionRequirement(file: *const File, scope: ?*const Struct, req: *UnionRequirement, ty: Type) LayoutError!void {
    switch (try classifyScoped(file, scope, ty)) {
        .void => {},
        .data => |bits| req.data_bits = @max(req.data_bits, @max(bits, @as(usize, 8))),
        .pointer => req.has_pointer = true,
    }
}

fn unionFieldSlot(file: *const File, scope: ?*const Struct, ty: Type, layout: UnionLayout) LayoutError!FieldSlot {
    return switch (try classifyScoped(file, scope, ty)) {
        .void => .void,
        .data => |bits| if (bits == 1) .{ .data_bit = layout.data_bit } else .{ .data_byte = layout.data_bit / 8 },
        .pointer => .{ .pointer = layout.pointer orelse return error.UnsupportedType },
    };
}

const BitRange = struct {
    start: usize,
    end: usize,
};

fn allocateDataBits(allocator: std.mem.Allocator, ranges: *std.ArrayList(BitRange), bits: usize) LayoutError!usize {
    var start: usize = 0;
    while (true) {
        start = alignForward(usize, start, bits);
        const end = std.math.add(usize, start, bits) catch return error.InvalidOrdinal;
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

fn rangesOverlap(a_start: usize, a_end: usize, b_start: usize, b_end: usize) bool {
    return a_start < b_end and b_start < a_end;
}

fn nextOrdinalFieldIndex(fields: []const Field, assigned: []const bool) ?usize {
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

const TypeClass = union(enum) {
    void,
    data: usize,
    pointer,
};

fn classify(file: *const File, ty: Type) LayoutError!TypeClass {
    return classifyScoped(file, null, ty);
}

fn classifyScoped(file: *const File, scope: ?*const Struct, ty: Type) LayoutError!TypeClass {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void => .void,
        .bool => .{ .data = 1 },
        .int8, .uint8 => .{ .data = 8 },
        .int16, .uint16 => .{ .data = 16 },
        .int32, .uint32, .float32 => .{ .data = 32 },
        .int64, .uint64, .float64 => .{ .data = 64 },
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => .pointer,
        .optional => .pointer,
        .named => |name| if (findEnum(file, name) != null) .{ .data = 16 } else .pointer,
    };
}

fn findEnum(file: *const File, name: []const u8) ?*const EnumDecl {
    if (findEnumDirect(file, name)) |decl| return decl;
    const resolved = resolveNamedAlias(file, null, name, 0) orelse return null;
    return switch (resolved) {
        .named => |resolved_name| findEnumDirect(file, resolved_name),
        else => null,
    };
}

fn findEnumDirect(file: *const File, name: []const u8) ?*const EnumDecl {
    for (file.enums) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

fn findStructDirect(file: *const File, name: []const u8) ?*const Struct {
    for (file.structs) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

fn findInterface(file: *const File, name: []const u8) ?*const InterfaceDecl {
    if (findInterfaceDirect(file, name)) |decl| return decl;
    const resolved = resolveNamedAlias(file, null, name, 0) orelse return null;
    return switch (resolved) {
        .named => |resolved_name| findInterfaceDirect(file, resolved_name),
        .capability => &builtin_capability_interface,
        else => null,
    };
}

const builtin_capability_interface = InterfaceDecl{ .name = "Capability" };

fn findInterfaceDirect(file: *const File, name: []const u8) ?*const InterfaceDecl {
    for (file.interfaces) |*decl| {
        if (typeNameEqualsCanonical(name, decl.name)) return decl;
    }
    return null;
}

fn firstTopLevelDot(raw: []const u8) ?usize {
    var depth: usize = 0;
    for (raw, 0..) |c, index| {
        switch (c) {
            '(' => depth += 1,
            ')' => {
                if (depth != 0) depth -= 1;
            },
            '.' => {
                if (depth == 0) return index;
            },
            else => {},
        }
    }
    return null;
}

fn lastTopLevelDot(raw: []const u8) ?usize {
    var depth: usize = 0;
    var found: ?usize = null;
    for (raw, 0..) |c, index| {
        switch (c) {
            '(' => depth += 1,
            ')' => {
                if (depth != 0) depth -= 1;
            },
            '.' => {
                if (depth == 0) found = index;
            },
            else => {},
        }
    }
    return found;
}

fn typeNameEqualsCanonical(raw: []const u8, canonical: []const u8) bool {
    var canonical_index: usize = 0;
    var depth: usize = 0;
    for (raw) |c| {
        switch (c) {
            '(' => {
                depth += 1;
                continue;
            },
            ')' => {
                if (depth == 0) return false;
                depth -= 1;
                continue;
            },
            else => {},
        }
        if (depth != 0) continue;
        if (canonical_index >= canonical.len or canonical[canonical_index] != c) return false;
        canonical_index += 1;
    }
    return depth == 0 and canonical_index == canonical.len;
}

fn canonicalTypeNameAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var depth: usize = 0;
    for (raw) |c| {
        switch (c) {
            '(' => {
                depth += 1;
                continue;
            },
            ')' => {
                if (depth != 0) depth -= 1;
                continue;
            },
            else => {},
        }
        if (depth == 0) try out.append(allocator, c);
    }
    return out.toOwnedSlice(allocator);
}

fn isImportedTypeName(file: *const File, name: []const u8) bool {
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

fn isStructLikeName(file: *const File, name: []const u8) bool {
    return findStructDirect(file, name) != null or
        isImportedTypeName(file, name) or
        std.mem.indexOfScalar(u8, name, '.') != null;
}

fn resolveType(file: *const File, ty: Type) Type {
    return resolveTypeScoped(file, null, ty);
}

fn resolveTypeScoped(file: *const File, scope: ?*const Struct, ty: Type) Type {
    return switch (ty) {
        .named => |name| resolveNamedAlias(file, scope, name, 0) orelse ty,
        else => ty,
    };
}

fn resolveNamedAlias(file: *const File, scope: ?*const Struct, name: []const u8, depth: usize) ?Type {
    if (depth >= 32) return null;
    if (scope) |decl| {
        for (decl.aliases) |alias| {
            if (!std.mem.eql(u8, alias.name, name)) continue;
            return switch (alias.target) {
                .named => |target_name| resolveNamedAlias(file, scope, target_name, depth + 1) orelse alias.target,
                else => alias.target,
            };
        }
    }
    for (file.aliases) |alias| {
        if (!std.mem.eql(u8, alias.name, name)) continue;
        return switch (alias.target) {
            .named => |target_name| resolveNamedAlias(file, null, target_name, depth + 1) orelse alias.target,
            else => alias.target,
        };
    }
    return null;
}

fn isSimpleConstType(ty: Type) bool {
    return switch (ty) {
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64, .text, .data, .list, .named => true,
        else => false,
    };
}

fn anonymousAliasName(ty: Type) ?[]const u8 {
    return switch (ty) {
        .named => |name| if (lastTopLevelDot(name)) |dot| name[dot + 1 ..] else name,
        else => null,
    };
}

fn isGroupType(ty: Type) bool {
    return switch (ty) {
        .named => |name| std.mem.eql(u8, name, "group"),
        else => false,
    };
}

fn alignForward(comptime T: type, value: T, alignment: T) T {
    if (alignment == 0) return value;
    return ((value + alignment - 1) / alignment) * alignment;
}

fn parseInteger(text: []const u8) (std.fmt.ParseIntError || error{InvalidToken})!u64 {
    if (text.len > 2 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X')) {
        return std.fmt.parseInt(u64, text[2..], 16);
    }
    return std.fmt.parseInt(u64, text, 10);
}

fn isIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

fn isIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

fn isNumberContinue(c: u8) bool {
    return switch (c) {
        '0'...'9', 'a'...'f', 'A'...'F', 'x', 'X', '.', '+', '-' => true,
        else => false,
    };
}

test "schema parser handles structs, file ids, lists, comments" {
    const source =
        \\@0xabcdef;
        \\# a comment
        \\struct Person {
        \\  id @0 :UInt32 = 123;
        \\  name @1 :Text;
        \\  scores @2 :List(Int32);
        \\  bestFriend @3 :Person;
        \\}
    ;

    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 0xabcdef), file.id);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Person", file.structs[0].name);
    try std.testing.expectEqual(@as(usize, 4), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("id", file.structs[0].fields[0].name);
    try std.testing.expectEqual(@as(u32, 0), file.structs[0].fields[0].ordinal);
    try std.testing.expectEqual(Type.uint32, file.structs[0].fields[0].ty);
    try std.testing.expectEqualStrings("123", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqual(Type.text, file.structs[0].fields[1].ty);
    try std.testing.expect(file.structs[0].fields[2].ty == .list);
    try std.testing.expectEqual(Type.int32, file.structs[0].fields[2].ty.list.*);
    try std.testing.expect(file.structs[0].fields[3].ty == .named);
    try std.testing.expectEqualStrings("Person", file.structs[0].fields[3].ty.named);
}

test "schema parser rejects invalid syntax" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct Bad { field @0 UInt32; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "@!;"));
}

test "schema parser rejects duplicate enum ordinals" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\enum Bad {
        \\  a @0;
        \\  b @0;
        \\}
    ));
}

test "schema parser rejects duplicate enum value names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\enum Bad {
        \\  value @0;
        \\  value @1;
        \\}
    ));
}

test "schema parser rejects duplicate interface method names and ordinals" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> ();
        \\  call @1 () -> ();
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  first @0 () -> ();
        \\  second @0 () -> ();
        \\}
    ));
}

test "schema parser rejects duplicate field names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :UInt32;
        \\  value @1 :Text;
        \\}
    ));
}

test "schema parser rejects duplicate top-level declaration names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Thing {
        \\  id @0 :UInt32;
        \\}
        \\enum Thing {
        \\  value @0;
        \\}
    ));
}

test "schema parser skips common top-level using and const declarations" {
    const source =
        \\using Go = import "go.capnp";
        \\const defaultName :Text = "Ada";
        \\const embeddedText :Text = embed "testdata/short.txt";
        \\const rawPerson :Person = (name = "Raw");
        \\const blockText :Text =
        \\  `line one
        \\  `"quoted" line two
        \\  ;
        \\struct Person {
        \\  name @0 :Text = "Ada";
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqual(@as(usize, 4), file.consts.len);
    try std.testing.expectEqualStrings("Person", file.structs[0].name);
    try std.testing.expectEqualStrings("Ada", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("defaultName", file.consts[0].name);
    try std.testing.expectEqualStrings("embeddedText", file.consts[1].name);
    try std.testing.expectEqualStrings("embed \"testdata/short.txt\"", file.consts[1].literal);
    try std.testing.expect(!file.consts[1].emit_value);
    try std.testing.expectEqualStrings("rawPerson", file.consts[2].name);
    try std.testing.expectEqualStrings("(name = \"Raw\")", file.consts[2].literal);
    try std.testing.expect(!file.consts[2].emit_value);
    try std.testing.expectEqualStrings("blockText", file.consts[3].name);
}

test "schema parser tolerates imports and annotations" {
    const source =
        \\using Cxx = import "/capnp/c++.capnp".Cpp;
        \\enum Status {
        \\  ok @0 $Cxx.name("OK");
        \\  bad @1;
        \\}
        \\struct Task $Cxx.name("Task") {
        \\  id @0 :UInt64 $Cxx.name("id");
        \\  status @1 :Status = ok $Cxx.name("status");
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.enums.len);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Task", file.structs[0].name);
    try std.testing.expectEqualStrings("ok", file.structs[0].fields[1].default_literal.?);
}

test "schema parser records imported type aliases" {
    const source =
        \\using Other = import "other.capnp";
        \\using import "common.capnp".Shared;
        \\struct Holder {
        \\  external @0 :Other.External;
        \\  shared @1 :Shared;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), file.imports.len);
    try std.testing.expectEqualStrings("Other", file.imports[0].name);
    try std.testing.expectEqualStrings("other.capnp", file.imports[0].path);
    try std.testing.expect(file.imports[0].member == null);
    try std.testing.expectEqualStrings("Shared", file.imports[1].name);
    try std.testing.expectEqualStrings("common.capnp", file.imports[1].path);
    try std.testing.expectEqualStrings("Shared", file.imports[1].member.?);
    try std.testing.expectEqualStrings("Other.External", file.structs[0].fields[0].ty.named);
    try std.testing.expectEqualStrings("Shared", file.structs[0].fields[1].ty.named);
}

test "schema parser skips top-level annotations and interfaces" {
    const source =
        \\annotation deprecated @0xaaaa (field) :Text;
        \\annotation labels(enumerant) :List(Text);
        \\$Cxx.namespace("example");
        \\interface Service {
        \\  call @0 (request :Text) -> (response :Text);
        \\}
        \\interface Extended extends(Service) {
        \\  next @1 () -> ();
        \\}
        \\struct Payload {
        \\  id @0 :UInt32;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), file.annotations.len);
    try std.testing.expectEqualStrings("deprecated", file.annotations[0].name);
    try std.testing.expectEqual(@as(?u64, 0xaaaa), file.annotations[0].id);
    try std.testing.expectEqual(Type.text, file.annotations[0].ty);
    try std.testing.expect(file.annotations[0].targets.field);
    try std.testing.expect(!file.annotations[0].targets.file);
    try std.testing.expectEqualStrings("labels", file.annotations[1].name);
    try std.testing.expect(file.annotations[1].ty == .list);
    try std.testing.expectEqual(Type.text, file.annotations[1].ty.list.*);
    try std.testing.expect(file.annotations[1].targets.enumerant);
    try std.testing.expectEqual(@as(usize, 2), file.interfaces.len);
    try std.testing.expectEqualStrings("Service", file.interfaces[0].name);
    try std.testing.expectEqual(@as(usize, 1), file.interfaces[0].methods.len);
    try std.testing.expectEqualStrings("call", file.interfaces[0].methods[0].name);
    try std.testing.expectEqual(@as(u16, 0), file.interfaces[0].methods[0].ordinal);
    try std.testing.expectEqualStrings("Extended", file.interfaces[1].name);
    try std.testing.expectEqual(@as(usize, 1), file.interfaces[1].superclasses.len);
    try std.testing.expect(file.interfaces[1].superclasses[0] == .named);
    try std.testing.expectEqualStrings("Service", file.interfaces[1].superclasses[0].named);
    try std.testing.expectEqual(@as(usize, 1), file.interfaces[1].methods.len);
    try std.testing.expectEqualStrings("next", file.interfaces[1].methods[0].name);
    try std.testing.expectEqual(@as(u16, 1), file.interfaces[1].methods[0].ordinal);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Payload", file.structs[0].name);
    try std.testing.expectEqual(@as(usize, 1), file.structs[0].fields.len);
}

test "schema parser lowers simple named group declarations" {
    const source =
        \\struct Late {
        \\  before @0 :Text;
        \\  selected @1! :union $Ann.name("selected") {
        \\    text @2 :Text;
        \\    id @3 :UInt32;
        \\  }
        \\  metadata :group {
        \\    created @4 :UInt64;
        \\  }
        \\  const localName :Text =
        \\    `block text
        \\    ;
        \\  using Alias = Text;
        \\  annotation local(field) :Text;
        \\  interface Local {
        \\    call @0 () -> ();
        \\  }
        \\  keep @5 :Text;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqual(@as(usize, 5), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("before", file.structs[0].fields[0].name);
    try std.testing.expectEqualStrings("metadata_created", file.structs[0].fields[1].name);
    try std.testing.expectEqual(Type.uint64, file.structs[0].fields[1].ty);
    try std.testing.expectEqual(@as(u32, 4), file.structs[0].fields[1].ordinal);
    try std.testing.expectEqualStrings("keep", file.structs[0].fields[2].name);
    try std.testing.expectEqualStrings("selected_text", file.structs[0].fields[3].name);
    try std.testing.expect(file.structs[0].fields[3].ty == .text);
    try std.testing.expectEqual(@as(?u32, 0), file.structs[0].fields[3].union_index);
    try std.testing.expectEqual(@as(u16, 0), file.structs[0].fields[3].union_discriminant);
    try std.testing.expectEqualStrings("selected_id", file.structs[0].fields[4].name);
    try std.testing.expectEqual(Type.uint32, file.structs[0].fields[4].ty);
    try std.testing.expectEqual(@as(?u32, 0), file.structs[0].fields[4].union_index);
    try std.testing.expectEqual(@as(u16, 1), file.structs[0].fields[4].union_discriminant);
}

test "schema parser accepts TypeList shorthand" {
    var file = try parse(std.testing.allocator,
        \\struct Lists {
        \\  ids @0 :UInt32List;
        \\  names @1 :TextList;
        \\  children @2 :ChildList;
        \\}
        \\struct Child {
        \\  id @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expect(file.structs[0].fields[0].ty == .list);
    try std.testing.expectEqual(Type.uint32, file.structs[0].fields[0].ty.list.*);
    try std.testing.expect(file.structs[0].fields[1].ty == .list);
    try std.testing.expectEqual(Type.text, file.structs[0].fields[1].ty.list.*);
    try std.testing.expect(file.structs[0].fields[2].ty == .list);
    try std.testing.expect(file.structs[0].fields[2].ty.list.* == .named);
    try std.testing.expectEqualStrings("Child", file.structs[0].fields[2].ty.list.*.named);
}

test "schema parser and codegen accept plus-prefixed numeric defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Numbers {
        \\  ratio @0 :Float32 = +1.5;
        \\  count @1 :Int32 = +7;
        \\  tiny @2 :Float64 = 1e-3;
        \\  huge @3 :Float64 = +2.5E+4;
        \\  posInf @4 :Float32 = inf;
        \\  negInf @5 :Float64 = -inf;
        \\  quietNan @6 :Float32 = nan;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("+1.5", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("+7", file.structs[0].fields[1].default_literal.?);
    try std.testing.expectEqualStrings("1e-3", file.structs[0].fields[2].default_literal.?);
    try std.testing.expectEqualStrings("+2.5E+4", file.structs[0].fields[3].default_literal.?);
    try std.testing.expectEqualStrings("inf", file.structs[0].fields[4].default_literal.?);
    try std.testing.expectEqualStrings("-inf", file.structs[0].fields[5].default_literal.?);
    try std.testing.expectEqualStrings("nan", file.structs[0].fields[6].default_literal.?);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(0, 1.5)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getInt32(4, 7)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(8, 1e-3)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(16, 2.5E+4)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(24, std.math.inf(f32))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(32, -std.math.inf(f64))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(28, std.math.nan(f32))") != null);
}

test "schema parser tolerates list and struct field defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Child {
        \\  id @0 :UInt32;
        \\}
        \\struct Defaults {
        \\  nums @0 :List(UInt32) = [1, 2, 3];
        \\  child @1 :Child = (id = 42);
        \\  bytes @2 :Data = 0x"62 61 72";
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?[]const u8, null), file.structs[1].fields[0].default_literal);
    try std.testing.expectEqual(@as(?[]const u8, null), file.structs[1].fields[1].default_literal);
    try std.testing.expectEqualStrings("62 61 72", file.structs[1].fields[2].default_literal.?);
    try std.testing.expect(file.structs[1].fields[2].default_is_hex_data);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Defaults = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_nums(self: Builder, count: usize)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_child(self: Builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getDataDefault(\"bar\")") != null);
}

test "schema parser and codegen accept optional pointer types" {
    var file = try parse(std.testing.allocator,
        \\struct Maybe {
        \\  name @0 :?Text;
        \\  friend @1 :?Maybe;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expect(file.structs[0].fields[0].ty == .optional);
    try std.testing.expectEqual(Type.text, file.structs[0].fields[0].ty.optional.*);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 2), layouts.structs[0].pointer_count);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn name(self: @This()) ![]const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !@\"cpz.schema\".Maybe.Builder") != null);
}

test "schema parser lowers anonymous unions and tolerates group blocks inside structs" {
    const source =
        \\struct Choice {
        \\  union {
        \\    name @0 :Text;
        \\    id @1 :UInt32;
        \\  }
        \\  metadata @2 :group {
        \\    created @3 :UInt64;
        \\  }
        \\  keep @4 :Text;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    // Simple named group fields are flattened with a group-name prefix;
    // anonymous union fields are lowered into ordinary fields tagged with
    // discriminant metadata.
    try std.testing.expectEqual(@as(usize, 4), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("metadata_created", file.structs[0].fields[0].name);
    try std.testing.expectEqual(Type.uint64, file.structs[0].fields[0].ty);
    try std.testing.expectEqualStrings("keep", file.structs[0].fields[1].name);
    try std.testing.expectEqualStrings("name", file.structs[0].fields[2].name);
    try std.testing.expectEqual(@as(?u32, 0), file.structs[0].fields[2].union_index);
    try std.testing.expectEqual(@as(u16, 0), file.structs[0].fields[2].union_discriminant);
    try std.testing.expectEqualStrings("id", file.structs[0].fields[3].name);
    try std.testing.expectEqual(@as(?u32, 0), file.structs[0].fields[3].union_index);
    try std.testing.expectEqual(@as(u16, 1), file.structs[0].fields[3].union_discriminant);
}

test "schema parser tolerates nested declarations and dotted type names" {
    const source =
        \\struct Outer {
        \\  struct Inner {
        \\    value @0 :UInt32;
        \\  }
        \\  enum State {
        \\    ready @0;
        \\  }
        \\  using LocalName = Text;
        \\  child @0 :Outer.Inner;
        \\  state @1 :State;
        \\  aliasName @2 :LocalName;
        \\  anonymousAlias @3 :Inner;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), file.structs.len);
    try std.testing.expectEqualStrings("Outer.Inner", file.structs[0].name);
    try std.testing.expectEqualStrings("Outer", file.structs[1].name);
    try std.testing.expectEqual(@as(usize, 1), file.enums.len);
    try std.testing.expectEqualStrings("Outer.State", file.enums[0].name);

    const outer = &file.structs[1];
    try std.testing.expectEqual(@as(usize, 4), outer.fields.len);
    try std.testing.expectEqual(@as(usize, 3), outer.aliases.len);
    try std.testing.expectEqualStrings("Inner", outer.aliases[0].name);
    try std.testing.expect(outer.aliases[0].target == .named);
    try std.testing.expectEqualStrings("Outer.Inner", outer.aliases[0].target.named);
    try std.testing.expectEqualStrings("State", outer.aliases[1].name);
    try std.testing.expect(outer.aliases[1].target == .named);
    try std.testing.expectEqualStrings("Outer.State", outer.aliases[1].target.named);
    try std.testing.expectEqualStrings("LocalName", outer.aliases[2].name);
    try std.testing.expect(outer.fields[0].ty == .named);
    try std.testing.expectEqualStrings("Outer.Inner", outer.fields[0].ty.named);
    try std.testing.expect(outer.fields[1].ty == .named);
    try std.testing.expectEqualStrings("State", outer.fields[1].ty.named);
    const resolved_state = resolveTypeScoped(&file, outer, outer.fields[1].ty);
    try std.testing.expect(resolved_state == .named);
    try std.testing.expectEqualStrings("Outer.State", resolved_state.named);
    try std.testing.expect(outer.fields[2].ty == .named);
    try std.testing.expectEqualStrings("LocalName", outer.fields[2].ty.named);
    try std.testing.expectEqual(Type.text, resolveTypeScoped(&file, outer, outer.fields[2].ty));
    try std.testing.expect(outer.fields[3].ty == .named);
    try std.testing.expectEqualStrings("Inner", outer.fields[3].ty.named);
    const resolved_anonymous = resolveTypeScoped(&file, outer, outer.fields[3].ty);
    try std.testing.expect(resolved_anonymous == .named);
    try std.testing.expectEqualStrings("Outer.Inner", resolved_anonymous.named);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, layouts.structs[1].fields[2].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 2 }, layouts.structs[1].fields[3].slot);
}

test "schema layout planner assigns data and pointer slots" {
    const source =
        \\struct Sample {
        \\  enabled @0 :Bool;
        \\  count @1 :UInt16;
        \\  name @2 :Text;
        \\  value @3 :Float64;
        \\  children @4 :List(Sample);
        \\}
    ;

    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), layouts.structs.len);
    const layout = layouts.structs[0];
    try std.testing.expectEqual(@as(u16, 2), layout.data_words);
    try std.testing.expectEqual(@as(u16, 2), layout.pointer_count);
    try std.testing.expectEqual(FieldSlot{ .data_bit = 0 }, layout.fields[0].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 2 }, layout.fields[1].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, layout.fields[2].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 8 }, layout.fields[3].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, layout.fields[4].slot);
}

test "schema layout planner rejects duplicate ordinals" {
    var file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  a @0 :UInt32;
        \\  b @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectError(error.OrdinalCollision, planLayouts(std.testing.allocator, &file));
}

test "schema layout planner allocates slots by ordinal not declaration order" {
    var file = try parse(std.testing.allocator,
        \\struct OutOfOrder {
        \\  later @1 :UInt32;
        \\  first @0 :UInt32;
        \\  ptrLater @3 :Text;
        \\  ptrFirst @2 :Text;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const fields = layouts.structs[0].fields;
    try std.testing.expectEqualStrings("later", fields[0].field.name);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 4 }, fields[0].slot);
    try std.testing.expectEqualStrings("first", fields[1].field.name);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, fields[1].slot);
    try std.testing.expectEqualStrings("ptrLater", fields[2].field.name);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, fields[2].slot);
    try std.testing.expectEqualStrings("ptrFirst", fields[3].field.name);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, fields[3].slot);
}

test "schema layout planner overlaps anonymous union fields" {
    var file = try parse(std.testing.allocator,
        \\struct Choice {
        \\  before @0 :Text;
        \\  union {
        \\    foo @1 :UInt16;
        \\    bar @3 :UInt32;
        \\  }
        \\  middle @2 :UInt16;
        \\  after @4 :Text;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const layout = layouts.structs[0];
    try std.testing.expectEqual(@as(u16, 1), layout.data_words);
    try std.testing.expectEqual(@as(u16, 2), layout.pointer_count);
    try std.testing.expectEqual(@as(usize, 1), layout.unions.len);
    try std.testing.expectEqual(@as(usize, 0), layout.unions[0].discriminant_byte);
    try std.testing.expectEqual(@as(usize, 32), layout.unions[0].data_bit);
    try std.testing.expectEqual(@as(usize, 32), layout.unions[0].data_bits);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, layout.fields[0].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 2 }, layout.fields[1].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, layout.fields[2].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 4 }, layout.fields[3].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 4 }, layout.fields[4].slot);
}

test "schema layout planner reuses alignment padding holes" {
    var file = try parse(std.testing.allocator,
        \\struct Compact {
        \\  byte @0 :UInt8;
        \\  word @1 :UInt64;
        \\  small @2 :UInt16;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const layout = layouts.structs[0];
    try std.testing.expectEqual(@as(u16, 2), layout.data_words);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, layout.fields[0].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 8 }, layout.fields[1].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 2 }, layout.fields[2].slot);
}

pub const CodegenOptions = struct {
    runtime_import_name: []const u8 = "cpz",
    raw_schema_comment: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
};

pub fn generateZig(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile) LayoutError![]u8 {
    return generateZigWithOptions(allocator, file, layouts, .{});
}

pub fn generateZigWithOptions(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile, options: CodegenOptions) LayoutError![]u8 {
    try validateZigNameCollisions(allocator, file);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (options.raw_schema_comment) |source| {
        try appendRawSchemaComment(allocator, &out, source);
    }
    try appendFmt(allocator, &out,
        \\const std = @import("std");
        \\const cpz = @import("{s}");
        \\const @"cpz.schema" = @This();
        \\
        \\
    , .{options.runtime_import_name});
    if (options.namespace) |raw_namespace| {
        const namespace = try zigIdentAlloc(allocator, raw_namespace);
        defer allocator.free(namespace);
        try appendFmt(allocator, &out,
            \\pub const {s} = struct {{
            \\    const @"cpz.schema" = @This();
            \\
        , .{namespace});
    }
    if (file.id) |id| {
        const indent = if (options.namespace != null) "    " else "";
        try appendFmt(allocator, &out,
            \\{s}pub const @"cpz.file_id": u64 = 0x{x};
            \\
            \\
        , .{ indent, id });
    }
    for (file.annotations_raw, 0..) |annotation_raw, index| {
        const indent = if (options.namespace != null) "    " else "";
        const annotation_literal = try zigStringLiteralAlloc(allocator, annotation_raw);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, &out,
            \\{s}pub const @"cpz.file_annotation.{}": []const u8 = {s};
            \\
        , .{ indent, index, annotation_literal });
    }
    if (file.annotations_raw.len != 0) try out.append(allocator, '\n');
    try emitFileAnnotationMetadataTable(allocator, &out, file.annotations_raw, if (options.namespace != null) "    " else "");
    try emitDeclarationMetadataTable(allocator, &out, file, if (options.namespace != null) "    " else "");
    try emitImportMetadataTable(allocator, &out, file.imports, if (options.namespace != null) "    " else "");
    try emitAliasMetadataTable(allocator, &out, file, null, file.aliases, if (options.namespace != null) "    " else "");
    try emitConstMetadataTable(allocator, &out, file, null, file.consts, if (options.namespace != null) "    " else "");
    for (file.consts, 0..) |*decl, const_index| {
        try emitConst(allocator, &out, file, const_index, decl);
    }
    for (file.enums) |*decl| {
        try emitEnum(allocator, &out, decl);
    }
    for (file.interfaces) |*decl| {
        try emitInterface(allocator, &out, file, decl);
    }
    try emitAnnotationMetadataTable(allocator, &out, file, file.annotations, if (options.namespace != null) "    " else "");
    for (file.annotations) |*decl| {
        try emitAnnotation(allocator, &out, file, decl);
    }
    for (file.aliases, 0..) |*decl, alias_index| {
        try emitAlias(allocator, &out, file, null, alias_index, decl, "");
    }
    for (layouts.structs) |*layout| {
        try emitStruct(allocator, &out, file, layout);
    }
    if (options.namespace != null) {
        try out.appendSlice(allocator, "};\n");
    }
    return out.toOwnedSlice(allocator);
}

fn appendRawSchemaComment(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8) std.mem.Allocator.Error!void {
    try out.appendSlice(allocator, "// cpz source schema begin\n");
    var start: usize = 0;
    while (start <= source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        try out.appendSlice(allocator, "// ");
        try out.appendSlice(allocator, source[start..end]);
        try out.append(allocator, '\n');
        if (end == source.len) break;
        start = end + 1;
    }
    try out.appendSlice(allocator, "// cpz source schema end\n\n");
}

fn validateZigNameCollisions(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
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
        try validateFieldZigNames(allocator, &lhs);
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
        try validateInterfaceMethodZigNames(allocator, &lhs);
    }
    for (file.annotations, 0..) |lhs, i| {
        for (file.annotations[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

fn validateFieldZigNames(allocator: std.mem.Allocator, decl: *const Struct) LayoutError!void {
    for (decl.fields, 0..) |lhs, i| {
        for (decl.fields[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.consts) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (decl.aliases) |rhs| {
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

fn validateEnumValueZigNames(allocator: std.mem.Allocator, decl: *const EnumDecl) LayoutError!void {
    for (decl.values, 0..) |lhs, i| {
        for (decl.values[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

fn validateInterfaceMethodZigNames(allocator: std.mem.Allocator, decl: *const InterfaceDecl) LayoutError!void {
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

fn zigNamesEqual(allocator: std.mem.Allocator, lhs_raw: []const u8, rhs_raw: []const u8) std.mem.Allocator.Error!bool {
    const lhs = try zigIdentAlloc(allocator, lhs_raw);
    defer allocator.free(lhs);
    const rhs = try zigIdentAlloc(allocator, rhs_raw);
    defer allocator.free(rhs);
    return std.mem.eql(u8, lhs, rhs);
}

fn emitDeclarationAnnotations(allocator: std.mem.Allocator, out: *std.ArrayList(u8), annotations: []const u8, indent: []const u8) LayoutError!void {
    if (annotations.len == 0) return;
    const annotation_literal = try zigStringLiteralAlloc(allocator, annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.annotations": []const u8 = {s};
        \\
    , .{ indent, annotation_literal });
}

fn emitEnum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), decl: *const EnumDecl) LayoutError!void {
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
        \\
        \\pub fn @"cpz.enum.{s}.valueByMetadata"(metadata: cpz.schema.EnumValueMetadata) ?{s} {{
        \\    return @"cpz.enum.{s}.fromRaw"(metadata.ordinal);
        \\}}
        \\
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
    , .{ enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name, enum_name });
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
        const annotation_literal = try zigStringLiteralAlloc(allocator, value.annotations);
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
        const annotation_literal = try zigStringLiteralAlloc(allocator, value.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out,
            \\pub const @"cpz.enumerant.{s}.{s}.annotations": []const u8 = {s};
            \\
        , .{ enum_name_for_const, value_name, annotation_literal });
    }
    try out.append(allocator, '\n');
}

fn emitInterface(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, decl: *const InterfaceDecl) LayoutError!void {
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
        const signature_literal = try zigStringLiteralAlloc(allocator, method.signature);
        defer allocator.free(signature_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.signature": []const u8 = {s};
            \\
        , .{ method_name, signature_literal });
        const params_signature_literal = try zigStringLiteralAlloc(allocator, method.params_signature);
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
        const resolved_params_type = if (method.params_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, decl, method.params_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_params_type);
        const resolved_params_type_literal = try zigStringLiteralAlloc(allocator, resolved_params_type);
        defer allocator.free(resolved_params_type_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.resolvedParamsType": []const u8 = {s};
            \\
        , .{ method_name, resolved_params_type_literal });
        const results_signature_literal = try zigStringLiteralAlloc(allocator, method.results_signature);
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
        const resolved_results_type = if (method.results_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, decl, method.results_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_results_type);
        const resolved_results_type_literal = try zigStringLiteralAlloc(allocator, resolved_results_type);
        defer allocator.free(resolved_results_type_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.method.{s}.resolvedResultsType": []const u8 = {s};
            \\
        , .{ method_name, resolved_results_type_literal });
        const annotation_signature_literal = try zigStringLiteralAlloc(allocator, method.annotation_signature);
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
        try appendMethodFieldMetadata(allocator, out, file, decl, method_name, "params", method.param_fields, "    ");
        try appendMethodFieldMetadata(allocator, out, file, decl, method_name, "results", method.result_fields, "    ");
    }
    try appendFmt(allocator, out,
        \\}};
        \\
        \\
    , .{});
}

fn emitInterfaceSuperclassMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const InterfaceDecl, superclasses: []const Type, indent: []const u8) LayoutError!void {
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

fn appendInterfaceMethodTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const InterfaceDecl, methods: []const InterfaceMethod, indent: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.methodCount": usize = {};
        \\
    , .{ indent, methods.len });
    try appendFmt(allocator, out, "{s}pub const @\"cpz.methods\": []const cpz.schema.InterfaceMethodMetadata = &[_]cpz.schema.InterfaceMethodMetadata{{", .{indent});
    for (methods, 0..) |method, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, method.name);
        defer allocator.free(name_literal);
        const signature_literal = try zigStringLiteralAlloc(allocator, method.signature);
        defer allocator.free(signature_literal);
        const params_literal = try zigStringLiteralAlloc(allocator, method.params_signature);
        defer allocator.free(params_literal);
        const results_literal = try zigStringLiteralAlloc(allocator, method.results_signature);
        defer allocator.free(results_literal);
        const params_type_literal = try zigStringLiteralAlloc(allocator, method.params_type);
        defer allocator.free(params_type_literal);
        const results_type_literal = try zigStringLiteralAlloc(allocator, method.results_type);
        defer allocator.free(results_type_literal);
        const resolved_params_type = if (method.params_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method.params_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_params_type);
        const resolved_params_type_literal = try zigStringLiteralAlloc(allocator, resolved_params_type);
        defer allocator.free(resolved_params_type_literal);
        const resolved_results_type = if (method.results_type.len != 0) try methodFieldResolvedTypeNameAlloc(allocator, file, scope, method.results_type) else try allocator.dupe(u8, "");
        defer allocator.free(resolved_results_type);
        const resolved_results_type_literal = try zigStringLiteralAlloc(allocator, resolved_results_type);
        defer allocator.free(resolved_results_type_literal);
        const annotations_literal = try zigStringLiteralAlloc(allocator, method.annotation_signature);
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
            try appendMethodFieldListLiteral(allocator, out, file, scope, method.param_fields);
        }
        if (method.result_fields.len != 0) {
            try out.appendSlice(allocator, ", .result_fields = ");
            try appendMethodFieldListLiteral(allocator, out, file, scope, method.result_fields);
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
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    try appendFmt(allocator, out,
        \\{s}pub fn @"cpz.methodByParameter"(@"cpz.parameter": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| for (@"cpz.method".parameters) |@"cpz.methodParam"| if (std.mem.eql(u8, @"cpz.methodParam", @"cpz.parameter")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.methodByAnnotations"(@"cpz.annotationFilter": []const u8) ?cpz.schema.InterfaceMethodMetadata {{
        \\{s}    for (@"cpz.methods") |@"cpz.method"| if (std.mem.eql(u8, @"cpz.method".annotations, @"cpz.annotationFilter")) return @"cpz.method";
        \\{s}    return null;
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent });
    if (methods.len != 0) try out.append(allocator, '\n');
}

fn emitParameterMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), parameters: []const []const u8, indent: []const u8) LayoutError!void {
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

fn emitParameterLookupHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), metadata_name: []const u8, indent: []const u8) LayoutError!void {
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

fn emitParameterConstants(allocator: std.mem.Allocator, out: *std.ArrayList(u8), prefix: []const u8, parameters: []const []const u8, indent: []const u8) LayoutError!void {
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

fn appendParameterListLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), parameters: []const []const u8) LayoutError!void {
    try out.appendSlice(allocator, "&[_][]const u8{");
    for (parameters, 0..) |parameter, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const literal = try zigStringLiteralAlloc(allocator, parameter);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "}");
}

fn appendMethodParameterMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), method_name: []const u8, parameters: []const []const u8, indent: []const u8) LayoutError!void {
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

fn appendMethodFieldMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const InterfaceDecl, method_name: []const u8, kind: []const u8, fields: []const MethodField, indent: []const u8) LayoutError!void {
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
        const resolved_type_name = try methodFieldResolvedTypeNameAlloc(allocator, file, scope, field.ty);
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
            const default_literal = try zigStringLiteralAlloc(allocator, default_raw);
            defer allocator.free(default_literal);
            try appendFmt(allocator, out, "{s};\n", .{default_literal});
        } else {
            try out.appendSlice(allocator, "null;\n");
        }
        const annotations_literal = try zigStringLiteralAlloc(allocator, field.annotations);
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
        const resolved_type_name = try methodFieldResolvedTypeNameAlloc(allocator, file, scope, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        const annotations_literal = try zigStringLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        if (field.default_literal) |default_raw| {
            const default_literal = try zigStringLiteralAlloc(allocator, default_raw);
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

fn appendMethodFieldListLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const InterfaceDecl, fields: []const MethodField) LayoutError!void {
    try out.appendSlice(allocator, "&[_]cpz.schema.MethodField{");
    for (fields, 0..) |field, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const name_literal = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(name_literal);
        const type_literal = try zigStringLiteralAlloc(allocator, field.ty);
        defer allocator.free(type_literal);
        const resolved_type_name = try methodFieldResolvedTypeNameAlloc(allocator, file, scope, field.ty);
        defer allocator.free(resolved_type_name);
        const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
        defer allocator.free(resolved_type_literal);
        const annotations_literal = try zigStringLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotations_literal);
        if (field.default_literal) |default_raw| {
            const default_literal = try zigStringLiteralAlloc(allocator, default_raw);
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

fn emitMethodFieldLookupHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), metadata_name: []const u8, indent: []const u8) LayoutError!void {
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
    const by_annotations_ident = try zigStringLiteralAlloc(allocator, by_annotations);
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

fn emitAnnotation(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, decl: *const AnnotationDecl) LayoutError!void {
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

fn methodFieldResolvedTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const InterfaceDecl, raw: []const u8) LayoutError![]u8 {
    const source = try std.fmt.allocPrint(allocator, "struct T {{ f @0 :{s}; }}", .{raw});
    defer allocator.free(source);
    var parsed = try parse(allocator, source);
    defer parsed.deinit(allocator);
    if (parsed.structs.len == 0 or parsed.structs[0].fields.len == 0) return error.UnexpectedToken;
    const owner_name = if (scope) |decl| decl.name else null;
    return schemaResolvedTypeNameInOwnerScopeAlloc(allocator, file, owner_name, parsed.structs[0].fields[0].ty);
}

fn annotationOwnerName(annotation_name: []const u8) ?[]const u8 {
    const dot = lastTopLevelDot(annotation_name) orelse return null;
    return annotation_name[0..dot];
}

fn annotationTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, owner_name: ?[]const u8, ty: Type) LayoutError![]u8 {
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
            if (findEnum(file, type_name) != null or findInterface(file, type_name) != null or isStructLikeName(file, type_name)) {
                return zigTypeRefAlloc(allocator, file, type_name);
            }
            return allocator.dupe(u8, "cpz.PointerReader");
        },
        .list => |child| {
            const child_type = try annotationTypeNameAlloc(allocator, file, owner_name, child.*);
            defer allocator.free(child_type);
            return std.fmt.allocPrint(allocator, "[]const {s}", .{child_type});
        },
        .optional => |child| annotationTypeNameAlloc(allocator, file, owner_name, child.*),
    };
}

fn resolveTypeInOwnerScope(file: *const File, owner_name: ?[]const u8, ty: Type) Type {
    return switch (ty) {
        .named => |name| resolveNamedAliasInOwnerScope(file, owner_name, name, 0) orelse ty,
        else => ty,
    };
}

fn resolveNamedAliasInOwnerScope(file: *const File, owner_name: ?[]const u8, name: []const u8, depth: usize) ?Type {
    if (depth >= 32) return null;
    if (owner_name) |owner| {
        if (findStructDirect(file, owner)) |decl| {
            if (resolveNamedAliasInList(decl.aliases, file, owner_name, name, depth)) |resolved| return resolved;
        }
        if (findInterfaceDirect(file, owner)) |decl| {
            if (resolveNamedAliasInList(decl.aliases, file, owner_name, name, depth)) |resolved| return resolved;
        }
        if (lastTopLevelDot(owner)) |dot| {
            if (resolveNamedAliasInOwnerScope(file, owner[0..dot], name, depth + 1)) |resolved| return resolved;
        }
    }
    return resolveNamedAliasInList(file.aliases, file, null, name, depth);
}

fn resolveNamedAliasInList(aliases: []const AliasDecl, file: *const File, owner_name: ?[]const u8, name: []const u8, depth: usize) ?Type {
    for (aliases) |alias| {
        if (!std.mem.eql(u8, alias.name, name)) continue;
        return switch (alias.target) {
            .named => |target_name| resolveNamedAliasInOwnerScope(file, owner_name, target_name, depth + 1) orelse alias.target,
            else => alias.target,
        };
    }
    return null;
}

fn emitFileAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), annotations_raw: []const []const u8, indent: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.fileAnnotationCount": usize = {};
        \\
    , .{ indent, annotations_raw.len });
    for (annotations_raw, 0..) |annotation_raw, index| {
        const annotation_literal = try zigStringLiteralAlloc(allocator, annotation_raw);
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
        const annotation_literal = try zigStringLiteralAlloc(allocator, annotation_raw);
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

fn emitDeclarationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, indent: []const u8) LayoutError!void {
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
        try emitDeclarationMetadataConstants(allocator, out, constant_index, decl.name, "annotation_decl", decl.id, "", &.{}, indent);
        constant_index += 1;
    }
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.structCount": usize = {};
        \\{s}pub const @"cpz.enumCount": usize = {};
        \\{s}pub const @"cpz.interfaceCount": usize = {};
        \\
    , .{ indent, file.structs.len, indent, file.enums.len, indent, file.interfaces.len });
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
        try appendDeclarationMetadataLiteral(allocator, out, count, decl.name, "annotation_decl", decl.id, "", &.{});
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
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (count != 0) try out.append(allocator, '\n');
}

fn emitDeclarationMetadataConstants(
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
    const annotations_literal = try zigStringLiteralAlloc(allocator, annotations);
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

fn appendDeclarationMetadataLiteral(
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
    const annotations_literal = try zigStringLiteralAlloc(allocator, annotations);
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

fn emitImportMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), imports: []const ImportDecl, indent: []const u8) LayoutError!void {
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
        \\{s}pub fn @"cpz.importByMemberFlag"(@"cpz.hasMember": bool) ?cpz.schema.ImportMetadata {{
        \\{s}    for (@This().@"cpz.imports") |@"cpz.import"| if (@"cpz.import".has_member == @"cpz.hasMember") return @"cpz.import";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.importByIndex"(@"cpz.index": usize) ?cpz.schema.ImportMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.imports".len) return null;
        \\{s}    return @This().@"cpz.imports"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (imports.len != 0) try out.append(allocator, '\n');
}

fn emitAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, annotations: []const AnnotationDecl, indent: []const u8) LayoutError!void {
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

fn emitScopedAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, indent: []const u8) LayoutError!void {
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

fn emitAnnotationLookupHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8) LayoutError!void {
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
        \\{s}pub fn @"cpz.annotationByTarget"(@"cpz.target": []const u8) ?cpz.schema.AnnotationMetadata {{
        \\{s}    for (@This().@"cpz.annotation_decls") |@"cpz.annotation"| if (cpz.schema.annotationTargetsHas(@"cpz.annotation".targets, @"cpz.target")) return @"cpz.annotation";
        \\{s}    return null;
        \\{s}}}
        \\
        \\{s}pub fn @"cpz.annotationByIndex"(@"cpz.index": usize) ?cpz.schema.AnnotationMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.annotation_decls".len) return null;
        \\{s}    return @This().@"cpz.annotation_decls"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
}

fn emitAnnotationMetadataConstants(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, index: usize, decl: *const AnnotationDecl, indent: []const u8) LayoutError!void {
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
        \\{s}pub const @"cpz.annotationDecl.{s}.targetCount": usize = {};
        \\{s}pub const @"cpz.annotationDecl.{s}.targets": cpz.schema.AnnotationTargets = 
    , .{ indent, annotation_name, index, indent, annotation_name, type_literal, indent, annotation_name, resolved_type_literal, indent, annotation_name, annotationTargetCount(decl.targets), indent, annotation_name });
    try appendAnnotationTargetsLiteral(allocator, out, decl.targets);
    try out.appendSlice(allocator, ";\n\n");
}

fn appendAnnotationMetadataLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, index: usize, decl: *const AnnotationDecl) LayoutError!void {
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
    try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, ", .{ index, name_literal });
    if (decl.id) |id| try appendFmt(allocator, out, ".id = 0x{x}, ", .{id});
    try appendFmt(allocator, out, ".ty = {s}, .resolved_ty = {s}, .target_count = {}, .targets = ", .{ type_literal, resolved_type_literal, annotationTargetCount(decl.targets) });
    try appendAnnotationTargetsLiteral(allocator, out, decl.targets);
    try out.appendSlice(allocator, " }");
}

fn annotationTargetCount(targets: AnnotationTargets) usize {
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

fn appendAnnotationTargetsLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), targets: AnnotationTargets) std.mem.Allocator.Error!void {
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

fn emitAliasMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, aliases: []const AliasDecl, indent: []const u8) LayoutError!void {
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

fn emitConstMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, consts: []const ConstDecl, indent: []const u8) LayoutError!void {
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
        \\{s}pub fn @"cpz.constByIndex"(@"cpz.index": usize) ?cpz.schema.ConstMetadata {{
        \\{s}    if (@"cpz.index" >= @This().@"cpz.consts".len) return null;
        \\{s}    return @This().@"cpz.consts"[@"cpz.index"];
        \\{s}}}
        \\
    , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    if (consts.len != 0) try out.append(allocator, '\n');
}

fn appendConstMetadataLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const ConstDecl) LayoutError!void {
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
    const annotations_literal = try zigStringLiteralAlloc(allocator, decl.annotations);
    defer allocator.free(annotations_literal);
    try appendFmt(allocator, out, ".{{ .index = {}, .name = {s}, .ty = {s}, .resolved_ty = {s}", .{ index, name_literal, type_literal, resolved_type_literal });
    if (decl.literal.len != 0) {
        try appendFmt(allocator, out, ", .literal = {s}", .{value_literal});
    }
    if (decl.is_hex_data) {
        try out.appendSlice(allocator, ", .is_hex_data = true");
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
    try out.appendSlice(allocator, " }");
}

fn appendConstListItemsLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), items: []const ConstListItem) LayoutError!void {
    try out.appendSlice(allocator, "&[_]cpz.schema.ConstListItem{");
    for (items, 0..) |item, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        const literal = try zigStringLiteralAlloc(allocator, item.literal);
        defer allocator.free(literal);
        const annotations = try zigStringLiteralAlloc(allocator, item.annotations);
        defer allocator.free(annotations);
        try appendFmt(allocator, out, ".{{ .index = {}, .literal = {s}", .{ item.index, literal });
        if (item.is_hex_data) {
            try out.appendSlice(allocator, ", .is_hex_data = true");
        }
        if (item.annotations.len != 0) {
            try appendFmt(allocator, out, ", .annotations = {s}", .{annotations});
        }
        try out.appendSlice(allocator, " }");
    }
    try out.appendSlice(allocator, "}");
}

fn emitAlias(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const AliasDecl, indent: []const u8) LayoutError!void {
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

fn aliasLine(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, alias_name: []const u8, value: []const u8) std.mem.Allocator.Error!void {
    return appendFmt(allocator, out, "{s}pub const {s} = {s};\n\n", .{ indent, alias_name, value });
}

fn emitAliasTarget(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, alias_name: []const u8, target: Type) LayoutError!void {
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
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try aliasLine(allocator, out, indent, alias_name, zig_type);
        },
        .list => |child| switch (resolveTypeScoped(file, scope, child.*)) {
            .void => try aliasLine(allocator, out, indent, alias_name, "[]const void"),
            .bool => try aliasLine(allocator, out, indent, alias_name, "[]const bool"),
            .uint8 => try aliasLine(allocator, out, indent, alias_name, "[]const u8"),
            .uint16 => try aliasLine(allocator, out, indent, alias_name, "[]const u16"),
            .uint32 => try aliasLine(allocator, out, indent, alias_name, "[]const u32"),
            .uint64 => try aliasLine(allocator, out, indent, alias_name, "[]const u64"),
            .int8 => try aliasLine(allocator, out, indent, alias_name, "[]const i8"),
            .int16 => try aliasLine(allocator, out, indent, alias_name, "[]const i16"),
            .int32 => try aliasLine(allocator, out, indent, alias_name, "[]const i32"),
            .int64 => try aliasLine(allocator, out, indent, alias_name, "[]const i64"),
            .float32 => try aliasLine(allocator, out, indent, alias_name, "[]const f32"),
            .float64 => try aliasLine(allocator, out, indent, alias_name, "[]const f64"),
            .text, .data => try aliasLine(allocator, out, indent, alias_name, "[]const []const u8"),
            .named => |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                const list_type = try std.fmt.allocPrint(allocator, "[]const {s}", .{zig_type});
                defer allocator.free(list_type);
                try aliasLine(allocator, out, indent, alias_name, list_type);
            },
            .any_pointer, .any_struct, .any_list, .capability, .list, .optional => {},
        },
        .optional => |child| try emitAliasTarget(allocator, out, file, scope, indent, alias_name, child.*),
    }
}

fn emitConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, index: usize, decl: *const ConstDecl) LayoutError!void {
    return emitConstWithIndent(allocator, out, file, null, index, decl, "");
}

fn emitNestedConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const ConstDecl) LayoutError!void {
    return emitConstWithIndent(allocator, out, file, scope, index, decl, "    ");
}

fn emitConstWithIndent(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, index: usize, decl: *const ConstDecl, indent: []const u8) LayoutError!void {
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
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.const.{s}.index": usize = {};
        \\{s}pub const @"cpz.const.{s}.name": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.metadata": cpz.schema.ConstMetadata = @This().@"cpz.consts"[{}];
        \\{s}pub const @"cpz.const.{s}.type": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.resolvedType": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.literal": []const u8 = {s};
        \\{s}pub const @"cpz.const.{s}.isHexData": bool = {};
        \\{s}pub const @"cpz.const.{s}.emitted": bool = {};
        \\{s}pub const @"cpz.const.{s}.listItemCount": usize = {};
        \\{s}pub const @"cpz.const.{s}.listItems": []const cpz.schema.ConstListItem = 
    , .{ indent, const_name, index, indent, const_name, name_literal, indent, const_name, index, indent, const_name, type_literal, indent, const_name, resolved_type_literal, indent, const_name, literal_value, indent, const_name, decl.is_hex_data, indent, const_name, decl.emit_value, indent, const_name, if (decl.list_items) |items| items.len else 0, indent, const_name });
    if (decl.list_items) |items| {
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
    if (decl.list_items) |items| {
        for (items) |item| {
            const item_literal = try zigStringLiteralAlloc(allocator, item.literal);
            defer allocator.free(item_literal);
            const item_annotations = try zigStringLiteralAlloc(allocator, item.annotations);
            defer allocator.free(item_annotations);
            try appendFmt(allocator, out,
                \\{s}pub const @"cpz.const.{s}.listItem.{}.index": usize = {};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.metadata": cpz.schema.ConstListItem = @This().@"cpz.const.{s}.listItems"[{}];
                \\{s}pub const @"cpz.const.{s}.listItem.{}.literal": []const u8 = {s};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.isHexData": bool = {};
                \\{s}pub const @"cpz.const.{s}.listItem.{}.annotations": []const u8 = {s};
                \\
            , .{ indent, const_name, item.index, item.index, indent, const_name, item.index, const_name, item.index, indent, const_name, item.index, item_literal, indent, const_name, item.index, item.is_hex_data, indent, const_name, item.index, item_annotations });
        }
    }
    try out.appendSlice(allocator,
        \\
    );
    const annotation_literal = try zigStringLiteralAlloc(allocator, decl.annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out,
        \\{s}pub const @"cpz.const.{s}.annotations": []const u8 = {s};
        \\
    , .{ indent, const_name, annotation_literal });
    if (!decl.emit_value) return;
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
        , .{ indent, const_name, try boolConstLiteral(decl.literal) }),
        .int8 => try emitNumericConst(allocator, out, indent, const_name, "i8", decl.literal),
        .int16 => try emitNumericConst(allocator, out, indent, const_name, "i16", decl.literal),
        .int32 => try emitNumericConst(allocator, out, indent, const_name, "i32", decl.literal),
        .int64 => try emitNumericConst(allocator, out, indent, const_name, "i64", decl.literal),
        .uint8 => try emitNumericConst(allocator, out, indent, const_name, "u8", decl.literal),
        .uint16 => try emitNumericConst(allocator, out, indent, const_name, "u16", decl.literal),
        .uint32 => try emitNumericConst(allocator, out, indent, const_name, "u32", decl.literal),
        .uint64 => try emitNumericConst(allocator, out, indent, const_name, "u64", decl.literal),
        .float32 => try emitNumericConst(allocator, out, indent, const_name, "f32", floatConstLiteral(decl.literal, "f32")),
        .float64 => try emitNumericConst(allocator, out, indent, const_name, "f64", floatConstLiteral(decl.literal, "f64")),
        .text => {
            const literal = try zigStringLiteralAlloc(allocator, decl.literal);
            defer allocator.free(literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: []const u8 = {s};
                \\
                \\
            , .{ indent, const_name, literal });
        },
        .data => {
            const literal = try zigDataLiteralAlloc(allocator, decl.literal, decl.is_hex_data);
            defer allocator.free(literal);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: []const u8 = {s};
                \\
                \\
            , .{ indent, const_name, literal });
        },
        .named => |type_name| {
            if (decl.list_items) |items| {
                const resolved = resolveNamedAlias(file, scope, type_name, 0) orelse return;
                if (resolved != .list) return;
                try emitListConst(allocator, out, file, scope, indent, const_name, resolved.list.*, items);
            } else {
                const enum_decl = findEnum(file, type_name) orelse return;
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\{s}pub const {s}: {s} = @enumFromInt({});
                    \\
                    \\
                , .{ indent, const_name, zig_type, try enumDefaultOrdinal(enum_decl, decl.literal) });
            }
        },
        .list => |child| {
            const items = decl.list_items orelse return;
            try emitListConst(allocator, out, file, scope, indent, const_name, child.*, items);
        },
        else => return,
    }
}

fn emitNumericConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, name: []const u8, zig_type: []const u8, literal: []const u8) std.mem.Allocator.Error!void {
    try appendFmt(allocator, out,
        \\{s}pub const {s}: {s} = {s};
        \\
        \\
    , .{ indent, name, zig_type, if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal });
}

fn emitListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, child: Type, items: []const ConstListItem) LayoutError!void {
    switch (resolveTypeScoped(file, scope, child)) {
        .void => try emitListConstOfType(allocator, out, indent, name, "void", items, voidConstItem),
        .bool => try emitListConstOfType(allocator, out, indent, name, "bool", items, boolConstItem),
        .int8 => try emitListConstOfType(allocator, out, indent, name, "i8", items, numericConstItem),
        .int16 => try emitListConstOfType(allocator, out, indent, name, "i16", items, numericConstItem),
        .int32 => try emitListConstOfType(allocator, out, indent, name, "i32", items, numericConstItem),
        .int64 => try emitListConstOfType(allocator, out, indent, name, "i64", items, numericConstItem),
        .uint8 => try emitListConstOfType(allocator, out, indent, name, "u8", items, numericConstItem),
        .uint16 => try emitListConstOfType(allocator, out, indent, name, "u16", items, numericConstItem),
        .uint32 => try emitListConstOfType(allocator, out, indent, name, "u32", items, numericConstItem),
        .uint64 => try emitListConstOfType(allocator, out, indent, name, "u64", items, numericConstItem),
        .float32 => try emitListConstOfType(allocator, out, indent, name, "f32", items, float32ConstItem),
        .float64 => try emitListConstOfType(allocator, out, indent, name, "f64", items, float64ConstItem),
        .text => try emitListConstOfType(allocator, out, indent, name, "[]const u8", items, stringConstItem),
        .data => try emitListConstOfType(allocator, out, indent, name, "[]const u8", items, dataConstItem),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\{s}pub const {s}: []const {s} = &[_]{s}{{
            , .{ indent, name, zig_type, zig_type });
            for (items, 0..) |item, i| {
                if (i != 0) try out.appendSlice(allocator, ", ");
                try appendFmt(allocator, out, "@enumFromInt({})", .{try enumDefaultOrdinal(enum_decl, item.literal)});
            }
            try out.appendSlice(allocator, "};\n\n");
        },
        else => return,
    }
}

fn emitListConstOfType(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    zig_type: []const u8,
    items: []const ConstListItem,
    comptime itemLiteral: fn (std.mem.Allocator, ConstListItem) LayoutError![]const u8,
) LayoutError!void {
    try appendFmt(allocator, out,
        \\{s}pub const {s}: []const {s} = &[_]{s}{{
    , .{ indent, name, zig_type, zig_type });
    for (items, 0..) |item, i| {
        if (i != 0) try out.appendSlice(allocator, ", ");
        const literal = try itemLiteral(allocator, item);
        defer allocator.free(literal);
        try out.appendSlice(allocator, literal);
    }
    try out.appendSlice(allocator, "};\n\n");
}

fn voidConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    if (!std.mem.eql(u8, item.literal, "void")) return error.InvalidToken;
    return allocator.dupe(u8, "{}");
}

fn boolConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return allocator.dupe(u8, try boolConstLiteral(item.literal));
}

fn numericConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    const literal = if (std.mem.startsWith(u8, item.literal, "+")) item.literal[1..] else item.literal;
    return allocator.dupe(u8, literal);
}

fn float32ConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return allocator.dupe(u8, floatConstLiteral(item.literal, "f32"));
}

fn float64ConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return allocator.dupe(u8, floatConstLiteral(item.literal, "f64"));
}

fn stringConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return zigStringLiteralAlloc(allocator, item.literal);
}

fn dataConstItem(allocator: std.mem.Allocator, item: ConstListItem) LayoutError![]const u8 {
    return zigDataLiteralAlloc(allocator, item.literal, item.is_hex_data);
}

fn emitStructUnionMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    try appendFmt(allocator, out,
        \\    pub const @"cpz.unionCount": usize = {};
        \\
    , .{layout.unions.len});
    for (layout.unions, 0..) |union_layout, index| {
        const field_count = unionFieldCount(layout, @intCast(index));
        try appendFmt(allocator, out,
            \\    pub const @"cpz.union.{}.index": u32 = {};
            \\    pub const @"cpz.union.{}.discriminantByte": usize = {};
            \\    pub const @"cpz.union.{}.dataBit": usize = {};
            \\    pub const @"cpz.union.{}.dataBits": usize = {};
            \\    pub const @"cpz.union.{}.fieldCount": usize = {};
            \\    pub const @"cpz.union.{}.pointer": ?usize = 
        , .{ index, index, index, union_layout.discriminant_byte, index, union_layout.data_bit, index, union_layout.data_bits, index, field_count, index });
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
            \\    pub fn @"cpz.union.{}.fieldByExplicitDefault"(@"cpz.hasDefault": bool) ?cpz.schema.FieldMetadata {{
            \\        for (@This().@"cpz.union.{}.fields") |@"cpz.field"| if (@"cpz.field".has_explicit_default == @"cpz.hasDefault") return @"cpz.field";
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
        , .{ index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index, index });
    }
    try out.appendSlice(allocator, "    pub const @\"cpz.unions\": []const cpz.schema.UnionMetadata = &[_]cpz.schema.UnionMetadata{");
    for (layout.unions, 0..) |union_layout, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        try appendFmt(allocator, out, ".{{ .index = {}, .discriminant_byte = {}, .field_count = {}, .fields = ", .{ index, union_layout.discriminant_byte, unionFieldCount(layout, @intCast(index)) });
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
        \\    pub fn @"cpz.unionByIndex"(@"cpz.index": u32) ?cpz.schema.UnionMetadata {
        \\        for (@This().@"cpz.unions") |@"cpz.union"| if (@"cpz.union".index == @"cpz.index") return @"cpz.union";
        \\        return null;
        \\    }
        \\
    );
}

fn appendUnionFieldMetadataLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, union_index: u32) LayoutError!void {
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
        const default_literal = try zigStringLiteralAlloc(allocator, field.default_expression);
        defer allocator.free(default_literal);
        const annotations_literal = try zigStringLiteralAlloc(allocator, field.annotations);
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

fn unionFieldCount(layout: *const StructLayout, union_index: u32) usize {
    var count: usize = 0;
    for (layout.fields) |field_layout| {
        if (field_layout.field.union_index) |current| {
            if (current == union_index) count += 1;
        }
    }
    return count;
}

fn emitStructFieldMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
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
        const default_literal = try zigStringLiteralAlloc(allocator, field.default_expression);
        defer allocator.free(default_literal);
        const annotations_literal = try zigStringLiteralAlloc(allocator, field.annotations);
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

fn fieldSlotMetadata(slot: FieldSlot) struct { name: []const u8, offset: usize } {
    return switch (slot) {
        .void => .{ .name = "void", .offset = 0 },
        .data_bit => |bit| .{ .name = "data_bit", .offset = bit },
        .data_byte => |byte| .{ .name = "data_byte", .offset = byte },
        .pointer => |index| .{ .name = "pointer", .offset = index },
    };
}

fn fieldIndex(layout: *const StructLayout, target: *const Field) usize {
    for (layout.fields, 0..) |field_layout, index| {
        if (field_layout.field == target) return index;
    }
    unreachable;
}

fn emitStruct(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    const struct_name = try zigIdentAlloc(allocator, layout.decl.name);
    defer allocator.free(struct_name);
    try appendFmt(allocator, out,
        \\pub const {s} = struct {{
        \\    pub const size: cpz.StructSize = .{{ .data_words = {}, .pointer_count = {} }};
        \\    pub const @"cpz.dataWordCount": u16 = {};
        \\    pub const @"cpz.pointerCount": u16 = {};
        \\    pub const @"cpz.structSize": cpz.StructSize = size;
        \\
    , .{ struct_name, layout.data_words, layout.pointer_count, layout.data_words, layout.pointer_count });
    if (layout.decl.id) |id| {
        try appendFmt(allocator, out,
            \\    pub const @"cpz.type_id": u64 = 0x{x};
            \\
        , .{id});
    }
    try emitDeclarationAnnotations(allocator, out, layout.decl.annotations, "    ");
    try emitParameterMetadata(allocator, out, layout.decl.parameters, "    ");

    for (layout.decl.aliases, 0..) |*decl, alias_index| {
        try emitAlias(allocator, out, file, layout.decl, alias_index, decl, "    ");
    }
    try emitAliasMetadataTable(allocator, out, file, layout.decl, layout.decl.aliases, "    ");

    for (layout.decl.consts, 0..) |*decl, const_index| {
        try emitNestedConst(allocator, out, file, layout.decl, const_index, decl);
    }

    try emitConstMetadataTable(allocator, out, file, layout.decl, layout.decl.consts, "    ");
    try emitScopedAnnotationMetadataTable(allocator, out, file, layout.decl.name, "    ");
    try emitStructUnionMetadata(allocator, out, file, layout);
    try emitStructFieldMetadata(allocator, out, file, layout);

    try appendFmt(allocator, out,
        \\    pub const Orphan = struct {{
        \\        orphan: cpz.Orphan,
        \\
        \\        pub fn fromOrphan(orphan: cpz.Orphan) Orphan {{
        \\            return .{{ .orphan = orphan }};
        \\        }}
        \\
        \\        pub fn fromRaw(orphan: cpz.Orphan) Orphan {{
        \\            return fromOrphan(orphan);
        \\        }}
        \\
        \\        pub fn raw(self: @This()) cpz.Word {{
        \\            return self.orphan.raw;
        \\        }}
        \\
        \\        pub fn isNull(self: @This()) bool {{
        \\            return self.orphan.isNull();
        \\        }}
        \\
        \\        pub fn pointerType(self: @This()) ?cpz.wire.PointerType {{
        \\            return self.orphan.pointerType();
        \\        }}
        \\
        \\        pub fn decode(self: @This(), message_reader: *cpz.MessageReader) !?cpz.wire.DecodedPointer {{
        \\            return self.orphan.decode(message_reader);
        \\        }}
        \\
        \\        pub fn asPointerReader(self: @This(), message_reader: *cpz.MessageReader) cpz.PointerReader {{
        \\            return self.orphan.asReader(message_reader);
        \\        }}
        \\
        \\        pub fn get(self: @This()) !Builder {{
        \\            return Builder.fromBuilder(try self.orphan.getStruct());
        \\        }}
        \\
        \\        pub fn getReader(self: @This(), message_reader: *cpz.MessageReader) !{s} {{
        \\            return {s}.fromReader(try self.orphan.asReader(message_reader).getStruct(null));
        \\        }}
        \\
        \\        pub fn asReader(self: @This(), message_reader: *cpz.MessageReader) !{s} {{
        \\            return self.getReader(message_reader);
        \\        }}
        \\
        \\        pub fn validate(self: @This()) !cpz.MessageStats {{
        \\            return self.orphan.validate();
        \\        }}
        \\
        \\        pub fn validateWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.orphan.validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.orphan.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.orphan.totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn release(self: *@This()) void {{
        \\            self.orphan.release();
        \\        }}
        \\    }};
        \\
        \\    reader: cpz.StructReader,
        \\
        \\    pub fn initRoot(@"cpz.builder": *cpz.MessageBuilder) !cpz.StructBuilder {{
        \\        return @"cpz.builder".initRoot(size);
        \\    }}
        \\
        \\    pub fn getRoot(@"cpz.reader": *cpz.MessageReader) !{s} {{
        \\        return fromReader(try @"cpz.reader".getRoot());
        \\    }}
        \\
        \\    pub fn getRootTyped(@"cpz.builder": *cpz.MessageBuilder) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.builder".getRoot());
        \\    }}
        \\
        \\    pub fn @"cpz.root.isNull"(@"cpz.root": anytype) !bool {{
        \\        return @"cpz.root".isRootNull();
        \\    }}
        \\
        \\    pub fn @"cpz.root.clear"(@"cpz.builder": *cpz.MessageBuilder) !void {{
        \\        return @"cpz.builder".clearRoot();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerKind"(@"cpz.reader": *cpz.MessageReader) !?cpz.wire.PointerType {{
        \\        return @"cpz.reader".getRootPointerKind();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointer"(@"cpz.reader": *cpz.MessageReader) !cpz.PointerReader {{
        \\        return @"cpz.reader".getRootPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsNull"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return (try @"cpz.reader".getRootPointer()).isNull();
        \\    }}
        \\
        \\    pub fn @"cpz.root.rawPointer"(@"cpz.reader": *cpz.MessageReader) !cpz.Word {{
        \\        return @"cpz.reader".getRootRawPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.decodedPointer"(@"cpz.reader": *cpz.MessageReader) !?cpz.wire.DecodedPointer {{
        \\        return @"cpz.reader".getRootDecodedPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.stats"(@"cpz.reader": *cpz.MessageReader) !cpz.MessageStats {{
        \\        return @"cpz.reader".getRootPointerStats();
        \\    }}
        \\
        \\    pub fn @"cpz.root.statsWithOptions"(@"cpz.reader": *cpz.MessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return @"cpz.reader".getRootPointerStatsWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.totalSize"(@"cpz.reader": *cpz.MessageReader) !cpz.MessageSize {{
        \\        return @"cpz.reader".getRootPointerTotalSize();
        \\    }}
        \\
        \\    pub fn @"cpz.root.totalSizeWithOptions"(@"cpz.reader": *cpz.MessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return @"cpz.reader".getRootPointerTotalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.segments"(@"cpz.reader": *cpz.MessageReader) []const cpz.serialize.ConstSegment {{
        \\        return @"cpz.reader".segments;
        \\    }}
        \\
        \\    pub fn @"cpz.root.segmentCount"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".segmentCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.segmentBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.index": usize) !cpz.serialize.ConstSegment {{
        \\        return @"cpz.reader".segmentBytes(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.root.segmentByteLen"(@"cpz.reader": *cpz.MessageReader, @"cpz.index": usize) !usize {{
        \\        return @"cpz.reader".segmentByteLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.root.segmentWordLen"(@"cpz.reader": *cpz.MessageReader, @"cpz.index": usize) !usize {{
        \\        return @"cpz.reader".segmentWordLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.root.serializedSize"(@"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return @"cpz.reader".serializedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.root.serializedSizeInWords"(@"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return @"cpz.reader".serializedSizeInWords();
        \\    }}
        \\
        \\    pub fn @"cpz.root.segmentTable"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) ![]u8 {{
        \\        return @"cpz.reader".serializeSegmentTable(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.root.toFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) ![]u8 {{
        \\        return @"cpz.reader".toFlatBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.root.toPackedBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) ![]u8 {{
        \\        return @"cpz.reader".toPackedBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.root.writeToWriter"(@"cpz.reader": *cpz.MessageReader, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.reader".writeToWriter(@"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.root.writePackedToWriter"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.reader".writePackedToWriter(@"cpz.allocator", @"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.root.traversalLimitWords"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".traversalLimitWords();
        \\    }}
        \\
        \\    pub fn @"cpz.root.traversalRemainingWords"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".traversalRemainingWords();
        \\    }}
        \\
        \\    pub fn @"cpz.root.nestingLimit"(@"cpz.reader": *cpz.MessageReader) u16 {{
        \\        return @"cpz.reader".nestingLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.root.capabilityCountLimit"(@"cpz.reader": *cpz.MessageReader) ?usize {{
        \\        return @"cpz.reader".capabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.root.validate"(@"cpz.reader": *cpz.MessageReader) !cpz.MessageStats {{
        \\        return @"cpz.reader".validate();
        \\    }}
        \\
        \\    pub fn @"cpz.root.validateWithOptions"(@"cpz.reader": *cpz.MessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return @"cpz.reader".validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.messageTotalSizeWithOptions"(@"cpz.reader": *cpz.MessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return @"cpz.reader".totalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.toCanonicalSegmentBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) ![]u8 {{
        \\        return @"cpz.reader".toCanonicalSegmentBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.root.toSingleSegmentFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) ![]u8 {{
        \\        return @"cpz.reader".toSingleSegmentFlatBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerKind"(@"cpz.builder": *cpz.MessageBuilder) !?cpz.wire.PointerType {{
        \\        return @"cpz.builder".getRootPointerKind();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointer"(@"cpz.builder": *cpz.MessageBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".getRootPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsNull"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return (try @"cpz.builder".getRootPointer()).isNull();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.rawPointer"(@"cpz.builder": *cpz.MessageBuilder) !cpz.Word {{
        \\        return @"cpz.builder".getRootRawPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.decodedPointer"(@"cpz.builder": *cpz.MessageBuilder) !?cpz.wire.DecodedPointer {{
        \\        return @"cpz.builder".getRootDecodedPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.stats"(@"cpz.builder": *cpz.MessageBuilder) !cpz.MessageStats {{
        \\        return @"cpz.builder".getRootPointerStats();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.statsWithOptions"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return @"cpz.builder".getRootPointerStatsWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.totalSize"(@"cpz.builder": *cpz.MessageBuilder) !cpz.MessageSize {{
        \\        return @"cpz.builder".getRootPointerTotalSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.totalSizeWithOptions"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return @"cpz.builder".getRootPointerTotalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.asMessageReader"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageReader {{
        \\        return @"cpz.builder".asReader(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.firstSegmentWords"(@"cpz.builder": *cpz.MessageBuilder) usize {{
        \\        return @"cpz.builder".firstSegmentWords();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.nextSegmentMinWords"(@"cpz.builder": *cpz.MessageBuilder) usize {{
        \\        return @"cpz.builder".nextSegmentMinWords();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segments"(@"cpz.builder": *cpz.MessageBuilder) ![]const cpz.serialize.ConstSegment {{
        \\        return @"cpz.builder".segmentsConst();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentCount"(@"cpz.builder": *cpz.MessageBuilder) usize {{
        \\        return @"cpz.builder".segmentCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !cpz.serialize.ConstSegment {{
        \\        return @"cpz.builder".segmentBytes(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentByteLen"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !usize {{
        \\        return @"cpz.builder".segmentByteLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentWordLen"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !usize {{
        \\        return @"cpz.builder".segmentWordLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentCapacityWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !usize {{
        \\        return @"cpz.builder".segmentCapacityWords(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentRemainingWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !usize {{
        \\        return @"cpz.builder".segmentRemainingWords(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentCapacityBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !usize {{
        \\        return @"cpz.builder".segmentCapacityBytes(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentRemainingBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.index": usize) !usize {{
        \\        return @"cpz.builder".segmentRemainingBytes(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.serializedSize"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return @"cpz.builder".serializedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.serializedSizeInWords"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return @"cpz.builder".serializedSizeInWords();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.segmentTable"(@"cpz.builder": *cpz.MessageBuilder) ![]u8 {{
        \\        return @"cpz.builder".serializeSegmentTable();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.validate"(@"cpz.builder": *cpz.MessageBuilder) !cpz.MessageStats {{
        \\        return @"cpz.builder".validate(.{{}});
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.validateWithOptions"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return @"cpz.builder".validate(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toFlatBytes"(@"cpz.builder": *cpz.MessageBuilder) ![]u8 {{
        \\        return @"cpz.builder".toFlatBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toPackedBytes"(@"cpz.builder": *cpz.MessageBuilder) ![]u8 {{
        \\        return @"cpz.builder".toPackedBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.writeToWriter"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.builder".writeToWriter(@"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.writePackedToWriter"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.builder".writePackedToWriter(@"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toCanonicalSegmentBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) ![]u8 {{
        \\        return @"cpz.builder".toCanonicalSegmentBytes(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toSingleSegmentFlatBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) ![]u8 {{
        \\        return @"cpz.builder".toSingleSegmentFlatBytes(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.list"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !cpz.ListReader {{
        \\        return @"cpz.reader".getRootList(@"cpz.elementSize");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.initList"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
        \\        return @"cpz.builder".initRootList(@"cpz.elementSize", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.initStructList"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize, @"cpz.elementStructSize": cpz.StructSize) !cpz.ListBuilder {{
        \\        return @"cpz.builder".initRootStructList(@"cpz.count", @"cpz.elementStructSize");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.list"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !cpz.ListBuilder {{
        \\        return @"cpz.builder".getRootList(@"cpz.elementSize");
        \\    }}
        \\
        \\    pub fn @"cpz.root.text"(@"cpz.reader": *cpz.MessageReader) ![]const u8 {{
        \\        return @"cpz.reader".getRootText();
        \\    }}
        \\
        \\    pub fn @"cpz.root.data"(@"cpz.reader": *cpz.MessageReader) ![]const u8 {{
        \\        return @"cpz.reader".getRootData();
        \\    }}
        \\
        \\    pub fn @"cpz.root.capability"(@"cpz.reader": *cpz.MessageReader) !u32 {{
        \\        return @"cpz.reader".getRootCapability();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.setText"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": []const u8) !void {{
        \\        return @"cpz.builder".setRootText(@"cpz.value");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.text"(@"cpz.builder": *cpz.MessageBuilder) ![]const u8 {{
        \\        return @"cpz.builder".getRootText();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.setData"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": []const u8) !void {{
        \\        return @"cpz.builder".setRootData(@"cpz.value");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.data"(@"cpz.builder": *cpz.MessageBuilder) ![]const u8 {{
        \\        return @"cpz.builder".getRootData();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.setCapability"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": u32) !void {{
        \\        return @"cpz.builder".setRootCapability(@"cpz.value");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.capability"(@"cpz.builder": *cpz.MessageBuilder) !u32 {{
        \\        return @"cpz.builder".getRootCapability();
        \\    }}
        \\
        \\    pub fn @"cpz.root.disown"(@"cpz.builder": *cpz.MessageBuilder) !cpz.Orphan {{
        \\        return @"cpz.builder".disownRoot();
        \\    }}
        \\
        \\    pub fn @"cpz.root.adopt"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.orphan": *cpz.Orphan) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".adoptRoot(@"cpz.orphan");
        \\    }}
        \\
        \\    pub fn @"cpz.root.disownTyped"(@"cpz.builder": *cpz.MessageBuilder) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.builder".disownRoot());
        \\    }}
        \\
        \\    pub fn @"cpz.root.adoptTyped"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.orphan": *Orphan) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".adoptRoot(&@"cpz.orphan".orphan);
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": *cpz.MessageReader) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.builder".copyRootFrom(@"cpz.source"));
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyPointerFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": cpz.PointerReader) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".copyRootPointerFrom(@"cpz.source");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": *cpz.MessageReader) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.builder".copyRootCanonicalFrom(@"cpz.source"));
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyPointerCanonicalFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": cpz.PointerReader) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".copyRootPointerCanonicalFrom(@"cpz.source");
        \\    }}
        \\
        \\    pub fn newOrphan(@"cpz.builder": *cpz.MessageBuilder) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.builder".newOrphanStruct(size));
        \\    }}
        \\
        \\    pub fn newOrphanIn(@"cpz.orphanage": cpz.Orphanage) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.orphanage".newStruct(size));
        \\    }}
        \\
        \\    pub fn newOrphanCopy(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.builder".newOrphanCopyStruct(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn newOrphanCopyIn(@"cpz.orphanage": cpz.Orphanage, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.orphanage".newCopyStruct(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn fromReader(@"cpz.reader": cpz.StructReader) {s} {{
        \\        return .{{ .reader = @"cpz.reader" }};
        \\    }}
        \\
        \\    pub fn validate(self: @This()) !cpz.MessageStats {{
        \\        return self.reader.validate();
        \\    }}
        \\
        \\    pub fn validateWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return self.reader.validateWithOptions(options);
        \\    }}
        \\
        \\    pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\        return self.reader.totalSize();
        \\    }}
        \\
        \\    pub fn totalSizeWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return self.reader.totalSizeWithOptions(options);
        \\    }}
        \\
        \\    pub fn actualSize(self: @This()) cpz.StructSize {{
        \\        return self.reader.size();
        \\    }}
        \\
        \\    pub fn dataSection(self: @This()) []const u8 {{
        \\        return self.reader.dataSectionBytes();
        \\    }}
        \\
        \\    pub fn pointerSection(self: @This()) cpz.ListReader {{
        \\        return self.reader.pointerSectionAsList();
        \\    }}
        \\
    , .{ struct_name, struct_name, struct_name, struct_name, struct_name });

    try emitUnionDeclarations(allocator, out, layout);

    for (layout.fields) |field_layout| {
        try emitFieldGetter(allocator, out, file, layout, struct_name, field_layout);
    }
    for (layout.fields) |field_layout| {
        if (resolveTypeScoped(file, layout.decl, field_layout.field.ty) == .list) {
            try emitListWrapper(allocator, out, file, layout.decl, struct_name, field_layout.field);
        }
    }

    try appendFmt(allocator, out,
        \\
        \\    pub fn initRootTyped(@"cpz.message": *cpz.MessageBuilder) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.message".initRoot(size));
        \\    }}
        \\
        \\    pub const Builder = struct {{
        \\        builder: cpz.StructBuilder,
        \\
        \\        pub fn fromBuilder(@"cpz.builder": cpz.StructBuilder) Builder {{
        \\            return .{{ .builder = @"cpz.builder" }};
        \\        }}
        \\
        \\        pub fn asReader(self: Builder, message_reader: *cpz.MessageReader) {s} {{
        \\            return {s}.fromReader(self.builder.asReader(message_reader));
        \\        }}
        \\
        \\        pub fn validate(self: Builder) !cpz.MessageStats {{
        \\            return self.builder.validate();
        \\        }}
        \\
        \\        pub fn validateWithOptions(self: Builder, options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.builder.validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn totalSize(self: Builder) !cpz.MessageSize {{
        \\            return self.builder.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: Builder, options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.builder.totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn actualSize(self: Builder) cpz.StructSize {{
        \\            return self.builder.size();
        \\        }}
        \\
        \\        pub fn dataSection(self: Builder) []u8 {{
        \\            return self.builder.dataSectionBytes();
        \\        }}
        \\
        \\        pub fn pointerSection(self: Builder) cpz.ListBuilder {{
        \\            return self.builder.pointerSectionAsList();
        \\        }}
        \\
        \\        pub fn clear(self: Builder) !void {{
        \\            return self.builder.clear();
        \\        }}
        \\
        \\        pub fn copyFrom(self: Builder, @"cpz.value": {s}) !void {{
        \\            return self.builder.copyFromReader(@"cpz.value".reader);
        \\        }}
        \\
        \\        pub fn orphanage(self: Builder) cpz.Orphanage {{
        \\            return self.builder.orphanage();
        \\        }}
        \\
    , .{ struct_name, struct_name, struct_name });

    try emitBuilderUnionHelpers(allocator, out, struct_name, layout);

    for (layout.fields) |field_layout| {
        try emitFieldBuilderMethod(allocator, out, file, layout, struct_name, field_layout);
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    try appendFmt(allocator, out, "}};\n\n", .{});
}

fn emitUnionDeclarations(allocator: std.mem.Allocator, out: *std.ArrayList(u8), layout: *const StructLayout) LayoutError!void {
    for (layout.unions, 0..) |union_layout, union_index| {
        _ = union_layout;
        try appendFmt(allocator, out,
            \\    pub const Union{} = enum(u16) {{
            \\
        , .{union_index});
        for (layout.fields) |field_layout| {
            const field = field_layout.field;
            if (field.union_index == null or field.union_index.? != union_index) continue;
            const field_name = try zigIdentAlloc(allocator, field.name);
            defer allocator.free(field_name);
            try appendFmt(allocator, out,
                \\        {s} = {},
                \\
            , .{ field_name, field.union_discriminant });
        }
        try appendFmt(allocator, out,
            \\    }};
            \\
            \\    pub fn union{}(self: @This()) ?Union{} {{
            \\        return std.enums.fromInt(Union{}, self.reader.getUInt16({}, 0));
            \\    }}
            \\
            \\
        , .{ union_index, union_index, union_index, layout.unions[union_index].discriminant_byte });
    }
    if (layout.unions.len == 1) {
        try appendFmt(allocator, out,
            \\    pub fn which(self: @This()) ?Union0 {{
            \\        return self.union0();
            \\    }}
            \\
            \\
        , .{});
    }
}

fn emitBuilderUnionHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), owner_name: []const u8, layout: *const StructLayout) LayoutError!void {
    for (layout.unions, 0..) |union_layout, union_index| {
        try appendFmt(allocator, out,
            \\        pub fn union{}(self: Builder) !?{s}.Union{} {{
            \\            return std.enums.fromInt({s}.Union{}, try self.builder.getUInt16({}, 0));
            \\        }}
            \\
        , .{ union_index, owner_name, union_index, owner_name, union_index, union_layout.discriminant_byte });
        try appendFmt(allocator, out,
            \\        fn activateUnion{}(self: Builder, discriminant: u16) !void {{
        , .{union_index});
        if (union_layout.data_bits != 0) {
            try appendFmt(allocator, out,
                \\
                \\            try self.builder.clearDataBytes({}, {});
            , .{ union_layout.data_bit / 8, (union_layout.data_bits + 7) / 8 });
        }
        if (union_layout.pointer) |pointer| {
            try appendFmt(allocator, out,
                \\
                \\            try self.builder.clearPointer({});
            , .{pointer});
        }
        try appendFmt(allocator, out,
            \\
            \\            try self.builder.setUInt16({}, discriminant, 0);
            \\        }}
            \\
            \\
        , .{union_layout.discriminant_byte});
    }
    if (layout.unions.len == 1) {
        try appendFmt(allocator, out,
            \\        pub fn which(self: Builder) !?{s}.Union0 {{
            \\            return self.union0();
            \\        }}
            \\
            \\
        , .{owner_name});
    }
}

fn emitFieldGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    const field_name_literal = try zigStringLiteralAlloc(allocator, field.name);
    defer allocator.free(field_name_literal);
    const field_index = fieldIndex(layout, field);
    const slot = fieldSlotMetadata(field_layout.slot);
    const slot_literal = try zigStringLiteralAlloc(allocator, slot.name);
    defer allocator.free(slot_literal);
    try appendFmt(allocator, out,
        \\    pub const @"cpz.field.{s}.index": usize = {};
        \\    pub const @"cpz.field.{s}.name": []const u8 = {s};
        \\    pub const @"cpz.field.{s}.ordinal": u32 = {};
        \\    pub const @"cpz.field.{s}.metadata": cpz.schema.FieldMetadata = @"cpz.fields"[{}];
        \\
    , .{ field_name, field_index, field_name, field_name_literal, field_name, field.ordinal, field_name, field_index });
    const type_name = try schemaTypeNameAlloc(allocator, field.ty);
    defer allocator.free(type_name);
    const type_literal = try zigStringLiteralAlloc(allocator, type_name);
    defer allocator.free(type_literal);
    const resolved_type_name = try schemaResolvedTypeNameAlloc(allocator, file, layout.decl, field.ty);
    defer allocator.free(resolved_type_name);
    const resolved_type_literal = try zigStringLiteralAlloc(allocator, resolved_type_name);
    defer allocator.free(resolved_type_literal);
    try appendFmt(allocator, out,
        \\    pub const @"cpz.field.{s}.type": []const u8 = {s};
        \\    pub const @"cpz.field.{s}.resolvedType": []const u8 = {s};
        \\    pub const @"cpz.field.{s}.slot": []const u8 = {s};
        \\    pub const @"cpz.field.{s}.offset": usize = {};
        \\    pub const @"cpz.field.{s}.isUnionMember": bool = {};
        \\    pub const @"cpz.field.{s}.unionIndex": ?u32 = 
    , .{ field_name, type_literal, field_name, resolved_type_literal, field_name, slot_literal, field_name, slot.offset, field_name, field.union_index != null, field_name });
    if (field.union_index) |union_index| {
        try appendFmt(allocator, out, "{};\n", .{union_index});
    } else {
        try out.appendSlice(allocator, "null;\n");
    }
    try appendFmt(allocator, out,
        \\    pub const @"cpz.field.{s}.unionDiscriminant": u16 = {};
    , .{ field_name, field.union_discriminant });
    const default_expression_literal = try zigStringLiteralAlloc(allocator, field.default_expression);
    defer allocator.free(default_expression_literal);
    const annotation_literal = try zigStringLiteralAlloc(allocator, field.annotations);
    defer allocator.free(annotation_literal);
    try appendFmt(allocator, out,
        \\    pub const @"cpz.field.{s}.default": []const u8 = {s};
        \\    pub const @"cpz.field.{s}.hasExplicitDefault": bool = {};
        \\    pub const @"cpz.field.{s}.defaultIsHexData": bool = {};
        \\    pub const @"cpz.field.{s}.annotations": []const u8 = {s};
        \\
    , .{ field_name, default_expression_literal, field_name, field.default_expression.len != 0, field_name, field.default_is_hex_data, field_name, annotation_literal });
    switch (field_layout.slot) {
        .void => if (unionLayoutForField(layout, field)) |union_layout| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !void {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\    }}
            \\
        , .{ field_name, union_layout.discriminant_byte, field.union_discriminant }) else try appendFmt(allocator, out,
            \\    pub fn {s}(self: {s}) void {{
            \\        _ = self;
            \\    }}
            \\
        , .{ field_name, "@This()" }),
        .data_bit => |bit| if (unionLayoutForField(layout, field)) |union_layout| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !bool {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field_name, union_layout.discriminant_byte, field.union_discriminant, bit, try defaultBoolLiteral(field) }) else try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) bool {{
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field_name, bit, try defaultBoolLiteral(field) }),
        .data_byte => |byte| try emitDataGetter(allocator, out, file, layout, field_name, field, byte),
        .pointer => |index| try emitPointerGetter(allocator, out, file, layout, owner_name, field_name, field, index),
    }
}

fn emitDataGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    const union_layout = unionLayoutForField(layout, field);
    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .int8 => try scalarGetter(allocator, out, field_name, "i8", "getInt8", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .int16 => try scalarGetter(allocator, out, field_name, "i16", "getInt16", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .int32 => try scalarGetter(allocator, out, field_name, "i32", "getInt32", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .int64 => try scalarGetter(allocator, out, field_name, "i64", "getInt64", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint8 => try scalarGetter(allocator, out, field_name, "u8", "getUInt8", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint16 => try scalarGetter(allocator, out, field_name, "u16", "getUInt16", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint32 => try scalarGetter(allocator, out, field_name, "u32", "getUInt32", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint64 => try scalarGetter(allocator, out, field_name, "u64", "getUInt64", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .float32 => try scalarGetter(allocator, out, field_name, "f32", "getFloat32", byte, defaultFloatLiteral(field, "f32"), union_layout, field.union_discriminant),
        .float64 => try scalarGetter(allocator, out, field_name, "f64", "getFloat64", byte, defaultFloatLiteral(field, "f64"), union_layout, field.union_discriminant),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s} {{
            , .{ field_name, zig_type });
            if (union_layout) |u| {
                try appendFmt(allocator, out,
                    \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
                    \\
                , .{ u.discriminant_byte, field.union_discriminant });
            }
            try appendFmt(allocator, out,
                \\        return std.enums.fromInt({s}, self.reader.getUInt16({}, {})) orelse error.InvalidEnumValue;
                \\    }}
                \\
                \\    pub fn {s}_raw(self: @This()) u16 {{
                \\        return self.reader.getUInt16({}, {});
                \\    }}
                \\
            , .{ zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, method: []const u8, byte: usize, default: []const u8, union_layout: ?UnionLayout, discriminant: u16) !void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !{s} {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\        return self.reader.{s}({}, {s});
            \\    }}
            \\
        , .{ name, zig_type, u.discriminant_byte, discriminant, method, byte, default });
    } else {
        try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) {s} {{
            \\        return self.reader.{s}({}, {s});
            \\    }}
            \\
        , .{ name, zig_type, method, byte, default });
    }
}

fn emitPointerGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    if (field.ty == .optional) {
        var optional_field = field.*;
        optional_field.ty = field.ty.optional.*;
        return emitPointerGetter(allocator, out, file, layout, owner_name, field_name, &optional_field, index);
    }
    const union_layout = unionLayoutForField(layout, field);

    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\    pub fn has_{s}(self: @This()) bool {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return false;
            \\        return !self.reader.getPointerField({}).isNull();
            \\    }}
            \\
        , .{ field_name, u.discriminant_byte, field.union_discriminant, index });
    } else {
        try appendFmt(allocator, out,
            \\    pub fn has_{s}(self: @This()) bool {{
            \\        return !self.reader.getPointerField({}).isNull();
            \\    }}
            \\
        , .{ field_name, index });
    }

    try appendFmt(allocator, out,
        \\    pub fn {s}AsPointer(self: @This()) !cpz.PointerReader {{
    , .{field_name});
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({});
        \\    }}
        \\
        \\    pub fn {s}PointerKind(self: @This()) !?cpz.wire.PointerType {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).pointerType();
        \\    }}
        \\
        \\    pub fn {s}RawPointer(self: @This()) !cpz.Word {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).raw();
        \\    }}
        \\
        \\    pub fn {s}DecodedPointer(self: @This()) !?cpz.wire.DecodedPointer {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).decode();
        \\    }}
        \\
        \\    pub fn {s}Stats(self: @This()) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).validate();
        \\    }}
        \\
        \\    pub fn {s}StatsWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).validateWithOptions(options);
        \\    }}
        \\
        \\    pub fn {s}TotalSize(self: @This()) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).totalSize();
        \\    }}
        \\
        \\    pub fn {s}TotalSizeWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).totalSizeWithOptions(options);
        \\    }}
        \\
    , .{index});

    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .text => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) ![]const u8 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getTextDefault({s});
                    \\    }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getText();
                    \\    }}
                    \\
                , .{index});
            }
        },
        .data => {
            const default_literal = if (field.default_literal) |literal| try zigDataLiteralAlloc(allocator, literal, field.default_is_hex_data) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) ![]const u8 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getDataDefault({s});
                    \\    }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getData();
                    \\    }}
                    \\
                , .{index});
            }
        },
        .any_pointer => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.PointerReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({});
                \\    }}
                \\
                \\    pub fn {s}PointerType(self: @This()) !?cpz.wire.PointerType {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).pointerType();
                \\    }}
                \\
                \\    pub fn {s}AsStruct(self: @This()) !cpz.StructReader {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getStruct(null);
                \\    }}
                \\
                \\    pub fn {s}AsList(self: @This(), expected: ?cpz.ElementSize) !cpz.ListReader {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getList(expected);
                \\    }}
                \\
                \\    pub fn {s}AsText(self: @This()) ![]const u8 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getText();
                \\    }}
                \\
                \\    pub fn {s}AsData(self: @This()) ![]const u8 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getData();
                \\    }}
                \\
                \\    pub fn {s}AsCapability(self: @This()) !u32 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getCapabilityIndex();
                \\    }}
                \\
            , .{index});
        },
        .any_struct => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.StructReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getStruct(null);
                \\    }}
                \\
                \\    pub fn {s}PointerSection(self: @This()) !cpz.ListReader {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return (try self.reader.getPointerField({}).getStruct(null)).pointerSectionAsList();
                \\    }}
                \\
                \\    pub fn {s}DataSection(self: @This()) ![]const u8 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return (try self.reader.getPointerField({}).getStruct(null)).dataSectionBytes();
                \\    }}
                \\
            , .{index});
        },
        .any_list => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.ListReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getList(null);
                \\    }}
                \\
            , .{index});
        },
        .capability => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !u32 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getCapabilityIndex();
                \\    }}
                \\
            , .{index});
        },
        .list => |child| {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s}_{s}_List {{
            , .{ field_name, owner_name, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return .{{ .list = try self.reader.getPointerField({}).getList({s}) }};
                \\    }}
                \\
            , .{ index, try listElementSizeLiteral(file, layout.decl, child.*) });
        },
        .named => |type_name| if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !u32 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getCapabilityIndex();
                \\    }}
                \\
            , .{index});
        } else if (!isStructLikeName(file, type_name)) {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.PointerReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({});
                \\    }}
                \\
            , .{index});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s} {{
            , .{ field_name, zig_type });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return {s}.fromReader(try self.reader.getPointerField({}).getStruct(null));
                \\    }}
                \\
            , .{ zig_type, index });
        },
        else => return error.UnsupportedType,
    }
}

fn emitReaderUnionCheck(allocator: std.mem.Allocator, out: *std.ArrayList(u8), union_layout: ?UnionLayout, discriminant: u16) std.mem.Allocator.Error!void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\
        , .{ u.discriminant_byte, discriminant });
    }
}

fn unionLayoutForField(layout: *const StructLayout, field: *const Field) ?UnionLayout {
    const union_index = field.union_index orelse return null;
    return layout.unions[@intCast(union_index)];
}

fn emitListWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, owner_name: []const u8, field: *const Field) LayoutError!void {
    const list_type = switch (resolveTypeScoped(file, scope, field.ty)) {
        .list => |child| child,
        else => return error.UnsupportedType,
    };
    const child = list_type.*;
    const resolved_child = resolveTypeScoped(file, scope, child);
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_List = struct {{
        \\        list: cpz.ListReader,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
        \\        pub fn isEmpty(self: @This()) bool {{
        \\            return self.list.isEmpty();
        \\        }}
        \\
        \\        pub fn lastIndex(self: @This()) !usize {{
        \\            return self.list.lastIndex();
        \\        }}
        \\
        \\        pub fn rawBytes(self: @This()) []const u8 {{
        \\            return self.list.bytes();
        \\        }}
        \\
        \\        pub fn rawPrimitiveBytes(self: @This()) ![]const u8 {{
        \\            return self.list.rawPrimitiveBytes();
        \\        }}
        \\
        \\        pub fn validate(self: @This()) !cpz.MessageStats {{
        \\            return self.list.validate();
        \\        }}
        \\
        \\        pub fn validateWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.list.validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.list.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.list.totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn elementSize(self: @This()) cpz.ElementSize {{
        \\            return self.list.elementSize();
        \\        }}
        \\
        \\        pub fn structElementSize(self: @This()) cpz.StructSize {{
        \\            return self.list.structElementSize();
        \\        }}
        \\
        \\        pub fn slice(self: @This(), start: usize, count: usize) !{s}_{s}_List {{
        \\            return .{{ .list = try self.list.slice(start, count) }};
        \\        }}
        \\
    , .{ owner_name, field_name, owner_name, field_name });

    if (isPointerListElement(file, scope, child)) {
        try emitListReaderPointerElementHelpers(allocator, out);
    }

    switch (resolved_child) {
        .void => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) void {{
            \\            _ = self;
            \\            _ = index;
            \\        }}
            \\
        , .{}),
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) bool {{
            \\            return self.list.getBool(index);
            \\        }}
            \\
        , .{}),
        .uint8 => try listScalarGetter(allocator, out, "u8", "getUInt8"),
        .uint16 => try listScalarGetter(allocator, out, "u16", "getUInt16"),
        .uint32 => try listScalarGetter(allocator, out, "u32", "getUInt32"),
        .uint64 => try listScalarGetter(allocator, out, "u64", "getUInt64"),
        .int8 => try listScalarGetter(allocator, out, "i8", "getInt8"),
        .int16 => try listScalarGetter(allocator, out, "i16", "getInt16"),
        .int32 => try listScalarGetter(allocator, out, "i32", "getInt32"),
        .int64 => try listScalarGetter(allocator, out, "i64", "getInt64"),
        .float32 => try listScalarGetter(allocator, out, "f32", "getFloat32"),
        .float64 => try listScalarGetter(allocator, out, "f64", "getFloat64"),
        .text => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getText();
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
        , .{}),
        .any_pointer => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.PointerReader {{
            \\            return self.list.getPointerElement(index);
            \\        }}
            \\
            \\        pub fn getAsStruct(self: @This(), index: usize) !cpz.StructReader {{
            \\            return (try self.list.getPointerElement(index)).getStruct(null);
            \\        }}
            \\
            \\        pub fn getAsList(self: @This(), index: usize, expected: ?cpz.ElementSize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(index)).getList(expected);
            \\        }}
            \\
            \\        pub fn getAsText(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getText();
            \\        }}
            \\
            \\        pub fn getAsData(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
            \\        pub fn getAsCapability(self: @This(), index: usize) !u32 {{
            \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
            \\        }}
            \\
        , .{}),
        .any_struct => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.StructReader {{
            \\            return (try self.list.getPointerElement(index)).getStruct(null);
            \\        }}
            \\
            \\        pub fn pointerSection(self: @This(), index: usize) !cpz.ListReader {{
            \\            return (try (try self.list.getPointerElement(index)).getStruct(null)).pointerSectionAsList();
            \\        }}
            \\
            \\        pub fn dataSection(self: @This(), index: usize) ![]const u8 {{
            \\            return (try (try self.list.getPointerElement(index)).getStruct(null)).dataSectionBytes();
            \\        }}
            \\
        , .{}),
        .any_list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(index)).getList(null);
            \\        }}
            \\
            \\        pub fn elementSizeAt(self: @This(), index: usize) !cpz.ElementSize {{
            \\            return (try (try self.list.getPointerElement(index)).getList(null)).elementSize();
            \\        }}
            \\
            \\        pub fn structElementSizeAt(self: @This(), index: usize) !cpz.StructSize {{
            \\            return (try (try self.list.getPointerElement(index)).getList(null)).structElementSize();
            \\        }}
            \\
        , .{}),
        .capability => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !u32 {{
            \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
            \\        }}
            \\
        , .{}),
        .list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(index)).getList(null);
            \\        }}
            \\
        , .{}),
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return std.enums.fromInt({s}, self.list.getUInt16(index)) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn getRaw(self: @This(), index: usize) u16 {{
                \\            return self.list.getUInt16(index);
                \\        }}
                \\
            , .{ zig_type, zig_type });
        } else if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !u32 {{
                \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
                \\        }}
                \\
            , .{});
        } else if (!isStructLikeName(file, type_name)) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !cpz.PointerReader {{
                \\            return self.list.getPointerElement(index);
                \\        }}
                \\
            , .{});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return {s}.fromReader(try self.list.getStructElement(index));
                \\        }}
                \\
            , .{ zig_type, zig_type });
        },
        .optional => {},
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    const list_orphan_new = if (isStructListElement(file, scope, child)) |type_name| blk: {
        const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
        defer allocator.free(zig_type);
        break :blk try std.fmt.allocPrint(allocator,
            \\        pub fn newOrphan(builder: *cpz.MessageBuilder, count: usize) !@This() {{
            \\            return fromOrphan(try builder.newOrphanStructList(count, {s}.size));
            \\        }}
            \\
            \\        pub fn newOrphanIn(orphanage: cpz.Orphanage, count: usize) !@This() {{
            \\            return fromOrphan(try orphanage.newStructList(count, {s}.size));
            \\        }}
            \\
            \\        pub fn newOrphanCopy(builder: *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try builder.newOrphanCopyList(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try orphanage.newCopyList(@"cpz.value".list));
            \\        }}
            \\
        , .{ zig_type, zig_type, owner_name, field_name, owner_name, field_name });
    } else try std.fmt.allocPrint(allocator,
        \\        pub fn newOrphan(builder: *cpz.MessageBuilder, count: usize) !@This() {{
        \\            return fromOrphan(try builder.newOrphanList({s}, count));
        \\        }}
        \\
        \\        pub fn newOrphanIn(orphanage: cpz.Orphanage, count: usize) !@This() {{
        \\            return fromOrphan(try orphanage.newList({s}, count));
        \\        }}
        \\
        \\        pub fn newOrphanCopy(builder: *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try builder.newOrphanCopyList(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try orphanage.newCopyList(@"cpz.value".list));
        \\        }}
        \\
    , .{ try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), owner_name, field_name, owner_name, field_name });
    defer allocator.free(list_orphan_new);

    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_Orphan = struct {{
        \\        orphan: cpz.Orphan,
        \\
        \\        pub fn fromOrphan(orphan: cpz.Orphan) @This() {{
        \\            return .{{ .orphan = orphan }};
        \\        }}
        \\
        \\        pub fn fromRaw(orphan: cpz.Orphan) @This() {{
        \\            return fromOrphan(orphan);
        \\        }}
        \\
        \\{s}
        \\        pub fn raw(self: @This()) cpz.Word {{
        \\            return self.orphan.raw;
        \\        }}
        \\
        \\        pub fn isNull(self: @This()) bool {{
        \\            return self.orphan.isNull();
        \\        }}
        \\
        \\        pub fn pointerType(self: @This()) ?cpz.wire.PointerType {{
        \\            return self.orphan.pointerType();
        \\        }}
        \\
        \\        pub fn decode(self: @This(), message_reader: *cpz.MessageReader) !?cpz.wire.DecodedPointer {{
        \\            return self.orphan.decode(message_reader);
        \\        }}
        \\
        \\        pub fn asPointerReader(self: @This(), message_reader: *cpz.MessageReader) cpz.PointerReader {{
        \\            return self.orphan.asReader(message_reader);
        \\        }}
        \\
        \\        pub fn get(self: @This()) !{s}_{s}_BuilderList {{
        \\            return .{{ .list = try self.orphan.getList({s}) }};
        \\        }}
        \\
        \\        pub fn getReader(self: @This(), message_reader: *cpz.MessageReader) !{s}_{s}_List {{
        \\            return .{{ .list = try self.orphan.asReader(message_reader).getList({s}) }};
        \\        }}
        \\
        \\        pub fn asReader(self: @This(), message_reader: *cpz.MessageReader) !{s}_{s}_List {{
        \\            return self.getReader(message_reader);
        \\        }}
        \\
        \\        pub fn validate(self: @This()) !cpz.MessageStats {{
        \\            return self.orphan.validate();
        \\        }}
        \\
        \\        pub fn validateWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.orphan.validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.orphan.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.orphan.totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn release(self: *@This()) void {{
        \\            self.orphan.release();
        \\        }}
        \\    }};
        \\
    , .{ owner_name, field_name, list_orphan_new, owner_name, field_name, try listElementSizeLiteral(file, scope, child), owner_name, field_name, try listElementSizeLiteral(file, scope, child), owner_name, field_name });

    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_BuilderList = struct {{
        \\        list: cpz.ListBuilder,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
        \\        pub fn isEmpty(self: @This()) bool {{
        \\            return self.list.isEmpty();
        \\        }}
        \\
        \\        pub fn lastIndex(self: @This()) !usize {{
        \\            return self.list.lastIndex();
        \\        }}
        \\
        \\        pub fn rawBytes(self: @This()) []u8 {{
        \\            return self.list.bytes();
        \\        }}
        \\
        \\        pub fn rawPrimitiveBytes(self: @This()) ![]u8 {{
        \\            return self.list.rawPrimitiveBytes();
        \\        }}
        \\
        \\        pub fn asReader(self: @This(), message_reader: *cpz.MessageReader) {s}_{s}_List {{
        \\            return .{{ .list = self.list.asReader(message_reader) }};
        \\        }}
        \\
        \\        pub fn validate(self: @This()) !cpz.MessageStats {{
        \\            return self.list.validate();
        \\        }}
        \\
        \\        pub fn validateWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.list.validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.list.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.list.totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn elementSize(self: @This()) cpz.ElementSize {{
        \\            return self.list.elementSize();
        \\        }}
        \\
        \\        pub fn structElementSize(self: @This()) cpz.StructSize {{
        \\            return self.list.structElementSize();
        \\        }}
        \\
        \\        pub fn orphanage(self: @This()) cpz.Orphanage {{
        \\            return self.list.orphanage();
        \\        }}
        \\
        \\        pub fn slice(self: @This(), start: usize, count: usize) !{s}_{s}_BuilderList {{
        \\            return .{{ .list = try self.list.slice(start, count) }};
        \\        }}
        \\
    , .{ owner_name, field_name, owner_name, field_name, owner_name, field_name });

    if (isPointerListElement(file, scope, child)) {
        try emitListBuilderPointerElementHelpers(allocator, out);
    }

    switch (resolved_child) {
        .void => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !void {{
            \\            if (index >= self.list.len()) return error.PointerOutOfBounds;
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: void) !void {{
            \\            _ = new_value;
            \\            if (index >= self.list.len()) return error.PointerOutOfBounds;
            \\        }}
            \\
        , .{}),
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !bool {{
            \\            return self.list.getBool(index);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: bool) !void {{
            \\            return self.list.setBool(index, new_value);
            \\        }}
            \\
        , .{}),
        .uint8 => try listScalarSetter(allocator, out, "u8", "setUInt8"),
        .uint16 => try listScalarSetter(allocator, out, "u16", "setUInt16"),
        .uint32 => try listScalarSetter(allocator, out, "u32", "setUInt32"),
        .uint64 => try listScalarSetter(allocator, out, "u64", "setUInt64"),
        .int8 => try listScalarSetter(allocator, out, "i8", "setInt8"),
        .int16 => try listScalarSetter(allocator, out, "i16", "setInt16"),
        .int32 => try listScalarSetter(allocator, out, "i32", "setInt32"),
        .int64 => try listScalarSetter(allocator, out, "i64", "setInt64"),
        .float32 => try listScalarSetter(allocator, out, "f32", "setFloat32"),
        .float64 => try listScalarSetter(allocator, out, "f64", "setFloat64"),
        .text => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getText();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setText(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), new_value: []const u8) !cpz.Orphan {{
            \\            return self.orphanage().newText(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setData(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), new_value: []const u8) !cpz.Orphan {{
            \\            return self.orphanage().newData(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .any_pointer => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.PointerBuilder {{
            \\            return self.list.getPointerElement(index);
            \\        }}
            \\
            \\        pub fn getAsStruct(self: @This(), index: usize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(index)).getStruct();
            \\        }}
            \\
            \\        pub fn getAsList(self: @This(), index: usize, expected: ?cpz.ElementSize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).getList(expected);
            \\        }}
            \\
            \\        pub fn getAsText(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getText();
            \\        }}
            \\
            \\        pub fn getAsData(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
            \\        pub fn getAsCapability(self: @This(), index: usize) !u32 {{
            \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
            \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
            \\        }}
            \\
            \\        pub fn initStruct(self: @This(), index: usize, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(index)).initStruct(struct_size);
            \\        }}
            \\
            \\        pub fn initList(self: @This(), index: usize, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).initList(element_size, count);
            \\        }}
            \\
            \\        pub fn initStructList(self: @This(), index: usize, count: usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).initStructList(count, struct_size);
            \\        }}
            \\
            \\        pub fn setText(self: @This(), index: usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setText(new_value);
            \\        }}
            \\
            \\        pub fn setData(self: @This(), index: usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setData(new_value);
            \\        }}
            \\
            \\        pub fn setCapability(self: @This(), index: usize, new_value: u32) !void {{
            \\            return (try self.list.getPointerElement(index)).setCapability(new_value);
            \\        }}
            \\
            \\        pub fn newStructOrphan(self: @This(), struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStruct(struct_size);
            \\        }}
            \\
            \\        pub fn newListOrphan(self: @This(), element_size: cpz.ElementSize, count: usize) !cpz.Orphan {{
            \\            return self.orphanage().newList(element_size, count);
            \\        }}
            \\
            \\        pub fn newStructListOrphan(self: @This(), count: usize, struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStructList(count, struct_size);
            \\        }}
            \\
            \\        pub fn newTextOrphan(self: @This(), new_value: []const u8) !cpz.Orphan {{
            \\            return self.orphanage().newText(new_value);
            \\        }}
            \\
            \\        pub fn newDataOrphan(self: @This(), new_value: []const u8) !cpz.Orphan {{
            \\            return self.orphanage().newData(new_value);
            \\        }}
            \\
            \\        pub fn newCapabilityOrphan(self: @This(), new_value: u32) !cpz.Orphan {{
            \\            return self.orphanage().newCapability(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphan(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyPointer(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .any_struct => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(index)).getStruct();
            \\        }}
            \\
            \\        pub fn pointerSection(self: @This(), index: usize) !cpz.ListBuilder {{
            \\            return (try (try self.list.getPointerElement(index)).getStruct()).pointerSectionAsList();
            \\        }}
            \\
            \\        pub fn dataSection(self: @This(), index: usize) ![]u8 {{
            \\            return (try (try self.list.getPointerElement(index)).getStruct()).dataSectionBytes();
            \\        }}
            \\
            \\        pub fn init(self: @This(), index: usize, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(index)).initStruct(struct_size);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: cpz.StructReader) !void {{
            \\            return (try self.list.getPointerElement(index)).copyStructFrom(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStruct(struct_size);
            \\        }}
            \\
            \\        pub fn newCopyOrphan(self: @This(), new_value: cpz.StructReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyStruct(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .any_list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).getList(null);
            \\        }}
            \\
            \\        pub fn elementSizeAt(self: @This(), index: usize) !cpz.ElementSize {{
            \\            return (try (try self.list.getPointerElement(index)).getList(null)).elementSize();
            \\        }}
            \\
            \\        pub fn structElementSizeAt(self: @This(), index: usize) !cpz.StructSize {{
            \\            return (try (try self.list.getPointerElement(index)).getList(null)).structElementSize();
            \\        }}
            \\
            \\        pub fn init(self: @This(), index: usize, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).initList(element_size, count);
            \\        }}
            \\
            \\        pub fn initStructList(self: @This(), index: usize, count: usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).initStructList(count, struct_size);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
            \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), element_size: cpz.ElementSize, count: usize) !cpz.Orphan {{
            \\            return self.orphanage().newList(element_size, count);
            \\        }}
            \\
            \\        pub fn newStructListOrphan(self: @This(), count: usize, struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStructList(count, struct_size);
            \\        }}
            \\
            \\        pub fn newCopyOrphan(self: @This(), new_value: cpz.ListReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyList(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .capability => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !u32 {{
            \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: u32) !void {{
            \\            return (try self.list.getPointerElement(index)).setCapability(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), new_value: u32) !cpz.Orphan {{
            \\            return self.orphanage().newCapability(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .list => |nested_child| {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(index)).getList(null);
                \\        }}
                \\
                \\        pub fn init(self: @This(), index: usize, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(index)).initList(element_size, count);
                \\        }}
                \\
            , .{});
            if (isStructListElement(file, scope, nested_child.*)) |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn initStructList(self: @This(), index: usize, count: usize) !cpz.ListBuilder {{
                    \\            return (try self.list.getPointerElement(index)).initStructList(count, {s}.size);
                    \\        }}
                    \\
                , .{zig_type});
            }
            try appendFmt(allocator, out,
                \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return self.list.clearPointerElement(index);
                \\        }}
                \\
                \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(index);
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(index, orphan);
                \\        }}
                \\
            , .{});
        },
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return std.enums.fromInt({s}, try self.list.getUInt16(index)) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn getRaw(self: @This(), index: usize) !u16 {{
                \\            return self.list.getUInt16(index);
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, new_value: {s}) !void {{
                \\            return self.list.setUInt16(index, @intFromEnum(new_value));
                \\        }}
                \\
                \\        pub fn setRaw(self: @This(), index: usize, new_value: u16) !void {{
                \\            return self.list.setUInt16(index, new_value);
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        } else if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !u32 {{
                \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, new_value: u32) !void {{
                \\            return (try self.list.getPointerElement(index)).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return self.list.clearPointerElement(index);
                \\        }}
                \\
                \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(index);
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(index, orphan);
                \\        }}
                \\
            , .{});
        } else if (!isStructLikeName(file, type_name)) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !cpz.PointerBuilder {{
                \\            return self.list.getPointerElement(index);
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return self.list.clearPointerElement(index);
                \\        }}
                \\
                \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(index);
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(index, orphan);
                \\        }}
                \\
            , .{});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s}.Builder {{
                \\            return {s}.Builder.fromBuilder(try self.list.getStructElement(index));
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, new_value: {s}) !void {{
                \\            return (try self.list.getStructElement(index)).copyFromReader(new_value.reader);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return (try self.list.getStructElement(index)).clear();
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        },
        .optional => {},
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});
}

fn emitListSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, field_name: []const u8, field: *const Field, index: usize, child: Type) LayoutError!void {
    switch (resolveTypeScoped(file, scope, child)) {
        .void => {
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, @"cpz.values": []const void) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            _ = try (try self.builder.getPointerField({})).initList(.void, @"cpz.values".len);
                \\        }}
                \\
            , .{index});
        },
        .bool => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "bool", ".bit", "setBool"),
        .uint8 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u8", ".byte", "setUInt8"),
        .uint16 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u16", ".two_bytes", "setUInt16"),
        .uint32 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u32", ".four_bytes", "setUInt32"),
        .uint64 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u64", ".eight_bytes", "setUInt64"),
        .int8 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i8", ".byte", "setInt8"),
        .int16 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i16", ".two_bytes", "setInt16"),
        .int32 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i32", ".four_bytes", "setInt32"),
        .int64 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i64", ".eight_bytes", "setInt64"),
        .float32 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "f32", ".four_bytes", "setFloat32"),
        .float64 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "f64", ".eight_bytes", "setFloat64"),
        .text => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "[]const u8", "setText"),
        .data => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "[]const u8", "setData"),
        .any_pointer, .any_list, .list => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "cpz.PointerReader", "copyFrom"),
        .any_struct => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "cpz.StructReader", "copyStructFrom"),
        .capability => try emitCapabilitySliceSetter(allocator, out, field_name, field, index),
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
            , .{ field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.two_bytes, @"cpz.values".len);
                \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try @"cpz.list".setUInt16(@"cpz.i", @intFromEnum(@"cpz.item"));
                \\        }}
                \\
                \\        pub fn set_{s}_raw(self: Builder, @"cpz.values": []const u16) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.two_bytes, @"cpz.values".len);
                \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try @"cpz.list".setUInt16(@"cpz.i", @"cpz.item");
                \\        }}
                \\
            , .{index});
        } else if (findInterface(file, type_name) != null) {
            try emitCapabilitySliceSetter(allocator, out, field_name, field, index);
        } else if (!isStructLikeName(file, type_name)) {
            try emitListPointerSliceSetter(allocator, out, field_name, field, index, "cpz.PointerReader", "copyFrom");
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
            , .{ field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initStructList(@"cpz.values".len, {s}.size);
                \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try (try @"cpz.list".getStructElement(@"cpz.i")).copyFromReader(@"cpz.item".reader);
                \\        }}
                \\
            , .{ index, zig_type });
        },
        .optional => {},
    }
}

fn emitListReaderPointerElementHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
    try appendFmt(allocator, out,
        \\        pub fn elementAsPointer(self: @This(), index: usize) !cpz.PointerReader {{
        \\            return self.list.getPointerElement(index);
        \\        }}
        \\
        \\        pub fn elementIsNull(self: @This(), index: usize) !bool {{
        \\            return (try self.list.getPointerElement(index)).isNull();
        \\        }}
        \\
        \\        pub fn elementPointerKind(self: @This(), index: usize) !?cpz.wire.PointerType {{
        \\            return (try self.list.getPointerElement(index)).pointerType();
        \\        }}
        \\
        \\        pub fn elementRawPointer(self: @This(), index: usize) !cpz.Word {{
        \\            return (try self.list.getPointerElement(index)).raw();
        \\        }}
        \\
        \\        pub fn elementDecodedPointer(self: @This(), index: usize) !?cpz.wire.DecodedPointer {{
        \\            return (try self.list.getPointerElement(index)).decode();
        \\        }}
        \\
        \\        pub fn elementStats(self: @This(), index: usize) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(index)).validate();
        \\        }}
        \\
        \\        pub fn elementStatsWithOptions(self: @This(), index: usize, options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(index)).validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn elementTotalSize(self: @This(), index: usize) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(index)).totalSize();
        \\        }}
        \\
        \\        pub fn elementTotalSizeWithOptions(self: @This(), index: usize, options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(index)).totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn elementAsStruct(self: @This(), index: usize) !cpz.StructReader {{
        \\            return (try self.list.getPointerElement(index)).getStruct(null);
        \\        }}
        \\
        \\        pub fn elementAsList(self: @This(), index: usize, expected: ?cpz.ElementSize) !cpz.ListReader {{
        \\            return (try self.list.getPointerElement(index)).getList(expected);
        \\        }}
        \\
        \\        pub fn elementAsText(self: @This(), index: usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(index)).getText();
        \\        }}
        \\
        \\        pub fn elementAsData(self: @This(), index: usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(index)).getData();
        \\        }}
        \\
        \\        pub fn elementAsCapability(self: @This(), index: usize) !u32 {{
        \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
        \\        }}
        \\
    , .{});
}

fn emitListBuilderPointerElementHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
    try appendFmt(allocator, out,
        \\        pub fn elementAsPointer(self: @This(), index: usize) !cpz.PointerBuilder {{
        \\            return self.list.getPointerElement(index);
        \\        }}
        \\
        \\        pub fn elementIsNull(self: @This(), index: usize) !bool {{
        \\            return (try self.list.getPointerElement(index)).isNull();
        \\        }}
        \\
        \\        pub fn elementAsReader(self: @This(), index: usize, message_reader: *cpz.MessageReader) !cpz.PointerReader {{
        \\            return (try self.list.getPointerElement(index)).asReader(message_reader);
        \\        }}
        \\
        \\        pub fn elementPointerKind(self: @This(), index: usize) !?cpz.wire.PointerType {{
        \\            return (try self.list.getPointerElement(index)).pointerType();
        \\        }}
        \\
        \\        pub fn elementRawPointer(self: @This(), index: usize) !cpz.Word {{
        \\            return (try self.list.getPointerElement(index)).raw();
        \\        }}
        \\
        \\        pub fn elementDecodedPointer(self: @This(), index: usize) !?cpz.wire.DecodedPointer {{
        \\            return (try self.list.getPointerElement(index)).decode();
        \\        }}
        \\
        \\        pub fn elementStats(self: @This(), index: usize) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(index)).validate();
        \\        }}
        \\
        \\        pub fn elementStatsWithOptions(self: @This(), index: usize, options: cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(index)).validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn elementTotalSize(self: @This(), index: usize) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(index)).totalSize();
        \\        }}
        \\
        \\        pub fn elementTotalSizeWithOptions(self: @This(), index: usize, options: cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(index)).totalSizeWithOptions(options);
        \\        }}
        \\
        \\        pub fn elementAsStruct(self: @This(), index: usize) !cpz.StructBuilder {{
        \\            return (try self.list.getPointerElement(index)).getStruct();
        \\        }}
        \\
        \\        pub fn elementAsList(self: @This(), index: usize, expected: ?cpz.ElementSize) !cpz.ListBuilder {{
        \\            return (try self.list.getPointerElement(index)).getList(expected);
        \\        }}
        \\
        \\        pub fn elementAsText(self: @This(), index: usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(index)).getText();
        \\        }}
        \\
        \\        pub fn elementAsData(self: @This(), index: usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(index)).getData();
        \\        }}
        \\
        \\        pub fn elementAsCapability(self: @This(), index: usize) !u32 {{
        \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
        \\        }}
        \\
    , .{});
}

fn emitListPrimitiveSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, zig_type: []const u8, element_size: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
    , .{ field_name, zig_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList({s}, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try @"cpz.list".{s}(@"cpz.i", @"cpz.item");
        \\        }}
        \\
    , .{ index, element_size, method });
}

fn emitListPointerSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, item_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
    , .{ field_name, item_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try (try @"cpz.list".getPointerElement(@"cpz.i")).{s}(@"cpz.item");
        \\        }}
        \\
    , .{ index, method });
}

fn emitCapabilitySliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const u32) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| (try @"cpz.list".getPointerElement(@"cpz.i")).setCapability(@"cpz.item");
        \\        }}
        \\
    , .{index});
}

fn listScalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), zig_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get(self: @This(), index: usize) {s} {{
        \\            return self.list.{s}(index);
        \\        }}
        \\
    , .{ zig_type, method });
}

fn listScalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), zig_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get(self: @This(), index: usize) !{s} {{
        \\            return self.list.get{s}(index);
        \\        }}
        \\
        \\        pub fn set(self: @This(), index: usize, new_value: {s}) !void {{
        \\            return self.list.{s}(index, new_value);
        \\        }}
        \\
    , .{ zig_type, method["set".len..], zig_type, method });
}

fn emitFieldBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    const union_layout = unionLayoutForField(layout, field);
    switch (field_layout.slot) {
        .void => if (field.union_index) |union_index| try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder) !void {{
            \\            return self.activateUnion{}({});
            \\        }}
            \\
        , .{ field_name, union_index, field.union_discriminant }) else try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder) void {{
            \\            _ = self;
            \\        }}
            \\
        , .{field_name}),
        .data_bit => |bit| {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !bool {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getBool({}, {s});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: bool) !void {{
            , .{ bit, try defaultBoolLiteral(field), field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setBool({}, new_value, {s});
                \\        }}
                \\
            , .{ bit, try defaultBoolLiteral(field) });
        },
        .data_byte => |byte| try emitDataBuilderMethod(allocator, out, file, layout, field_name, field, byte),
        .pointer => |index| try emitPointerBuilderMethod(allocator, out, file, layout, owner_name, field_name, field, index),
    }
}

fn emitDataBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    const union_layout = unionLayoutForField(layout, field);
    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .int8 => try scalarSetter(allocator, out, field_name, "i8", "getInt8", "setInt8", byte, defaultScalarLiteral(field), union_layout, field),
        .int16 => try scalarSetter(allocator, out, field_name, "i16", "getInt16", "setInt16", byte, defaultScalarLiteral(field), union_layout, field),
        .int32 => try scalarSetter(allocator, out, field_name, "i32", "getInt32", "setInt32", byte, defaultScalarLiteral(field), union_layout, field),
        .int64 => try scalarSetter(allocator, out, field_name, "i64", "getInt64", "setInt64", byte, defaultScalarLiteral(field), union_layout, field),
        .uint8 => try scalarSetter(allocator, out, field_name, "u8", "getUInt8", "setUInt8", byte, defaultScalarLiteral(field), union_layout, field),
        .uint16 => try scalarSetter(allocator, out, field_name, "u16", "getUInt16", "setUInt16", byte, defaultScalarLiteral(field), union_layout, field),
        .uint32 => try scalarSetter(allocator, out, field_name, "u32", "getUInt32", "setUInt32", byte, defaultScalarLiteral(field), union_layout, field),
        .uint64 => try scalarSetter(allocator, out, field_name, "u64", "getUInt64", "setUInt64", byte, defaultScalarLiteral(field), union_layout, field),
        .float32 => try scalarSetter(allocator, out, field_name, "f32", "getFloat32", "setFloat32", byte, defaultFloatLiteral(field, "f32"), union_layout, field),
        .float64 => try scalarSetter(allocator, out, field_name, "f64", "getFloat64", "setFloat64", byte, defaultFloatLiteral(field, "f64"), union_layout, field),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s} {{
            , .{ field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return std.enums.fromInt({s}, try self.builder.getUInt16({}, {})) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn get_{s}_raw(self: Builder) !u16 {{
            , .{ zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getUInt16({}, {});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: {s}) !void {{
            , .{ byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setUInt16({}, @intFromEnum(new_value), {});
                \\        }}
                \\
                \\        pub fn set_{s}_raw(self: Builder, new_value: u16) !void {{
            , .{ byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setUInt16({}, new_value, {});
                \\        }}
                \\
            , .{ byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, get_method: []const u8, method: []const u8, byte: usize, default: []const u8, union_layout: ?UnionLayout, field: *const Field) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get_{s}(self: Builder) !{s} {{
    , .{ name, zig_type });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return self.builder.{s}({}, {s});
        \\        }}
        \\
        \\        pub fn set_{s}(self: Builder, new_value: {s}) !void {{
    , .{ get_method, byte, default, name, zig_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            return self.builder.{s}({}, new_value, {s});
        \\        }}
        \\
    , .{ method, byte, default });
}

fn emitPointerBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    if (field.ty == .optional) {
        var optional_field = field.*;
        optional_field.ty = field.ty.optional.*;
        return emitPointerBuilderMethod(allocator, out, file, layout, owner_name, field_name, &optional_field, index);
    }
    const union_layout = unionLayoutForField(layout, field);

    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\        pub fn has_{s}(self: Builder) !bool {{
            \\            if (try self.builder.getUInt16({}, 0) != {}) return false;
            \\            return !(try self.builder.getPointerField({})).isNull();
            \\        }}
            \\
            \\        pub fn clear_{s}(self: Builder) !void {{
        , .{ field_name, u.discriminant_byte, field.union_discriminant, index, field_name });
        try emitBuilderUnionActivation(allocator, out, field);
        try appendFmt(allocator, out,
            \\            return self.builder.clearPointer({});
            \\        }}
            \\
        , .{index});
    } else {
        try appendFmt(allocator, out,
            \\        pub fn has_{s}(self: Builder) !bool {{
            \\            return !(try self.builder.getPointerField({})).isNull();
            \\        }}
            \\
            \\        pub fn clear_{s}(self: Builder) !void {{
            \\            return self.builder.clearPointer({});
            \\        }}
            \\
        , .{ field_name, index, field_name, index });
    }

    try appendFmt(allocator, out,
        \\        pub fn disown_{s}(self: Builder) !cpz.Orphan {{
    , .{field_name});
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).disown();
        \\        }}
        \\
        \\        pub fn adopt_{s}(self: Builder, orphan: *cpz.Orphan) !void {{
    , .{ index, field_name });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).adopt(orphan);
        \\        }}
        \\
        \\        pub fn get_{s}AsPointer(self: Builder) !cpz.PointerBuilder {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return self.builder.getPointerField({});
        \\        }}
        \\
        \\        pub fn get_{s}AsReader(self: Builder, message_reader: *cpz.MessageReader) !cpz.PointerReader {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).asReader(message_reader);
        \\        }}
        \\
        \\        pub fn get_{s}PointerKind(self: Builder) !?cpz.wire.PointerType {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).pointerType();
        \\        }}
        \\
        \\        pub fn get_{s}RawPointer(self: Builder) !cpz.Word {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).raw();
        \\        }}
        \\
        \\        pub fn get_{s}DecodedPointer(self: Builder) !?cpz.wire.DecodedPointer {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).decode();
        \\        }}
        \\
        \\        pub fn get_{s}Stats(self: Builder) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).validate();
        \\        }}
        \\
        \\        pub fn get_{s}StatsWithOptions(self: Builder, options: cpz.ReaderOptions) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).validateWithOptions(options);
        \\        }}
        \\
        \\        pub fn get_{s}TotalSize(self: Builder) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).totalSize();
        \\        }}
        \\
        \\        pub fn get_{s}TotalSizeWithOptions(self: Builder, options: cpz.ReaderOptions) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).totalSizeWithOptions(options);
        \\        }}
        \\
    , .{index});

    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .text => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) ![]const u8 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getTextDefault({s});
                    \\        }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getText();
                    \\        }}
                    \\
                , .{index});
            }
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, new_value: []const u8) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setText({}, new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: []const u8) !cpz.Orphan {{
                \\            return self.orphanage().newText(new_value);
                \\        }}
                \\
            , .{ index, field_name });
        },
        .data => {
            const default_literal = if (field.default_literal) |literal| try zigDataLiteralAlloc(allocator, literal, field.default_is_hex_data) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) ![]const u8 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getDataDefault({s});
                    \\        }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getData();
                    \\        }}
                    \\
                , .{index});
            }
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, new_value: []const u8) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setData({}, new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: []const u8) !cpz.Orphan {{
                \\            return self.orphanage().newData(new_value);
                \\        }}
                \\
            , .{ index, field_name });
        },
        .list => |child| {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}_{s}_BuilderList {{
            , .{ field_name, owner_name, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return .{{ .list = try (try self.builder.getPointerField({})).getList({s}) }};
                \\        }}
                \\
            , .{ index, try listElementSizeLiteral(file, layout.decl, child.*) });

            try appendFmt(allocator, out,
                \\        pub fn set_{s}_from(self: Builder, new_value: {s}_{s}_List) !void {{
            , .{ field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFrom(new_value.list);
                \\        }}
                \\
                \\        pub fn disown_{s}_typed(self: Builder) !{s}_{s}_Orphan {{
            , .{ index, field_name, owner_name, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return {s}_{s}_Orphan.fromOrphan((try self.builder.getPointerField({})).disown());
                \\        }}
                \\
                \\        pub fn adopt_{s}_typed(self: Builder, orphan: *{s}_{s}_Orphan) !void {{
            , .{ owner_name, field_name, index, field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).adopt(&orphan.orphan);
                \\        }}
                \\
            , .{index});

            try emitListSliceSetter(allocator, out, file, layout.decl, field_name, field, index, child.*);

            if (isStructListElement(file, layout.decl, child.*)) |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn init_{s}(self: Builder, count: usize) !{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionActivation(allocator, out, field);
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).initStructList(count, {s}.size) }};
                    \\        }}
                    \\
                , .{ index, zig_type });
            } else {
                try appendFmt(allocator, out,
                    \\        pub fn init_{s}(self: Builder, count: usize) !{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionActivation(allocator, out, field);
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).initList({s}, count) }};
                    \\        }}
                    \\
                , .{ index, try listElementSizeLiteral(file, layout.decl, child.*) });
            }
        },
        .any_pointer => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.PointerBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getPointerField({});
                \\        }}
                \\
                \\        pub fn get_{s}PointerType(self: Builder) !?cpz.wire.PointerType {{
                \\            return (try self.builder.getPointerField({})).pointerType();
                \\        }}
                \\
                \\        pub fn get_{s}AsStruct(self: Builder) !cpz.StructBuilder {{
                \\            return (try self.builder.getPointerField({})).getStruct();
                \\        }}
                \\
                \\        pub fn get_{s}AsList(self: Builder, expected: ?cpz.ElementSize) !cpz.ListBuilder {{
                \\            return (try self.builder.getPointerField({})).getList(expected);
                \\        }}
                \\
                \\        pub fn get_{s}AsText(self: Builder) ![]const u8 {{
                \\            return (try self.builder.getPointerField({})).getText();
                \\        }}
                \\
                \\        pub fn get_{s}AsData(self: Builder) ![]const u8 {{
                \\            return (try self.builder.getPointerField({})).getData();
                \\        }}
                \\
                \\        pub fn get_{s}AsCapability(self: Builder) !u32 {{
                \\            return (try self.builder.getPointerField({})).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name, index, field_name, index, field_name, index, field_name, index, field_name, index, field_name, index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_text(self: Builder, new_value: []const u8) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).setText(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_data(self: Builder, new_value: []const u8) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).setData(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_capability(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn init_{s}_struct(self: Builder, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStruct(struct_size);
                \\        }}
                \\
                \\        pub fn init_{s}_list(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initList(element_size, count);
                \\        }}
                \\
                \\        pub fn init_{s}_structList(self: Builder, count: usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStructList(count, struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_structOrphan(self: Builder, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStruct(struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_listOrphan(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.Orphan {{
                \\            return self.orphanage().newList(element_size, count);
                \\        }}
                \\
                \\        pub fn new_{s}_structListOrphan(self: Builder, count: usize, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStructList(count, struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_textOrphan(self: Builder, new_value: []const u8) !cpz.Orphan {{
                \\            return self.orphanage().newText(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_dataOrphan(self: Builder, new_value: []const u8) !cpz.Orphan {{
                \\            return self.orphanage().newData(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_capabilityOrphan(self: Builder, new_value: u32) !cpz.Orphan {{
                \\            return self.orphanage().newCapability(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointer(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name, field_name, field_name, field_name, field_name, field_name });
        },
        .any_struct => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.StructBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getStruct();
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStruct(struct_size);
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: cpz.StructReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFrom(new_value);
                \\        }}
                \\
                \\        pub fn get_{s}PointerSection(self: Builder) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try (try self.builder.getPointerField({})).getStruct()).pointerSectionAsList();
                \\        }}
                \\
                \\        pub fn get_{s}DataSection(self: Builder) ![]u8 {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try (try self.builder.getPointerField({})).getStruct()).dataSectionBytes();
                \\        }}
                \\
                \\        pub fn new_{s}_structOrphan(self: Builder, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStruct(struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: cpz.StructReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyStruct(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name });
        },
        .any_list => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.ListBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getList(null);
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initList(element_size, count);
                \\        }}
                \\
                \\        pub fn init_{s}_structList(self: Builder, count: usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStructList(count, struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_listOrphan(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.Orphan {{
                \\            return self.orphanage().newList(element_size, count);
                \\        }}
                \\
                \\        pub fn new_{s}_structListOrphan(self: Builder, count: usize, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStructList(count, struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: cpz.ListReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyList(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name, field_name, field_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
            , .{index});
        },
        .capability => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !u32 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: u32) !cpz.Orphan {{
                \\            return self.orphanage().newCapability(new_value);
                \\        }}
                \\
            , .{ index, field_name });
        },
        .named => |type_name| if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !u32 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: u32) !cpz.Orphan {{
                \\            return self.orphanage().newCapability(new_value);
                \\        }}
                \\
            , .{ index, field_name });
        } else if (!isStructLikeName(file, type_name)) {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.PointerBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getPointerField({});
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
            , .{index});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}.Builder {{
            , .{ field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).getStruct());
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder) !{s}.Builder {{
            , .{ zig_type, index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).initStruct({s}.size));
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: {s}) !void {{
            , .{ zig_type, index, zig_type, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFrom(new_value.reader);
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder) !{s}.Orphan {{
                \\            return {s}.Orphan.fromOrphan(try self.orphanage().newStruct({s}.size));
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: {s}) !{s}.Orphan {{
                \\            return {s}.Orphan.fromOrphan(try self.orphanage().newCopyStruct(new_value.reader));
                \\        }}
                \\
                \\        pub fn disown_{s}_typed(self: Builder) !{s}.Orphan {{
            , .{ index, field_name, zig_type, zig_type, zig_type, field_name, zig_type, zig_type, zig_type, field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return {s}.Orphan.fromOrphan((try self.builder.getPointerField({})).disown());
                \\        }}
                \\
                \\        pub fn adopt_{s}_typed(self: Builder, orphan: *{s}.Orphan) !void {{
            , .{ zig_type, index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).adopt(&orphan.orphan);
                \\        }}
                \\
            , .{index});
        },
        else => return error.UnsupportedType,
    }
}

fn emitBuilderUnionCheck(allocator: std.mem.Allocator, out: *std.ArrayList(u8), union_layout: ?UnionLayout, discriminant: u16) std.mem.Allocator.Error!void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\            if (try self.builder.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\
        , .{ u.discriminant_byte, discriminant });
    }
}

fn emitBuilderUnionActivation(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field: *const Field) std.mem.Allocator.Error!void {
    if (field.union_index) |union_index| {
        try appendFmt(allocator, out,
            \\            try self.activateUnion{}({});
            \\
        , .{ union_index, field.union_discriminant });
    }
}

fn listElementSizeLiteral(file: *const File, scope: ?*const Struct, ty: Type) LayoutError![]const u8 {
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

fn isPointerListElement(file: *const File, scope: ?*const Struct, ty: Type) bool {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => true,
        .named => |name| findEnum(file, name) == null and (findInterface(file, name) != null or !isStructLikeName(file, name)),
        else => false,
    };
}

fn isStructListElement(file: *const File, scope: ?*const Struct, ty: Type) ?[]const u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .named => |name| if (findEnumDirect(file, name) == null and findInterfaceDirect(file, name) == null and isStructLikeName(file, name)) name else null,
        else => null,
    };
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) std.mem.Allocator.Error!void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn zigTypeRefAlloc(allocator: std.mem.Allocator, file: *const File, raw: []const u8) std.mem.Allocator.Error![]u8 {
    if (try importedTypeRefAlloc(allocator, file, raw)) |imported| return imported;
    const canonical = try canonicalTypeNameAlloc(allocator, raw);
    defer allocator.free(canonical);
    const ident = try zigIdentAlloc(allocator, canonical);
    defer allocator.free(ident);
    return std.fmt.allocPrint(allocator, "@\"cpz.schema\".{s}", .{ident});
}

fn importedTypeRefAlloc(allocator: std.mem.Allocator, file: *const File, raw: []const u8) std.mem.Allocator.Error!?[]u8 {
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

fn zigIdentAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (raw.len == 0 or !isZigIdentStart(raw[0])) {
        try out.append(allocator, '_');
    }
    for (raw) |c| {
        try out.append(allocator, if (isZigIdentContinue(c)) c else '_');
    }
    if (isZigKeyword(out.items)) {
        try out.append(allocator, '_');
    }
    return out.toOwnedSlice(allocator);
}

fn zigDataLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8, is_hex: bool) LayoutError![]u8 {
    if (!is_hex) return zigStringLiteralAlloc(allocator, raw);

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
    const decoded = try bytes.toOwnedSlice(allocator);
    defer allocator.free(decoded);
    return zigStringLiteralAlloc(allocator, decoded);
}

fn hexValue(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

fn zigStringLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
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
                'n' => try appendZigStringChar(allocator, &out, '\n'),
                'r' => try appendZigStringChar(allocator, &out, '\r'),
                't' => try appendZigStringChar(allocator, &out, '\t'),
                '"' => try appendZigStringChar(allocator, &out, '"'),
                '\\' => try appendZigStringChar(allocator, &out, '\\'),
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
                else => try appendZigStringChar(allocator, &out, escaped),
            }
        } else {
            try appendZigStringChar(allocator, &out, c);
        }
    }
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

fn appendZigStringChar(allocator: std.mem.Allocator, out: *std.ArrayList(u8), c: u8) std.mem.Allocator.Error!void {
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

fn isZigIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

fn isZigIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

fn isZigKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "addrspace", "align",     "allowzero",   "and",            "anyframe",       "anytype",      "asm",
        "async",     "await",     "break",       "callconv",       "catch",          "comptime",     "const",
        "continue",  "defer",     "else",        "enum",           "errdefer",       "error",        "export",
        "extern",    "fn",        "for",         "if",             "inline",         "linksection",  "noalias",
        "noinline",  "nosuspend", "opaque",      "or",             "orelse",         "packed",       "pub",
        "resume",    "return",    "struct",      "suspend",        "switch",         "test",         "threadlocal",
        "try",       "union",     "unreachable", "usingnamespace", "var",            "volatile",     "while",

        // Primitive type names and literal spellings are not all Zig keywords,
        // but declarations using them still shadow builtins or produce invalid
        // generated code in common schemas (for example json.Value.null).
        "bool",      "c_int",     "c_long",      "c_longdouble",   "c_longlong",     "c_char",       "c_short",
        "c_uint",    "c_ulong",   "c_ulonglong", "c_ushort",       "comptime_float", "comptime_int", "f16",
        "f32",       "f64",       "f80",         "f128",           "false",          "isize",        "null",
        "true",      "type",      "usize",       "void",           "anyopaque",      "i0",           "i1",
        "i2",        "i3",        "i4",          "i5",             "i6",             "i7",           "i8",
        "i16",       "i32",       "i64",         "i128",           "u0",             "u1",           "u2",
        "u3",        "u4",        "u5",          "u6",             "u7",             "u8",           "u16",
        "u32",       "u64",       "u128",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
    }
    return false;
}

fn defaultScalarLiteral(field: *const Field) []const u8 {
    const literal = field.default_literal orelse return "0";
    return if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal;
}

fn schemaTypeNameAlloc(allocator: std.mem.Allocator, ty: Type) LayoutError![]u8 {
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

fn schemaResolvedTypeNameAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type) LayoutError![]u8 {
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

fn schemaResolvedTypeNameInOwnerScopeAlloc(allocator: std.mem.Allocator, file: *const File, owner_name: ?[]const u8, ty: Type) LayoutError![]u8 {
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

fn defaultFloatLiteral(field: *const Field, comptime zig_type: []const u8) []const u8 {
    const literal = field.default_literal orelse return "0";
    return floatConstLiteral(literal, zig_type);
}

fn floatConstLiteral(literal: []const u8, comptime zig_type: []const u8) []const u8 {
    const unsigned = if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal;
    if (std.mem.eql(u8, unsigned, "inf")) return if (std.mem.eql(u8, zig_type, "f32")) "std.math.inf(f32)" else "std.math.inf(f64)";
    if (std.mem.eql(u8, unsigned, "-inf")) return if (std.mem.eql(u8, zig_type, "f32")) "-std.math.inf(f32)" else "-std.math.inf(f64)";
    if (std.mem.eql(u8, unsigned, "nan")) return if (std.mem.eql(u8, zig_type, "f32")) "std.math.nan(f32)" else "std.math.nan(f64)";
    return unsigned;
}

fn boolConstLiteral(literal: []const u8) LayoutError![]const u8 {
    if (std.mem.eql(u8, literal, "true") or std.mem.eql(u8, literal, "false")) return literal;
    return error.InvalidToken;
}

fn defaultBoolLiteral(field: *const Field) LayoutError![]const u8 {
    const literal = field.default_literal orelse return "false";
    return boolConstLiteral(literal);
}

fn enumDefaultOrdinal(decl: *const EnumDecl, literal: ?[]const u8) LayoutError!u16 {
    const raw_name = literal orelse return 0;
    const name = if (std.mem.lastIndexOfScalar(u8, raw_name, '.')) |dot| raw_name[dot + 1 ..] else raw_name;
    for (decl.values) |value| {
        if (std.mem.eql(u8, value.name, name)) return value.ordinal;
    }
    return error.InvalidToken;
}

test "schema parser and code generator preserve declaration ids" {
    const source =
        \\struct StreamResult @0x995f9a3377c0b16e {
        \\  value @0 :Text;
        \\}
        \\interface Persistent @0xc8cb212fcd9f5691 {
        \\  save @0 () -> (sturdyRef :Data);
        \\}
        \\annotation note @0xa110ca110c (field) :Text;
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?u64, 0x995f9a3377c0b16e), file.structs[0].id);
    try std.testing.expectEqual(@as(?u64, 0xc8cb212fcd9f5691), file.interfaces[0].id);
    try std.testing.expectEqual(@as(?u64, 0xa110ca110c), file.annotations[0].id);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.type_id\": u64 = 0x995f9a3377c0b16e;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.type_id\": u64 = 0xc8cb212fcd9f5691;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.type_id\": u64 = 0xa110ca110c;") != null);
}

test "schema code generator emits file id constant" {
    const source =
        \\@0xabcdef;
        \\struct Sample {
        \\  id @0 :UInt32;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.file_id\": u64 = 0xabcdef;") != null);
}

test "schema code generator emits Zig accessor skeletons" {
    const source =
        \\enum Color {
        \\  red @0;
        \\  green @1;
        \\}
        \\struct Person {
        \\  id @0 :UInt32 = 42;
        \\  active @1 :Bool = true;
        \\  favorite @2 :Color = Color.green;
        \\  name @3 :Text = "Anon";
        \\  friend @4 :Person;
        \\  scores @5 :List(UInt32);
        \\  children @6 :List(Person);
        \\  palette @7 :List(Color);
        \\  aliases @8 :TextList;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Person = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "data_words = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pointer_count = 6") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn id(self: @This()) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getUInt32(0, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getBool(32, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "std.enums.fromInt(@\"cpz.schema\".Color, self.reader.getUInt16(6, 1))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn favorite_raw(self: @This()) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_favorite(self: Builder) !@\"cpz.schema\".Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_favorite_raw(self: Builder) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_favorite_raw(self: Builder, new_value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getTextDefault(\"Anon\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Person.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_scores_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_children_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @\"cpz.schema\".Person.fromReader(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_friend(self: Builder) !@\"cpz.schema\".Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !@\"cpz.schema\".Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@\"cpz.schema\".Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_scores_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt32(index, new_value);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_children_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @\"cpz.schema\".Person.Builder.fromBuilder(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromReader(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getPointerElement(index)).getText();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearPointerElement(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getStructElement(index)).clear();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return std.enums.fromInt(@\"cpz.schema\".Color, self.list.getUInt16(index)) orelse error.InvalidEnumValue;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), index: usize) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), index: usize) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setRaw(self: @This(), index: usize, new_value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt16(index, @intFromEnum(new_value));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(count, @\"cpz.schema\".Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Builder = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_id(self: Builder) !u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_id(self: Builder, new_value: u32) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setUInt32(0, new_value, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setBool(32, new_value, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn has_name(self: Builder) !bool") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_name(self: Builder) ![]const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_name(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_name(self: Builder, new_value: []const u8) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_friend(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_friend_from(self: Builder, new_value: @\"cpz.schema\".Person) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFrom(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_scores(self: Builder) !void") != null);
}

test "schema code generator emits external import type references" {
    const source =
        \\using Other = import "other.capnp";
        \\using import "common.capnp".Shared;
        \\struct Holder {
        \\  external @0 :Other.External;
        \\  shared @1 :Shared;
        \\  externalList @2 :List(Other.External);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "@import(\"Other\").External.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@import(\"Shared\").Shared.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@import(\"Other\").External.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@import(\"Shared\").Shared.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @import(\"Other\").External.fromReader(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(count, @import(\"Other\").External.size)") != null);
}

test "schema code generator lowers generic type parameters to pointer accessors" {
    const source =
        \\struct Box(T) {
        \\  item @0 :T;
        \\  items @1 :List(T);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn item(self: @This()) !cpz.PointerReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_item(self: Builder) !cpz.PointerBuilder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getPointerField(1).getList(.pointer)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get(self: @This(), index: usize) !cpz.PointerReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_items(self: Builder, @\"cpz.values\": []const cpz.PointerReader)") != null);
}

test "schema code generator can wrap declarations in a namespace" {
    var file = try parse(std.testing.allocator,
        \\struct Demo {
        \\  id @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{ .namespace = "my.api" });
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const my_api = struct {") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Demo = struct") != null);
    try std.testing.expect(std.mem.endsWith(u8, std.mem.trimEnd(u8, code, "\n"), "};"));
}

test "schema code generator can include raw schema comments" {
    const source =
        \\struct Demo {
        \\  id @0 :UInt32;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{ .raw_schema_comment = source });
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.startsWith(u8, code, "// cpz source schema begin\n"));
    try std.testing.expect(std.mem.indexOf(u8, code, "// struct Demo {") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "// cpz source schema end") != null);
}

test "schema code generator supports custom runtime import names" {
    var file = try parse(std.testing.allocator,
        \\struct Demo {
        \\  id @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{
        .runtime_import_name = "my_cpz",
    });
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "const cpz = @import(\"my_cpz\");") != null);
}

test "schema code generator converts escaped string defaults to Zig literals" {
    const literal = try zigStringLiteralAlloc(std.testing.allocator, "line\\n\\\"tab\\t\\x21");
    defer std.testing.allocator.free(literal);
    try std.testing.expectEqualStrings("\"line\\n\\\"tab\\t!\"", literal);
    const hex_literal = try zigDataLiteralAlloc(std.testing.allocator, "62 61 72 00 ff", true);
    defer std.testing.allocator.free(hex_literal);
    try std.testing.expectEqualStrings("\"bar\\x00\\xFF\"", hex_literal);
}

test "schema code generator sanitizes dotted named type references" {
    var file = try parse(std.testing.allocator,
        \\struct Ref {
        \\  child @0 :Outer.Inner;
        \\  children @1 :List(Outer.Inner);
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "!@\"cpz.schema\".Outer_Inner") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Outer_Inner.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Outer_Inner.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Outer_Inner.size") != null);
}

test "schema code generator sanitizes Zig keywords in declarations and fields" {
    var file = try parse(std.testing.allocator,
        \\enum error {
        \\  test @0;
        \\  ok @1;
        \\}
        \\struct fn {
        \\  error @0 :UInt32;
        \\  enum @1 :error = test;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const error_ = enum") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "test_ = 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const fn_ = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn error_(self: @This()) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn enum_(self: @This()) !@\"cpz.schema\".error_") != null);
}

test "schema code generator rejects sanitized Zig name collisions" {
    {
        var file = try parse(std.testing.allocator,
            \\struct error {
            \\  id @0 :UInt32;
            \\}
            \\struct error_ {
            \\  id @0 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\struct Fields {
            \\  error @0 :UInt32;
            \\  error_ @1 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\enum Values {
            \\  test @0;
            \\  test_ @1;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
}

test "schema parser, layout, and codegen handle enums" {
    const source =
        \\enum Color {
        \\  red @0;
        \\  green @1;
        \\  blue @2;
        \\}
        \\struct Pixel {
        \\  color @0 :Color = green;
        \\  label @1 :Text;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.enums.len);
    try std.testing.expectEqualStrings("Color", file.enums[0].name);
    try std.testing.expectEqual(@as(u16, 1), file.enums[0].values[1].ordinal);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 1), layouts.structs[0].data_words);
    try std.testing.expectEqual(@as(u16, 1), layouts.structs[0].pointer_count);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, layouts.structs[0].fields[0].slot);

    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Color = enum(u16)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "green = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn color(self: @This()) !@\"cpz.schema\".Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getUInt16(0, 1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_color(self: Builder, new_value: @\"cpz.schema\".Color) !void") != null);
}
