const std = @import("std");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const state = @import("state.zig");
const mod_field_defaults = @import("field_defaults.zig");
const mod_flat = @import("flat.zig");
const mod_interface = @import("interface.zig");
const mod_list = @import("list.zig");
const mod_struct = @import("struct.zig");
const mod_text = @import("text.zig");

const Error = frontend.Error;
const Field = frontend.Field;
const FieldLayout = frontend.FieldLayout;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const StructLayout = frontend.StructLayout;
const UnionLayout = frontend.UnionLayout;
const effectiveNamedTypeNameAlloc = frontend.effectiveNamedTypeNameAlloc;
const findEnumRelative = frontend.findEnumRelative;
const findInterface = frontend.findInterface;
const isStructLikeName = frontend.isStructLikeName;
const namedTypeResolvesToGenericParameter = frontend.namedTypeResolvesToGenericParameter;
const resolveTypeScoped = frontend.resolveTypeScoped;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const anyPointerFieldDefaultFlatIsEmitted = mod_field_defaults.anyPointerFieldDefaultFlatIsEmitted;
const listFieldDefaultFlatIsEmitted = mod_field_defaults.listFieldDefaultFlatIsEmitted;
const structFieldDefaultFlatIsEmitted = mod_field_defaults.structFieldDefaultFlatIsEmitted;
const fieldBlobDefaultLiteralAlloc = mod_flat.fieldBlobDefaultLiteralAlloc;
const defaultExpressionIsNullPointer = mod_interface.defaultExpressionIsNullPointer;
const emitListSliceSetter = mod_list.emitListSliceSetter;
const emitReaderUnionCheck = mod_struct.emitReaderUnionCheck;
const unionLayoutForField = mod_struct.unionLayoutForField;
const appendFmt = mod_text.appendFmt;
const isStructListElement = mod_text.isStructListElement;
const listElementSizeLiteral = mod_text.listElementSizeLiteral;
const resolvedFieldDefaultBoolLiteral = mod_text.resolvedFieldDefaultBoolLiteral;
const resolvedFieldDefaultEnumOrdinal = mod_text.resolvedFieldDefaultEnumOrdinal;
const resolvedFieldDefaultFloatLiteral = mod_text.resolvedFieldDefaultFloatLiteral;
const resolvedFieldDefaultScalarLiteral = mod_text.resolvedFieldDefaultScalarLiteral;
const zigTypeRefAlloc = mod_text.zigTypeRefAlloc;

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
    , .{index});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
            \\
            \\    pub fn {s}PointerKind(self: @This()) !?cpz.wire.PointerType {{
        , .{field_name});
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
    }

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
    , .{index});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
            \\
            \\        pub fn get_{s}PointerKind(self: Builder) !?cpz.wire.PointerType {{
        , .{field_name});
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
    }

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
            , .{index});
            if (state.emit_orphan_helpers_enabled) {
                try appendFmt(allocator, out,
                    \\
                    \\        pub fn disown_{s}_typed(self: Builder) !{s}_{s}_Orphan {{
                , .{ field_name, owner_name, field_name });
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
            }

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
