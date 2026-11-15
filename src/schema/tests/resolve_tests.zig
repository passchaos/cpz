const std = @import("std");
const frontend = @import("../frontend.zig");
const codegen = @import("../codegen.zig");

const FieldSlot = frontend.FieldSlot;
const Type = frontend.Type;
const generateZig = codegen.generateZig;
const parse = frontend.parse;
const planLayouts = frontend.planLayouts;
const resolveTypeScoped = frontend.resolveTypeScoped;

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
