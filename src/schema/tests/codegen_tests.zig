const std = @import("std");
const message = @import("../../message.zig");
const serialize = @import("../../serialize.zig");
const frontend = @import("../frontend.zig");
const codegen = @import("../codegen.zig");

const Field = frontend.Field;
const byteListPaddedLen = codegen.byteListPaddedLen;
const constListItemsFromInlineLiteralAlloc = codegen.constListItemsFromInlineLiteralAlloc;
const findFieldLayoutByName = codegen.findFieldLayoutByName;
const flatByteLenForSegmentBytes = codegen.flatByteLenForSegmentBytes;
const flatByteLenForSegmentWords = codegen.flatByteLenForSegmentWords;
const generateZig = codegen.generateZig;
const generateZigWithOptions = codegen.generateZigWithOptions;
const listTextOrDataFieldDefaultFlatBytesAlloc = codegen.listTextOrDataFieldDefaultFlatBytesAlloc;
const listTextOrDataFlatBytesAlloc = codegen.listTextOrDataFlatBytesAlloc;
const listUnsignedFlatBytesAlloc = codegen.listUnsignedFlatBytesAlloc;
const parse = frontend.parse;
const parseSignedLiteral = frontend.parseSignedLiteral;
const planLayouts = frontend.planLayouts;
const pointerListElementWordIndex = codegen.pointerListElementWordIndex;
const resolvedFieldDefaultEnumOrdinal = codegen.resolvedFieldDefaultEnumOrdinal;
const rootListSegmentWords = codegen.rootListSegmentWords;
const rootPointerListElementWordIndex = codegen.rootPointerListElementWordIndex;
const structLiteralFlatBytesAlloc = codegen.structLiteralFlatBytesAlloc;
const structPointerWordIndex = codegen.structPointerWordIndex;
const wordByteLen = codegen.wordByteLen;
const wordByteOffset = codegen.wordByteOffset;
const zigDataLiteralAlloc = codegen.zigDataLiteralAlloc;
const zigRawStringLiteralAlloc = codegen.zigRawStringLiteralAlloc;
const zigSchemaSyntaxLiteralAlloc = codegen.zigSchemaSyntaxLiteralAlloc;
const zigStringLiteralAlloc = codegen.zigStringLiteralAlloc;

