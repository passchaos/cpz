const std = @import("std");

pub const Error = error{
    UnexpectedToken,
    InvalidToken,
    InvalidOrdinal,
    NameCollision,
    OrdinalCollision,
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
    optional: *Type,
    named: []const u8,

    pub fn deinit(self: *Type, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .list, .optional => |child| {
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
    question,
    arrow,
    integer,
    string,
    eof,
};

const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    start: usize = 0,
    end: usize = 0,
};

const Lexer = struct {
    source: []const u8,
    index: usize = 0,

    fn next(self: *Lexer) Error!Token {
        try self.skipSpaceAndComments();
        if (self.index >= self.source.len) return .{ .tag = .eof, .lexeme = "", .start = self.index, .end = self.index };
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
            '?' => .{ .tag = .question, .lexeme = self.source[start..self.index] },
            '-' => blk: {
                if (self.index < self.source.len and self.source[self.index] == '>') {
                    self.index += 1;
                    break :blk .{ .tag = .arrow, .lexeme = self.source[start..self.index] };
                }
                if (self.index >= self.source.len or !std.ascii.isDigit(self.source[self.index])) return error.InvalidToken;
                while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
            },
            '+' => blk: {
                if (self.index >= self.source.len or !std.ascii.isDigit(self.source[self.index])) return error.InvalidToken;
                while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
            },
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
            'A'...'Z', 'a'...'z', '_' => blk: {
                while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index], .start = start, .end = self.index };
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
        var decl_names = std.StringHashMap(void).init(self.allocator);
        defer decl_names.deinit();
        var file_id: ?u64 = null;

        while (self.lookahead.tag != .eof) {
            if (self.eatKeyword("struct")) {
                var decl = try self.parseStruct();
                const entry = try decl_names.getOrPut(decl.name);
                if (entry.found_existing) {
                    decl.deinit(self.allocator);
                    return error.NameCollision;
                }
                try structs.append(self.allocator, decl);
            } else if (self.eatKeyword("enum")) {
                var decl = try self.parseEnum();
                const entry = try decl_names.getOrPut(decl.name);
                if (entry.found_existing) {
                    decl.deinit(self.allocator);
                    return error.NameCollision;
                }
                try enums.append(self.allocator, decl);
            } else if (self.eatKeyword("interface")) {
                try self.skipBracedDeclaration();
            } else if (self.eatKeyword("using") or self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
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
        var field_names = std.StringHashMap(void).init(self.allocator);
        defer field_names.deinit();

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (self.isKeyword("union") and (try self.peekNext()).tag == .l_brace) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            var field = try self.parseField();
            const entry = try field_names.getOrPut(field.name);
            if (entry.found_existing) {
                field.deinit(self.allocator);
                return error.NameCollision;
            }
            try fields.append(self.allocator, field);
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
        var occupied_ordinals = std.AutoHashMap(u16, void).init(self.allocator);
        defer occupied_ordinals.deinit();
        var value_names = std.StringHashMap(void).init(self.allocator);
        defer value_names.deinit();

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const value_name = try self.expectIdentifier();
            const name_entry = try value_names.getOrPut(value_name);
            if (name_entry.found_existing) return error.NameCollision;
            try self.expect(.at);
            const ordinal_u64 = try self.expectInteger();
            if (ordinal_u64 > std.math.maxInt(u16)) return error.InvalidOrdinal;
            const ordinal: u16 = @intCast(ordinal_u64);
            const entry = try occupied_ordinals.getOrPut(ordinal);
            if (entry.found_existing) return error.OrdinalCollision;
            try self.skipUntilSemicolon();
            try values.append(self.allocator, .{ .name = value_name, .ordinal = ordinal });
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
        if (isGroupType(ty) and self.lookahead.tag == .l_brace) {
            try self.skipCurrentBracedBody();
            return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = .void };
        }
        const default_literal = if (self.lookahead.tag == .equal) blk: {
            try self.expect(.equal);
            break :blk try self.expectDefaultLiteral();
        } else null;
        try self.skipUntilSemicolon();
        return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = ty, .default_literal = default_literal };
    }

    fn parseType(self: *Parser) Error!Type {
        if (self.lookahead.tag == .question) {
            try self.expect(.question);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            return .{ .optional = child };
        }
        const first = self.lookahead;
        const name = try self.expectIdentifier();
        if (std.mem.eql(u8, name, "List")) {
            try self.expect(.l_paren);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            try self.expect(.r_paren);
            return .{ .list = child };
        }
        if (std.mem.endsWith(u8, name, "List") and name.len > "List".len) {
            const base_name = name[0 .. name.len - "List".len];
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = scalarOrNamed(base_name);
            return .{ .list = child };
        }
        var end = first.end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
        }
        if (end != first.end) return .{ .named = self.lexer.source[first.start..end] };
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
        if (self.isKeyword(keyword)) {
            self.advance() catch unreachable;
            return true;
        }
        return false;
    }

    fn isKeyword(self: *const Parser, keyword: []const u8) bool {
        return self.lookahead.tag == .identifier and std.mem.eql(u8, self.lookahead.lexeme, keyword);
    }

    fn peekNext(self: *const Parser) Error!Token {
        var lexer = self.lexer;
        return lexer.next();
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
            .identifier => {
                const first = self.lookahead;
                const value = self.lookahead.lexeme;
                try self.advance();
                var end = first.end;
                while (self.lookahead.tag == .dot) {
                    try self.expect(.dot);
                    const part = self.lookahead;
                    _ = try self.expectIdentifier();
                    end = part.end;
                }
                if (end != first.end) return self.lexer.source[first.start..end];
                return value;
            },
            .integer, .string => {
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

    fn skipBracedDeclaration(self: *Parser) Error!void {
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    fn skipCurrentBracedBody(self: *Parser) Error!void {
        try self.expect(.l_brace);
        var depth: usize = 1;
        while (depth != 0) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            switch (self.lookahead.tag) {
                .l_brace => depth += 1,
                .r_brace => depth -= 1,
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
    const fields = try allocator.alloc(FieldLayout, decl.fields.len);
    errdefer allocator.free(fields);

    var occupied_ordinals = std.AutoHashMap(u32, void).init(allocator);
    defer occupied_ordinals.deinit();
    var assigned = try allocator.alloc(bool, decl.fields.len);
    defer allocator.free(assigned);
    @memset(assigned, false);
    var data_ranges = std.ArrayList(BitRange).empty;
    defer data_ranges.deinit(allocator);

    var data_end_bit: usize = 0;
    var next_pointer: usize = 0;

    for (decl.fields) |*field| {
        const entry = try occupied_ordinals.getOrPut(field.ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }

    for (0..decl.fields.len) |_| {
        const field_index = nextOrdinalFieldIndex(decl.fields, assigned) orelse unreachable;
        assigned[field_index] = true;
        const field = &decl.fields[field_index];

        const slot: FieldSlot = switch (try classify(file, field.ty)) {
            .void => .void,
            .data => |bits| blk: {
                const start = try allocateDataBits(allocator, &data_ranges, bits);
                data_end_bit = @max(data_end_bit, start + bits);
                if (bits == 1) break :blk .{ .data_bit = start };
                break :blk .{ .data_byte = start / 8 };
            },
            .pointer => blk: {
                const index = next_pointer;
                next_pointer += 1;
                break :blk .{ .pointer = index };
            },
        };
        fields[field_index] = .{ .field = field, .slot = slot };
    }

    if (data_end_bit > @as(usize, std.math.maxInt(u16)) * 64) return error.InvalidOrdinal;
    if (next_pointer > std.math.maxInt(u16)) return error.InvalidOrdinal;

    return .{
        .decl = decl,
        .data_words = @intCast((data_end_bit + 63) / 64),
        .pointer_count = @intCast(next_pointer),
        .fields = fields,
    };
}

const BitRange = struct {
    start: usize,
    end: usize,
};

fn allocateDataBits(allocator: std.mem.Allocator, ranges: *std.ArrayList(BitRange), bits: usize) LayoutError!usize {
    var start: usize = 0;
    while (true) {
        start = alignForward(usize, start, bits);
        const end = std.math.add(usize, start, bits) catch return error.InvalidOrdinal;
        var advanced = false;
        for (ranges.items) |range| {
            if (rangesOverlap(start, end, range.start, range.end)) {
                start = range.end;
                advanced = true;
                break;
            }
        }
        if (!advanced) {
            try ranges.append(allocator, .{ .start = start, .end = end });
            return start;
        }
    }
}

fn rangesOverlap(a_start: usize, a_end: usize, b_start: usize, b_end: usize) bool {
    return a_start < b_end and b_start < a_end;
}

fn nextOrdinalFieldIndex(fields: []const Field, assigned: []const bool) ?usize {
    var best: ?usize = null;
    for (fields, 0..) |field, index| {
        if (assigned[index]) continue;
        if (best) |best_index| {
            if (field.ordinal < fields[best_index].ordinal) best = index;
        } else {
            best = index;
        }
    }
    return best;
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
        .optional => .pointer,
        .named => |name| if (findEnum(file, name) != null) .{ .data = 16 } else .pointer,
    };
}

fn findEnum(file: *const File, name: []const u8) ?*const EnumDecl {
    for (file.enums) |*decl| {
        if (std.mem.eql(u8, decl.name, name)) return decl;
    }
    return null;
}

fn isGroupType(ty: Type) bool {
    return switch (ty) {
        .named => |name| std.mem.eql(u8, name, "group"),
        else => false,
    };
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
        '0'...'9', 'a'...'f', 'A'...'F', 'x', 'X', '.', '+', '-' => true,
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

test "schema parser rejects duplicate enum ordinals" {
    try std.testing.expectError(error.OrdinalCollision, parse(std.testing.allocator,
        \\enum Bad {
        \\  a @0;
        \\  b @0;
        \\}
    ));
}

test "schema parser rejects duplicate enum value names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\enum Bad {
        \\  value @0;
        \\  value @1;
        \\}
    ));
}

test "schema parser rejects duplicate field names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Bad {
        \\  value @0 :UInt32;
        \\  value @1 :Text;
        \\}
    ));
}

