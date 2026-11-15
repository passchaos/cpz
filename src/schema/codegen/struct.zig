const std = @import("std");
const message = @import("../../message.zig");
const serialize = @import("../../serialize.zig");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const state = @import("state.zig");
const mod_const_emit = @import("const_emit.zig");
const mod_field_defaults = @import("field_defaults.zig");
const mod_interface = @import("interface.zig");
const mod_list = @import("list.zig");
const mod_metadata = @import("metadata.zig");
const mod_pointer = @import("pointer.zig");
const mod_text = @import("text.zig");

const Error = frontend.Error;
const Field = frontend.Field;
const FieldLayout = frontend.FieldLayout;
const FieldMetadata = frontend.FieldMetadata;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const StructLayout = frontend.StructLayout;
const UnionLayout = frontend.UnionLayout;
const findEnumRelative = frontend.findEnumRelative;
const resolveTypeScoped = frontend.resolveTypeScoped;
const schemaTypeNameAlloc = frontend.schemaTypeNameAlloc;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const emitAlias = mod_const_emit.emitAlias;
const emitNestedConst = mod_const_emit.emitNestedConst;
const emitStructFieldDefaultFlats = mod_field_defaults.emitStructFieldDefaultFlats;
const fieldSlotMetadata = mod_field_defaults.fieldSlotMetadata;
const emitDeclarationAnnotations = mod_interface.emitDeclarationAnnotations;
const emitParameterMetadata = mod_interface.emitParameterMetadata;
const emitListWrapper = mod_list.emitListWrapper;
const emitAliasMetadataTable = mod_metadata.emitAliasMetadataTable;
const emitConstMetadataTable = mod_metadata.emitConstMetadataTable;
const emitScopedAnnotationMetadataTable = mod_metadata.emitScopedAnnotationMetadataTable;
const emitStructFieldMetadata = mod_metadata.emitStructFieldMetadata;
const emitStructGroupMetadata = mod_metadata.emitStructGroupMetadata;
const emitStructUnionMetadata = mod_metadata.emitStructUnionMetadata;
const emitFieldBuilderMethod = mod_pointer.emitFieldBuilderMethod;
const emitPointerGetter = mod_pointer.emitPointerGetter;
const appendFmt = mod_text.appendFmt;
const resolvedFieldDefaultBoolLiteral = mod_text.resolvedFieldDefaultBoolLiteral;
const resolvedFieldDefaultEnumOrdinal = mod_text.resolvedFieldDefaultEnumOrdinal;
const resolvedFieldDefaultFloatLiteral = mod_text.resolvedFieldDefaultFloatLiteral;
const resolvedFieldDefaultScalarLiteral = mod_text.resolvedFieldDefaultScalarLiteral;
const schemaResolvedTypeNameAlloc = mod_text.schemaResolvedTypeNameAlloc;
const zigSchemaSyntaxLiteralAlloc = mod_text.zigSchemaSyntaxLiteralAlloc;
const zigStringLiteralAlloc = mod_text.zigStringLiteralAlloc;
const zigTypeRefAlloc = mod_text.zigTypeRefAlloc;

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

    if (state.emit_orphan_helpers_enabled) {
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
        , .{ struct_name, struct_name, struct_name });
    }
    try appendFmt(allocator, out,
        \\
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
    , .{ struct_name, struct_name });

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
    if (state.emit_metadata_enabled) {
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