test "schema code generator avoids cpz member shadowing" {
    var file = try parse(std.testing.allocator,
        \\struct S {
        \\  const cpz :UInt32 = 1;
        \\  const std :UInt32 = 2;
        \\  using cpzAlias = UInt32;
        \\  using stdAlias = UInt32;
        \\  annotation cpzNote(field) :Text;
        \\  f @0 :UInt32;
        \\}
        \\interface I {
        \\  const cpz :UInt32 = 1;
        \\  const std :UInt32 = 2;
        \\  using cpzAlias = UInt32;
        \\  using stdAlias = UInt32;
        \\  annotation cpzNote(method) :Text;
        \\  m @0 () -> ();
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const cpz_: u32 = 1;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const std_: u32 = 2;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const cpzAlias = u32;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const stdAlias = u32;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const cpzNote = @\"cpz.schema\".S_cpzNote;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const cpzNote = @\"cpz.schema\".I_cpzNote;") != null);
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

test "schema code generator can omit metadata tables" {
    const source =
        \\struct Lean {
        \\  value @0 :UInt32;
        \\  text @1 :Text;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const full = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(full);
    const lean = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{ .emit_metadata = false });
    defer std.testing.allocator.free(lean);

    try std.testing.expect(std.mem.indexOf(u8, full, "cpz.fieldByName") != null);
    try std.testing.expect(std.mem.indexOf(u8, full, "cpz.declarations") != null);
    try std.testing.expect(std.mem.indexOf(u8, lean, "cpz.fieldByName") == null);
    try std.testing.expect(std.mem.indexOf(u8, lean, "cpz.declarations") == null);
    try std.testing.expect(std.mem.indexOf(u8, lean, "pub const Lean") != null);
    try std.testing.expect(std.mem.indexOf(u8, lean, "pub fn get_value") != null);
    try std.testing.expect(lean.len < full.len);
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
        \\  favorite @2 :Color = .Color.green;
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

    try std.testing.expectEqualStrings(".Color.green", file.structs[0].fields[2].default_literal.?);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(@\"cpz.index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_children_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @\"cpz.schema\".Person.fromReader(try self.list.getStructElement(@\"cpz.index\"));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_friend(self: Builder) !@\"cpz.schema\".Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !@\"cpz.schema\".Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@\"cpz.schema\".Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_scores_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(@\"cpz.index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt32(@\"cpz.index\", new_value);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementFrom(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementFromBuilder(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementFromCanonical(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementFromCanonicalBuilder(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementsFrom(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\", @\"cpz.count\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementsFromBuilder(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\", @\"cpz.count\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementsFromCanonical(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\", @\"cpz.count\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.copyElementsFromCanonicalBuilder(@\"cpz.index\", @\"cpz.source\".list, @\"cpz.source_index\", @\"cpz.count\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearElements(@\"cpz.start\", @\"cpz.count\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_scores_fromBuilder(self: Builder, new_value: Person_scores_BuilderList) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyListFromBuilder(new_value.list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_scores_canonicalFrom(self: Builder, new_value: Person_scores_List) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyListFromCanonical(new_value.list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_scores_canonicalFromBuilder(self: Builder, new_value: Person_scores_BuilderList) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyListFromCanonicalBuilder(new_value.list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newOrphanCopyFromBuilder(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.value\": Person_scores_BuilderList) !@This()") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newOrphanCopyListFromBuilder(@\"cpz.value\".list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newOrphanCopyCanonical(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.value\": Person_scores_List) !@This()") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newOrphanCopyListCanonical(@\"cpz.value\".list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newOrphanCopyCanonicalFromBuilder(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.value\": Person_scores_BuilderList) !@This()") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newOrphanCopyListCanonicalFromBuilder(@\"cpz.value\".list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_children_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @\"cpz.schema\".Person.Builder.fromBuilder(try self.list.getStructElement(@\"cpz.index\"));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromReader(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setFromBuilder(self: @This(), @\"cpz.index\": usize, new_value: @\"cpz.schema\".Person.Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromBuilder(new_value.builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getPointerElement(@\"cpz.index\")).getText();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearPointerElement(@\"cpz.index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearStructElement(@\"cpz.index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return std.enums.fromInt(@\"cpz.schema\".Color, self.list.getUInt16(@\"cpz.index\")) orelse error.InvalidEnumValue;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), @\"cpz.index\": usize) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), @\"cpz.index\": usize) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setRaw(self: @This(), @\"cpz.index\": usize, new_value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt16(@\"cpz.index\", @intFromEnum(new_value));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearElement(@\"cpz.index\");") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(@\"cpz.count\", @\"cpz.schema\".Person.size)") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_friend_canonicalFrom(self: Builder, new_value: @\"cpz.schema\".Person) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFromCanonical(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_friend_fromBuilder(self: Builder, new_value: @\"cpz.schema\".Person.Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFromBuilder(new_value.builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_friend_canonicalFromBuilder(self: Builder, new_value: @\"cpz.schema\".Person.Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFromCanonicalBuilder(new_value.builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_friend_copyOrphanCanonical(self: Builder, new_value: @\"cpz.schema\".Person) !@\"cpz.schema\".Person.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructCanonical(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_friend_copyOrphanCanonicalFromBuilder(self: Builder, new_value: @\"cpz.schema\".Person.Builder) !@\"cpz.schema\".Person.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructCanonicalFromBuilder(new_value.builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_friend_copyOrphanFromBuilder(self: Builder, new_value: @\"cpz.schema\".Person.Builder) !@\"cpz.schema\".Person.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructFromBuilder(new_value.builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newOrphanCopyFromBuilder(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.value\": Builder) !Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyFromBuilder\"(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.source\": Builder) !Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyRootFromBuilder(@\"cpz.source\".builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyPointerFromBuilder\"(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.source\": cpz.PointerBuilder) !cpz.PointerBuilder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyRootPointerFromBuilder(@\"cpz.source\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyToBuilder\"(@\"cpz.source\": *cpz.MessageBuilder, @\"cpz.target\": *cpz.MessageBuilder) !cpz.PointerBuilder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyRootToBuilder(@\"cpz.target\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyTypedToBuilder\"(@\"cpz.source\": *cpz.MessageBuilder, @\"cpz.target\": *cpz.MessageBuilder) !Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyCanonicalFromBuilder\"(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.source\": Builder) !Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyRootCanonicalFromBuilder(@\"cpz.source\".builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyPointerCanonicalFromBuilder\"(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.source\": cpz.PointerBuilder) !cpz.PointerBuilder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyRootPointerCanonicalFromBuilder(@\"cpz.source\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyCanonicalToBuilder\"(@\"cpz.source\": *cpz.MessageBuilder, @\"cpz.target\": *cpz.MessageBuilder) !cpz.PointerBuilder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyRootCanonicalToBuilder(@\"cpz.target\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn @\"cpz.root.copyCanonicalTypedToBuilder\"(@\"cpz.source\": *cpz.MessageBuilder, @\"cpz.target\": *cpz.MessageBuilder) !Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn copyFromBuilder(self: Builder, @\"cpz.value\": Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.copyFromBuilder(@\"cpz.value\".builder);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_scores(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "cpz.root.toFlatBytesInto") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "cpz.builderRoot.toFlatBytesInto") != null);
}

test "schema code generator emits builtin any builder copy helpers" {
    const source =
        \\struct DynamicBox {
        \\  any @0 :AnyPointer;
        \\  anyStruct @1 :AnyStruct;
        \\  anyList @2 :AnyList;
        \\  anyItems @3 :List(AnyPointer);
        \\  anyStructItems @4 :List(AnyStruct);
        \\  anyListItems @5 :List(AnyList);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_any_fromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_any_canonicalFrom(self: Builder, new_value: cpz.PointerReader) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_any_canonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromCanonicalBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_any_copyOrphanFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_any_copyOrphanCanonical(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_any_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonicalFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonicalFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_anyStruct_fromBuilder(self: Builder, new_value: cpz.StructBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_anyStruct_canonicalFrom(self: Builder, new_value: cpz.StructReader) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFromCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_anyStruct_canonicalFromBuilder(self: Builder, new_value: cpz.StructBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFromCanonicalBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_anyStruct_copyOrphanFromBuilder(self: Builder, new_value: cpz.StructBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_anyStruct_copyOrphanCanonical(self: Builder, new_value: cpz.StructReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_anyStruct_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.StructBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructCanonicalFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.StructReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.StructBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyStructCanonicalFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_anyList_fromBuilder(self: Builder, new_value: cpz.ListBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyListFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_anyList_canonicalFrom(self: Builder, new_value: cpz.ListReader) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyListFromCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_anyList_canonicalFromBuilder(self: Builder, new_value: cpz.ListBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyListFromCanonicalBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_anyList_copyOrphanFromBuilder(self: Builder, new_value: cpz.ListBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyListFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_anyList_copyOrphanCanonical(self: Builder, new_value: cpz.ListReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyListCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_anyList_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.ListBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyListCanonicalFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.ListReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyListCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.ListBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyListCanonicalFromBuilder(new_value)") != null);
}

test "schema code generator emits generic pointer builder copy helpers" {
    const source =
        \\struct Box(T) {
        \\  value @0 :T;
        \\  items @1 :List(T);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_value_fromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_value_canonicalFrom(self: Builder, new_value: cpz.PointerReader) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_value_canonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromCanonicalBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_value_copyOrphanCanonical(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn new_value_copyOrphanCanonicalFromBuilder(self: Builder, new_value: cpz.PointerBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonicalFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newOrphanCopyCanonical(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.value\": Box_items_List) !@This()") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newOrphanCopyListCanonical(@\"cpz.value\".list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newOrphanCopyCanonicalFromBuilder(@\"cpz.builder\": *cpz.MessageBuilder, @\"cpz.value\": Box_items_BuilderList) !@This()") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newOrphanCopyListCanonicalFromBuilder(@\"cpz.value\".list)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setFromBuilder(self: @This(), @\"cpz.index\": usize, new_value: cpz.PointerBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setCanonical(self: @This(), @\"cpz.index\": usize, new_value: cpz.PointerReader) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setCanonicalFromBuilder(self: @This(), @\"cpz.index\": usize, new_value: cpz.PointerBuilder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromCanonicalBuilder(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonical(self: @This(), new_value: cpz.PointerReader) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonical(new_value)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn newCopyOrphanCanonicalFromBuilder(self: @This(), new_value: cpz.PointerBuilder) !cpz.Orphan") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "newCopyPointerCanonicalFromBuilder(new_value)") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "return @import(\"Other\").External.fromReader(try self.list.getStructElement(@\"cpz.index\"));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(@\"cpz.count\", @import(\"Other\").External.size)") != null);
}

test "schema code generator records inline import type references" {
    const source =
        \\struct Holder {
        \\  external @0 :import "other.capnp".External;
        \\  externalList @1 :List(import "other.capnp".External);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.imports.len);
    try std.testing.expectEqualStrings("External", file.imports[0].name);
    try std.testing.expectEqualStrings("other.capnp", file.imports[0].path);
    try std.testing.expectEqualStrings("External", file.imports[0].member.?);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "@import(\"External\").External.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@import(\"External\").External.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(@\"cpz.count\", @import(\"External\").External.size)") != null);
}

test "schema code generator lowers generic type parameters to pointer accessors" {
    const source =
        \\using T = UInt32;
        \\struct Box(T) {
        \\  using AliasT = T;
        \\  using AliasInner = Inner;
        \\  using AliasInnerText = Inner(Text);
        \\  item @0 :T;
        \\  items @1 :List(T);
        \\  struct Inner(U) {
        \\    value @0 :U;
        \\  }
        \\}
        \\struct Outer {
        \\  using U = UInt32;
        \\  struct Inner(U) {
        \\    item @0 :U;
        \\  }
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get(self: @This(), @\"cpz.index\": usize) !cpz.PointerReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_items(self: Builder, @\"cpz.values\": []const cpz.PointerReader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const AliasT = cpz.PointerReader;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const AliasInnerText = @\"cpz.schema\".Box_Inner;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.field.item.resolvedType\": []const u8 = \"T\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.field.item.resolvedType\": []const u8 = \"U\"") != null);
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

    const escaped = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{
        .runtime_import_name = "my\\runtime\"name",
    });
    defer std.testing.allocator.free(escaped);
    try std.testing.expect(std.mem.indexOf(u8, escaped, "const cpz = @import(\"my\\\\runtime\\\"name\");") != null);
}

test "schema flat containers qualify helper calls to avoid list name ambiguity" {
    const source =
        \\struct Item {
        \\  value @0 :UInt32;
        \\}
        \\const list :List(Item) = [(value = 1)];
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "try @This().list(message_reader)") != null);
}

test "schema signed integer literals accept base prefixes" {
    try std.testing.expectEqual(@as(i8, -128), parseSignedLiteral(i8, "-0x80").?);
    try std.testing.expectEqual(@as(i16, -32768), parseSignedLiteral(i16, "-0x8000").?);
    try std.testing.expectEqual(@as(i32, 0x7fffffff), parseSignedLiteral(i32, "+0x7fffffff").?);
    try std.testing.expectEqual(@as(i64, -0o10), parseSignedLiteral(i64, "-0o10").?);
    try std.testing.expectEqual(@as(?i8, null), parseSignedLiteral(i8, "0x80"));
}

test "schema struct const flat emission supports wider integers and floats" {
    const source =
        \\const raw :Sample = (small = 7, tiny = -8, middle = -1234, ratio = 2.5, word = -99, big = 99, huge = -12.25);
        \\struct Sample {
        \\  small @0 :UInt8 = 1;
        \\  tiny @1 :Int8 = -1;
        \\  middle @2 :Int16 = 5;
        \\  ratio @3 :Float32 = 1.5;
        \\  word @4 :Int64 = -5;
        \\  big @5 :UInt64 = 5;
        \\  huge @6 :Float64 = 4.25;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[0])).?;
    defer std.testing.allocator.free(flat);
    var view_segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&view_segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    try std.testing.expectEqual(@as(u8, 7), root.getUInt8(0, 1));
    try std.testing.expectEqual(@as(i8, -8), root.getInt8(1, -1));
    try std.testing.expectEqual(@as(i16, -1234), root.getInt16(2, 5));
    try std.testing.expectEqual(@as(f32, 2.5), root.getFloat32(4, 1.5));
    try std.testing.expectEqual(@as(i64, -99), root.getInt64(8, -5));
    try std.testing.expectEqual(@as(u64, 99), root.getUInt64(16, 5));
    try std.testing.expectEqual(@as(f64, -12.25), root.getFloat64(24, 4.25));
}

test "schema struct const flats resolve group first-field shorthand" {
    const source =
        \\struct Holder {
        \\  intGroup :group {
        \\    i @0 :UInt32;
        \\    label @1 :Text = "default";
        \\  }
        \\}
        \\const value :Holder = (intGroup = 123);
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[0])).?;
    defer std.testing.allocator.free(flat);
    var segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    const field_layout = findFieldLayoutByName(&layouts.structs[0], "intGroup_i").?;
    try std.testing.expectEqual(@as(u32, 123), root.getUInt32(field_layout.slot.data_byte, 0));
}

test "schema struct const flats bind generic type parameters" {
    const source =
        \\struct Inner(T) {
        \\  item @0 :T;
        \\}
        \\struct Box(T) {
        \\  item @0 :T;
        \\  rev @1 :Box(Text);
        \\  nested @2 :Inner(T /* comment with ), comma , */);
        \\}
        \\struct Payload {
        \\  value @0 :UInt32;
        \\}
        \\const c :Box(Payload) = (item = (value = 7), rev = (item = "hi"), nested = (item = (value = 9)));
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[0])).?;
    defer std.testing.allocator.free(flat);
    var segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    const item = try root.getPointerField(0).getStruct(null);
    try std.testing.expectEqual(@as(u32, 7), item.getUInt32(0, 0));
    const rev = try root.getPointerField(1).getStruct(null);
    try std.testing.expectEqualSlices(u8, "hi", try rev.getPointerField(0).getText());
    const nested = try root.getPointerField(2).getStruct(null);
    const nested_item = try nested.getPointerField(0).getStruct(null);
    try std.testing.expectEqual(@as(u32, 9), nested_item.getUInt32(0, 0));
}

test "schema struct const flats support implied first-field struct literals" {
    const source =
        \\struct Parent {
        \\  struct Child {
        \\    text @0 :Text;
        \\    id @1 :UInt32 = 321;
        \\  }
        \\  child @0 :Child;
        \\  children @1 :List(Child);
        \\}
        \\const value :Parent = (child = "one", children = ["two", (text = "three", id = 3)]);
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[0])).?;
    defer std.testing.allocator.free(flat);
    var segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    const child = try root.getPointerField(0).getStruct(null);
    try std.testing.expectEqualSlices(u8, "one", try child.getPointerField(0).getText());
    const children = try root.getPointerField(1).getList(.composite);
    const first = try children.getStructElement(0);
    try std.testing.expectEqualSlices(u8, "two", try first.getPointerField(0).getText());
    const second = try children.getStructElement(1);
    try std.testing.expectEqualSlices(u8, "three", try second.getPointerField(0).getText());
    try std.testing.expectEqual(@as(u32, 3), second.getUInt32(0, 321));
}