test "schema parser rejects duplicate top-level declaration names" {
    try std.testing.expectError(error.NameCollision, parse(std.testing.allocator,
        \\struct Thing {
        \\  id @0 :UInt32;
        \\}
        \\enum Thing {
        \\  value @0;
        \\}
    ));
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

test "schema parser skips top-level annotations and interfaces" {
    const source =
        \\annotation deprecated @0xaaaa (field) :Text;
        \\$Cxx.namespace("example");
        \\interface Service {
        \\  call @0 (request :Text) -> (response :Text);
        \\}
        \\struct Payload {
        \\  id @0 :UInt32;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqualStrings("Payload", file.structs[0].name);
    try std.testing.expectEqual(@as(usize, 1), file.structs[0].fields.len);
}

test "schema parser accepts TypeList shorthand" {
    var file = try parse(std.testing.allocator,
        \\struct Lists {
        \\  ids @0 :UInt32List;
        \\  names @1 :TextList;
        \\  children @2 :ChildList;
        \\}
        \\struct Child {
        \\  id @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expect(file.structs[0].fields[0].ty == .list);
    try std.testing.expectEqual(Type.uint32, file.structs[0].fields[0].ty.list.*);
    try std.testing.expect(file.structs[0].fields[1].ty == .list);
    try std.testing.expectEqual(Type.text, file.structs[0].fields[1].ty.list.*);
    try std.testing.expect(file.structs[0].fields[2].ty == .list);
    try std.testing.expect(file.structs[0].fields[2].ty.list.* == .named);
    try std.testing.expectEqualStrings("Child", file.structs[0].fields[2].ty.list.*.named);
}

test "schema parser and codegen accept plus-prefixed numeric defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Numbers {
        \\  ratio @0 :Float32 = +1.5;
        \\  count @1 :Int32 = +7;
        \\  tiny @2 :Float64 = 1e-3;
        \\  huge @3 :Float64 = +2.5E+4;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("+1.5", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("+7", file.structs[0].fields[1].default_literal.?);
    try std.testing.expectEqualStrings("1e-3", file.structs[0].fields[2].default_literal.?);
    try std.testing.expectEqualStrings("+2.5E+4", file.structs[0].fields[3].default_literal.?);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(0, 1.5)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getInt32(4, 7)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(8, 1e-3)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(16, 2.5E+4)") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !Maybe.Builder") != null);
}

test "schema parser tolerates union and group blocks inside structs" {
    const source =
        \\struct Choice {
        \\  union {
        \\    name @0 :Text;
        \\    id @1 :UInt32;
        \\  }
        \\  metadata @2 :group {
        \\    created @3 :UInt64;
        \\  }
        \\  keep @4 :Text;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    // The union is skipped for now; the group is represented as a void
    // placeholder so ordinal accounting can remain deterministic until full
    // group lowering exists.
    try std.testing.expectEqual(@as(usize, 2), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("metadata", file.structs[0].fields[0].name);
    try std.testing.expectEqual(Type.void, file.structs[0].fields[0].ty);
    try std.testing.expectEqualStrings("keep", file.structs[0].fields[1].name);
}

test "schema parser tolerates nested declarations and dotted type names" {
    const source =
        \\struct Outer {
        \\  struct Inner {
        \\    value @0 :UInt32;
        \\  }
        \\  enum State {
        \\    ready @0;
        \\  }
        \\  child @0 :Outer.Inner;
        \\  state @1 :Outer.State;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqual(@as(usize, 2), file.structs[0].fields.len);
    try std.testing.expect(file.structs[0].fields[0].ty == .named);
    try std.testing.expectEqualStrings("Outer.Inner", file.structs[0].fields[0].ty.named);
    try std.testing.expect(file.structs[0].fields[1].ty == .named);
    try std.testing.expectEqualStrings("Outer.State", file.structs[0].fields[1].ty.named);
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

test "schema layout planner allocates slots by ordinal not declaration order" {
    var file = try parse(std.testing.allocator,
        \\struct OutOfOrder {
        \\  later @1 :UInt32;
        \\  first @0 :UInt32;
        \\  ptrLater @3 :Text;
        \\  ptrFirst @2 :Text;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const fields = layouts.structs[0].fields;
    try std.testing.expectEqualStrings("later", fields[0].field.name);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 4 }, fields[0].slot);
    try std.testing.expectEqualStrings("first", fields[1].field.name);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, fields[1].slot);
    try std.testing.expectEqualStrings("ptrLater", fields[2].field.name);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, fields[2].slot);
    try std.testing.expectEqualStrings("ptrFirst", fields[3].field.name);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, fields[3].slot);
}

test "schema layout planner reuses alignment padding holes" {
    var file = try parse(std.testing.allocator,
        \\struct Compact {
        \\  byte @0 :UInt8;
        \\  word @1 :UInt64;
        \\  small @2 :UInt16;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const layout = layouts.structs[0];
    try std.testing.expectEqual(@as(u16, 2), layout.data_words);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 0 }, layout.fields[0].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 8 }, layout.fields[1].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 2 }, layout.fields[2].slot);
}

pub const CodegenOptions = struct {
    runtime_import_name: []const u8 = "cpz",
    raw_schema_comment: ?[]const u8 = null,
};

pub fn generateZig(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile) LayoutError![]u8 {
    return generateZigWithOptions(allocator, file, layouts, .{});
}

pub fn generateZigWithOptions(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile, options: CodegenOptions) LayoutError![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (options.raw_schema_comment) |source| {
        try appendRawSchemaComment(allocator, &out, source);
    }
    try appendFmt(allocator, &out,
        \\const std = @import("std");
        \\const cpz = @import("{s}");
        \\
        \\
    , .{options.runtime_import_name});
    for (file.enums) |*decl| {
        try emitEnum(allocator, &out, decl);
    }
    for (layouts.structs) |*layout| {
        try emitStruct(allocator, &out, file, layout);
    }
    return out.toOwnedSlice(allocator);
}

fn appendRawSchemaComment(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8) std.mem.Allocator.Error!void {
    try out.appendSlice(allocator, "// cpz source schema begin\n");
    var start: usize = 0;
    while (start <= source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        try out.appendSlice(allocator, "// ");
        try out.appendSlice(allocator, source[start..end]);
        try out.append(allocator, '\n');
        if (end == source.len) break;
        start = end + 1;
    }
    try out.appendSlice(allocator, "// cpz source schema end\n\n");
}

fn emitEnum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), decl: *const EnumDecl) LayoutError!void {
    const enum_name = try zigIdentAlloc(allocator, decl.name);
    defer allocator.free(enum_name);
    try appendFmt(allocator, out,
        \\pub const {s} = enum(u16) {{
        \\
    , .{enum_name});
    for (decl.values) |value| {
        const value_name = try zigIdentAlloc(allocator, value.name);
        defer allocator.free(value_name);
        try appendFmt(allocator, out,
            \\    {s} = {},
            \\
        , .{ value_name, value.ordinal });
    }
    try appendFmt(allocator, out,
        \\}};
        \\
        \\
    , .{});
}

