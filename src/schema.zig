const std = @import("std");

pub const Error = error{
    UnexpectedToken,
    InvalidToken,
    InvalidOrdinal,
    UnsupportedType,
} || std.mem.Allocator.Error || std.fmt.ParseIntError;

pub const Type = union(enum) {
    void,
    bool,
    int8,
    int16,
    int32,
    int64,
    uint8,
    uint16,
    uint32,
    uint64,
    float32,
    float64,
    text,
    data,
    list: *Type,
    named: []const u8,

    pub fn deinit(self: *Type, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .list => |child| {
                child.deinit(allocator);
                allocator.destroy(child);
            },
            else => {},
        }
        self.* = undefined;
    }
};

pub const Field = struct {
    name: []const u8,
    ordinal: u32,
    ty: Type,
    default_literal: ?[]const u8 = null,

    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        self.* = undefined;
    }
};

pub const Struct = struct {
    name: []const u8,
    fields: []Field,

    pub fn deinit(self: *Struct, allocator: std.mem.Allocator) void {
        for (self.fields) |*field| field.deinit(allocator);
        allocator.free(self.fields);
        self.* = undefined;
    }
};

pub const EnumValue = struct {
    name: []const u8,
    ordinal: u16,
};

pub const EnumDecl = struct {
    name: []const u8,
    values: []EnumValue,

    pub fn deinit(self: *EnumDecl, allocator: std.mem.Allocator) void {
        allocator.free(self.values);
        self.* = undefined;
    }
};

pub const File = struct {
    id: ?u64,
    structs: []Struct,
    enums: []EnumDecl,

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        for (self.structs) |*s| s.deinit(allocator);
        allocator.free(self.structs);
        for (self.enums) |*e| e.deinit(allocator);
        allocator.free(self.enums);
        self.* = undefined;
    }
};

pub const LayoutError = Error || error{
    OrdinalCollision,
    UnsupportedInlineComposite,
};

pub const FieldSlot = union(enum) {
    void,
    data_bit: usize,
    data_byte: usize,
    pointer: usize,
};

pub const FieldLayout = struct {
    field: *const Field,
    slot: FieldSlot,
};

pub const StructLayout = struct {
    decl: *const Struct,
    data_words: u16,
    pointer_count: u16,
    fields: []FieldLayout,

    pub fn deinit(self: *StructLayout, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
        self.* = undefined;
    }
};

pub const LayoutFile = struct {
    structs: []StructLayout,

    pub fn deinit(self: *LayoutFile, allocator: std.mem.Allocator) void {
        for (self.structs) |*layout| layout.deinit(allocator);
        allocator.free(self.structs);
        self.* = undefined;
    }
};

const TokenTag = enum {
    identifier,
    at,
    colon,
    semicolon,
    l_brace,
    r_brace,
    l_paren,
    r_paren,
    l_bracket,
    r_bracket,
    equal,
    dollar,
    dot,
    comma,
    integer,
    string,
    eof,
};

const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
};

