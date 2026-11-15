const std = @import("std");
const message = @import("../message.zig");
const serialize = @import("../serialize.zig");
const wire = @import("../wire.zig");
const frontend = @import("frontend.zig");

threadlocal var emit_metadata_enabled: bool = true;

pub const Error = frontend.Error;
pub const Type = frontend.Type;
pub const Field = frontend.Field;
pub const AliasDecl = frontend.AliasDecl;
pub const AliasMetadata = frontend.AliasMetadata;
pub const ConstDecl = frontend.ConstDecl;
pub const ConstListItem = frontend.ConstListItem;
pub const ConstStructField = frontend.ConstStructField;
pub const ConstMetadata = frontend.ConstMetadata;
pub const ImportDecl = frontend.ImportDecl;
pub const ImportMetadata = frontend.ImportMetadata;
pub const UnionDecl = frontend.UnionDecl;
pub const GroupDecl = frontend.GroupDecl;
pub const Struct = frontend.Struct;
pub const EnumValue = frontend.EnumValue;
pub const EnumValueMetadata = frontend.EnumValueMetadata;
pub const FieldMetadata = frontend.FieldMetadata;
pub const UnionMetadata = frontend.UnionMetadata;
pub const DeclarationKind = frontend.DeclarationKind;
pub const DeclarationMetadata = frontend.DeclarationMetadata;
pub const EnumDecl = frontend.EnumDecl;
pub const MethodField = frontend.MethodField;
pub const InterfaceMethod = frontend.InterfaceMethod;
pub const InterfaceMethodMetadata = frontend.InterfaceMethodMetadata;
pub const InterfaceSuperclassMetadata = frontend.InterfaceSuperclassMetadata;
pub const InterfaceDecl = frontend.InterfaceDecl;
pub const AnnotationTargets = frontend.AnnotationTargets;
pub const annotationTargetsHas = frontend.annotationTargetsHas;
pub const AnnotationDecl = frontend.AnnotationDecl;
pub const AnnotationMetadata = frontend.AnnotationMetadata;
pub const FileAnnotationMetadata = frontend.FileAnnotationMetadata;
pub const File = frontend.File;
pub const LayoutError = frontend.LayoutError;
pub const FieldSlot = frontend.FieldSlot;
pub const FieldLayout = frontend.FieldLayout;
pub const UnionLayout = frontend.UnionLayout;
pub const StructLayout = frontend.StructLayout;
pub const LayoutFile = frontend.LayoutFile;
pub const Parser = frontend.Parser;
pub const parse = frontend.parse;
pub const EmbedError = frontend.EmbedError;
pub const loadEmbeddedConstValues = frontend.loadEmbeddedConstValues;
pub const planLayouts = frontend.planLayouts;
pub const planStructLayout = frontend.planStructLayout;
pub const typesEqual = frontend.typesEqual;
pub const deinitConstListItems = frontend.deinitConstListItems;
pub const parseConstStructFieldsAlloc = frontend.parseConstStructFieldsAlloc;
pub const UnionBuilder = frontend.UnionBuilder;
pub const allAnnotationTargets = frontend.allAnnotationTargets;
pub const TokenTag = frontend.TokenTag;
pub const Token = frontend.Token;
pub const skipLineCommentIndex = frontend.skipLineCommentIndex;
pub const skipBlockCommentIndexOrNull = frontend.skipBlockCommentIndexOrNull;
pub const skipBlockCommentIndex = frontend.skipBlockCommentIndex;
pub const skipRawSlashIndex = frontend.skipRawSlashIndex;
pub const skipRawStringIndex = frontend.skipRawStringIndex;
pub const skipRawStringOrCommentIndex = frontend.skipRawStringOrCommentIndex;
pub const skipRawStringOrCommentInPostLoop = frontend.skipRawStringOrCommentInPostLoop;
pub const skipTriviaIndex = frontend.skipTriviaIndex;
pub const skipTriviaIndexOrNull = frontend.skipTriviaIndexOrNull;
pub const Lexer = frontend.Lexer;
pub const loadEmbeddedConstValuesInScope = frontend.loadEmbeddedConstValuesInScope;
pub const embeddedConstPathAlloc = frontend.embeddedConstPathAlloc;
pub const EmbeddedSegmentRange = frontend.EmbeddedSegmentRange;
pub const embeddedFlatSegmentRangesAlloc = frontend.embeddedFlatSegmentRangesAlloc;
pub const validateEmbeddedStructBytes = frontend.validateEmbeddedStructBytes;
pub const putFieldName = frontend.putFieldName;
pub const appendUnionFields = frontend.appendUnionFields;
pub const validateStructMemberOrdinals = frontend.validateStructMemberOrdinals;
pub const unionDeclsFromBuilders = frontend.unionDeclsFromBuilders;
pub const validateFileTypeApplications = frontend.validateFileTypeApplications;
pub const validateFileSimpleNamedTypes = frontend.validateFileSimpleNamedTypes;
pub const validateFieldOptionalPointerType = frontend.validateFieldOptionalPointerType;
pub const typeCanBeOptionalPointerField = frontend.typeCanBeOptionalPointerField;
pub const validateFileConstReferenceCycles = frontend.validateFileConstReferenceCycles;
pub const validateConstReferenceCycleDecl = frontend.validateConstReferenceCycleDecl;
pub const constDeclLiteralCanBeReference = frontend.constDeclLiteralCanBeReference;
pub const ownerNameScope = frontend.ownerNameScope;
pub const sameOptionalTypeName = frontend.sameOptionalTypeName;
pub const validateFileAggregateDefaults = frontend.validateFileAggregateDefaults;
pub const validateFieldDefaultValue = frontend.validateFieldDefaultValue;
pub const defaultLiteralIsValidBareLiteral = frontend.defaultLiteralIsValidBareLiteral;
pub const defaultConstTypeCompatibleScoped = frontend.defaultConstTypeCompatibleScoped;
pub const defaultConstTypeCompatibleScopedDepth = frontend.defaultConstTypeCompatibleScopedDepth;
pub const isEnumLikeNameRelative = frontend.isEnumLikeNameRelative;
pub const isInterfaceLikeNameRelative = frontend.isInterfaceLikeNameRelative;
pub const isStructLikeNameRelative = frontend.isStructLikeNameRelative;
pub const defaultConstTypeCompatible = frontend.defaultConstTypeCompatible;
pub const validateInterfaceSuperclass = frontend.validateInterfaceSuperclass;
pub const validateFileAliasCycles = frontend.validateFileAliasCycles;
pub const aliasTargetReferencesAlias = frontend.aliasTargetReferencesAlias;
pub const aliasReferenceHeadAlloc = frontend.aliasReferenceHeadAlloc;
pub const findAliasTargetInOwnerScope = frontend.findAliasTargetInOwnerScope;
pub const findAliasTargetInList = frontend.findAliasTargetInList;
pub const validateConstAggregateDefault = frontend.validateConstAggregateDefault;
pub const validateConstReferenceDefaultValue = frontend.validateConstReferenceDefaultValue;
pub const validateReferenceLikeDefaultLiteral = frontend.validateReferenceLikeDefaultLiteral;
pub const validateMethodFieldDefaultValue = frontend.validateMethodFieldDefaultValue;
pub const validateTypeAggregateDefault = frontend.validateTypeAggregateDefault;
pub const resolveTypeApplicationSuffixAliasAlloc = frontend.resolveTypeApplicationSuffixAliasAlloc;
pub const resolveAppliedAliasInScopeAlloc = frontend.resolveAppliedAliasInScopeAlloc;
pub const resolveAliasSuffixAlloc = frontend.resolveAliasSuffixAlloc;
pub const resolveQualifiedAliasSuffixAlloc = frontend.resolveQualifiedAliasSuffixAlloc;
pub const namedTypeResolvesToGenericParameter = frontend.namedTypeResolvesToGenericParameter;
pub const effectiveNamedTypeNameAlloc = frontend.effectiveNamedTypeNameAlloc;
pub const prefixRelativeAliasTargetAlloc = frontend.prefixRelativeAliasTargetAlloc;
pub const findAliasDeclInList = frontend.findAliasDeclInList;
pub const TypeApplicationBindings = frontend.TypeApplicationBindings;
pub const typeApplicationBindingsAlloc = frontend.typeApplicationBindingsAlloc;
pub const validateAnyPointerLikeDefault = frontend.validateAnyPointerLikeDefault;
pub const parameterNameInScope = frontend.parameterNameInScope;
pub const nonNullDefaultType = frontend.nonNullDefaultType;
pub const nonNullResolvedDefaultType = frontend.nonNullResolvedDefaultType;
pub const findStructFieldByNameOrGroupFirst = frontend.findStructFieldByNameOrGroupFirst;
pub const UnionRequirement = frontend.UnionRequirement;
pub const countUnions = frontend.countUnions;
pub const dataRangeEnd = frontend.dataRangeEnd;
pub const checkedUnionIndex = frontend.checkedUnionIndex;
pub const hashMapCapacityCount = frontend.hashMapCapacityCount;
pub const computeUnionRelativeSlotsAlloc = frontend.computeUnionRelativeSlotsAlloc;
pub const countUnionMembers = frontend.countUnionMembers;
pub const unionMemberRelativeSlot = frontend.unionMemberRelativeSlot;
pub const absoluteUnionFieldSlot = frontend.absoluteUnionFieldSlot;
pub const BitRange = frontend.BitRange;
pub const allocateDataBits = frontend.allocateDataBits;
pub const rangesOverlap = frontend.rangesOverlap;
pub const nextOrdinalFieldIndex = frontend.nextOrdinalFieldIndex;
pub const nextOrdinalFieldIndexChecked = frontend.nextOrdinalFieldIndexChecked;
pub const TypeClass = frontend.TypeClass;
pub const classify = frontend.classify;
pub const classifyScoped = frontend.classifyScoped;
pub const findEnum = frontend.findEnum;
pub const findEnumRelative = frontend.findEnumRelative;
pub const findEnumDirect = frontend.findEnumDirect;
pub const findStructDirect = frontend.findStructDirect;
pub const findStructInOwnerScope = frontend.findStructInOwnerScope;
pub const findInterface = frontend.findInterface;
pub const builtin_capability_interface = frontend.builtin_capability_interface;
pub const findInterfaceDirect = frontend.findInterfaceDirect;
pub const findInterfaceInOwnerScope = frontend.findInterfaceInOwnerScope;
pub const findAnnotationDirect = frontend.findAnnotationDirect;
pub const firstTopLevelDot = frontend.firstTopLevelDot;
pub const lastTopLevelDot = frontend.lastTopLevelDot;
pub const typeNameEqualsCanonical = frontend.typeNameEqualsCanonical;
pub const typeApplicationOpen = frontend.typeApplicationOpen;
pub const declarationParameterCount = frontend.declarationParameterCount;
pub const declarationParameterCountInOwnerScope = frontend.declarationParameterCountInOwnerScope;
pub const validateRawTypeApplicationArity = frontend.validateRawTypeApplicationArity;
pub const isBuiltinTypeApplicationBase = frontend.isBuiltinTypeApplicationBase;
pub const isBuiltinSchemaTypeName = frontend.isBuiltinSchemaTypeName;
pub const isEnumTypeApplicationBase = frontend.isEnumTypeApplicationBase;
pub const isEnumDirectInOwnerScope = frontend.isEnumDirectInOwnerScope;
pub const isStructDirectInOwnerScope = frontend.isStructDirectInOwnerScope;
pub const isInterfaceDirectInOwnerScope = frontend.isInterfaceDirectInOwnerScope;
pub const isAnnotationDirectInOwnerScope = frontend.isAnnotationDirectInOwnerScope;
pub const validateTypeReference = frontend.validateTypeReference;
pub const validateTypeApplicationArity = frontend.validateTypeApplicationArity;
pub const validateRawTypeReference = frontend.validateRawTypeReference;
pub const validateMethodFieldTypeReference = frontend.validateMethodFieldTypeReference;
pub const validateMethodTypeReference = frontend.validateMethodTypeReference;
pub const validateSimpleNamedTypeExists = frontend.validateSimpleNamedTypeExists;
pub const canonicalTypeNameAlloc = frontend.canonicalTypeNameAlloc;
pub const isImportedTypeName = frontend.isImportedTypeName;
pub const isImportedAliasName = frontend.isImportedAliasName;
pub const isStructLikeName = frontend.isStructLikeName;
pub const resolveType = frontend.resolveType;
pub const resolveTypeScoped = frontend.resolveTypeScoped;
pub const resolveNamedAlias = frontend.resolveNamedAlias;
pub const isSimpleConstType = frontend.isSimpleConstType;
pub const typeAcceptsTextLiteral = frontend.typeAcceptsTextLiteral;
pub const typeAcceptsDataLiteral = frontend.typeAcceptsDataLiteral;
pub const anonymousAliasName = frontend.anonymousAliasName;
pub const anonymousAliasNameFromRaw = frontend.anonymousAliasNameFromRaw;
pub const importNameFromPath = frontend.importNameFromPath;
pub const capitalizedImportNameAlloc = frontend.capitalizedImportNameAlloc;
pub const isGroupType = frontend.isGroupType;
pub const alignForwardChecked = frontend.alignForwardChecked;
pub const parseInteger = frontend.parseInteger;
pub const isIdentStart = frontend.isIdentStart;
pub const isSchemaIdentifier = frontend.isSchemaIdentifier;
pub const isIdentContinue = frontend.isIdentContinue;
pub const defaultLiteralCanBeReference = frontend.defaultLiteralCanBeReference;
pub const defaultLiteralIsSignedNumber = frontend.defaultLiteralIsSignedNumber;
pub const isNumberContinue = frontend.isNumberContinue;

pub const CodegenOptions = struct {
    runtime_import_name: []const u8 = "cpz",
    raw_schema_comment: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    /// Emit schema introspection tables and `@"cpz.*"` lookup helpers.
    /// Disable this for a lean generated API that only contains wire accessors.
    emit_metadata: bool = true,
};

/// Generate Zig accessors with default options. The caller owns the result.
pub fn generateZig(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile) LayoutError![]u8 {
    return generateZigWithOptions(allocator, file, layouts, .{});
}

/// Generate Zig accessors with explicit options. The caller owns the result.
pub fn generateZigWithOptions(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile, options: CodegenOptions) LayoutError![]u8 {
    try validateZigNameCollisions(allocator, file);

    const previous_emit_metadata = emit_metadata_enabled;
    emit_metadata_enabled = options.emit_metadata;
    defer emit_metadata_enabled = previous_emit_metadata;

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (options.raw_schema_comment) |source| {
        try appendRawSchemaComment(allocator, &out, source);
    }
    const runtime_import_literal = try zigRawStringLiteralAlloc(allocator, options.runtime_import_name);
    defer allocator.free(runtime_import_literal);
    if (options.namespace == null) {
        try appendFmt(allocator, &out,
            \\const std = @import("std");
            \\const cpz = @import({s});
            \\const @"cpz.schema" = @This();
            \\
            \\
        , .{runtime_import_literal});
    } else {
        try appendFmt(allocator, &out,
            \\const std = @import("std");
            \\const cpz = @import({s});
            \\
            \\
        , .{runtime_import_literal});
    }
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
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, annotation_raw);
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
    if (!emit_metadata_enabled) stripRootHelperBlocks(&out);
    return out.toOwnedSlice(allocator);
}

pub fn stripRootHelperBlocks(out: *std.ArrayList(u8)) void {
    const start_marker = "    pub fn @\"cpz.root.isNull\"";
    const end_marker = "    pub fn fromReader(@\"cpz.reader\": cpz.StructReader)";
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, out.items, search_start, start_marker)) |start| {
        const end = std.mem.indexOfPos(u8, out.items, start, end_marker) orelse break;
        const remove_len = end - start;
        std.mem.copyForwards(u8, out.items[start..], out.items[end..]);
        out.items.len -= remove_len;
        search_start = start;
    }
}

pub fn appendRawSchemaComment(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8) std.mem.Allocator.Error!void {
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

pub fn zigNamesEqual(allocator: std.mem.Allocator, lhs_raw: []const u8, rhs_raw: []const u8) std.mem.Allocator.Error!bool {
    const lhs = try zigIdentAlloc(allocator, lhs_raw);
    defer allocator.free(lhs);
    const rhs = try zigIdentAlloc(allocator, rhs_raw);
    defer allocator.free(rhs);
    return std.mem.eql(u8, lhs, rhs);
}

pub fn emitDeclarationAnnotations(allocator: std.mem.Allocator, out: *std.ArrayList(u8), annotations: []const u8, indent: []const u8) LayoutError!void {
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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

pub const AnyPointerDefaultKind = enum { any, struct_ptr, list };

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

pub fn resolveConstDeclType(file: *const File, scope: ?*const Struct, decl: *const ConstDecl) Type {
    if (constDeclOwnerName(file, decl)) |owner_name| {
        return resolveTypeInOwnerScope(file, owner_name, decl.ty);
    }
    return resolveTypeScoped(file, scope, decl.ty);
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

pub fn typeAcceptsNullPointerDefault(file: *const File, ty: Type) bool {
    return switch (ty) {
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => true,
        .named => |type_name| findEnum(file, type_name) == null,
        else => false,
    };
}

pub fn typeAcceptsVoidPointerDefault(file: *const File, ty: Type) bool {
    return switch (ty) {
        .any_pointer, .any_struct, .any_list, .capability => true,
        .named => |type_name| findInterface(file, type_name) != null,
        else => false,
    };
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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

pub fn annotationOwnerName(annotation_name: []const u8) ?[]const u8 {
    const dot = lastTopLevelDot(annotation_name) orelse return null;
    return annotation_name[0..dot];
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

pub fn resolveTypeInOwnerScope(file: *const File, owner_name: ?[]const u8, ty: Type) Type {
    return switch (ty) {
        .named => |name| resolveNamedAliasInOwnerScope(file, owner_name, name, 0) orelse ty,
        else => ty,
    };
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

pub fn declHasParameter(parameters: []const []const u8, name: []const u8) bool {
    for (parameters) |parameter| {
        if (std.mem.eql(u8, parameter, name)) return true;
    }
    return false;
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

pub fn emitFileAnnotationMetadataTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), annotations_raw: []const []const u8, indent: []const u8) LayoutError!void {
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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

pub const LayoutSpecialization = struct {
    fields: []Field = &.{},
    field_layouts: []FieldLayout = &.{},
    owned_names: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *LayoutSpecialization, allocator: std.mem.Allocator) void {
        for (self.fields) |*field| field.ty.deinit(allocator);
        allocator.free(self.fields);
        allocator.free(self.field_layouts);
        for (self.owned_names.items) |name| allocator.free(name);
        self.owned_names.deinit(allocator);
        self.* = undefined;
    }
};

pub fn scalarOrNamedType(name: []const u8) Type {
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

pub fn specializeLayoutForTypeApplicationAlloc(allocator: std.mem.Allocator, type_name: []const u8, layout: *StructLayout) LayoutError!?LayoutSpecialization {
    if (layout.decl.parameters.len == 0) return null;
    const args = (try splitTypeApplicationArgsAlloc(allocator, type_name)) orelse return null;
    defer {
        for (args) |*arg| arg.deinit(allocator);
        allocator.free(args);
    }
    if (args.len == 0) return null;
    var specialization = LayoutSpecialization{};
    errdefer specialization.deinit(allocator);
    specialization.fields = try allocator.alloc(Field, layout.fields.len);
    specialization.field_layouts = try allocator.alloc(FieldLayout, layout.fields.len);
    for (layout.fields, 0..) |field_layout, index| {
        specialization.fields[index] = field_layout.field.*;
        specialization.fields[index].ty = try substituteGenericTypeAlloc(allocator, &specialization.owned_names, field_layout.field.ty, layout.decl.parameters, args);
        specialization.field_layouts[index] = field_layout;
        specialization.field_layouts[index].field = &specialization.fields[index];
    }
    layout.fields = specialization.field_layouts;
    return specialization;
}

pub fn structListLiteralFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl) LayoutError!?[]u8 {
    const items = decl.list_items orelse return null;
    const child = switch (resolveTypeScoped(file, scope, decl.ty)) {
        .list => |list_child| list_child.*,
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .list => |list_child| list_child.*,
            else => return null,
        },
        else => return null,
    };
    const type_name = switch (resolveTypeScoped(file, scope, child)) {
        .named => |name| name,
        else => return null,
    };
    return listStructItemsFlatBytesAlloc(allocator, file, scope, type_name, items) catch |err| switch (err) {
        error.UnsupportedType => return null,
        else => return err,
    };
}

pub fn writeStructListItemIntoSegment(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    struct_decl: *const Struct,
    layout: *const StructLayout,
    item: ConstListItem,
    segment: *std.ArrayList(u8),
    object_start_words: usize,
    depth: usize,
) LayoutError!void {
    if (depth >= 32) return error.UnsupportedType;
    if (item.struct_fields.len != 0) {
        try writeStructLiteralFieldsIntoSegment(allocator, file, scope, layout, item.struct_fields, segment, object_start_words);
        return;
    }

    if (findConstReference(file, scope, item.literal)) |decl| {
        var decl_scope_fields: [0]Field = .{};
        var decl_scope_storage: Struct = undefined;
        const decl_scope = constDeclResolutionScope(file, scope, decl, decl_scope_fields[0..], &decl_scope_storage);
        if (decl.struct_fields) |fields| {
            try writeStructLiteralFieldsIntoSegment(allocator, file, decl_scope, layout, fields, segment, object_start_words);
            return;
        }
        try writeStructListItemIntoSegment(
            allocator,
            file,
            decl_scope,
            struct_decl,
            layout,
            .{ .index = item.index, .literal = decl.literal },
            segment,
            object_start_words,
            depth + 1,
        );
        return;
    }

    const fields = try parseStructLiteralOrImpliedFirstFieldAlloc(allocator, struct_decl, item.literal);
    defer allocator.free(fields);
    try writeStructLiteralFieldsIntoSegment(allocator, file, scope, layout, fields, segment, object_start_words);
}

pub fn listStructItemsFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, items: []const ConstListItem) LayoutError![]u8 {
    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const element_words = @as(usize, layout.data_words) + @as(usize, layout.pointer_count);
    if (element_words == 0) return error.UnsupportedType;
    const content_words = std.math.mul(usize, element_words, items.len) catch return error.SerializedSizeOverflow;

    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    const total_words = std.math.add(usize, content_words, 2) catch return error.SerializedSizeOverflow;
    const total_bytes = std.math.mul(usize, total_words, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
    try segment.appendNTimes(allocator, 0, total_bytes);
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .composite, content_words));
    writeWordBytes(segment.items[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeStructListTag(items.len, .{ .data_words = layout.data_words, .pointer_count = layout.pointer_count }));

    for (items) |item| {
        const element_offset = std.math.mul(usize, item.index, element_words) catch return error.SerializedSizeOverflow;
        const element_target = std.math.add(usize, 2, element_offset) catch return error.SerializedSizeOverflow;
        try writeStructListItemIntoSegment(allocator, file, scope, struct_decl, &layout, item, &segment, element_target, 0);
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn appendStructListItemPointer(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    segment: *std.ArrayList(u8),
    element_index: usize,
    list_start_words: usize,
    type_name: []const u8,
    item: ConstListItem,
) LayoutError!void {
    var item_segment = std.ArrayList(u8).empty;
    defer item_segment.deinit(allocator);

    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const object_words = @as(usize, layout.data_words) + @as(usize, layout.pointer_count);
    if (object_words == 0) return error.UnsupportedType;
    try item_segment.appendNTimes(allocator, 0, try wordByteLen(object_words));
    try writeStructListItemIntoSegment(allocator, file, scope, struct_decl, &layout, item, &item_segment, 0, 0);

    const pointer_word_index = try pointerListElementWordIndex(list_start_words, element_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    try segment.appendSlice(allocator, item_segment.items);
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeStruct(offset, layout.data_words, layout.pointer_count));
}

pub fn structLiteralTypeName(file: *const File, scope: ?*const Struct, ty: Type) ?[]const u8 {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .named => |name| name,
        .optional => |child| switch (resolveTypeScoped(file, scope, child.*)) {
            .named => |name| name,
            else => null,
        },
        else => null,
    };
}

pub fn structLiteralFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl) LayoutError!?[]u8 {
    if (!decl.is_struct_literal) return null;
    const type_name = structLiteralTypeName(file, scope, decl.ty) orelse return null;
    const struct_decl = findStructDirect(file, type_name) orelse return null;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const original_layout_fields = layout.fields;
    var specialization = try specializeLayoutForTypeApplicationAlloc(allocator, type_name, &layout) orelse LayoutSpecialization{};
    defer {
        layout.fields = original_layout_fields;
        specialization.deinit(allocator);
    }
    const fields = decl.struct_fields orelse return null;

    const object = try structLiteralObjectBytesAlloc(allocator, file, scope, &layout, fields, true) orelse return null;
    defer allocator.free(object);
    const segment_words = object.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(object.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], object);
    return flat;
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

pub fn appendInlineListPointer(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, element_size: wire.ElementSize, element_count: usize) LayoutError![]u8 {
    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    const list_words = try wire.wordsForList(element_size, element_count);
    try segment.appendNTimes(allocator, 0, try wordByteLen(list_words));
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    const raw = try wire.encodeList(offset, element_size, element_count);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], raw);
    return segment.items[try wordByteOffset(target_word_index)..][0..try wordByteLen(list_words)];
}

pub fn inlineQuotedStringBytesAlloc(allocator: std.mem.Allocator, expression: []const u8) LayoutError![]u8 {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    var index: usize = 0;
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var saw_string = false;

    while (true) {
        index = try skipTriviaIndex(source, index);
        if (index >= source.len) break;
        if (source[index] != '"') return error.UnsupportedType;
        index += 1;
        const content_start = index;
        while (index < source.len) {
            if (source[index] == '\\') {
                index += 2;
            } else if (source[index] == '"') {
                break;
            } else {
                index += 1;
            }
        }
        if (index >= source.len) return error.UnexpectedToken;
        const decoded = try decodedStringBytesAlloc(allocator, source[content_start..index]);
        defer allocator.free(decoded);
        try out.appendSlice(allocator, decoded);
        saw_string = true;
        index += 1;
    }

    if (!saw_string) return error.UnsupportedType;
    return out.toOwnedSlice(allocator);
}

pub fn inlineDataBytesAlloc(allocator: std.mem.Allocator, expression: []const u8) LayoutError![]u8 {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    if (std.mem.startsWith(u8, source, "0x\"") and source.len >= 4 and source[source.len - 1] == '"') {
        return try hexBytesAlloc(allocator, source[3 .. source.len - 1]);
    }
    return inlineQuotedStringBytesAlloc(allocator, source);
}

pub fn appendPointerListPointer(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, element_count: usize) LayoutError!usize {
    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    const list_words = try wire.wordsForList(.pointer, element_count);
    try segment.appendNTimes(allocator, 0, try wordByteLen(list_words));
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    const raw = try wire.encodeList(offset, .pointer, element_count);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], raw);
    return target_word_index;
}

pub fn appendPointerListOfByteLists(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, items: []const []const u8, comptime text_items: bool) LayoutError!void {
    const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
    for (items, 0..) |item, index| {
        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item, text_items)) orelse ((if (text_items)
            inlineQuotedStringBytesAlloc(allocator, item)
        else
            inlineDataBytesAlloc(allocator, item)) catch |err| switch (err) {
            error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
            else => return err,
        });
        defer allocator.free(bytes);
        try appendByteListPointerAtWord(allocator, segment, try pointerListElementWordIndex(list_start_words, index), bytes, text_items);
    }
}

pub fn parseStructLiteralOrImpliedFirstFieldAlloc(allocator: std.mem.Allocator, struct_decl: *const Struct, literal: []const u8) LayoutError![]ConstStructField {
    return parseConstStructFieldsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => {
            const raw = std.mem.trim(u8, literal, " \t\r\n");
            if (raw.len == 0 or raw[0] == '(') return error.UnsupportedType;
            if (struct_decl.fields.len == 0) return error.UnsupportedType;
            const fields = try allocator.alloc(ConstStructField, 1);
            fields[0] = .{ .index = 0, .name = struct_decl.fields[0].name, .literal = raw };
            return fields;
        },
        else => return err,
    };
}

pub fn appendStructLiteralPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, type_name: []const u8, literal: []const u8) LayoutError!void {
    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var nested_layout = try planStructLayout(allocator, file, struct_decl);
    defer nested_layout.deinit(allocator);
    const original_nested_layout_fields = nested_layout.fields;
    var nested_specialization = try specializeLayoutForTypeApplicationAlloc(allocator, type_name, &nested_layout) orelse LayoutSpecialization{};
    defer {
        nested_layout.fields = original_nested_layout_fields;
        nested_specialization.deinit(allocator);
    }
    const fields = try parseStructLiteralOrImpliedFirstFieldAlloc(allocator, struct_decl, literal);
    defer allocator.free(fields);

    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const object_words = @as(usize, nested_layout.data_words) + @as(usize, nested_layout.pointer_count);
    if (object_words == 0) {
        if (fields.len != 0) return error.UnsupportedType;
        writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeStruct(-1, 0, 0));
        return;
    }

    const target_word_index = segment.items.len / @sizeOf(u64);
    try segment.appendNTimes(allocator, 0, try wordByteLen(object_words));
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeStruct(offset, nested_layout.data_words, nested_layout.pointer_count));
    try writeStructLiteralFieldsIntoSegment(allocator, file, scope, &nested_layout, fields, segment, target_word_index);
}

pub fn appendStructListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, type_name: []const u8, literal: []const u8) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);
    const struct_decl = findStructDirect(file, type_name) orelse return error.UnsupportedType;
    var element_layout = try planStructLayout(allocator, file, struct_decl);
    defer element_layout.deinit(allocator);
    const original_element_layout_fields = element_layout.fields;
    var element_specialization = try specializeLayoutForTypeApplicationAlloc(allocator, type_name, &element_layout) orelse LayoutSpecialization{};
    defer {
        element_layout.fields = original_element_layout_fields;
        element_specialization.deinit(allocator);
    }
    const element_words = @as(usize, element_layout.data_words) + @as(usize, element_layout.pointer_count);
    if (element_words == 0) return error.UnsupportedType;
    const content_words = std.math.mul(usize, element_words, items.len) catch return error.SerializedSizeOverflow;

    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    const target_word_index = segment.items.len / @sizeOf(u64);
    const appended_words = std.math.add(usize, content_words, 1) catch return error.SerializedSizeOverflow;
    const appended_bytes = std.math.mul(usize, appended_words, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
    try segment.appendNTimes(allocator, 0, appended_bytes);
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], try wire.encodeList(offset, .composite, content_words));
    writeWordBytes(segment.items[try wordByteOffset(target_word_index)..][0..@sizeOf(u64)], try wire.encodeStructListTag(items.len, .{ .data_words = element_layout.data_words, .pointer_count = element_layout.pointer_count }));

    for (items, 0..) |item, index| {
        const fields = try parseStructLiteralOrImpliedFirstFieldAlloc(allocator, struct_decl, item);
        defer allocator.free(fields);
        const element_offset = std.math.mul(usize, index, element_words) catch return error.SerializedSizeOverflow;
        const elements_start = std.math.add(usize, target_word_index, 1) catch return error.SerializedSizeOverflow;
        const element_target = std.math.add(usize, elements_start, element_offset) catch return error.SerializedSizeOverflow;
        try writeStructLiteralFieldsIntoSegment(allocator, file, scope, &element_layout, fields, segment, element_target);
    }
}