test "schema struct const flats accept void fields" {
    const source =
        \\struct T {
        \\  empty @0 :Void;
        \\  id @1 :UInt32;
        \\}
        \\const one :T = (empty = void, id = 7);
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[0])).?;
    defer std.testing.allocator.free(flat);
    var segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    try std.testing.expectEqual(@as(u32, 7), root.getUInt32(0, 0));
}

test "schema struct const flats resolve any pointer const references" {
    const source =
        \\struct Payload {
        \\  value @0 :UInt32;
        \\}
        \\const payload :Payload = (value = 123);
        \\const values :List(UInt32) = [1, 2];
        \\struct Holder {
        \\  anyStruct @0 :AnyPointer;
        \\  asStruct @1 :AnyStruct;
        \\  anyList @2 :AnyPointer;
        \\  asList @3 :AnyList;
        \\}
        \\const holder :Holder = (anyStruct = payload, asStruct = payload, anyList = values, asList = values);
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[2])).?;
    defer std.testing.allocator.free(flat);
    var segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    try std.testing.expectEqual(@as(u32, 123), (try root.getPointerField(0).getStruct(null)).getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 123), (try root.getPointerField(1).getStruct(null)).getUInt32(0, 0));
    try std.testing.expectEqual(@as(u32, 1), (try root.getPointerField(2).getList(.four_bytes)).getUInt32(0));
    try std.testing.expectEqual(@as(u32, 2), (try root.getPointerField(3).getList(.four_bytes)).getUInt32(1));
}

