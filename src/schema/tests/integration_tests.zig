const std = @import("std");
const frontend = @import("../frontend.zig");
const codegen = @import("../codegen.zig");

const FieldSlot = frontend.FieldSlot;
const Type = frontend.Type;
const generateZig = codegen.generateZig;
const parse = frontend.parse;
const planLayouts = frontend.planLayouts;

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