pub fn appendScalarListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, child_ty: Type, literal: []const u8) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);
    switch (resolveTypeScoped(file, scope, child_ty)) {
        .void => {
            _ = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .void, items.len);
            for (items) |item| if (!std.mem.eql(u8, resolveScalarConstLiteral(file, scope, item), "void")) return error.UnsupportedType;
        },
        .bool => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .bit, items.len);
            for (items, 0..) |item, index| {
                const value = parseBoolLiteral(resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                if (value) setBit(data, index);
            }
        },
        .int8 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .byte, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i8, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                data[index] = @bitCast(value);
            }
        },
        .int16 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .two_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i16, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u16, data[index * @sizeOf(u16) ..][0..@sizeOf(u16)], @bitCast(value), .little);
            }
        },
        .int32 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .four_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i32, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u32, data[index * @sizeOf(u32) ..][0..@sizeOf(u32)], @bitCast(value), .little);
            }
        },
        .int64 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .eight_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseSignedLiteral(i64, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u64, data[try wordByteOffset(index)..][0..@sizeOf(u64)], @bitCast(value), .little);
            }
        },
        .uint8 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .byte, items.len);
            for (items, 0..) |item, index| {
                data[index] = parseUnsignedLiteral(u8, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
            }
        },
        .uint16 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .two_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseUnsignedLiteral(u16, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u16, data[index * @sizeOf(u16) ..][0..@sizeOf(u16)], value, .little);
            }
        },
        .uint32 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .four_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseUnsignedLiteral(u32, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u32, data[index * @sizeOf(u32) ..][0..@sizeOf(u32)], value, .little);
            }
        },
        .uint64 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .eight_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseUnsignedLiteral(u64, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u64, data[try wordByteOffset(index)..][0..@sizeOf(u64)], value, .little);
            }
        },
        .float32 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .four_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseFloatLiteral(f32, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u32, data[index * @sizeOf(u32) ..][0..@sizeOf(u32)], @bitCast(value), .little);
            }
        },
        .float64 => {
            const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .eight_bytes, items.len);
            for (items, 0..) |item, index| {
                const value = parseFloatLiteral(f64, resolveScalarConstLiteral(file, scope, item)) orelse return error.UnsupportedType;
                std.mem.writeInt(u64, data[try wordByteOffset(index)..][0..@sizeOf(u64)], @bitCast(value), .little);
            }
        },
        .text => try appendPointerListOfByteLists(allocator, file, scope, segment, pointer_index, data_words, object_start_words, items, true),
        .data => try appendPointerListOfByteLists(allocator, file, scope, segment, pointer_index, data_words, object_start_words, items, false),
        .list => |child| {
            const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
            for (items, 0..) |item, index| {
                try appendScalarListPointer(allocator, file, scope, segment, 0, 0, try pointerListElementWordIndex(list_start_words, index), child.*, item);
            }
        },
        .named => |type_name| {
            if (findEnum(file, type_name)) |enum_decl| {
                const data = try appendInlineListPointer(allocator, segment, pointer_index, data_words, object_start_words, .two_bytes, items.len);
                for (items, 0..) |item, index| {
                    const value = resolvedEnumLiteralOrdinal(file, scope, enum_decl, item) orelse return error.UnsupportedType;
                    std.mem.writeInt(u16, data[index * @sizeOf(u16) ..][0..@sizeOf(u16)], value, .little);
                }
            } else {
                try appendStructListPointer(allocator, file, scope, segment, pointer_index, data_words, object_start_words, type_name, literal);
            }
        },
        else => return error.UnsupportedType,
    }
}

pub fn appendStructPointerFieldLiteral(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, layout: *const StructLayout, segment: *std.ArrayList(u8), pointer_index: usize, object_start_words: usize, ty: Type, literal: []const u8) LayoutError!void {
    const literal_scope = scope orelse layout.decl;
    const const_ref = findConstReference(file, literal_scope, literal);
    const resolved_literal = resolveConstReferenceLiteral(file, literal_scope, literal);
    switch (resolveTypeScoped(file, layout.decl, ty)) {
        .text => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, layout.decl, decl) == .text) {
                    const text = try constBlobBytesAlloc(allocator, file, literal_scope, decl, true);
                    defer allocator.free(text);
                    try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, text, true, object_start_words);
                    return;
                }
            }
            const text = inlineQuotedStringBytesAlloc(allocator, resolved_literal) catch |err| switch (err) {
                error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
                else => return err,
            };
            defer allocator.free(text);
            try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, text, true, object_start_words);
        },
        .data => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, layout.decl, decl) == .data) {
                    const data = try constBlobBytesAlloc(allocator, file, literal_scope, decl, false);
                    defer allocator.free(data);
                    try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, data, false, object_start_words);
                    return;
                }
            }
            const data = inlineDataBytesAlloc(allocator, resolved_literal) catch |err| switch (err) {
                error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
                else => return err,
            };
            defer allocator.free(data);
            try appendByteListPointer(allocator, segment, pointer_index, layout.data_words, data, false, object_start_words);
        },
        .list => |child| try appendScalarListPointer(allocator, file, literal_scope, segment, pointer_index, layout.data_words, object_start_words, child.*, resolved_literal),
        .any_pointer => {
            if (const_ref) |decl| {
                return appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, decl.ty, decl.literal);
            }
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .any_struct => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, literal_scope, decl) == .named) {
                    return appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, decl.ty, decl.literal);
                }
            }
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .any_list => {
            if (const_ref) |decl| {
                if (resolveConstDeclType(file, literal_scope, decl) == .list) {
                    return appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, decl.ty, decl.literal);
                }
            }
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .capability => {
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
            return error.UnsupportedType;
        },
        .named => |type_name| {
            if (findInterface(file, type_name) != null) {
                const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
                if (std.mem.eql(u8, raw, "void") or std.mem.eql(u8, raw, "null")) return;
                return error.UnsupportedType;
            }
            try appendStructLiteralPointer(allocator, file, literal_scope, segment, pointer_index, layout.data_words, object_start_words, type_name, resolved_literal);
        },
        .optional => |child| {
            const raw = std.mem.trim(u8, resolved_literal, " \t\r\n");
            if (std.mem.eql(u8, raw, "null")) return;
            try appendStructPointerFieldLiteral(allocator, file, literal_scope, layout, segment, pointer_index, object_start_words, child.*, resolved_literal);
        },
        else => return error.UnsupportedType,
    }
}

pub fn writeStructLiteralFieldsIntoSegment(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, layout: *const StructLayout, fields: []const ConstStructField, segment: *std.ArrayList(u8), object_start_words: usize) LayoutError!void {
    const object_start_bytes = try wordByteLen(object_start_words);
    for (fields) |const_field| {
        const field_layout = findFieldLayoutByNameOrGroupFirst(layout, const_field.name) orelse return error.UnsupportedType;
        const field = field_layout.field;
        const literal_scope = scope orelse layout.decl;
        const const_literal = resolveScalarConstLiteral(file, literal_scope, const_field.literal);
        const default_literal = if (field.default_literal) |literal| resolveScalarConstLiteral(file, layout.decl, literal) else null;
        if (field.union_index) |union_index| {
            const union_layout = layout.unions[@intCast(union_index)];
            std.mem.writeInt(u16, segment.items[object_start_bytes + union_layout.discriminant_byte ..][0..@sizeOf(u16)], field.union_discriminant, .little);
        }
        switch (field_layout.slot) {
            .void => {
                if (!std.mem.eql(u8, const_literal, "void")) return error.UnsupportedType;
            },
            .data_bit => |bit_offset| switch (resolveTypeScoped(file, layout.decl, field.ty)) {
                .bool => {
                    const value = parseBoolLiteral(const_literal) orelse return error.UnsupportedType;
                    const default_value = parseBoolLiteral(default_literal orelse "false") orelse return error.UnsupportedType;
                    if (value != default_value) setBit(segment.items[object_start_bytes..], bit_offset);
                },
                else => return error.UnsupportedType,
            },
            .data_byte => |byte_offset| switch (resolveTypeScoped(file, layout.decl, field.ty)) {
                .int8 => {
                    const value = parseSignedLiteral(i8, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i8, default_literal orelse "0") orelse return error.UnsupportedType;
                    segment.items[object_start_bytes + byte_offset] = @as(u8, @bitCast(value)) ^ @as(u8, @bitCast(default_value));
                },
                .int16 => {
                    const value = parseSignedLiteral(i16, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i16, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u16 = @as(u16, @bitCast(value)) ^ @as(u16, @bitCast(default_value));
                    std.mem.writeInt(u16, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u16)], stored, .little);
                },
                .int32 => {
                    const value = parseSignedLiteral(i32, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i32, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u32 = @as(u32, @bitCast(value)) ^ @as(u32, @bitCast(default_value));
                    std.mem.writeInt(u32, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u32)], stored, .little);
                },
                .int64 => {
                    const value = parseSignedLiteral(i64, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseSignedLiteral(i64, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u64 = @as(u64, @bitCast(value)) ^ @as(u64, @bitCast(default_value));
                    std.mem.writeInt(u64, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u64)], stored, .little);
                },
                .uint8 => {
                    const value = parseUnsignedLiteral(u8, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u8, default_literal orelse "0") orelse return error.UnsupportedType;
                    segment.items[object_start_bytes + byte_offset] = value ^ default_value;
                },
                .uint16 => {
                    const value = parseUnsignedLiteral(u16, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u16, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u16 = value ^ default_value;
                    std.mem.writeInt(u16, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u16)], stored, .little);
                },
                .uint32 => {
                    const value = parseUnsignedLiteral(u32, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u32, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u32 = value ^ default_value;
                    std.mem.writeInt(u32, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u32)], stored, .little);
                },
                .uint64 => {
                    const value = parseUnsignedLiteral(u64, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseUnsignedLiteral(u64, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u64 = value ^ default_value;
                    std.mem.writeInt(u64, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u64)], stored, .little);
                },
                .float32 => {
                    const value = parseFloatLiteral(f32, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseFloatLiteral(f32, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u32 = @as(u32, @bitCast(value)) ^ @as(u32, @bitCast(default_value));
                    std.mem.writeInt(u32, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u32)], stored, .little);
                },
                .float64 => {
                    const value = parseFloatLiteral(f64, const_literal) orelse return error.UnsupportedType;
                    const default_value = parseFloatLiteral(f64, default_literal orelse "0") orelse return error.UnsupportedType;
                    const stored: u64 = @as(u64, @bitCast(value)) ^ @as(u64, @bitCast(default_value));
                    std.mem.writeInt(u64, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u64)], stored, .little);
                },
                .named => |field_type_name| {
                    const enum_decl = findEnum(file, field_type_name) orelse return error.UnsupportedType;
                    const value = resolvedEnumLiteralOrdinal(file, literal_scope, enum_decl, const_field.literal) orelse return error.UnsupportedType;
                    const default_value = if (field.default_literal) |literal|
                        try resolvedEnumDefaultOrdinal(file, layout.decl, enum_decl, literal)
                    else
                        0;
                    const stored: u16 = value ^ default_value;
                    std.mem.writeInt(u16, segment.items[object_start_bytes + byte_offset ..][0..@sizeOf(u16)], stored, .little);
                },
                else => return error.UnsupportedType,
            },
            .pointer => |pointer_index| try appendStructPointerFieldLiteral(allocator, file, scope, layout, segment, pointer_index, object_start_words, field.ty, const_field.literal),
        }
    }
}

pub fn structLiteralObjectBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, layout: *const StructLayout, fields: []const ConstStructField, comptime include_root_pointer: bool) LayoutError!?[]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    const object_words = @as(usize, layout.data_words) + @as(usize, layout.pointer_count);
    const object_start_words: usize = if (include_root_pointer) 1 else 0;
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, object_start_words, object_words)));
    if (include_root_pointer) {
        writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeStruct(0, layout.data_words, layout.pointer_count));
    }
    writeStructLiteralFieldsIntoSegment(allocator, file, scope, layout, fields, &segment, object_start_words) catch |err| switch (err) {
        error.UnsupportedType => return null,
        else => return err,
    };
    return try segment.toOwnedSlice(allocator);
}

pub fn findFieldLayoutByName(layout: *const StructLayout, name: []const u8) ?FieldLayout {
    for (layout.fields) |field_layout| {
        if (std.mem.eql(u8, field_layout.field.name, name)) return field_layout;
    }
    return null;
}

pub fn findFieldLayoutByNameOrGroupFirst(layout: *const StructLayout, name: []const u8) ?FieldLayout {
    if (findFieldLayoutByName(layout, name)) |field_layout| return field_layout;
    for (layout.fields) |field_layout| {
        if (field_layout.field.name.len > name.len + 1 and
            std.mem.startsWith(u8, field_layout.field.name, name) and
            field_layout.field.name[name.len] == '_')
        {
            return field_layout;
        }
    }
    return null;
}

pub fn appendByteListPointer(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, bytes: []const u8, nul_terminated: bool, object_start_words: usize) LayoutError!void {
    const pointer_word_index = try structPointerWordIndex(object_start_words, data_words, pointer_index);
    return appendByteListPointerAtWord(allocator, segment, pointer_word_index, bytes, nul_terminated);
}

pub fn appendByteListPointerAtWord(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), pointer_word_index: usize, bytes: []const u8, nul_terminated: bool) LayoutError!void {
    const target_word_index = segment.items.len / @sizeOf(u64);
    const list_len = std.math.add(usize, bytes.len, @intFromBool(nul_terminated)) catch return error.SerializedSizeOverflow;
    const padded_len = try byteListPaddedLen(list_len);
    try segment.appendNTimes(allocator, 0, padded_len);
    const data_start = try wordByteOffset(target_word_index);
    @memcpy(segment.items[data_start..][0..bytes.len], bytes);
    if (nul_terminated) segment.items[data_start + bytes.len] = 0;
    const offset = try wire.offsetFromPointer(pointer_word_index, target_word_index);
    const raw = try wire.encodeList(offset, .byte, list_len);
    writeWordBytes(segment.items[try wordByteOffset(pointer_word_index)..][0..@sizeOf(u64)], raw);
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

pub fn parseUnsignedLiteral(comptime T: type, raw_literal: []const u8) ?T {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    if (raw.len == 0 or raw[0] == '.') return null;
    const digits = if (raw[0] == '+') raw[1..] else raw;
    if (digits.len == 0) return null;
    const value = parseInteger(digits) catch return null;
    if (value > std.math.maxInt(T)) return null;
    return @intCast(value);
}

pub fn parseFloatLiteral(comptime T: type, raw_literal: []const u8) ?T {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    const unsigned = if (std.mem.startsWith(u8, raw, "+")) raw[1..] else raw;
    if (std.mem.eql(u8, unsigned, "inf")) return std.math.inf(T);
    if (std.mem.eql(u8, unsigned, "-inf")) return -std.math.inf(T);
    if (std.mem.eql(u8, unsigned, "nan")) return std.math.nan(T);
    return std.fmt.parseFloat(T, unsigned) catch null;
}

pub fn enumLiteralOrdinal(decl: *const EnumDecl, raw_literal: []const u8) ?u16 {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    const unqualified = if (std.mem.startsWith(u8, raw, ".")) raw[1..] else raw;
    const literal = if (lastTopLevelDot(unqualified)) |dot| unqualified[dot + 1 ..] else unqualified;
    if (literal.len == 0) return null;
    for (decl.values) |value| if (std.mem.eql(u8, value.name, literal)) return value.ordinal;
    return null;
}

pub fn parseBoolLiteral(raw_literal: []const u8) ?bool {
    const raw = std.mem.trim(u8, raw_literal, " \t\r\n");
    if (std.mem.eql(u8, raw, "true")) return true;
    if (std.mem.eql(u8, raw, "false")) return false;
    return null;
}

pub fn setBit(bytes: []u8, bit_offset: usize) void {
    bytes[bit_offset / 8] |= @as(u8, 1) << @as(u3, @intCast(bit_offset % 8));
}

pub fn flatByteLenForSegmentWords(segment_words: usize) LayoutError!usize {
    return flatByteLenForSegmentBytes(try wordByteLen(segment_words));
}

pub fn rootListSegmentWords(data_words: usize) LayoutError!usize {
    return std.math.add(usize, 1, data_words) catch return error.SerializedSizeOverflow;
}

pub fn flatByteLenForSegmentBytes(segment_bytes: usize) LayoutError!usize {
    return std.math.add(usize, @sizeOf(u64), segment_bytes) catch return error.SerializedSizeOverflow;
}

pub fn wordByteLen(word_count: usize) LayoutError!usize {
    return std.math.mul(usize, word_count, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
}

pub fn wordByteOffset(word_index: usize) LayoutError!usize {
    return wordByteLen(word_index);
}

pub fn structPointerWordIndex(object_start_words: usize, data_words: u16, pointer_index: usize) LayoutError!usize {
    const pointer_section_start = std.math.add(usize, object_start_words, data_words) catch return error.SerializedSizeOverflow;
    return std.math.add(usize, pointer_section_start, pointer_index) catch return error.SerializedSizeOverflow;
}

pub fn rootPointerListElementWordIndex(index: usize) LayoutError!usize {
    return std.math.add(usize, 1, index) catch return error.SerializedSizeOverflow;
}

pub fn pointerListElementWordIndex(list_start_words: usize, index: usize) LayoutError!usize {
    return std.math.add(usize, list_start_words, index) catch return error.SerializedSizeOverflow;
}

pub fn byteListPaddedLen(list_len: usize) LayoutError!usize {
    const padded_words = std.math.divCeil(usize, list_len, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
    return std.math.mul(usize, padded_words, @sizeOf(u64)) catch return error.SerializedSizeOverflow;
}

pub fn simpleQuotedTextLiteralAlloc(allocator: std.mem.Allocator, literal: []const u8) LayoutError!?[]u8 {
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (raw.len < 2 or raw[0] != '"' or raw[raw.len - 1] != '"') return null;
    const inner = raw[1 .. raw.len - 1];
    if (std.mem.indexOfScalar(u8, inner, '\\') != null) return null;
    return try allocator.dupe(u8, inner);
}

pub fn simpleDataLiteralAlloc(allocator: std.mem.Allocator, literal: []const u8) LayoutError!?[]u8 {
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (std.mem.startsWith(u8, raw, "0x\"") and raw.len >= 4 and raw[raw.len - 1] == '"') {
        return try hexBytesAlloc(allocator, raw[3 .. raw.len - 1]);
    }
    return simpleQuotedTextLiteralAlloc(allocator, raw);
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

pub fn writeWordBytes(dest: []u8, value: u64) void {
    std.mem.writeInt(u64, dest[0..@sizeOf(u64)], value, .little);
}

pub fn emitEmbeddedStructConst(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    zig_type: []const u8,
    bytes: []const u8,
) LayoutError!void {
    const literal = try zigRawStringLiteralAlloc(allocator, bytes);
    defer allocator.free(literal);
    const ranges = try embeddedFlatSegmentRangesAlloc(allocator, bytes);
    defer allocator.free(ranges);

    try appendFmt(allocator, out,
        \\{s}pub const {s} = struct {{
        \\{s}    pub const flatBytes: []const u8 = {s};
        \\{s}    pub const segmentCount: usize = {};
        \\{s}    pub const serializedSize: usize = flatBytes.len;
        \\
    , .{ indent, name, indent, literal, indent, ranges.len, indent });

    for (ranges, 0..) |range, index| {
        try appendFmt(allocator, out,
            \\{s}    pub const segment{}: []const u8 = flatBytes[{}..{}];
            \\
        , .{ indent, index, range.start, range.end });
    }

    try appendFmt(allocator, out,
        \\{s}    pub const segments: []const []const u8 = &[_][]const u8{{
    , .{indent});
    for (ranges, 0..) |_, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        try appendFmt(allocator, out, "segment{}", .{index});
    }
    try out.appendSlice(allocator, "};\n");

    try appendFmt(allocator, out,
        \\{s}
        \\{s}    pub const Reader = struct {{
        \\{s}        reader: cpz.MessageReader,
        \\
        \\{s}        pub fn init(@"cpz.options": cpz.ReaderOptions) @This() {{
        \\{s}            return .{{ .reader = cpz.MessageReader.init({s}.segments, @"cpz.options") }};
        \\{s}        }}
        \\
        \\{s}        pub fn asReader(self: *@This()) *cpz.MessageReader {{
        \\{s}            return &self.reader;
        \\{s}        }}
        \\
        \\{s}        pub fn root(self: *@This()) !{s} {{
        \\{s}            return {s}.getRoot(&self.reader);
        \\{s}        }}
        \\
        \\{s}        pub fn typedRoot(self: *@This()) !{s} {{
        \\{s}            return self.root();
        \\{s}        }}
        \\
    , .{
        indent,
        indent,
        indent,
        indent,
        indent,
        name,
        indent,
        indent,
        indent,
        indent,
        indent,
        zig_type,
        indent,
        zig_type,
        indent,
        indent,
        zig_type,
        indent,
        indent,
    });
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
        \\{s}    pub fn reader(@"cpz.options": cpz.ReaderOptions) cpz.MessageReader {{
        \\{s}        return cpz.MessageReader.init(@This().segments, @"cpz.options");
        \\{s}    }}
        \\
    , .{
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
    });
    try appendFmt(allocator, out,
        \\{s}    pub fn root(message_reader: *cpz.MessageReader) !{s} {{
        \\{s}        return {s}.getRoot(message_reader);
        \\{s}    }}
        \\
        \\{s}    pub fn typedRoot(message_reader: *cpz.MessageReader) !{s} {{
        \\{s}        return @This().root(message_reader);
        \\{s}    }}
        \\
        \\{s}    pub fn validate(@"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\{s}        var @"cpz.reader" = reader(@"cpz.options");
        \\{s}        return @"cpz.reader".validate();
        \\{s}    }}
        \\
        \\{s}    pub fn matchesSerializedSize(@"cpz.count": usize) bool {{
        \\{s}        return serializedSize == @"cpz.count";
        \\{s}    }}
        \\
        \\{s}    pub fn matchesSegmentCount(@"cpz.count": usize) bool {{
        \\{s}        return segmentCount == @"cpz.count";
        \\{s}    }}
        \\{s}}};
        \\
    , .{
        indent,
        zig_type,
        indent,
        zig_type,
        indent,
        indent,
        zig_type,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
        indent,
    });
}

pub fn listUnsignedFlatBytesAlloc(comptime T: type, allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, element_size: wire.ElementSize) LayoutError![]u8 {
    const data_words = try wire.wordsForList(element_size, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, element_size, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseUnsignedLiteral(T, resolved_item.literal) orelse return error.InvalidToken;
        std.mem.writeInt(T, data[item.index * @sizeOf(T) ..][0..@sizeOf(T)], value, .little);
    }
    return flat;
}

pub fn listSignedFlatBytesAlloc(comptime T: type, comptime U: type, allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, element_size: wire.ElementSize) LayoutError![]u8 {
    const data_words = try wire.wordsForList(element_size, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, element_size, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseSignedLiteral(T, resolved_item.literal) orelse return error.InvalidToken;
        std.mem.writeInt(U, data[item.index * @sizeOf(U) ..][0..@sizeOf(U)], @bitCast(value), .little);
    }
    return flat;
}

pub fn listFloatFlatBytesAlloc(comptime T: type, comptime U: type, allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, element_size: wire.ElementSize) LayoutError![]u8 {
    const data_words = try wire.wordsForList(element_size, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, element_size, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseFloatLiteral(T, resolved_item.literal) orelse return error.InvalidToken;
        std.mem.writeInt(U, data[item.index * @sizeOf(U) ..][0..@sizeOf(U)], @bitCast(value), .little);
    }
    return flat;
}

pub fn listBoolFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem) LayoutError![]u8 {
    const data_words = try wire.wordsForList(.bit, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .bit, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const value = parseBoolLiteral(resolved_item.literal) orelse return error.InvalidToken;
        if (value) setBit(data, item.index);
    }
    return flat;
}

pub fn listCapabilityFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem) LayoutError![]u8 {
    const data_words = try wire.wordsForList(.pointer, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));
    for (items) |item| {
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        const raw = std.mem.trim(u8, resolved_item.literal, " \t\r\n");
        if (item.index >= items.len or (!std.mem.eql(u8, raw, "void") and !std.mem.eql(u8, raw, "null"))) return error.InvalidToken;
    }
    return flat;
}

pub fn listVoidFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem) LayoutError![]u8 {
    const segment_words: usize = 1;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .void, items.len));
    for (items) |item| {
        const resolved_item = resolveScalarConstListItem(file, scope, item);
        if (item.index >= items.len or !std.mem.eql(u8, resolved_item.literal, "void")) return error.InvalidToken;
    }
    return flat;
}

pub fn decodedStringBytesAlloc(allocator: std.mem.Allocator, raw: []const u8) LayoutError![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        i += 1;
        if (c == '\\' and i < raw.len) {
            const escaped = raw[i];
            i += 1;
            switch (escaped) {
                'a' => try out.append(allocator, 0x07),
                'b' => try out.append(allocator, 0x08),
                'f' => try out.append(allocator, 0x0c),
                'n' => try out.append(allocator, '\n'),
                'r' => try out.append(allocator, '\r'),
                't' => try out.append(allocator, '\t'),
                'v' => try out.append(allocator, 0x0b),
                '\'', '"', '\\', '?' => try out.append(allocator, escaped),
                'x' => {
                    if (i + 2 <= raw.len) {
                        if (std.fmt.parseInt(u8, raw[i .. i + 2], 16)) |value| {
                            i += 2;
                            try out.append(allocator, value);
                        } else |_| {
                            try out.append(allocator, escaped);
                        }
                    } else {
                        try out.append(allocator, escaped);
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
                    try out.append(allocator, @truncate(value));
                },
                else => try out.append(allocator, escaped),
            }
        } else {
            try out.append(allocator, c);
        }
    }
    return out.toOwnedSlice(allocator);
}

pub fn listTextOrDataFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, comptime nul_terminated: bool) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item.literal, nul_terminated)) orelse (if (item.is_hex_data)
            try hexBytesAlloc(allocator, item.literal)
        else
            try decodedStringBytesAlloc(allocator, item.literal));
        defer allocator.free(bytes);
        try appendByteListPointer(allocator, &segment, 0, 0, bytes, nul_terminated, try rootPointerListElementWordIndex(item.index));
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listEnumFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, enum_decl: *const EnumDecl, items: []const ConstListItem) LayoutError![]u8 {
    const data_words = try wire.wordsForList(.two_bytes, items.len);
    const segment_words = try rootListSegmentWords(data_words);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeList(0, .two_bytes, items.len));
    const data = flat[2 * @sizeOf(u64) ..];
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const ordinal = try resolvedEnumDefaultOrdinal(file, scope, enum_decl, item.literal);
        std.mem.writeInt(u16, data[item.index * @sizeOf(u16) ..][0..@sizeOf(u16)], ordinal, .little);
    }
    return flat;
}

pub fn supportsScalarConstFlatContainer(file: *const File, scope: ?*const Struct, ty: Type) bool {
    return switch (resolveTypeScoped(file, scope, ty)) {
        .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => true,
        .named => |type_name| findEnum(file, type_name) != null,
        else => false,
    };
}

pub fn resolveScalarConstLiteral(file: *const File, scope: ?*const Struct, literal: []const u8) []const u8 {
    return resolveScalarConstLiteralDepth(file, scope, literal, 0);
}

pub fn resolveScalarConstLiteralDepth(file: *const File, scope: ?*const Struct, literal: []const u8, depth: usize) []const u8 {
    if (depth >= 32) return literal;
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    const decl = findConstReference(file, scope, raw) orelse return literal;
    if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), raw)) return decl.literal;
    if (constDeclOwnerName(file, decl)) |owner_name| {
        return resolveScalarConstLiteralInOwnerDepth(file, scope, owner_name, decl.literal, depth + 1);
    }
    return resolveScalarConstLiteralDepth(file, scope, decl.literal, depth + 1);
}

pub fn resolveScalarConstLiteralInOwnerDepth(file: *const File, scope: ?*const Struct, owner_name: []const u8, literal: []const u8, depth: usize) []const u8 {
    if (depth >= 32) return literal;
    const raw = std.mem.trim(u8, literal, " \t\r\n");
    if (lastTopLevelDot(raw) == null) {
        if (findConstInOwner(file, scope, owner_name, raw)) |decl| {
            if (std.mem.eql(u8, std.mem.trim(u8, decl.literal, " \t\r\n"), raw)) return decl.literal;
            return resolveScalarConstLiteralInOwnerDepth(file, scope, constDeclOwnerName(file, decl) orelse owner_name, decl.literal, depth + 1);
        }
    }
    return resolveScalarConstLiteralDepth(file, scope, literal, depth);
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

pub fn resolveConstReferenceLiteral(file: *const File, scope: ?*const Struct, literal: []const u8) []const u8 {
    return resolveConstReferenceLiteralDepth(file, scope, literal, 0);
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

pub fn referencedBlobBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool) LayoutError!?[]u8 {
    return referencedBlobBytesAllocDepth(allocator, file, scope, literal, is_text, 0);
}

pub fn referencedBlobBytesAllocDepth(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool, depth: usize) LayoutError!?[]u8 {
    if (depth >= 32) return error.UnsupportedType;
    const decl = findConstReference(file, scope, literal) orelse return null;
    return referencedBlobBytesFromDeclAlloc(allocator, file, scope, decl, literal, constDeclOwnerName(file, decl), is_text, depth);
}

pub fn constBlobBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, decl: *const ConstDecl, comptime is_text: bool) LayoutError![]u8 {
    if (decl.is_embed) return try allocator.dupe(u8, decl.embed_bytes orelse return error.UnsupportedType);
    if (try referencedBlobBytesAlloc(allocator, file, scope, decl.literal, is_text)) |bytes| return bytes;
    return if (!is_text and decl.is_hex_data)
        try hexBytesAlloc(allocator, decl.literal)
    else
        try decodedStringBytesAlloc(allocator, decl.literal);
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

pub fn constDeclResolutionScope(file: *const File, fallback_scope: ?*const Struct, decl: *const ConstDecl, empty_fields: []Field, storage: *Struct) ?*const Struct {
    const owner_name = constDeclOwnerName(file, decl) orelse return fallback_scope;
    if (findStructDirect(file, owner_name)) |owner| return owner;
    if (findInterfaceDirect(file, owner_name)) |owner| {
        storage.* = .{
            .name = owner.name,
            .fields = empty_fields,
            .consts = owner.consts,
            .aliases = owner.aliases,
        };
        return storage;
    }
    return fallback_scope;
}

pub fn referencedBlobBytesFromDeclAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    decl: *const ConstDecl,
    original_literal: []const u8,
    owner_name: ?[]const u8,
    comptime is_text: bool,
    depth: usize,
) LayoutError!?[]u8 {
    if (depth >= 32) return error.UnsupportedType;
    const resolved_ty = switch (resolveConstDeclType(file, scope, decl)) {
        .optional => |child| resolveConstDeclChildType(file, scope, decl, child.*),
        else => |resolved| resolved,
    };
    if (is_text) {
        if (resolved_ty != .text) return null;
        if (decl.is_embed) return try allocator.dupe(u8, decl.embed_bytes orelse return error.UnsupportedType);
        if (try referencedBlobBytesFromNestedConstAlloc(allocator, file, scope, decl, original_literal, owner_name, true, depth + 1)) |bytes| return bytes;
        return try decodedStringBytesAlloc(allocator, decl.literal);
    }
    if (resolved_ty != .data) return null;
    if (decl.is_embed) return try allocator.dupe(u8, decl.embed_bytes orelse return error.UnsupportedType);
    if (try referencedBlobBytesFromNestedConstAlloc(allocator, file, scope, decl, original_literal, owner_name, false, depth + 1)) |bytes| return bytes;
    return if (decl.is_hex_data)
        try hexBytesAlloc(allocator, decl.literal)
    else
        try decodedStringBytesAlloc(allocator, decl.literal);
}

