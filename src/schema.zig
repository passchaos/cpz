const std = @import("std");
const message = @import("message.zig");
const serialize = @import("serialize.zig");
const wire = @import("wire.zig");
const frontend = @import("schema/frontend.zig");
const codegen = @import("schema/codegen.zig");

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
const countUnions = frontend.countUnions;
const dataRangeEnd = frontend.dataRangeEnd;
const checkedUnionIndex = frontend.checkedUnionIndex;
const hashMapCapacityCount = frontend.hashMapCapacityCount;
const BitRange = frontend.BitRange;
const allocateDataBits = frontend.allocateDataBits;
const nextOrdinalFieldIndexChecked = frontend.nextOrdinalFieldIndexChecked;
const resolveTypeScoped = frontend.resolveTypeScoped;
const alignForwardChecked = frontend.alignForwardChecked;

pub const CodegenOptions = codegen.CodegenOptions;
pub const generateZig = codegen.generateZig;
pub const generateZigWithOptions = codegen.generateZigWithOptions;
pub const zigNamesEqual = codegen.zigNamesEqual;
pub const resolveConstDeclType = codegen.resolveConstDeclType;
pub const typeAcceptsNullPointerDefault = codegen.typeAcceptsNullPointerDefault;
pub const typeAcceptsVoidPointerDefault = codegen.typeAcceptsVoidPointerDefault;
pub const annotationOwnerName = codegen.annotationOwnerName;
pub const resolveTypeInOwnerScope = codegen.resolveTypeInOwnerScope;
pub const resolveNamedAliasInOwnerScope = codegen.resolveNamedAliasInOwnerScope;
pub const declHasParameter = codegen.declHasParameter;
pub const annotationTargetCount = codegen.annotationTargetCount;
pub const parseTypeArgAlloc = codegen.parseTypeArgAlloc;
pub const splitTypeApplicationArgsAlloc = codegen.splitTypeApplicationArgsAlloc;
pub const matchingParen = codegen.matchingParen;
pub const substituteGenericTypeAlloc = codegen.substituteGenericTypeAlloc;
const structLiteralFlatBytesAlloc = codegen.structLiteralFlatBytesAlloc;
pub const parseInlineConstListElementsAlloc = codegen.parseInlineConstListElementsAlloc;
const findFieldLayoutByName = codegen.findFieldLayoutByName;
pub const parseSignedLiteral = codegen.parseSignedLiteral;
pub const parseUnsignedLiteral = codegen.parseUnsignedLiteral;
pub const parseFloatLiteral = codegen.parseFloatLiteral;
pub const enumLiteralOrdinal = codegen.enumLiteralOrdinal;
pub const parseBoolLiteral = codegen.parseBoolLiteral;
const flatByteLenForSegmentWords = codegen.flatByteLenForSegmentWords;
const rootListSegmentWords = codegen.rootListSegmentWords;
const flatByteLenForSegmentBytes = codegen.flatByteLenForSegmentBytes;
const wordByteLen = codegen.wordByteLen;
const wordByteOffset = codegen.wordByteOffset;
const structPointerWordIndex = codegen.structPointerWordIndex;
const rootPointerListElementWordIndex = codegen.rootPointerListElementWordIndex;
const pointerListElementWordIndex = codegen.pointerListElementWordIndex;
const byteListPaddedLen = codegen.byteListPaddedLen;
pub const hexBytesAlloc = codegen.hexBytesAlloc;
const listUnsignedFlatBytesAlloc = codegen.listUnsignedFlatBytesAlloc;
const listTextOrDataFlatBytesAlloc = codegen.listTextOrDataFlatBytesAlloc;
pub const findConstReference = codegen.findConstReference;
pub const resolveConstReferenceLiteral = codegen.resolveConstReferenceLiteral;
pub const constDeclOwnerName = codegen.constDeclOwnerName;
const constListItemsFromInlineLiteralAlloc = codegen.constListItemsFromInlineLiteralAlloc;
const listTextOrDataFieldDefaultFlatBytesAlloc = codegen.listTextOrDataFieldDefaultFlatBytesAlloc;
const fieldIndex = codegen.fieldIndex;
const zigDataLiteralAlloc = codegen.zigDataLiteralAlloc;
const zigStringLiteralAlloc = codegen.zigStringLiteralAlloc;
const zigSchemaSyntaxLiteralAlloc = codegen.zigSchemaSyntaxLiteralAlloc;
const zigRawStringLiteralAlloc = codegen.zigRawStringLiteralAlloc;
pub const schemaTypeNameAlloc = codegen.schemaTypeNameAlloc;
const resolvedFieldDefaultEnumOrdinal = codegen.resolvedFieldDefaultEnumOrdinal;

