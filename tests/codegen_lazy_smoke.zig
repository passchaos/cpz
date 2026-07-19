const std = @import("std");
const generated = @import("generated_lazy_schema");

test "lazy generated declarations are valid when referenced" {
    _ = generated.Groups.Union0;
    _ = generated.Generic.AliasFoo;
    _ = generated.Generic.AliasInnerText;
    _ = generated.Generic_UseAliases.revFoo;
    _ = generated.UseConcreteAliases.aliasFoo;
    _ = generated.UseConcreteAliases.aliasInner;
    _ = generated.Constants.structConst.fields;
    _ = generated.Constants.structListConst.items;

    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, @typeName(generated.Groups.Union0), "Union0"));
    try std.testing.expect(generated.Constants.structConst.fieldCount > 0);
    try std.testing.expect(generated.Constants.structListConst.itemCount > 0);
}