pub fn referencedBlobBytesFromNestedConstAlloc(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    decl: *const ConstDecl,
    original_literal: []const u8,
    owner_name: ?[]const u8,
    comptime is_text: bool,
    depth: usize,
) LayoutError!?[]u8 {
    if (depth >= 32) return error.UnsupportedType;
    const raw_literal = std.mem.trim(u8, decl.literal, " \t\r\n");
    if (std.mem.eql(u8, raw_literal, std.mem.trim(u8, original_literal, " \t\r\n"))) return null;
    if (lastTopLevelDot(raw_literal) == null) {
        if (owner_name) |owner| {
            if (findConstInOwner(file, scope, owner, raw_literal)) |nested_decl| {
                if (nested_decl != decl) {
                    if (try referencedBlobBytesFromDeclAlloc(allocator, file, scope, nested_decl, decl.literal, constDeclOwnerName(file, nested_decl) orelse owner, is_text, depth + 1)) |bytes| return bytes;
                }
            }
        }
    }
    return try referencedBlobBytesAllocDepth(allocator, file, scope, decl.literal, is_text, depth + 1);
}

pub fn fieldBlobDefaultBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, field: *const Field, comptime is_text: bool) LayoutError!?[]u8 {
    const literal = field.default_literal orelse return null;
    if (try referencedBlobBytesAlloc(allocator, file, scope, literal, is_text)) |bytes| return bytes;
    if (is_text) return try decodedStringBytesAlloc(allocator, literal);
    return if (field.default_is_hex_data)
        try hexBytesAlloc(allocator, literal)
    else
        try decodedStringBytesAlloc(allocator, literal);
}

pub fn fieldBlobDefaultLiteralAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, field: *const Field, comptime is_text: bool) LayoutError!?[]u8 {
    const bytes = try fieldBlobDefaultBytesAlloc(allocator, file, scope, field, is_text) orelse return null;
    defer allocator.free(bytes);
    return try zigRawStringLiteralAlloc(allocator, bytes);
}

pub fn resolveScalarConstListItem(file: *const File, scope: ?*const Struct, item: ConstListItem) ConstListItem {
    var resolved = item;
    resolved.literal = resolveScalarConstLiteral(file, scope, item.literal);
    return resolved;
}

pub fn scalarConstFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, ty: Type, literal: []const u8) LayoutError![]u8 {
    const resolved_literal = resolveScalarConstLiteral(file, scope, literal);
    const segment_words: usize = 2;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentWords(segment_words));
    errdefer allocator.free(flat);
    @memset(flat, 0);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    writeWordBytes(flat[@sizeOf(u64)..][0..@sizeOf(u64)], try wire.encodeStruct(0, 1, 0));
    const data = flat[2 * @sizeOf(u64) ..][0..@sizeOf(u64)];
    switch (resolveTypeScoped(file, scope, ty)) {
        .void => {},
        .bool => {
            const value = parseBoolLiteral(resolved_literal) orelse return error.InvalidToken;
            if (value) setBit(data, 0);
        },
        .int8 => {
            const value = parseSignedLiteral(i8, resolved_literal) orelse return error.InvalidToken;
            data[0] = @bitCast(value);
        },
        .int16 => {
            const value = parseSignedLiteral(i16, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u16, data[0..@sizeOf(u16)], @bitCast(value), .little);
        },
        .int32 => {
            const value = parseSignedLiteral(i32, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u32, data[0..@sizeOf(u32)], @bitCast(value), .little);
        },
        .int64 => {
            const value = parseSignedLiteral(i64, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u64, data[0..@sizeOf(u64)], @bitCast(value), .little);
        },
        .uint8 => data[0] = parseUnsignedLiteral(u8, resolved_literal) orelse return error.InvalidToken,
        .uint16 => {
            const value = parseUnsignedLiteral(u16, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u16, data[0..@sizeOf(u16)], value, .little);
        },
        .uint32 => {
            const value = parseUnsignedLiteral(u32, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u32, data[0..@sizeOf(u32)], value, .little);
        },
        .uint64 => {
            const value = parseUnsignedLiteral(u64, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u64, data[0..@sizeOf(u64)], value, .little);
        },
        .float32 => {
            const value = parseFloatLiteral(f32, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u32, data[0..@sizeOf(u32)], @bitCast(value), .little);
        },
        .float64 => {
            const value = parseFloatLiteral(f64, resolved_literal) orelse return error.InvalidToken;
            std.mem.writeInt(u64, data[0..@sizeOf(u64)], @bitCast(value), .little);
        },
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const ordinal = resolvedEnumLiteralOrdinal(file, scope, enum_decl, literal) orelse return error.InvalidToken;
            std.mem.writeInt(u16, data[0..@sizeOf(u16)], ordinal, .little);
        },
        else => return error.UnsupportedType,
    }
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

pub fn listOptionalTextOrDataFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, comptime is_text: bool) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const bytes = try optionalBlobConstItemBytesAlloc(allocator, file, scope, item, is_text) orelse continue;
        defer allocator.free(bytes);
        try appendByteListPointer(allocator, &segment, 0, 0, bytes, is_text, try rootPointerListElementWordIndex(item.index));
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listOptionalStructConstFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, items: []const ConstListItem) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    const list_start_words = try appendPointerListPointer(allocator, &segment, 0, 0, 0, items.len);
    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item.literal), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;
        try appendStructListItemPointer(allocator, file, scope, &segment, item.index, list_start_words, type_name, item);
    }
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn emitOptionalStructListConst(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, name: []const u8, child: Type, type_name: []const u8, items: []const ConstListItem) LayoutError!void {
    const flat = try listOptionalStructConstFlatBytesAlloc(allocator, file, scope, type_name, items);
    defer allocator.free(flat);
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, name, child, flat);
}

pub fn appendAnyPointerConstDeclListElementPointer(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    segment: *std.ArrayList(u8),
    element_index: usize,
    list_start_words: usize,
    decl: *const ConstDecl,
    comptime want: AnyPointerDefaultKind,
    depth: usize,
) LayoutError!void {
    if (depth >= 32) return error.UnsupportedType;
    var decl_scope_fields: [0]Field = .{};
    var decl_scope_storage: Struct = undefined;
    const decl_scope = constDeclResolutionScope(file, scope, decl, decl_scope_fields[0..], &decl_scope_storage);
    const resolved_ty = switch (resolveConstDeclType(file, scope, decl)) {
        .optional => |child| methodOptionalDefaultChildOrNullForDecl(file, scope, decl, child.*, decl.literal) orelse return error.UnsupportedType,
        else => |resolved| resolved,
    };
    switch (resolved_ty) {
        .named => |type_name| {
            if (want == .list) return error.UnsupportedType;
            if (findStructDirect(file, type_name) == null) return error.UnsupportedType;
            try appendStructLiteralPointer(allocator, file, decl_scope, segment, element_index, 0, list_start_words, type_name, decl.literal);
        },
        .list => |child| {
            if (want == .struct_ptr) return error.UnsupportedType;
            try appendScalarListPointer(allocator, file, decl_scope, segment, element_index, 0, list_start_words, child.*, decl.literal);
        },
        .any_pointer, .any_struct, .any_list => {
            const next_decl = findConstReference(file, decl_scope, decl.literal) orelse return error.UnsupportedType;
            if (next_decl == decl) return error.UnsupportedType;
            try appendAnyPointerConstDeclListElementPointer(allocator, file, decl_scope, segment, element_index, list_start_words, next_decl, want, depth + 1);
        },
        else => return error.UnsupportedType,
    }
}

pub fn appendAnyPointerConstListElementPointer(
    allocator: std.mem.Allocator,
    file: *const File,
    scope: ?*const Struct,
    segment: *std.ArrayList(u8),
    element_index: usize,
    list_start_words: usize,
    literal: []const u8,
    comptime want: AnyPointerDefaultKind,
) LayoutError!void {
    const decl = findConstReference(file, scope, literal) orelse return error.UnsupportedType;
    try appendAnyPointerConstDeclListElementPointer(allocator, file, scope, segment, element_index, list_start_words, decl, want, 0);
}

pub fn listOptionalAnyPointerConstFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, items: []const ConstListItem, comptime want: AnyPointerDefaultKind) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    const list_start_words = try appendPointerListPointer(allocator, &segment, 0, 0, 0, items.len);

    for (items) |item| {
        if (item.index >= items.len) return error.InvalidToken;
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item.literal), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;

        try appendAnyPointerConstListElementPointer(allocator, file, scope, &segment, item.index, list_start_words, item.literal, want);
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
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

pub fn emitStructUnionMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    if (!emit_metadata_enabled) return;
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
    if (!emit_metadata_enabled) return;
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

pub fn constListItemsFromInlineLiteralAlloc(allocator: std.mem.Allocator, literal: []const u8) LayoutError![]ConstListItem {
    const raw_items = try parseInlineConstListElementsAlloc(allocator, literal);
    defer allocator.free(raw_items);
    const items = try allocator.alloc(ConstListItem, raw_items.len);
    errdefer allocator.free(items);
    for (raw_items, 0..) |item, index| {
        items[index] = .{ .index = index, .literal = item };
    }
    return items;
}

pub fn listTextOrDataFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool) LayoutError![]u8 {
    const items = try parseInlineConstListElementsAlloc(allocator, literal);
    defer allocator.free(items);

    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items, 0..) |item, index| {
        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item, is_text)) orelse if (is_text)
            try inlineQuotedStringBytesAlloc(allocator, item)
        else
            try inlineDataBytesAlloc(allocator, item);
        defer allocator.free(bytes);
        try appendByteListPointerAtWord(allocator, &segment, try rootPointerListElementWordIndex(index), bytes, is_text);
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listOptionalTextOrDataFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime is_text: bool) LayoutError![]u8 {
    const items = try parseInlineConstListElementsAlloc(allocator, literal);
    defer allocator.free(items);

    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, try wordByteLen(try std.math.add(usize, items.len, 1)));
    writeWordBytes(segment.items[0..@sizeOf(u64)], try wire.encodeList(0, .pointer, items.len));

    for (items, 0..) |item, index| {
        // Optional blob-list elements encode absent values as null pointer slots.
        // Resolve const references before the null check so `List(?Text)` and
        // `List(?Data)` defaults can reuse `?Text = null` / `?Data = null`
        // constants without accidentally treating the spelling "null" as bytes.
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;

        const bytes = (try referencedBlobBytesAlloc(allocator, file, scope, item, is_text)) orelse if (is_text)
            try inlineQuotedStringBytesAlloc(allocator, resolved_item)
        else
            try inlineDataBytesAlloc(allocator, resolved_item);
        defer allocator.free(bytes);
        try appendByteListPointerAtWord(allocator, &segment, try rootPointerListElementWordIndex(index), bytes, is_text);
    }

    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listStructFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, literal: []const u8) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendStructListPointer(allocator, file, scope, &segment, 0, 0, 0, type_name, literal);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn appendOptionalStructListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, type_name: []const u8, literal: []const u8) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);

    const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
    for (items, 0..) |item, index| {
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;
        try appendStructListItemPointer(allocator, file, scope, segment, index, list_start_words, type_name, .{ .index = index, .literal = item });
    }
}

pub fn appendOptionalAnyPointerListPointer(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, segment: *std.ArrayList(u8), pointer_index: usize, data_words: u16, object_start_words: usize, literal: []const u8, comptime want: AnyPointerDefaultKind) LayoutError!void {
    const items = parseInlineConstListElementsAlloc(allocator, literal) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return error.UnsupportedType,
        else => return err,
    };
    defer allocator.free(items);

    const list_start_words = try appendPointerListPointer(allocator, segment, pointer_index, data_words, object_start_words, items.len);
    for (items, 0..) |item, index| {
        const resolved_item = std.mem.trim(u8, resolveConstReferenceLiteral(file, scope, item), " \t\r\n");
        if (std.mem.eql(u8, resolved_item, "null")) continue;

        try appendAnyPointerConstListElementPointer(allocator, file, scope, segment, index, list_start_words, item, want);
    }
}

pub fn listOptionalStructFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, literal: []const u8) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendOptionalStructListPointer(allocator, file, scope, &segment, 0, 0, 0, type_name, literal);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listOptionalAnyPointerDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, literal: []const u8, comptime want: AnyPointerDefaultKind) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendOptionalAnyPointerListPointer(allocator, file, scope, &segment, 0, 0, 0, literal, want);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn listNestedFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, child: Type, literal: []const u8) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendScalarListPointer(allocator, file, scope, &segment, 0, 0, 0, child, literal);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn blobFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, bytes: []const u8, comptime is_text: bool) LayoutError![]u8 {
    var segment = std.ArrayList(u8).empty;
    defer segment.deinit(allocator);
    try segment.appendNTimes(allocator, 0, @sizeOf(u64));
    try appendByteListPointerAtWord(allocator, &segment, 0, bytes, is_text);
    const segment_words = segment.items.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(segment.items.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], segment.items);
    return flat;
}

pub fn emitBlobFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, container_name: []const u8, bytes: []const u8, comptime is_text: bool) LayoutError!void {
    const flat = try blobFieldDefaultFlatBytesAlloc(allocator, bytes, is_text);
    defer allocator.free(flat);
    const flat_literal = try zigRawStringLiteralAlloc(allocator, flat);
    defer allocator.free(flat_literal);
    const get_method = if (is_text) "getRootText" else "getRootData";
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
        \\{s}    pub fn get(message_reader: *cpz.MessageReader) ![]const u8 {{
        \\{s}        return message_reader.{s}();
        \\{s}    }}
        \\
        \\{s}    pub fn getByteCount(message_reader: *cpz.MessageReader) !usize {{
        \\{s}        return (try @This().get(message_reader)).len;
        \\{s}    }}
        \\
    , .{ indent, container_name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, get_method, indent, indent, indent, indent });
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

pub fn structFieldDefaultFlatBytesAlloc(allocator: std.mem.Allocator, file: *const File, scope: ?*const Struct, type_name: []const u8, default_expression: []const u8) LayoutError!?[]u8 {
    const struct_decl = findStructDirect(file, type_name) orelse return null;
    var layout = try planStructLayout(allocator, file, struct_decl);
    defer layout.deinit(allocator);
    const fields = parseConstStructFieldsAlloc(allocator, default_expression) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken => return null,
        else => return err,
    };
    defer allocator.free(fields);
    const object = try structLiteralObjectBytesAlloc(allocator, file, scope, &layout, fields, true) orelse return null;
    defer allocator.free(object);
    const segment_words = object.len / @sizeOf(u64);
    if (segment_words > std.math.maxInt(u32)) return error.SegmentTooLarge;
    const flat = try allocator.alloc(u8, try flatByteLenForSegmentBytes(object.len));
    errdefer allocator.free(flat);
    std.mem.writeInt(u32, flat[0..4], 0, .little);
    std.mem.writeInt(u32, flat[4..8], @intCast(segment_words), .little);
    @memcpy(flat[@sizeOf(u64)..], object);
    return flat;
}

pub fn emitBlobFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), indent: []const u8, field_name: []const u8, bytes: []const u8, comptime is_text: bool) LayoutError!void {
    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(container_name);
    try emitBlobFlatContainer(allocator, out, indent, container_name, bytes, is_text);
}

pub fn emitAnyPointerFieldDefaultFlatContainerFromBytes(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    flat: []const u8,
    comptime kind: enum { any, struct_ptr, list },
) LayoutError!void {
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
        \\{s}    pub fn pointerKind(message_reader: *cpz.MessageReader) !?cpz.wire.PointerType {{
        \\{s}        return (try @This().pointer(message_reader)).pointerType();
        \\{s}    }}
        \\
    , .{ indent, name, indent, flat_literal, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent, indent });
    switch (kind) {
        .any => try appendFmt(allocator, out,
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
        , .{ indent, indent, indent, indent, indent, indent, indent, indent, indent }),
        .struct_ptr => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader) !cpz.StructReader {{
            \\{s}        return (try @This().pointer(message_reader)).getStruct(null);
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
        .list => try appendFmt(allocator, out,
            \\{s}    pub fn get(message_reader: *cpz.MessageReader, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\{s}        return (try @This().pointer(message_reader)).getList(@"cpz.expected");
            \\{s}    }}
            \\
        , .{ indent, indent, indent }),
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

pub fn emitScalarFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, field_name: []const u8, ty: Type, literal: []const u8) LayoutError!void {
    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(container_name);
    emitScalarConstFlatContainer(allocator, out, file, scope, indent, container_name, ty, literal) catch |err| switch (err) {
        error.InvalidToken, error.UnsupportedType => return,
        else => return err,
    };
}

pub fn emitListFieldDefaultFlatContainerFromBytes(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, container_name: []const u8, child: Type, flat: []const u8) LayoutError!void {
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
    , .{ indent, container_name, indent, flat_literal, indent, indent, indent, indent, indent });
    try emitMethodListDefaultGetters(allocator, out, file, scope, indent, child);
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

pub fn emitListFieldDefaultFlatContainer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, indent: []const u8, field_name: []const u8, child: Type, default_expression: []const u8) LayoutError!void {
    const flat = methodListDefaultFlatBytesAlloc(allocator, file, scope, child, default_expression) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return,
        else => return err,
    };
    defer allocator.free(flat);
    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
    defer allocator.free(container_name);
    try emitListFieldDefaultFlatContainerFromBytes(allocator, out, file, scope, indent, container_name, child, flat);
}

pub fn emitStructFieldDefaultFlats(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    for (layout.fields) |field_layout| {
        const field = field_layout.field;
        if (field.default_expression.len == 0) continue;
        const field_name = try zigIdentAlloc(allocator, field.name);
        defer allocator.free(field_name);
        const resolved_ty = switch (resolveTypeScoped(file, layout.decl, field.ty)) {
            .optional => |child| blk: {
                const child_ty = resolveTypeScoped(file, layout.decl, child.*);
                if (defaultExpressionIsNullPointer(file, layout.decl, field.default_expression) or defaultExpressionIsVoidPointer(file, layout.decl, field.default_expression, child_ty)) {
                    const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                    defer allocator.free(container_name);
                    try emitNullPointerFlatContainer(allocator, out, "    ", container_name);
                    continue;
                }
                break :blk child_ty;
            },
            else => |resolved| resolved,
        };
        if ((defaultExpressionIsNullPointer(file, layout.decl, field.default_expression) and typeAcceptsNullPointerDefault(file, resolved_ty)) or defaultExpressionIsVoidPointer(file, layout.decl, field.default_expression, resolved_ty)) {
            const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
            defer allocator.free(container_name);
            try emitNullPointerFlatContainer(allocator, out, "    ", container_name);
            continue;
        }
        switch (resolved_ty) {
            .void, .bool, .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64 => {
                const literal = field.default_literal orelse continue;
                try emitScalarFieldDefaultFlatContainer(allocator, out, file, layout.decl, "    ", field_name, resolved_ty, literal);
            },
            .text => {
                const bytes = try fieldBlobDefaultBytesAlloc(allocator, file, layout.decl, field, true) orelse continue;
                defer allocator.free(bytes);
                try emitBlobFieldDefaultFlatContainer(allocator, out, "    ", field_name, bytes, true);
            },
            .data => {
                const bytes = try fieldBlobDefaultBytesAlloc(allocator, file, layout.decl, field, false) orelse continue;
                defer allocator.free(bytes);
                try emitBlobFieldDefaultFlatContainer(allocator, out, "    ", field_name, bytes, false);
            },
            .list => |list_child| try emitListFieldDefaultFlatContainer(allocator, out, file, layout.decl, "    ", field_name, list_child.*, resolveConstReferenceLiteral(file, layout.decl, field.default_expression)),
            .any_pointer => {
                const flat = methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .any) catch |err| switch (err) {
                    error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => continue,
                    else => return err,
                };
                defer allocator.free(flat);
                const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                defer allocator.free(container_name);
                try emitAnyPointerFieldDefaultFlatContainerFromBytes(allocator, out, "    ", container_name, flat, .any);
            },
            .any_struct => {
                const flat = methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .struct_ptr) catch |err| switch (err) {
                    error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => continue,
                    else => return err,
                };
                defer allocator.free(flat);
                const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                defer allocator.free(container_name);
                try emitAnyPointerFieldDefaultFlatContainerFromBytes(allocator, out, "    ", container_name, flat, .struct_ptr);
            },
            .any_list => {
                const flat = methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .list) catch |err| switch (err) {
                    error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => continue,
                    else => return err,
                };
                defer allocator.free(flat);
                const container_name = try std.fmt.allocPrint(allocator, "{s}Default", .{field_name});
                defer allocator.free(container_name);
                try emitAnyPointerFieldDefaultFlatContainerFromBytes(allocator, out, "    ", container_name, flat, .list);
            },
            .named => |type_name| {
                if (findEnum(file, type_name) != null) {
                    const literal = field.default_literal orelse continue;
                    try emitScalarFieldDefaultFlatContainer(allocator, out, file, layout.decl, "    ", field_name, resolved_ty, literal);
                    continue;
                }
                if (findInterface(file, type_name) != null or !isStructLikeName(file, type_name)) continue;
                const flat = (try structFieldDefaultFlatBytesAlloc(allocator, file, layout.decl, type_name, resolveConstReferenceLiteral(file, layout.decl, field.default_expression))) orelse continue;
                defer allocator.free(flat);
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                const container_name = try std.fmt.allocPrint(allocator, "{s}DefaultFlat", .{field_name});
                defer allocator.free(container_name);
                try emitEmbeddedStructConst(allocator, out, "    ", container_name, zig_type, flat);
            },
            else => continue,
        }
    }
}

pub fn structFieldDefaultFlatIsEmitted(allocator: std.mem.Allocator, file: *const File, layout: *const StructLayout, field: *const Field, type_name: []const u8) LayoutError!bool {
    if (field.default_expression.len == 0) return false;
    if (defaultExpressionIsNullPointer(file, layout.decl, field.default_expression)) return false;
    if (findInterface(file, type_name) != null or !isStructLikeName(file, type_name)) return false;
    const flat = (try structFieldDefaultFlatBytesAlloc(allocator, file, layout.decl, type_name, resolveConstReferenceLiteral(file, layout.decl, field.default_expression))) orelse return false;
    defer allocator.free(flat);
    return true;
}

pub fn listFieldDefaultFlatIsEmitted(allocator: std.mem.Allocator, file: *const File, layout: *const StructLayout, field: *const Field, child: Type) LayoutError!bool {
    if (field.default_expression.len == 0) return false;
    const flat = methodListDefaultFlatBytesAlloc(allocator, file, layout.decl, child, field.default_expression) catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return false,
        else => return err,
    };
    defer allocator.free(flat);
    return true;
}

pub fn anyPointerFieldDefaultFlatIsEmitted(allocator: std.mem.Allocator, file: *const File, layout: *const StructLayout, field: *const Field, comptime want: enum { any, struct_ptr, list }) LayoutError!bool {
    if (field.default_expression.len == 0) return false;
    const flat = switch (want) {
        .any => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .any),
        .struct_ptr => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .struct_ptr),
        .list => methodAnyPointerDefaultFlatBytesAlloc(allocator, file, layout.decl, field.default_expression, .list),
    } catch |err| switch (err) {
        error.UnexpectedToken, error.InvalidToken, error.UnsupportedType => return false,
        else => return err,
    };
    defer allocator.free(flat);
    return true;
}

pub fn fieldSlotMetadata(slot: FieldSlot) struct { name: []const u8, offset: usize } {
    return switch (slot) {
        .void => .{ .name = "void", .offset = 0 },
        .data_bit => |bit| .{ .name = "data_bit", .offset = bit },
        .data_byte => |byte| .{ .name = "data_byte", .offset = byte },
        .pointer => |index| .{ .name = "pointer", .offset = index },
    };
}