test "schema struct const flats encode void capability pointers as null" {
    const source =
        \\interface Service {
        \\  call @0 () -> ();
        \\}
        \\struct Holder {
        \\  cap @0 :Capability;
        \\  svc @1 :Service;
        \\}
        \\const holder :Holder = (cap = void, svc = void);
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[0])).?;
    defer std.testing.allocator.free(flat);
    var segments: [1]serialize.ConstSegment = undefined;
    const view = try serialize.readFlatMessageViewInto(&segments, flat);
    var reader = message.MessageReader.init(view.segments, .{});
    const root = try reader.getRoot();
    try std.testing.expect(root.getPointerField(0).isNull());
    try std.testing.expect(root.getPointerField(1).isNull());
}

test "schema text and data list flats resolve const item references" {
    const source =
        \\const hello :Text = "hi";
        \\const blob :Data = 0x"01 02";
        \\const names :List(Text) = [hello, "ok"];
        \\const blobs :List(Data) = [blob, 0x"03"];
        \\struct Box {
        \\  const local :Text = "local";
        \\  names @0 :List(Text) = [Box.local, hello];
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);

    const names_flat = try listTextOrDataFlatBytesAlloc(std.testing.allocator, &file, null, file.consts[2].list_items.?, true);
    defer std.testing.allocator.free(names_flat);
    var names_segments: [1]serialize.ConstSegment = undefined;
    const names_view = try serialize.readFlatMessageViewInto(&names_segments, names_flat);
    var names_reader = message.MessageReader.init(names_view.segments, .{});
    const names = try names_reader.getRootList(.pointer);
    try std.testing.expectEqualSlices(u8, "hi", try (try names.getPointerElement(0)).getText());
    try std.testing.expectEqualSlices(u8, "ok", try (try names.getPointerElement(1)).getText());

    const blobs_flat = try listTextOrDataFlatBytesAlloc(std.testing.allocator, &file, null, file.consts[3].list_items.?, false);
    defer std.testing.allocator.free(blobs_flat);
    var blobs_segments: [1]serialize.ConstSegment = undefined;
    const blobs_view = try serialize.readFlatMessageViewInto(&blobs_segments, blobs_flat);
    var blobs_reader = message.MessageReader.init(blobs_view.segments, .{});
    const blobs = try blobs_reader.getRootList(.pointer);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2 }, try (try blobs.getPointerElement(0)).getData());
    try std.testing.expectEqualSlices(u8, &[_]u8{3}, try (try blobs.getPointerElement(1)).getData());

    const default_flat = try listTextOrDataFieldDefaultFlatBytesAlloc(std.testing.allocator, &file, &file.structs[0], file.structs[0].fields[0].default_expression, true);
    defer std.testing.allocator.free(default_flat);
    var default_segments: [1]serialize.ConstSegment = undefined;
    const default_view = try serialize.readFlatMessageViewInto(&default_segments, default_flat);
    var default_reader = message.MessageReader.init(default_view.segments, .{});
    const defaults = try default_reader.getRootList(.pointer);
    try std.testing.expectEqualSlices(u8, "local", try (try defaults.getPointerElement(0)).getText());
    try std.testing.expectEqualSlices(u8, "hi", try (try defaults.getPointerElement(1)).getText());
}