fn emitStruct(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout) LayoutError!void {
    const struct_name = try zigIdentAlloc(allocator, layout.decl.name);
    defer allocator.free(struct_name);
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
    , .{ struct_name, layout.data_words, layout.pointer_count, struct_name });

    for (layout.fields) |field_layout| {
        try emitFieldGetter(allocator, out, file, struct_name, field_layout);
    }
    for (layout.fields) |field_layout| {
        if (field_layout.field.ty == .list) {
            try emitListWrapper(allocator, out, file, struct_name, field_layout.field);
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
        try emitFieldBuilderMethod(allocator, out, file, struct_name, field_layout);
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    try appendFmt(allocator, out, "}};\n\n", .{});
}

fn emitFieldGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    switch (field_layout.slot) {
        .void => try appendFmt(allocator, out,
            \\    pub fn {s}(self: {s}) void {{
            \\        _ = self;
            \\    }}
            \\
        , .{ field_name, "@This()" }),
        .data_bit => |bit| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) bool {{
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field_name, bit, try defaultBoolLiteral(field) }),
        .data_byte => |byte| try emitDataGetter(allocator, out, file, field_name, field, byte),
        .pointer => |index| try emitPointerGetter(allocator, out, file, owner_name, field_name, field, index),
    }
}

fn emitDataGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    switch (field.ty) {
        .int8 => try scalarGetter(allocator, out, field_name, "i8", "getInt8", byte, defaultScalarLiteral(field)),
        .int16 => try scalarGetter(allocator, out, field_name, "i16", "getInt16", byte, defaultScalarLiteral(field)),
        .int32 => try scalarGetter(allocator, out, field_name, "i32", "getInt32", byte, defaultScalarLiteral(field)),
        .int64 => try scalarGetter(allocator, out, field_name, "i64", "getInt64", byte, defaultScalarLiteral(field)),
        .uint8 => try scalarGetter(allocator, out, field_name, "u8", "getUInt8", byte, defaultScalarLiteral(field)),
        .uint16 => try scalarGetter(allocator, out, field_name, "u16", "getUInt16", byte, defaultScalarLiteral(field)),
        .uint32 => try scalarGetter(allocator, out, field_name, "u32", "getUInt32", byte, defaultScalarLiteral(field)),
        .uint64 => try scalarGetter(allocator, out, field_name, "u64", "getUInt64", byte, defaultScalarLiteral(field)),
        .float32 => try scalarGetter(allocator, out, field_name, "f32", "getFloat32", byte, defaultScalarLiteral(field)),
        .float64 => try scalarGetter(allocator, out, field_name, "f64", "getFloat64", byte, defaultScalarLiteral(field)),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s} {{
                \\        return std.enums.fromInt({s}, self.reader.getUInt16({}, {})) orelse error.InvalidEnumValue;
                \\    }}
                \\
                \\    pub fn {s}_raw(self: @This()) u16 {{
                \\        return self.reader.getUInt16({}, {});
                \\    }}
                \\
            , .{ field_name, zig_type, zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
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

fn emitPointerGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    if (field.ty == .optional) {
        var optional_field = field.*;
        optional_field.ty = field.ty.optional.*;
        return emitPointerGetter(allocator, out, file, owner_name, field_name, &optional_field, index);
    }

    try appendFmt(allocator, out,
        \\    pub fn has_{s}(self: @This()) bool {{
        \\        return !self.reader.getPointerField({}).isNull();
        \\    }}
        \\
    , .{ field_name, index });

    switch (field.ty) {
        .text => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\    pub fn {s}(self: @This()) ![]const u8 {{
                    \\        return self.reader.getPointerField({}).getTextDefault({s});
                    \\    }}
                    \\
                , .{ field_name, index, literal });
            } else try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) ![]const u8 {{
                \\        return self.reader.getPointerField({}).getText();
                \\    }}
                \\
            , .{ field_name, index });
        },
        .data => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\    pub fn {s}(self: @This()) ![]const u8 {{
                    \\        return self.reader.getPointerField({}).getDataDefault({s});
                    \\    }}
                    \\
                , .{ field_name, index, literal });
            } else try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) ![]const u8 {{
                \\        return self.reader.getPointerField({}).getData();
                \\    }}
                \\
            , .{ field_name, index });
        },
        .list => |child| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !{s}_{s}_List {{
            \\        return .{{ .list = try self.reader.getPointerField({}).getList({s}) }};
            \\    }}
            \\
        , .{ field_name, owner_name, field_name, index, try listElementSizeLiteral(file, child.*) }),
        .named => |type_name| {
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s} {{
                \\        return {s}.fromReader(try self.reader.getPointerField({}).getStruct(null));
                \\    }}
                \\
            , .{ field_name, zig_type, zig_type, index });
        },
        else => return error.UnsupportedType,
    }
}