const Lexer = struct {
    source: []const u8,
    index: usize = 0,

    fn next(self: *Lexer) Error!Token {
        try self.skipSpaceAndComments();
        if (self.index >= self.source.len) return .{ .tag = .eof, .lexeme = "" };
        const start = self.index;
        const c = self.source[self.index];
        self.index += 1;
        return switch (c) {
            '@' => .{ .tag = .at, .lexeme = self.source[start..self.index] },
            ':' => .{ .tag = .colon, .lexeme = self.source[start..self.index] },
            ';' => .{ .tag = .semicolon, .lexeme = self.source[start..self.index] },
            '{' => .{ .tag = .l_brace, .lexeme = self.source[start..self.index] },
            '}' => .{ .tag = .r_brace, .lexeme = self.source[start..self.index] },
            '(' => .{ .tag = .l_paren, .lexeme = self.source[start..self.index] },
            ')' => .{ .tag = .r_paren, .lexeme = self.source[start..self.index] },
            '[' => .{ .tag = .l_bracket, .lexeme = self.source[start..self.index] },
            ']' => .{ .tag = .r_bracket, .lexeme = self.source[start..self.index] },
            '=' => .{ .tag = .equal, .lexeme = self.source[start..self.index] },
            '$' => .{ .tag = .dollar, .lexeme = self.source[start..self.index] },
            '.' => .{ .tag = .dot, .lexeme = self.source[start..self.index] },
            ',' => .{ .tag = .comma, .lexeme = self.source[start..self.index] },
            '"' => blk: {
                const content_start = self.index;
                while (self.index < self.source.len) {
                    switch (self.source[self.index]) {
                        '"' => {
                            const content = self.source[content_start..self.index];
                            self.index += 1;
                            break :blk .{ .tag = .string, .lexeme = content };
                        },
                        '\\' => {
                            self.index += 1;
                            if (self.index >= self.source.len) return error.InvalidToken;
                            self.index += 1;
                        },
                        '\n', '\r' => return error.InvalidToken,
                        else => self.index += 1,
                    }
                }
                return error.InvalidToken;
            },
            '0'...'9' => blk: {
                while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
            },
            '-' => blk: {
                if (self.index >= self.source.len or !std.ascii.isDigit(self.source[self.index])) return error.InvalidToken;
                while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
            },
            'A'...'Z', 'a'...'z', '_' => blk: {
                while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index] };
            },
            else => error.InvalidToken,
        };
    }

    fn skipSpaceAndComments(self: *Lexer) Error!void {
        while (self.index < self.source.len) {
            switch (self.source[self.index]) {
                ' ', '\t', '\r', '\n' => self.index += 1,
                '#' => {
                    while (self.index < self.source.len and self.source[self.index] != '\n') self.index += 1;
                },
                '/' => {
                    if (self.index + 1 < self.source.len and self.source[self.index + 1] == '/') {
                        self.index += 2;
                        while (self.index < self.source.len and self.source[self.index] != '\n') self.index += 1;
                    } else return;
                },
                else => return,
            }
        }
    }
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    lookahead: Token,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Error!Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .lookahead = first };
    }

    pub fn parse(self: *Parser) Error!File {
        var structs = std.ArrayList(Struct).empty;
        errdefer {
            for (structs.items) |*s| s.deinit(self.allocator);
            structs.deinit(self.allocator);
        }
        var enums = std.ArrayList(EnumDecl).empty;
        errdefer {
            for (enums.items) |*e| e.deinit(self.allocator);
            enums.deinit(self.allocator);
        }
        var file_id: ?u64 = null;

        while (self.lookahead.tag != .eof) {
            if (self.eatKeyword("struct")) {
                try structs.append(self.allocator, try self.parseStruct());
            } else if (self.eatKeyword("enum")) {
                try enums.append(self.allocator, try self.parseEnum());
            } else if (self.eatKeyword("using") or self.eatKeyword("const")) {
                try self.skipUntilSemicolon();
            } else if (self.lookahead.tag == .at) {
                file_id = try self.parseFileId();
            } else {
                return error.UnexpectedToken;
            }
        }

        return .{
            .id = file_id,
            .structs = try structs.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
        };
    }

    fn parseFileId(self: *Parser) Error!u64 {
        try self.expect(.at);
        const id = try self.expectInteger();
        try self.expect(.semicolon);
        return id;
    }

    fn parseStruct(self: *Parser) Error!Struct {
        const name = try self.expectIdentifier();
        try self.skipUntil(.l_brace);
        try self.expect(.l_brace);

        var fields = std.ArrayList(Field).empty;
        errdefer {
            for (fields.items) |*field| field.deinit(self.allocator);
            fields.deinit(self.allocator);
        }

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            try fields.append(self.allocator, try self.parseField());
        }
        try self.expect(.r_brace);
        return .{ .name = name, .fields = try fields.toOwnedSlice(self.allocator) };
    }

    fn parseEnum(self: *Parser) Error!EnumDecl {
        const name = try self.expectIdentifier();
        try self.skipUntil(.l_brace);
        try self.expect(.l_brace);

        var values = std.ArrayList(EnumValue).empty;
        errdefer values.deinit(self.allocator);

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const value_name = try self.expectIdentifier();
            try self.expect(.at);
            const ordinal_u64 = try self.expectInteger();
            if (ordinal_u64 > std.math.maxInt(u16)) return error.InvalidOrdinal;
            try self.skipUntilSemicolon();
            try values.append(self.allocator, .{ .name = value_name, .ordinal = @intCast(ordinal_u64) });
        }
        try self.expect(.r_brace);
        return .{ .name = name, .values = try values.toOwnedSlice(self.allocator) };
    }

    fn parseField(self: *Parser) Error!Field {
        const name = try self.expectIdentifier();
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        try self.expect(.colon);
        const ty = try self.parseType();
        const default_literal = if (self.lookahead.tag == .equal) blk: {
            try self.expect(.equal);
            break :blk try self.expectDefaultLiteral();
        } else null;
        try self.skipUntilSemicolon();
        return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = ty, .default_literal = default_literal };
    }

    fn parseType(self: *Parser) Error!Type {
        const name = try self.expectIdentifier();
        if (std.mem.eql(u8, name, "List")) {
            try self.expect(.l_paren);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            try self.expect(.r_paren);
            return .{ .list = child };
        }
        return scalarOrNamed(name);
    }

    fn scalarOrNamed(name: []const u8) Type {
        if (std.mem.eql(u8, name, "Void")) return .void;
        if (std.mem.eql(u8, name, "Bool")) return .bool;
        if (std.mem.eql(u8, name, "Int8")) return .int8;
        if (std.mem.eql(u8, name, "Int16")) return .int16;
        if (std.mem.eql(u8, name, "Int32")) return .int32;
        if (std.mem.eql(u8, name, "Int64")) return .int64;
        if (std.mem.eql(u8, name, "UInt8")) return .uint8;
        if (std.mem.eql(u8, name, "UInt16")) return .uint16;
        if (std.mem.eql(u8, name, "UInt32")) return .uint32;
        if (std.mem.eql(u8, name, "UInt64")) return .uint64;
        if (std.mem.eql(u8, name, "Float32")) return .float32;
        if (std.mem.eql(u8, name, "Float64")) return .float64;
        if (std.mem.eql(u8, name, "Text")) return .text;
        if (std.mem.eql(u8, name, "Data")) return .data;
        return .{ .named = name };
    }

    fn eatKeyword(self: *Parser, keyword: []const u8) bool {
        if (self.lookahead.tag == .identifier and std.mem.eql(u8, self.lookahead.lexeme, keyword)) {
            self.advance() catch unreachable;
            return true;
        }
        return false;
    }

    fn expectIdentifier(self: *Parser) Error![]const u8 {
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        const value = self.lookahead.lexeme;
        try self.advance();
        return value;
    }

    fn expectInteger(self: *Parser) Error!u64 {
        if (self.lookahead.tag != .integer) return error.UnexpectedToken;
        const value = try parseInteger(self.lookahead.lexeme);
        try self.advance();
        return value;
    }

    fn expectDefaultLiteral(self: *Parser) Error![]const u8 {
        switch (self.lookahead.tag) {
            .identifier, .integer, .string => {
                const value = self.lookahead.lexeme;
                try self.advance();
                return value;
            },
            else => return error.UnexpectedToken,
        }
    }

    fn skipUntilSemicolon(self: *Parser) Error!void {
        try self.skipUntil(.semicolon);
        try self.expect(.semicolon);
    }

    fn skipUntil(self: *Parser, tag: TokenTag) Error!void {
        var depth: usize = 0;
        while (self.lookahead.tag != tag or depth != 0) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            switch (self.lookahead.tag) {
                .l_paren, .l_bracket => depth += 1,
                .r_paren, .r_bracket => {
                    if (depth > 0) depth -= 1;
                },
                else => {},
            }
            try self.advance();
        }
    }

    fn expect(self: *Parser, tag: TokenTag) Error!void {
        if (self.lookahead.tag != tag) return error.UnexpectedToken;
        try self.advance();
    }

    fn advance(self: *Parser) Error!void {
        self.lookahead = try self.lexer.next();
    }
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8) Error!File {
    var parser = try Parser.init(allocator, source);
    return parser.parse();
}