test "schema code generator rejects cyclic blob const references" {
    var text_file = try parse(std.testing.allocator,
        \\const a :Text = b;
        \\const b :Text = a;
    );
    defer text_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &text_file));

    var data_file = try parse(std.testing.allocator,
        \\const a :Data = b;
        \\const b :Data = a;
    );
    defer data_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &data_file));

    var scalar_file = try parse(std.testing.allocator,
        \\const a :UInt32 = b;
        \\const b :UInt32 = a;
    );
    defer scalar_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &scalar_file));
}

test "schema list flats resolve scalar const item references" {
    try std.testing.expectEqual(@as(usize, 16), try flatByteLenForSegmentWords(1));
    try std.testing.expectEqual(@as(usize, 16), try flatByteLenForSegmentBytes(8));
    try std.testing.expectError(error.SerializedSizeOverflow, flatByteLenForSegmentWords(std.math.maxInt(usize)));
    try std.testing.expectError(error.SerializedSizeOverflow, flatByteLenForSegmentBytes(std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 8), try byteListPaddedLen(1));
    try std.testing.expectError(error.SerializedSizeOverflow, byteListPaddedLen(std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 8), try wordByteLen(1));
    try std.testing.expectError(error.SerializedSizeOverflow, wordByteLen(std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 8), try wordByteOffset(1));
    try std.testing.expectError(error.SerializedSizeOverflow, wordByteOffset(std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 2), try rootListSegmentWords(1));
    try std.testing.expectError(error.SerializedSizeOverflow, rootListSegmentWords(std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 4), try structPointerWordIndex(1, 2, 1));
    try std.testing.expectError(error.SerializedSizeOverflow, structPointerWordIndex(std.math.maxInt(usize), 1, 0));
    try std.testing.expectError(error.SerializedSizeOverflow, structPointerWordIndex(std.math.maxInt(usize) - 1, 1, 1));
    try std.testing.expectEqual(@as(usize, 1), try rootPointerListElementWordIndex(0));
    try std.testing.expectError(error.SerializedSizeOverflow, rootPointerListElementWordIndex(std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 5), try pointerListElementWordIndex(3, 2));
    try std.testing.expectError(error.SerializedSizeOverflow, pointerListElementWordIndex(std.math.maxInt(usize), 1));

    const source =
        \\const one :UInt32 = 1;
        \\const two :UInt32 = 2;
        \\const values :List(UInt32) = [.one, two];
        \\struct Sample {
        \\  const local :UInt16 = 7;
        \\  values @0 :List(UInt16) = [Sample.local, 8];
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const values_flat = try listUnsignedFlatBytesAlloc(u32, std.testing.allocator, &file, null, file.consts[2].list_items.?, .four_bytes);
    defer std.testing.allocator.free(values_flat);
    var values_segments: [1]serialize.ConstSegment = undefined;
    const values_view = try serialize.readFlatMessageViewInto(&values_segments, values_flat);
    var values_reader = message.MessageReader.init(values_view.segments, .{});
    const values_list = try values_reader.getRootList(.four_bytes);
    try std.testing.expectEqual(@as(u32, 1), values_list.getUInt32(0));
    try std.testing.expectEqual(@as(u32, 2), values_list.getUInt32(1));

    const default_items = try constListItemsFromInlineLiteralAlloc(std.testing.allocator, file.structs[0].fields[0].default_expression);
    defer std.testing.allocator.free(default_items);
    const defaults_flat = try listUnsignedFlatBytesAlloc(u16, std.testing.allocator, &file, &file.structs[0], default_items, .two_bytes);
    defer std.testing.allocator.free(defaults_flat);
    var defaults_segments: [1]serialize.ConstSegment = undefined;
    const defaults_view = try serialize.readFlatMessageViewInto(&defaults_segments, defaults_flat);
    var defaults_reader = message.MessageReader.init(defaults_view.segments, .{});
    const defaults_list = try defaults_reader.getRootList(.two_bytes);
    try std.testing.expectEqual(@as(u16, 7), defaults_list.getUInt16(0));
    try std.testing.expectEqual(@as(u16, 8), defaults_list.getUInt16(1));
}

test "schema struct const flats resolve scalar const field references" {
    const source =
        \\const globalId :UInt32 = 12345;
        \\const chosen :Color = blue;
        \\const label :Text = "sample";
        \\const scoreDefaults :List(UInt32) = [.globalId, 2];
        \\enum Color {
        \\  red @0;
        \\  blue @1;
        \\}
        \\struct Sample {
        \\  id @0 :UInt32;
        \\  shade @1 :Color;
        \\  scores @2 :List(UInt32);
        \\  label @3 :Text;
        \\  payload @4 :Data;
        \\  const defaultId :UInt32 = 99;
        \\}
        \\const sample :Sample = (id = .globalId, shade = chosen, scores = scoreDefaults, label = label, payload = "da" "ta");
        \\const nested :Sample = (id = Sample.defaultId, shade = blue, scores = [Sample.defaultId], label = "nest" "ed", payload = 0x"01 02");
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const sample_layout = &layouts.structs[0];
    const scores_pointer = findFieldLayoutByName(sample_layout, "scores").?.slot.pointer;
    const label_pointer = findFieldLayoutByName(sample_layout, "label").?.slot.pointer;
    const payload_pointer = findFieldLayoutByName(sample_layout, "payload").?.slot.pointer;

    const sample_flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[4])).?;
    defer std.testing.allocator.free(sample_flat);
    var sample_segments: [1]serialize.ConstSegment = undefined;
    const sample_view = try serialize.readFlatMessageViewInto(&sample_segments, sample_flat);
    var sample_reader = message.MessageReader.init(sample_view.segments, .{});
    const sample_root = try sample_reader.getRoot();
    try std.testing.expectEqual(@as(u32, 12345), sample_root.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u16, 1), sample_root.getUInt16(4, 0));
    const sample_scores = try sample_root.getPointerField(scores_pointer).getList(.four_bytes);
    try std.testing.expectEqual(@as(u32, 12345), sample_scores.getUInt32(0));
    try std.testing.expectEqual(@as(u32, 2), sample_scores.getUInt32(1));
    try std.testing.expectEqualSlices(u8, "sample", try sample_root.getPointerField(label_pointer).getText());
    try std.testing.expectEqualSlices(u8, "data", try sample_root.getPointerField(payload_pointer).getData());

    const nested_flat = (try structLiteralFlatBytesAlloc(std.testing.allocator, &file, null, &file.consts[5])).?;
    defer std.testing.allocator.free(nested_flat);
    var nested_segments: [1]serialize.ConstSegment = undefined;
    const nested_view = try serialize.readFlatMessageViewInto(&nested_segments, nested_flat);
    var nested_reader = message.MessageReader.init(nested_view.segments, .{});
    const nested_root = try nested_reader.getRoot();
    try std.testing.expectEqual(@as(u32, 99), nested_root.getUInt32(0, 0));
    try std.testing.expectEqual(@as(u16, 1), nested_root.getUInt16(4, 0));
    const nested_scores = try nested_root.getPointerField(scores_pointer).getList(.four_bytes);
    try std.testing.expectEqual(@as(u32, 99), nested_scores.getUInt32(0));
    try std.testing.expectEqualSlices(u8, "nested", try nested_root.getPointerField(label_pointer).getText());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2 }, try nested_root.getPointerField(payload_pointer).getData());
}

