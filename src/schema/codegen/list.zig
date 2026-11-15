const std = @import("std");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

const state = @import("state.zig");
const mod_pointer = @import("pointer.zig");
const mod_text = @import("text.zig");

const Error = frontend.Error;
const Field = frontend.Field;
const File = frontend.File;
const LayoutError = frontend.LayoutError;
const Struct = frontend.Struct;
const Type = frontend.Type;
const findEnumDirect = frontend.findEnumDirect;
const findInterface = frontend.findInterface;
const isStructLikeName = frontend.isStructLikeName;
const namedTypeResolvesToGenericParameter = frontend.namedTypeResolvesToGenericParameter;
const resolveTypeScoped = frontend.resolveTypeScoped;
const zigIdentAlloc = zig_names.zigIdentAlloc;
const emitBuilderUnionActivation = mod_pointer.emitBuilderUnionActivation;
const appendFmt = mod_text.appendFmt;
const isPointerListElement = mod_text.isPointerListElement;
const isStructListElement = mod_text.isStructListElement;
const listElementSizeLiteral = mod_text.listElementSizeLiteral;
const zigTypeRefAlloc = mod_text.zigTypeRefAlloc;

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
    , .{ owner_name, field_name });
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn slice(self: @This(), @"cpz.start": usize, @"cpz.count": usize) !{s}_{s}_List {{
        \\            return .{{ .list = try self.list.slice(@"cpz.start", @"cpz.count") }};
        \\        }}
        \\
    , .{ owner_name, field_name });

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

    if (state.emit_orphan_helpers_enabled) {
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
        , .{ owner_name, field_name, list_orphan_new, owner_name, field_name, try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child) });
        if (state.emit_introspection_enabled) {
            try appendFmt(allocator, out,
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
            , .{ try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child), try listElementSizeLiteral(file, scope, child) });
        }
        try appendFmt(allocator, out,
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
        , .{ owner_name, field_name, try listElementSizeLiteral(file, scope, child), owner_name, field_name });
    }
    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_BuilderList = struct {{
        \\        list: cpz.ListBuilder,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
    , .{ owner_name, field_name });
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{ owner_name, field_name });
    }
    try appendFmt(allocator, out,
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
    , .{ owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name, owner_name, field_name });

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
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsStruct(self: @This(), @"cpz.index": usize) !cpz.StructReader {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct(null);
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsList(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListReader {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getList(@"cpz.expected");
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsText(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
            \\
            \\        pub fn elementTextByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getTextByteCount();
            \\        }}
            \\
            \\        pub fn elementTextMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).textMatchesBytes(@"cpz.count");
            \\        }}
            \\
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsData(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
            \\
            \\        pub fn elementDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getDataByteCount();
            \\        }}
            \\
            \\        pub fn elementDataMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).dataMatchesBytes(@"cpz.count");
            \\        }}
            \\
        , .{});
    }
    try appendFmt(allocator, out,
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
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsStruct(self: @This(), @"cpz.index": usize) !cpz.StructBuilder {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getStruct();
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsList(self: @This(), @"cpz.index": usize, @"cpz.expected": ?cpz.ElementSize) !cpz.ListBuilder {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getList(@"cpz.expected");
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
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
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsText(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getText();
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
            \\
            \\        pub fn elementTextByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getTextByteCount();
            \\        }}
            \\
            \\        pub fn elementTextMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).textMatchesBytes(@"cpz.count");
            \\        }}
            \\
        , .{});
    }
    try appendFmt(allocator, out,
        \\
        \\        pub fn elementAsData(self: @This(), @"cpz.index": usize) ![]const u8 {{
        \\            return (try self.list.getPointerElement(@"cpz.index")).getData();
        \\        }}
        \\
    , .{});
    if (state.emit_introspection_enabled) {
        try appendFmt(allocator, out,
            \\
            \\        pub fn elementDataByteCount(self: @This(), @"cpz.index": usize) !usize {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).getDataByteCount();
            \\        }}
            \\
            \\        pub fn elementDataMatchesBytes(self: @This(), @"cpz.index": usize, @"cpz.count": usize) !bool {{
            \\            return (try self.list.getPointerElement(@"cpz.index")).dataMatchesBytes(@"cpz.count");
            \\        }}
            \\
        , .{});
    }
    try appendFmt(allocator, out,
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
