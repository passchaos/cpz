const std = @import("std");

/// Zig identifier escaping and keyword avoidance shared by the schema frontend
/// and code generator. Generated declarations and parser-level name-collision
/// checks must agree on the same canonical spelling.
pub fn zigIdentAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (raw.len == 0 or !isZigIdentStart(raw[0])) {
        try out.append(allocator, '_');
    }
    for (raw) |c| {
        try out.append(allocator, if (isZigIdentContinue(c)) c else '_');
    }
    if (isZigKeyword(out.items)) {
        try out.append(allocator, '_');
    }
    return out.toOwnedSlice(allocator);
}

pub fn zigNamesEqual(allocator: std.mem.Allocator, lhs_raw: []const u8, rhs_raw: []const u8) std.mem.Allocator.Error!bool {
    const lhs = try zigIdentAlloc(allocator, lhs_raw);
    defer allocator.free(lhs);
    const rhs = try zigIdentAlloc(allocator, rhs_raw);
    defer allocator.free(rhs);
    return std.mem.eql(u8, lhs, rhs);
}

pub fn isZigIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

pub fn isZigIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

pub fn isZigKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "addrspace", "align",     "allowzero",   "and",            "anyframe",       "anytype",      "asm",
        "async",     "await",     "break",       "callconv",       "catch",          "comptime",     "const",
        "continue",  "defer",     "else",        "enum",           "errdefer",       "error",        "export",
        "extern",    "fn",        "for",         "if",             "inline",         "linksection",  "noalias",
        "noinline",  "nosuspend", "opaque",      "or",             "orelse",         "packed",       "pub",
        "resume",    "return",    "struct",      "suspend",        "switch",         "test",         "threadlocal",
        "try",       "union",     "unreachable", "usingnamespace", "var",            "volatile",     "while",

        // Primitive type names and literal spellings are not all Zig keywords,
        // but declarations using them still shadow builtins or produce invalid
        // generated code in common schemas (for example json.Value.null).
        "bool",      "c_int",     "c_long",      "c_longdouble",   "c_longlong",     "c_char",       "c_short",
        "c_uint",    "c_ulong",   "c_ulonglong", "c_ushort",       "comptime_float", "comptime_int", "f16",
        "f32",       "f64",       "f80",         "f128",           "false",          "isize",        "null",
        "true",      "type",      "usize",       "void",           "anyopaque",      "i0",           "i1",
        "i2",        "i3",        "i4",          "i5",             "i6",             "i7",           "i8",
        "i16",       "i32",       "i64",         "i128",           "u0",             "u1",           "u2",
        "u3",        "u4",        "u5",          "u6",             "u7",             "u8",           "u16",
        "u32",       "u64",       "u128",        "reader",         "size",           "new_value",    "orphan",
        "validate",  "totalSize", "Orphan",      "Builder",        "fromReader",     "cpz",          "std",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
    }
    return false;
}