test "schema parser handles structs, file ids, lists, comments" {
    const source =
        \\/* leading block comment */
        \\@0xabcdef;
        \\# a comment
        \\/* declaration block comment */
        \\struct Person {
        \\  id @0 :UInt32 = 123;
        \\  /* field block comment with ; braces {} and brackets [] */
        \\  name @1 :Text;
        \\  scores @2 :List(Int32);
        \\  /* trailing block comment before a field */
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

test "schema parser concatenates adjacent string literals" {
    var file = try parse(std.testing.allocator,
        \\const greeting :Text = "hello, " "world";
        \\const names :List(Text) = ["Al" "ice", "Bob"];
        \\struct Defaults {
        \\  text @0 :Text = "ab" "cd";
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("hello, world", file.consts[0].literal);
    try std.testing.expectEqualStrings("Alice", file.consts[1].list_items.?[0].literal);
    try std.testing.expectEqualStrings("abcd", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("\"ab\" \"cd\"", file.structs[0].fields[0].default_expression);
}

test "schema parser accepts binary and octal integer literals" {
    var file = try parse(std.testing.allocator,
        \\@0b10_1010;
        \\struct Bits @0o7_7 {
        \\  field @1_0 :UInt32;
        \\}
        \\enum Mode {
        \\  active @0O1_0;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 42), file.id);
    try std.testing.expectEqual(@as(?u64, 63), file.structs[0].id);
    try std.testing.expectEqual(@as(u32, 10), file.structs[0].fields[0].ordinal);
    try std.testing.expectEqual(@as(u16, 8), file.enums[0].values[0].ordinal);
}

test "schema parser rejects duplicate file ids" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\@0xaaaa;
        \\@0xbbbb;
        \\struct Thing {
        \\  field @0 :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Thing {
        \\  field @0 :UInt32;
        \\}
        \\@0xaaaa;
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\$unknown("file-annotation");
        \\@0xaaaa;
    ));
}

test "schema parser accepts file id after top-level using" {
    var file = try parse(std.testing.allocator,
        \\using Cxx = import "/capnp/c++.capnp";
        \\@0xff75ddc6a36723c9;
        \\$Cxx.namespace("example");
        \\
        \\struct ParkingLot {
        \\  cars @0 :List(Car);
        \\}
        \\
        \\struct Car {
        \\  make @0 :Text;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 0xff75ddc6a36723c9), file.id);
    try std.testing.expectEqual(@as(usize, 1), file.imports.len);
    try std.testing.expectEqualStrings("Cxx", file.imports[0].name);
    try std.testing.expectEqual(@as(usize, 1), file.annotations_raw.len);
    try std.testing.expectEqualStrings("$Cxx.namespace(\"example\")", file.annotations_raw[0]);
    try std.testing.expectEqual(@as(usize, 2), file.structs.len);
}

test "schema parser accepts inline import annotation designators" {
    var file = try parse(std.testing.allocator,
        \\@0xb8630836983feed7;
        \\$import "/capnp/c++.capnp".namespace("capnp");
        \\
        \\struct Example $import "/capnp/c++.capnp".name("Example") {
        \\  value @0 :UInt32 $import "/capnp/c++.capnp".name("value");
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 0xb8630836983feed7), file.id);
    try std.testing.expectEqual(@as(usize, 0), file.imports.len);
    try std.testing.expectEqual(@as(usize, 1), file.annotations_raw.len);
    try std.testing.expectEqualStrings("$import \"/capnp/c++.capnp\".namespace(\"capnp\")", file.annotations_raw[0]);
    try std.testing.expectEqualStrings("$import \"/capnp/c++.capnp\".name(\"Example\")", file.structs[0].annotations);
    try std.testing.expectEqualStrings("$import \"/capnp/c++.capnp\".name(\"value\")", file.structs[0].fields[0].annotations);
}

test "schema parser accepts type-applied annotation designators" {
    var file = try parse(std.testing.allocator,
        \\struct Generic(T, U) {
        \\  annotation ann(struct) :Text;
        \\}
        \\
        \\struct Use $Generic(Text, Data).ann("used") {
        \\  value @0 :Text;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), file.structs.len);
    try std.testing.expectEqualStrings("$Generic(Text, Data).ann(\"used\")", file.structs[1].annotations);
}

test "schema parser rejects duplicate declaration ids" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\@0xaaaa;
        \\struct Thing @0xaaaa {
        \\  field @0 :UInt32;
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct First @0xaaaa {
        \\}
        \\enum Second @0xaaaa {
        \\  value @0;
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\const first @0xaaaa :UInt32 = 1;
        \\const second @0xaaaa :UInt32 = 2;
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Outer @0xaaaa {
        \\  struct Inner @0xbbbb {
        \\  }
        \\  const value @0xbbbb :UInt32 = 1;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Thing @0xaaaa @0xbbbb {
        \\  field @0 :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\annotation bad @0xaaaa @0xbbbb (field) :Text;
    ));
}

test "schema parser rejects invalid syntax" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct Bad { field @0 UInt32; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "@!;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct Bad trailing { field @0 :UInt32; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "enum Bad { a @0 trailing; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct Bad { field @0 :UInt32 trailing; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const bad :UInt32 = 1 trailing;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "interface Bad { call @0 () -> () trailing; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "@+1;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct Bad { field @+1 :UInt32; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "enum Bad { value @+1; }"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "interface Bad { call @+1 () -> (); }"));
}

test "schema parser rejects signed identifiers" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct +Bad {}"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct -Bad {}"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using +Alias = UInt32;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  +field @0 :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\enum Bad {
        \\  -value @0;
        \\}
    ));
}

test "schema parser rejects malformed struct field defaults" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  item @0 :Item = (id = );
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  item @0 :Item = (id = 1, id = 2);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :UInt32 = 123abc;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  payload @0 :Data = 0x"0";
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  values @0 :List(UInt32) = [1,, 2];
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  values @0 :List(UInt32) = [1, 2;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  items @0 :List(Item) = [(id = 1), (id = )];
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  item @0 :Item = (id = 1 trailing);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  items @0 :List(Item) = [(id = 1 trailing)];
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  item @0 :Item = (id = 1, = 2);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  values @0 :List(UInt32) = [1,];
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const bad :Item = (id = 1 trailing);
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const bad :List(Item) = [(id = 1 trailing)];
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const bad :Item = (id = 1, = 2);
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\const bad :List(UInt32) = [1,];
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\const bad :UInt32 = 123abc;
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\const bad :Data = 0x"0";
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\const bad :List(UInt32) = [1, 123abc];
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\const bad :List(Data) = [0x"0"];
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const bad :Item = (missing = 1);
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  item @0 :Item = (missing = 1);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const bad :List(Item) = [(missing = 1)];
    ));
}

test "schema parser rejects malformed type application arguments" {
    var commented_file = try parse(std.testing.allocator,
        \\struct Box(T, U) {
        \\  first @0 :T;
        \\  second @1 :U;
        \\}
        \\struct UsesCommentedArgs {
        \\  value @0 :Box(Text /* comment with ), comma , */, UInt32);
        \\  delayed @1 :Box /* comment with ( ) */ (Text, UInt32);
        \\}
    );
    defer commented_file.deinit(std.testing.allocator);
    var commented_layouts = try planLayouts(std.testing.allocator, &commented_file);
    commented_layouts.deinit(std.testing.allocator);

    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :GenericBox();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :GenericBox(, Text);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :GenericBox(Text,);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :GenericBox(Text,, Data);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :List(Text, Data);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :List(List(Text), Data);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :GenericBox(Text Data);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :GenericBox(List(Text) Data);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (field :GenericBox(Text Data)) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (field :List(Text, Data)) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (field :List(List(Text), Data)) -> ();
        \\}
    ));
}

test "schema parser rejects malformed using alias targets" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\using ;
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\using Bad = GenericBox();
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\using Bad = GenericBox(Text Data);
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\using GenericBox(Text Data);
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Owner {
        \\  using Bad = GenericBox(Text Data);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Service {
        \\  using Bad = GenericBox(Text Data);
        \\  call @0 () -> ();
        \\}
    ));
}

test "schema layout planner rejects generic arity mismatches" {
    var field_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\struct Bad {
        \\  field @0 :Box(Text, Data);
        \\}
    );
    defer field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &field_file));

    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\struct Bad {
        \\  field @0 :Box(Text)(UInt32);
        \\}
    ));

    var commented_field_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\struct Bad {
        \\  field @0 :Box /* comment before args */ (Text, Data);
        \\}
    );
    defer commented_field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &commented_field_file));

    var nested_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\struct Bad {
        \\  field @0 :List(Box(Text, Data));
        \\}
    );
    defer nested_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &nested_file));

    var method_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\interface Bad {
        \\  call @0 Box(Text, Data) -> ();
        \\}
    );
    defer method_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &method_file));

    var dotted_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  struct Box(T) {
        \\    value @0 :T;
        \\  }
        \\}
        \\struct Bad {
        \\  field @0 :Parent.Box(Text, Data);
        \\}
    );
    defer dotted_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &dotted_file));

    var local_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  struct Box(T) {
        \\    value @0 :T;
        \\  }
        \\  field @0 :Box(Text, Data);
        \\}
    );
    defer local_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &local_file));

    var alias_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\struct Bad {
        \\  using LocalBox = Box;
        \\  field @0 :LocalBox(Text, Data);
        \\}
    );
    defer alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &alias_file));

    var bound_alias_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T;
        \\}
        \\using BoundBox = Box(Text);
        \\struct Bad {
        \\  field @0 :BoundBox(UInt32);
        \\}
    );
    defer bound_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &bound_alias_file));

    var nested_box_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  struct Box(T) {
        \\    value @0 :T;
        \\  }
        \\  struct Bad {
        \\    field @0 :Box(Text, Data);
        \\  }
        \\}
    );
    defer nested_box_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &nested_box_file));

    var nested_box_alias_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  struct Box(T) {
        \\    value @0 :T;
        \\  }
        \\  using Alias = Box;
        \\  struct Bad {
        \\    field @0 :Alias(Text, Data);
        \\  }
        \\}
    );
    defer nested_box_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &nested_box_alias_file));

    var builtin_alias_file = try parse(std.testing.allocator,
        \\using Alias = Text;
        \\struct Bad {
        \\  field @0 :Alias(UInt32);
        \\}
    );
    defer builtin_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &builtin_alias_file));

    var nested_builtin_alias_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  using Alias = Text;
        \\  struct Bad {
        \\    field @0 :Alias(UInt32);
        \\  }
        \\}
    );
    defer nested_builtin_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &nested_builtin_alias_file));

    var builtin_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  field @0 :Text(UInt32);
        \\}
    );
    defer builtin_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &builtin_file));

    var builtin_method_file = try parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (field :AnyPointer(Text)) -> ();
        \\}
    );
    defer builtin_method_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &builtin_method_file));

    var enum_file = try parse(std.testing.allocator,
        \\enum E {
        \\  a @0;
        \\}
        \\struct Bad {
        \\  field @0 :E(Text);
        \\}
    );
    defer enum_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &enum_file));

    var enum_alias_file = try parse(std.testing.allocator,
        \\enum E {
        \\  a @0;
        \\}
        \\using Alias = E;
        \\struct Bad {
        \\  field @0 :Alias(Text);
        \\}
    );
    defer enum_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &enum_alias_file));

    var nested_enum_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  enum E {
        \\    a @0;
        \\  }
        \\  struct Bad {
        \\    field @0 :E(Text);
        \\  }
        \\}
    );
    defer nested_enum_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &nested_enum_file));

    var nested_enum_alias_file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  enum E {
        \\    a @0;
        \\  }
        \\  using Alias = E;
        \\  struct Bad {
        \\    field @0 :Alias(Text);
        \\  }
        \\}
    );
    defer nested_enum_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &nested_enum_alias_file));
}