test "schema method default flats expose typed enum getters" {
    const source =
        \\enum Color {
        \\  red @0;
        \\  blue @1;
        \\}
        \\interface Service {
        \\  choose @0 (color :Color = blue) -> ();
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.method.choose.params.field.color.defaultFlat\" = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(message_reader: *cpz.MessageReader) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "std.enums.fromInt") != null);
}

test "schema method metadata keeps method generic parameters unresolved" {
    const source =
        \\using T = UInt32;
        \\interface Service {
        \\  call @0 [T] (value :T) -> (result :List(T));
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.method.call.params.field.value.resolvedType\": []const u8 = \"T\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.method.call.results.field.result.resolvedType\": []const u8 = \"List(T)\"") != null);
}

test "schema code generator resolves const reference scalar defaults for flats" {
    const source =
        \\struct Field {
        \\  const noDiscriminant :UInt16 = 0xffff;
        \\  discriminantValue @0 :UInt16 = Field.noDiscriminant;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub const discriminantValueDefaultFlat = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "\\xFF\\xFF\\x00\\x00\\x00\\x00\\x00\\x00") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try @This().root(message_reader)).getUInt16(0, 0);") != null);
}

test "schema code generator prefers enum literals over same-named consts" {
    const source =
        \\enum Color {
        \\  red @0;
        \\  blue @1;
        \\}
        \\const blue :UInt16 = 0;
        \\const chosen :Color = blue;
        \\struct Paint {
        \\  color @0 :Color = blue;
        \\  colors @1 :List(Color) = [blue, chosen];
        \\}
        \\interface Service {
        \\  choose @0 (color :Color = blue) -> ();
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const enum_decl = &file.enums[0];
    try std.testing.expectEqual(@as(u16, 1), try resolvedFieldDefaultEnumOrdinal(&file, &file.structs[0], enum_decl, &file.structs[0].fields[0]));

    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const chosen: @\"cpz.schema\".Color = @enumFromInt(1);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getUInt16(0, 1);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.method.choose.params.field.color.defaultFlat\" = struct") != null);
}

