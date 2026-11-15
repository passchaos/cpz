const std = @import("std");
const frontend = @import("../frontend.zig");
const codegen = @import("../codegen.zig");

const Field = frontend.Field;
const FieldSlot = frontend.FieldSlot;
const Type = frontend.Type;
const checkedUnionIndex = frontend.checkedUnionIndex;
const countUnions = frontend.countUnions;
const generateZig = codegen.generateZig;
const hashMapCapacityCount = frontend.hashMapCapacityCount;
const parse = frontend.parse;
const planLayouts = frontend.planLayouts;
const resolveTypeScoped = frontend.resolveTypeScoped;

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