pub fn planLayouts(allocator: std.mem.Allocator, file: *const File) LayoutError!LayoutFile {
    var layouts = std.ArrayList(StructLayout).empty;
    errdefer {
        for (layouts.items) |*layout| layout.deinit(allocator);
        layouts.deinit(allocator);
    }

    for (file.structs) |*decl| {
        try layouts.append(allocator, try planStructLayout(allocator, file, decl));
    }
    return .{ .structs = try layouts.toOwnedSlice(allocator) };
}

pub fn planStructLayout(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!StructLayout {
    var fields = try std.ArrayList(FieldLayout).initCapacity(allocator, decl.fields.len);
    errdefer fields.deinit(allocator);

    var occupied_ordinals = std.AutoHashMap(u32, void).init(allocator);
    defer occupied_ordinals.deinit();

    var next_bit: usize = 0;
    var next_pointer: usize = 0;

    for (decl.fields) |*field| {
        const entry = try occupied_ordinals.getOrPut(field.ordinal);
        if (entry.found_existing) return error.OrdinalCollision;

        const slot: FieldSlot = switch (try classify(file, field.ty)) {
            .void => .void,
            .data => |bits| blk: {
                const aligned = alignForward(usize, next_bit, bits);
                next_bit = aligned + bits;
                if (bits == 1) break :blk .{ .data_bit = aligned };
                break :blk .{ .data_byte = aligned / 8 };
            },
            .pointer => blk: {
                const index = next_pointer;
                next_pointer += 1;
                break :blk .{ .pointer = index };
            },
        };
        fields.appendAssumeCapacity(.{ .field = field, .slot = slot });
    }

    if (next_bit > @as(usize, std.math.maxInt(u16)) * 64) return error.InvalidOrdinal;
    if (next_pointer > std.math.maxInt(u16)) return error.InvalidOrdinal;

    return .{
        .decl = decl,
        .data_words = @intCast((next_bit + 63) / 64),
        .pointer_count = @intCast(next_pointer),
        .fields = try fields.toOwnedSlice(allocator),
    };
}

const TypeClass = union(enum) {
    void,
    data: usize,
    pointer,
};

fn classify(file: *const File, ty: Type) LayoutError!TypeClass {
    return switch (ty) {
        .void => .void,
        .bool => .{ .data = 1 },
        .int8, .uint8 => .{ .data = 8 },
        .int16, .uint16 => .{ .data = 16 },
        .int32, .uint32, .float32 => .{ .data = 32 },
        .int64, .uint64, .float64 => .{ .data = 64 },
        .text, .data, .list => .pointer,
        .named => |name| if (findEnum(file, name) != null) .{ .data = 16 } else .pointer,
    };
}

fn findEnum(file: *const File, name: []const u8) ?*const EnumDecl {
    for (file.enums) |*decl| {
        if (std.mem.eql(u8, decl.name, name)) return decl;
    }
    return null;
}

fn alignForward(comptime T: type, value: T, alignment: T) T {
    if (alignment == 0) return value;
    return ((value + alignment - 1) / alignment) * alignment;
}

fn parseInteger(text: []const u8) (std.fmt.ParseIntError || error{InvalidToken})!u64 {
    if (text.len > 2 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X')) {
        return std.fmt.parseInt(u64, text[2..], 16);
    }
    return std.fmt.parseInt(u64, text, 10);
}

fn isIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

fn isNumberContinue(c: u8) bool {
    return switch (c) {
        '0'...'9', 'a'...'f', 'A'...'F', 'x', 'X', '.' => true,
        else => false,
    };
}

test "schema parser handles structs, file ids, lists, comments" {
    const source =
        \\@0xabcdef;
        \\# a comment
        \\struct Person {
        \\  id @0 :UInt32 = 123;
        \\  name @1 :Text;
        \\  scores @2 :List(Int32);
        \\  bestFriend @3 :Person;
        \\}
    ;

    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 0xabcdef), file.id);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Person", file.structs[0].name);
    try std.testing.expectEqual(@as(usize, 4), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("id", file.structs[0].fields[0].name);
    try std.testing.expectEqual(@as(u32, 0), file.structs[0].fields[0].ordinal);
    try std.testing.expectEqual(Type.uint32, file.structs[0].fields[0].ty);
    try std.testing.expectEqualStrings("123", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqual(Type.text, file.structs[0].fields[1].ty);
    try std.testing.expect(file.structs[0].fields[2].ty == .list);
    try std.testing.expectEqual(Type.int32, file.structs[0].fields[2].ty.list.*);
    try std.testing.expect(file.structs[0].fields[3].ty == .named);
    try std.testing.expectEqualStrings("Person", file.structs[0].fields[3].ty.named);
}

test "schema parser rejects invalid syntax" {
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "struct Bad { field @0 UInt32; }"));
    try std.testing.expectError(error.InvalidToken, parse(std.testing.allocator, "@!;"));
}