pub fn emitStructGroupMetadata(allocator: std.mem.Allocator, out: *std.ArrayList(u8), groups: []const GroupDecl) LayoutError!void {
    if (!emit_metadata_enabled) return;
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

pub fn fieldIndex(layout: *const StructLayout, target: *const Field) LayoutError!usize {
    for (layout.fields, 0..) |field_layout, index| {
        if (field_layout.field == target) return index;
    }
    return error.UnsupportedType;
}

pub fn emitStruct(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
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
    try emitStructGroupMetadata(allocator, out, layout.decl.groups);
    try emitStructUnionMetadata(allocator, out, file, layout);
    try emitStructFieldMetadata(allocator, out, file, layout);
    try emitStructFieldDefaultFlats(allocator, out, file, layout);

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
        \\        pub fn segmentId(self: @This()) u32 {{
        \\            return self.orphan.segmentId();
        \\        }}
        \\
        \\        pub fn pointerWordIndex(self: @This()) usize {{
        \\            return self.orphan.pointerWordIndex();
        \\        }}
        \\
        \\        pub fn matchesLocation(self: @This(), @"cpz.segmentId": u32, @"cpz.wordIndex": usize) bool {{
        \\            return self.orphan.matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\        }}
        \\
        \\        pub fn matchesPointerType(self: @This(), @"cpz.expected": cpz.wire.PointerType) bool {{
        \\            return self.orphan.matchesPointerType(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn isStructPointer(self: @This()) bool {{
        \\            return self.orphan.isStructPointer();
        \\        }}
        \\
        \\        pub fn isListPointer(self: @This()) bool {{
        \\            return self.orphan.isListPointer();
        \\        }}
        \\
        \\        pub fn isFarPointer(self: @This()) bool {{
        \\            return self.orphan.isFarPointer();
        \\        }}
        \\
        \\        pub fn isOtherPointer(self: @This()) bool {{
        \\            return self.orphan.isOtherPointer();
        \\        }}
        \\
        \\        pub fn isCapabilityPointer(self: @This()) bool {{
        \\            return self.orphan.isCapabilityPointer();
        \\        }}
        \\
        \\        pub fn isNearPointer(self: @This()) bool {{
        \\            return self.orphan.isNearPointer();
        \\        }}
        \\
        \\        pub fn maxCapabilityCount(self: @This()) !usize {{
        \\            return self.orphan.maxCapabilityCount();
        \\        }}
        \\
        \\        pub fn matchesMaxCapabilityCount(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.matchesMaxCapabilityCount(@"cpz.count");
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
        \\        pub fn structSize(self: @This()) !cpz.StructSize {{
        \\            return self.orphan.structSize();
        \\        }}
        \\
        \\        pub fn structDataWordCount(self: @This()) !u16 {{
        \\            return self.orphan.structDataWordCount();
        \\        }}
        \\
        \\        pub fn structPointerCount(self: @This()) !u16 {{
        \\            return self.orphan.structPointerCount();
        \\        }}
        \\
        \\        pub fn structTotalWords(self: @This()) !usize {{
        \\            return self.orphan.structTotalWords();
        \\        }}
        \\
        \\        pub fn structDataByteCount(self: @This()) !usize {{
        \\            return self.orphan.structDataByteCount();
        \\        }}
        \\
        \\        pub fn structPointerByteCount(self: @This()) !usize {{
        \\            return self.orphan.structPointerByteCount();
        \\        }}
        \\
        \\        pub fn structTotalByteCount(self: @This()) !usize {{
        \\            return self.orphan.structTotalByteCount();
        \\        }}
        \\
        \\        pub fn structMatchesSize(self: @This(), @"cpz.expected": cpz.StructSize) bool {{
        \\            return self.orphan.structMatchesSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn structMatchesDataWords(self: @This(), @"cpz.count": u16) bool {{
        \\            return self.orphan.structMatchesDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn structMatchesPointerCount(self: @This(), @"cpz.count": u16) bool {{
        \\            return self.orphan.structMatchesPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn structMatchesTotalWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.structMatchesTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn structMatchesTotalBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.structMatchesTotalBytes(@"cpz.count");
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
        \\        pub fn validateWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.orphan.validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.orphan.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.orphan.totalSizeWithOptions(@"cpz.options");
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
        \\    pub fn @"cpz.root.matchesPointerKind"(@"cpz.reader": *cpz.MessageReader, @"cpz.kind": cpz.wire.PointerType) !bool {{
        \\        return @"cpz.reader".matchesRootPointerType(@"cpz.kind");
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsStruct"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return @"cpz.reader".isRootStructPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsList"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return @"cpz.reader".isRootListPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsFar"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return @"cpz.reader".isRootFarPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsOther"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return @"cpz.reader".isRootOtherPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsCapability"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return @"cpz.reader".isRootCapabilityPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerIsNear"(@"cpz.reader": *cpz.MessageReader) !bool {{
        \\        return @"cpz.reader".isRootNearPointer();
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
        \\    pub fn @"cpz.root.pointerSegmentId"(@"cpz.reader": *cpz.MessageReader) !u32 {{
        \\        return (try @"cpz.reader".getRootPointer()).segmentId();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerWordIndex"(@"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return (try @"cpz.reader".getRootPointer()).pointerWordIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.root.pointerMatchesLocation"(@"cpz.reader": *cpz.MessageReader, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
        \\        return (try @"cpz.reader".getRootPointer()).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
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
        \\    pub fn @"cpz.root.toFlatBytesInto"(@"cpz.reader": *cpz.MessageReader, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.reader".toFlatBytesInto(@"cpz.dest");
        \\    }}
        \\
        \\    pub fn @"cpz.root.toPackedBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) ![]u8 {{
        \\        return @"cpz.reader".toPackedBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.root.packedSize"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return @"cpz.reader".packedSize(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.root.packedSizeWithTableBuffer"(@"cpz.reader": *cpz.MessageReader, @"cpz.tableBuffer": []u8) !usize {{
        \\        return @"cpz.reader".packedSizeWithTableBuffer(@"cpz.tableBuffer");
        \\    }}
        \\
        \\    pub fn @"cpz.root.maxPackedSize"(@"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return @"cpz.reader".maxPackedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.root.toPackedBytesInto"(@"cpz.reader": *cpz.MessageReader, @"cpz.tableBuffer": []u8, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.reader".toPackedBytesInto(@"cpz.tableBuffer", @"cpz.dest");
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
        \\    pub fn @"cpz.root.writePackedToWriterWithTableBuffer"(@"cpz.reader": *cpz.MessageReader, @"cpz.tableBuffer": []u8, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.reader".writePackedToWriterWithTableBuffer(@"cpz.tableBuffer", @"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.root.fromFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.bytes": []const u8, @"cpz.options": cpz.ReaderOptions) !cpz.OwnedMessageReader {{
        \\        return cpz.OwnedMessageReader.initFlat(@"cpz.allocator", @"cpz.bytes", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.fromPackedBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.bytes": []const u8, @"cpz.options": cpz.ReaderOptions) !cpz.OwnedMessageReader {{
        \\        return cpz.OwnedMessageReader.initPacked(@"cpz.allocator", @"cpz.bytes", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.fromReader"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *std.Io.Reader, @"cpz.options": cpz.ReaderOptions) !cpz.OwnedMessageReader {{
        \\        return cpz.OwnedMessageReader.initFromReader(@"cpz.allocator", @"cpz.reader", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.fromPackedReader"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *std.Io.Reader, @"cpz.options": cpz.ReaderOptions) !cpz.OwnedMessageReader {{
        \\        return cpz.OwnedMessageReader.initPackedFromReader(@"cpz.allocator", @"cpz.reader", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.viewFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.bytes": []const u8, @"cpz.options": cpz.ReaderOptions) !cpz.MessageReaderView {{
        \\        return cpz.MessageReaderView.initFlat(@"cpz.allocator", @"cpz.bytes", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.viewFlatBytesInto"(@"cpz.segmentTable": []cpz.serialize.ConstSegment, @"cpz.bytes": []const u8, @"cpz.options": cpz.ReaderOptions) !cpz.MessageReaderView {{
        \\        return cpz.MessageReaderView.initFlatInto(@"cpz.segmentTable", @"cpz.bytes", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.viewPackedBytesInto"(@"cpz.segmentTable": []cpz.serialize.ConstSegment, @"cpz.flatBuffer": []u8, @"cpz.bytes": []const u8, @"cpz.options": cpz.ReaderOptions) !cpz.MessageReaderView {{
        \\        return cpz.MessageReaderView.initPackedInto(@"cpz.segmentTable", @"cpz.flatBuffer", @"cpz.bytes", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.viewFromReaderInto"(@"cpz.segmentTable": []cpz.serialize.ConstSegment, @"cpz.flatBuffer": []u8, @"cpz.reader": *std.Io.Reader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageReaderView {{
        \\        return cpz.MessageReaderView.initFromReaderInto(@"cpz.segmentTable", @"cpz.flatBuffer", @"cpz.reader", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.root.viewFromPackedReaderInto"(@"cpz.segmentTable": []cpz.serialize.ConstSegment, @"cpz.flatBuffer": []u8, @"cpz.reader": *std.Io.Reader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageReaderView {{
        \\        return cpz.MessageReaderView.initPackedFromReaderInto(@"cpz.segmentTable", @"cpz.flatBuffer", @"cpz.reader", @"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.consumedLen"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".consumedLen();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.asReader"(@"cpz.reader": *cpz.OwnedMessageReader) *cpz.MessageReader {{
        \\        return @"cpz.reader".asReader();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.root"(@"cpz.reader": *cpz.OwnedMessageReader) !@This() {{
        \\        return getRoot(@"cpz.reader".asReader());
        \\    }}
        \\
        \\    pub fn @"cpz.owned.isNull"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootNull();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointer"(@"cpz.reader": *cpz.OwnedMessageReader) !cpz.PointerReader {{
        \\        return @"cpz.reader".getRootPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsNull"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return (try @"cpz.reader".getRootPointer()).isNull();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerSegmentId"(@"cpz.reader": *cpz.OwnedMessageReader) !u32 {{
        \\        return (try @"cpz.reader".getRootPointer()).segmentId();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerWordIndex"(@"cpz.reader": *cpz.OwnedMessageReader) !usize {{
        \\        return (try @"cpz.reader".getRootPointer()).pointerWordIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerMatchesLocation"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
        \\        return (try @"cpz.reader".getRootPointer()).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerKind"(@"cpz.reader": *cpz.OwnedMessageReader) !?cpz.wire.PointerType {{
        \\        return @"cpz.reader".getRootPointerKind();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.matchesPointerKind"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.kind": cpz.wire.PointerType) !bool {{
        \\        return @"cpz.reader".matchesRootPointerType(@"cpz.kind");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsStruct"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootStructPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsList"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootListPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsFar"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootFarPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsOther"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootOtherPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsCapability"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootCapabilityPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.pointerIsNear"(@"cpz.reader": *cpz.OwnedMessageReader) !bool {{
        \\        return @"cpz.reader".isRootNearPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.rawPointer"(@"cpz.reader": *cpz.OwnedMessageReader) !cpz.Word {{
        \\        return @"cpz.reader".getRootRawPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.decodedPointer"(@"cpz.reader": *cpz.OwnedMessageReader) !?cpz.wire.DecodedPointer {{
        \\        return @"cpz.reader".getRootDecodedPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.stats"(@"cpz.reader": *cpz.OwnedMessageReader) !cpz.MessageStats {{
        \\        return (try @"cpz.reader".getRootPointer()).validate();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.statsWithOptions"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return (try @"cpz.reader".getRootPointer()).validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.totalSizeRoot"(@"cpz.reader": *cpz.OwnedMessageReader) !cpz.MessageSize {{
        \\        return (try @"cpz.owned.stats"(@"cpz.reader")).size();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.totalSizeRootWithOptions"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return (try @"cpz.owned.statsWithOptions"(@"cpz.reader", @"cpz.options")).size();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.text"(@"cpz.reader": *cpz.OwnedMessageReader) ![]const u8 {{
        \\        return @"cpz.reader".getRootText();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.textDefault"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.reader".getRootTextDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.textDefaultByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.reader".getRootTextDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.textDefaultMatchesBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootTextDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.textByteCount"(@"cpz.reader": *cpz.OwnedMessageReader) !usize {{
        \\        return @"cpz.reader".getRootTextByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.textMatchesBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootTextMatchesBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.data"(@"cpz.reader": *cpz.OwnedMessageReader) ![]const u8 {{
        \\        return @"cpz.reader".getRootData();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.dataDefault"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.reader".getRootDataDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.dataDefaultByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.reader".getRootDataDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.dataDefaultMatchesBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootDataDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.dataByteCount"(@"cpz.reader": *cpz.OwnedMessageReader) !usize {{
        \\        return @"cpz.reader".getRootDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.dataMatchesBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootDataMatchesBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.capability"(@"cpz.reader": *cpz.OwnedMessageReader) !u32 {{
        \\        return @"cpz.reader".getRootCapability();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.list"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !cpz.ListReader {{
        \\        return @"cpz.reader".getRootList(@"cpz.elementSize");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listLen"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).len();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesLen"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesLen(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listIsEmpty"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).isEmpty();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listHasIndex"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.index": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).hasIndex(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listFirstIndex"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).firstIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listLastIndex"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).lastIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listElementSize"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !cpz.ElementSize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).elementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesElementSize"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listElementBitCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).elementBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesElementBits"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listElementByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).elementByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesElementBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listElementWordCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).elementWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesElementWords"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listContentBitCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).contentBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesContentBits"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesContentBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listContentByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).contentByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesContentBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesContentBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listContentWordCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).contentWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesContentWords"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesContentWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementSize"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !cpz.StructSize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementDataWordCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementDataWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementPointerCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementPointerCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementTotalWords"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementTotalWords();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementDataByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementPointerByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementPointerByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listStructElementTotalByteCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).structElementTotalByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementSize"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.StructSize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementDataWords"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementDataWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementPointerCount"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementPointerCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementTotalWords"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementTotalWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementDataBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementDataBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementPointerBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementPointerBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.listMatchesStructElementTotalBytes"(@"cpz.reader": *cpz.OwnedMessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.owned.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementTotalBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.traversalLimitWords"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".traversalLimitWords();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.traversalLimitBytes"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".traversalLimitBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.matchesTraversalLimitWords"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.count": usize) bool {{
        \\        return @"cpz.reader".matchesTraversalLimitWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.matchesTraversalLimitBytes"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.count": usize) bool {{
        \\        return @"cpz.reader".matchesTraversalLimitBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.traversalRemainingWords"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".traversalRemainingWords();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.traversalRemainingBytes"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".traversalRemainingBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.nestingLimit"(@"cpz.reader": *const cpz.OwnedMessageReader) u16 {{
        \\        return @"cpz.reader".nestingLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.matchesNestingLimit"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.count": u16) bool {{
        \\        return @"cpz.reader".matchesNestingLimit(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.capabilityCountLimit"(@"cpz.reader": *const cpz.OwnedMessageReader) ?usize {{
        \\        return @"cpz.reader".capabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.hasCapabilityCountLimit"(@"cpz.reader": *const cpz.OwnedMessageReader) bool {{
        \\        return @"cpz.reader".hasCapabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.matchesCapabilityCountLimit"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.count": usize) bool {{
        \\        return @"cpz.reader".matchesCapabilityCountLimit(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.validate"(@"cpz.reader": *cpz.OwnedMessageReader) !cpz.MessageStats {{
        \\        return @"cpz.reader".validate();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.validateWithOptions"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return @"cpz.reader".validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.totalSize"(@"cpz.reader": *cpz.OwnedMessageReader) !cpz.MessageSize {{
        \\        return @"cpz.reader".totalSize();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.totalSizeWithOptions"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return @"cpz.reader".totalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.segmentCount"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".segmentCount();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.segmentBytes"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.index": usize) !cpz.serialize.ConstSegment {{
        \\        return @"cpz.reader".segmentBytes(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.segmentByteLen"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.index": usize) !usize {{
        \\        return @"cpz.reader".segmentByteLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.segmentWordLen"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.index": usize) !usize {{
        \\        return @"cpz.reader".segmentWordLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.serializedSize"(@"cpz.reader": *const cpz.OwnedMessageReader) !usize {{
        \\        return @"cpz.reader".serializedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.serializedSizeInWords"(@"cpz.reader": *const cpz.OwnedMessageReader) !usize {{
        \\        return @"cpz.reader".serializedSizeInWords();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.segmentTable"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader) ![]u8 {{
        \\        return @"cpz.reader".serializeSegmentTable(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.toFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader) ![]u8 {{
        \\        return @"cpz.reader".toFlatBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.toFlatBytesInto"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.reader".toFlatBytesInto(@"cpz.dest");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.writeToWriter"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.reader".writeToWriter(@"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.toPackedBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader) ![]u8 {{
        \\        return @"cpz.reader".toPackedBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.packedSize"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader) !usize {{
        \\        return @"cpz.reader".packedSize(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.packedSizeWithTableBuffer"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.tableBuffer": []u8) !usize {{
        \\        return @"cpz.reader".packedSizeWithTableBuffer(@"cpz.tableBuffer");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.maxPackedSize"(@"cpz.reader": *const cpz.OwnedMessageReader) !usize {{
        \\        return @"cpz.reader".maxPackedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.toPackedBytesInto"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.tableBuffer": []u8, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.reader".toPackedBytesInto(@"cpz.tableBuffer", @"cpz.dest");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.writePackedToWriter"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.reader".writePackedToWriter(@"cpz.allocator", @"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.writePackedToWriterWithTableBuffer"(@"cpz.reader": *const cpz.OwnedMessageReader, @"cpz.tableBuffer": []u8, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.reader".writePackedToWriterWithTableBuffer(@"cpz.tableBuffer", @"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.toCanonicalSegmentBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader) ![]u8 {{
        \\        return @"cpz.reader".toCanonicalSegmentBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.toSingleSegmentFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.reader": *const cpz.OwnedMessageReader) ![]u8 {{
        \\        return @"cpz.reader".toSingleSegmentFlatBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.owned.sourceConsumedLen"(@"cpz.reader": *const cpz.OwnedMessageReader) usize {{
        \\        return @"cpz.reader".sourceConsumedLen();
        \\    }}
        \\
        \\    pub fn @"cpz.owned.bytes"(@"cpz.reader": *const cpz.OwnedMessageReader) []const u8 {{
        \\        return @"cpz.reader".bytes();
        \\    }}
        \\
        \\    pub fn @"cpz.view.consumedLen"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".consumedLen();
        \\    }}
        \\
        \\    pub fn @"cpz.view.asReader"(@"cpz.view": *cpz.MessageReaderView) *cpz.MessageReader {{
        \\        return @"cpz.view".asReader();
        \\    }}
        \\
        \\    pub fn @"cpz.view.root"(@"cpz.view": *cpz.MessageReaderView) !@This() {{
        \\        return getRoot(@"cpz.view".asReader());
        \\    }}
        \\
        \\    pub fn @"cpz.view.isNull"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootNull();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointer"(@"cpz.view": *cpz.MessageReaderView) !cpz.PointerReader {{
        \\        return @"cpz.view".getRootPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsNull"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return (try @"cpz.view".getRootPointer()).isNull();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerSegmentId"(@"cpz.view": *cpz.MessageReaderView) !u32 {{
        \\        return (try @"cpz.view".getRootPointer()).segmentId();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerWordIndex"(@"cpz.view": *cpz.MessageReaderView) !usize {{
        \\        return (try @"cpz.view".getRootPointer()).pointerWordIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerMatchesLocation"(@"cpz.view": *cpz.MessageReaderView, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
        \\        return (try @"cpz.view".getRootPointer()).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerKind"(@"cpz.view": *cpz.MessageReaderView) !?cpz.wire.PointerType {{
        \\        return @"cpz.view".getRootPointerKind();
        \\    }}
        \\
        \\    pub fn @"cpz.view.matchesPointerKind"(@"cpz.view": *cpz.MessageReaderView, @"cpz.kind": cpz.wire.PointerType) !bool {{
        \\        return @"cpz.view".matchesRootPointerType(@"cpz.kind");
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsStruct"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootStructPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsList"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootListPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsFar"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootFarPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsOther"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootOtherPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsCapability"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootCapabilityPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.pointerIsNear"(@"cpz.view": *cpz.MessageReaderView) !bool {{
        \\        return @"cpz.view".isRootNearPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.rawPointer"(@"cpz.view": *cpz.MessageReaderView) !cpz.Word {{
        \\        return @"cpz.view".getRootRawPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.decodedPointer"(@"cpz.view": *cpz.MessageReaderView) !?cpz.wire.DecodedPointer {{
        \\        return @"cpz.view".getRootDecodedPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.view.stats"(@"cpz.view": *cpz.MessageReaderView) !cpz.MessageStats {{
        \\        return (try @"cpz.view".getRootPointer()).validate();
        \\    }}
        \\
        \\    pub fn @"cpz.view.statsWithOptions"(@"cpz.view": *cpz.MessageReaderView, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return (try @"cpz.view".getRootPointer()).validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.view.totalSizeRoot"(@"cpz.view": *cpz.MessageReaderView) !cpz.MessageSize {{
        \\        return (try @"cpz.view.stats"(@"cpz.view")).size();
        \\    }}
        \\
        \\    pub fn @"cpz.view.totalSizeRootWithOptions"(@"cpz.view": *cpz.MessageReaderView, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return (try @"cpz.view.statsWithOptions"(@"cpz.view", @"cpz.options")).size();
        \\    }}
        \\
        \\    pub fn @"cpz.view.text"(@"cpz.view": *cpz.MessageReaderView) ![]const u8 {{
        \\        return @"cpz.view".getRootText();
        \\    }}
        \\
        \\    pub fn @"cpz.view.textDefault"(@"cpz.view": *cpz.MessageReaderView, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.view".getRootTextDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.view.textDefaultByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.view".getRootTextDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.view.textDefaultMatchesBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.view".rootTextDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.textByteCount"(@"cpz.view": *cpz.MessageReaderView) !usize {{
        \\        return @"cpz.view".getRootTextByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.textMatchesBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.count": usize) !bool {{
        \\        return @"cpz.view".rootTextMatchesBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.data"(@"cpz.view": *cpz.MessageReaderView) ![]const u8 {{
        \\        return @"cpz.view".getRootData();
        \\    }}
        \\
        \\    pub fn @"cpz.view.dataDefault"(@"cpz.view": *cpz.MessageReaderView, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.view".getRootDataDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.view.dataDefaultByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.view".getRootDataDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.view.dataDefaultMatchesBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.view".rootDataDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.dataByteCount"(@"cpz.view": *cpz.MessageReaderView) !usize {{
        \\        return @"cpz.view".getRootDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.dataMatchesBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.count": usize) !bool {{
        \\        return @"cpz.view".rootDataMatchesBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.capability"(@"cpz.view": *cpz.MessageReaderView) !u32 {{
        \\        return @"cpz.view".getRootCapability();
        \\    }}
        \\
        \\    pub fn @"cpz.view.list"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !cpz.ListReader {{
        \\        return @"cpz.view".getRootList(@"cpz.elementSize");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listLen"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).len();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesLen"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesLen(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listIsEmpty"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).isEmpty();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listHasIndex"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.index": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).hasIndex(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listFirstIndex"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).firstIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listLastIndex"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).lastIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listElementSize"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !cpz.ElementSize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).elementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesElementSize"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listElementBitCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).elementBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesElementBits"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesElementBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listElementByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).elementByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesElementBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesElementBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listElementWordCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).elementWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesElementWords"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesElementWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listContentBitCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).contentBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesContentBits"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesContentBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listContentByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).contentByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesContentBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesContentBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listContentWordCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).contentWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesContentWords"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesContentWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementSize"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !cpz.StructSize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementDataWordCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementDataWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementPointerCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementPointerCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementTotalWords"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementTotalWords();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementDataByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementPointerByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementPointerByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listStructElementTotalByteCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).structElementTotalByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementSize"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.StructSize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementDataWords"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementDataWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementPointerCount"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementPointerCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementTotalWords"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementTotalWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementDataBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementDataBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementPointerBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementPointerBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.listMatchesStructElementTotalBytes"(@"cpz.view": *cpz.MessageReaderView, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.view.list"(@"cpz.view", @"cpz.elementSize")).matchesStructElementTotalBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.traversalLimitWords"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".traversalLimitWords();
        \\    }}
        \\
        \\    pub fn @"cpz.view.traversalLimitBytes"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".traversalLimitBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.view.matchesTraversalLimitWords"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.count": usize) bool {{
        \\        return @"cpz.view".matchesTraversalLimitWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.matchesTraversalLimitBytes"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.count": usize) bool {{
        \\        return @"cpz.view".matchesTraversalLimitBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.traversalRemainingWords"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".traversalRemainingWords();
        \\    }}
        \\
        \\    pub fn @"cpz.view.traversalRemainingBytes"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".traversalRemainingBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.view.nestingLimit"(@"cpz.view": *const cpz.MessageReaderView) u16 {{
        \\        return @"cpz.view".nestingLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.view.matchesNestingLimit"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.count": u16) bool {{
        \\        return @"cpz.view".matchesNestingLimit(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.capabilityCountLimit"(@"cpz.view": *const cpz.MessageReaderView) ?usize {{
        \\        return @"cpz.view".capabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.view.hasCapabilityCountLimit"(@"cpz.view": *const cpz.MessageReaderView) bool {{
        \\        return @"cpz.view".hasCapabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.view.matchesCapabilityCountLimit"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.count": usize) bool {{
        \\        return @"cpz.view".matchesCapabilityCountLimit(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.view.validate"(@"cpz.view": *cpz.MessageReaderView) !cpz.MessageStats {{
        \\        return @"cpz.view".validate();
        \\    }}
        \\
        \\    pub fn @"cpz.view.validateWithOptions"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return @"cpz.view".validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.view.totalSize"(@"cpz.view": *cpz.MessageReaderView) !cpz.MessageSize {{
        \\        return @"cpz.view".totalSize();
        \\    }}
        \\
        \\    pub fn @"cpz.view.totalSizeWithOptions"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return @"cpz.view".totalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.view.segmentCount"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".segmentCount();
        \\    }}
        \\
        \\    pub fn @"cpz.view.segmentBytes"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.index": usize) !cpz.serialize.ConstSegment {{
        \\        return @"cpz.view".segmentBytes(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.view.segmentByteLen"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.index": usize) !usize {{
        \\        return @"cpz.view".segmentByteLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.view.segmentWordLen"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.index": usize) !usize {{
        \\        return @"cpz.view".segmentWordLen(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.view.serializedSize"(@"cpz.view": *const cpz.MessageReaderView) !usize {{
        \\        return @"cpz.view".serializedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.view.serializedSizeInWords"(@"cpz.view": *const cpz.MessageReaderView) !usize {{
        \\        return @"cpz.view".serializedSizeInWords();
        \\    }}
        \\
        \\    pub fn @"cpz.view.segmentTable"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView) ![]u8 {{
        \\        return @"cpz.view".serializeSegmentTable(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.view.toFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView) ![]u8 {{
        \\        return @"cpz.view".toFlatBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.view.toFlatBytesInto"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.view".toFlatBytesInto(@"cpz.dest");
        \\    }}
        \\
        \\    pub fn @"cpz.view.writeToWriter"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.view".writeToWriter(@"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.view.toPackedBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView) ![]u8 {{
        \\        return @"cpz.view".toPackedBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.view.packedSize"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView) !usize {{
        \\        return @"cpz.view".packedSize(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.view.packedSizeWithTableBuffer"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.tableBuffer": []u8) !usize {{
        \\        return @"cpz.view".packedSizeWithTableBuffer(@"cpz.tableBuffer");
        \\    }}
        \\
        \\    pub fn @"cpz.view.maxPackedSize"(@"cpz.view": *const cpz.MessageReaderView) !usize {{
        \\        return @"cpz.view".maxPackedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.view.toPackedBytesInto"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.tableBuffer": []u8, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.view".toPackedBytesInto(@"cpz.tableBuffer", @"cpz.dest");
        \\    }}
        \\
        \\    pub fn @"cpz.view.writePackedToWriter"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.view".writePackedToWriter(@"cpz.allocator", @"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.view.writePackedToWriterWithTableBuffer"(@"cpz.view": *const cpz.MessageReaderView, @"cpz.tableBuffer": []u8, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.view".writePackedToWriterWithTableBuffer(@"cpz.tableBuffer", @"cpz.writer");
        \\    }}
        \\
        \\    pub fn @"cpz.view.toCanonicalSegmentBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView) ![]u8 {{
        \\        return @"cpz.view".toCanonicalSegmentBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.view.toSingleSegmentFlatBytes"(@"cpz.allocator": std.mem.Allocator, @"cpz.view": *const cpz.MessageReaderView) ![]u8 {{
        \\        return @"cpz.view".toSingleSegmentFlatBytes(@"cpz.allocator");
        \\    }}
        \\
        \\    pub fn @"cpz.view.sourceConsumedLen"(@"cpz.view": *const cpz.MessageReaderView) usize {{
        \\        return @"cpz.view".sourceConsumedLen();
        \\    }}
        \\
        \\    pub fn @"cpz.view.bytes"(@"cpz.view": *const cpz.MessageReaderView) []const u8 {{
        \\        return @"cpz.view".bytes();
        \\    }}
        \\
        \\    pub fn @"cpz.root.traversalLimitWords"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".traversalLimitWords();
        \\    }}
        \\
        \\    pub fn @"cpz.root.traversalLimitBytes"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".traversalLimitBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.root.matchesTraversalLimitWords"(@"cpz.reader": *cpz.MessageReader, @"cpz.count": usize) bool {{
        \\        return @"cpz.reader".matchesTraversalLimitWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.matchesTraversalLimitBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.count": usize) bool {{
        \\        return @"cpz.reader".matchesTraversalLimitBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.traversalRemainingWords"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".traversalRemainingWords();
        \\    }}
        \\
        \\    pub fn @"cpz.root.traversalRemainingBytes"(@"cpz.reader": *cpz.MessageReader) usize {{
        \\        return @"cpz.reader".traversalRemainingBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.root.nestingLimit"(@"cpz.reader": *cpz.MessageReader) u16 {{
        \\        return @"cpz.reader".nestingLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.root.matchesNestingLimit"(@"cpz.reader": *cpz.MessageReader, @"cpz.count": u16) bool {{
        \\        return @"cpz.reader".matchesNestingLimit(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.capabilityCountLimit"(@"cpz.reader": *cpz.MessageReader) ?usize {{
        \\        return @"cpz.reader".capabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.root.hasCapabilityCountLimit"(@"cpz.reader": *cpz.MessageReader) bool {{
        \\        return @"cpz.reader".hasCapabilityCountLimit();
        \\    }}
        \\
        \\    pub fn @"cpz.root.matchesCapabilityCountLimit"(@"cpz.reader": *cpz.MessageReader, @"cpz.count": usize) bool {{
        \\        return @"cpz.reader".matchesCapabilityCountLimit(@"cpz.count");
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
        \\    pub fn @"cpz.root.messageTotalSize"(@"cpz.reader": *cpz.MessageReader) !cpz.MessageSize {{
        \\        return @"cpz.reader".totalSize();
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
        \\    pub fn @"cpz.builderRoot.matchesPointerKind"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.kind": cpz.wire.PointerType) !bool {{
        \\        return @"cpz.builder".matchesRootPointerType(@"cpz.kind");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsStruct"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return @"cpz.builder".isRootStructPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsList"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return @"cpz.builder".isRootListPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsFar"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return @"cpz.builder".isRootFarPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsOther"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return @"cpz.builder".isRootOtherPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsCapability"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return @"cpz.builder".isRootCapabilityPointer();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerIsNear"(@"cpz.builder": *cpz.MessageBuilder) !bool {{
        \\        return @"cpz.builder".isRootNearPointer();
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
        \\    pub fn @"cpz.builderRoot.pointerSegmentId"(@"cpz.builder": *cpz.MessageBuilder) !u32 {{
        \\        return (try @"cpz.builder".getRootPointer()).segmentId();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerWordIndex"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return (try @"cpz.builder".getRootPointer()).pointerWordIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.pointerMatchesLocation"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
        \\        return (try @"cpz.builder".getRootPointer()).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
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
        \\    pub fn @"cpz.builderRoot.firstSegmentBytes"(@"cpz.builder": *cpz.MessageBuilder) usize {{
        \\        return @"cpz.builder".firstSegmentBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.matchesFirstSegmentWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) bool {{
        \\        return @"cpz.builder".matchesFirstSegmentWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.matchesFirstSegmentBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) bool {{
        \\        return @"cpz.builder".matchesFirstSegmentBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.nextSegmentMinWords"(@"cpz.builder": *cpz.MessageBuilder) usize {{
        \\        return @"cpz.builder".nextSegmentMinWords();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.nextSegmentMinBytes"(@"cpz.builder": *cpz.MessageBuilder) usize {{
        \\        return @"cpz.builder".nextSegmentMinBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.matchesNextSegmentMinWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) bool {{
        \\        return @"cpz.builder".matchesNextSegmentMinWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.matchesNextSegmentMinBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) bool {{
        \\        return @"cpz.builder".matchesNextSegmentMinBytes(@"cpz.count");
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
        \\    pub fn @"cpz.builderRoot.messageTotalSize"(@"cpz.builder": *cpz.MessageBuilder) !cpz.MessageSize {{
        \\        return @"cpz.builder".totalSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.messageTotalSizeWithOptions"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return @"cpz.builder".totalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toFlatBytes"(@"cpz.builder": *cpz.MessageBuilder) ![]u8 {{
        \\        return @"cpz.builder".toFlatBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toFlatBytesInto"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.builder".toFlatBytesInto(@"cpz.dest");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toPackedBytes"(@"cpz.builder": *cpz.MessageBuilder) ![]u8 {{
        \\        return @"cpz.builder".toPackedBytes();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.packedSize"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return @"cpz.builder".packedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.packedSizeWithTableBuffer"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.tableBuffer": []u8) !usize {{
        \\        return @"cpz.builder".packedSizeWithTableBuffer(@"cpz.tableBuffer");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.maxPackedSize"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return @"cpz.builder".maxPackedSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.toPackedBytesInto"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.tableBuffer": []u8, @"cpz.dest": []u8) !usize {{
        \\        return @"cpz.builder".toPackedBytesInto(@"cpz.tableBuffer", @"cpz.dest");
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
        \\    pub fn @"cpz.builderRoot.writePackedToWriterWithTableBuffer"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.tableBuffer": []u8, @"cpz.writer": *std.Io.Writer) !void {{
        \\        return @"cpz.builder".writePackedToWriterWithTableBuffer(@"cpz.tableBuffer", @"cpz.writer");
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
        \\    pub fn @"cpz.root.listLen"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).len();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesLen"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesLen(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listIsEmpty"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).isEmpty();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listHasIndex"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.index": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).hasIndex(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listFirstIndex"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).firstIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listLastIndex"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).lastIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listElementSize"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !cpz.ElementSize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).elementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesElementSize"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listElementBitCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).elementBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesElementBits"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listElementByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).elementByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesElementBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listElementWordCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).elementWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesElementWords"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesElementWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listContentBitCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).contentBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesContentBits"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesContentBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listContentByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).contentByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listContentWordCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).contentWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesContentWords"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesContentWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesContentBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesContentBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementSize"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !cpz.StructSize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementDataWordCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementDataWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementPointerCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementPointerCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementTotalWords"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementTotalWords();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementDataByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementPointerByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementPointerByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listStructElementTotalByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).structElementTotalByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementSize"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.StructSize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementDataWords"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementDataWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementPointerCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementPointerCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementTotalWords"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementTotalWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementDataBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementDataBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementPointerBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementPointerBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.listMatchesStructElementTotalBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.root.list"(@"cpz.reader", @"cpz.elementSize")).matchesStructElementTotalBytes(@"cpz.count");
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
        \\    pub fn @"cpz.builderRoot.listLen"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).len();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesLen"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesLen(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listIsEmpty"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).isEmpty();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listHasIndex"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.index": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).hasIndex(@"cpz.index");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listFirstIndex"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).firstIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listLastIndex"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).lastIndex();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listElementSize"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !cpz.ElementSize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).elementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesElementSize"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.ElementSize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listElementBitCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).elementBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesElementBits"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesElementBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listElementByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).elementByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesElementBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesElementBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listElementWordCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).elementWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesElementWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesElementWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listContentBitCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).contentBitCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesContentBits"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesContentBits(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listContentByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).contentByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listContentWordCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).contentWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesContentWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesContentWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesContentBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesContentBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementSize"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !cpz.StructSize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementSize();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementDataWordCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementDataWordCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementPointerCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !u16 {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementPointerCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementTotalWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementTotalWords();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementDataByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementPointerByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementPointerByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listStructElementTotalByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize) !usize {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).structElementTotalByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementSize"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.expected": cpz.StructSize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementDataWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementDataWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementPointerCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementPointerCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementTotalWords"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementTotalWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementDataBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementDataBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementPointerBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementPointerBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.listMatchesStructElementTotalBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try @"cpz.builderRoot.list"(@"cpz.builder", @"cpz.elementSize")).matchesStructElementTotalBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.text"(@"cpz.reader": *cpz.MessageReader) ![]const u8 {{
        \\        return @"cpz.reader".getRootText();
        \\    }}
        \\
        \\    pub fn @"cpz.root.textDefault"(@"cpz.reader": *cpz.MessageReader, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.reader".getRootTextDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.root.textDefaultByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.reader".getRootTextDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.root.textDefaultMatchesBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootTextDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.textByteCount"(@"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return @"cpz.reader".getRootTextByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.textMatchesBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootTextMatchesBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.data"(@"cpz.reader": *cpz.MessageReader) ![]const u8 {{
        \\        return @"cpz.reader".getRootData();
        \\    }}
        \\
        \\    pub fn @"cpz.root.dataDefault"(@"cpz.reader": *cpz.MessageReader, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.reader".getRootDataDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.root.dataDefaultByteCount"(@"cpz.reader": *cpz.MessageReader, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.reader".getRootDataDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.root.dataDefaultMatchesBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootDataDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.root.dataByteCount"(@"cpz.reader": *cpz.MessageReader) !usize {{
        \\        return @"cpz.reader".getRootDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.root.dataMatchesBytes"(@"cpz.reader": *cpz.MessageReader, @"cpz.count": usize) !bool {{
        \\        return @"cpz.reader".rootDataMatchesBytes(@"cpz.count");
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
        \\    pub fn @"cpz.builderRoot.textDefault"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.builder".getRootTextDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.textDefaultByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.builder".getRootTextDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.textDefaultMatchesBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.builder".rootTextDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.textByteCount"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return @"cpz.builder".getRootTextByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.textMatchesBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) !bool {{
        \\        return @"cpz.builder".rootTextMatchesBytes(@"cpz.count");
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
        \\    pub fn @"cpz.builderRoot.dataDefault"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.default": []const u8) ![]const u8 {{
        \\        return @"cpz.builder".getRootDataDefault(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.dataDefaultByteCount"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.default": []const u8) !usize {{
        \\        return @"cpz.builder".getRootDataDefaultByteCount(@"cpz.default");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.dataDefaultMatchesBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.default": []const u8, @"cpz.count": usize) !bool {{
        \\        return @"cpz.builder".rootDataDefaultMatchesBytes(@"cpz.default", @"cpz.count");
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.dataByteCount"(@"cpz.builder": *cpz.MessageBuilder) !usize {{
        \\        return @"cpz.builder".getRootDataByteCount();
        \\    }}
        \\
        \\    pub fn @"cpz.builderRoot.dataMatchesBytes"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) !bool {{
        \\        return @"cpz.builder".rootDataMatchesBytes(@"cpz.count");
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
        \\    pub fn @"cpz.root.copyFromBuilder"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": Builder) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.builder".copyRootFromBuilder(@"cpz.source".builder));
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyPointerFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": cpz.PointerReader) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".copyRootPointerFrom(@"cpz.source");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyPointerFromBuilder"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": cpz.PointerBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".copyRootPointerFromBuilder(@"cpz.source");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyTo"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.source".copyRootTo(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyToBuilder"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.source".copyRootToBuilder(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyTypedTo"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !Builder {{
        \\        _ = try @"cpz.source".copyRootTo(@"cpz.target");
        \\        return getRootTyped(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyTypedToBuilder"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !Builder {{
        \\        _ = try @"cpz.source".copyRootToBuilder(@"cpz.target");
        \\        return getRootTyped(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": *cpz.MessageReader) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.builder".copyRootCanonicalFrom(@"cpz.source"));
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalFromBuilder"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": Builder) !Builder {{
        \\        return Builder.fromBuilder(try @"cpz.builder".copyRootCanonicalFromBuilder(@"cpz.source".builder));
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyPointerCanonicalFrom"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": cpz.PointerReader) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".copyRootPointerCanonicalFrom(@"cpz.source");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyPointerCanonicalFromBuilder"(@"cpz.builder": *cpz.MessageBuilder, @"cpz.source": cpz.PointerBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.builder".copyRootPointerCanonicalFromBuilder(@"cpz.source");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalTo"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.source".copyRootCanonicalTo(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalToBuilder"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !cpz.PointerBuilder {{
        \\        return @"cpz.source".copyRootCanonicalToBuilder(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalTypedTo"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !Builder {{
        \\        _ = try @"cpz.source".copyRootCanonicalTo(@"cpz.target");
        \\        return getRootTyped(@"cpz.target");
        \\    }}
        \\
        \\    pub fn @"cpz.root.copyCanonicalTypedToBuilder"(@"cpz.source": *cpz.MessageBuilder, @"cpz.target": *cpz.MessageBuilder) !Builder {{
        \\        _ = try @"cpz.source".copyRootCanonicalToBuilder(@"cpz.target");
        \\        return getRootTyped(@"cpz.target");
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
        \\    pub fn newOrphanCopyCanonical(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.builder".newOrphanCopyStructCanonical(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn newOrphanCopyFromBuilder(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": Builder) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.builder".newOrphanCopyStructFromBuilder(@"cpz.value".builder));
        \\    }}
        \\
        \\    pub fn newOrphanCopyCanonicalFromBuilder(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": Builder) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.builder".newOrphanCopyStructCanonicalFromBuilder(@"cpz.value".builder));
        \\    }}
        \\
        \\    pub fn newOrphanCopyIn(@"cpz.orphanage": cpz.Orphanage, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.orphanage".newCopyStruct(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn newOrphanCopyCanonicalIn(@"cpz.orphanage": cpz.Orphanage, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.orphanage".newCopyStructCanonical(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn newOrphanCopyFromBuilderIn(@"cpz.orphanage": cpz.Orphanage, @"cpz.value": Builder) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.orphanage".newCopyStructFromBuilder(@"cpz.value".builder));
        \\    }}
        \\
        \\    pub fn newOrphanCopyCanonicalFromBuilderIn(@"cpz.orphanage": cpz.Orphanage, @"cpz.value": Builder) !Orphan {{
        \\        return Orphan.fromOrphan(try @"cpz.orphanage".newCopyStructCanonicalFromBuilder(@"cpz.value".builder));
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
        \\    pub fn validateWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\        return self.reader.validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\        return self.reader.totalSize();
        \\    }}
        \\
        \\    pub fn totalSizeWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\        return self.reader.totalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn actualSize(self: @This()) cpz.StructSize {{
        \\        return self.reader.size();
        \\    }}
        \\
        \\    pub fn actualDataWordCount(self: @This()) u16 {{
        \\        return self.actualSize().dataWordCount();
        \\    }}
        \\
        \\    pub fn actualPointerCount(self: @This()) u16 {{
        \\        return self.actualSize().pointerCount();
        \\    }}
        \\
        \\    pub fn actualTotalWords(self: @This()) usize {{
        \\        return self.actualSize().totalWords();
        \\    }}
        \\
        \\    pub fn actualDataByteCount(self: @This()) usize {{
        \\        return self.actualSize().dataByteCount();
        \\    }}
        \\
        \\    pub fn actualPointerByteCount(self: @This()) usize {{
        \\        return self.actualSize().pointerByteCount();
        \\    }}
        \\
        \\    pub fn actualTotalByteCount(self: @This()) usize {{
        \\        return self.actualSize().totalByteCount();
        \\    }}
        \\
        \\    pub fn matchesActualSize(self: @This(), @"cpz.expected": cpz.StructSize) bool {{
        \\        const actual = self.actualSize();
        \\        return actual.data_words == @"cpz.expected".data_words and actual.pointer_count == @"cpz.expected".pointer_count;
        \\    }}
        \\
        \\    pub fn matchesActualDataWords(self: @This(), @"cpz.count": u16) bool {{
        \\        return self.actualSize().matchesDataWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn matchesActualPointerCount(self: @This(), @"cpz.count": u16) bool {{
        \\        return self.actualSize().matchesPointerCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn matchesActualTotalWords(self: @This(), @"cpz.count": usize) bool {{
        \\        return self.actualSize().matchesTotalWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn matchesActualDataBytes(self: @This(), @"cpz.count": usize) bool {{
        \\        return self.actualSize().matchesDataBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn matchesActualPointerBytes(self: @This(), @"cpz.count": usize) bool {{
        \\        return self.actualSize().matchesPointerBytes(@"cpz.count");
        \\    }}
        \\
        \\    pub fn matchesActualTotalBytes(self: @This(), @"cpz.count": usize) bool {{
        \\        return self.actualSize().matchesTotalBytes(@"cpz.count");
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
        const resolved_field_ty = resolveTypeScoped(file, layout.decl, field_layout.field.ty);
        const needs_list_wrapper = switch (resolved_field_ty) {
            .list => true,
            .optional => |child| resolveTypeScoped(file, layout.decl, child.*) == .list,
            else => false,
        };
        if (needs_list_wrapper) {
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
        \\        pub fn validateWithOptions(self: Builder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.builder.validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn totalSize(self: Builder) !cpz.MessageSize {{
        \\            return self.builder.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: Builder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.builder.totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn actualSize(self: Builder) cpz.StructSize {{
        \\            return self.builder.size();
        \\        }}
        \\
        \\        pub fn actualDataWordCount(self: Builder) u16 {{
        \\            return self.actualSize().dataWordCount();
        \\        }}
        \\
        \\        pub fn actualPointerCount(self: Builder) u16 {{
        \\            return self.actualSize().pointerCount();
        \\        }}
        \\
        \\        pub fn actualTotalWords(self: Builder) usize {{
        \\            return self.actualSize().totalWords();
        \\        }}
        \\
        \\        pub fn actualDataByteCount(self: Builder) usize {{
        \\            return self.actualSize().dataByteCount();
        \\        }}
        \\
        \\        pub fn actualPointerByteCount(self: Builder) usize {{
        \\            return self.actualSize().pointerByteCount();
        \\        }}
        \\
        \\        pub fn actualTotalByteCount(self: Builder) usize {{
        \\            return self.actualSize().totalByteCount();
        \\        }}
        \\
        \\        pub fn matchesActualSize(self: Builder, @"cpz.expected": cpz.StructSize) bool {{
        \\            const actual = self.actualSize();
        \\            return actual.data_words == @"cpz.expected".data_words and actual.pointer_count == @"cpz.expected".pointer_count;
        \\        }}
        \\
        \\        pub fn matchesActualDataWords(self: Builder, @"cpz.count": u16) bool {{
        \\            return self.actualSize().matchesDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesActualPointerCount(self: Builder, @"cpz.count": u16) bool {{
        \\            return self.actualSize().matchesPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesActualTotalWords(self: Builder, @"cpz.count": usize) bool {{
        \\            return self.actualSize().matchesTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesActualDataBytes(self: Builder, @"cpz.count": usize) bool {{
        \\            return self.actualSize().matchesDataBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesActualPointerBytes(self: Builder, @"cpz.count": usize) bool {{
        \\            return self.actualSize().matchesPointerBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesActualTotalBytes(self: Builder, @"cpz.count": usize) bool {{
        \\            return self.actualSize().matchesTotalBytes(@"cpz.count");
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
        \\        pub fn copyFromBuilder(self: Builder, @"cpz.value": Builder) !void {{
        \\            return self.builder.copyFromBuilder(@"cpz.value".builder);
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

pub fn emitUnionDeclarations(allocator: std.mem.Allocator, out: *std.ArrayList(u8), layout: *const StructLayout) LayoutError!void {
    for (layout.unions, 0..) |union_layout, union_index| {
        try appendFmt(allocator, out,
            \\    pub const Union{} = enum(u16) {{
            \\
        , .{union_index});
        var emitted_discriminants = std.AutoHashMap(u16, void).init(allocator);
        defer emitted_discriminants.deinit();
        for (layout.fields) |field_layout| {
            const field = field_layout.field;
            if (field.union_index == null or field.union_index.? != union_index) continue;
            const entry = try emitted_discriminants.getOrPut(field.union_discriminant);
            if (entry.found_existing) continue;
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
            \\    pub fn union{}Discriminant(self: @This()) u16 {{
            \\        return self.reader.getUInt16({}, 0);
            \\    }}
            \\
            \\    pub fn union{}(self: @This()) ?Union{} {{
            \\        return std.enums.fromInt(Union{}, self.union{}Discriminant());
            \\    }}
            \\
            \\    pub fn union{}Is(self: @This(), tag: Union{}) bool {{
            \\        return self.union{}() == tag;
            \\    }}
            \\
            \\    pub fn union{}MatchesDiscriminant(self: @This(), discriminant: u16) bool {{
            \\        return self.union{}Discriminant() == discriminant;
            \\    }}
            \\
            \\    pub fn union{}Field(self: @This()) ?cpz.schema.FieldMetadata {{
            \\        return @This().@"cpz.union.{}.fieldByDiscriminant"(self.union{}Discriminant());
            \\    }}
            \\
            \\
        , .{ union_index, union_layout.discriminant_byte, union_index, union_index, union_index, union_index, union_index, union_index, union_index, union_index, union_index, union_index, union_index, union_index });
    }
    if (layout.unions.len == 1) {
        try appendFmt(allocator, out,
            \\    pub fn whichDiscriminant(self: @This()) u16 {{
            \\        return self.union0Discriminant();
            \\    }}
            \\
            \\    pub fn which(self: @This()) ?Union0 {{
            \\        return self.union0();
            \\    }}
            \\
            \\    pub fn whichIs(self: @This(), tag: Union0) bool {{
            \\        return self.union0Is(tag);
            \\    }}
            \\
            \\    pub fn whichMatchesDiscriminant(self: @This(), discriminant: u16) bool {{
            \\        return self.union0MatchesDiscriminant(discriminant);
            \\    }}
            \\
            \\    pub fn whichField(self: @This()) ?cpz.schema.FieldMetadata {{
            \\        return self.union0Field();
            \\    }}
            \\
            \\
        , .{});
    }
}

pub fn emitBuilderUnionHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), owner_name: []const u8, layout: *const StructLayout) LayoutError!void {
    for (layout.unions, 0..) |union_layout, union_index| {
        try appendFmt(allocator, out,
            \\        pub fn union{}Discriminant(self: Builder) !u16 {{
            \\            return self.builder.getUInt16({}, 0);
            \\        }}
            \\
            \\        pub fn union{}(self: Builder) !?{s}.Union{} {{
            \\            return std.enums.fromInt({s}.Union{}, try self.union{}Discriminant());
            \\        }}
            \\
            \\        pub fn union{}Is(self: Builder, tag: {s}.Union{}) !bool {{
            \\            return (try self.union{}()) == tag;
            \\        }}
            \\
            \\        pub fn union{}MatchesDiscriminant(self: Builder, discriminant: u16) !bool {{
            \\            return (try self.union{}Discriminant()) == discriminant;
            \\        }}
            \\
            \\        pub fn union{}Field(self: Builder) !?cpz.schema.FieldMetadata {{
            \\            return {s}.@"cpz.union.{}.fieldByDiscriminant"(try self.union{}Discriminant());
            \\        }}
            \\
        , .{ union_index, union_layout.discriminant_byte, union_index, owner_name, union_index, owner_name, union_index, union_index, union_index, owner_name, union_index, union_index, union_index, union_index, union_index, owner_name, union_index, union_index });
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
            \\        pub fn whichDiscriminant(self: Builder) !u16 {{
            \\            return self.union0Discriminant();
            \\        }}
            \\
            \\        pub fn which(self: Builder) !?{s}.Union0 {{
            \\            return self.union0();
            \\        }}
            \\
            \\        pub fn whichIs(self: Builder, tag: {s}.Union0) !bool {{
            \\            return self.union0Is(tag);
            \\        }}
            \\
            \\        pub fn whichMatchesDiscriminant(self: Builder, discriminant: u16) !bool {{
            \\            return self.union0MatchesDiscriminant(discriminant);
            \\        }}
            \\
            \\        pub fn whichField(self: Builder) !?cpz.schema.FieldMetadata {{
            \\            return self.union0Field();
            \\        }}
            \\
            \\
        , .{ owner_name, owner_name });
    }
}

pub fn emitFieldGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    if (emit_metadata_enabled) {
        const field_name_literal = try zigStringLiteralAlloc(allocator, field.name);
        defer allocator.free(field_name_literal);
        const field_index = try fieldIndex(layout, field);
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
        const default_expression_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.default_expression);
        defer allocator.free(default_expression_literal);
        const annotation_literal = try zigSchemaSyntaxLiteralAlloc(allocator, field.annotations);
        defer allocator.free(annotation_literal);
        try appendFmt(allocator, out,
            \\    pub const @"cpz.field.{s}.default": []const u8 = {s};
            \\    pub const @"cpz.field.{s}.hasExplicitDefault": bool = {};
            \\    pub const @"cpz.field.{s}.defaultIsHexData": bool = {};
            \\    pub const @"cpz.field.{s}.annotations": []const u8 = {s};
            \\
        , .{ field_name, default_expression_literal, field_name, field.default_expression.len != 0, field_name, field.default_is_hex_data, field_name, annotation_literal });
    }
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
        , .{ field_name, union_layout.discriminant_byte, field.union_discriminant, bit, try resolvedFieldDefaultBoolLiteral(file, layout.decl, field) }) else try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) bool {{
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field_name, bit, try resolvedFieldDefaultBoolLiteral(file, layout.decl, field) }),
        .data_byte => |byte| try emitDataGetter(allocator, out, file, layout, field_name, field, byte),
        .pointer => |index| try emitPointerGetter(allocator, out, file, layout, owner_name, field_name, field, index),
    }
}

pub fn emitDataGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    const union_layout = unionLayoutForField(layout, field);
    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .int8 => try scalarGetter(allocator, out, field_name, "i8", "getInt8", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .int16 => try scalarGetter(allocator, out, field_name, "i16", "getInt16", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .int32 => try scalarGetter(allocator, out, field_name, "i32", "getInt32", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .int64 => try scalarGetter(allocator, out, field_name, "i64", "getInt64", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .uint8 => try scalarGetter(allocator, out, field_name, "u8", "getUInt8", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .uint16 => try scalarGetter(allocator, out, field_name, "u16", "getUInt16", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .uint32 => try scalarGetter(allocator, out, field_name, "u32", "getUInt32", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .uint64 => try scalarGetter(allocator, out, field_name, "u64", "getUInt64", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field.union_discriminant),
        .float32 => try scalarGetter(allocator, out, field_name, "f32", "getFloat32", byte, resolvedFieldDefaultFloatLiteral(file, layout.decl, field, "f32"), union_layout, field.union_discriminant),
        .float64 => try scalarGetter(allocator, out, field_name, "f64", "getFloat64", byte, resolvedFieldDefaultFloatLiteral(file, layout.decl, field, "f64"), union_layout, field.union_discriminant),
        .named => |type_name| {
            const enum_decl = findEnumRelative(file, layout.decl.name, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, enum_decl.name);
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
            , .{ zig_type, byte, try resolvedFieldDefaultEnumOrdinal(file, layout.decl, enum_decl, field), field_name, byte, try resolvedFieldDefaultEnumOrdinal(file, layout.decl, enum_decl, field) });
        },
        else => return error.UnsupportedType,
    }
}

pub fn scalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, method: []const u8, byte: usize, default: []const u8, union_layout: ?UnionLayout, discriminant: u16) !void {
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

pub fn emitPointerGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_name: []const u8, raw_field: *const Field, index: usize) LayoutError!void {
    var optional_field_storage: Field = undefined;
    const field_is_optional = raw_field.ty == .optional;
    const field: *const Field = if (field_is_optional) blk: {
        optional_field_storage = raw_field.*;
        optional_field_storage.ty = raw_field.ty.optional.*;
        break :blk &optional_field_storage;
    } else raw_field;
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
        \\    pub fn {s}PointerSegmentId(self: @This()) !u32 {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).segmentId();
        \\    }}
        \\
        \\    pub fn {s}PointerWordIndex(self: @This()) !usize {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).pointerWordIndex();
        \\    }}
        \\
        \\    pub fn {s}PointerMatchesLocation(self: @This(), @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\    }}
        \\
        \\    pub fn {s}MatchesPointerKind(self: @This(), @"cpz.kind": cpz.wire.PointerType) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).matchesPointerType(@"cpz.kind");
        \\    }}
        \\
        \\    pub fn {s}PointerIsStruct(self: @This()) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).isStructPointer();
        \\    }}
        \\
        \\    pub fn {s}PointerIsList(self: @This()) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).isListPointer();
        \\    }}
        \\
        \\    pub fn {s}PointerIsFar(self: @This()) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).isFarPointer();
        \\    }}
        \\
        \\    pub fn {s}PointerIsOther(self: @This()) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).isOtherPointer();
        \\    }}
        \\
        \\    pub fn {s}PointerIsCapability(self: @This()) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).isCapabilityPointer();
        \\    }}
        \\
        \\    pub fn {s}PointerIsNear(self: @This()) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).isNearPointer();
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
        \\    pub fn {s}MaxCapabilityCount(self: @This()) !usize {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).maxCapabilityCount();
        \\    }}
        \\
        \\    pub fn {s}MatchesMaxCapabilityCount(self: @This(), @"cpz.count": usize) !bool {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).matchesMaxCapabilityCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}Stats(self: @This()) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).validate();
        \\    }}
        \\
        \\    pub fn {s}StatsWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).validateWithOptions(@"cpz.options");
        \\    }}
        \\
        \\    pub fn {s}TotalSize(self: @This()) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).totalSize();
        \\    }}
        \\
        \\    pub fn {s}TotalSizeWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\        return self.reader.getPointerField({}).totalSizeWithOptions(@"cpz.options");
        \\    }}
        \\
    , .{index});
    try appendFmt(allocator, out,
        \\    pub fn {s}StructSize(self: @This()) !cpz.StructSize {{
        \\        return (try self.{s}AsPointer()).getStructSize();
        \\    }}
        \\
        \\    pub fn {s}StructDataWordCount(self: @This()) !u16 {{
        \\        return (try self.{s}AsPointer()).getStructDataWordCount();
        \\    }}
        \\
        \\    pub fn {s}StructPointerCount(self: @This()) !u16 {{
        \\        return (try self.{s}AsPointer()).getStructPointerCount();
        \\    }}
        \\
        \\    pub fn {s}StructTotalWords(self: @This()) !usize {{
        \\        return (try self.{s}AsPointer()).getStructTotalWords();
        \\    }}
        \\
        \\    pub fn {s}StructDataByteCount(self: @This()) !usize {{
        \\        return (try self.{s}AsPointer()).getStructDataByteCount();
        \\    }}
        \\
        \\    pub fn {s}StructPointerByteCount(self: @This()) !usize {{
        \\        return (try self.{s}AsPointer()).getStructPointerByteCount();
        \\    }}
        \\
        \\    pub fn {s}StructTotalByteCount(self: @This()) !usize {{
        \\        return (try self.{s}AsPointer()).getStructTotalByteCount();
        \\    }}
        \\
        \\    pub fn {s}StructMatchesSize(self: @This(), @"cpz.expected": cpz.StructSize) !bool {{
        \\        return (try self.{s}AsPointer()).structMatchesSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}StructMatchesDataWords(self: @This(), @"cpz.count": u16) !bool {{
        \\        return (try self.{s}AsPointer()).structMatchesDataWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}StructMatchesPointerCount(self: @This(), @"cpz.count": u16) !bool {{
        \\        return (try self.{s}AsPointer()).structMatchesPointerCount(@"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}StructMatchesTotalWords(self: @This(), @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).structMatchesTotalWords(@"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}StructMatchesTotalBytes(self: @This(), @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).structMatchesTotalBytes(@"cpz.count");
        \\    }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });
    try appendFmt(allocator, out,
        \\    pub fn {s}ListLen(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListLen(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesLen(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesLen(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListElementSize(self: @This(), @"cpz.expected": ?cpz.ElementSize) !cpz.ElementSize {{
        \\        return (try self.{s}AsPointer()).getListElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesElementSize(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesElementSize(@"cpz.expected", @"cpz.elementSize");
        \\    }}
        \\
        \\    pub fn {s}ListElementBitCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListElementBitCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListElementByteCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListElementByteCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListElementWordCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListElementWordCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListContentBitCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListContentBitCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListContentByteCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListContentByteCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListContentWordCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListContentWordCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesContentBytes(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesContentBytes(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListStructElementSize(self: @This(), @"cpz.expected": ?cpz.ElementSize) !cpz.StructSize {{
        \\        return (try self.{s}AsPointer()).getListStructElementSize(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementSize(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.size": cpz.StructSize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementSize(@"cpz.expected", @"cpz.size");
        \\    }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    try appendFmt(allocator, out,
        \\    pub fn {s}ListIsEmpty(self: @This(), @"cpz.expected": ?cpz.ElementSize) !bool {{
        \\        return (try self.{s}AsPointer()).listIsEmpty(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListHasIndex(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.index": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listHasIndex(@"cpz.expected", @"cpz.index");
        \\    }}
        \\
        \\    pub fn {s}ListFirstIndex(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListFirstIndex(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListLastIndex(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListLastIndex(@"cpz.expected");
        \\    }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    try appendFmt(allocator, out,
        \\    pub fn {s}ListMatchesElementBits(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesElementBits(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesElementBytes(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesElementBytes(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesElementWords(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesElementWords(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesContentBits(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesContentBits(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesContentWords(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesContentWords(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    try appendFmt(allocator, out,
        \\    pub fn {s}ListStructElementDataWordCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\        return (try self.{s}AsPointer()).getListStructElementDataWordCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListStructElementPointerCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\        return (try self.{s}AsPointer()).getListStructElementPointerCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListStructElementTotalWords(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListStructElementTotalWords(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListStructElementDataByteCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListStructElementDataByteCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListStructElementPointerByteCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListStructElementPointerByteCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListStructElementTotalByteCount(self: @This(), @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\        return (try self.{s}AsPointer()).getListStructElementTotalByteCount(@"cpz.expected");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementDataWords(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementDataWords(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementPointerCount(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementPointerCount(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementTotalWords(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementTotalWords(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementDataBytes(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementDataBytes(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementPointerBytes(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementPointerBytes(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
        \\    pub fn {s}ListMatchesStructElementTotalBytes(self: @This(), @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\        return (try self.{s}AsPointer()).listMatchesStructElementTotalBytes(@"cpz.expected", @"cpz.count");
        \\    }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .text => {
            const is_null_default = defaultExpressionIsNullPointer(file, layout.decl, field.default_expression);
            const default_literal = if (is_null_default) null else try fieldBlobDefaultLiteralAlloc(allocator, file, layout.decl, field, true);
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
            try appendFmt(allocator, out,
                \\    pub fn {s}OrNull(self: @This()) !?[]const u8 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        const @"cpz.pointer" = self.reader.getPointerField({});
                \\        if (@"cpz.pointer".isNull()) {{
            , .{index});
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\            return {s};
                    \\
                , .{literal});
            } else {
                try out.appendSlice(allocator,
                    \\            return null;
                    \\
                );
            }
            try appendFmt(allocator, out,
                \\        }}
                \\        return try @"cpz.pointer".getText();
                \\    }}
                \\
                \\    pub fn {s}ByteCount(self: @This()) !usize {{
                \\        return (try self.{s}()).len;
                \\    }}
                \\
                \\    pub fn {s}MatchesBytes(self: @This(), @"cpz.count": usize) !bool {{
                \\        return (try self.{s}ByteCount()) == @"cpz.count";
                \\    }}
                \\
            , .{ field_name, field_name, field_name, field_name });
        },
        .data => {
            const is_null_default = defaultExpressionIsNullPointer(file, layout.decl, field.default_expression);
            const default_literal = if (is_null_default) null else try fieldBlobDefaultLiteralAlloc(allocator, file, layout.decl, field, false);
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
            try appendFmt(allocator, out,
                \\    pub fn {s}OrNull(self: @This()) !?[]const u8 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        const @"cpz.pointer" = self.reader.getPointerField({});
                \\        if (@"cpz.pointer".isNull()) {{
            , .{index});
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\            return {s};
                    \\
                , .{literal});
            } else {
                try out.appendSlice(allocator,
                    \\            return null;
                    \\
                );
            }
            try appendFmt(allocator, out,
                \\        }}
                \\        return try @"cpz.pointer".getData();
                \\    }}
                \\
                \\    pub fn {s}ByteCount(self: @This()) !usize {{
                \\        return (try self.{s}()).len;
                \\    }}
                \\
                \\    pub fn {s}MatchesBytes(self: @This(), @"cpz.count": usize) !bool {{
                \\        return (try self.{s}ByteCount()) == @"cpz.count";
                \\    }}
                \\
            , .{ field_name, field_name, field_name, field_name });
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
                \\    pub fn {s}AsList(self: @This(), @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getList(@"cpz.expected");
                \\    }}
                \\
                \\    pub fn {s}AsText(self: @This()) ![]const u8 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getText();
                \\    }}
                \\
                \\    pub fn {s}AsTextByteCount(self: @This()) !usize {{
                \\        return (try self.{s}()).getTextByteCount();
                \\    }}
                \\
                \\    pub fn {s}AsTextMatchesBytes(self: @This(), @"cpz.count": usize) !bool {{
                \\        return (try self.{s}()).textMatchesBytes(@"cpz.count");
                \\    }}
                \\
                \\    pub fn {s}AsData(self: @This()) ![]const u8 {{
            , .{ index, field_name, field_name, field_name, field_name, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getData();
                \\    }}
                \\
                \\    pub fn {s}AsDataByteCount(self: @This()) !usize {{
                \\        return (try self.{s}()).getDataByteCount();
                \\    }}
                \\
                \\    pub fn {s}AsDataMatchesBytes(self: @This(), @"cpz.count": usize) !bool {{
                \\        return (try self.{s}()).dataMatchesBytes(@"cpz.count");
                \\    }}
                \\
                \\    pub fn {s}AsCapability(self: @This()) !u32 {{
            , .{ index, field_name, field_name, field_name, field_name, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getCapabilityIndex();
                \\    }}
                \\
            , .{index});
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\    pub fn {s}OrNull(self: @This()) !?cpz.PointerReader {{
                , .{field_name});
                try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\        const @"cpz.pointer" = self.reader.getPointerField({});
                    \\        if (@"cpz.pointer".isNull()) return null;
                    \\        return @"cpz.pointer";
                    \\    }}
                    \\
                , .{index});
            }
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
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\    pub fn {s}OrNull(self: @This()) !?cpz.StructReader {{
                , .{field_name});
                try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\        const @"cpz.pointer" = self.reader.getPointerField({});
                    \\        if (@"cpz.pointer".isNull()) return null;
                    \\        return try @"cpz.pointer".getStruct(null);
                    \\    }}
                    \\
                , .{index});
            }
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
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\    pub fn {s}OrNull(self: @This()) !?cpz.ListReader {{
                , .{field_name});
                try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\        const @"cpz.pointer" = self.reader.getPointerField({});
                    \\        if (@"cpz.pointer".isNull()) return null;
                    \\        return try @"cpz.pointer".getList(null);
                    \\    }}
                    \\
                , .{index});
            }
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
                \\    pub fn {s}OrNull(self: @This()) !?u32 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        const @"cpz.pointer" = self.reader.getPointerField({});
                \\        if (@"cpz.pointer".isNull()) return null;
                \\        return try @"cpz.pointer".getCapabilityIndex();
                \\    }}
                \\
                \\    pub fn {s}FromTable(self: @This(), comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return @"cpz.table".getPointer(self.reader.getPointerField({}));
                \\    }}
                \\
                \\    pub fn {s}OrNullFromTable(self: @This(), comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return @"cpz.table".getPointerOrNull(self.reader.getPointerField({}));
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
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\    pub fn {s}OrNull(self: @This()) !?{s}_{s}_List {{
                , .{ field_name, owner_name, field_name });
                try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\        const @"cpz.pointer" = self.reader.getPointerField({});
                    \\        if (@"cpz.pointer".isNull()) return null;
                    \\        return .{{ .list = try @"cpz.pointer".getList({s}) }};
                    \\    }}
                    \\
                , .{ index, try listElementSizeLiteral(file, layout.decl, child.*) });
            }
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
                \\    pub fn {s}OrNull(self: @This()) !?u32 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        const @"cpz.pointer" = self.reader.getPointerField({});
                \\        if (@"cpz.pointer".isNull()) return null;
                \\        return try @"cpz.pointer".getCapabilityIndex();
                \\    }}
                \\
                \\    pub fn {s}FromTable(self: @This(), comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return @"cpz.table".getPointer(self.reader.getPointerField({}));
                \\    }}
                \\
                \\    pub fn {s}OrNullFromTable(self: @This(), comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return @"cpz.table".getPointerOrNull(self.reader.getPointerField({}));
                \\    }}
                \\
            , .{index});
        } else if (!isStructLikeName(file, type_name) or try namedTypeResolvesToGenericParameter(allocator, file, layout.decl, type_name)) {
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
            const effective_type_name = try effectiveNamedTypeNameAlloc(allocator, file, layout.decl, type_name);
            defer allocator.free(effective_type_name);
            const zig_type = try zigTypeRefAlloc(allocator, file, effective_type_name);
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
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\    pub fn {s}OrNull(self: @This()) !?{s} {{
                , .{ field_name, zig_type });
                try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\        const @"cpz.pointer" = self.reader.getPointerField({});
                    \\        if (@"cpz.pointer".isNull()) return null;
                    \\        return {s}.fromReader(try @"cpz.pointer".getStruct(null));
                    \\    }}
                    \\
                , .{ index, zig_type });
            }
        },
        else => return error.UnsupportedType,
    }
}

pub fn emitReaderUnionCheck(allocator: std.mem.Allocator, out: *std.ArrayList(u8), union_layout: ?UnionLayout, discriminant: u16) std.mem.Allocator.Error!void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\
        , .{ u.discriminant_byte, discriminant });
    }
}

pub fn unionLayoutForField(layout: *const StructLayout, field: *const Field) ?UnionLayout {
    const union_index = field.union_index orelse return null;
    return layout.unions[@intCast(union_index)];
}

pub fn emitListWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, owner_name: []const u8, field: *const Field) LayoutError!void {
    const list_type = switch (resolveTypeScoped(file, scope, field.ty)) {
        .list => |child| child,
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .list => |child| child,
            else => return error.UnsupportedType,
        },
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
        \\        pub fn matchesLen(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesLen(@"cpz.count");
        \\        }}
        \\
        \\        pub fn isEmpty(self: @This()) bool {{
        \\            return self.list.isEmpty();
        \\        }}
        \\
        \\        pub fn hasIndex(self: @This(), @"cpz.index": usize) bool {{
        \\            return self.list.hasIndex(@"cpz.index");
        \\        }}
        \\
        \\        pub fn firstIndex(self: @This()) !usize {{
        \\            return self.list.firstIndex();
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
        \\        pub fn validateWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.list.validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.list.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.list.totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn elementSize(self: @This()) cpz.ElementSize {{
        \\            return self.list.elementSize();
        \\        }}
        \\
        \\        pub fn matchesElementSize(self: @This(), @"cpz.expected": cpz.ElementSize) bool {{
        \\            return self.list.matchesElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementBitCount(self: @This()) usize {{
        \\            return self.list.elementBitCount();
        \\        }}
        \\
        \\        pub fn elementByteCount(self: @This()) !usize {{
        \\            return self.list.elementByteCount();
        \\        }}
        \\
        \\        pub fn elementWordCount(self: @This()) !usize {{
        \\            return self.list.elementWordCount();
        \\        }}
        \\
        \\        pub fn contentBitCount(self: @This()) !usize {{
        \\            return self.list.contentBitCount();
        \\        }}
        \\
        \\        pub fn contentByteCount(self: @This()) !usize {{
        \\            return self.list.contentByteCount();
        \\        }}
        \\
        \\        pub fn contentWordCount(self: @This()) !usize {{
        \\            return self.list.contentWordCount();
        \\        }}
        \\
        \\        pub fn matchesElementBits(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesElementBits(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesElementBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesElementBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesElementWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesElementWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentBits(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesContentBits(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesContentBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesContentWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn structElementSize(self: @This()) cpz.StructSize {{
        \\            return self.list.structElementSize();
        \\        }}
        \\
        \\        pub fn matchesStructElementSize(self: @This(), @"cpz.expected": cpz.StructSize) bool {{
        \\            return self.list.matchesStructElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn structElementDataWordCount(self: @This()) u16 {{
        \\            return self.list.structElementDataWordCount();
        \\        }}
        \\
        \\        pub fn structElementPointerCount(self: @This()) u16 {{
        \\            return self.list.structElementPointerCount();
        \\        }}
        \\
        \\        pub fn structElementTotalWords(self: @This()) usize {{
        \\            return self.list.structElementTotalWords();
        \\        }}
        \\
        \\        pub fn structElementDataByteCount(self: @This()) usize {{
        \\            return self.list.structElementDataByteCount();
        \\        }}
        \\
        \\        pub fn structElementPointerByteCount(self: @This()) usize {{
        \\            return self.list.structElementPointerByteCount();
        \\        }}
        \\
        \\        pub fn structElementTotalByteCount(self: @This()) usize {{
        \\            return self.list.structElementTotalByteCount();
        \\        }}
        \\
        \\        pub fn matchesStructElementDataWords(self: @This(), @"cpz.count": u16) bool {{
        \\            return self.list.matchesStructElementDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementPointerCount(self: @This(), @"cpz.count": u16) bool {{
        \\            return self.list.matchesStructElementPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementTotalWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementDataBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementDataBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementPointerBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementPointerBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementTotalBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementTotalBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn slice(self: @This(), @"cpz.start": usize, @"cpz.count": usize) !{s}_{s}_List {{
        \\            return .{{ .list = try self.list.slice(@"cpz.start", @"cpz.count") }};
        \\        }}
        \\
    , .{ owner_name, field_name, owner_name, field_name });

    if (isPointerListElement(file, scope, child)) {
        try emitListReaderPointerElementHelpers(allocator, out);
    }

    switch (resolved_child) {
        .void => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) void {{
            \\            _ = self;
            \\            _ = @"cpz.index";
            \\        }}
            \\
        , .{}),
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) bool {{
            \\            return self.list.getBool(@"cpz.index");
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
            \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
            \\        }}
            \\
            \\        pub fn getByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).len;
            \\        }}
            \\
            \\        pub fn matchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.getByteCount(@"cpz.index")) == @"cpz.count";
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
            \\        }}
            \\
            \\        pub fn getByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).len;
            \\        }}
            \\
            \\        pub fn matchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.getByteCount(@"cpz.index")) == @"cpz.count";
            \\        }}
            \\
        , .{}),
        .any_pointer => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.PointerReader {{
            \\            return self.list.getPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn getAsStruct(self: @This(), @"cpz.index": usize) !cpz.StructReader {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct(null);
            \\        }}
            \\
            \\        pub fn getAsList(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getList(@"cpz.expected");
            \\        }}
            \\
            \\        pub fn getAsText(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
            \\        }}
            \\
            \\        pub fn getAsTextByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).getTextByteCount();
            \\        }}
            \\
            \\        pub fn getAsTextMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.get(@"cpz.index")).textMatchesBytes(@"cpz.count");
            \\        }}
            \\
            \\        pub fn getAsData(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
            \\        }}
            \\
            \\        pub fn getAsDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).getDataByteCount();
            \\        }}
            \\
            \\        pub fn getAsDataMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.get(@"cpz.index")).dataMatchesBytes(@"cpz.count");
            \\        }}
            \\
            \\        pub fn getAsCapability(self: @This(), @"cpz.index": usize) !u32 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn getAsCapabilityFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            \\            return @"cpz.table".getListElement(self.list, @"cpz.index");
            \\        }}
            \\
        , .{}),
        .any_struct => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.StructReader {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct(null);
            \\        }}
            \\
            \\        pub fn pointerSection(self: @This(), @"cpz.index": usize) !cpz.ListReader {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getStruct(null)).pointerSectionAsList();
            \\        }}
            \\
            \\        pub fn dataSection(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getStruct(null)).dataSectionBytes();
            \\        }}
            \\
        , .{}),
        .any_list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getList(null);
            \\        }}
            \\
            \\        pub fn elementSizeAt(self: @This(), @"cpz.index": usize) !cpz.ElementSize {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getList(null)).elementSize();
            \\        }}
            \\
            \\        pub fn structElementSizeAt(self: @This(), @"cpz.index": usize) !cpz.StructSize {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getList(null)).structElementSize();
            \\        }}
            \\
        , .{}),
        .capability => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            \\            return @"cpz.table".getListElement(self.list, @"cpz.index");
            \\        }}
            \\
        , .{}),
        .list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getList(null);
            \\        }}
            \\
        , .{}),
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !{s} {{
                \\            return std.enums.fromInt({s}, self.list.getUInt16(@"cpz.index")) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn getRaw(self: @This(), @"cpz.index": usize) u16 {{
                \\            return self.list.getUInt16(@"cpz.index");
                \\        }}
                \\
            , .{ zig_type, zig_type });
        } else if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
                \\            return @"cpz.table".getListElement(self.list, @"cpz.index");
                \\        }}
                \\
            , .{});
        } else if (!isStructLikeName(file, type_name) or try namedTypeResolvesToGenericParameter(allocator, file, scope, type_name)) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.PointerReader {{
                \\            return self.list.getPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !{s} {{
                \\            return {s}.fromReader(try self.list.getStructElement(@"cpz.index"));
                \\        }}
                \\
            , .{ zig_type, zig_type });
        },
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .text => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?[]const u8 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getText();
                \\        }}
                \\
                \\        pub fn getByteCount(self: @This(), @"cpz.index": usize) !usize {{
                \\            return (try self.get(@"cpz.index")).len;
                \\        }}
                \\
                \\        pub fn matchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
                \\            return (try self.getByteCount(@"cpz.index")) == @"cpz.count";
                \\        }}
                \\
            , .{}),
            .data => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?[]const u8 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getData();
                \\        }}
                \\
                \\        pub fn getByteCount(self: @This(), @"cpz.index": usize) !usize {{
                \\            return (try self.get(@"cpz.index")).len;
                \\        }}
                \\
                \\        pub fn matchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
                \\            return (try self.getByteCount(@"cpz.index")) == @"cpz.count";
                \\        }}
                \\
            , .{}),
            .capability => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?u32 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
                \\            return @"cpz.table".getListElement(self.list, @"cpz.index");
                \\        }}
                \\
                \\        pub fn getOrNullFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
                \\            return @"cpz.table".getListElementOrNull(self.list, @"cpz.index");
                \\        }}
                \\
            , .{}),
            .named => |type_name| if (findInterface(file, type_name) != null) try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?u32 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
                \\            return @"cpz.table".getListElement(self.list, @"cpz.index");
                \\        }}
                \\
                \\        pub fn getOrNullFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
                \\            return @"cpz.table".getListElementOrNull(self.list, @"cpz.index");
                \\        }}
                \\
            , .{}) else if (isStructLikeName(file, type_name)) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn get(self: @This(), @"cpz.index": usize) !{s} {{
                    \\            return {s}.fromReader(try (try self.list.getPointerElement(@"cpz.index")).getStruct(null));
                    \\        }}
                    \\
                    \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?{s} {{
                    \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return {s}.fromReader(try @"cpz.pointer".getStruct(null));
                    \\        }}
                    \\
                , .{ zig_type, zig_type, zig_type, zig_type });
            },
            .any_pointer => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.PointerReader {{
                \\            return self.list.getPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?cpz.PointerReader {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return @"cpz.pointer";
                \\        }}
                \\
            , .{}),
            .any_struct => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.StructReader {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct(null);
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?cpz.StructReader {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getStruct(null);
                \\        }}
                \\
                \\        pub fn pointerSection(self: @This(), @"cpz.index": usize) !cpz.ListReader {{
                \\            return (try self.get(@"cpz.index")).pointerSectionAsList();
                \\        }}
                \\
                \\        pub fn dataSection(self: @This(), @"cpz.index": usize) ![]const u8 {{
                \\            return (try self.get(@"cpz.index")).dataSectionBytes();
                \\        }}
                \\
            , .{}),
            .any_list => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.ListReader {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getList(null);
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?cpz.ListReader {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getList(null);
                \\        }}
                \\
                \\        pub fn elementSizeAt(self: @This(), @"cpz.index": usize) !cpz.ElementSize {{
                \\            return (try self.get(@"cpz.index")).elementSize();
                \\        }}
                \\
                \\        pub fn structElementSizeAt(self: @This(), @"cpz.index": usize) !cpz.StructSize {{
                \\            return (try self.get(@"cpz.index")).structElementSize();
                \\        }}
                \\
            , .{}),
            else => {},
        },
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    const list_orphan_new = if (isStructListElement(file, scope, child)) |type_name| blk: {
        const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
        defer allocator.free(zig_type);
        break :blk try std.fmt.allocPrint(allocator,
            \\        pub fn newOrphan(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) !@This() {{
            \\            return fromOrphan(try @"cpz.builder".newOrphanStructList(@"cpz.count", {s}.size));
            \\        }}
            \\
            \\        pub fn newOrphanIn(orphanage: cpz.Orphanage, @"cpz.count": usize) !@This() {{
            \\            return fromOrphan(try orphanage.newStructList(@"cpz.count", {s}.size));
            \\        }}
            \\
            \\        pub fn newOrphanCopy(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try @"cpz.builder".newOrphanCopyList(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyCanonical(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try @"cpz.builder".newOrphanCopyListCanonical(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyFromBuilder(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
            \\            return fromOrphan(try @"cpz.builder".newOrphanCopyListFromBuilder(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyCanonicalFromBuilder(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
            \\            return fromOrphan(try @"cpz.builder".newOrphanCopyListCanonicalFromBuilder(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try orphanage.newCopyList(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyCanonicalIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try orphanage.newCopyListCanonical(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyFromBuilderIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
            \\            return fromOrphan(try orphanage.newCopyListFromBuilder(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyCanonicalFromBuilderIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
            \\            return fromOrphan(try orphanage.newCopyListCanonicalFromBuilder(@"cpz.value".list));
            \\        }}
            \\
        , .{ zig_type, zig_type, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name });
    } else try std.fmt.allocPrint(allocator,
        \\        pub fn newOrphan(@"cpz.builder": *cpz.MessageBuilder, @"cpz.count": usize) !@This() {{
        \\            return fromOrphan(try @"cpz.builder".newOrphanList({s}, @"cpz.count"));
        \\        }}
        \\
        \\        pub fn newOrphanIn(orphanage: cpz.Orphanage, @"cpz.count": usize) !@This() {{
        \\            return fromOrphan(try orphanage.newList({s}, @"cpz.count"));
        \\        }}
        \\
        \\        pub fn newOrphanCopy(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try @"cpz.builder".newOrphanCopyList(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyCanonical(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try @"cpz.builder".newOrphanCopyListCanonical(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyFromBuilder(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
        \\            return fromOrphan(try @"cpz.builder".newOrphanCopyListFromBuilder(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyCanonicalFromBuilder(@"cpz.builder": *cpz.MessageBuilder, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
        \\            return fromOrphan(try @"cpz.builder".newOrphanCopyListCanonicalFromBuilder(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try orphanage.newCopyList(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyCanonicalIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try orphanage.newCopyListCanonical(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyFromBuilderIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
        \\            return fromOrphan(try orphanage.newCopyListFromBuilder(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyCanonicalFromBuilderIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_BuilderList) !@This() {{
        \\            return fromOrphan(try orphanage.newCopyListCanonicalFromBuilder(@"cpz.value".list));
        \\        }}
        \\
    , .{ try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name });
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
        \\        pub fn len(self: @This()) !usize {{
        \\            return self.orphan.getListLen({s});
        \\        }}
        \\
        \\        pub fn matchesLen(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesLen({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn isEmpty(self: @This()) bool {{
        \\            return (self.get() catch return false).isEmpty();
        \\        }}
        \\
        \\        pub fn hasIndex(self: @This(), @"cpz.index": usize) bool {{
        \\            return (self.get() catch return false).hasIndex(@"cpz.index");
        \\        }}
        \\
        \\        pub fn firstIndex(self: @This()) !usize {{
        \\            return (try self.get()).firstIndex();
        \\        }}
        \\
        \\        pub fn lastIndex(self: @This()) !usize {{
        \\            return (try self.get()).lastIndex();
        \\        }}
        \\
        \\        pub fn elementSize(self: @This()) !cpz.ElementSize {{
        \\            return self.orphan.getListElementSize({s});
        \\        }}
        \\
        \\        pub fn matchesElementSize(self: @This(), @"cpz.elementSize": cpz.ElementSize) bool {{
        \\            return self.orphan.listMatchesElementSize({s}, @"cpz.elementSize");
        \\        }}
        \\
        \\        pub fn elementBitCount(self: @This()) !usize {{
        \\            return self.orphan.getListElementBitCount({s});
        \\        }}
        \\
        \\        pub fn elementByteCount(self: @This()) !usize {{
        \\            return self.orphan.getListElementByteCount({s});
        \\        }}
        \\
        \\        pub fn elementWordCount(self: @This()) !usize {{
        \\            return self.orphan.getListElementWordCount({s});
        \\        }}
        \\
        \\        pub fn contentBitCount(self: @This()) !usize {{
        \\            return self.orphan.getListContentBitCount({s});
        \\        }}
        \\
        \\        pub fn contentByteCount(self: @This()) !usize {{
        \\            return self.orphan.getListContentByteCount({s});
        \\        }}
        \\
        \\        pub fn contentWordCount(self: @This()) !usize {{
        \\            return self.orphan.getListContentWordCount({s});
        \\        }}
        \\
        \\        pub fn matchesElementBits(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesElementBits({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesElementBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesElementBytes({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesElementWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesElementWords({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentBits(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesContentBits({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesContentWords({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.orphan.listMatchesContentBytes({s}, @"cpz.count");
        \\        }}
        \\
        \\        pub fn structElementSize(self: @This()) !cpz.StructSize {{
        \\            return self.orphan.getListStructElementSize({s});
        \\        }}
        \\
        \\        pub fn structElementDataWordCount(self: @This()) !u16 {{
        \\            return (try self.structElementSize()).dataWordCount();
        \\        }}
        \\
        \\        pub fn structElementPointerCount(self: @This()) !u16 {{
        \\            return (try self.structElementSize()).pointerCount();
        \\        }}
        \\
        \\        pub fn structElementTotalWords(self: @This()) !usize {{
        \\            return (try self.structElementSize()).totalWords();
        \\        }}
        \\
        \\        pub fn structElementDataByteCount(self: @This()) !usize {{
        \\            return (try self.structElementSize()).dataByteCount();
        \\        }}
        \\
        \\        pub fn structElementPointerByteCount(self: @This()) !usize {{
        \\            return (try self.structElementSize()).pointerByteCount();
        \\        }}
        \\
        \\        pub fn structElementTotalByteCount(self: @This()) !usize {{
        \\            return (try self.structElementSize()).totalByteCount();
        \\        }}
        \\
        \\        pub fn matchesStructElementSize(self: @This(), @"cpz.size": cpz.StructSize) bool {{
        \\            return self.orphan.listMatchesStructElementSize({s}, @"cpz.size");
        \\        }}
        \\
        \\        pub fn matchesStructElementDataWords(self: @This(), @"cpz.count": u16) bool {{
        \\            return (self.structElementDataWordCount() catch return false) == @"cpz.count";
        \\        }}
        \\
        \\        pub fn matchesStructElementPointerCount(self: @This(), @"cpz.count": u16) bool {{
        \\            return (self.structElementPointerCount() catch return false) == @"cpz.count";
        \\        }}
        \\
        \\        pub fn matchesStructElementTotalWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return (self.structElementTotalWords() catch return false) == @"cpz.count";
        \\        }}
        \\
        \\        pub fn matchesStructElementDataBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return (self.structElementDataByteCount() catch return false) == @"cpz.count";
        \\        }}
        \\
        \\        pub fn matchesStructElementPointerBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return (self.structElementPointerByteCount() catch return false) == @"cpz.count";
        \\        }}
        \\
        \\        pub fn matchesStructElementTotalBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return (self.structElementTotalByteCount() catch return false) == @"cpz.count";
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
        \\        pub fn validateWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.orphan.validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.orphan.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.orphan.totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn release(self: *@This()) void {{
        \\            self.orphan.release();
        \\        }}
        \\    }};
        \\
    , .{
        owner_name,
        field_name,
        list_orphan_new,
        owner_name,
        field_name,
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        try listElementSizeLiteral(file, scope, child),
        owner_name,
        field_name,
        try listElementSizeLiteral(file, scope, child),
        owner_name,
        field_name,
    });

    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_BuilderList = struct {{
        \\        list: cpz.ListBuilder,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
        \\        pub fn matchesLen(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesLen(@"cpz.count");
        \\        }}
        \\
        \\        pub fn isEmpty(self: @This()) bool {{
        \\            return self.list.isEmpty();
        \\        }}
        \\
        \\        pub fn hasIndex(self: @This(), @"cpz.index": usize) bool {{
        \\            return self.list.hasIndex(@"cpz.index");
        \\        }}
        \\
        \\        pub fn firstIndex(self: @This()) !usize {{
        \\            return self.list.firstIndex();
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
        \\        pub fn validateWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return self.list.validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.list.totalSize();
        \\        }}
        \\
        \\        pub fn totalSizeWithOptions(self: @This(), @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return self.list.totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn elementSize(self: @This()) cpz.ElementSize {{
        \\            return self.list.elementSize();
        \\        }}
        \\
        \\        pub fn matchesElementSize(self: @This(), @"cpz.expected": cpz.ElementSize) bool {{
        \\            return self.list.matchesElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementBitCount(self: @This()) usize {{
        \\            return self.list.elementBitCount();
        \\        }}
        \\
        \\        pub fn elementByteCount(self: @This()) !usize {{
        \\            return self.list.elementByteCount();
        \\        }}
        \\
        \\        pub fn elementWordCount(self: @This()) !usize {{
        \\            return self.list.elementWordCount();
        \\        }}
        \\
        \\        pub fn contentBitCount(self: @This()) !usize {{
        \\            return self.list.contentBitCount();
        \\        }}
        \\
        \\        pub fn contentByteCount(self: @This()) !usize {{
        \\            return self.list.contentByteCount();
        \\        }}
        \\
        \\        pub fn contentWordCount(self: @This()) !usize {{
        \\            return self.list.contentWordCount();
        \\        }}
        \\
        \\        pub fn matchesElementBits(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesElementBits(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesElementBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesElementBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesElementWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesElementWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentBits(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesContentBits(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesContentBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesContentWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesContentWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn structElementSize(self: @This()) cpz.StructSize {{
        \\            return self.list.structElementSize();
        \\        }}
        \\
        \\        pub fn matchesStructElementSize(self: @This(), @"cpz.expected": cpz.StructSize) bool {{
        \\            return self.list.matchesStructElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn structElementDataWordCount(self: @This()) u16 {{
        \\            return self.list.structElementDataWordCount();
        \\        }}
        \\
        \\        pub fn structElementPointerCount(self: @This()) u16 {{
        \\            return self.list.structElementPointerCount();
        \\        }}
        \\
        \\        pub fn structElementTotalWords(self: @This()) usize {{
        \\            return self.list.structElementTotalWords();
        \\        }}
        \\
        \\        pub fn structElementDataByteCount(self: @This()) usize {{
        \\            return self.list.structElementDataByteCount();
        \\        }}
        \\
        \\        pub fn structElementPointerByteCount(self: @This()) usize {{
        \\            return self.list.structElementPointerByteCount();
        \\        }}
        \\
        \\        pub fn structElementTotalByteCount(self: @This()) usize {{
        \\            return self.list.structElementTotalByteCount();
        \\        }}
        \\
        \\        pub fn matchesStructElementDataWords(self: @This(), @"cpz.count": u16) bool {{
        \\            return self.list.matchesStructElementDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementPointerCount(self: @This(), @"cpz.count": u16) bool {{
        \\            return self.list.matchesStructElementPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementTotalWords(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementDataBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementDataBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementPointerBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementPointerBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn matchesStructElementTotalBytes(self: @This(), @"cpz.count": usize) bool {{
        \\            return self.list.matchesStructElementTotalBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn orphanage(self: @This()) cpz.Orphanage {{
        \\            return self.list.orphanage();
        \\        }}
        \\
        \\        pub fn slice(self: @This(), @"cpz.start": usize, @"cpz.count": usize) !{s}_{s}_BuilderList {{
        \\            return .{{ .list = try self.list.slice(@"cpz.start", @"cpz.count") }};
        \\        }}
        \\
        \\        pub fn copyFrom(self: @This(), @"cpz.index": usize, @"cpz.source": {s}_{s}_List, @"cpz.source_index": usize) !void {{
        \\            return self.list.copyElementFrom(@"cpz.index", @"cpz.source".list, @"cpz.source_index");
        \\        }}
        \\
        \\        pub fn copyCanonicalFrom(self: @This(), @"cpz.index": usize, @"cpz.source": {s}_{s}_List, @"cpz.source_index": usize) !void {{
        \\            return self.list.copyElementFromCanonical(@"cpz.index", @"cpz.source".list, @"cpz.source_index");
        \\        }}
        \\
        \\        pub fn copyFromBuilder(self: @This(), @"cpz.index": usize, @"cpz.source": @This(), @"cpz.source_index": usize) !void {{
        \\            return self.list.copyElementFromBuilder(@"cpz.index", @"cpz.source".list, @"cpz.source_index");
        \\        }}
        \\
        \\        pub fn copyCanonicalFromBuilder(self: @This(), @"cpz.index": usize, @"cpz.source": @This(), @"cpz.source_index": usize) !void {{
        \\            return self.list.copyElementFromCanonicalBuilder(@"cpz.index", @"cpz.source".list, @"cpz.source_index");
        \\        }}
        \\
        \\        pub fn copyRangeFrom(self: @This(), @"cpz.index": usize, @"cpz.source": {s}_{s}_List, @"cpz.source_index": usize, @"cpz.count": usize) !void {{
        \\            return self.list.copyElementsFrom(@"cpz.index", @"cpz.source".list, @"cpz.source_index", @"cpz.count");
        \\        }}
        \\
        \\        pub fn copyCanonicalRangeFrom(self: @This(), @"cpz.index": usize, @"cpz.source": {s}_{s}_List, @"cpz.source_index": usize, @"cpz.count": usize) !void {{
        \\            return self.list.copyElementsFromCanonical(@"cpz.index", @"cpz.source".list, @"cpz.source_index", @"cpz.count");
        \\        }}
        \\
        \\        pub fn copyRangeFromBuilder(self: @This(), @"cpz.index": usize, @"cpz.source": @This(), @"cpz.source_index": usize, @"cpz.count": usize) !void {{
        \\            return self.list.copyElementsFromBuilder(@"cpz.index", @"cpz.source".list, @"cpz.source_index", @"cpz.count");
        \\        }}
        \\
        \\        pub fn copyCanonicalRangeFromBuilder(self: @This(), @"cpz.index": usize, @"cpz.source": @This(), @"cpz.source_index": usize, @"cpz.count": usize) !void {{
        \\            return self.list.copyElementsFromCanonicalBuilder(@"cpz.index", @"cpz.source".list, @"cpz.source_index", @"cpz.count");
        \\        }}
        \\
        \\        pub fn clearRange(self: @This(), @"cpz.start": usize, @"cpz.count": usize) !void {{
        \\            return self.list.clearElements(@"cpz.start", @"cpz.count");
        \\        }}
        \\
    , .{ owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name });

    if (isPointerListElement(file, scope, child)) {
        try emitListBuilderPointerElementHelpers(allocator, out);
    }

    switch (resolved_child) {
        .void => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !void {{
            \\            if (@"cpz.index" >= self.list.len()) return error.PointerOutOfBounds;
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: void) !void {{
            \\            _ = new_value;
            \\            if (@"cpz.index" >= self.list.len()) return error.PointerOutOfBounds;
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearElement(@"cpz.index");
            \\        }}
            \\
        , .{}),
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !bool {{
            \\            return self.list.getBool(@"cpz.index");
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: bool) !void {{
            \\            return self.list.setBool(@"cpz.index", new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearElement(@"cpz.index");
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
            \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
            \\        }}
            \\
            \\        pub fn getByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).len;
            \\        }}
            \\
            \\        pub fn matchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.getByteCount(@"cpz.index")) == @"cpz.count";
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).setText(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), new_value: []const u8) !cpz.Orphan {{
            \\            return self.orphanage().newText(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
            \\        }}
            \\
            \\        pub fn getByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).len;
            \\        }}
            \\
            \\        pub fn matchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.getByteCount(@"cpz.index")) == @"cpz.count";
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).setData(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), new_value: []const u8) !cpz.Orphan {{
            \\            return self.orphanage().newData(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
            \\        }}
            \\
        , .{}),
        .any_pointer => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.PointerBuilder {{
            \\            return self.list.getPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn getAsStruct(self: @This(), @"cpz.index": usize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct();
            \\        }}
            \\
            \\        pub fn getAsList(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getList(@"cpz.expected");
            \\        }}
            \\
            \\        pub fn getAsText(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
            \\        }}
            \\
            \\        pub fn getAsTextByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).getTextByteCount();
            \\        }}
            \\
            \\        pub fn getAsTextMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.get(@"cpz.index")).textMatchesBytes(@"cpz.count");
            \\        }}
            \\
            \\        pub fn getAsData(self: @This(), @"cpz.index": usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
            \\        }}
            \\
            \\        pub fn getAsDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.get(@"cpz.index")).getDataByteCount();
            \\        }}
            \\
            \\        pub fn getAsDataMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.get(@"cpz.index")).dataMatchesBytes(@"cpz.count");
            \\        }}
            \\
            \\        pub fn getAsCapability(self: @This(), @"cpz.index": usize) !u32 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn getAsCapabilityFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            \\            return @"cpz.table".getListBuilderElement(self.list, @"cpz.index");
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).copyFrom(new_value);
            \\        }}
            \\
            \\        pub fn initStruct(self: @This(), @"cpz.index": usize, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).initStruct(struct_size);
            \\        }}
            \\
            \\        pub fn initList(self: @This(), @"cpz.index": usize, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).initList(@"cpz.elementSize", @"cpz.count");
            \\        }}
            \\
            \\        pub fn initStructList(self: @This(), @"cpz.index": usize, @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).initStructList(@"cpz.count", struct_size);
            \\        }}
            \\
            \\        pub fn setText(self: @This(), @"cpz.index": usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).setText(new_value);
            \\        }}
            \\
            \\        pub fn setData(self: @This(), @"cpz.index": usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).setData(new_value);
            \\        }}
            \\
            \\        pub fn setCapability(self: @This(), @"cpz.index": usize, new_value: u32) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).setCapability(new_value);
            \\        }}
            \\
            \\        pub fn newStructOrphan(self: @This(), struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStruct(struct_size);
            \\        }}
            \\
            \\        pub fn newListOrphan(self: @This(), @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.Orphan {{
            \\            return self.orphanage().newList(@"cpz.elementSize", @"cpz.count");
            \\        }}
            \\
            \\        pub fn newStructListOrphan(self: @This(), @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStructList(@"cpz.count", struct_size);
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
            \\        pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyPointerCanonical(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan {{
            \\            return self.orphanage().newCopyPointerFromBuilder(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan {{
            \\            return self.orphanage().newCopyPointerCanonicalFromBuilder(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
            \\        }}
            \\
        , .{}),
        .any_struct => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct();
            \\        }}
            \\
            \\        pub fn pointerSection(self: @This(), @"cpz.index": usize) !cpz.ListBuilder {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getStruct()).pointerSectionAsList();
            \\        }}
            \\
            \\        pub fn dataSection(self: @This(), @"cpz.index": usize) ![]u8 {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getStruct()).dataSectionBytes();
            \\        }}
            \\
            \\        pub fn init(self: @This(), @"cpz.index": usize, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).initStruct(struct_size);
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.StructReader) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).copyStructFrom(new_value);
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
            \\        pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.StructReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyStructCanonical(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanFromBuilder(self: @This(), new_value: cpz.StructBuilder) !cpz.Orphan {{
            \\            return self.orphanage().newCopyStructFromBuilder(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.StructBuilder) !cpz.Orphan {{
            \\            return self.orphanage().newCopyStructCanonicalFromBuilder(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
            \\        }}
            \\
        , .{}),
        .any_list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getList(null);
            \\        }}
            \\
            \\        pub fn elementSizeAt(self: @This(), @"cpz.index": usize) !cpz.ElementSize {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getList(null)).elementSize();
            \\        }}
            \\
            \\        pub fn structElementSizeAt(self: @This(), @"cpz.index": usize) !cpz.StructSize {{
            \\            return (try (try self.list.getPointerElement(@"cpz.index")).getList(null)).structElementSize();
            \\        }}
            \\
            \\        pub fn init(self: @This(), @"cpz.index": usize, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).initList(@"cpz.elementSize", @"cpz.count");
            \\        }}
            \\
            \\        pub fn initStructList(self: @This(), @"cpz.index": usize, @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).initStructList(@"cpz.count", struct_size);
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).copyFrom(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.Orphan {{
            \\            return self.orphanage().newList(@"cpz.elementSize", @"cpz.count");
            \\        }}
            \\
            \\        pub fn newStructListOrphan(self: @This(), @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.Orphan {{
            \\            return self.orphanage().newStructList(@"cpz.count", struct_size);
            \\        }}
            \\
            \\        pub fn newCopyOrphan(self: @This(), new_value: cpz.ListReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyList(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.ListReader) !cpz.Orphan {{
            \\            return self.orphanage().newCopyListCanonical(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanFromBuilder(self: @This(), new_value: cpz.ListBuilder) !cpz.Orphan {{
            \\            return self.orphanage().newCopyListFromBuilder(new_value);
            \\        }}
            \\
            \\        pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.ListBuilder) !cpz.Orphan {{
            \\            return self.orphanage().newCopyListCanonicalFromBuilder(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
            \\        }}
            \\
        , .{}),
        .capability => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            \\            return @"cpz.table".getListBuilderElement(self.list, @"cpz.index");
            \\        }}
            \\
            \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: u32) !void {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).setCapability(new_value);
            \\        }}
            \\
            \\        pub fn newOrphan(self: @This(), new_value: u32) !cpz.Orphan {{
            \\            return self.orphanage().newCapability(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
            \\            return self.list.clearPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(@"cpz.index");
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
            \\        }}
            \\
        , .{}),
        .list => |nested_child| {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getList(null);
                \\        }}
                \\
                \\        pub fn init(self: @This(), @"cpz.index": usize, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).initList(@"cpz.elementSize", @"cpz.count");
                \\        }}
                \\
            , .{});
            if (isStructListElement(file, scope, nested_child.*)) |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn initStructList(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !cpz.ListBuilder {{
                    \\            return (try self.list.getPointerElement(@"cpz.index")).initStructList(@"cpz.count", {s}.size);
                    \\        }}
                    \\
                , .{zig_type});
            }
            try appendFmt(allocator, out,
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn setFromBuilder(self: @This(), @"cpz.index": usize, new_value: cpz.PointerBuilder) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn setCanonical(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFromCanonical(new_value);
                \\        }}
                \\
                \\        pub fn setCanonicalFromBuilder(self: @This(), @"cpz.index": usize, new_value: cpz.PointerBuilder) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFromCanonicalBuilder(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphan(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointer(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonical(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphanFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonicalFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
                \\        }}
                \\
            , .{});
        },
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !{s} {{
                \\            return std.enums.fromInt({s}, try self.list.getUInt16(@"cpz.index")) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn getRaw(self: @This(), @"cpz.index": usize) !u16 {{
                \\            return self.list.getUInt16(@"cpz.index");
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: {s}) !void {{
                \\            return self.list.setUInt16(@"cpz.index", @intFromEnum(new_value));
                \\        }}
                \\
                \\        pub fn setRaw(self: @This(), @"cpz.index": usize, new_value: u16) !void {{
                \\            return self.list.setUInt16(@"cpz.index", new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearElement(@"cpz.index");
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        } else if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
                \\            return @"cpz.table".getListBuilderElement(self.list, @"cpz.index");
                \\        }}
                \\
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: u32) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
                \\        }}
                \\
            , .{});
        } else if (!isStructLikeName(file, type_name) or try namedTypeResolvesToGenericParameter(allocator, file, scope, type_name)) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.PointerBuilder {{
                \\            return self.list.getPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn setFromBuilder(self: @This(), @"cpz.index": usize, new_value: cpz.PointerBuilder) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn setCanonical(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFromCanonical(new_value);
                \\        }}
                \\
                \\        pub fn setCanonicalFromBuilder(self: @This(), @"cpz.index": usize, new_value: cpz.PointerBuilder) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFromCanonicalBuilder(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphan(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointer(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonical(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphanFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonicalFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn disown(self: @This(), @"cpz.index": usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), @"cpz.index": usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(@"cpz.index", orphan);
                \\        }}
                \\
            , .{});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !{s}.Builder {{
                \\            return {s}.Builder.fromBuilder(try self.list.getStructElement(@"cpz.index"));
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: {s}) !void {{
                \\            return (try self.list.getStructElement(@"cpz.index")).copyFromReader(new_value.reader);
                \\        }}
                \\
                \\        pub fn setFromBuilder(self: @This(), @"cpz.index": usize, new_value: {s}.Builder) !void {{
                \\            return (try self.list.getStructElement(@"cpz.index")).copyFromBuilder(new_value.builder);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearStructElement(@"cpz.index");
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type, zig_type });
        },
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .text => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?[]const u8 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getText();
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: []const u8) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).setText(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?[]const u8) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}),
            .data => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) ![]const u8 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?[]const u8 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getData();
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: []const u8) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).setData(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?[]const u8) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}),
            .capability => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?u32 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
                \\            return @"cpz.table".getListBuilderElement(self.list, @"cpz.index");
                \\        }}
                \\
                \\        pub fn getOrNullFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
                \\            return @"cpz.table".getListBuilderElementOrNull(self.list, @"cpz.index");
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: u32) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?u32) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}),
            .named => |type_name| if (findInterface(file, type_name) != null) try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !u32 {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?u32 {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn getFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
                \\            return @"cpz.table".getListBuilderElement(self.list, @"cpz.index");
                \\        }}
                \\
                \\        pub fn getOrNullFromTable(self: @This(), @"cpz.index": usize, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
                \\            return @"cpz.table".getListBuilderElementOrNull(self.list, @"cpz.index");
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: u32) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?u32) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}) else if (isStructLikeName(file, type_name)) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn get(self: @This(), @"cpz.index": usize) !{s}.Builder {{
                    \\            return {s}.Builder.fromBuilder(try (try self.list.getPointerElement(@"cpz.index")).getStruct());
                    \\        }}
                    \\
                    \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?{s}.Builder {{
                    \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return {s}.Builder.fromBuilder(try @"cpz.pointer".getStruct());
                    \\        }}
                    \\
                    \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: {s}) !void {{
                    \\            return (try self.list.getPointerElement(@"cpz.index")).copyStructFrom(new_value.reader);
                    \\        }}
                    \\
                    \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?{s}) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                    \\            return self.clear(@"cpz.index");
                    \\        }}
                    \\
                    \\        pub fn setFromBuilder(self: @This(), @"cpz.index": usize, new_value: {s}.Builder) !void {{
                    \\            return (try self.list.getPointerElement(@"cpz.index")).copyStructFromBuilder(new_value.builder);
                    \\        }}
                    \\
                    \\        pub fn setOrNullFromBuilder(self: @This(), @"cpz.index": usize, new_value: ?{s}.Builder) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.setFromBuilder(@"cpz.index", @"cpz.value");
                    \\            return self.clear(@"cpz.index");
                    \\        }}
                    \\
                    \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                    \\            return self.list.clearPointerElement(@"cpz.index");
                    \\        }}
                    \\
                , .{ zig_type, zig_type, zig_type, zig_type, zig_type, zig_type, zig_type, zig_type });
            },
            .any_pointer => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.PointerBuilder {{
                \\            return self.list.getPointerElement(@"cpz.index");
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?cpz.PointerBuilder {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return @"cpz.pointer";
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?cpz.PointerReader) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}),
            .any_struct => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.StructBuilder {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct();
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?cpz.StructBuilder {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getStruct();
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.StructReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyStructFrom(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?cpz.StructReader) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}),
            .any_list => try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), @"cpz.index": usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).getList(null);
                \\        }}
                \\
                \\        pub fn getOrNull(self: @This(), @"cpz.index": usize) !?cpz.ListBuilder {{
                \\            const @"cpz.pointer" = try self.list.getPointerElement(@"cpz.index");
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getList(null);
                \\        }}
                \\
                \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: cpz.ListReader) !void {{
                \\            return (try self.list.getPointerElement(@"cpz.index")).copyListFrom(new_value);
                \\        }}
                \\
                \\        pub fn setOrNull(self: @This(), @"cpz.index": usize, new_value: ?cpz.ListReader) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set(@"cpz.index", @"cpz.value");
                \\            return self.clear(@"cpz.index");
                \\        }}
                \\
                \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
                \\            return self.list.clearPointerElement(@"cpz.index");
                \\        }}
                \\
            , .{}),
            else => {},
        },
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});
}