test "schema layout planner rejects recursive aliases" {
    var top_file = try parse(std.testing.allocator,
        \\using A = List(A);
        \\struct Holder {
        \\  value @0 :A;
        \\}
    );
    defer top_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &top_file));

    var commented_application_file = try parse(std.testing.allocator,
        \\using A = A /* comment before args */ (Text);
        \\struct Holder {
        \\  value @0 :A;
        \\}
    );
    defer commented_application_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &commented_application_file));

    var local_file = try parse(std.testing.allocator,
        \\struct Holder {
        \\  using A = List(A);
        \\  value @0 :A;
        \\}
    );
    defer local_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &local_file));

    var interface_file = try parse(std.testing.allocator,
        \\interface Holder {
        \\  using A = List(A);
        \\  call @0 (value :A) -> ();
        \\}
    );
    defer interface_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &interface_file));
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

test "schema parser rejects empty enums" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\enum Bad {
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

test "schema parser rejects malformed method signatures" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call () -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> ;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 GenericBox() -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32) trailing -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> GenericBox();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> (result :UInt32) trailing;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 stream -> ();
        \\}
    ));
}

test "schema parser rejects duplicate interface method field names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32, value :Text) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> (value :UInt32, value :Text);
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (error :UInt32, error_ :Text) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> (error :UInt32, error_ :Text);
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 [error_] (error :UInt32) -> ();
        \\}
    ));
}

test "schema parser keeps separators inside quoted method defaults" {
    var file = try parse(std.testing.allocator,
        \\interface Service {
        \\  literalSyntax @0 (
        \\    greeting :Text = "hello, method",
        \\    payload :Data = "raw,bytes",
        \\    marker :Text = "contains $ marker"
        \\  ) -> (reply :Text = "ok, result");
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), file.interfaces.len);
    try std.testing.expectEqual(@as(usize, 1), file.interfaces[0].methods.len);
    const method = file.interfaces[0].methods[0];
    try std.testing.expectEqual(@as(usize, 3), method.param_fields.len);
    try std.testing.expectEqual(@as(usize, 1), method.result_fields.len);
    try std.testing.expectEqualStrings("\"hello, method\"", method.param_fields[0].default_literal.?);
    try std.testing.expectEqualStrings("\"raw,bytes\"", method.param_fields[1].default_literal.?);
    try std.testing.expectEqualStrings("\"contains $ marker\"", method.param_fields[2].default_literal.?);
    try std.testing.expectEqualStrings("\"ok, result\"", method.result_fields[0].default_literal.?);
}

test "schema parser accepts comments between method field tokens" {
    var file = try parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [
        \\    T /* generic parameter T */,
        \\    # generic parameter U
        \\    U
        \\  ] (
        \\    item /* name/type separator */ : /* type */ T,
        \\    # default expression follows
        \\    label :Text = /* default */ "commented",
        \\    payload :Data /* keep hex classification */ = 0x"aa bb"
        \\  ) -> (
        \\    result :U
        \\  );
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), file.interfaces.len);
    try std.testing.expectEqual(@as(usize, 1), file.interfaces[0].methods.len);
    const method = file.interfaces[0].methods[0];
    try std.testing.expectEqual(@as(usize, 2), method.parameters.len);
    try std.testing.expectEqualStrings("T", method.parameters[0]);
    try std.testing.expectEqualStrings("U", method.parameters[1]);
    try std.testing.expectEqual(@as(usize, 3), method.param_fields.len);
    try std.testing.expectEqualStrings("item", method.param_fields[0].name);
    try std.testing.expectEqualStrings("T", method.param_fields[0].ty);
    try std.testing.expectEqualStrings("label", method.param_fields[1].name);
    try std.testing.expectEqualStrings("\"commented\"", method.param_fields[1].default_literal.?);
    try std.testing.expectEqualStrings("payload", method.param_fields[2].name);
    try std.testing.expectEqualStrings("Data /* keep hex classification */", method.param_fields[2].ty);
    try std.testing.expect(method.param_fields[2].default_is_hex_data);
    try std.testing.expectEqual(@as(usize, 1), method.result_fields.len);
    try std.testing.expectEqualStrings("result", method.result_fields[0].name);
    try std.testing.expectEqualStrings("U", method.result_fields[0].ty);
}

test "schema parser accepts comments between method signature sections" {
    var file = try parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 /* generics follow */ [T] /* params follow */ (item :T) -> /* results follow */ ();
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), file.interfaces.len);
    try std.testing.expectEqual(@as(usize, 1), file.interfaces[0].methods.len);
    const method = file.interfaces[0].methods[0];
    try std.testing.expectEqual(@as(usize, 1), method.parameters.len);
    try std.testing.expectEqualStrings("T", method.parameters[0]);
    try std.testing.expectEqual(@as(usize, 1), method.param_fields.len);
    try std.testing.expectEqualStrings("item", method.param_fields[0].name);
    try std.testing.expectEqual(@as(usize, 0), method.result_fields.len);
}

test "schema parser accepts comments before method annotations" {
    var file = try parse(std.testing.allocator,
        \\annotation marker(method) :Void;
        \\interface Result {
        \\  done @0 () -> ();
        \\}
        \\interface Service {
        \\  call @0 () -> Result /* result annotation follows */ $marker;
        \\  list @1 () -> List /* type application */ (Text) /* annotation follows */ $marker;
        \\  stream @2 () -> stream /* stream annotation follows */ $marker;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), file.interfaces.len);
    const service = &file.interfaces[1];
    try std.testing.expectEqual(@as(usize, 3), service.methods.len);
    try std.testing.expectEqualStrings("Result", service.methods[0].results_type);
    try std.testing.expectEqualStrings("$marker", service.methods[0].annotation_signature);
    try std.testing.expectEqualStrings("$marker", service.methods[1].annotation_signature);
    try std.testing.expectEqualStrings("stream", service.methods[2].results_signature);
    try std.testing.expect(service.methods[2].is_streaming);
    try std.testing.expectEqualStrings("$marker", service.methods[2].annotation_signature);
}