test "schema parser skips common top-level using and const declarations" {
    const source =
        \\using Go = import "go.capnp";
        \\const defaultName :Text = "Ada";
        \\struct Person {
        \\  name @0 :Text = "Ada";
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Person", file.structs[0].name);
    try std.testing.expectEqualStrings("Ada", file.structs[0].fields[0].default_literal.?);
}

test "schema parser tolerates imports and annotations" {
    const source =
        \\using Cxx = import "/capnp/c++.capnp".Cpp;
        \\enum Status {
        \\  ok @0 $Cxx.name("OK");
        \\  bad @1;
        \\}
        \\struct Task $Cxx.name("Task") {
        \\  id @0 :UInt64 $Cxx.name("id");
        \\  status @1 :Status = ok $Cxx.name("status");
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.enums.len);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Task", file.structs[0].name);
    try std.testing.expectEqualStrings("ok", file.structs[0].fields[1].default_literal.?);
}

test "schema layout planner assigns data and pointer slots" {
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
}

test "schema layout planner rejects duplicate ordinals" {
    var file = try parse(std.testing.allocator,
        \\struct Bad {
        \\  a @0 :UInt32;
        \\  b @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectError(error.OrdinalCollision, planLayouts(std.testing.allocator, &file));
}

pub fn generateZig(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile) LayoutError![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator,
        \\const cpz = @import("cpz");
        \\
        \\
    );
    for (file.enums) |*decl| {
        try emitEnum(allocator, &out, decl);
    }
    for (layouts.structs) |*layout| {
        try emitStruct(allocator, &out, file, layout);
    }
    return out.toOwnedSlice(allocator);
}

fn emitEnum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), decl: *const EnumDecl) LayoutError!void {
    try appendFmt(allocator, out,
        \\pub const {s} = enum(u16) {{
        \\
    , .{decl.name});
    for (decl.values) |value| {
        try appendFmt(allocator, out,
            \\    {s} = {},
            \\
        , .{ value.name, value.ordinal });
    }
    try appendFmt(allocator, out,
        \\}};
        \\
        \\
    , .{});
}

