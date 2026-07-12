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
    any_pointer,
    any_struct,
    any_list,
    capability,
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
    default_is_hex_data: bool = false,
    union_index: ?u32 = null,
    union_discriminant: u16 = 0,

    pub fn deinit(self: *Field, allocator: std.mem.Allocator) void {
        self.ty.deinit(allocator);
        self.* = undefined;
    }
};

pub const AliasDecl = struct {
    name: []const u8,
    target: Type,

    pub fn deinit(self: *AliasDecl, allocator: std.mem.Allocator) void {
        self.target.deinit(allocator);
        self.* = undefined;
    }
};

pub const ImportDecl = struct {
    name: []const u8,
    path: []const u8,
    member: ?[]const u8 = null,
};

const UnionBuilder = struct {
    fields: std.ArrayList(Field) = .empty,
    field_names: std.StringHashMap(void),
    next_discriminant: u16 = 0,

    fn init(allocator: std.mem.Allocator) UnionBuilder {
        return .{ .field_names = std.StringHashMap(void).init(allocator) };
    }

    fn deinit(self: *UnionBuilder, allocator: std.mem.Allocator) void {
        for (self.fields.items) |*field| field.deinit(allocator);
        self.fields.deinit(allocator);
        self.field_names.deinit();
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

pub const InterfaceDecl = struct {
    name: []const u8,
};

pub const File = struct {
    id: ?u64,
    structs: []Struct,
    enums: []EnumDecl,
    aliases: []AliasDecl,
    imports: []ImportDecl,
    interfaces: []InterfaceDecl,

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        for (self.structs) |*s| s.deinit(allocator);
        allocator.free(self.structs);
        for (self.enums) |*e| e.deinit(allocator);
        allocator.free(self.enums);
        for (self.aliases) |*a| a.deinit(allocator);
        allocator.free(self.aliases);
        allocator.free(self.imports);
        allocator.free(self.interfaces);
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

pub const UnionLayout = struct {
    discriminant_byte: usize,
    data_bit: usize = 0,
    data_bits: usize = 0,
    pointer: ?usize = null,
};

pub const StructLayout = struct {
    decl: *const Struct,
    data_words: u16,
    pointer_count: u16,
    fields: []FieldLayout,
    unions: []UnionLayout,

    pub fn deinit(self: *StructLayout, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
        allocator.free(self.unions);
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
    bang,
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
            '!' => .{ .tag = .bang, .lexeme = self.source[start..self.index] },
            '-' => blk: {
                if (self.index < self.source.len and self.source[self.index] == '>') {
                    self.index += 1;
                    break :blk .{ .tag = .arrow, .lexeme = self.source[start..self.index] };
                }
                if (self.index >= self.source.len) return error.InvalidToken;
                if (std.ascii.isDigit(self.source[self.index])) {
                    while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
                }
                if (isIdentStart(self.source[self.index])) {
                    self.index += 1;
                    while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index], .start = start, .end = self.index };
                }
                return error.InvalidToken;
            },
            '+' => blk: {
                if (self.index >= self.source.len) return error.InvalidToken;
                if (std.ascii.isDigit(self.source[self.index])) {
                    while (self.index < self.source.len and isNumberContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .integer, .lexeme = self.source[start..self.index] };
                }
                if (isIdentStart(self.source[self.index])) {
                    self.index += 1;
                    while (self.index < self.source.len and isIdentContinue(self.source[self.index])) self.index += 1;
                    break :blk .{ .tag = .identifier, .lexeme = self.source[start..self.index], .start = start, .end = self.index };
                }
                return error.InvalidToken;
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
        var aliases = std.ArrayList(AliasDecl).empty;
        errdefer {
            for (aliases.items) |*a| a.deinit(self.allocator);
            aliases.deinit(self.allocator);
        }
        var imports = std.ArrayList(ImportDecl).empty;
        errdefer imports.deinit(self.allocator);
        var interfaces = std.ArrayList(InterfaceDecl).empty;
        errdefer interfaces.deinit(self.allocator);
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
                const name = try self.parseInterfaceDeclaration();
                const entry = try decl_names.getOrPut(name);
                if (entry.found_existing) return error.NameCollision;
                try interfaces.append(self.allocator, .{ .name = name });
            } else if (self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, &imports, &decl_names);
            } else if (self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
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
            .aliases = try aliases.toOwnedSlice(self.allocator),
            .imports = try imports.toOwnedSlice(self.allocator),
            .interfaces = try interfaces.toOwnedSlice(self.allocator),
        };
    }

    fn parseInterfaceDeclaration(self: *Parser) Error![]const u8 {
        const name = try self.expectIdentifier();
        try self.skipBracedDeclaration();
        return name;
    }

    fn parseUsingOrSkip(self: *Parser, aliases: *std.ArrayList(AliasDecl), imports: *std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.isKeyword("import")) {
            try self.parseAnonymousImport(imports, decl_names);
            return;
        }
        if (self.lookahead.tag != .identifier or (try self.peekNext()).tag != .equal) {
            try self.skipRawUntilSemicolon();
            return;
        }

        const name = try self.expectIdentifier();
        try self.expect(.equal);
        if (self.isKeyword("import")) {
            try self.advance();
            if (self.lookahead.tag != .string) {
                try self.skipRawUntilSemicolon();
                return;
            }
            const path = self.lookahead.lexeme;
            try self.advance();
            var member: ?[]const u8 = null;
            if (self.lookahead.tag == .dot) {
                try self.expect(.dot);
                const first = self.lookahead;
                _ = try self.expectIdentifier();
                var end = first.end;
                while (self.lookahead.tag == .dot) {
                    try self.expect(.dot);
                    const part = self.lookahead;
                    _ = try self.expectIdentifier();
                    end = part.end;
                }
                member = self.lexer.source[first.start..end];
            }
            if (self.lookahead.tag != .semicolon) {
                try self.skipRawUntilSemicolon();
                return;
            }
            try self.expect(.semicolon);

            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
            return;
        }

        var target = self.parseType() catch {
            try self.skipRawUntilSemicolon();
            return;
        };
        errdefer target.deinit(self.allocator);
        if (self.lookahead.tag != .semicolon) {
            target.deinit(self.allocator);
            try self.skipRawUntilSemicolon();
            return;
        }
        try self.expect(.semicolon);

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = name, .target = target });
    }

    fn parseAnonymousImport(self: *Parser, imports: *std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        try self.advance();
        if (self.lookahead.tag != .string) {
            try self.skipRawUntilSemicolon();
            return;
        }
        const path = self.lookahead.lexeme;
        try self.advance();
        if (self.lookahead.tag != .dot) {
            try self.skipRawUntilSemicolon();
            return;
        }
        try self.expect(.dot);
        const first = self.lookahead;
        _ = try self.expectIdentifier();
        var end = first.end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
        }
        if (self.lookahead.tag != .semicolon) {
            try self.skipRawUntilSemicolon();
            return;
        }
        try self.expect(.semicolon);

        const member = self.lexer.source[first.start..end];
        const name = if (std.mem.lastIndexOfScalar(u8, member, '.')) |dot| member[dot + 1 ..] else member;
        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
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
        var unions = std.ArrayList(UnionBuilder).empty;
        errdefer {
            for (unions.items) |*u| u.deinit(self.allocator);
            unions.deinit(self.allocator);
        }

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(&fields, &field_names, &unions);
                continue;
            }
            if (self.isKeyword("union") and (try self.peekNext()).tag == .l_brace) {
                try self.advance();
                const union_index: u32 = @intCast(unions.items.len);
                try unions.append(self.allocator, UnionBuilder.init(self.allocator));
                try self.parseAnonymousUnion(&unions.items[union_index], union_index);
                continue;
            }
            if (self.eatKeyword("using") or self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            if (try putFieldName(&field_names, field.name)) {
                field.deinit(self.allocator);
                return error.NameCollision;
            }
            try fields.append(self.allocator, field);
        }
        try self.expect(.r_brace);
        for (unions.items) |*u| try appendUnionFields(self.allocator, &fields, &field_names, u);
        for (unions.items) |*u| u.deinit(self.allocator);
        unions.deinit(self.allocator);
        return .{ .name = name, .fields = try fields.toOwnedSlice(self.allocator) };
    }

    fn parseAnonymousUnion(self: *Parser, union_builder: *UnionBuilder, union_index: u32) Error!void {
        try self.expect(.l_brace);
        try self.parseAnonymousUnionBody(union_builder, union_index);
    }

    fn parseNamedAggregate(self: *Parser, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), unions: *std.ArrayList(UnionBuilder)) Error!void {
        const name = try self.expectIdentifier();
        const ordinal = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        _ = unions;
        if (std.mem.eql(u8, kind, "union") or std.mem.eql(u8, kind, "group")) {
            try self.skipUntil(.l_brace);
            try self.skipCurrentBracedBody();
            if (ordinal) |value| {
                var field = Field{ .name = name, .ordinal = value, .ty = .void };
                if (try putFieldName(field_names, field.name)) {
                    field.deinit(self.allocator);
                    return error.NameCollision;
                }
                try fields.append(self.allocator, field);
            }
            return;
        }
        return error.UnexpectedToken;
    }

    fn skipNamedAggregate(self: *Parser) Error!void {
        _ = try self.expectIdentifier();
        _ = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (!std.mem.eql(u8, kind, "union") and !std.mem.eql(u8, kind, "group")) return error.UnexpectedToken;
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    fn parseOptionalOrdinalBang(self: *Parser) Error!?u32 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        return @intCast(ordinal_u64);
    }

    fn parseAnonymousUnionBody(self: *Parser, union_builder: *UnionBuilder, union_index: u32) Error!void {
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.skipNamedAggregate();
                continue;
            }
            if (self.eatKeyword("using") or self.eatKeyword("const") or self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            field.union_index = union_index;
            if (try putFieldName(&union_builder.field_names, field.name)) {
                field.deinit(self.allocator);
                return error.NameCollision;
            }
            try union_builder.fields.append(self.allocator, field);
        }
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    fn assignUnionDiscriminants(self: *Parser, fields: []Field) Error!void {
        var assigned = try self.allocator.alloc(bool, fields.len);
        defer self.allocator.free(assigned);
        @memset(assigned, false);
        for (0..fields.len) |discriminant| {
            if (discriminant > std.math.maxInt(u16)) return error.InvalidOrdinal;
            const field_index = nextOrdinalFieldIndex(fields, assigned) orelse unreachable;
            assigned[field_index] = true;
            fields[field_index].union_discriminant = @intCast(discriminant);
        }
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
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        try self.expect(.colon);
        const ty = try self.parseType();
        if (isGroupType(ty) and self.lookahead.tag == .l_brace) {
            try self.skipCurrentBracedBody();
            return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = .void };
        }
        var default_is_hex_data = false;
        const default_literal = if (self.lookahead.tag == .equal) blk: {
            try self.expect(.equal);
            if (ty == .data and self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) return error.UnexpectedToken;
                const value = self.lookahead.lexeme;
                try self.advance();
                default_is_hex_data = true;
                break :blk value;
            }
            break :blk try self.expectDefaultLiteral();
        } else null;
        try self.skipUntilSemicolon();
        return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = ty, .default_literal = default_literal, .default_is_hex_data = default_is_hex_data };
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
        if (std.mem.eql(u8, name, "AnyList")) return .any_list;
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
        if (std.mem.eql(u8, name, "AnyPointer")) return .any_pointer;
        if (std.mem.eql(u8, name, "AnyStruct")) return .any_struct;
        if (std.mem.eql(u8, name, "AnyList")) return .any_list;
        if (std.mem.eql(u8, name, "Capability")) return .capability;
        return .{ .named = name };
    }

    fn isNamedAggregateStart(self: *const Parser) Error!bool {
        if (self.lookahead.tag != .identifier) return false;
        var lexer = self.lexer;
        var token = try lexer.next();
        if (token.tag == .at) {
            token = try lexer.next();
            if (token.tag != .integer) return false;
            token = try lexer.next();
            if (token.tag == .bang) token = try lexer.next();
        }
        if (token.tag != .colon) return false;
        token = try lexer.next();
        if (token.tag != .identifier) return false;
        if (!std.mem.eql(u8, token.lexeme, "union") and !std.mem.eql(u8, token.lexeme, "group")) return false;
        while (token.tag != .eof and token.tag != .semicolon and token.tag != .r_brace) : (token = try lexer.next()) {
            if (token.tag == .l_brace) return true;
        }
        return false;
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

    fn expectDefaultLiteral(self: *Parser) Error!?[]const u8 {
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
            .l_paren, .l_bracket => return null,
            else => return error.UnexpectedToken,
        }
    }

    fn skipUntilSemicolon(self: *Parser) Error!void {
        try self.skipUntil(.semicolon);
        try self.expect(.semicolon);
    }

    fn skipRawUntilSemicolon(self: *Parser) Error!void {
        const source = self.lexer.source;
        var index = self.lexer.index;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var brace_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
                '`' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '"' => {
                    if (index + 2 < source.len and source[index + 1] == '"' and source[index + 2] == '"') {
                        index += 3;
                        while (index + 2 < source.len and !(source[index] == '"' and source[index + 1] == '"' and source[index + 2] == '"')) : (index += 1) {}
                        if (index + 2 >= source.len) return error.UnexpectedToken;
                        index += 3;
                    } else {
                        index += 1;
                        while (index < source.len) {
                            if (source[index] == '\\') {
                                index += 2;
                            } else if (source[index] == '"') {
                                index += 1;
                                break;
                            } else {
                                index += 1;
                            }
                        }
                    }
                },
                '#' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index += 2;
                        while (index < source.len and source[index] != '\n') index += 1;
                    } else {
                        index += 1;
                    }
                },
                '(' => {
                    paren_depth += 1;
                    index += 1;
                },
                ')' => {
                    if (paren_depth > 0) paren_depth -= 1;
                    index += 1;
                },
                '[' => {
                    bracket_depth += 1;
                    index += 1;
                },
                ']' => {
                    if (bracket_depth > 0) bracket_depth -= 1;
                    index += 1;
                },
                '{' => {
                    brace_depth += 1;
                    index += 1;
                },
                '}' => {
                    if (brace_depth > 0) brace_depth -= 1;
                    index += 1;
                },
                ';' => {
                    index += 1;
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) {
                        self.lexer.index = index;
                        try self.advance();
                        return;
                    }
                },
                else => index += 1,
            }
        }
        return error.UnexpectedToken;
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