test "schema parser accepts methods with implicit void results" {
    var file = try parse(std.testing.allocator,
        \\annotation marker(method) :Void;
        \\interface Service {
        \\  end @0 ();
        \\  ended @1 (byteCount :UInt64) $marker;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), file.interfaces.len);
    try std.testing.expectEqual(@as(usize, 2), file.interfaces[0].methods.len);
    const end = file.interfaces[0].methods[0];
    try std.testing.expectEqualStrings("()", end.params_signature);
    try std.testing.expectEqualStrings("()", end.results_signature);
    try std.testing.expectEqual(@as(usize, 0), end.param_fields.len);
    try std.testing.expectEqual(@as(usize, 0), end.result_fields.len);
    const ended = file.interfaces[0].methods[1];
    try std.testing.expectEqualStrings("(byteCount :UInt64)", ended.params_signature);
    try std.testing.expectEqualStrings("()", ended.results_signature);
    try std.testing.expectEqual(@as(usize, 1), ended.param_fields.len);
    try std.testing.expectEqual(@as(usize, 0), ended.result_fields.len);
    try std.testing.expectEqualStrings("$marker", ended.annotation_signature);
}

test "schema parser rejects malformed method field commas" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32,) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (, value :UInt32) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (first :UInt32,, second :UInt32) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> (value :UInt32,);
        \\}
    ));
}

test "schema parser rejects empty method field types" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> (value :);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value := 1) -> ();
        \\}
    ));
}

test "schema parser rejects empty method field defaults" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32 =) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32 =, other :UInt32) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 () -> (value :UInt32 =);
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32 = 1 trailing) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32 trailing) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\annotation label(param) :Text;
        \\interface Bad {
        \\  call @0 (value :Text $label("bad") = "late") -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (payload :Data = 0x"01" "junk") -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :UInt32 = 123abc) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (payload :Data = 0x"0") -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (values :List(UInt32) = [1,, 2]) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (values :List(UInt32) = [1, 2) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (values :List(UInt32) = [1,]) -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (item :Item = (id = 1, = 2)) -> ();
        \\}
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (item :Item = (id = )) -> ();
        \\}
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
    ));
}

test "schema layout planner rejects unknown struct literal fields" {
    var const_file = try parse(std.testing.allocator,
        \\const bad :Item = (missing = 1);
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
    );
    defer const_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &const_file));

    var field_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  item @0 :Item = (missing = 1);
        \\}
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
    );
    defer field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &field_file));

    var method_file = try parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (item :Item = (missing = 1)) -> ();
        \\  struct Item {
        \\    id @0 :UInt32;
        \\  }
        \\}
    );
    defer method_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &method_file));
}

test "schema layout planner rejects mismatched aggregate default item types" {
    var enum_field_file = try parse(std.testing.allocator,
        \\enum E {
        \\  a @0;
        \\}
        \\struct Bad {
        \\  values @0 :List(E) = [missing];
        \\}
    );
    defer enum_field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &enum_field_file));

    var enum_method_file = try parse(std.testing.allocator,
        \\enum E {
        \\  a @0;
        \\}
        \\interface Bad {
        \\  call @0 (values :List(E) = [missing]) -> ();
        \\}
    );
    defer enum_method_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &enum_method_file));

    var scalar_list_const_file = try parse(std.testing.allocator,
        \\const values :List(UInt32) = [missing];
    );
    defer scalar_list_const_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &scalar_list_const_file));

    var scalar_struct_const_file = try parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const item :Item = (id = missing);
    );
    defer scalar_struct_const_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &scalar_struct_const_file));

    var struct_ref_file = try parse(std.testing.allocator,
        \\const scalar :UInt32 = 1;
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  item @0 :Item = scalar;
        \\}
    );
    defer struct_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &struct_ref_file));

    var list_ref_file = try parse(std.testing.allocator,
        \\const scalar :UInt32 = 1;
        \\struct Bad {
        \\  values @0 :List(UInt32) = scalar;
        \\}
    );
    defer list_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &list_ref_file));

    var any_struct_scalar_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :AnyStruct = 1;
        \\}
    );
    defer any_struct_scalar_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &any_struct_scalar_file));

    var any_list_struct_file = try parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\struct Bad {
        \\  value @0 :AnyList = (id = 1);
        \\}
    );
    defer any_list_struct_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &any_list_struct_file));

    var capability_scalar_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :Capability = 1;
        \\}
    );
    defer capability_scalar_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &capability_scalar_file));

    var scalar_field_ref_file = try parse(std.testing.allocator,
        \\const text :Text = "x";
        \\struct Bad {
        \\  value @0 :UInt32 = text;
        \\}
    );
    defer scalar_field_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &scalar_field_ref_file));

    var text_field_ref_file = try parse(std.testing.allocator,
        \\const value :UInt32 = 1;
        \\struct Bad {
        \\  text @0 :Text = value;
        \\}
    );
    defer text_field_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &text_field_ref_file));

    var unknown_ref_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :UInt32 = missing;
        \\}
    );
    defer unknown_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &unknown_ref_file));
}

test "schema layout planner rejects defaults for unresolved named types" {
    var field_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :Missing = 1;
        \\}
    );
    defer field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &field_file));

    var list_field_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  values @0 :List(Missing) = [1];
        \\}
    );
    defer list_field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &list_field_file));

    var const_file = try parse(std.testing.allocator,
        \\const value :Missing = 1;
    );
    defer const_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &const_file));

    var scalar_const_ref_file = try parse(std.testing.allocator,
        \\const value :UInt32 = missing;
    );
    defer scalar_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &scalar_const_ref_file));

    var bool_const_ref_file = try parse(std.testing.allocator,
        \\const value :Bool = missing;
    );
    defer bool_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &bool_const_ref_file));

    var text_const_ref_file = try parse(std.testing.allocator,
        \\const value :Text = missing;
    );
    defer text_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &text_const_ref_file));

    var data_const_ref_file = try parse(std.testing.allocator,
        \\const value :Data = missing;
    );
    defer data_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &data_const_ref_file));

    var list_const_ref_file = try parse(std.testing.allocator,
        \\const value :List(UInt32) = missing;
    );
    defer list_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &list_const_ref_file));

    var any_const_ref_file = try parse(std.testing.allocator,
        \\const value :AnyPointer = missing;
    );
    defer any_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &any_const_ref_file));

    var method_file = try parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :Missing = 1) -> ();
        \\}
    );
    defer method_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &method_file));

    var method_const_ref_file = try parse(std.testing.allocator,
        \\const text :Text = "x";
        \\const number :UInt32 = 1;
        \\interface Bad {
        \\  wrongScalar @0 (value :UInt32 = text) -> ();
        \\  wrongText @1 (label :Text = number) -> ();
        \\}
    );
    defer method_const_ref_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &method_const_ref_file));
}