pub fn emitListSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, scope: ?*const Struct, field_name: []const u8, field: *const Field, index: usize, child: Type) LayoutError!void {
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
        } else if (!isStructLikeName(file, type_name) or try namedTypeResolvesToGenericParameter(allocator, file, scope, type_name)) {
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
        .optional => |optional_child| switch (resolveTypeScoped(file, scope, optional_child.*)) {
            .text => try emitOptionalBlobSliceSetter(allocator, out, field_name, field, index, "setText"),
            .data => try emitOptionalBlobSliceSetter(allocator, out, field_name, field, index, "setData"),
            .any_pointer => try emitOptionalPointerSliceSetter(allocator, out, field_name, field, index),
            .any_struct => try emitOptionalAnyStructSliceSetter(allocator, out, field_name, field, index),
            .any_list => try emitOptionalAnyListSliceSetter(allocator, out, field_name, field, index),
            .capability => try emitOptionalCapabilitySliceSetter(allocator, out, field_name, field, index),
            .named => |type_name| if (findInterface(file, type_name) != null)
                try emitOptionalCapabilitySliceSetter(allocator, out, field_name, field, index)
            else if (isStructLikeName(file, type_name)) {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try emitOptionalStructSliceSetter(allocator, out, field_name, field, index, zig_type);
            },
            else => {},
        },
    }
}