fn putFieldName(names: *std.StringHashMap(void), name: []const u8) std.mem.Allocator.Error!bool {
    const entry = try names.getOrPut(name);
    return entry.found_existing;
}

fn appendUnionFields(allocator: std.mem.Allocator, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), union_builder: *UnionBuilder) Error!void {
    var appended: usize = 0;
    errdefer {
        var i = fields.items.len - appended;
        while (i < fields.items.len) : (i += 1) fields.items[i].deinit(allocator);
        fields.shrinkRetainingCapacity(fields.items.len - appended);
    }
    try fields.ensureUnusedCapacity(allocator, union_builder.fields.items.len);
    try field_names.ensureUnusedCapacity(@intCast(union_builder.fields.items.len));
    for (union_builder.fields.items) |field| {
        if (field_names.contains(field.name)) return error.NameCollision;
    }
    for (union_builder.fields.items) |field| {
        field_names.putAssumeCapacityNoClobber(field.name, {});
        fields.appendAssumeCapacity(field);
        appended += 1;
    }
    union_builder.fields.clearRetainingCapacity();
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
    const union_count = countUnions(decl.fields);
    const unions = try allocator.alloc(UnionLayout, union_count);
    errdefer allocator.free(unions);
    for (unions) |*u| u.* = .{ .discriminant_byte = 0 };
    const union_requirements = try allocator.alloc(UnionRequirement, union_count);
    defer allocator.free(union_requirements);
    for (union_requirements) |*req| req.* = .{};
    const union_allocated = try allocator.alloc(bool, union_count);
    defer allocator.free(union_allocated);
    @memset(union_allocated, false);

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
        if (field.union_index) |union_index| {
            try addUnionRequirement(file, &union_requirements[@intCast(union_index)], field.ty);
        }
    }

    for (0..decl.fields.len) |_| {
        const field_index = nextOrdinalFieldIndex(decl.fields, assigned) orelse unreachable;
        assigned[field_index] = true;
        const field = &decl.fields[field_index];

        const slot: FieldSlot = if (field.union_index) |union_index| blk: {
            const index: usize = @intCast(union_index);
            if (!union_allocated[index]) {
                const discriminant_start = try allocateDataBits(allocator, &data_ranges, 16);
                data_end_bit = @max(data_end_bit, discriminant_start + 16);
                unions[index].discriminant_byte = discriminant_start / 8;
                if (union_requirements[index].data_bits != 0) {
                    const start = try allocateDataBits(allocator, &data_ranges, union_requirements[index].data_bits);
                    data_end_bit = @max(data_end_bit, start + union_requirements[index].data_bits);
                    unions[index].data_bit = start;
                    unions[index].data_bits = union_requirements[index].data_bits;
                }
                if (union_requirements[index].has_pointer) {
                    unions[index].pointer = next_pointer;
                    next_pointer += 1;
                }
                union_allocated[index] = true;
            }
            break :blk try unionFieldSlot(file, field.ty, unions[index]);
        } else switch (try classify(file, field.ty)) {
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
        .unions = unions,
    };
}

const UnionRequirement = struct {
    data_bits: usize = 0,
    has_pointer: bool = false,
};

fn countUnions(fields: []const Field) usize {
    var count: usize = 0;
    for (fields) |field| {
        if (field.union_index) |union_index| count = @max(count, @as(usize, @intCast(union_index)) + 1);
    }
    return count;
}

fn addUnionRequirement(file: *const File, req: *UnionRequirement, ty: Type) LayoutError!void {
    switch (try classify(file, ty)) {
        .void => {},
        .data => |bits| req.data_bits = @max(req.data_bits, @max(bits, @as(usize, 8))),
        .pointer => req.has_pointer = true,
    }
}