test "schema layout planner rejects unresolved simple named types without defaults" {
    var field_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :Missing;
        \\}
    );
    defer field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &field_file));

    var list_field_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  values @0 :List(Missing);
        \\}
    );
    defer list_field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &list_field_file));

    var alias_file = try parse(std.testing.allocator,
        \\using Alias = Missing;
        \\struct Bad {
        \\  value @0 :Alias;
        \\}
    );
    defer alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &alias_file));

    var method_file = try parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :Missing) -> ();
        \\}
    );
    defer method_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &method_file));

    var method_list_file = try parse(std.testing.allocator,
        \\interface Bad {
        \\  call @0 (value :List(Missing)) -> ();
        \\}
    );
    defer method_list_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &method_list_file));

    var dotted_field_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :Missing.Type;
        \\}
    );
    defer dotted_field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &dotted_field_file));

    var method_import_file = try parse(std.testing.allocator,
        \\interface Imported {
        \\  call @0 (value :import "imported.capnp".Value) -> ();
        \\}
    );
    defer method_import_file.deinit(std.testing.allocator);
    var method_import_layouts = try planLayouts(std.testing.allocator, &method_import_file);
    method_import_layouts.deinit(std.testing.allocator);

    var method_list_import_file = try parse(std.testing.allocator,
        \\interface Imported {
        \\  call @0 (value :List(import "imported.capnp".Value)) -> ();
        \\}
    );
    defer method_list_import_file.deinit(std.testing.allocator);
    var method_list_import_layouts = try planLayouts(std.testing.allocator, &method_list_import_file);
    method_list_import_layouts.deinit(std.testing.allocator);
}

test "schema layout planner rejects scalar defaults for generic parameters" {
    var field_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  value @0 :T = 1;
        \\}
    );
    defer field_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &field_file));

    var const_file = try parse(std.testing.allocator,
        \\struct Box(T) {
        \\  const value :T = 1;
        \\}
    );
    defer const_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnexpectedToken, planLayouts(std.testing.allocator, &const_file));
}

test "schema layout planner accepts interface parameters in nested structs" {
    var file = try parse(std.testing.allocator,
        \\interface Persistent(SturdyRef, Owner) {
        \\  save @0 SaveParams -> SaveResults;
        \\
        \\  struct SaveParams {
        \\    sealFor @0 :Owner;
        \\  }
        \\
        \\  struct SaveResults {
        \\    sturdyRef @0 :SturdyRef;
        \\  }
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), file.structs.len);
    try std.testing.expectEqualStrings("Owner", file.structs[0].fields[0].ty.named);
    try std.testing.expectEqualStrings("SturdyRef", file.structs[1].fields[0].ty.named);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 1), layouts.structs[0].pointer_count);
    try std.testing.expectEqual(@as(u16, 1), layouts.structs[1].pointer_count);
}

test "schema parser rejects duplicate field names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :UInt32;
        \\  value @1 :Text;
        \\}
    ));
}

test "schema parser rejects duplicate group and union names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  repeated @0 :group {
        \\    first @0 :UInt32;
        \\  }
        \\  repeated @1 :group {
        \\    second @0 :UInt32;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  repeated @0 :union {
        \\    first @0 :UInt32;
        \\  }
        \\  repeated @1 :union {
        \\    second @0 :UInt32;
        \\  }
        \\}
    ));
}

test "schema parser rejects empty group and union bodies" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  union {
        \\  }
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  choice @0 :union {
        \\  }
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  group @0 :group {
        \\  }
        \\}
    ));
}

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

test "schema parser rejects duplicate top-level declaration names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Thing {
        \\  id @0 :UInt32;
        \\}
        \\enum Thing {
        \\  value @0;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\using import "foo.capnp";
        \\const Foo :UInt32 = 1;
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\using import "foo.capnp";
        \\const Foo :List(UInt32) = [1, 2];
    ));
}

test "schema parser rejects duplicate declaration and method parameter names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(Box) {
        \\  item @0 :Box;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(error, error_) {
        \\  item @0 :error;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service(Service) {
        \\  call @0 () -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service(error, error_) {
        \\  call @0 () -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(T, T) {
        \\  item @0 :T;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service(Req, Req) {
        \\  call @0 () -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [T, T] () -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [call] (item :call) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(Text) {
        \\  item @0 :Text;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [UInt32] (item :UInt32) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service(T) {
        \\  call @0 [T] (item :T) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  using T = UInt32;
        \\  call @0 [T] (item :T) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  const T :UInt32 = 1;
        \\  call @0 [T] (item :T) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(T) {
        \\  using T = Text;
        \\  item @0 :Text;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(T) {
        \\  T @0 :Text;
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(T) {
        \\  union {
        \\    T @0 :UInt32;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Box(T) {
        \\  group :group {
        \\    T @0 :UInt32;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service(T) {
        \\  using T = Text;
        \\  call @0 () -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [T] (T :UInt32) -> ();
        \\}
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [error, error_] () -> ();
        \\}
    ));
}

test "schema parser rejects malformed declaration and method parameter lists" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Box(T U) {
        \\  item @0 :T;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [T U] () -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Box(T,) {
        \\  item @0 :T;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [T,] () -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Box() {
        \\  item @0 :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Service {
        \\  call @0 [] () -> ();
        \\}
    ));
}

test "schema parser rejects malformed interface extends list" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Derived extends() {
        \\  call @0 () -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Base {
        \\  call @0 () -> ();
        \\}
        \\interface Derived extends(Base Base) {
        \\  call @0 () -> ();
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Base {
        \\  call @0 () -> ();
        \\}
        \\interface Derived extends(Base,) {
        \\  call @0 () -> ();
        \\}
    ));
}

test "schema parser rejects duplicate interface superclasses" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\interface Base {
        \\  call @0 () -> ();
        \\}
        \\interface Derived extends(Base, Base) {
        \\  call @0 () -> ();
        \\}
    ));
}

test "schema layout planner rejects unsupported interface superclasses" {
    var unknown_file = try parse(std.testing.allocator,
        \\interface Derived extends(Missing) {
        \\  call @0 () -> ();
        \\}
    );
    defer unknown_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &unknown_file));

    var scalar_file = try parse(std.testing.allocator,
        \\interface Derived extends(UInt32) {
        \\  call @0 () -> ();
        \\}
    );
    defer scalar_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &scalar_file));

    var capability_file = try parse(std.testing.allocator,
        \\interface Derived extends(Capability) {
        \\  call @0 () -> ();
        \\}
    );
    defer capability_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &capability_file));

    var capability_alias_file = try parse(std.testing.allocator,
        \\using Cap = Capability;
        \\interface Derived extends(Cap) {
        \\  call @0 () -> ();
        \\}
    );
    defer capability_alias_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &capability_alias_file));

    var alias_file = try parse(std.testing.allocator,
        \\interface Base {
        \\  call @0 () -> ();
        \\}
        \\using Alias = Base;
        \\interface Derived extends(Alias) {
        \\  call @0 () -> ();
        \\}
    );
    defer alias_file.deinit(std.testing.allocator);
    var alias_layouts = try planLayouts(std.testing.allocator, &alias_file);
    alias_layouts.deinit(std.testing.allocator);

    var import_file = try parse(std.testing.allocator,
        \\using Base = import "base.capnp";
        \\interface Derived extends(Base.Service) {
        \\  call @0 () -> ();
        \\}
    );
    defer import_file.deinit(std.testing.allocator);
    var import_layouts = try planLayouts(std.testing.allocator, &import_file);
    import_layouts.deinit(std.testing.allocator);
}

