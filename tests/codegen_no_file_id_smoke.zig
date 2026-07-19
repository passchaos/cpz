const std = @import("std");
const generated = @import("generated_no_file_id_schema");

test "schema without file id still parses and emits constants" {
    try std.testing.expectEqualStrings("foo", generated.@"cpz.constByName"("foo").?.name);
    try std.testing.expectEqualStrings("bar", generated.foo);
    var reader = generated.fooFlat.reader(.{});
    try std.testing.expectEqualStrings("bar", try generated.fooFlat.get(&reader));
}