fn emitStruct(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    try appendFmt(allocator, out,
        \\pub const {s} = struct {{
        \\    pub const size: cpz.StructSize = .{{ .data_words = {}, .pointer_count = {} }};
        \\
        \\    reader: cpz.StructReader,
        \\
        \\    pub fn initRoot(builder: *cpz.MessageBuilder) !cpz.StructBuilder {{
        \\        return builder.initRoot(size);
        \\    }}
        \\
        \\    pub fn fromReader(reader: cpz.StructReader) {s} {{
        \\        return .{{ .reader = reader }};
        \\    }}
        \\
    , .{ layout.decl.name, layout.data_words, layout.pointer_count, layout.decl.name });

    for (layout.fields) |field_layout| {
        try emitFieldGetter(allocator, out, file, layout.decl.name, field_layout);
    }
    for (layout.fields) |field_layout| {
        if (field_layout.field.ty == .list) {
            try emitListWrapper(allocator, out, file, layout.decl.name, field_layout.field);
        }
    }

    try appendFmt(allocator, out,
        \\
        \\    pub fn initRootTyped(message: *cpz.MessageBuilder) !Builder {{
        \\        return Builder.fromBuilder(try message.initRoot(size));
        \\    }}
        \\
        \\    pub const Builder = struct {{
        \\        builder: cpz.StructBuilder,
        \\
        \\        pub fn fromBuilder(builder: cpz.StructBuilder) Builder {{
        \\            return .{{ .builder = builder }};
        \\        }}
        \\
    , .{});

    for (layout.fields) |field_layout| {
        try emitFieldBuilderMethod(allocator, out, file, field_layout);
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    try appendFmt(allocator, out, "}};\n\n", .{});
}

fn emitFieldGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    switch (field_layout.slot) {
        .void => try appendFmt(allocator, out,
            \\    pub fn {s}(self: {s}) void {{
            \\        _ = self;
            \\    }}
            \\
        , .{ field.name, "@This()" }),
        .data_bit => |bit| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) bool {{
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field.name, bit, try defaultBoolLiteral(field) }),
        .data_byte => |byte| try emitDataGetter(allocator, out, file, field, byte),
        .pointer => |index| try emitPointerGetter(allocator, out, file, owner_name, field, index),
    }
}

fn emitDataGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field: *const Field, byte: usize) LayoutError!void {
    switch (field.ty) {
        .int8 => try scalarGetter(allocator, out, field.name, "i8", "getInt8", byte, defaultScalarLiteral(field)),
        .int16 => try scalarGetter(allocator, out, field.name, "i16", "getInt16", byte, defaultScalarLiteral(field)),
        .int32 => try scalarGetter(allocator, out, field.name, "i32", "getInt32", byte, defaultScalarLiteral(field)),
        .int64 => try scalarGetter(allocator, out, field.name, "i64", "getInt64", byte, defaultScalarLiteral(field)),
        .uint8 => try scalarGetter(allocator, out, field.name, "u8", "getUInt8", byte, defaultScalarLiteral(field)),
        .uint16 => try scalarGetter(allocator, out, field.name, "u16", "getUInt16", byte, defaultScalarLiteral(field)),
        .uint32 => try scalarGetter(allocator, out, field.name, "u32", "getUInt32", byte, defaultScalarLiteral(field)),
        .uint64 => try scalarGetter(allocator, out, field.name, "u64", "getUInt64", byte, defaultScalarLiteral(field)),
        .float32 => try scalarGetter(allocator, out, field.name, "f32", "getFloat32", byte, defaultScalarLiteral(field)),
        .float64 => try scalarGetter(allocator, out, field.name, "f64", "getFloat64", byte, defaultScalarLiteral(field)),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) {s} {{
                \\        return @enumFromInt(self.reader.getUInt16({}, {}));
                \\    }}
                \\
            , .{ field.name, type_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, method: []const u8, byte: usize, default: []const u8) !void {
    try appendFmt(allocator, out,
        \\    pub fn {s}(self: @This()) {s} {{
        \\        return self.reader.{s}({}, {s});
        \\    }}
        \\
    , .{ name, zig_type, method, byte, default });
}

fn emitPointerGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    switch (field.ty) {
        .text => try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) ![]const u8 {{
            \\        return self.reader.getPointerField({}).getText();
            \\    }}
            \\
        , .{ field.name, index }),
        .data => try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) ![]const u8 {{
            \\        return self.reader.getPointerField({}).getData();
            \\    }}
            \\
        , .{ field.name, index }),
        .list => |child| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !{s}_{s}_List {{
            \\        return .{{ .list = try self.reader.getPointerField({}).getList({s}) }};
            \\    }}
            \\
        , .{ field.name, owner_name, field.name, index, try listElementSizeLiteral(file, child.*) }),
        .named => |type_name| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !{s} {{
            \\        return {s}.fromReader(try self.reader.getPointerField({}).getStruct(null));
            \\    }}
            \\
        , .{ field.name, type_name, type_name, index }),
        else => return error.UnsupportedType,
    }
}

