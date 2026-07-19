const std = @import("std");
const generated = @import("generated_namespace_schema");

test "generated namespace wrapper compiles and exposes declarations" {
    try std.testing.expectEqual(generated.api.Tone.low, generated.api.defaultTone);
    try std.testing.expectEqual(@as(usize, 2), generated.api.Demo.@"cpz.fieldCount");
    try std.testing.expectEqualStrings("Tone", generated.api.Demo.@"cpz.field.tone.resolvedType");
    try std.testing.expectEqualStrings("Child", generated.api.Demo.@"cpz.field.child.resolvedType");
}