fn emitListWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field: *const Field) LayoutError!void {
    const child = field.ty.list.*;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_List = struct {{
        \\        list: cpz.ListReader,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
    , .{ owner_name, field_name });

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
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return std.enums.fromInt({s}, self.list.getUInt16(index)) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn getRaw(self: @This(), index: usize) u16 {{
                \\            return self.list.getUInt16(index);
                \\        }}
                \\
            , .{ zig_type, zig_type });
        } else {
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return {s}.fromReader(try self.list.getStructElement(index));
                \\        }}
                \\
            , .{ zig_type, zig_type });
        },
        .void, .list, .optional => {},
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_BuilderList = struct {{
        \\        list: cpz.ListBuilder,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
    , .{ owner_name, field_name });

    switch (child) {
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !bool {{
            \\            return self.list.getBool(index);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, value: bool) !void {{
            \\            return self.list.setBool(index, value);
            \\        }}
            \\
        , .{}),
        .uint8 => try listScalarSetter(allocator, out, "u8", "setUInt8"),
        .uint16 => try listScalarSetter(allocator, out, "u16", "setUInt16"),
        .uint32 => try listScalarSetter(allocator, out, "u32", "setUInt32"),
        .uint64 => try listScalarSetter(allocator, out, "u64", "setUInt64"),
        .int8 => try listScalarSetter(allocator, out, "i8", "setInt8"),
        .int16 => try listScalarSetter(allocator, out, "i16", "setInt16"),
        .int32 => try listScalarSetter(allocator, out, "i32", "setInt32"),
        .int64 => try listScalarSetter(allocator, out, "i64", "setInt64"),
        .float32 => try listScalarSetter(allocator, out, "f32", "setFloat32"),
        .float64 => try listScalarSetter(allocator, out, "f64", "setFloat64"),
        .text => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getText();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setText(value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setData(value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
        , .{}),
        .named => |type_name| if (findEnum(file, type_name) != null) {
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return std.enums.fromInt({s}, try self.list.getUInt16(index)) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn getRaw(self: @This(), index: usize) !u16 {{
                \\            return self.list.getUInt16(index);
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, value: {s}) !void {{
                \\            return self.list.setUInt16(index, @intFromEnum(value));
                \\        }}
                \\
                \\        pub fn setRaw(self: @This(), index: usize, value: u16) !void {{
                \\            return self.list.setUInt16(index, value);
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        } else {
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s}.Builder {{
                \\            return {s}.Builder.fromBuilder(try self.list.getStructElement(index));
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, value: {s}) !void {{
                \\            return (try self.list.getStructElement(index)).copyFromReader(value.reader);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return (try self.list.getStructElement(index)).clear();
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        },
        .void, .list, .optional => {},
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

fn listScalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), zig_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get(self: @This(), index: usize) !{s} {{
        \\            return self.list.get{s}(index);
        \\        }}
        \\
        \\        pub fn set(self: @This(), index: usize, value: {s}) !void {{
        \\            return self.list.{s}(index, value);
        \\        }}
        \\
    , .{ zig_type, method["set".len..], zig_type, method });
}

fn emitFieldBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    switch (field_layout.slot) {
        .void => try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder) void {{
            \\            _ = self;
            \\        }}
            \\
        , .{field_name}),
        .data_bit => |bit| try appendFmt(allocator, out,
            \\        pub fn get_{s}(self: Builder) !bool {{
            \\            return self.builder.getBool({}, {s});
            \\        }}
            \\
            \\        pub fn set_{s}(self: Builder, value: bool) !void {{
            \\            return self.builder.setBool({}, value, {s});
            \\        }}
            \\
        , .{ field_name, bit, try defaultBoolLiteral(field), field_name, bit, try defaultBoolLiteral(field) }),
        .data_byte => |byte| try emitDataBuilderMethod(allocator, out, file, field_name, field, byte),
        .pointer => |index| try emitPointerBuilderMethod(allocator, out, file, owner_name, field_name, field, index),
    }
}

fn emitDataBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    switch (field.ty) {
        .int8 => try scalarSetter(allocator, out, field_name, "i8", "getInt8", "setInt8", byte, defaultScalarLiteral(field)),
        .int16 => try scalarSetter(allocator, out, field_name, "i16", "getInt16", "setInt16", byte, defaultScalarLiteral(field)),
        .int32 => try scalarSetter(allocator, out, field_name, "i32", "getInt32", "setInt32", byte, defaultScalarLiteral(field)),
        .int64 => try scalarSetter(allocator, out, field_name, "i64", "getInt64", "setInt64", byte, defaultScalarLiteral(field)),
        .uint8 => try scalarSetter(allocator, out, field_name, "u8", "getUInt8", "setUInt8", byte, defaultScalarLiteral(field)),
        .uint16 => try scalarSetter(allocator, out, field_name, "u16", "getUInt16", "setUInt16", byte, defaultScalarLiteral(field)),
        .uint32 => try scalarSetter(allocator, out, field_name, "u32", "getUInt32", "setUInt32", byte, defaultScalarLiteral(field)),
        .uint64 => try scalarSetter(allocator, out, field_name, "u64", "getUInt64", "setUInt64", byte, defaultScalarLiteral(field)),
        .float32 => try scalarSetter(allocator, out, field_name, "f32", "getFloat32", "setFloat32", byte, defaultScalarLiteral(field)),
        .float64 => try scalarSetter(allocator, out, field_name, "f64", "getFloat64", "setFloat64", byte, defaultScalarLiteral(field)),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s} {{
                \\            return std.enums.fromInt({s}, try self.builder.getUInt16({}, {})) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn get_{s}_raw(self: Builder) !u16 {{
                \\            return self.builder.getUInt16({}, {});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, value: {s}) !void {{
                \\            return self.builder.setUInt16({}, @intFromEnum(value), {});
                \\        }}
                \\
                \\        pub fn set_{s}_raw(self: Builder, value: u16) !void {{
                \\            return self.builder.setUInt16({}, value, {});
                \\        }}
                \\
            , .{ field_name, zig_type, zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, get_method: []const u8, method: []const u8, byte: usize, default: []const u8) !void {
    try appendFmt(allocator, out,
        \\        pub fn get_{s}(self: Builder) !{s} {{
        \\            return self.builder.{s}({}, {s});
        \\        }}
        \\
        \\        pub fn set_{s}(self: Builder, value: {s}) !void {{
        \\            return self.builder.{s}({}, value, {s});
        \\        }}
        \\
    , .{ name, zig_type, get_method, byte, default, name, zig_type, method, byte, default });
}

fn emitPointerBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    if (field.ty == .optional) {
        var optional_field = field.*;
        optional_field.ty = field.ty.optional.*;
        return emitPointerBuilderMethod(allocator, out, file, owner_name, field_name, &optional_field, index);
    }

    try appendFmt(allocator, out,
        \\        pub fn has_{s}(self: Builder) !bool {{
        \\            return !(try self.builder.getPointerField({})).isNull();
        \\        }}
        \\
        \\        pub fn clear_{s}(self: Builder) !void {{
        \\            return self.builder.clearPointer({});
        \\        }}
        \\
    , .{ field_name, index, field_name, index });

    switch (field.ty) {
        .text => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}(self: Builder) ![]const u8 {{
                    \\            return (try self.builder.getPointerField({})).getTextDefault({s});
                    \\        }}
                    \\
                , .{ field_name, index, literal });
            } else try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) ![]const u8 {{
                \\            return (try self.builder.getPointerField({})).getText();
                \\        }}
                \\
            , .{ field_name, index });
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, value: []const u8) !void {{
                \\            return self.builder.setText({}, value);
                \\        }}
                \\
            , .{ field_name, index });
        },
        .data => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\        pub fn get_{s}(self: Builder) ![]const u8 {{
                    \\            return (try self.builder.getPointerField({})).getDataDefault({s});
                    \\        }}
                    \\
                , .{ field_name, index, literal });
            } else try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) ![]const u8 {{
                \\            return (try self.builder.getPointerField({})).getData();
                \\        }}
                \\
            , .{ field_name, index });
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, value: []const u8) !void {{
                \\            return self.builder.setData({}, value);
                \\        }}
                \\
            , .{ field_name, index });
        },
        .list => |child| if (isStructListElement(file, child.*)) |type_name| {
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn init_{s}(self: Builder, count: usize) !{s}_{s}_BuilderList {{
                \\            return .{{ .list = try (try self.builder.getPointerField({})).initStructList(count, {s}.size) }};
                \\        }}
                \\
            , .{ field_name, owner_name, field_name, index, zig_type });
        } else try appendFmt(allocator, out,
            \\        pub fn init_{s}(self: Builder, count: usize) !{s}_{s}_BuilderList {{
            \\            return .{{ .list = try (try self.builder.getPointerField({})).initList({s}, count) }};
            \\        }}
            \\
        , .{ field_name, owner_name, field_name, index, try listElementSizeLiteral(file, child.*) }),
        .named => |type_name| {
            const zig_type = try zigIdentAlloc(allocator, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}.Builder {{
                \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).getStruct());
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder) !{s}.Builder {{
                \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).initStruct({s}.size));
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, value: {s}) !void {{
                \\            return (try self.builder.getPointerField({})).copyStructFrom(value.reader);
                \\        }}
                \\
            , .{ field_name, zig_type, zig_type, index, field_name, zig_type, zig_type, index, zig_type, field_name, zig_type, index });
        },
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
        .optional => ".pointer",
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