pub fn emitListReaderPointerElementHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
    try appendFmt(allocator, out,
        \\        pub fn elementAsPointer(self: @This(), @"cpz.index": usize) !cpz.PointerReader {{
        \\            return self.list.getPointerElement(@"cpz.index");
        \\        }}
        \\
        \\        pub fn elementIsNull(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isNull();
        \\        }}
        \\
        \\        pub fn elementPointerKind(self: @This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).pointerType();
        \\        }}
        \\
        \\        pub fn elementPointerSegmentId(self: @This(), @"cpz.index": usize) !u32 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).segmentId();
        \\        }}
        \\
        \\        pub fn elementPointerWordIndex(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).pointerWordIndex();
        \\        }}
        \\
        \\        pub fn elementPointerMatchesLocation(self: @This(), @"cpz.index": usize, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\        }}
        \\
        \\        pub fn elementMatchesPointerKind(self: @This(), @"cpz.index": usize, @"cpz.kind": cpz.wire.PointerType) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).matchesPointerType(@"cpz.kind");
        \\        }}
        \\
        \\        pub fn elementPointerIsStruct(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isStructPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsList(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isListPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsFar(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isFarPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsOther(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isOtherPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsCapability(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isCapabilityPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsNear(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isNearPointer();
        \\        }}
        \\
        \\        pub fn elementRawPointer(self: @This(), @"cpz.index": usize) !cpz.Word {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).raw();
        \\        }}
        \\
        \\        pub fn elementDecodedPointer(self: @This(), @"cpz.index": usize) !?cpz.wire.DecodedPointer {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).decode();
        \\        }}
        \\
        \\        pub fn elementMaxCapabilityCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).maxCapabilityCount();
        \\        }}
        \\
        \\        pub fn elementMatchesMaxCapabilityCount(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).matchesMaxCapabilityCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStats(self: @This(), @"cpz.index": usize) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).validate();
        \\        }}
        \\
        \\        pub fn elementStatsWithOptions(self: @This(), @"cpz.index": usize, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn elementTotalSize(self: @This(), @"cpz.index": usize) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).totalSize();
        \\        }}
        \\
        \\        pub fn elementTotalSizeWithOptions(self: @This(), @"cpz.index": usize, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn elementAsStruct(self: @This(), @"cpz.index": usize) !cpz.StructReader {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct(null);
        \\        }}
        \\
        \\        pub fn elementStructSize(self: @This(), @"cpz.index": usize) !cpz.StructSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructSize();
        \\        }}
        \\
        \\        pub fn elementStructDataWordCount(self: @This(), @"cpz.index": usize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructDataWordCount();
        \\        }}
        \\
        \\        pub fn elementStructPointerCount(self: @This(), @"cpz.index": usize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructPointerCount();
        \\        }}
        \\
        \\        pub fn elementStructTotalWords(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructTotalWords();
        \\        }}
        \\
        \\        pub fn elementStructDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructDataByteCount();
        \\        }}
        \\
        \\        pub fn elementStructPointerByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructPointerByteCount();
        \\        }}
        \\
        \\        pub fn elementStructTotalByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructTotalByteCount();
        \\        }}
        \\
        \\        pub fn elementStructMatchesSize(self: @This(), @"cpz.index": usize, @"cpz.expected": cpz.StructSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementStructMatchesDataWords(self: @This(), @"cpz.index": usize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStructMatchesPointerCount(self: @This(), @"cpz.index": usize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStructMatchesTotalWords(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStructMatchesTotalBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesTotalBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsList(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getList(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListLen(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListLen(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesLen(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesLen(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListIsEmpty(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listIsEmpty(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListHasIndex(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, element_index: usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listHasIndex(@"cpz.expected", element_index);
        \\        }}
        \\
        \\        pub fn elementListFirstIndex(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListFirstIndex(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListLastIndex(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListLastIndex(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ElementSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementSize(@"cpz.expected", @"cpz.elementSize");
        \\        }}
        \\
        \\        pub fn elementListElementBitCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementBitCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementBits(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementBits(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListElementByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListElementWordCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListContentBitCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListContentBitCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesContentBits(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesContentBits(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListContentByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListContentByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListContentWordCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListContentWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesContentBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesContentBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesContentWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesContentWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListStructElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.StructSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementDataWordCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementDataWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementPointerCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementPointerCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementTotalWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementTotalWords(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementDataByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementDataByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementPointerByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementPointerByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementTotalByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementTotalByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.size": cpz.StructSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementSize(@"cpz.expected", @"cpz.size");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementDataWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementDataWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementPointerCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementPointerCount(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementTotalWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementTotalWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementDataBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementDataBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementPointerBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementPointerBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementTotalBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementTotalBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsText(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
        \\        }}
        \\
        \\        pub fn elementTextByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getTextByteCount();
        \\        }}
        \\
        \\        pub fn elementTextMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).textMatchesBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsData(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
        \\        }}
        \\
        \\        pub fn elementDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getDataByteCount();
        \\        }}
        \\
        \\        pub fn elementDataMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).dataMatchesBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsCapability(self: @This(), @"cpz.index": usize) !u32 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
        \\        }}
        \\
    , .{});
}

pub fn emitListBuilderPointerElementHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) std.mem.Allocator.Error!void {
    try appendFmt(allocator, out,
        \\        pub fn elementAsPointer(self: @This(), @"cpz.index": usize) !cpz.PointerBuilder {{
        \\            return self.list.getPointerElement(@"cpz.index");
        \\        }}
        \\
        \\        pub fn elementIsNull(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isNull();
        \\        }}
        \\
        \\        pub fn elementAsReader(self: @This(), @"cpz.index": usize, message_reader: *cpz.MessageReader) !cpz.PointerReader {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).asReader(message_reader);
        \\        }}
        \\
        \\        pub fn elementPointerKind(self: @This(), @"cpz.index": usize) !?cpz.wire.PointerType {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).pointerType();
        \\        }}
        \\
        \\        pub fn elementPointerSegmentId(self: @This(), @"cpz.index": usize) !u32 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).segmentId();
        \\        }}
        \\
        \\        pub fn elementPointerWordIndex(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).pointerWordIndex();
        \\        }}
        \\
        \\        pub fn elementPointerMatchesLocation(self: @This(), @"cpz.index": usize, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\        }}
        \\
        \\        pub fn elementMatchesPointerKind(self: @This(), @"cpz.index": usize, @"cpz.kind": cpz.wire.PointerType) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).matchesPointerType(@"cpz.kind");
        \\        }}
        \\
        \\        pub fn elementPointerIsStruct(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isStructPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsList(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isListPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsFar(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isFarPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsOther(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isOtherPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsCapability(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isCapabilityPointer();
        \\        }}
        \\
        \\        pub fn elementPointerIsNear(self: @This(), @"cpz.index": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).isNearPointer();
        \\        }}
        \\
        \\        pub fn elementRawPointer(self: @This(), @"cpz.index": usize) !cpz.Word {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).raw();
        \\        }}
        \\
        \\        pub fn elementDecodedPointer(self: @This(), @"cpz.index": usize) !?cpz.wire.DecodedPointer {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).decode();
        \\        }}
        \\
        \\        pub fn elementMaxCapabilityCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).maxCapabilityCount();
        \\        }}
        \\
        \\        pub fn elementMatchesMaxCapabilityCount(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).matchesMaxCapabilityCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStats(self: @This(), @"cpz.index": usize) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).validate();
        \\        }}
        \\
        \\        pub fn elementStatsWithOptions(self: @This(), @"cpz.index": usize, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn elementTotalSize(self: @This(), @"cpz.index": usize) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).totalSize();
        \\        }}
        \\
        \\        pub fn elementTotalSizeWithOptions(self: @This(), @"cpz.index": usize, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn elementAsStruct(self: @This(), @"cpz.index": usize) !cpz.StructBuilder {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct();
        \\        }}
        \\
        \\        pub fn elementStructSize(self: @This(), @"cpz.index": usize) !cpz.StructSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructSize();
        \\        }}
        \\
        \\        pub fn elementStructDataWordCount(self: @This(), @"cpz.index": usize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructDataWordCount();
        \\        }}
        \\
        \\        pub fn elementStructPointerCount(self: @This(), @"cpz.index": usize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructPointerCount();
        \\        }}
        \\
        \\        pub fn elementStructTotalWords(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructTotalWords();
        \\        }}
        \\
        \\        pub fn elementStructDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructDataByteCount();
        \\        }}
        \\
        \\        pub fn elementStructPointerByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructPointerByteCount();
        \\        }}
        \\
        \\        pub fn elementStructTotalByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStructTotalByteCount();
        \\        }}
        \\
        \\        pub fn elementStructMatchesSize(self: @This(), @"cpz.index": usize, @"cpz.expected": cpz.StructSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementStructMatchesDataWords(self: @This(), @"cpz.index": usize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStructMatchesPointerCount(self: @This(), @"cpz.index": usize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStructMatchesTotalWords(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementStructMatchesTotalBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).structMatchesTotalBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsList(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListBuilder {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getList(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListLen(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListLen(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesLen(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesLen(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListIsEmpty(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listIsEmpty(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListHasIndex(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, element_index: usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listHasIndex(@"cpz.expected", element_index);
        \\        }}
        \\
        \\        pub fn elementListFirstIndex(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListFirstIndex(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListLastIndex(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListLastIndex(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ElementSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementSize(@"cpz.expected", @"cpz.elementSize");
        \\        }}
        \\
        \\        pub fn elementListElementBitCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementBitCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementBits(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementBits(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListElementByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListElementWordCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListElementWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesElementWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesElementWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListContentBitCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListContentBitCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesContentBits(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesContentBits(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListContentByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListContentByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListContentWordCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListContentWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesContentBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesContentBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesContentWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesContentWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListStructElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.StructSize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementDataWordCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementDataWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementPointerCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementPointerCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementTotalWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementTotalWords(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementDataByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementDataByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementPointerByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementPointerByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListStructElementTotalByteCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getListStructElementTotalByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementSize(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.size": cpz.StructSize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementSize(@"cpz.expected", @"cpz.size");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementDataWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementDataWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementPointerCount(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementPointerCount(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementTotalWords(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementTotalWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementDataBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementDataBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementPointerBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementPointerBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementListMatchesStructElementTotalBytes(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).listMatchesStructElementTotalBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsText(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
        \\        }}
        \\
        \\        pub fn elementTextByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getTextByteCount();
        \\        }}
        \\
        \\        pub fn elementTextMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).textMatchesBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsData(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
        \\        }}
        \\
        \\        pub fn elementDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getDataByteCount();
        \\        }}
        \\
        \\        pub fn elementDataMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).dataMatchesBytes(@"cpz.count");
        \\        }}
        \\
        \\        pub fn elementAsCapability(self: @This(), @"cpz.index": usize) !u32 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getCapabilityIndex();
        \\        }}
        \\
    , .{});
}

pub fn emitListPrimitiveSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, zig_type: []const u8, element_size: []const u8, method: []const u8) LayoutError!void {
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

pub fn emitListPointerSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, item_type: []const u8, method: []const u8) LayoutError!void {
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

pub fn emitCapabilitySliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
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

pub fn emitOptionalCapabilitySliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const ?u32) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| {{
        \\                if (@"cpz.item") |@"cpz.value"| {{
        \\                    (try @"cpz.list".getPointerElement(@"cpz.i")).setCapability(@"cpz.value");
        \\                }} else {{
        \\                    try @"cpz.list".clearPointerElement(@"cpz.i");
        \\                }}
        \\            }}
        \\        }}
        \\
    , .{index});
}