fn unionFieldSlot(file: *const File, ty: Type, layout: UnionLayout) LayoutError!FieldSlot {
    return switch (try classify(file, ty)) {
        .void => .void,
        .data => |bits| if (bits == 1) .{ .data_bit = layout.data_bit } else .{ .data_byte = layout.data_bit / 8 },
        .pointer => .{ .pointer = layout.pointer orelse return error.UnsupportedType },
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
    return switch (resolveType(file, ty)) {
        .void => .void,
        .bool => .{ .data = 1 },
        .int8, .uint8 => .{ .data = 8 },
        .int16, .uint16 => .{ .data = 16 },
        .int32, .uint32, .float32 => .{ .data = 32 },
        .int64, .uint64, .float64 => .{ .data = 64 },
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => .pointer,
        .optional => .pointer,
        .named => |name| if (findEnum(file, name) != null) .{ .data = 16 } else .pointer,
    };
}

fn findEnum(file: *const File, name: []const u8) ?*const EnumDecl {
    if (findEnumDirect(file, name)) |decl| return decl;
    const resolved = resolveNamedAlias(file, name, 0) orelse return null;
    return switch (resolved) {
        .named => |resolved_name| findEnumDirect(file, resolved_name),
        else => null,
    };
}

fn findEnumDirect(file: *const File, name: []const u8) ?*const EnumDecl {
    for (file.enums) |*decl| {
        if (std.mem.eql(u8, decl.name, name)) return decl;
    }
    return null;
}

fn findInterface(file: *const File, name: []const u8) ?*const InterfaceDecl {
    if (findInterfaceDirect(file, name)) |decl| return decl;
    const resolved = resolveNamedAlias(file, name, 0) orelse return null;
    return switch (resolved) {
        .named => |resolved_name| findInterfaceDirect(file, resolved_name),
        .capability => &builtin_capability_interface,
        else => null,
    };
}

const builtin_capability_interface = InterfaceDecl{ .name = "Capability" };

fn findInterfaceDirect(file: *const File, name: []const u8) ?*const InterfaceDecl {
    for (file.interfaces) |*decl| {
        if (std.mem.eql(u8, decl.name, name)) return decl;
    }
    return null;
}

fn resolveType(file: *const File, ty: Type) Type {
    return switch (ty) {
        .named => |name| resolveNamedAlias(file, name, 0) orelse ty,
        else => ty,
    };
}

fn resolveNamedAlias(file: *const File, name: []const u8, depth: usize) ?Type {
    if (depth >= 32) return null;
    for (file.aliases) |alias| {
        if (!std.mem.eql(u8, alias.name, name)) continue;
        return switch (alias.target) {
            .named => |target_name| resolveNamedAlias(file, target_name, depth + 1) orelse alias.target,
            else => alias.target,
        };
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

fn isIdentStart(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
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
    try std.testing.expectError(error.UnexpectedToken, parse(std.testing.allocator, "@!;"));
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
        \\const blockText :Text =
        \\  `line one
        \\  `"quoted" line two
        \\  ;
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

test "schema parser records imported type aliases" {
    const source =
        \\using Other = import "other.capnp";
        \\using import "common.capnp".Shared;
        \\struct Holder {
        \\  external @0 :Other.External;
        \\  shared @1 :Shared;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), file.imports.len);
    try std.testing.expectEqualStrings("Other", file.imports[0].name);
    try std.testing.expectEqualStrings("other.capnp", file.imports[0].path);
    try std.testing.expect(file.imports[0].member == null);
    try std.testing.expectEqualStrings("Shared", file.imports[1].name);
    try std.testing.expectEqualStrings("common.capnp", file.imports[1].path);
    try std.testing.expectEqualStrings("Shared", file.imports[1].member.?);
    try std.testing.expectEqualStrings("Other.External", file.structs[0].fields[0].ty.named);
    try std.testing.expectEqualStrings("Shared", file.structs[0].fields[1].ty.named);
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

test "schema parser tolerates named union and group declarations" {
    const source =
        \\struct Late {
        \\  before @0 :Text;
        \\  selected @1! :union $Ann.name("selected") {
        \\    text @2 :Text;
        \\    id @3 :UInt32;
        \\  }
        \\  metadata :group {
        \\    created @4 :UInt64;
        \\  }
        \\  const localName :Text =
        \\    `block text
        \\    ;
        \\  using Alias = Text;
        \\  annotation local(field) :Text;
        \\  interface Local {
        \\    call @0 () -> ();
        \\  }
        \\  keep @5 :Text;
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), file.structs.len);
    try std.testing.expectEqual(@as(usize, 3), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("before", file.structs[0].fields[0].name);
    try std.testing.expectEqualStrings("selected", file.structs[0].fields[1].name);
    try std.testing.expectEqual(Type.void, file.structs[0].fields[1].ty);
    try std.testing.expectEqual(@as(u32, 1), file.structs[0].fields[1].ordinal);
    try std.testing.expectEqualStrings("keep", file.structs[0].fields[2].name);
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
        \\  posInf @4 :Float32 = inf;
        \\  negInf @5 :Float64 = -inf;
        \\  quietNan @6 :Float32 = nan;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("+1.5", file.structs[0].fields[0].default_literal.?);
    try std.testing.expectEqualStrings("+7", file.structs[0].fields[1].default_literal.?);
    try std.testing.expectEqualStrings("1e-3", file.structs[0].fields[2].default_literal.?);
    try std.testing.expectEqualStrings("+2.5E+4", file.structs[0].fields[3].default_literal.?);
    try std.testing.expectEqualStrings("inf", file.structs[0].fields[4].default_literal.?);
    try std.testing.expectEqualStrings("-inf", file.structs[0].fields[5].default_literal.?);
    try std.testing.expectEqualStrings("nan", file.structs[0].fields[6].default_literal.?);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(0, 1.5)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getInt32(4, 7)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(8, 1e-3)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(16, 2.5E+4)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(24, std.math.inf(f32))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat64(32, -std.math.inf(f64))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getFloat32(28, std.math.nan(f32))") != null);
}

test "schema parser tolerates list and struct field defaults" {
    var file = try parse(std.testing.allocator,
        \\struct Child {
        \\  id @0 :UInt32;
        \\}
        \\struct Defaults {
        \\  nums @0 :List(UInt32) = [1, 2, 3];
        \\  child @1 :Child = (id = 42);
        \\  bytes @2 :Data = 0x"62 61 72";
        \\}
    );
    defer file.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?[]const u8, null), file.structs[1].fields[0].default_literal);
    try std.testing.expectEqual(@as(?[]const u8, null), file.structs[1].fields[1].default_literal);
    try std.testing.expectEqualStrings("62 61 72", file.structs[1].fields[2].default_literal.?);
    try std.testing.expect(file.structs[1].fields[2].default_is_hex_data);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Defaults = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_nums(self: Builder, count: usize)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_child(self: Builder)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getDataDefault(\"bar\")") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !@\"cpz.schema\".Maybe.Builder") != null);
}

test "schema parser lowers anonymous unions and tolerates group blocks inside structs" {
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
    // The group is still represented as a void placeholder until full group
    // lowering exists; anonymous union fields are now lowered into ordinary
    // fields tagged with discriminant metadata.
    try std.testing.expectEqual(@as(usize, 4), file.structs[0].fields.len);
    try std.testing.expectEqualStrings("metadata", file.structs[0].fields[0].name);
    try std.testing.expectEqual(Type.void, file.structs[0].fields[0].ty);
    try std.testing.expectEqualStrings("keep", file.structs[0].fields[1].name);
    try std.testing.expectEqualStrings("name", file.structs[0].fields[2].name);
    try std.testing.expectEqual(@as(?u32, 0), file.structs[0].fields[2].union_index);
    try std.testing.expectEqual(@as(u16, 0), file.structs[0].fields[2].union_discriminant);
    try std.testing.expectEqualStrings("id", file.structs[0].fields[3].name);
    try std.testing.expectEqual(@as(?u32, 0), file.structs[0].fields[3].union_index);
    try std.testing.expectEqual(@as(u16, 1), file.structs[0].fields[3].union_discriminant);
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

test "schema layout planner overlaps anonymous union fields" {
    var file = try parse(std.testing.allocator,
        \\struct Choice {
        \\  before @0 :Text;
        \\  union {
        \\    foo @1 :UInt16;
        \\    bar @3 :UInt32;
        \\  }
        \\  middle @2 :UInt16;
        \\  after @4 :Text;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);

    const layout = layouts.structs[0];
    try std.testing.expectEqual(@as(u16, 1), layout.data_words);
    try std.testing.expectEqual(@as(u16, 2), layout.pointer_count);
    try std.testing.expectEqual(@as(usize, 1), layout.unions.len);
    try std.testing.expectEqual(@as(usize, 0), layout.unions[0].discriminant_byte);
    try std.testing.expectEqual(@as(usize, 32), layout.unions[0].data_bit);
    try std.testing.expectEqual(@as(usize, 32), layout.unions[0].data_bits);
    try std.testing.expectEqual(FieldSlot{ .pointer = 0 }, layout.fields[0].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 2 }, layout.fields[1].slot);
    try std.testing.expectEqual(FieldSlot{ .pointer = 1 }, layout.fields[2].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 4 }, layout.fields[3].slot);
    try std.testing.expectEqual(FieldSlot{ .data_byte = 4 }, layout.fields[4].slot);
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
    namespace: ?[]const u8 = null,
};

pub fn generateZig(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile) LayoutError![]u8 {
    return generateZigWithOptions(allocator, file, layouts, .{});
}

pub fn generateZigWithOptions(allocator: std.mem.Allocator, file: *const File, layouts: *const LayoutFile, options: CodegenOptions) LayoutError![]u8 {
    try validateZigNameCollisions(allocator, file);

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    if (options.raw_schema_comment) |source| {
        try appendRawSchemaComment(allocator, &out, source);
    }
    try appendFmt(allocator, &out,
        \\const std = @import("std");
        \\const cpz = @import("{s}");
        \\const @"cpz.schema" = @This();
        \\
        \\
    , .{options.runtime_import_name});
    if (options.namespace) |raw_namespace| {
        const namespace = try zigIdentAlloc(allocator, raw_namespace);
        defer allocator.free(namespace);
        try appendFmt(allocator, &out,
            \\pub const {s} = struct {{
            \\    const @"cpz.schema" = @This();
            \\
        , .{namespace});
    }
    for (file.enums) |*decl| {
        try emitEnum(allocator, &out, decl);
    }
    for (layouts.structs) |*layout| {
        try emitStruct(allocator, &out, file, layout);
    }
    if (options.namespace != null) {
        try out.appendSlice(allocator, "};\n");
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

fn validateZigNameCollisions(allocator: std.mem.Allocator, file: *const File) LayoutError!void {
    for (file.structs, 0..) |lhs, i| {
        for (file.structs[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        for (file.enums) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        try validateFieldZigNames(allocator, &lhs);
    }
    for (file.enums, 0..) |lhs, i| {
        for (file.enums[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
        try validateEnumValueZigNames(allocator, &lhs);
    }
}

fn validateFieldZigNames(allocator: std.mem.Allocator, decl: *const Struct) LayoutError!void {
    for (decl.fields, 0..) |lhs, i| {
        for (decl.fields[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

fn validateEnumValueZigNames(allocator: std.mem.Allocator, decl: *const EnumDecl) LayoutError!void {
    for (decl.values, 0..) |lhs, i| {
        for (decl.values[i + 1 ..]) |rhs| {
            if (try zigNamesEqual(allocator, lhs.name, rhs.name)) return error.NameCollision;
        }
    }
}

fn zigNamesEqual(allocator: std.mem.Allocator, lhs_raw: []const u8, rhs_raw: []const u8) std.mem.Allocator.Error!bool {
    const lhs = try zigIdentAlloc(allocator, lhs_raw);
    defer allocator.free(lhs);
    const rhs = try zigIdentAlloc(allocator, rhs_raw);
    defer allocator.free(rhs);
    return std.mem.eql(u8, lhs, rhs);
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
        \\    pub const Orphan = struct {{
        \\        orphan: cpz.Orphan,
        \\
        \\        pub fn fromOrphan(orphan: cpz.Orphan) Orphan {{
        \\            return .{{ .orphan = orphan }};
        \\        }}
        \\
        \\        pub fn fromRaw(orphan: cpz.Orphan) Orphan {{
        \\            return fromOrphan(orphan);
        \\        }}
        \\
        \\        pub fn raw(self: @This()) cpz.Word {{
        \\            return self.orphan.raw;
        \\        }}
        \\
        \\        pub fn isNull(self: @This()) bool {{
        \\            return self.orphan.isNull();
        \\        }}
        \\
        \\        pub fn pointerType(self: @This()) ?cpz.wire.PointerType {{
        \\            return self.orphan.pointerType();
        \\        }}
        \\
        \\        pub fn get(self: @This()) !Builder {{
        \\            return Builder.fromBuilder(try self.orphan.getStruct());
        \\        }}
        \\
        \\        pub fn getReader(self: @This(), message_reader: *cpz.MessageReader) !{s} {{
        \\            return {s}.fromReader(try self.orphan.asReader(message_reader).getStruct(null));
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.orphan.totalSize();
        \\        }}
        \\
        \\        pub fn release(self: *@This()) void {{
        \\            self.orphan.release();
        \\        }}
        \\    }};
        \\
        \\    reader: cpz.StructReader,
        \\
        \\    pub fn initRoot(builder: *cpz.MessageBuilder) !cpz.StructBuilder {{
        \\        return builder.initRoot(size);
        \\    }}
        \\
        \\    pub fn getRoot(reader: *cpz.MessageReader) !{s} {{
        \\        return fromReader(try reader.getRoot());
        \\    }}
        \\
        \\    pub fn getRootTyped(builder: *cpz.MessageBuilder) !Builder {{
        \\        return Builder.fromBuilder(try builder.getRoot());
        \\    }}
        \\
        \\    pub fn newOrphan(builder: *cpz.MessageBuilder) !Orphan {{
        \\        return Orphan.fromOrphan(try builder.newOrphanStruct(size));
        \\    }}
        \\
        \\    pub fn newOrphanIn(orphanage: cpz.Orphanage) !Orphan {{
        \\        return Orphan.fromOrphan(try orphanage.newStruct(size));
        \\    }}
        \\
        \\    pub fn newOrphanCopy(builder: *cpz.MessageBuilder, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try builder.newOrphanCopyStruct(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": @This()) !Orphan {{
        \\        return Orphan.fromOrphan(try orphanage.newCopyStruct(@"cpz.value".reader));
        \\    }}
        \\
        \\    pub fn fromReader(reader: cpz.StructReader) {s} {{
        \\        return .{{ .reader = reader }};
        \\    }}
        \\
        \\    pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\        return self.reader.totalSize();
        \\    }}
        \\
    , .{ struct_name, layout.data_words, layout.pointer_count, struct_name, struct_name, struct_name, struct_name });

    try emitUnionDeclarations(allocator, out, layout);

    for (layout.fields) |field_layout| {
        try emitFieldGetter(allocator, out, file, layout, struct_name, field_layout);
    }
    for (layout.fields) |field_layout| {
        if (resolveType(file, field_layout.field.ty) == .list) {
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
        \\        pub fn asReader(self: Builder, message_reader: *cpz.MessageReader) {s} {{
        \\            return {s}.fromReader(self.builder.asReader(message_reader));
        \\        }}
        \\
        \\        pub fn totalSize(self: Builder) !cpz.MessageSize {{
        \\            return self.builder.totalSize();
        \\        }}
        \\
        \\        pub fn orphanage(self: Builder) cpz.Orphanage {{
        \\            return self.builder.orphanage();
        \\        }}
        \\
    , .{ struct_name, struct_name });

    try emitBuilderUnionHelpers(allocator, out, struct_name, layout);

    for (layout.fields) |field_layout| {
        try emitFieldBuilderMethod(allocator, out, file, layout, struct_name, field_layout);
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    try appendFmt(allocator, out, "}};\n\n", .{});
}

fn emitUnionDeclarations(allocator: std.mem.Allocator, out: *std.ArrayList(u8), layout: *const StructLayout) LayoutError!void {
    for (layout.unions, 0..) |union_layout, union_index| {
        _ = union_layout;
        try appendFmt(allocator, out,
            \\    pub const Union{} = enum(u16) {{
            \\
        , .{union_index});
        for (layout.fields) |field_layout| {
            const field = field_layout.field;
            if (field.union_index == null or field.union_index.? != union_index) continue;
            const field_name = try zigIdentAlloc(allocator, field.name);
            defer allocator.free(field_name);
            try appendFmt(allocator, out,
                \\        {s} = {},
                \\
            , .{ field_name, field.union_discriminant });
        }
        try appendFmt(allocator, out,
            \\    }};
            \\
            \\    pub fn union{}(self: @This()) ?Union{} {{
            \\        return std.enums.fromInt(Union{}, self.reader.getUInt16({}, 0));
            \\    }}
            \\
            \\
        , .{ union_index, union_index, union_index, layout.unions[union_index].discriminant_byte });
    }
    if (layout.unions.len == 1) {
        try appendFmt(allocator, out,
            \\    pub fn which(self: @This()) ?Union0 {{
            \\        return self.union0();
            \\    }}
            \\
            \\
        , .{});
    }
}

fn emitBuilderUnionHelpers(allocator: std.mem.Allocator, out: *std.ArrayList(u8), owner_name: []const u8, layout: *const StructLayout) LayoutError!void {
    for (layout.unions, 0..) |union_layout, union_index| {
        try appendFmt(allocator, out,
            \\        pub fn union{}(self: Builder) !?{s}.Union{} {{
            \\            return std.enums.fromInt({s}.Union{}, try self.builder.getUInt16({}, 0));
            \\        }}
            \\
        , .{ union_index, owner_name, union_index, owner_name, union_index, union_layout.discriminant_byte });
        try appendFmt(allocator, out,
            \\        fn activateUnion{}(self: Builder, discriminant: u16) !void {{
        , .{union_index});
        if (union_layout.data_bits != 0) {
            try appendFmt(allocator, out,
                \\
                \\            try self.builder.clearDataBytes({}, {});
            , .{ union_layout.data_bit / 8, (union_layout.data_bits + 7) / 8 });
        }
        if (union_layout.pointer) |pointer| {
            try appendFmt(allocator, out,
                \\
                \\            try self.builder.clearPointer({});
            , .{pointer});
        }
        try appendFmt(allocator, out,
            \\
            \\            try self.builder.setUInt16({}, discriminant, 0);
            \\        }}
            \\
            \\
        , .{union_layout.discriminant_byte});
    }
    if (layout.unions.len == 1) {
        try appendFmt(allocator, out,
            \\        pub fn which(self: Builder) !?{s}.Union0 {{
            \\            return self.union0();
            \\        }}
            \\
            \\
        , .{owner_name});
    }
}

fn emitFieldGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    switch (field_layout.slot) {
        .void => if (unionLayoutForField(layout, field)) |union_layout| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !void {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\    }}
            \\
        , .{ field_name, union_layout.discriminant_byte, field.union_discriminant }) else try appendFmt(allocator, out,
            \\    pub fn {s}(self: {s}) void {{
            \\        _ = self;
            \\    }}
            \\
        , .{ field_name, "@This()" }),
        .data_bit => |bit| if (unionLayoutForField(layout, field)) |union_layout| try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !bool {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field_name, union_layout.discriminant_byte, field.union_discriminant, bit, try defaultBoolLiteral(field) }) else try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) bool {{
            \\        return self.reader.getBool({}, {s});
            \\    }}
            \\
        , .{ field_name, bit, try defaultBoolLiteral(field) }),
        .data_byte => |byte| try emitDataGetter(allocator, out, file, layout, field_name, field, byte),
        .pointer => |index| try emitPointerGetter(allocator, out, file, layout, owner_name, field_name, field, index),
    }
}

fn emitDataGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    const union_layout = unionLayoutForField(layout, field);
    switch (resolveType(file, field.ty)) {
        .int8 => try scalarGetter(allocator, out, field_name, "i8", "getInt8", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .int16 => try scalarGetter(allocator, out, field_name, "i16", "getInt16", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .int32 => try scalarGetter(allocator, out, field_name, "i32", "getInt32", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .int64 => try scalarGetter(allocator, out, field_name, "i64", "getInt64", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint8 => try scalarGetter(allocator, out, field_name, "u8", "getUInt8", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint16 => try scalarGetter(allocator, out, field_name, "u16", "getUInt16", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint32 => try scalarGetter(allocator, out, field_name, "u32", "getUInt32", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .uint64 => try scalarGetter(allocator, out, field_name, "u64", "getUInt64", byte, defaultScalarLiteral(field), union_layout, field.union_discriminant),
        .float32 => try scalarGetter(allocator, out, field_name, "f32", "getFloat32", byte, defaultFloatLiteral(field, "f32"), union_layout, field.union_discriminant),
        .float64 => try scalarGetter(allocator, out, field_name, "f64", "getFloat64", byte, defaultFloatLiteral(field, "f64"), union_layout, field.union_discriminant),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s} {{
            , .{ field_name, zig_type });
            if (union_layout) |u| {
                try appendFmt(allocator, out,
                    \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
                    \\
                , .{ u.discriminant_byte, field.union_discriminant });
            }
            try appendFmt(allocator, out,
                \\        return std.enums.fromInt({s}, self.reader.getUInt16({}, {})) orelse error.InvalidEnumValue;
                \\    }}
                \\
                \\    pub fn {s}_raw(self: @This()) u16 {{
                \\        return self.reader.getUInt16({}, {});
                \\    }}
                \\
            , .{ zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, method: []const u8, byte: usize, default: []const u8, union_layout: ?UnionLayout, discriminant: u16) !void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) !{s} {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\        return self.reader.{s}({}, {s});
            \\    }}
            \\
        , .{ name, zig_type, u.discriminant_byte, discriminant, method, byte, default });
    } else {
        try appendFmt(allocator, out,
            \\    pub fn {s}(self: @This()) {s} {{
            \\        return self.reader.{s}({}, {s});
            \\    }}
            \\
        , .{ name, zig_type, method, byte, default });
    }
}

fn emitPointerGetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    if (field.ty == .optional) {
        var optional_field = field.*;
        optional_field.ty = field.ty.optional.*;
        return emitPointerGetter(allocator, out, file, layout, owner_name, field_name, &optional_field, index);
    }
    const union_layout = unionLayoutForField(layout, field);

    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\    pub fn has_{s}(self: @This()) bool {{
            \\        if (self.reader.getUInt16({}, 0) != {}) return false;
            \\        return !self.reader.getPointerField({}).isNull();
            \\    }}
            \\
        , .{ field_name, u.discriminant_byte, field.union_discriminant, index });
    } else {
        try appendFmt(allocator, out,
            \\    pub fn has_{s}(self: @This()) bool {{
            \\        return !self.reader.getPointerField({}).isNull();
            \\    }}
            \\
        , .{ field_name, index });
    }

    switch (resolveType(file, field.ty)) {
        .text => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) ![]const u8 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getTextDefault({s});
                    \\    }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getText();
                    \\    }}
                    \\
                , .{index});
            }
        },
        .data => {
            const default_literal = if (field.default_literal) |literal| try zigDataLiteralAlloc(allocator, literal, field.default_is_hex_data) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) ![]const u8 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getDataDefault({s});
                    \\    }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\        return self.reader.getPointerField({}).getData();
                    \\    }}
                    \\
                , .{index});
            }
        },
        .any_pointer => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.PointerReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({});
                \\    }}
                \\
            , .{index});
        },
        .any_struct => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.StructReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getStruct(null);
                \\    }}
                \\
                \\    pub fn {s}PointerSection(self: @This()) !cpz.ListReader {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return (try self.reader.getPointerField({}).getStruct(null)).pointerSectionAsList();
                \\    }}
                \\
                \\    pub fn {s}DataSection(self: @This()) ![]const u8 {{
            , .{ index, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return (try self.reader.getPointerField({}).getStruct(null)).dataSectionBytes();
                \\    }}
                \\
            , .{index});
        },
        .any_list => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !cpz.ListReader {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getList(null);
                \\    }}
                \\
            , .{index});
        },
        .capability => {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !u32 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getCapabilityIndex();
                \\    }}
                \\
            , .{index});
        },
        .list => |child| {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s}_{s}_List {{
            , .{ field_name, owner_name, field_name });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return .{{ .list = try self.reader.getPointerField({}).getList({s}) }};
                \\    }}
                \\
            , .{ index, try listElementSizeLiteral(file, child.*) });
        },
        .named => |type_name| if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !u32 {{
            , .{field_name});
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return self.reader.getPointerField({}).getCapabilityIndex();
                \\    }}
                \\
            , .{index});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\    pub fn {s}(self: @This()) !{s} {{
            , .{ field_name, zig_type });
            try emitReaderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\        return {s}.fromReader(try self.reader.getPointerField({}).getStruct(null));
                \\    }}
                \\
            , .{ zig_type, index });
        },
        else => return error.UnsupportedType,
    }
}

fn emitReaderUnionCheck(allocator: std.mem.Allocator, out: *std.ArrayList(u8), union_layout: ?UnionLayout, discriminant: u16) std.mem.Allocator.Error!void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\        if (self.reader.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\
        , .{ u.discriminant_byte, discriminant });
    }
}

fn unionLayoutForField(layout: *const StructLayout, field: *const Field) ?UnionLayout {
    const union_index = field.union_index orelse return null;
    return layout.unions[@intCast(union_index)];
}

fn emitListWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, owner_name: []const u8, field: *const Field) LayoutError!void {
    const list_type = switch (resolveType(file, field.ty)) {
        .list => |child| child,
        else => return error.UnsupportedType,
    };
    const child = list_type.*;
    const resolved_child = resolveType(file, child);
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
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.list.totalSize();
        \\        }}
        \\
        \\        pub fn slice(self: @This(), start: usize, count: usize) !{s}_{s}_List {{
        \\            return .{{ .list = try self.list.slice(start, count) }};
        \\        }}
        \\
    , .{ owner_name, field_name, owner_name, field_name });

    switch (resolved_child) {
        .void => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) void {{
            \\            _ = self;
            \\            _ = index;
            \\        }}
            \\
        , .{}),
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
        .any_pointer => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.PointerReader {{
            \\            return self.list.getPointerElement(index);
            \\        }}
            \\
        , .{}),
        .any_struct => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.StructReader {{
            \\            return (try self.list.getPointerElement(index)).getStruct(null);
            \\        }}
            \\
        , .{}),
        .any_list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(index)).getList(null);
            \\        }}
            \\
        , .{}),
        .capability => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !u32 {{
            \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
            \\        }}
            \\
        , .{}),
        .list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.ListReader {{
            \\            return (try self.list.getPointerElement(index)).getList(null);
            \\        }}
            \\
        , .{}),
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
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
        } else if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !u32 {{
                \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
                \\        }}
                \\
            , .{});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s} {{
                \\            return {s}.fromReader(try self.list.getStructElement(index));
                \\        }}
                \\
            , .{ zig_type, zig_type });
        },
        .optional => {},
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});

    const list_orphan_new = if (isStructListElement(file, child)) |type_name| blk: {
        const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
        defer allocator.free(zig_type);
        break :blk try std.fmt.allocPrint(allocator,
            \\        pub fn newOrphan(builder: *cpz.MessageBuilder, count: usize) !@This() {{
            \\            return fromOrphan(try builder.newOrphanStructList(count, {s}.size));
            \\        }}
            \\
            \\        pub fn newOrphanIn(orphanage: cpz.Orphanage, count: usize) !@This() {{
            \\            return fromOrphan(try orphanage.newStructList(count, {s}.size));
            \\        }}
            \\
            \\        pub fn newOrphanCopy(builder: *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try builder.newOrphanCopyList(@"cpz.value".list));
            \\        }}
            \\
            \\        pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
            \\            return fromOrphan(try orphanage.newCopyList(@"cpz.value".list));
            \\        }}
            \\
        , .{ zig_type, zig_type, owner_name, field_name, owner_name, field_name });
    } else try std.fmt.allocPrint(allocator,
        \\        pub fn newOrphan(builder: *cpz.MessageBuilder, count: usize) !@This() {{
        \\            return fromOrphan(try builder.newOrphanList({s}, count));
        \\        }}
        \\
        \\        pub fn newOrphanIn(orphanage: cpz.Orphanage, count: usize) !@This() {{
        \\            return fromOrphan(try orphanage.newList({s}, count));
        \\        }}
        \\
        \\        pub fn newOrphanCopy(builder: *cpz.MessageBuilder, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try builder.newOrphanCopyList(@"cpz.value".list));
        \\        }}
        \\
        \\        pub fn newOrphanCopyIn(orphanage: cpz.Orphanage, @"cpz.value": {s}_{s}_List) !@This() {{
        \\            return fromOrphan(try orphanage.newCopyList(@"cpz.value".list));
        \\        }}
        \\
    , .{ try listElementSizeLiteral(file, child), try listElementSizeLiteral(file, child), owner_name, field_name, owner_name, field_name });
    defer allocator.free(list_orphan_new);

    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_Orphan = struct {{
        \\        orphan: cpz.Orphan,
        \\
        \\        pub fn fromOrphan(orphan: cpz.Orphan) @This() {{
        \\            return .{{ .orphan = orphan }};
        \\        }}
        \\
        \\        pub fn fromRaw(orphan: cpz.Orphan) @This() {{
        \\            return fromOrphan(orphan);
        \\        }}
        \\
        \\{s}
        \\        pub fn raw(self: @This()) cpz.Word {{
        \\            return self.orphan.raw;
        \\        }}
        \\
        \\        pub fn isNull(self: @This()) bool {{
        \\            return self.orphan.isNull();
        \\        }}
        \\
        \\        pub fn pointerType(self: @This()) ?cpz.wire.PointerType {{
        \\            return self.orphan.pointerType();
        \\        }}
        \\
        \\        pub fn get(self: @This()) !{s}_{s}_BuilderList {{
        \\            return .{{ .list = try self.orphan.getList({s}) }};
        \\        }}
        \\
        \\        pub fn getReader(self: @This(), message_reader: *cpz.MessageReader) !{s}_{s}_List {{
        \\            return .{{ .list = try self.orphan.asReader(message_reader).getList({s}) }};
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.orphan.totalSize();
        \\        }}
        \\
        \\        pub fn release(self: *@This()) void {{
        \\            self.orphan.release();
        \\        }}
        \\    }};
        \\
    , .{ owner_name, field_name, list_orphan_new, owner_name, field_name, try listElementSizeLiteral(file, child), owner_name, field_name, try listElementSizeLiteral(file, child) });

    try appendFmt(allocator, out,
        \\
        \\    pub const {s}_{s}_BuilderList = struct {{
        \\        list: cpz.ListBuilder,
        \\
        \\        pub fn len(self: @This()) usize {{
        \\            return self.list.len();
        \\        }}
        \\
        \\        pub fn asReader(self: @This(), message_reader: *cpz.MessageReader) {s}_{s}_List {{
        \\            return .{{ .list = self.list.asReader(message_reader) }};
        \\        }}
        \\
        \\        pub fn totalSize(self: @This()) !cpz.MessageSize {{
        \\            return self.list.totalSize();
        \\        }}
        \\
        \\        pub fn orphanage(self: @This()) cpz.Orphanage {{
        \\            return self.list.orphanage();
        \\        }}
        \\
        \\        pub fn slice(self: @This(), start: usize, count: usize) !{s}_{s}_BuilderList {{
        \\            return .{{ .list = try self.list.slice(start, count) }};
        \\        }}
        \\
    , .{ owner_name, field_name, owner_name, field_name, owner_name, field_name });

    switch (resolved_child) {
        .void => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !void {{
            \\            if (index >= self.list.len()) return error.PointerOutOfBounds;
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: void) !void {{
            \\            _ = new_value;
            \\            if (index >= self.list.len()) return error.PointerOutOfBounds;
            \\        }}
            \\
        , .{}),
        .bool => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !bool {{
            \\            return self.list.getBool(index);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: bool) !void {{
            \\            return self.list.setBool(index, new_value);
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
            \\        pub fn set(self: @This(), index: usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setText(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .data => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) ![]const u8 {{
            \\            return (try self.list.getPointerElement(index)).getData();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: []const u8) !void {{
            \\            return (try self.list.getPointerElement(index)).setData(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .any_pointer => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.PointerBuilder {{
            \\            return self.list.getPointerElement(index);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
            \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .any_struct => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.StructBuilder {{
            \\            return (try self.list.getPointerElement(index)).getStruct();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: cpz.StructReader) !void {{
            \\            return (try self.list.getPointerElement(index)).copyStructFrom(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .any_list => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !cpz.ListBuilder {{
            \\            return (try self.list.getPointerElement(index)).getList(null);
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
            \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .capability => try appendFmt(allocator, out,
            \\        pub fn get(self: @This(), index: usize) !u32 {{
            \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
            \\        }}
            \\
            \\        pub fn set(self: @This(), index: usize, new_value: u32) !void {{
            \\            return (try self.list.getPointerElement(index)).setCapability(new_value);
            \\        }}
            \\
            \\        pub fn clear(self: @This(), index: usize) !void {{
            \\            return self.list.clearPointerElement(index);
            \\        }}
            \\
            \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
            \\            return self.list.disownPointerElement(index);
            \\        }}
            \\
            \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
            \\            return self.list.adoptPointerElement(index, orphan);
            \\        }}
            \\
        , .{}),
        .list => |nested_child| {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(index)).getList(null);
                \\        }}
                \\
                \\        pub fn init(self: @This(), index: usize, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
                \\            return (try self.list.getPointerElement(index)).initList(element_size, count);
                \\        }}
                \\
            , .{});
            if (isStructListElement(file, nested_child.*)) |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn initStructList(self: @This(), index: usize, count: usize) !cpz.ListBuilder {{
                    \\            return (try self.list.getPointerElement(index)).initStructList(count, {s}.size);
                    \\        }}
                    \\
                , .{zig_type});
            }
            try appendFmt(allocator, out,
                \\        pub fn set(self: @This(), index: usize, new_value: cpz.PointerReader) !void {{
                \\            return (try self.list.getPointerElement(index)).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return self.list.clearPointerElement(index);
                \\        }}
                \\
                \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(index);
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(index, orphan);
                \\        }}
                \\
            , .{});
        },
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
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
                \\        pub fn set(self: @This(), index: usize, new_value: {s}) !void {{
                \\            return self.list.setUInt16(index, @intFromEnum(new_value));
                \\        }}
                \\
                \\        pub fn setRaw(self: @This(), index: usize, new_value: u16) !void {{
                \\            return self.list.setUInt16(index, new_value);
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        } else if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !u32 {{
                \\            return (try self.list.getPointerElement(index)).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, new_value: u32) !void {{
                \\            return (try self.list.getPointerElement(index)).setCapability(new_value);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return self.list.clearPointerElement(index);
                \\        }}
                \\
                \\        pub fn disown(self: @This(), index: usize) !cpz.Orphan {{
                \\            return self.list.disownPointerElement(index);
                \\        }}
                \\
                \\        pub fn adopt(self: @This(), index: usize, orphan: *cpz.Orphan) !void {{
                \\            return self.list.adoptPointerElement(index, orphan);
                \\        }}
                \\
            , .{});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get(self: @This(), index: usize) !{s}.Builder {{
                \\            return {s}.Builder.fromBuilder(try self.list.getStructElement(index));
                \\        }}
                \\
                \\        pub fn set(self: @This(), index: usize, new_value: {s}) !void {{
                \\            return (try self.list.getStructElement(index)).copyFromReader(new_value.reader);
                \\        }}
                \\
                \\        pub fn clear(self: @This(), index: usize) !void {{
                \\            return (try self.list.getStructElement(index)).clear();
                \\        }}
                \\
            , .{ zig_type, zig_type, zig_type });
        },
        .optional => {},
    }

    try appendFmt(allocator, out,
        \\    }};
        \\
    , .{});
}

fn emitListSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, field_name: []const u8, field: *const Field, index: usize, child: Type) LayoutError!void {
    switch (resolveType(file, child)) {
        .void => {
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, @"cpz.values": []const void) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            _ = try (try self.builder.getPointerField({})).initList(.void, @"cpz.values".len);
                \\        }}
                \\
            , .{index});
        },
        .bool => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "bool", ".bit", "setBool"),
        .uint8 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u8", ".byte", "setUInt8"),
        .uint16 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u16", ".two_bytes", "setUInt16"),
        .uint32 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u32", ".four_bytes", "setUInt32"),
        .uint64 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "u64", ".eight_bytes", "setUInt64"),
        .int8 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i8", ".byte", "setInt8"),
        .int16 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i16", ".two_bytes", "setInt16"),
        .int32 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i32", ".four_bytes", "setInt32"),
        .int64 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "i64", ".eight_bytes", "setInt64"),
        .float32 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "f32", ".four_bytes", "setFloat32"),
        .float64 => try emitListPrimitiveSliceSetter(allocator, out, field_name, field, index, "f64", ".eight_bytes", "setFloat64"),
        .text => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "[]const u8", "setText"),
        .data => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "[]const u8", "setData"),
        .any_pointer, .any_list, .list => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "cpz.PointerReader", "copyFrom"),
        .any_struct => try emitListPointerSliceSetter(allocator, out, field_name, field, index, "cpz.StructReader", "copyStructFrom"),
        .capability => try emitCapabilitySliceSetter(allocator, out, field_name, field, index),
        .named => |type_name| if (findEnumDirect(file, type_name) != null) {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
            , .{ field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.two_bytes, @"cpz.values".len);
                \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try @"cpz.list".setUInt16(@"cpz.i", @intFromEnum(@"cpz.item"));
                \\        }}
                \\
                \\        pub fn set_{s}_raw(self: Builder, @"cpz.values": []const u16) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.two_bytes, @"cpz.values".len);
                \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try @"cpz.list".setUInt16(@"cpz.i", @"cpz.item");
                \\        }}
                \\
            , .{index});
        } else if (findInterface(file, type_name) != null) {
            try emitCapabilitySliceSetter(allocator, out, field_name, field, index);
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
            , .{ field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initStructList(@"cpz.values".len, {s}.size);
                \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try (try @"cpz.list".getStructElement(@"cpz.i")).copyFromReader(@"cpz.item".reader);
                \\        }}
                \\
            , .{ index, zig_type });
        },
        .optional => {},
    }
}

fn emitListPrimitiveSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, zig_type: []const u8, element_size: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
    , .{ field_name, zig_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList({s}, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try @"cpz.list".{s}(@"cpz.i", @"cpz.item");
        \\        }}
        \\
    , .{ index, element_size, method });
}

fn emitListPointerSliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize, item_type: []const u8, method: []const u8) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const {s}) !void {{
    , .{ field_name, item_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| try (try @"cpz.list".getPointerElement(@"cpz.i")).{s}(@"cpz.item");
        \\        }}
        \\
    , .{ index, method });
}

fn emitCapabilitySliceSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn set_{s}(self: Builder, @"cpz.values": []const u32) !void {{
    , .{field_name});
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            const @"cpz.list" = try (try self.builder.getPointerField({})).initList(.pointer, @"cpz.values".len);
        \\            for (@"cpz.values", 0..) |@"cpz.item", @"cpz.i"| (try @"cpz.list".getPointerElement(@"cpz.i")).setCapability(@"cpz.item");
        \\        }}
        \\
    , .{index});
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
        \\        pub fn set(self: @This(), index: usize, new_value: {s}) !void {{
        \\            return self.list.{s}(index, new_value);
        \\        }}
        \\
    , .{ zig_type, method["set".len..], zig_type, method });
}

fn emitFieldBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_layout: FieldLayout) LayoutError!void {
    const field = field_layout.field;
    const field_name = try zigIdentAlloc(allocator, field.name);
    defer allocator.free(field_name);
    const union_layout = unionLayoutForField(layout, field);
    switch (field_layout.slot) {
        .void => if (field.union_index) |union_index| try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder) !void {{
            \\            return self.activateUnion{}({});
            \\        }}
            \\
        , .{ field_name, union_index, field.union_discriminant }) else try appendFmt(allocator, out,
            \\        pub fn set_{s}(self: Builder) void {{
            \\            _ = self;
            \\        }}
            \\
        , .{field_name}),
        .data_bit => |bit| {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !bool {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getBool({}, {s});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: bool) !void {{
            , .{ bit, try defaultBoolLiteral(field), field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setBool({}, new_value, {s});
                \\        }}
                \\
            , .{ bit, try defaultBoolLiteral(field) });
        },
        .data_byte => |byte| try emitDataBuilderMethod(allocator, out, file, layout, field_name, field, byte),
        .pointer => |index| try emitPointerBuilderMethod(allocator, out, file, layout, owner_name, field_name, field, index),
    }
}

fn emitDataBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, field_name: []const u8, field: *const Field, byte: usize) LayoutError!void {
    const union_layout = unionLayoutForField(layout, field);
    switch (resolveType(file, field.ty)) {
        .int8 => try scalarSetter(allocator, out, field_name, "i8", "getInt8", "setInt8", byte, defaultScalarLiteral(field), union_layout, field),
        .int16 => try scalarSetter(allocator, out, field_name, "i16", "getInt16", "setInt16", byte, defaultScalarLiteral(field), union_layout, field),
        .int32 => try scalarSetter(allocator, out, field_name, "i32", "getInt32", "setInt32", byte, defaultScalarLiteral(field), union_layout, field),
        .int64 => try scalarSetter(allocator, out, field_name, "i64", "getInt64", "setInt64", byte, defaultScalarLiteral(field), union_layout, field),
        .uint8 => try scalarSetter(allocator, out, field_name, "u8", "getUInt8", "setUInt8", byte, defaultScalarLiteral(field), union_layout, field),
        .uint16 => try scalarSetter(allocator, out, field_name, "u16", "getUInt16", "setUInt16", byte, defaultScalarLiteral(field), union_layout, field),
        .uint32 => try scalarSetter(allocator, out, field_name, "u32", "getUInt32", "setUInt32", byte, defaultScalarLiteral(field), union_layout, field),
        .uint64 => try scalarSetter(allocator, out, field_name, "u64", "getUInt64", "setUInt64", byte, defaultScalarLiteral(field), union_layout, field),
        .float32 => try scalarSetter(allocator, out, field_name, "f32", "getFloat32", "setFloat32", byte, defaultFloatLiteral(field, "f32"), union_layout, field),
        .float64 => try scalarSetter(allocator, out, field_name, "f64", "getFloat64", "setFloat64", byte, defaultFloatLiteral(field, "f64"), union_layout, field),
        .named => |type_name| {
            const enum_decl = findEnum(file, type_name) orelse return error.UnsupportedType;
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s} {{
            , .{ field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return std.enums.fromInt({s}, try self.builder.getUInt16({}, {})) orelse error.InvalidEnumValue;
                \\        }}
                \\
                \\        pub fn get_{s}_raw(self: Builder) !u16 {{
            , .{ zig_type, byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getUInt16({}, {});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: {s}) !void {{
            , .{ byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setUInt16({}, @intFromEnum(new_value), {});
                \\        }}
                \\
                \\        pub fn set_{s}_raw(self: Builder, new_value: u16) !void {{
            , .{ byte, try enumDefaultOrdinal(enum_decl, field.default_literal), field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setUInt16({}, new_value, {});
                \\        }}
                \\
            , .{ byte, try enumDefaultOrdinal(enum_decl, field.default_literal) });
        },
        else => return error.UnsupportedType,
    }
}

fn scalarSetter(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, zig_type: []const u8, get_method: []const u8, method: []const u8, byte: usize, default: []const u8, union_layout: ?UnionLayout, field: *const Field) LayoutError!void {
    try appendFmt(allocator, out,
        \\        pub fn get_{s}(self: Builder) !{s} {{
    , .{ name, zig_type });
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return self.builder.{s}({}, {s});
        \\        }}
        \\
        \\        pub fn set_{s}(self: Builder, new_value: {s}) !void {{
    , .{ get_method, byte, default, name, zig_type });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            return self.builder.{s}({}, new_value, {s});
        \\        }}
        \\
    , .{ method, byte, default });
}

fn emitPointerBuilderMethod(allocator: std.mem.Allocator, out: *std.ArrayList(u8), file: *const File, layout: *const StructLayout, owner_name: []const u8, field_name: []const u8, field: *const Field, index: usize) LayoutError!void {
    if (field.ty == .optional) {
        var optional_field = field.*;
        optional_field.ty = field.ty.optional.*;
        return emitPointerBuilderMethod(allocator, out, file, layout, owner_name, field_name, &optional_field, index);
    }
    const union_layout = unionLayoutForField(layout, field);

    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\        pub fn has_{s}(self: Builder) !bool {{
            \\            if (try self.builder.getUInt16({}, 0) != {}) return false;
            \\            return !(try self.builder.getPointerField({})).isNull();
            \\        }}
            \\
            \\        pub fn clear_{s}(self: Builder) !void {{
        , .{ field_name, u.discriminant_byte, field.union_discriminant, index, field_name });
        try emitBuilderUnionActivation(allocator, out, field);
        try appendFmt(allocator, out,
            \\            return self.builder.clearPointer({});
            \\        }}
            \\
        , .{index});
    } else {
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
    }

    try appendFmt(allocator, out,
        \\        pub fn disown_{s}(self: Builder) !cpz.Orphan {{
    , .{field_name});
    try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).disown();
        \\        }}
        \\
        \\        pub fn adopt_{s}(self: Builder, orphan: *cpz.Orphan) !void {{
    , .{ index, field_name });
    try emitBuilderUnionActivation(allocator, out, field);
    try appendFmt(allocator, out,
        \\            return (try self.builder.getPointerField({})).adopt(orphan);
        \\        }}
        \\
    , .{index});

    switch (resolveType(file, field.ty)) {
        .text => {
            const default_literal = if (field.default_literal) |literal| try zigStringLiteralAlloc(allocator, literal) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) ![]const u8 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getTextDefault({s});
                    \\        }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getText();
                    \\        }}
                    \\
                , .{index});
            }
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, new_value: []const u8) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setText({}, new_value);
                \\        }}
                \\
            , .{index});
        },
        .data => {
            const default_literal = if (field.default_literal) |literal| try zigDataLiteralAlloc(allocator, literal, field.default_is_hex_data) else null;
            defer if (default_literal) |literal| allocator.free(literal);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) ![]const u8 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            if (default_literal) |literal| {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getDataDefault({s});
                    \\        }}
                    \\
                , .{ index, literal });
            } else {
                try appendFmt(allocator, out,
                    \\            return (try self.builder.getPointerField({})).getData();
                    \\        }}
                    \\
                , .{index});
            }
            try appendFmt(allocator, out,
                \\        pub fn set_{s}(self: Builder, new_value: []const u8) !void {{
            , .{field_name});
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return self.builder.setData({}, new_value);
                \\        }}
                \\
            , .{index});
        },
        .list => |child| {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}_{s}_BuilderList {{
            , .{ field_name, owner_name, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return .{{ .list = try (try self.builder.getPointerField({})).getList({s}) }};
                \\        }}
                \\
            , .{ index, try listElementSizeLiteral(file, child.*) });

            try appendFmt(allocator, out,
                \\        pub fn set_{s}_from(self: Builder, new_value: {s}_{s}_List) !void {{
            , .{ field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyListFrom(new_value.list);
                \\        }}
                \\
                \\        pub fn disown_{s}_typed(self: Builder) !{s}_{s}_Orphan {{
            , .{ index, field_name, owner_name, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return {s}_{s}_Orphan.fromOrphan((try self.builder.getPointerField({})).disown());
                \\        }}
                \\
                \\        pub fn adopt_{s}_typed(self: Builder, orphan: *{s}_{s}_Orphan) !void {{
            , .{ owner_name, field_name, index, field_name, owner_name, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).adopt(&orphan.orphan);
                \\        }}
                \\
            , .{index});

            try emitListSliceSetter(allocator, out, file, field_name, field, index, child.*);

            if (isStructListElement(file, child.*)) |type_name| {
                const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
                defer allocator.free(zig_type);
                try appendFmt(allocator, out,
                    \\        pub fn init_{s}(self: Builder, count: usize) !{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionActivation(allocator, out, field);
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).initStructList(count, {s}.size) }};
                    \\        }}
                    \\
                , .{ index, zig_type });
            } else {
                try appendFmt(allocator, out,
                    \\        pub fn init_{s}(self: Builder, count: usize) !{s}_{s}_BuilderList {{
                , .{ field_name, owner_name, field_name });
                try emitBuilderUnionActivation(allocator, out, field);
                try appendFmt(allocator, out,
                    \\            return .{{ .list = try (try self.builder.getPointerField({})).initList({s}, count) }};
                    \\        }}
                    \\
                , .{ index, try listElementSizeLiteral(file, child.*) });
            }
        },
        .any_pointer => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.PointerBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return self.builder.getPointerField({});
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
                \\        pub fn init_{s}_struct(self: Builder, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStruct(struct_size);
                \\        }}
                \\
                \\        pub fn init_{s}_list(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initList(element_size, count);
                \\        }}
                \\
                \\        pub fn init_{s}_structList(self: Builder, count: usize, struct_size: cpz.StructSize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStructList(count, struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_structOrphan(self: Builder, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStruct(struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_listOrphan(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.Orphan {{
                \\            return self.orphanage().newList(element_size, count);
                \\        }}
                \\
                \\        pub fn new_{s}_structListOrphan(self: Builder, count: usize, struct_size: cpz.StructSize) !cpz.Orphan {{
                \\            return self.orphanage().newStructList(count, struct_size);
                \\        }}
                \\
                \\        pub fn new_{s}_copyOrphan(self: Builder, new_value: cpz.PointerReader) !cpz.Orphan {{
                \\            return self.orphanage().newCopyPointer(new_value);
                \\        }}
                \\
            , .{ index, field_name, field_name, field_name, field_name });
        },
        .any_struct => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.StructBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getStruct();
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder, struct_size: cpz.StructSize) !cpz.StructBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initStruct(struct_size);
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: cpz.StructReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFrom(new_value);
                \\        }}
                \\
                \\        pub fn get_{s}PointerSection(self: Builder) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try (try self.builder.getPointerField({})).getStruct()).pointerSectionAsList();
                \\        }}
                \\
                \\        pub fn get_{s}DataSection(self: Builder) ![]u8 {{
            , .{ index, field_name });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try (try self.builder.getPointerField({})).getStruct()).dataSectionBytes();
                \\        }}
                \\
            , .{index});
        },
        .any_list => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !cpz.ListBuilder {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getList(null);
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder, element_size: cpz.ElementSize, count: usize) !cpz.ListBuilder {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).initList(element_size, count);
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: cpz.PointerReader) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyFrom(new_value);
                \\        }}
                \\
            , .{index});
        },
        .capability => {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !u32 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
            , .{index});
        },
        .named => |type_name| if (findInterface(file, type_name) != null) {
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !u32 {{
            , .{field_name});
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).getCapabilityIndex();
                \\        }}
                \\
                \\        pub fn set_{s}(self: Builder, new_value: u32) !void {{
            , .{ index, field_name });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            (try self.builder.getPointerField({})).setCapability(new_value);
                \\        }}
                \\
            , .{index});
        } else {
            const zig_type = try zigTypeRefAlloc(allocator, file, type_name);
            defer allocator.free(zig_type);
            try appendFmt(allocator, out,
                \\        pub fn get_{s}(self: Builder) !{s}.Builder {{
            , .{ field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).getStruct());
                \\        }}
                \\
                \\        pub fn init_{s}(self: Builder) !{s}.Builder {{
            , .{ zig_type, index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return {s}.Builder.fromBuilder(try (try self.builder.getPointerField({})).initStruct({s}.size));
                \\        }}
                \\
                \\        pub fn set_{s}_from(self: Builder, new_value: {s}) !void {{
            , .{ zig_type, index, zig_type, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).copyStructFrom(new_value.reader);
                \\        }}
                \\
                \\        pub fn disown_{s}_typed(self: Builder) !{s}.Orphan {{
            , .{ index, field_name, zig_type });
            try emitBuilderUnionCheck(allocator, out, union_layout, field.union_discriminant);
            try appendFmt(allocator, out,
                \\            return {s}.Orphan.fromOrphan((try self.builder.getPointerField({})).disown());
                \\        }}
                \\
                \\        pub fn adopt_{s}_typed(self: Builder, orphan: *{s}.Orphan) !void {{
            , .{ zig_type, index, field_name, zig_type });
            try emitBuilderUnionActivation(allocator, out, field);
            try appendFmt(allocator, out,
                \\            return (try self.builder.getPointerField({})).adopt(&orphan.orphan);
                \\        }}
                \\
            , .{index});
        },
        else => return error.UnsupportedType,
    }
}

fn emitBuilderUnionCheck(allocator: std.mem.Allocator, out: *std.ArrayList(u8), union_layout: ?UnionLayout, discriminant: u16) std.mem.Allocator.Error!void {
    if (union_layout) |u| {
        try appendFmt(allocator, out,
            \\            if (try self.builder.getUInt16({}, 0) != {}) return error.InactiveUnionField;
            \\
        , .{ u.discriminant_byte, discriminant });
    }
}

fn emitBuilderUnionActivation(allocator: std.mem.Allocator, out: *std.ArrayList(u8), field: *const Field) std.mem.Allocator.Error!void {
    if (field.union_index) |union_index| {
        try appendFmt(allocator, out,
            \\            try self.activateUnion{}({});
            \\
        , .{ union_index, field.union_discriminant });
    }
}

fn listElementSizeLiteral(file: *const File, ty: Type) LayoutError![]const u8 {
    return switch (resolveType(file, ty)) {
        .void => ".void",
        .bool => ".bit",
        .int8, .uint8 => ".byte",
        .int16, .uint16 => ".two_bytes",
        .int32, .uint32, .float32 => ".four_bytes",
        .int64, .uint64, .float64 => ".eight_bytes",
        .text, .data, .any_pointer, .any_struct, .any_list, .capability, .list => ".pointer",
        .optional => ".pointer",
        .named => |name| if (findEnum(file, name) != null) ".two_bytes" else if (findInterface(file, name) != null) ".pointer" else ".composite",
    };
}

fn isStructListElement(file: *const File, ty: Type) ?[]const u8 {
    return switch (resolveType(file, ty)) {
        .named => |name| if (findEnumDirect(file, name) == null and findInterfaceDirect(file, name) == null) name else null,
        else => null,
    };
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) std.mem.Allocator.Error!void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn zigTypeRefAlloc(allocator: std.mem.Allocator, file: *const File, raw: []const u8) std.mem.Allocator.Error![]u8 {
    if (try importedTypeRefAlloc(allocator, file, raw)) |imported| return imported;
    const ident = try zigIdentAlloc(allocator, raw);
    defer allocator.free(ident);
    return std.fmt.allocPrint(allocator, "@\"cpz.schema\".{s}", .{ident});
}

fn importedTypeRefAlloc(allocator: std.mem.Allocator, file: *const File, raw: []const u8) std.mem.Allocator.Error!?[]u8 {
    const dot = std.mem.indexOfScalar(u8, raw, '.');
    const head = if (dot) |index| raw[0..index] else raw;
    const tail = if (dot) |index| raw[index + 1 ..] else null;
    for (file.imports) |import_decl| {
        if (!std.mem.eql(u8, import_decl.name, head)) continue;

        const imported_raw = if (import_decl.member) |member| blk: {
            if (tail) |suffix| {
                break :blk try std.fmt.allocPrint(allocator, "{s}.{s}", .{ member, suffix });
            }
            break :blk try allocator.dupe(u8, member);
        } else blk: {
            const suffix = tail orelse return null;
            break :blk try allocator.dupe(u8, suffix);
        };
        defer allocator.free(imported_raw);

        const module_literal = try zigStringLiteralAlloc(allocator, import_decl.name);
        defer allocator.free(module_literal);
        const imported_ident = try zigIdentAlloc(allocator, imported_raw);
        defer allocator.free(imported_ident);
        return try std.fmt.allocPrint(allocator, "@import({s}).{s}", .{ module_literal, imported_ident });
    }
    return null;
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

fn zigDataLiteralAlloc(allocator: std.mem.Allocator, raw: []const u8, is_hex: bool) LayoutError![]u8 {
    if (!is_hex) return zigStringLiteralAlloc(allocator, raw);

    var bytes = std.ArrayList(u8).empty;
    errdefer bytes.deinit(allocator);
    var high_nibble: ?u8 = null;
    for (raw) |c| {
        switch (c) {
            ' ', '\t', '\n', '\r' => continue,
            else => {},
        }
        const value = hexValue(c) orelse return error.InvalidToken;
        if (high_nibble) |high| {
            try bytes.append(allocator, (high << 4) | value);
            high_nibble = null;
        } else {
            high_nibble = value;
        }
    }
    if (high_nibble != null) return error.InvalidToken;
    const decoded = try bytes.toOwnedSlice(allocator);
    defer allocator.free(decoded);
    return zigStringLiteralAlloc(allocator, decoded);
}

fn hexValue(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
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
        else => if (c < 0x20 or c >= 0x7f) {
            try appendFmt(allocator, out, "\\x{X:0>2}", .{c});
        } else {
            try out.append(allocator, c);
        },
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
        "u32",       "u64",       "u128",
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

fn defaultFloatLiteral(field: *const Field, comptime zig_type: []const u8) []const u8 {
    const literal = field.default_literal orelse return "0";
    const unsigned = if (std.mem.startsWith(u8, literal, "+")) literal[1..] else literal;
    if (std.mem.eql(u8, unsigned, "inf")) return if (std.mem.eql(u8, zig_type, "f32")) "std.math.inf(f32)" else "std.math.inf(f64)";
    if (std.mem.eql(u8, unsigned, "-inf")) return if (std.mem.eql(u8, zig_type, "f32")) "-std.math.inf(f32)" else "-std.math.inf(f64)";
    if (std.mem.eql(u8, unsigned, "nan")) return if (std.mem.eql(u8, zig_type, "f32")) "std.math.nan(f32)" else "std.math.nan(f64)";
    return unsigned;
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
    try std.testing.expect(std.mem.indexOf(u8, code, "std.enums.fromInt(@\"cpz.schema\".Color, self.reader.getUInt16(6, 1))") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn favorite_raw(self: @This()) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_favorite(self: Builder) !@\"cpz.schema\".Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_favorite_raw(self: Builder) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_favorite_raw(self: Builder, new_value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getTextDefault(\"Anon\")") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Person.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_scores_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "!Person_children_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @\"cpz.schema\".Person.fromReader(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_friend(self: Builder) !@\"cpz.schema\".Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn init_friend(self: Builder) !@\"cpz.schema\".Person.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@\"cpz.schema\".Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_scores_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.getUInt32(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt32(index, new_value);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_children_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @\"cpz.schema\".Person.Builder.fromBuilder(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyFromReader(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getPointerElement(index)).getText();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.clearPointerElement(index);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return (try self.list.getStructElement(index)).clear();") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_List") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return std.enums.fromInt(@\"cpz.schema\".Color, self.list.getUInt16(index)) orelse error.InvalidEnumValue;") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), index: usize) u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getRaw(self: @This(), index: usize) !u16") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn setRaw(self: @This(), index: usize, new_value: u16) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "Person_palette_BuilderList") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.list.setUInt16(index, @intFromEnum(new_value));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(count, @\"cpz.schema\".Person.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Builder = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_id(self: Builder) !u32") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_id(self: Builder, new_value: u32) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setUInt32(0, new_value, 42);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return self.builder.setBool(32, new_value, true);") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn has_name(self: Builder) !bool") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn get_name(self: Builder) ![]const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_name(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_name(self: Builder, new_value: []const u8) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_friend(self: Builder) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_friend_from(self: Builder, new_value: @\"cpz.schema\".Person) !void") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "copyStructFrom(new_value.reader)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn clear_scores(self: Builder) !void") != null);
}

test "schema code generator emits external import type references" {
    const source =
        \\using Other = import "other.capnp";
        \\using import "common.capnp".Shared;
        \\struct Holder {
        \\  external @0 :Other.External;
        \\  shared @1 :Shared;
        \\  externalList @2 :List(Other.External);
        \\}
    ;
    var file = try parse(std.testing.allocator, source);
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZig(std.testing.allocator, &file, &layouts);
    defer std.testing.allocator.free(code);

    try std.testing.expect(std.mem.indexOf(u8, code, "@import(\"Other\").External.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@import(\"Shared\").Shared.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@import(\"Other\").External.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStruct(@import(\"Shared\").Shared.size)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return @import(\"Other\").External.fromReader(try self.list.getStructElement(index));") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "initStructList(count, @import(\"Other\").External.size)") != null);
}

test "schema code generator can wrap declarations in a namespace" {
    var file = try parse(std.testing.allocator,
        \\struct Demo {
        \\  id @0 :UInt32;
        \\}
    );
    defer file.deinit(std.testing.allocator);
    var layouts = try planLayouts(std.testing.allocator, &file);
    defer layouts.deinit(std.testing.allocator);
    const code = try generateZigWithOptions(std.testing.allocator, &file, &layouts, .{ .namespace = "my.api" });
    defer std.testing.allocator.free(code);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const my_api = struct {") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Demo = struct") != null);
    try std.testing.expect(std.mem.endsWith(u8, std.mem.trimEnd(u8, code, "\n"), "};"));
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
    const hex_literal = try zigDataLiteralAlloc(std.testing.allocator, "62 61 72 00 ff", true);
    defer std.testing.allocator.free(hex_literal);
    try std.testing.expectEqualStrings("\"bar\\x00\\xFF\"", hex_literal);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "!@\"cpz.schema\".Outer_Inner") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Outer_Inner.fromReader") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Outer_Inner.Builder") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "@\"cpz.schema\".Outer_Inner.size") != null);
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn enum_(self: @This()) !@\"cpz.schema\".error_") != null);
}

test "schema code generator rejects sanitized Zig name collisions" {
    {
        var file = try parse(std.testing.allocator,
            \\struct error {
            \\  id @0 :UInt32;
            \\}
            \\struct error_ {
            \\  id @0 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\struct Fields {
            \\  error @0 :UInt32;
            \\  error_ @1 :UInt32;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
    {
        var file = try parse(std.testing.allocator,
            \\enum Values {
            \\  test @0;
            \\  test_ @1;
            \\}
        );
        defer file.deinit(std.testing.allocator);
        var layouts = try planLayouts(std.testing.allocator, &file);
        defer layouts.deinit(std.testing.allocator);
        try std.testing.expectError(error.NameCollision, generateZig(std.testing.allocator, &file, &layouts));
    }
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
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn color(self: @This()) !@\"cpz.schema\".Color") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "getUInt16(0, 1)") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn set_color(self: Builder, new_value: @\"cpz.schema\".Color) !void") != null);
}