fn zigIdentAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
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

fn zigStringLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '"');

    var i: usize = 0;
    while (i < raw.len) {
        const c = raw[i];
        i += 1;
        if (c == '\\' and i < raw.len) {
            const escaped = raw[i];
            i += 1;
            switch (escaped) {
                'n' => try appendZigStringChar(allocator, &out, '\n'),
                'r' => try appendZigStringChar(allocator, &out, '\r'),
                't' => try appendZigStringChar(allocator, &out, '\t'),
                '"' => try appendZigStringChar(allocator, &out, '"'),
                '\\' => try appendZigStringChar(allocator, &out, '\\'),
                'x' => {
                    if (i + 2 <= raw.len) {
                        if (std.fmt.parseInt(u8, raw[i .. i + 2], 16)) |value| {
                            i += 2;
                            try appendZigStringChar(allocator, &out, value);
                        } else |_| {
                            try appendZigStringChar(allocator, &out, escaped);
                        }
                    } else {
                        try appendZigStringChar(allocator, &out, escaped);
                    }
                },
                else => try appendZigStringChar(allocator, &out, escaped),
            }
        } else {
            try appendZigStringChar(allocator, &out, c);
        }
    }
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

fn appendZigStringChar(allocator: std.mem.Allocator, out: *std.ArrayList(u8), c: u8) std.mem.Allocator.Error!void {
    switch (c) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '"' => try out.appendSlice(allocator, "\\\""),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        else => try out.append(allocator, c),
    }
}

