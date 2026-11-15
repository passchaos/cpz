const std = @import("std");

// Optional upstream compatibility fixtures are not vendored into cpz. Tests
// skip when the configured checkout is absent, so ordinary source
// distributions do not depend on a sibling Cap'n Proto tree.
//
// Resolution order:
//   CPZ_CAPNP_TESTDATA / CPZ_RPC_SCHEMA  (direct path override)
//   CPZ_CAPNP_SRC                        (Cap'n Proto checkout root)
//   /home/passchaos/Work/capnproto       (historical local default)
const default_capnp_src = "/home/passchaos/Work/capnproto";

fn envAlloc(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return std.testing.environ.getAlloc(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableMissing => null,
        else => return err,
    };
}

pub fn testdataDir(allocator: std.mem.Allocator) ![]u8 {
    if (try envAlloc(allocator, "CPZ_CAPNP_TESTDATA")) |path| return path;
    if (try envAlloc(allocator, "CPZ_CAPNP_SRC")) |src| {
        defer allocator.free(src);
        return std.fs.path.join(allocator, &.{ src, "c++", "src", "capnp", "testdata" });
    }
    return std.fs.path.join(allocator, &.{ default_capnp_src, "c++", "src", "capnp", "testdata" });
}

pub fn rpcSchemaPath(allocator: std.mem.Allocator) ![]u8 {
    if (try envAlloc(allocator, "CPZ_RPC_SCHEMA")) |path| return path;
    if (try envAlloc(allocator, "CPZ_CAPNP_SRC")) |src| {
        defer allocator.free(src);
        return std.fs.path.join(allocator, &.{ src, "c++", "src", "capnp", "rpc.capnp" });
    }
    return std.fs.path.join(allocator, &.{ default_capnp_src, "c++", "src", "capnp", "rpc.capnp" });
}