fn emitListWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field: *const Field) LayoutError!void {
    const child = field.ty.list.*;
    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_List = struct {{
        \\        list: cpz.ListReader,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
    , .{ owner_name, field.name });

    switch (child) {
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) bool {{
            \\            return self.list.getBool(index);
            \\        }}
            \\
        , .{}),
        .uint8 => try listScalarGetter(allocator, out, "u8", "getUInt8"),
        .uint16 => try listScalarGetter(allocator, out, "u16", "getUInt16"),
        .uint32 => try listScalarGetter(allocator, out, "u32", "getUInt32"),
        .uint64 => try listScalarGetter(allocator, out, "u64", "getUInt64"),
        .int8 => try listScalarGetter(allocator, out, "i8", "getInt8"),
        .int16 => try listScalarGetter(allocator, out, "i16", "getInt16"),
        .int32 => try listScalarGetter(allocator, out, "i32", "getInt32"),
        .int64 => try listScalarGetter(allocator, out, "i64", "getInt64"),
        .float32 => try listScalarGetter(allocator, out, "f32", "getFloat32"),
        .float64 => try listScalarGetter(allocator, out, "f64", "getFloat64"),
        .text => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getText();
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
        , .{}),
        .named => |type_name| if (findEnum(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) {s} {{
                \\            return @enumFromInt(self.list.getUInt16(index));
                \\        }}
                \\
            , .{type_name});
        } else {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return {s}.fromReader(try self.list.getStructElement(index));
                \\        }}
                \\
            , .{ type_name, type_name });
        },
        .void, .list => {},
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});
}