fn isZigIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

fn isZigIdentContinue(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

fn isZigKeyword(name: []const u8) bool {
    const keywords = [_][]const u8{
        "addrspace", "align",     "allowzero",   "and",            "anyframe", "anytype",     "asm",
        "async",     "await",     "break",       "callconv",       "catch",    "comptime",    "const",
        "continue",  "defer",     "else",        "enum",           "errdefer", "error",       "export",
        "extern",    "fn",        "for",         "if",             "inline",   "linksection", "noalias",
        "noinline",  "nosuspend", "opaque",      "or",             "orelse",   "packed",      "pub",
        "resume",    "return",    "struct",      "suspend",        "switch",   "test",        "threadlocal",
        "try",       "union",     "unreachable", "usingnamespace", "var",      "volatile",    "while",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, name, keyword)) return true;
    }
    return false;
}

fn defaultScalarLiteral(field: *const Field) []const u8 {
    const literal = field.default_literal orelse return "0";
    return if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal;
}

fn defaultBoolLiteral(field: *const Field) LayoutError![]const u8 {
    const literal = field.default_literal orelse return "false";
    if (std.mem.eql(u8, literal, "true") or std.mem.eql(u8, literal, "false")) return literal;
    return error.InvalidToken;
}

fn enumDefaultOrdinal(decl: *const EnumDecl, literal: ?[]const u8) LayoutError!u16 {
    const raw_name = literal orelse return 0;
    const name = if (std.mem.lastIndexOfScalar(u8, raw_name, '.')) |dot| raw_name[dot + 1 ..] else raw_name;
    for (decl.values) |value| {
        if (std.mem.eql(u8, value.name, name)) return value.ordinal;
    }
    return error.InvalidToken;
}