pub fn emitOptionalBlobSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const ?[]const u8) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| {{
        \\                if (@"cpz.item") |@"cpz.value"| {{
        \\                    try (try @"cpz.list".getPointerElement(@"cpz.i")).{s}(@"cpz.value");
        \\                }} else {{
        \\                    try @"cpz.list".clearPointerElement(@"cpz.i");
        \\                }}
        \\            }}
        \\        }}
        \\
    , .{ index, method });
}

pub fn emitOptionalPointerSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const ?cpz.PointerReader) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| {{
        \\                if (@"cpz.item") |@"cpz.value"| {{
        \\                    try (try @"cpz.list".getPointerElement(@"cpz.i")).copyFrom(@"cpz.value");
        \\                }} else {{
        \\                    try @"cpz.list".clearPointerElement(@"cpz.i");
        \\                }}
        \\            }}
        \\        }}
        \\
    , .{index});
}

pub fn emitOptionalStructSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, zig_type: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const ?{s}) !void {{
    , .{ field_name, zig_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| {{
        \\                if (@"cpz.item") |@"cpz.value"| {{
        \\                    try (try @"cpz.list".getPointerElement(@"cpz.i")).copyStructFrom(@"cpz.value".reader);
        \\                }} else {{
        \\                    try @"cpz.list".clearPointerElement(@"cpz.i");
        \\                }}
        \\            }}
        \\        }}
        \\
    , .{index});
}

pub fn emitOptionalAnyStructSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const ?cpz.StructReader) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| {{
        \\                if (@"cpz.item") |@"cpz.value"| {{
        \\                    try (try @"cpz.list".getPointerElement(@"cpz.i")).copyStructFrom(@"cpz.value");
        \\                }} else {{
        \\                    try @"cpz.list".clearPointerElement(@"cpz.i");
        \\                }}
        \\            }}
        \\        }}
        \\
    , .{index});
}

pub fn emitOptionalAnyListSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const ?cpz.ListReader) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| {{
        \\                if (@"cpz.item") |@"cpz.value"| {{
        \\                    try (try @"cpz.list".getPointerElement(@"cpz.i")).copyListFrom(@"cpz.value");
        \\                }} else {{
        \\                    try @"cpz.list".clearPointerElement(@"cpz.i");
        \\                }}
        \\            }}
        \\        }}
        \\
    , .{index});
}

pub fn listScalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), zig_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get(self: @This(), @"cpz.index": usize) {s} {{
        \\            return self.list.{s}(@"cpz.index");
        \\        }}
        \\
    , .{ zig_type, method });
}

pub fn listScalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), zig_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get(self: @This(), @"cpz.index": usize) !{s} {{
        \\            return self.list.get{s}(@"cpz.index");
        \\        }}
        \\
        \\        pub fn set(self: @This(), @"cpz.index": usize, new_value: {s}) !void {{
        \\            return self.list.{s}(@"cpz.index", new_value);
        \\        }}
        \\
        \\        pub fn clear(self: @This(), @"cpz.index": usize) !void {{
        \\            return self.list.clearElement(@"cpz.index");
        \\        }}
        \\
    , .{ zig_type, method["set".len..], zig_type, method });
}

pub fn emitFieldBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
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
            , .{ bit, try resolvedFieldDefaultBoolLiteral(file, layout.decl, field), field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setBool({}, new_value, {s});
                \\        }}
                \\
            , .{ bit, try resolvedFieldDefaultBoolLiteral(file, layout.decl, field) });
        },
        .data_byte => |byte| try emitDataBuilderMethod(allocator, out, file, layout, field_name, field, byte),
        .pointer => |index| try emitPointerBuilderMethod(allocator, out, file, layout, owner_name, field_name, field, index),
    }
}