fn listScalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), zig_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get(self: @This(), index: usize) {s} {{
        \\            return self.list.{s}(index);
        \\        }}
        \\
    , .{ zig_type, method });
}

fn emitFieldBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    switch (field_layout.slot) {
        .void => try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder) void {{
            \\            _ = self;
            \\        }}
            \\
        , .{field.name}),
        .data_bit => |bit| try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder, value: bool) !void {{
            \\            return self.builder.setBool({}, value, {s});
            \\        }}
            \\
        , .{ field.name, bit, try defaultBoolLiteral(field) }),
        .data_byte => |byte| try emitDataBuilderMethod(allocator, out, file, field, byte),
        .pointer => |index| try emitPointerBuilderMethod(allocator, out, file, field, index),
    }
}

fn emitDataBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field: *const Field, byte: usize) LayoutError!void {
    switch (field.ty) {
        .int8 => try scalarSetter(allocator, out, field.name, "i8", "setInt8", byte, defaultScalarLiteral(field)),
        .int16 => try scalarSetter(allocator, out, field.name, "i16", "setInt16", byte, defaultScalarLiteral(field)),
        .int32 => try scalarSetter(allocator, out, field.name, "i32", "setInt32", byte, defaultScalarLiteral(field)),
        .int64 => try scalarSetter(allocator, out, field.name, "i64", "setInt64", byte, defaultScalarLiteral(field)),
        .uint8 => try scalarSetter(allocator, out, field.name, "u8", "setUInt8", byte, defaultScalarLiteral(field)),
        .uint16 => try scalarSetter(allocator, out, field.name, "u16", "setUInt16", byte, defaultScalarLiteral(field)),
        .uint32 => try scalarSetter(allocator, out, field.name, "u32", "setUInt32", byte, defaultScalarLiteral(field)),
        .uint64 => try scalarSetter(allocator, out, field.name, "u64", "setUInt64", byte, defaultScalarLiteral(field)),
        .float32 => try scalarSetter(allocator, out, field.name, "f32", "setFloat32", byte, defaultScalarLiteral(field)),
        .float64 => try scalarSetter(allocator, out, field.name, "f64", "setFloat64", byte, defaultScalarLiteral(field)),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, value: {s}) !void {{
                \\            return self.builder.setUInt16({}, @intFromEnum(value), {});
                \\        }}
                \\
            , .{ field.name, type_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, method: []const u8, byte: usize, default: []const u8) !void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, value: {s}) !void {{
        \\            return self.builder.{s}({}, value, {s});
        \\        }}
        \\
    , .{ name, zig_type, method, byte, default });
}