test "schema code generator emits Zig accessor skeletons" {
    const source =
        \\enum Color {
        \\  red @0;
        \\  green @1;
        \\}
        \\struct Person {
        \\  id @0 :UInt32 = 42;
        \\  active @1 :Bool = true;
        \\  favorite @2 :Color = Color.green;
        \\  name @3 :Text = "Anon";
        \\  friend @4 :Person;
        \\  scores @5 :List(UInt32);
        \\  children @6 :List(Person);
        \\  palette @7 :List(Color);
        \\  aliases @8 :TextList;
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pointer_count = 6") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn id(self: @This()) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getUInt32(0, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.reader.getBool(32, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "std.enums.fromInt(Color, self.reader.getUInt16(6, 1))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn favorite_raw(self: @This()) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_favorite(self: Builder) !Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_favorite_raw(self: Builder) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_favorite_raw(self: Builder, value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getTextDefault(\"Anon\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_scores_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_children_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return Person.fromReader(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_friend(self: Builder) !Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_scores_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt32(index, value);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_children_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return Person.Builder.fromBuilder(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromReader(value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getPointerElement(index)).getText();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearPointerElement(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getStructElement(index)).clear();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return std.enums.fromInt(Color, self.list.getUInt16(index)) orelse error.InvalidEnumValue;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), index: usize) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), index: usize) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setRaw(self: @This(), index: usize, value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt16(index, @intFromEnum(value));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(count, Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Builder = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_id(self: Builder) !u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_id(self: Builder, value: u32) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setUInt32(0, value, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setBool(32, value, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn has_name(self: Builder) !bool") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_name(self: Builder) ![]const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_name(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_name(self: Builder, value: []const u8) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_friend(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_friend_from(self: Builder, value: Person) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFrom(value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_scores(self: Builder) !void") != null);
}

test "schema code generator can include raw schema comments" {
    const source =
        \\struct Demo {
        \\  id @0 :UInt32;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{ .raw_schema_comment = source });
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.startsWith(u8, code, "// cpz source schema begin\n"));
    try std.testing.expect(std.mem.indexOf(u8, code, "// struct Demo {") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "// cpz source schema end") != null);
}

test "schema code generator supports custom runtime import names" {
    var file = try parse(std.testing.allocator,
        \\struct Demo {
        \\  id @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{
        .runtime_import_name = "my_cpz",
    });
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "const cpz = @import(\"my_cpz\");") != null);
}

test "schema code generator converts escaped string defaults to Zig literals" {
    const literal = try zigStringLiteralAlloc(std.testing.allocator, "line\\n\\\"tab\\t\\x21");
    defer std.testing.allocator.free(literal);
    try std.testing.expectEqualStrings("\"line\\n\\\"tab\\t!\"", literal);
}

test "schema code generator sanitizes dotted named type references" {
    var file = try parse(std.testing.allocator,
        \\struct Ref {
        \\  child @0 :Outer.Inner;
        \\  children @1 :List(Outer.Inner);
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Outer_Inner") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Outer_Inner.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Outer_Inner.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Outer_Inner.size") != null);
}

test "schema code generator sanitizes Zig keywords in declarations and fields" {
    var file = try parse(std.testing.allocator,
        \\enum error {
        \\  test @0;
        \\  ok @1;
        \\}
        \\struct fn {
        \\  error @0 :UInt32;
        \\  enum @1 :error = test;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const error_ = enum") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "test_ = 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const fn_ = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn error_(self: @This()) u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn enum_(self: @This()) !error_") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn color(self: @This()) !Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getUInt16(0, 1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_color(self: Builder, value: Color) !void") != null);
}