test "schema parser skips common top-level using and const declarations" {
    const source =
        \\using Go = import "go.capnp";
        \\const defaultName :Text = "Ada";
        \\const embeddedText :Text = embed "testdata/short.txt";
        \\const embeddedPerson :Person = embed "testdata/binary";
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
    try std.testing.expectEqual(@as(usize, 5), file.consts.len);
    try std.testing.expectEqualStrings("Person", file.structs[0].name);
    try std.testing.expectEqualStrings("Ada", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("defaultName", file.consts[0].name);
    try std.testing.expectEqualStrings("embeddedText", file.consts[1].name);
    try std.testing.expectEqualStrings("embed \"testdata/short.txt\"", file.consts[1].literal);
    try std.testing.expect(file.consts[1].is_embed);
    try std.testing.expectEqualStrings("testdata/short.txt", file.consts[1].embed_path);
    try std.testing.expect(!file.consts[1].emit_value);
    try std.testing.expectEqualStrings("embeddedPerson", file.consts[2].name);
    try std.testing.expectEqualStrings("embed \"testdata/binary\"", file.consts[2].literal);
    try std.testing.expect(file.consts[2].is_embed);
    try std.testing.expectEqualStrings("testdata/binary", file.consts[2].embed_path);
    try std.testing.expect(!file.consts[2].emit_value);
    try std.testing.expectEqualStrings("rawPerson", file.consts[3].name);
    try std.testing.expectEqualStrings("(name = \"Raw\")", file.consts[3].literal);
    try std.testing.expect(!file.consts[3].emit_value);
    try std.testing.expect(file.consts[3].is_struct_literal);
    try std.testing.expectEqual(@as(usize, 1), file.consts[3].struct_fields.?.len);
    try std.testing.expectEqualStrings("name", file.consts[3].struct_fields.?[0].name);
    try std.testing.expectEqualStrings("\"Raw\"", file.consts[3].struct_fields.?[0].literal);
    try std.testing.expectEqualStrings("blockText", file.consts[4].name);
}

test "schema parser rejects malformed const declarations" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const :UInt32 = 1;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const bad UInt32 = 1;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const bad : = 1;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const bad :UInt32;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const bad :UInt32 = ;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "const bad :Data = 0x;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Owner {
        \\  const bad :UInt32;
        \\}
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\interface Service {
        \\  const bad :UInt32 = ;
        \\  call @0 () -> ();
        \\}
    ));
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

test "schema parser accepts wildcard annotation targets" {
    var file = try parse(std.testing.allocator,
        \\annotation all(*) :Void;
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), file.annotations.len);
    try std.testing.expectEqualStrings("all", file.annotations[0].name);
    try std.testing.expectEqual(@as(usize, 12), file.annotations[0].targets.count());
    try std.testing.expect(file.annotations[0].targets.hasTarget("file"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("const"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("enum"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("enumerant"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("struct"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("field"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("union"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("group"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("interface"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("method"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("param"));
    try std.testing.expect(file.annotations[0].targets.hasTarget("annotation"));
}

test "schema parser rejects wildcard annotation target mixed with explicit targets" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(*, field) :Void;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(field, *) :Void;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(*, *) :Void;"));
}

test "schema parser rejects duplicate annotation targets" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(field, field) :Void;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(struct, field, struct) :Void;"));
}

test "schema parser rejects malformed annotation target lists" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(field,) :Void;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad(,) :Void;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "annotation bad() :Void;"));
}

test "schema parser records imported type aliases" {
    const source =
        \\using Other = import "other.capnp";
        \\using import "whole.capnp";
        \\using import "/path/to/common.capnp";
        \\using import "common.capnp".Shared;
        \\using Generic = import "generic.capnp".Box(Text);
        \\using import "generic.capnp".Box(Text);
        \\using import "generic.capnp".Outer.Box(Text).Inner;
        \\struct Holder {
        \\  external @0 :Other.External;
        \\  shared @1 :Shared;
        \\  generic @2 :Generic;
        \\  box @3 :Box;
        \\  inner @4 :Inner;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 7), file.imports.len);
    try std.testing.expectEqualStrings("Other", file.imports[0].name);
    try std.testing.expectEqualStrings("other.capnp", file.imports[0].path);
    try std.testing.expect(file.imports[0].member == null);
    try std.testing.expectEqualStrings("whole", file.imports[1].name);
    try std.testing.expectEqualStrings("whole.capnp", file.imports[1].path);
    try std.testing.expect(file.imports[1].member == null);
    try std.testing.expectEqualStrings("common", file.imports[2].name);
    try std.testing.expectEqualStrings("/path/to/common.capnp", file.imports[2].path);
    try std.testing.expect(file.imports[2].member == null);
    try std.testing.expectEqualStrings("Shared", file.imports[3].name);
    try std.testing.expectEqualStrings("common.capnp", file.imports[3].path);
    try std.testing.expectEqualStrings("Shared", file.imports[3].member.?);
    try std.testing.expectEqualStrings("Generic", file.imports[4].name);
    try std.testing.expectEqualStrings("generic.capnp", file.imports[4].path);
    try std.testing.expectEqualStrings("Box(Text)", file.imports[4].member.?);
    try std.testing.expectEqualStrings("Box", file.imports[5].name);
    try std.testing.expectEqualStrings("generic.capnp", file.imports[5].path);
    try std.testing.expectEqualStrings("Box(Text)", file.imports[5].member.?);
    try std.testing.expectEqualStrings("Inner", file.imports[6].name);
    try std.testing.expectEqualStrings("generic.capnp", file.imports[6].path);
    try std.testing.expectEqualStrings("Outer.Box(Text).Inner", file.imports[6].member.?);
    try std.testing.expectEqualStrings("Other.External", file.structs[0].fields[0].ty.named);
    try std.testing.expectEqualStrings("Shared", file.structs[0].fields[1].ty.named);
    try std.testing.expectEqualStrings("Generic", file.structs[0].fields[2].ty.named);
    try std.testing.expectEqualStrings("Box", file.structs[0].fields[3].ty.named);
    try std.testing.expectEqualStrings("Inner", file.structs[0].fields[4].ty.named);
}

test "schema parser rejects bare anonymous import declaration name collisions" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Foo {
        \\}
        \\using import "foo.capnp";
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\using import "foo.capnp";
        \\struct Foo {
        \\}
    ));
}

test "schema parser rejects empty import paths" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using Empty = import \"\";"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using import \"\";"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using import \".capnp\";"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :import "".Value;
        \\}
    ));
}

test "schema parser rejects malformed import declarations" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using Bad = import;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using import;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using Bad = import \"bad.capnp\" trailing;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using import \"bad.capnp\" trailing;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using Bad = import \"bad.capnp\".;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "using import \"bad.capnp\".;"));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Owner {
        \\  using Bad = import "bad.capnp" trailing;
        \\}
    ));
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
        \\  metadata :group $Ann.name("metadata") {
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
    try std.testing.expectEqual(@as(usize, 1), file.structs[0].groups.len);
    try std.testing.expectEqualStrings("metadata", file.structs[0].groups[0].name);
    try std.testing.expectEqualStrings("$Ann.name(\"metadata\")", file.structs[0].groups[0].annotations);
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
    try std.testing.expectEqual(@as(usize, 1), file.structs[0].unions.len);
    try std.testing.expectEqualStrings("selected", file.structs[0].unions[0].name);
    try std.testing.expectEqual(@as(?u32, 1), file.structs[0].unions[0].ordinal);
    try std.testing.expectEqualStrings("$Ann.name(\"selected\")", file.structs[0].unions[0].annotations);
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
        \\  total @2 :UInt32 = +42;
        \\  tiny @3 :Float64 = 1e-3;
        \\  huge @4 :Float64 = +2.5E+4;
        \\  posInf @5 :Float32 = inf;
        \\  negInf @6 :Float64 = -inf;
        \\  quietNan @7 :Float32 = nan;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("+1.5", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("+7", file.structs[0].fields[1].default_literal.?);
    try std.testing.expectEqualStrings("+42", file.structs[0].fields[2].default_literal.?);
    try std.testing.expectEqualStrings("1e-3", file.structs[0].fields[3].default_literal.?);
    try std.testing.expectEqualStrings("+2.5E+4", file.structs[0].fields[4].default_literal.?);
    try std.testing.expectEqualStrings("inf", file.structs[0].fields[5].default_literal.?);
    try std.testing.expectEqualStrings("-inf", file.structs[0].fields[6].default_literal.?);
    try std.testing.expectEqualStrings("nan", file.structs[0].fields[7].default_literal.?);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(0, 1.5)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getInt32(4, 7)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getUInt32(8, 42)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(16, 1e-3)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(24, 2.5E+4)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(12, std.math.inf(f32))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(32, -std.math.inf(f64))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(40, std.math.nan(f32))") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_nums(self: Builder, @\"cpz.count\": usize)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_child(self: Builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getDataDefault(\"bar\")") != null);
}