fn emitPointerBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field: *const Field, index: usize) LayoutError!void {
    switch (field.ty) {
        .text => try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder, value: []const u8) !void {{
            \\            return self.builder.setText({}, value);
            \\        }}
            \\
        , .{ field.name, index }),
        .data => try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder, value: []const u8) !void {{
            \\            return self.builder.setData({}, value);
            \\        }}
            \\
        , .{ field.name, index }),
        .list => |child| if (isStructListElement(file, child.*)) |type_name| {
            try appendFmt(allocator, out,
                \\        pub fn init_{s}(self: Builder, count: usize) !cpz.ListBuilder {{
                \\            return (try self.builder.getPointerField({})).initStructList(count, {s}.size);
                \\        }}
                \\
            , .{ field.name, index, type_name });
        } else try appendFmt(allocator, out,
            \\        pub fn init_{s}(self: Builder, count: usize) !cpz.ListBuilder {{
            \\            return (try self.builder.getPointerField({})).initList({s}, count);
            \\        }}
            \\
        , .{ field.name, index, try listElementSizeLiteral(file, child.*) }),
        .named => try appendFmt(allocator, out,
            \\        pub fn init_{s}(self: Builder, size: cpz.StructSize) !cpz.StructBuilder {{
            \\            return (try self.builder.getPointerField({})).initStruct(size);
            \\        }}
            \\
        , .{ field.name, index }),
        else => return error.UnsupportedType,
    }
}

fn listElementSizeLiteral(file: *const File, ty: Type) LayoutError![]const u8 {
    return switch (ty) {
        .void => ".void",
        .bool => ".bit",
        .int8, .uint8 => ".byte",
        .int16, .uint16 => ".two_bytes",
        .int32, .uint32, .float32 => ".four_bytes",
        .int64, .uint64, .float64 => ".eight_bytes",
        .text, .data, .list => ".pointer",
        .named => |name| if (findEnum(file, name) != null) ".two_bytes" else ".composite",
    };
}

fn isStructListElement(file: *const File, ty: Type) ?[]const u8 {
    return switch (ty) {
        .named => |name| if (findEnum(file, name) == null) name else null,
        else => null,
    };
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) std.mem.Allocator.Error!void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn defaultScalarLiteral(field: *const Field) []const u8 {
    return field.default_literal orelse "0";
}

fn defaultBoolLiteral(field: *const Field) LayoutError![]const u8 {
    const literal = field.default_literal orelse return "false";
    if (std.mem.eql(u8, literal, "true") or std.mem.eql(u8, literal, "false")) return literal;
    return error.InvalidToken;
}

fn enumDefaultOrdinal(decl: *const EnumDecl, literal: ?[]const u8) LayoutError!u16 {
    const name = literal orelse return 0;
    for (decl.values) |value| {
        if (std.mem.eql(u8, value.name, name)) return value.ordinal;
    }
    return error.InvalidToken;
}

test "schema code generator emits Zig accessor skeletons" {
    const source =
        \\struct Person {
        \\  id @0 :UInt32 = 42;
        \\  active @1 :Bool = true;
        \\  name @2 :Text;
        \\  friend @3 :Person;
        \\  scores @4 :List(UInt32);
        \\  children @5 :List(Person);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Person = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "data_words = 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pointer_count = 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn id(self: @This()) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getUInt32(0, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getBool(32, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getText()") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_scores_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_children_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return Person.fromReader(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(count, Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Builder = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_id(self: Builder, value: u32) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setUInt32(0, value, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setBool(32, value, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_name(self: Builder, value: []const u8) !void") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn color(self: @This()) Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getUInt16(0, 1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_color(self: Builder, value: Color) !void") != null);
}
