const std = @import("std");
const frontend = @import("../frontend.zig");
const codegen = @import("../codegen.zig");

const BitRange = frontend.BitRange;
const Field = frontend.Field;
const FieldSlot = frontend.FieldSlot;
const Type = frontend.Type;
const alignForwardChecked = frontend.alignForwardChecked;
const allocateDataBits = frontend.allocateDataBits;
const dataRangeEnd = frontend.dataRangeEnd;
const fieldIndex = codegen.fieldIndex;
const generateZig = codegen.generateZig;
const nextOrdinalFieldIndexChecked = frontend.nextOrdinalFieldIndexChecked;
const parse = frontend.parse;
const planLayouts = frontend.planLayouts;

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