test "schema parser accepts trailing commas in struct defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Pair {
        \\  left @0 :Text;
        \\  right @1 :Text;
        \\}
        \\const pair :Pair = (
        \\  left = "a",
        \\  right = "b",
        \\);
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), file.consts.len);
    try std.testing.expectEqual(@as(usize, 2), file.consts[0].struct_fields.?.len);
    try std.testing.expectEqualStrings("right", file.consts[0].struct_fields.?[1].name);
}

test "schema parser rejects duplicate const struct field names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const item :Item = (id = 1, id = 2);
    ));
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const items :List(Item) = [(id = 1, id = 2)];
    ));
}

test "schema parser rejects empty const struct field values" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const item :Item = (id = );
    ));
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator,
        \\struct Item {
        \\  id @0 :UInt32;
        \\}
        \\const items :List(Item) = [(id = )];
    ));
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

test "schema layout planner rejects optional scalar fields" {
    var scalar_file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :?UInt32;
        \\}
    );
    defer scalar_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &scalar_file));

    var enum_file = try parse(std.testing.allocator,
        \\enum Mode {
        \\  off @0;
        \\}
        \\struct Bad {
        \\  mode @0 :?Mode;
        \\}
    );
    defer enum_file.deinit(std.testing.allocator);
    try std.testing.expectError(error.UnsupportedType, planLayouts(std.testing.allocator, &enum_file));
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
    try std.testing.expectEqual(@as(usize, 1), try countUnions(file.structs[0].fields));
    try std.testing.expectEqual(@as(u32, 0), try checkedUnionIndex(0));
    try std.testing.expectEqual(std.math.maxInt(u32), try checkedUnionIndex(std.math.maxInt(u32)));
    if (@bitSizeOf(usize) > @bitSizeOf(u32)) {
        try std.testing.expectError(error.InvalidOrdinal, checkedUnionIndex(@as(usize, std.math.maxInt(u32)) + 1));
    } else {
        const huge_union_field = [_]Field{.{
            .name = "huge",
            .ordinal = 0,
            .ty = .void,
            .union_index = std.math.maxInt(u32),
        }};
        try std.testing.expectError(error.InvalidOrdinal, countUnions(&huge_union_field));
    }
    try std.testing.expectEqual(@as(std.StringHashMap(void).Size, 0), try hashMapCapacityCount(0));
    try std.testing.expectEqual(std.math.maxInt(std.StringHashMap(void).Size), try hashMapCapacityCount(std.math.maxInt(std.StringHashMap(void).Size)));
    if (@bitSizeOf(usize) > @bitSizeOf(std.StringHashMap(void).Size)) {
        try std.testing.expectError(error.InvalidOrdinal, hashMapCapacityCount(@as(usize, std.math.maxInt(std.StringHashMap(void).Size)) + 1));
    }
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
        \\  absoluteChild @4 :.Outer.Inner;
        \\  absoluteChildren @5 :List(.Outer.Inner);
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
    try std.testing.expectEqual(@as(usize, 6), outer.fields.len);
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
    try std.testing.expect(outer.fields[4].ty == .named);
    try std.testing.expectEqualStrings("Outer.Inner", outer.fields[4].ty.named);
    try std.testing.expect(outer.fields[5].ty == .list);
    try std.testing.expect(outer.fields[5].ty.list.* == .named);
    try std.testing.expectEqualStrings("Outer.Inner", outer.fields[5].ty.list.*.named);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, layouts.structs[1].fields[2].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 2 }, layouts.structs[1].fields[3].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 3 }, layouts.structs[1].fields[4].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 4 }, layouts.structs[1].fields[5].slot);
}

test "schema layout planner resolves relative nested enum defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Outer {
        \\  struct Inner {
        \\    enum State {
        \\      ready @0;
        \\      done @1;
        \\    }
        \\  }
        \\  state @0 :Inner.State = done;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, layouts.structs[1].fields[0].slot);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "Outer_Inner_State") != null);
}

test "schema layout planner binds outer generic args for nested struct defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Box(Foo, Bar) {
        \\  struct Inner {
        \\    foo @0 :Foo;
        \\    bar @1 :Bar;
        \\  }
        \\}
        \\struct Defaults {
        \\  value @0 :Box(UInt32, Text).Inner = (foo = 123, bar = "ok");
        \\}
    );
    defer file.deinit(std.testing.allocator);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    var saw_defaults = false;
    for (layouts.structs) |layout| {
        if (std.mem.eql(u8, layout.decl.name, "Defaults")) {
            saw_defaults = true;
            try std.testing.expectEqual(@as(u16, 1), layout.pointer_count);
        }
    }
    try std.testing.expect(saw_defaults);
}

test "schema layout planner binds generic aliases in default types" {
    var file = try parse(std.testing.allocator,
        \\struct Box(Foo, Bar) {
        \\  using AliasFoo = Foo;
        \\  using AliasInner = Inner;
        \\  struct Inner {
        \\    foo @0 :Foo;
        \\    bar @1 :Bar;
        \\  }
        \\}
        \\struct Defaults {
        \\  value @0 :Box(UInt32, Text).AliasFoo = 123;
        \\  inner @1 :Box(UInt32, Text).AliasInner = (foo = 123, bar = "ok");
        \\}
    );
    defer file.deinit(std.testing.allocator);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    var saw_defaults = false;
    for (layouts.structs) |layout| {
        if (std.mem.eql(u8, layout.decl.name, "Defaults")) {
            saw_defaults = true;
        }
    }
    try std.testing.expect(saw_defaults);
}

test "schema layout planner resolves alias suffix type references" {
    var file = try parse(std.testing.allocator,
        \\struct Box(Foo, Bar) {
        \\  using AliasFoo = Foo;
        \\  using AliasRev = Box(Bar, Foo);
        \\
        \\  struct UseAliases {
        \\    revFoo @0 :AliasRev.AliasFoo;
        \\  }
        \\}
    );
    defer file.deinit(std.testing.allocator);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expect(layouts.structs.len >= 2);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn revFoo(self: @This()) !cpz.PointerReader") != null);
}

test "schema layout planner resolves qualified alias suffixes" {
    var file = try parse(std.testing.allocator,
        \\struct Owner {
        \\  using Bytes = Data;
        \\}
        \\struct Holder {
        \\  payload @0 :Owner.Bytes;
        \\}
    );
    defer file.deinit(std.testing.allocator);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 1), layouts.structs[1].pointer_count);
}