test "schema code generator resolves ancestor const references" {
    const source =
        \\struct Parent {
        \\  const defaultId :UInt32 = 7;
        \\  struct Child {
        \\    const childId :UInt32 = defaultId;
        \\    id @0 :UInt32 = defaultId;
        \\  }
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub const childId: u32 = 7;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getUInt32(0, 7);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.getUInt32(0, 7);") != null);
}

test "schema code generator converts C-style escaped string defaults to Zig literals" {
    const literal = try zigStringLiteralAlloc(std.testing.allocator, "line\\n\\\"tab\\t\\x21\\a\\b\\f\\v\\?\\'\\101");
    defer std.testing.allocator.free(literal);
    try std.testing.expectEqualStrings("\"line\\n\\\"tab\\t!\\x07\\x08\\x0C\\x0B?'A\"", literal);
    const raw_literal = try zigRawStringLiteralAlloc(std.testing.allocator, "line\\nraw\\x21");
    defer std.testing.allocator.free(raw_literal);
    try std.testing.expectEqualStrings("\"line\\\\nraw\\\\x21\"", raw_literal);
    const hex_literal = try zigDataLiteralAlloc(std.testing.allocator, "62 61 72 00 ff", true);
    defer std.testing.allocator.free(hex_literal);
    try std.testing.expectEqualStrings("\"bar\\x00\\xFF\"", hex_literal);
    const hex_backslash_literal = try zigDataLiteralAlloc(std.testing.allocator, "5c 6e 5c 78 32 31", true);
    defer std.testing.allocator.free(hex_backslash_literal);
    try std.testing.expectEqualStrings("\"\\\\n\\\\x21\"", hex_backslash_literal);

    var file = try parse(std.testing.allocator,
        \\annotation note(field) :Text;
        \\struct EscapedAnnotation {
        \\  field @0 :UInt32 $note("\n");
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("$note(\"\\n\")", file.structs[0].fields[0].annotations);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    const raw_annotation_literal = try zigSchemaSyntaxLiteralAlloc(std.testing.allocator, file.structs[0].fields[0].annotations);
    defer std.testing.allocator.free(raw_annotation_literal);
    const decoded_annotation_literal = try zigStringLiteralAlloc(std.testing.allocator, file.structs[0].fields[0].annotations);
    defer std.testing.allocator.free(decoded_annotation_literal);
    try std.testing.expect(!std.mem.eql(u8, raw_annotation_literal, decoded_annotation_literal));
    try std.testing.expect(std.mem.indexOf(u8, code, raw_annotation_literal) != null);
    try std.testing.expect(std.mem.indexOf(u8, code, decoded_annotation_literal) == null);
}

test "schema code generator sanitizes dotted named type references" {
    var file = try parse(std.testing.allocator,
        \\struct Outer {
        \\  struct Inner {
        \\    id @0 :UInt32;
        \\  }
        \\}
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
    {
        var file = try parse(std.testing.allocator,
            \\using import "foo-bar.capnp";
            \\using import "foo_bar.capnp";
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\struct Defaults {
            \\  value @0 :Text = "default";
            \\  valueDefault @1 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\struct Defaults {
            \\  value @0 :Text = "default";
            \\  valueDefaultFlat @1 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct PointerHelpers {
        \\  foo @0 :Text;
        \\  has_foo @1 :Bool;
        \\}
        ,
        \\struct PointerHelpers {
        \\  foo @0 :Text;
        \\  fooAsPointer @1 :Bool;
        \\}
        ,
        \\struct PointerHelpers {
        \\  foo @0 :Text;
        \\  fooPointerKind @1 :Bool;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct getRoot {
        \\  id @0 :UInt32;
        \\}
        ,
        \\struct initRoot {
        \\  id @0 :UInt32;
        \\}
        ,
        \\struct newOrphanCopy {
        \\  id @0 :UInt32;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\const getRoot :UInt32 = 1;
            \\using initRoot = UInt32;
            \\struct SafeRootHelperNames {
            \\  id @0 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        const code = try generateZig(std.testing.allocator, &file, &layouts);
        defer std.testing.allocator.free(code);
        try std.testing.expect(std.mem.indexOf(u8, code, "pub const getRoot: u32 = 1;") != null);
        try std.testing.expect(std.mem.indexOf(u8, code, "pub const initRoot = u32;") != null);
    }
    for ([_][]const u8{
        \\enum RawMode {
        \\  off @0;
        \\  on @1;
        \\}
        \\struct EnumRawHelpers {
        \\  mode @0 :RawMode;
        \\  mode_raw @1 :UInt16;
        \\}
        ,
        \\enum RawMode {
        \\  off @0;
        \\  on @1;
        \\}
        \\struct EnumRawHelpers {
        \\  mode @0 :RawMode;
        \\  const mode_raw :UInt16 = 1;
        \\}
        ,
        \\enum RawMode {
        \\  off @0;
        \\  on @1;
        \\}
        \\struct EnumRawHelpers {
        \\  mode @0 :RawMode;
        \\  using mode_raw = UInt16;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct BuilderTarget {
        \\  id @0 :UInt32;
        \\}
        \\struct BuilderHelpers {
        \\  foo @0 :BuilderTarget;
        \\  foo_from @1 :UInt32;
        \\}
        ,
        \\struct BuilderHelpers {
        \\  foo @0 :Text;
        \\  fooAsReader @1 :UInt32;
        \\}
        ,
        \\struct BuilderHelpers {
        \\  foo @0 :List(UInt16);
        \\  foo_fromBuilder @1 :UInt32;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\const flatName :Text = "x";
        \\struct flatNameFlat {
        \\  id @0 :UInt32;
        \\}
        ,
        \\const flatName :UInt32 = 1;
        \\const flatNameFlat :UInt32 = 2;
        ,
        \\struct ConstFlatHelpers {
        \\  const value :Text = "x";
        \\  valueFlat @0 :UInt32;
        \\}
        ,
        \\struct ConstFlatHelpers {
        \\  const value :UInt32 = 1;
        \\  using valueFlat = UInt16;
        \\}
        ,
        \\interface ConstFlatHelpers {
        \\  const value :Text = "x";
        \\  valueFlat @0 () -> ();
        \\}
        ,
        \\interface ConstFlatHelpers {
        \\  const value :Text = "x";
        \\  using valueFlat = UInt16;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct StructFieldNames {
        \\  fieldCount @0 :UInt32;
        \\}
        \\const structFieldNames :StructFieldNames = (fieldCount = 1);
        ,
        \\struct StructFieldNames {
        \\  flatBytes @0 :UInt32;
        \\}
        \\const structFieldNames :StructFieldNames = (flatBytes = 1);
        ,
        \\struct StructFieldNames {
        \\  error @0 :UInt32;
        \\  error_ @1 :UInt32;
        \\}
        \\const structFieldNames :StructFieldNames = (error = 1, error_ = 2);
        ,
        \\struct ConstStructFieldNames {
        \\  struct Inner {
        \\    fields @0 :Text;
        \\  }
        \\  const value :Inner = (fields = "x");
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct ListWrappers {
        \\  foo @0 :List(UInt16);
        \\  ListWrappers_foo_List @1 :UInt32;
        \\}
        ,
        \\struct ListWrappers {
        \\  foo @0 :List(UInt16);
        \\  ListWrappers_foo_BuilderList @1 :UInt32;
        \\}
        ,
        \\struct ListWrappers {
        \\  foo @0 :List(UInt16);
        \\  ListWrappers_foo_Orphan @1 :UInt32;
        \\}
        ,
        \\struct ListWrappers {
        \\  foo @0 :List(UInt16);
        \\  const ListWrappers_foo_List :UInt32 = 1;
        \\}
        ,
        \\struct ListWrappers {
        \\  foo @0 :List(UInt16);
        \\  using ListWrappers_foo_BuilderList = UInt16;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct FixedHelpers {
        \\  actualSize @0 :UInt32;
        \\}
        ,
        \\struct FixedHelpers {
        \\  dataSection @0 :Text;
        \\}
        ,
        \\struct FixedHelpers {
        \\  const pointerSection :UInt32 = 1;
        \\}
        ,
        \\struct FixedHelpers {
        \\  using actualTotalWords = UInt16;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct UnionHelpers {
        \\  union {
        \\    first @0 :Void;
        \\  }
        \\  union0 @1 :UInt32;
        \\}
        ,
        \\struct UnionHelpers {
        \\  union {
        \\    first @0 :Void;
        \\  }
        \\  Union0 @1 :UInt32;
        \\}
        ,
        \\struct UnionHelpers {
        \\  union {
        \\    first @0 :Void;
        \\  }
        \\  which @1 :UInt32;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\struct GroupHelpers {
        \\  error :group {
        \\    a @0 :UInt32;
        \\  }
        \\  error_ :group {
        \\    b @1 :UInt32;
        \\  }
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    for ([_][]const u8{
        \\interface SuperBase {}
        \\interface SuperHelpers extends (SuperBase) {
        \\  Superclass0 @0 () -> ();
        \\}
        ,
        \\interface SuperBase {}
        \\interface SuperHelpers extends (SuperBase) {
        \\  const Superclass0 :UInt32 = 1;
        \\}
        ,
        \\interface SuperBase {}
        \\interface SuperHelpers extends (SuperBase) {
        \\  using Superclass0 = UInt32;
        \\}
        ,
    }) |source| {
        var file = try parse(std.testing.allocator, source);
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
}
