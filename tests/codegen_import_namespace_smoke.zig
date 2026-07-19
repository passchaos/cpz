const std = @import("std");
const generated = @import("generated_import_use_namespace");

test "generated namespaced schema references imported modules" {
    try std.testing.expectEqual(@as(usize, 5), generated.api.@"cpz.importCount");
    try std.testing.expectEqualStrings("Holder", generated.api.@"cpz.declarationByName"("Holder").?.name);
    try std.testing.expectEqualStrings("Base.Child", generated.api.Holder.@"cpz.field.child.resolvedType");
    try std.testing.expectEqualStrings("List(Base.Child)", generated.api.Holder.@"cpz.field.children.resolvedType");
    try std.testing.expectEqualStrings("Base.Extra", generated.api.Holder.@"cpz.field.extra.resolvedType");
}