pub fn emitDataBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    const union_layout = unionLayoutForField(layout, field);
    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .int8 => try scalarSetter(allocator, out, field_name, "i8", "getInt8", "setInt8", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .int16 => try scalarSetter(allocator, out, field_name, "i16", "getInt16", "setInt16", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .int32 => try scalarSetter(allocator, out, field_name, "i32", "getInt32", "setInt32", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .int64 => try scalarSetter(allocator, out, field_name, "i64", "getInt64", "setInt64", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .uint8 => try scalarSetter(allocator, out, field_name, "u8", "getUInt8", "setUInt8", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .uint16 => try scalarSetter(allocator, out, field_name, "u16", "getUInt16", "setUInt16", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .uint32 => try scalarSetter(allocator, out, field_name, "u32", "getUInt32", "setUInt32", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .uint64 => try scalarSetter(allocator, out, field_name, "u64", "getUInt64", "setUInt64", byte, resolvedFieldDefaultScalarLiteral(file, layout.decl, field), union_layout, field),
        .float32 => try scalarSetter(allocator, out, field_name, "f32", "getFloat32", "setFloat32", byte, resolvedFieldDefaultFloatLiteral(file, layout.decl, field, "f32"), union_layout, field),
        .float64 => try scalarSetter(allocator, out, field_name, "f64", "getFloat64", "setFloat64", byte, resolvedFieldDefaultFloatLiteral(file, layout.decl, field, "f64"), union_layout, field),
        .named => |type_name| {
            const enum_decl = findEnumRelative(file, layout.decl.name, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, enum_decl.name);
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
            , .{ zig_type, byte, try resolvedFieldDefaultEnumOrdinal(file, layout.decl, enum_decl, field), field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getUInt16({}, {});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: {s}) !void {{
            , .{ byte, try resolvedFieldDefaultEnumOrdinal(file, layout.decl, enum_decl, field), field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setUInt16({}, @intFromEnum(new_value), {});
                \\        }}
                \\
                \\        pub fn set_{s}_raw(self: Builder, new_value: u16) !void {{
            , .{ byte, try resolvedFieldDefaultEnumOrdinal(file, layout.decl, enum_decl, field), field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setUInt16({}, new_value, {});
                \\        }}
                \\
            , .{ byte, try resolvedFieldDefaultEnumOrdinal(file, layout.decl, enum_decl, field) });
        },
        else => return error.UnsupportedType,
    }
}

pub fn scalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, get_method: []const u8, method: []const u8, byte: usize, default: []const u8, union_layout: ?UnionLayout, field: *const Field) LayoutError!void {
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

pub fn emitPointerBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_name: []const u8, raw_field: *const Field, index: usize) LayoutError!void {
    var optional_field_storage: Field = undefined;
    const field_is_optional = raw_field.ty == .optional;
    const field: *const Field = if (field_is_optional) blk: {
        optional_field_storage = raw_field.*;
        optional_field_storage.ty = raw_field.ty.optional.*;
        break :blk &optional_field_storage;
    } else raw_field;
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
        \\        pub fn get_{s}PointerSegmentId(self: Builder) !u32 {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).segmentId();
        \\        }}
        \\
        \\        pub fn get_{s}PointerWordIndex(self: Builder) !usize {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).pointerWordIndex();
        \\        }}
        \\
        \\        pub fn get_{s}PointerMatchesLocation(self: Builder, @"cpz.segmentId": u32, @"cpz.wordIndex": usize) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).matchesLocation(@"cpz.segmentId", @"cpz.wordIndex");
        \\        }}
        \\
        \\        pub fn get_{s}MatchesPointerKind(self: Builder, @"cpz.kind": cpz.wire.PointerType) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).matchesPointerType(@"cpz.kind");
        \\        }}
        \\
        \\        pub fn get_{s}PointerIsStruct(self: Builder) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).isStructPointer();
        \\        }}
        \\
        \\        pub fn get_{s}PointerIsList(self: Builder) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).isListPointer();
        \\        }}
        \\
        \\        pub fn get_{s}PointerIsFar(self: Builder) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).isFarPointer();
        \\        }}
        \\
        \\        pub fn get_{s}PointerIsOther(self: Builder) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).isOtherPointer();
        \\        }}
        \\
        \\        pub fn get_{s}PointerIsCapability(self: Builder) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).isCapabilityPointer();
        \\        }}
        \\
        \\        pub fn get_{s}PointerIsNear(self: Builder) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).isNearPointer();
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
        \\        pub fn get_{s}MaxCapabilityCount(self: Builder) !usize {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).maxCapabilityCount();
        \\        }}
        \\
        \\        pub fn get_{s}MatchesMaxCapabilityCount(self: Builder, @"cpz.count": usize) !bool {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).matchesMaxCapabilityCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}Stats(self: Builder) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).validate();
        \\        }}
        \\
        \\        pub fn get_{s}StatsWithOptions(self: Builder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageStats {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).validateWithOptions(@"cpz.options");
        \\        }}
        \\
        \\        pub fn get_{s}TotalSize(self: Builder) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).totalSize();
        \\        }}
        \\
        \\        pub fn get_{s}TotalSizeWithOptions(self: Builder, @"cpz.options": cpz.ReaderOptions) !cpz.MessageSize {{
    , .{ index, field_name });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).totalSizeWithOptions(@"cpz.options");
        \\        }}
        \\
    , .{index});
    try appendFmt(allocator, out,
        \\        pub fn get_{s}StructSize(self: Builder) !cpz.StructSize {{
        \\            return (try self.get_{s}AsPointer()).getStructSize();
        \\        }}
        \\
        \\        pub fn get_{s}StructDataWordCount(self: Builder) !u16 {{
        \\            return (try self.get_{s}AsPointer()).getStructDataWordCount();
        \\        }}
        \\
        \\        pub fn get_{s}StructPointerCount(self: Builder) !u16 {{
        \\            return (try self.get_{s}AsPointer()).getStructPointerCount();
        \\        }}
        \\
        \\        pub fn get_{s}StructTotalWords(self: Builder) !usize {{
        \\            return (try self.get_{s}AsPointer()).getStructTotalWords();
        \\        }}
        \\
        \\        pub fn get_{s}StructDataByteCount(self: Builder) !usize {{
        \\            return (try self.get_{s}AsPointer()).getStructDataByteCount();
        \\        }}
        \\
        \\        pub fn get_{s}StructPointerByteCount(self: Builder) !usize {{
        \\            return (try self.get_{s}AsPointer()).getStructPointerByteCount();
        \\        }}
        \\
        \\        pub fn get_{s}StructTotalByteCount(self: Builder) !usize {{
        \\            return (try self.get_{s}AsPointer()).getStructTotalByteCount();
        \\        }}
        \\
        \\        pub fn get_{s}StructMatchesSize(self: Builder, @"cpz.expected": cpz.StructSize) !bool {{
        \\            return (try self.get_{s}AsPointer()).structMatchesSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}StructMatchesDataWords(self: Builder, @"cpz.count": u16) !bool {{
        \\            return (try self.get_{s}AsPointer()).structMatchesDataWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}StructMatchesPointerCount(self: Builder, @"cpz.count": u16) !bool {{
        \\            return (try self.get_{s}AsPointer()).structMatchesPointerCount(@"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}StructMatchesTotalWords(self: Builder, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).structMatchesTotalWords(@"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}StructMatchesTotalBytes(self: Builder, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).structMatchesTotalBytes(@"cpz.count");
        \\        }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });
    try appendFmt(allocator, out,
        \\        pub fn get_{s}ListLen(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListLen(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesLen(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesLen(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListElementSize(self: Builder, @"cpz.expected": ?cpz.ElementSize) !cpz.ElementSize {{
        \\            return (try self.get_{s}AsPointer()).getListElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesElementSize(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.elementSize": cpz.ElementSize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesElementSize(@"cpz.expected", @"cpz.elementSize");
        \\        }}
        \\
        \\        pub fn get_{s}ListElementBitCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListElementBitCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListElementByteCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListElementByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListElementWordCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListElementWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListContentBitCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListContentBitCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListContentByteCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListContentByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListContentWordCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListContentWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesContentBytes(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesContentBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListStructElementSize(self: Builder, @"cpz.expected": ?cpz.ElementSize) !cpz.StructSize {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementSize(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementSize(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.size": cpz.StructSize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementSize(@"cpz.expected", @"cpz.size");
        \\        }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    try appendFmt(allocator, out,
        \\        pub fn get_{s}ListIsEmpty(self: Builder, @"cpz.expected": ?cpz.ElementSize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listIsEmpty(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListHasIndex(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.index": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listHasIndex(@"cpz.expected", @"cpz.index");
        \\        }}
        \\
        \\        pub fn get_{s}ListFirstIndex(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListFirstIndex(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListLastIndex(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListLastIndex(@"cpz.expected");
        \\        }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    try appendFmt(allocator, out,
        \\        pub fn get_{s}ListMatchesElementBits(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesElementBits(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesElementBytes(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesElementBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesElementWords(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesElementWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesContentBits(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesContentBits(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesContentWords(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesContentWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    try appendFmt(allocator, out,
        \\        pub fn get_{s}ListStructElementDataWordCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementDataWordCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListStructElementPointerCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !u16 {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementPointerCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListStructElementTotalWords(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementTotalWords(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListStructElementDataByteCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementDataByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListStructElementPointerByteCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementPointerByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListStructElementTotalByteCount(self: Builder, @"cpz.expected": ?cpz.ElementSize) !usize {{
        \\            return (try self.get_{s}AsPointer()).getListStructElementTotalByteCount(@"cpz.expected");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementDataWords(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementDataWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementPointerCount(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": u16) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementPointerCount(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementTotalWords(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementTotalWords(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementDataBytes(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementDataBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementPointerBytes(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementPointerBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
        \\        pub fn get_{s}ListMatchesStructElementTotalBytes(self: Builder, @"cpz.expected": ?cpz.ElementSize, @"cpz.count": usize) !bool {{
        \\            return (try self.get_{s}AsPointer()).listMatchesStructElementTotalBytes(@"cpz.expected", @"cpz.count");
        \\        }}
        \\
    , .{
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
        field_name, field_name,
    });

    switch (resolveTypeScoped(file, layout.decl, field.ty)) {
        .text => {
            const is_null_default = defaultExpressionIsNullPointer(file, layout.decl, field.default_expression);
            const default_literal = if (is_null_default) null else try fieldBlobDefaultLiteralAlloc(allocator, file, layout.decl, field, true);
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
                \\        pub fn get_{s}OrNull(self: Builder) !?[]const u8 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                \\            if (@"cpz.pointer".isNull()) {{
            , .{index});
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\                return {s};
                    \\
                , .{literal});
            } else {
                try out.appendSlice(allocator,
                    \\                return null;
                    \\
                );
            }
            try appendFmt(allocator, out,
                \\            }}
                \\            return try @"cpz.pointer".getText();
                \\        }}
                \\
                \\        pub fn get_{s}ByteCount(self: Builder) !usize {{
                \\            return (try self.get_{s}()).len;
                \\        }}
                \\
                \\        pub fn get_{s}MatchesBytes(self: Builder, @"cpz.count": usize) !bool {{
                \\            return (try self.get_{s}ByteCount()) == @"cpz.count";
                \\        }}
                \\
            , .{ field_name, field_name, field_name, field_name });
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, new_value: []const u8) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setText({}, new_value);
                \\        }}
                \\
                \\        pub fn set_{s}OrNull(self: Builder, new_value: ?[]const u8) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set_{s}(@"cpz.value");
                \\            return self.clear_{s}();
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: []const u8) !cpz.Orphan {{
                \\            return self.orphanage().newText(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name, field_name, field_name });
        },
        .data => {
            const is_null_default = defaultExpressionIsNullPointer(file, layout.decl, field.default_expression);
            const default_literal = if (is_null_default) null else try fieldBlobDefaultLiteralAlloc(allocator, file, layout.decl, field, false);
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
                \\        pub fn get_{s}OrNull(self: Builder) !?[]const u8 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                \\            if (@"cpz.pointer".isNull()) {{
            , .{index});
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\                return {s};
                    \\
                , .{literal});
            } else {
                try out.appendSlice(allocator,
                    \\                return null;
                    \\
                );
            }
            try appendFmt(allocator, out,
                \\            }}
                \\            return try @"cpz.pointer".getData();
                \\        }}
                \\
                \\        pub fn get_{s}ByteCount(self: Builder) !usize {{
                \\            return (try self.get_{s}()).len;
                \\        }}
                \\
                \\        pub fn get_{s}MatchesBytes(self: Builder, @"cpz.count": usize) !bool {{
                \\            return (try self.get_{s}ByteCount()) == @"cpz.count";
                \\        }}
                \\
            , .{ field_name, field_name, field_name, field_name });
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, new_value: []const u8) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setData({}, new_value);
                \\        }}
                \\
                \\        pub fn set_{s}OrNull(self: Builder, new_value: ?[]const u8) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set_{s}(@"cpz.value");
                \\            return self.clear_{s}();
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: []const u8) !cpz.Orphan {{
                \\            return self.orphanage().newData(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name, field_name, field_name });
        },
        .list => |child| {
            const has_default_flat = try listFieldDefaultFlatIsEmitted(allocator, file, layout, field, child.*);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}_{s}_BuilderList {{
            , .{ field_name, owner_name, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (has_default_flat) {
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) {{
                    \\                var @"cpz.defaultReader" = {s}.{s}DefaultFlat.reader(.{{}});
                    \\                const @"cpz.defaultList" = try {s}.{s}DefaultFlat.list(&@"cpz.defaultReader");
                    \\                try @"cpz.pointer".copyListFrom(@"cpz.defaultList");
                    \\            }}
                    \\            return .{{ .list = try @"cpz.pointer".getList({s}) }};
                    \\        }}
                    \\
                , .{ index, owner_name, field_name, owner_name, field_name, try listElementSizeLiteral(file, layout.decl, child.*) });
            } else {
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).getList({s}) }};
                    \\        }}
                    \\
                , .{ index, try listElementSizeLiteral(file, layout.decl, child.*) });
            }
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}OrNull(self: Builder) !?{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return .{{ .list = try @"cpz.pointer".getList({s}) }};
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNull(self: Builder, new_value: ?{s}_{s}_List) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_from(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                , .{ index, try listElementSizeLiteral(file, layout.decl, child.*), field_name, owner_name, field_name, field_name, field_name });
            }

            try appendFmt(allocator, out,
                \\        pub fn set_{s}_from(self: Builder, new_value: {s}_{s}_List) !void {{
            , .{ field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFrom(new_value.list);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFrom(self: Builder, new_value: {s}_{s}_List) !void {{
            , .{ index, field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFromCanonical(new_value.list);
                \\        }}
                \\
                \\        pub fn set_{s}_fromBuilder(self: Builder, new_value: {s}_{s}_BuilderList) !void {{
            , .{ index, field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFromBuilder(new_value.list);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFromBuilder(self: Builder, new_value: {s}_{s}_BuilderList) !void {{
            , .{ index, field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFromCanonicalBuilder(new_value.list);
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
                    \\        pub fn init_{s}(self: Builder, @"cpz.count": usize) !{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionActivation(allocator, out, field);
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).initStructList(@"cpz.count", {s}.size) }};
                    \\        }}
                    \\
                , .{ index, zig_type });
            } else {
                try appendFmt(allocator, out,
                    \\        pub fn init_{s}(self: Builder, @"cpz.count": usize) !{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionActivation(allocator, out, field);
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).initList({s}, @"cpz.count") }};
                    \\        }}
                    \\
                , .{ index, try listElementSizeLiteral(file, layout.decl, child.*) });
            }
        },
        .any_pointer => {
            const has_default_flat = try anyPointerFieldDefaultFlatIsEmitted(allocator, file, layout, field, .any);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.PointerBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (has_default_flat) {
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) {{
                    \\                var @"cpz.defaultReader" = {s}.{s}DefaultFlat.reader(.{{}});
                    \\                const @"cpz.defaultPointer" = try {s}.{s}DefaultFlat.pointer(&@"cpz.defaultReader");
                    \\                try @"cpz.pointer".copyFrom(@"cpz.defaultPointer");
                    \\            }}
                    \\            return @"cpz.pointer";
                    \\        }}
                    \\
                , .{ index, owner_name, field_name, owner_name, field_name });
            } else {
                try appendFmt(allocator, out,
                    \\            return self.builder.getPointerField({});
                    \\        }}
                    \\
                , .{index});
            }
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}OrNull(self: Builder) !?cpz.PointerBuilder {{
                , .{field_name});
                try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return @"cpz.pointer";
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNull(self: Builder, new_value: ?cpz.PointerReader) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNullFromBuilder(self: Builder, new_value: ?cpz.PointerBuilder) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_fromBuilder(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                , .{ index, field_name, field_name, field_name, field_name, field_name, field_name });
            }
            try appendFmt(allocator, out,
                \\        pub fn get_{s}PointerType(self: Builder) !?cpz.wire.PointerType {{
                \\            return (try self.get_{s}()).pointerType();
                \\        }}
                \\
                \\        pub fn get_{s}AsStruct(self: Builder) !cpz.StructBuilder {{
                \\            return (try self.get_{s}()).getStruct();
                \\        }}
                \\
                \\        pub fn get_{s}AsList(self: Builder, @"cpz.expected": ?cpz.ElementSize) !cpz.ListBuilder {{
                \\            return (try self.get_{s}()).getList(@"cpz.expected");
                \\        }}
                \\
                \\        pub fn get_{s}AsText(self: Builder) ![]const u8 {{
                \\            return (try self.get_{s}()).getText();
                \\        }}
                \\
                \\        pub fn get_{s}AsTextByteCount(self: Builder) !usize {{
                \\            return (try self.get_{s}()).getTextByteCount();
                \\        }}
                \\
                \\        pub fn get_{s}AsTextMatchesBytes(self: Builder, @"cpz.count": usize) !bool {{
                \\            return (try self.get_{s}()).textMatchesBytes(@"cpz.count");
                \\        }}
                \\
                \\        pub fn get_{s}AsData(self: Builder) ![]const u8 {{
                \\            return (try self.get_{s}()).getData();
                \\        }}
                \\
                \\        pub fn get_{s}AsDataByteCount(self: Builder) !usize {{
                \\            return (try self.get_{s}()).getDataByteCount();
                \\        }}
                \\
                \\        pub fn get_{s}AsDataMatchesBytes(self: Builder, @"cpz.count": usize) !bool {{
                \\            return (try self.get_{s}()).dataMatchesBytes(@"cpz.count");
                \\        }}
                \\
                \\        pub fn get_{s}AsCapability(self: Builder) !u32 {{
                \\            return (try self.get_{s}()).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
                field_name,
            });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFrom(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFromCanonical(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_fromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFromCanonicalBuilder(new_value);
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
                \\        pub fn init_{s}_list(self: Builder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initList(@"cpz.elementSize", @"cpz.count");
                \\        }}
                \\
                \\        pub fn init_{s}_structList(self: Builder, @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStructList(@"cpz.count", struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_structOrphan(self: Builder, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStruct(struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_listOrphan(self: Builder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.Orphan {{
                \\            return self.orphanage().newList(@"cpz.elementSize", @"cpz.count");
                \\        }}
                \\
                \\        pub fn new_{s}_structListOrphan(self: Builder, @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStructList(@"cpz.count", struct_size);
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
                \\        pub fn new_{s}_copyOrphanCanonical(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonical(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonicalFromBuilder(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name, field_name, field_name, field_name, field_name, field_name, field_name, field_name, field_name });
        },
        .any_struct => {
            const has_default_flat = try anyPointerFieldDefaultFlatIsEmitted(allocator, file, layout, field, .struct_ptr);
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}OrNull(self: Builder) !?cpz.StructBuilder {{
                , .{field_name});
                try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return try @"cpz.pointer".getStruct();
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNullFrom(self: Builder, new_value: ?cpz.StructReader) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_from(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNullFromBuilder(self: Builder, new_value: ?cpz.StructBuilder) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_fromBuilder(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                , .{ index, field_name, field_name, field_name, field_name, field_name, field_name });
            }
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.StructBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (has_default_flat) {
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) {{
                    \\                var @"cpz.defaultReader" = {s}.{s}DefaultFlat.reader(.{{}});
                    \\                const @"cpz.defaultStruct" = try {s}.{s}DefaultFlat.get(&@"cpz.defaultReader");
                    \\                try @"cpz.pointer".copyStructFrom(@"cpz.defaultStruct");
                    \\            }}
                    \\            return @"cpz.pointer".getStruct();
                    \\        }}
                    \\
                    \\        pub fn init_{s}(self: Builder, struct_size: cpz.StructSize) !cpz.StructBuilder {{
                , .{ index, owner_name, field_name, owner_name, field_name, field_name });
            } else {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getStruct();
                    \\        }}
                    \\
                    \\        pub fn init_{s}(self: Builder, struct_size: cpz.StructSize) !cpz.StructBuilder {{
                , .{ index, field_name });
            }
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
                \\        pub fn set_{s}_canonicalFrom(self: Builder, new_value: cpz.StructReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFromCanonical(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_fromBuilder(self: Builder, new_value: cpz.StructBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFromBuilder(self: Builder, new_value: cpz.StructBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFromCanonicalBuilder(new_value);
                \\        }}
                \\
                \\        pub fn get_{s}PointerSection(self: Builder) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.get_{s}()).pointerSectionAsList();
                \\        }}
                \\
                \\        pub fn get_{s}DataSection(self: Builder) ![]u8 {{
            , .{ field_name, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.get_{s}()).dataSectionBytes();
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
                \\        pub fn new_{s}_copyOrphanCanonical(self: Builder, new_value: cpz.StructReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyStructCanonical(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanFromBuilder(self: Builder, new_value: cpz.StructBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyStructFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.StructBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyStructCanonicalFromBuilder(new_value);
                \\        }}
                \\
            , .{
                field_name, field_name,
                field_name, field_name,
                field_name, field_name,
            });
        },
        .any_list => {
            const has_default_flat = try anyPointerFieldDefaultFlatIsEmitted(allocator, file, layout, field, .list);
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}OrNull(self: Builder) !?cpz.ListBuilder {{
                , .{field_name});
                try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return try @"cpz.pointer".getList(null);
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNullFrom(self: Builder, new_value: ?cpz.PointerReader) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_from(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNullFromBuilder(self: Builder, new_value: ?cpz.ListBuilder) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_fromBuilder(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                , .{ index, field_name, field_name, field_name, field_name, field_name, field_name });
            }
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.ListBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (has_default_flat) {
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) {{
                    \\                var @"cpz.defaultReader" = {s}.{s}DefaultFlat.reader(.{{}});
                    \\                const @"cpz.defaultList" = try {s}.{s}DefaultFlat.get(&@"cpz.defaultReader", null);
                    \\                try @"cpz.pointer".copyListFrom(@"cpz.defaultList");
                    \\            }}
                    \\            return @"cpz.pointer".getList(null);
                    \\        }}
                    \\
                    \\        pub fn init_{s}(self: Builder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
                , .{ index, owner_name, field_name, owner_name, field_name, field_name });
            } else {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getList(null);
                    \\        }}
                    \\
                    \\        pub fn init_{s}(self: Builder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.ListBuilder {{
                , .{ index, field_name });
            }
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initList(@"cpz.elementSize", @"cpz.count");
                \\        }}
                \\
                \\        pub fn init_{s}_structList(self: Builder, @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStructList(@"cpz.count", struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_listOrphan(self: Builder, @"cpz.elementSize": cpz.ElementSize, @"cpz.count": usize) !cpz.Orphan {{
                \\            return self.orphanage().newList(@"cpz.elementSize", @"cpz.count");
                \\        }}
                \\
                \\        pub fn new_{s}_structListOrphan(self: Builder, @"cpz.count": usize, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStructList(@"cpz.count", struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: cpz.ListReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyList(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonical(self: Builder, new_value: cpz.ListReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyListCanonical(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanFromBuilder(self: Builder, new_value: cpz.ListBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyListFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.ListBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyListCanonicalFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name, field_name, field_name, field_name, field_name, field_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFrom(self: Builder, new_value: cpz.ListReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFromCanonical(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_fromBuilder(self: Builder, new_value: cpz.ListBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFromBuilder(self: Builder, new_value: cpz.ListBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFromCanonicalBuilder(new_value);
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
                \\        pub fn get_{s}OrNull(self: Builder) !?u32 {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn get_{s}FromTable(self: Builder, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return @"cpz.table".getPointerBuilder(try self.builder.getPointerField({}));
                \\        }}
                \\
                \\        pub fn get_{s}OrNullFromTable(self: Builder, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return @"cpz.table".getPointerBuilderOrNull(try self.builder.getPointerField({}));
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}OrNull(self: Builder, new_value: ?u32) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set_{s}(@"cpz.value");
            , .{ index, field_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.clearPointer({});
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
                \\        pub fn get_{s}OrNull(self: Builder) !?u32 {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                \\            if (@"cpz.pointer".isNull()) return null;
                \\            return try @"cpz.pointer".getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn get_{s}FromTable(self: Builder, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !T {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return @"cpz.table".getPointerBuilder(try self.builder.getPointerField({}));
                \\        }}
                \\
                \\        pub fn get_{s}OrNullFromTable(self: Builder, comptime T: type, @"cpz.table": cpz.CapabilityTable(T)) !?T {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return @"cpz.table".getPointerBuilderOrNull(try self.builder.getPointerField({}));
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}OrNull(self: Builder, new_value: ?u32) !void {{
                \\            if (new_value) |@"cpz.value"| return self.set_{s}(@"cpz.value");
            , .{ index, field_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.clearPointer({});
                \\        }}
                \\
                \\        pub fn new_{s}_orphan(self: Builder, new_value: u32) !cpz.Orphan {{
                \\            return self.orphanage().newCapability(new_value);
                \\        }}
                \\
            , .{ index, field_name });
        } else if (!isStructLikeName(file, type_name) or try namedTypeResolvesToGenericParameter(allocator, file, layout.decl, type_name)) {
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
                \\        pub fn set_{s}_canonicalFrom(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFromCanonical(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_fromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFromCanonicalBuilder(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointer(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonical(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonical(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerFromBuilder(new_value);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointerCanonicalFromBuilder(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name, field_name, field_name });
        } else {
            const effective_type_name = try effectiveNamedTypeNameAlloc(allocator, file, layout.decl, type_name);
            defer allocator.free(effective_type_name);
            const zig_type = try zigTypeRefAlloc(allocator, file, effective_type_name);
            defer allocator.free(zig_type);
            const has_default_flat = try structFieldDefaultFlatIsEmitted(allocator, file, layout, field, type_name);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}.Builder {{
            , .{ field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (has_default_flat) {
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) {{
                    \\                var @"cpz.defaultReader" = {s}.{s}DefaultFlat.reader(.{{}});
                    \\                const @"cpz.defaultValue" = try {s}.{s}DefaultFlat.typedRoot(&@"cpz.defaultReader");
                    \\                try @"cpz.pointer".copyStructFrom(@"cpz.defaultValue".reader);
                    \\            }}
                    \\            return {s}.Builder.fromBuilder(try @"cpz.pointer".getStruct());
                    \\        }}
                    \\
                , .{ index, owner_name, field_name, owner_name, field_name, zig_type });
            } else {
                try appendFmt(allocator, out,
                    \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).getStruct());
                    \\        }}
                    \\
                , .{ zig_type, index });
            }
            if (field_is_optional) {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}OrNull(self: Builder) !?{s}.Builder {{
                , .{ field_name, zig_type });
                try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
                try appendFmt(allocator, out,
                    \\            const @"cpz.pointer" = try self.builder.getPointerField({});
                    \\            if (@"cpz.pointer".isNull()) return null;
                    \\            return {s}.Builder.fromBuilder(try @"cpz.pointer".getStruct());
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNull(self: Builder, new_value: ?{s}) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_from(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                    \\        pub fn set_{s}OrNullFromBuilder(self: Builder, new_value: ?{s}.Builder) !void {{
                    \\            if (new_value) |@"cpz.value"| return self.set_{s}_fromBuilder(@"cpz.value");
                    \\            return self.clear_{s}();
                    \\        }}
                    \\
                , .{ index, zig_type, field_name, zig_type, field_name, field_name, field_name, zig_type, field_name, field_name });
            }
            try appendFmt(allocator, out,
                \\        pub fn init_{s}(self: Builder) !{s}.Builder {{
            , .{ field_name, zig_type });
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
                \\        pub fn set_{s}_canonicalFrom(self: Builder, new_value: {s}) !void {{
            , .{ index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFromCanonical(new_value.reader);
                \\        }}
                \\
                \\        pub fn set_{s}_fromBuilder(self: Builder, new_value: {s}.Builder) !void {{
            , .{ index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFromBuilder(new_value.builder);
                \\        }}
                \\
                \\        pub fn set_{s}_canonicalFromBuilder(self: Builder, new_value: {s}.Builder) !void {{
            , .{ index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFromCanonicalBuilder(new_value.builder);
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
                \\        pub fn new_{s}_copyOrphanCanonical(self: Builder, new_value: {s}) !{s}.Orphan {{
                \\            return {s}.Orphan.fromOrphan(try self.orphanage().newCopyStructCanonical(new_value.reader));
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanFromBuilder(self: Builder, new_value: {s}.Builder) !{s}.Orphan {{
                \\            return {s}.Orphan.fromOrphan(try self.orphanage().newCopyStructFromBuilder(new_value.builder));
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphanCanonicalFromBuilder(self: Builder, new_value: {s}.Builder) !{s}.Orphan {{
                \\            return {s}.Orphan.fromOrphan(try self.orphanage().newCopyStructCanonicalFromBuilder(new_value.builder));
                \\        }}
                \\
                \\        pub fn disown_{s}_typed(self: Builder) !{s}.Orphan {{
            , .{ index, field_name, zig_type, zig_type, zig_type, field_name, zig_type, zig_type, zig_type, field_name, zig_type, zig_type, zig_type, field_name, zig_type, zig_type, zig_type, field_name, zig_type, zig_type, zig_type, field_name, zig_type });
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

pub fn emitBuilderUnionCheck(allocator: std.mem.Allocator, out: *std.ArrayList(u8), union_layout: ?UnionLayout, discriminant: u16) std.mem.Allocator.Error!void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\            if (try self.builder.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\
        , .{ u.discriminant_byte, discriminant });
    }
}

pub fn emitBuilderUnionActivation(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field: *const Field) std.mem.Allocator.Error!void {
    if (field.union_index) |union_index| {
        try appendFmt(allocator, out,
            \\            try self.activateUnion{}({});
            \\
        , .{ union_index, field.union_discriminant });
    }
}

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

pub fn zigIdentAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
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

pub fn zigDataLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8, is_hex: bool) LayoutError![]u8 {
    if (!is_hex) return zigStringLiteralAlloc(allocator, raw);

    const decoded = try hexBytesAlloc(allocator, raw);
    defer allocator.free(decoded);
    return zigRawStringLiteralAlloc(allocator, decoded);
}

pub fn hexValue(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
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

pub fn isZigIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

pub fn isZigIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

pub fn isZigKeyword(name: []const u8) bool {
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
        "u32",       "u64",       "u128",        "reader",         "size",           "new_value",    "orphan",
        "validate",  "totalSize", "Orphan",      "Builder",        "fromReader",     "cpz",          "std",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
    }
    return false;
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
