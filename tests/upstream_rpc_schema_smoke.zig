const std = @import("std");
const cpz = @import("cpz");
const upstream = @import("support/upstream.zig");

// Optional compatibility smoke for the upstream RPC schema. The upstream
// checkout is intentionally not vendored into cpz, so source distributions skip
// this test when the local reference tree is absent. Set CPZ_CAPNP_SRC (or
// CPZ_RPC_SCHEMA) to point at a Cap'n Proto checkout in CI.
const max_schema_bytes = 2 * 1024 * 1024;

fn readRpcSchema(allocator: std.mem.Allocator) ![]u8 {
    const path = try upstream.rpcSchemaPath(allocator);
    defer allocator.free(path);
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, allocator, .limited(max_schema_bytes)) catch |err| switch (err) {
        error.FileNotFound => error.SkipZigTest,
        else => err,
    };
}

test "upstream rpc.capnp parses, plans, and codegens" {
    const allocator = std.testing.allocator;
    const source = try readRpcSchema(allocator);
    defer allocator.free(source);

    var file = try cpz.schema.parse(allocator, source);
    defer file.deinit(allocator);
    try std.testing.expect(file.id != null);
    try std.testing.expect(file.structs.len > 0);
    try std.testing.expect(file.aliases.len > 0);

    var layouts = try cpz.schema.planLayouts(allocator, &file);
    defer layouts.deinit(allocator);
    try std.testing.expect(layouts.structs.len >= file.structs.len);

    const generated = try cpz.schema.generateZigWithOptions(allocator, &file, &layouts, .{
        .runtime_import_name = "cpz",
        .namespace = "rpcschema",
    });
    defer allocator.free(generated);
    try std.testing.expect(std.mem.indexOf(u8, generated, "pub const Message") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "pub const Bootstrap") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "pub const Release") != null);
}