test "schema resolver inherits aliases from ancestor declaration scopes" {
    var file = try parse(std.testing.allocator,
        \\struct Parent {
        \\  using Id = UInt32;
        \\  struct Child {
        \\    id @0 :Id;
        \\  }
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), file.structs.len);
    try std.testing.expectEqualStrings("Parent.Child", file.structs[0].name);
    try std.testing.expectEqualStrings("Parent", file.structs[1].name);
    try std.testing.expectEqualStrings("Id", file.structs[0].fields[0].ty.named);
    try std.testing.expectEqual(Type.uint32, resolveTypeScoped(&file, &file.structs[0], file.structs[0].fields[0].ty));

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, layouts.structs[0].fields[0].slot);

    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn id(self: @This()) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const @\"cpz.field.id.resolvedType\": []const u8 = \"UInt32\"") != null);
}

test "schema layout planner assigns data and pointer slots" {
    const fields_for_order = [_]Field{
        .{ .name = "later", .ordinal = 2, .ty = .void },
        .{ .name = "earlier", .ordinal = 1, .ty = .void },
    };
    var assigned_for_order = [_]bool{ false, false };
    try std.testing.expectEqual(@as(usize, 1), try nextOrdinalFieldIndexChecked(&fields_for_order, &assigned_for_order));
    assigned_for_order[1] = true;
    try std.testing.expectEqual(@as(usize, 0), try nextOrdinalFieldIndexChecked(&fields_for_order, &assigned_for_order));
    assigned_for_order[0] = true;
    try std.testing.expectError(error.InvalidOrdinal, nextOrdinalFieldIndexChecked(&fields_for_order, &assigned_for_order));
    try std.testing.expectError(error.InvalidOrdinal, nextOrdinalFieldIndexChecked(&fields_for_order, assigned_for_order[0..1]));

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
    const missing_field = Field{ .name = "missing", .ordinal = 99, .ty = .void };
    try std.testing.expectError(error.UnsupportedType, fieldIndex(&layout, &missing_field));
}

test "schema parser rejects duplicate struct field ordinals" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  a @0 :UInt32;
        \\  b @0 :UInt32;
        \\}
    ));
}

test "schema parser rejects flattened group and union ordinal collisions" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  before @0 :UInt32;
        \\  union {
        \\    collides @0 :Text;
        \\    other @1 :UInt32;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  before @0 :UInt32;
        \\  details @1 :group {
        \\    collides @0 :Text;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  before @0 :UInt32;
        \\  selected @1 :union {
        \\    collides @0 :Text;
        \\  }
        \\}
    ));
}

test "schema parser rejects named group and union member ordinal collisions" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  before @0 :UInt32;
        \\  details @0 :group {
        \\    value @1 :Text;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  before @0 :UInt32;
        \\  selected @0 :union {
        \\    value @1 :Text;
        \\  }
        \\}
    ));
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  details @0 :group {
        \\    value @1 :Text;
        \\  }
        \\  selected @0 :union {
        \\    other @2 :Text;
        \\  }
        \\}
    ));
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

test "schema layout planner handles group members inside unions" {
    var file = try parse(std.testing.allocator,
        \\struct Choice {
        \\  union {
        \\    foo :group {
        \\      id @0 :UInt32;
        \\      text @2 :Text;
        \\      union {
        \\        nested @5 :Text;
        \\        other @6 :UInt16;
        \\      }
        \\    }
        \\    bar :group {
        \\      label @1 :Text;
        \\      count @3 :UInt64;
        \\    }
        \\    plain @4 :UInt16;
        \\  }
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), file.structs[0].fields.len);
    try std.testing.expectEqual(@as(usize, 2), file.structs[0].groups.len);
    try std.testing.expectEqualStrings("foo", file.structs[0].groups[0].name);
    try std.testing.expectEqualStrings("bar", file.structs[0].groups[1].name);
    try std.testing.expectEqualStrings("foo_id", file.structs[0].fields[0].name);
    try std.testing.expectEqualStrings("foo_text", file.structs[0].fields[1].name);
    try std.testing.expectEqualStrings("bar_label", file.structs[0].fields[2].name);
    try std.testing.expectEqualStrings("bar_count", file.structs[0].fields[3].name);
    try std.testing.expectEqual(@as(u16, 0), file.structs[0].fields[0].union_discriminant);
    try std.testing.expectEqual(@as(u16, 0), file.structs[0].fields[1].union_discriminant);
    try std.testing.expectEqual(@as(u16, 1), file.structs[0].fields[2].union_discriminant);
    try std.testing.expectEqual(@as(u16, 1), file.structs[0].fields[3].union_discriminant);
    try std.testing.expectEqual(@as(u16, 2), file.structs[0].fields[4].union_discriminant);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const layout = layouts.structs[0];
    try std.testing.expectEqual(@as(u16, 2), layout.data_words);
    try std.testing.expectEqual(@as(u16, 1), layout.pointer_count);
    try std.testing.expectEqual(@as(usize, 1), layout.unions.len);
    try std.testing.expectEqual(@as(usize, 64), layout.unions[0].data_bit);
    try std.testing.expectEqual(@as(usize, 64), layout.unions[0].data_bits);
    try std.testing.expectEqual(@as(usize, 1), layout.unions[0].pointer_count);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 8 }, layout.fields[0].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, layout.fields[1].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, layout.fields[2].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 8 }, layout.fields[3].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 8 }, layout.fields[4].slot);

    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, code, "foo_id = 0,"));
    try std.testing.expectEqual(@as(usize, 0), std.mem.count(u8, code, "foo_text = 0,"));
}

test "schema parser validates defaults for flattened union groups" {
    var file = try parse(std.testing.allocator,
        \\struct Choice {
        \\  selected :union {
        \\    foo :group {
        \\      id @0 :UInt32;
        \\      label @1 :Text;
        \\    }
        \\    bar :group {
        \\      flag @2 :Bool;
        \\    }
        \\  }
        \\}
        \\struct Defaults {
        \\  choice @0 :Choice = (selected = (foo = (id = 123, label = "ok")));
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), file.structs.len);
    try std.testing.expectEqualStrings("(selected = (foo = (id = 123, label = \"ok\")))", file.structs[1].fields[0].default_expression);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
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

test "schema layout planner reports alignment overflow" {
    try std.testing.expectError(error.InvalidOrdinal, alignForwardChecked(std.math.maxInt(usize), 64));
    try std.testing.expectEqual(@as(usize, 65), try dataRangeEnd(1, 64));
    try std.testing.expectError(error.InvalidOrdinal, dataRangeEnd(std.math.maxInt(usize), 1));

    var ranges = std.ArrayList(BitRange).empty;
    defer ranges.deinit(std.testing.allocator);
    try ranges.append(std.testing.allocator, .{
        .start = 0,
        .end = std.math.maxInt(usize),
    });
    try std.testing.expectError(error.InvalidOrdinal, allocateDataBits(std.testing.allocator, &ranges, 64));
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

test "schema parser and code generator accept C-style escaped text literals" {
    var file = try parse(std.testing.allocator,
        \\const escaped :Text = "\a\b\f\v\?\'\101";
        \\struct Escaped {
        \\  text @0 :Text = "\x41\a";
        \\}
    );
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("\\a\\b\\f\\v\\?\\'\\101", file.consts[0].literal);
    try std.testing.expectEqualStrings("\\x41\\a", file.structs[0].fields[0].default_literal.?);

    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const escaped: []const u8 = \"\\x07\\x08\\x0C\\x0B?'A\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getTextDefault(\"A\\x07\")") != null);
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
