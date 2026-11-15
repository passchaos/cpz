const std = @import("std");
const zig_names = @import("../zig_names.zig");

const mod_layout = @import("layout.zig");
const mod_resolve = @import("resolve.zig");
const mod_types = @import("types.zig");

const zigNamesEqual = zig_names.zigNamesEqual;
const appendUnionFields = mod_layout.appendUnionFields;
const checkedUnionIndex = mod_layout.checkedUnionIndex;
const putFieldName = mod_layout.putFieldName;
const unionDeclsFromBuilders = mod_layout.unionDeclsFromBuilders;
const validateStructMemberOrdinals = mod_layout.validateStructMemberOrdinals;
const anonymousAliasName = mod_resolve.anonymousAliasName;
const anonymousAliasNameFromRaw = mod_resolve.anonymousAliasNameFromRaw;
const capitalizedImportNameAlloc = mod_resolve.capitalizedImportNameAlloc;
const defaultLiteralCanBeReference = mod_resolve.defaultLiteralCanBeReference;
const defaultLiteralIsSignedNumber = mod_resolve.defaultLiteralIsSignedNumber;
const hexBytesAlloc = mod_resolve.hexBytesAlloc;
const importNameFromPath = mod_resolve.importNameFromPath;
const isBuiltinSchemaTypeName = mod_resolve.isBuiltinSchemaTypeName;
const isGroupType = mod_resolve.isGroupType;
const isIdentContinue = mod_resolve.isIdentContinue;
const isIdentStart = mod_resolve.isIdentStart;
const isNumberContinue = mod_resolve.isNumberContinue;
const isSchemaIdentifier = mod_resolve.isSchemaIdentifier;
const isSimpleConstType = mod_resolve.isSimpleConstType;
const parseFloatLiteral = mod_resolve.parseFloatLiteral;
const parseInlineConstListElementsAlloc = mod_resolve.parseInlineConstListElementsAlloc;
const parseInteger = mod_resolve.parseInteger;
const parseSignedLiteral = mod_resolve.parseSignedLiteral;
const parseUnsignedLiteral = mod_resolve.parseUnsignedLiteral;
const typeAcceptsDataLiteral = mod_resolve.typeAcceptsDataLiteral;
const typeAcceptsTextLiteral = mod_resolve.typeAcceptsTextLiteral;
const typeNameEqualsCanonical = mod_resolve.typeNameEqualsCanonical;
const AliasDecl = mod_types.AliasDecl;
const AnnotationDecl = mod_types.AnnotationDecl;
const AnnotationTargets = mod_types.AnnotationTargets;
const ConstDecl = mod_types.ConstDecl;
const ConstListItem = mod_types.ConstListItem;
const ConstStructField = mod_types.ConstStructField;
const EnumDecl = mod_types.EnumDecl;
const EnumValue = mod_types.EnumValue;
const Error = mod_types.Error;
const Field = mod_types.Field;
const File = mod_types.File;
const GroupDecl = mod_types.GroupDecl;
const ImportDecl = mod_types.ImportDecl;
const InterfaceDecl = mod_types.InterfaceDecl;
const InterfaceMethod = mod_types.InterfaceMethod;
const MethodField = mod_types.MethodField;
const Struct = mod_types.Struct;
const Type = mod_types.Type;
const UnionBuilder = mod_types.UnionBuilder;
const allAnnotationTargets = mod_types.allAnnotationTargets;
const deinitConstListItems = mod_types.deinitConstListItems;
const typesEqual = mod_types.typesEqual;

pub fn parseConstStructFieldsAlloc(allocator: std.mem.Allocator, expression: []const u8) Error![]ConstStructField {
    const source = std.mem.trim(u8, expression, " \t\r\n");
    var index = try skipTriviaIndex(source, 0);
    if (index >= source.len or source[index] != '(') return error.UnexpectedToken;
    index += 1;

    var fields = std.ArrayList(ConstStructField).empty;
    errdefer fields.deinit(allocator);
    var names = std.StringHashMap(void).init(allocator);
    defer names.deinit();

    while (true) {
        index = try skipTriviaIndex(source, index);
        if (index >= source.len) return error.UnexpectedToken;
        if (source[index] == ')') {
            index += 1;
            break;
        }
        if (!isIdentStart(source[index])) return error.UnexpectedToken;
        const name_start = index;
        index += 1;
        while (index < source.len and isIdentContinue(source[index])) index += 1;
        const name = source[name_start..index];
        const entry = try names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;

        index = try skipTriviaIndex(source, index);
        if (index >= source.len or source[index] != '=') return error.UnexpectedToken;
        index += 1;
        index = try skipTriviaIndex(source, index);
        const literal_start = index;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var brace_depth: usize = 0;
        while (index < source.len) {
            switch (source[index]) {
                '"' => {
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
                    if (index > source.len) return error.UnexpectedToken;
                    continue;
                },
                '#' => {
                    index = skipLineCommentIndex(source, index);
                    continue;
                },
                '/' => {
                    const next = try skipRawSlashIndex(source, index);
                    if (next != index + 1) {
                        index = next;
                        continue;
                    }
                    index = next;
                    continue;
                },
                '(' => {
                    paren_depth += 1;
                    index += 1;
                    continue;
                },
                ')' => {
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) break;
                    if (paren_depth != 0) paren_depth -= 1;
                    index += 1;
                    continue;
                },
                '[' => {
                    bracket_depth += 1;
                    index += 1;
                    continue;
                },
                ']' => {
                    if (bracket_depth != 0) bracket_depth -= 1;
                    index += 1;
                    continue;
                },
                '{' => {
                    brace_depth += 1;
                    index += 1;
                    continue;
                },
                '}' => {
                    if (brace_depth != 0) brace_depth -= 1;
                    index += 1;
                    continue;
                },
                ',' => if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) break,
                else => {},
            }
            index += 1;
        }
        const literal = std.mem.trim(u8, source[literal_start..index], " \t\r\n");
        if (literal.len == 0) return error.UnexpectedToken;
        try fields.append(allocator, .{ .index = fields.items.len, .name = name, .literal = literal });

        index = try skipTriviaIndex(source, index);
        if (index >= source.len) return error.UnexpectedToken;
        if (source[index] == ',') {
            index += 1;
            index = try skipTriviaIndex(source, index);
            if (index >= source.len) return error.UnexpectedToken;
            if (source[index] == ')') {
                index += 1;
                break;
            }
            continue;
        }
        if (source[index] == ')') {
            index += 1;
            break;
        }
        return error.UnexpectedToken;
    }

    index = try skipTriviaIndex(source, index);
    if (index != source.len) return error.UnexpectedToken;
    return fields.toOwnedSlice(allocator);
}

pub const TokenTag = enum {
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
    star,
    integer,
    string,
    eof,
};

pub const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    start: usize = 0,
    end: usize = 0,
};

pub fn skipLineCommentIndex(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n') index += 1;
    return index;
}

pub fn skipBlockCommentIndexOrNull(source: []const u8, start: usize) ?usize {
    var index = start + 2;
    while (index + 1 < source.len) : (index += 1) {
        if (source[index] == '*' and source[index + 1] == '/') return index + 2;
    }
    return null;
}

pub fn skipBlockCommentIndex(source: []const u8, start: usize) Error!usize {
    return skipBlockCommentIndexOrNull(source, start) orelse error.InvalidToken;
}

pub fn skipRawSlashIndex(source: []const u8, start: usize) Error!usize {
    if (start + 1 < source.len and source[start + 1] == '/') return skipLineCommentIndex(source, start + 2);
    if (start + 1 < source.len and source[start + 1] == '*') return try skipBlockCommentIndex(source, start);
    return start + 1;
}

pub fn skipRawStringIndex(source: []const u8, start: usize) Error!usize {
    if (start + 2 < source.len and source[start + 1] == '"' and source[start + 2] == '"') {
        var index = start + 3;
        while (index + 2 < source.len and !(source[index] == '"' and source[index + 1] == '"' and source[index + 2] == '"')) : (index += 1) {}
        if (index + 2 >= source.len) return error.UnexpectedToken;
        return index + 3;
    }

    var index = start + 1;
    while (index < source.len) {
        if (source[index] == '\\') {
            index += 2;
        } else if (source[index] == '"') {
            return index + 1;
        } else {
            index += 1;
        }
    }
    return error.UnexpectedToken;
}

pub fn skipRawStringOrCommentIndex(source: []const u8, start: usize) Error!?usize {
    return switch (source[start]) {
        '`' => skipLineCommentIndex(source, start),
        '"' => try skipRawStringIndex(source, start),
        '#' => skipLineCommentIndex(source, start),
        '/' => if (start + 1 < source.len and (source[start + 1] == '/' or source[start + 1] == '*'))
            try skipRawSlashIndex(source, start)
        else
            null,
        else => null,
    };
}

pub fn skipRawStringOrCommentInPostLoop(source: []const u8, index: *usize) Error!bool {
    if (try skipRawStringOrCommentIndex(source, index.*)) |next| {
        index.* = if (next == 0) 0 else next - 1;
        return true;
    }
    return false;
}

pub fn skipTriviaIndex(source: []const u8, start: usize) Error!usize {
    var index = start;
    while (index < source.len) {
        switch (source[index]) {
            ' ', '\t', '\r', '\n' => index += 1,
            '#' => index = skipLineCommentIndex(source, index),
            '/' => {
                if (index + 1 < source.len and source[index + 1] == '/') {
                    index = skipLineCommentIndex(source, index + 2);
                } else if (index + 1 < source.len and source[index + 1] == '*') {
                    index = try skipBlockCommentIndex(source, index);
                } else {
                    return index;
                }
            },
            else => return index,
        }
    }
    return index;
}

pub fn skipTriviaIndexOrNull(source: []const u8, start: usize) ?usize {
    var index = start;
    while (index < source.len) {
        switch (source[index]) {
            ' ', '\t', '\r', '\n' => index += 1,
            '#' => index = skipLineCommentIndex(source, index),
            '/' => {
                if (index + 1 < source.len and source[index + 1] == '/') {
                    index = skipLineCommentIndex(source, index + 2);
                } else if (index + 1 < source.len and source[index + 1] == '*') {
                    index = skipBlockCommentIndexOrNull(source, index) orelse return null;
                } else {
                    return index;
                }
            },
            else => return index,
        }
    }
    return index;
}

pub const Lexer = struct {
    source: []const u8,
    index: usize = 0,

    pub fn next(self: *Lexer) Error!Token {
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
            '*' => .{ .tag = .star, .lexeme = self.source[start..self.index] },
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
                            break :blk .{ .tag = .string, .lexeme = content, .start = start, .end = self.index };
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

    pub fn skipSpaceAndComments(self: *Lexer) Error!void {
        self.index = try skipTriviaIndex(self.source, self.index);
    }
};

/// Recursive-descent parser for the supported Cap'n Proto schema subset.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    lookahead: Token,
    parsed_structs: ?*std.ArrayList(Struct) = null,
    parsed_enums: ?*std.ArrayList(EnumDecl) = null,
    parsed_interfaces: ?*std.ArrayList(InterfaceDecl) = null,
    parsed_annotations: ?*std.ArrayList(AnnotationDecl) = null,
    parsed_imports: ?*std.ArrayList(ImportDecl) = null,
    parsed_decl_names: ?*std.StringHashMap(void) = null,
    parsed_decl_ids: ?*std.AutoHashMap(u64, void) = null,
    literal_scratch: std.ArrayList([]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Error!Parser {
        var lexer: Lexer = .{ .source = source };
        const first = try lexer.next();
        return .{ .allocator = allocator, .lexer = lexer, .lookahead = first };
    }

    pub fn deinitLiteralScratch(self: *Parser) void {
        for (self.literal_scratch.items) |literal| self.allocator.free(literal);
        self.literal_scratch.deinit(self.allocator);
    }

    pub fn takeOwnedLiteral(self: *Parser, literal: []const u8) bool {
        for (self.literal_scratch.items, 0..) |owned, index| {
            if (owned.ptr == literal.ptr and owned.len == literal.len) {
                _ = self.literal_scratch.swapRemove(index);
                return true;
            }
        }
        return false;
    }

    pub fn ownsScratchLiteral(self: *const Parser, literal: []const u8) bool {
        for (self.literal_scratch.items) |owned| {
            if (owned.ptr == literal.ptr and owned.len == literal.len) return true;
        }
        return false;
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
        var consts = std.ArrayList(ConstDecl).empty;
        errdefer {
            for (consts.items) |*c| c.deinit(self.allocator);
            consts.deinit(self.allocator);
        }
        var imports = std.ArrayList(ImportDecl).empty;
        errdefer imports.deinit(self.allocator);
        var interfaces = std.ArrayList(InterfaceDecl).empty;
        errdefer {
            for (interfaces.items) |*i| i.deinit(self.allocator);
            interfaces.deinit(self.allocator);
        }
        var annotations = std.ArrayList(AnnotationDecl).empty;
        errdefer {
            for (annotations.items) |*a| a.deinit(self.allocator);
            annotations.deinit(self.allocator);
        }
        var raw_file_annotations = std.ArrayList([]const u8).empty;
        errdefer raw_file_annotations.deinit(self.allocator);
        var decl_names = std.StringHashMap(void).init(self.allocator);
        defer decl_names.deinit();
        var decl_ids = std.AutoHashMap(u64, void).init(self.allocator);
        defer decl_ids.deinit();
        var file_id: ?u64 = null;
        var saw_top_level_declaration = false;
        self.parsed_structs = &structs;
        self.parsed_enums = &enums;
        self.parsed_interfaces = &interfaces;
        self.parsed_annotations = &annotations;
        self.parsed_imports = &imports;
        self.parsed_decl_names = &decl_names;
        self.parsed_decl_ids = &decl_ids;
        defer {
            self.parsed_structs = null;
            self.parsed_enums = null;
            self.parsed_interfaces = null;
            self.parsed_annotations = null;
            self.parsed_imports = null;
            self.parsed_decl_names = null;
            self.parsed_decl_ids = null;
        }

        while (self.lookahead.tag != .eof) {
            if (try self.eatKeyword("struct")) {
                saw_top_level_declaration = true;
                var decl = try self.parseStruct(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedStruct(decl);
                keep = true;
            } else if (try self.eatKeyword("enum")) {
                saw_top_level_declaration = true;
                var decl = try self.parseEnum(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedEnum(decl);
                keep = true;
            } else if (try self.eatKeyword("interface")) {
                saw_top_level_declaration = true;
                var decl = try self.parseInterfaceDeclaration(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedInterface(decl);
                keep = true;
            } else if (try self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, &imports, &decl_names);
            } else if (try self.eatKeyword("const")) {
                saw_top_level_declaration = true;
                try self.parseConstOrSkip(&consts, &decl_names);
            } else if (try self.eatKeyword("annotation")) {
                saw_top_level_declaration = true;
                var decl = try self.parseAnnotationDeclaration(null);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.appendParsedAnnotation(decl);
                keep = true;
            } else if (self.lookahead.tag == .dollar) {
                saw_top_level_declaration = true;
                try raw_file_annotations.append(self.allocator, try self.takeAnnotationSuffixUntilSemicolon());
            } else if (self.lookahead.tag == .at) {
                if (saw_top_level_declaration) return error.UnexpectedToken;
                if (file_id != null) return error.OrdinalCollision;
                file_id = try self.parseFileId();
                try self.registerDeclarationId(file_id);
            } else {
                return error.UnexpectedToken;
            }
        }

        return .{
            .id = file_id,
            .annotations_raw = try raw_file_annotations.toOwnedSlice(self.allocator),
            .structs = try structs.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
            .consts = try consts.toOwnedSlice(self.allocator),
            .imports = try imports.toOwnedSlice(self.allocator),
            .interfaces = try interfaces.toOwnedSlice(self.allocator),
            .annotations = try annotations.toOwnedSlice(self.allocator),
        };
    }

    const QualifiedName = struct {
        name: []const u8,
        owns_name: bool = false,
    };

    pub fn parseInterfaceDeclaration(self: *Parser, name_prefix: ?[]const u8) Error!InterfaceDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const parameters = try self.parseDeclarationParameters(local_name);
        errdefer self.allocator.free(parameters);
        const superclasses = try self.parseInterfaceExtendsOrEmpty();
        errdefer {
            for (superclasses) |*superclass| superclass.deinit(self.allocator);
            self.allocator.free(superclasses);
        }
        const annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        var aliases = std.ArrayList(AliasDecl).empty;
        errdefer {
            for (aliases.items) |*a| a.deinit(self.allocator);
            aliases.deinit(self.allocator);
        }
        var consts = std.ArrayList(ConstDecl).empty;
        errdefer {
            for (consts.items) |*c| c.deinit(self.allocator);
            consts.deinit(self.allocator);
        }
        var member_names = std.StringHashMap(void).init(self.allocator);
        defer member_names.deinit();
        try reserveParameterNames(parameters, &member_names);

        const methods = try self.parseInterfaceBody(qualified.name, &aliases, &consts, &member_names);
        errdefer self.allocator.free(methods);
        return .{
            .name = qualified.name,
            .owns_name = qualified.owns_name,
            .id = decl_id,
            .annotations = annotations,
            .parameters = parameters,
            .methods = methods,
            .superclasses = superclasses,
            .consts = try consts.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
        };
    }

    pub fn parseAnnotationDeclaration(self: *Parser, name_prefix: ?[]const u8) Error!AnnotationDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const targets = try self.parseAnnotationTargets();
        try self.expect(.colon);
        var ty = try self.parseType();
        errdefer ty.deinit(self.allocator);
        const annotations = try self.takeAnnotationSuffixUntilSemicolon();
        return .{ .name = qualified.name, .owns_name = qualified.owns_name, .id = decl_id, .annotations = annotations, .ty = ty, .targets = targets };
    }

    pub fn parseAnnotationTargets(self: *Parser) Error!AnnotationTargets {
        try self.expect(.l_paren);
        var targets: AnnotationTargets = .{};
        var saw_target = false;
        var saw_wildcard = false;
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if (self.lookahead.tag == .star) {
                if (saw_wildcard) return error.UnexpectedToken;
                if (saw_target) return error.UnexpectedToken;
                try self.expect(.star);
                targets = allAnnotationTargets();
                saw_wildcard = true;
            } else {
                if (saw_wildcard) return error.UnexpectedToken;
                const target = try self.expectIdentifier();
                if (!setAnnotationTarget(&targets, target)) return error.UnexpectedToken;
                saw_target = true;
            }

            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        if (!saw_target and !saw_wildcard) return error.UnexpectedToken;
        try self.expect(.r_paren);
        return targets;
    }

    pub fn setAnnotationTarget(targets: *AnnotationTargets, target: []const u8) bool {
        if (std.mem.eql(u8, target, "file")) return setAnnotationTargetFlag(&targets.file);
        if (std.mem.eql(u8, target, "const")) return setAnnotationTargetFlag(&targets.const_decl);
        if (std.mem.eql(u8, target, "enum")) return setAnnotationTargetFlag(&targets.enum_decl);
        if (std.mem.eql(u8, target, "enumerant")) return setAnnotationTargetFlag(&targets.enumerant);
        if (std.mem.eql(u8, target, "struct")) return setAnnotationTargetFlag(&targets.struct_decl);
        if (std.mem.eql(u8, target, "field")) return setAnnotationTargetFlag(&targets.field);
        if (std.mem.eql(u8, target, "union")) return setAnnotationTargetFlag(&targets.union_decl);
        if (std.mem.eql(u8, target, "group")) return setAnnotationTargetFlag(&targets.group);
        if (std.mem.eql(u8, target, "interface")) return setAnnotationTargetFlag(&targets.interface_decl);
        if (std.mem.eql(u8, target, "method")) return setAnnotationTargetFlag(&targets.method);
        if (std.mem.eql(u8, target, "param")) return setAnnotationTargetFlag(&targets.param);
        if (std.mem.eql(u8, target, "annotation")) return setAnnotationTargetFlag(&targets.annotation_decl);
        return false;
    }

    pub fn setAnnotationTargetFlag(flag: *bool) bool {
        if (flag.*) return false;
        flag.* = true;
        return true;
    }

    pub fn parseInterfaceExtendsOrEmpty(self: *Parser) Error![]Type {
        if (!self.isKeyword("extends")) return try self.allocator.alloc(Type, 0);
        try self.advance();
        try self.expect(.l_paren);
        var superclasses = std.ArrayList(Type).empty;
        errdefer {
            for (superclasses.items) |*superclass| superclass.deinit(self.allocator);
            superclasses.deinit(self.allocator);
        }
        if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            var superclass = try self.parseType();
            var keep_superclass = false;
            errdefer if (!keep_superclass) superclass.deinit(self.allocator);
            for (superclasses.items) |existing| {
                if (typesEqual(existing, superclass)) return error.NameCollision;
            }
            try superclasses.append(self.allocator, superclass);
            keep_superclass = true;
            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return superclasses.toOwnedSlice(self.allocator);
    }

    pub fn parseDeclarationParameters(self: *Parser, declaration_name: []const u8) Error![]const []const u8 {
        if (self.lookahead.tag != .l_paren) return try self.allocator.alloc([]const u8, 0);
        try self.expect(.l_paren);
        var parameters = std.ArrayList([]const u8).empty;
        errdefer parameters.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();
        if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
        while (self.lookahead.tag != .r_paren) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            const name = try self.expectIdentifier();
            if (std.mem.eql(u8, name, declaration_name)) return error.NameCollision;
            if (isBuiltinSchemaTypeName(name)) return error.NameCollision;
            const entry = try names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            for (parameters.items) |existing| {
                if (try zigNamesEqual(self.allocator, existing, name)) return error.NameCollision;
            }
            try parameters.append(self.allocator, name);
            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_paren) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_paren);
        return parameters.toOwnedSlice(self.allocator);
    }

    pub fn reserveParameterNames(parameters: []const []const u8, names: *std.StringHashMap(void)) Error!void {
        for (parameters) |parameter| {
            const entry = try names.getOrPut(parameter);
            if (entry.found_existing) return error.NameCollision;
        }
    }

    pub fn parseInterfaceBody(self: *Parser, interface_name: []const u8, aliases: *std.ArrayList(AliasDecl), consts: *std.ArrayList(ConstDecl), member_names: *std.StringHashMap(void)) Error![]InterfaceMethod {
        try self.skipUntil(.l_brace);
        try self.expect(.l_brace);

        var methods = std.ArrayList(InterfaceMethod).empty;
        errdefer {
            for (methods.items) |method| {
                self.allocator.free(method.parameters);
                self.allocator.free(method.param_fields);
                self.allocator.free(method.result_fields);
            }
            methods.deinit(self.allocator);
        }
        var method_names = std.StringHashMap(void).init(self.allocator);
        defer method_names.deinit();
        var occupied_ordinals = std.AutoHashMap(u16, void).init(self.allocator);
        defer occupied_ordinals.deinit();

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if (self.isKeyword("struct") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseStruct(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedStruct(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("enum") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseEnum(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedEnum(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("interface") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseInterfaceDeclaration(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedInterface(decl);
                keep = true;
                continue;
            }
            if (try self.eatKeyword("annotation")) {
                var decl = try self.parseAnnotationDeclaration(interface_name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(aliases, member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedAnnotation(decl);
                keep = true;
                continue;
            }
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.eatKeyword("using")) {
                try self.parseUsingOrSkip(aliases, self.parsed_imports, member_names);
                continue;
            }
            if (try self.eatKeyword("const")) {
                try self.parseConstOrSkip(consts, member_names);
                continue;
            }
            if (self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            if (self.lookahead.tag != .identifier) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            if ((try self.peekNext()).tag != .at) return error.UnexpectedToken;
            const name = try self.expectIdentifier();
            try self.expect(.at);
            const ordinal_u64 = try self.expectInteger();
            if (ordinal_u64 > std.math.maxInt(u16)) return error.InvalidOrdinal;
            const ordinal: u16 = @intCast(ordinal_u64);
            const member_entry = try member_names.getOrPut(name);
            if (member_entry.found_existing) return error.NameCollision;
            const name_entry = try method_names.getOrPut(name);
            if (name_entry.found_existing) return error.NameCollision;
            const ordinal_entry = try occupied_ordinals.getOrPut(ordinal);
            if (ordinal_entry.found_existing) return error.OrdinalCollision;
            const signature = try self.takeRawUntilSemicolon();
            const parts = try splitMethodSignature(signature);
            try validateAnnotationSuffix(parts.annotations);
            try self.validateMethodEndpointType(parts.params, false);
            try self.validateMethodEndpointType(parts.results, true);
            const parameters = try self.parseMethodSignatureParameters(name, member_names, signature);
            var keep_parameters = false;
            errdefer if (!keep_parameters) self.allocator.free(parameters);
            const param_fields = try self.parseMethodFields(parts.params);
            var keep_param_fields = false;
            errdefer if (!keep_param_fields) self.allocator.free(param_fields);
            try validateMethodParameterFieldNames(self.allocator, parameters, param_fields);
            const result_fields = try self.parseMethodFields(parts.results);
            var keep_result_fields = false;
            errdefer if (!keep_result_fields) self.allocator.free(result_fields);
            try validateMethodParameterFieldNames(self.allocator, parameters, result_fields);
            try methods.append(self.allocator, .{
                .name = name,
                .ordinal = ordinal,
                .signature = signature,
                .params_signature = parts.params,
                .results_signature = parts.results,
                .annotation_signature = parts.annotations,
                .params_type = methodSignatureTypeName(parts.params),
                .results_type = methodSignatureTypeName(parts.results),
                .is_streaming = std.mem.eql(u8, parts.results, "stream"),
                .parameters = parameters,
                .param_fields = param_fields,
                .result_fields = result_fields,
            });
            keep_parameters = true;
            keep_param_fields = true;
            keep_result_fields = true;
        }
        try self.expect(.r_brace);
        return methods.toOwnedSlice(self.allocator);
    }

    pub fn parseMethodSignatureParameters(self: *Parser, method_name: []const u8, member_names: *const std.StringHashMap(void), signature: []const u8) Error![]const []const u8 {
        var index = try skipTriviaIndex(signature, 0);
        if (index >= signature.len or signature[index] != '[') return try self.allocator.alloc([]const u8, 0);
        var parameters = std.ArrayList([]const u8).empty;
        errdefer parameters.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();

        index += 1;
        while (true) {
            index = try skipTriviaIndex(signature, index);
            if (index >= signature.len) return error.UnexpectedToken;
            if (signature[index] == ']' and parameters.items.len == 0) return error.UnexpectedToken;
            if (signature[index] == ']') return parameters.toOwnedSlice(self.allocator);
            if (!isIdentStart(signature[index])) return error.UnexpectedToken;
            const start = index;
            index += 1;
            while (index < signature.len and isIdentContinue(signature[index])) index += 1;
            const name = signature[start..index];
            if (std.mem.eql(u8, name, method_name)) return error.NameCollision;
            if (isBuiltinSchemaTypeName(name)) return error.NameCollision;
            if (member_names.contains(name)) return error.NameCollision;
            const entry = try names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            for (parameters.items) |existing| {
                if (try zigNamesEqual(self.allocator, existing, name)) return error.NameCollision;
            }
            try parameters.append(self.allocator, name);
            index = try skipTriviaIndex(signature, index);
            if (index >= signature.len) return error.UnexpectedToken;
            if (signature[index] == ',') {
                index += 1;
                index = try skipTriviaIndex(signature, index);
                if (index < signature.len and signature[index] == ']') return error.UnexpectedToken;
                continue;
            }
            if (signature[index] == ']') {
                return parameters.toOwnedSlice(self.allocator);
            }
            return error.UnexpectedToken;
        }
    }

    pub fn parseMethodFields(self: *Parser, raw: []const u8) Error![]const MethodField {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "stream")) return try self.allocator.alloc(MethodField, 0);
        if (trimmed[0] != '(') return try self.allocator.alloc(MethodField, 0);
        var end = trimmed.len;
        var scan: usize = 1;
        var list_depth: usize = 1;
        while (scan < trimmed.len) : (scan += 1) {
            if (try skipRawStringOrCommentInPostLoop(trimmed, &scan)) continue;
            switch (trimmed[scan]) {
                '(' => list_depth += 1,
                ')' => {
                    list_depth -= 1;
                    if (list_depth == 0) {
                        end = scan;
                        break;
                    }
                },
                else => {},
            }
        }
        if (list_depth != 0) return error.UnexpectedToken;
        // `splitMethodSignature()` hands us the whole endpoint slice before the
        // arrow.  Once the outer field-list parens close, only trivia may
        // remain; otherwise syntax like `(value :UInt32) junk -> ()` would be
        // accepted after silently ignoring `junk`.
        if (try skipTriviaIndex(trimmed, end + 1) != trimmed.len) return error.UnexpectedToken;
        var index: usize = 1;
        var fields = std.ArrayList(MethodField).empty;
        errdefer fields.deinit(self.allocator);
        var names = std.StringHashMap(void).init(self.allocator);
        defer names.deinit();

        while (index < end) {
            index = try skipTriviaIndex(trimmed, index);
            if (index >= end) break;
            if (trimmed[index] == ',') return error.UnexpectedToken;
            if (!isIdentStart(trimmed[index])) return error.UnexpectedToken;
            const name_start = index;
            index += 1;
            while (index < end and isIdentContinue(trimmed[index])) index += 1;
            const field_name = trimmed[name_start..index];
            const entry = try names.getOrPut(field_name);
            if (entry.found_existing) return error.NameCollision;
            index = try skipTriviaIndex(trimmed, index);
            if (index >= end or trimmed[index] != ':') return error.UnexpectedToken;
            index += 1;
            index = try skipTriviaIndex(trimmed, index);
            const type_start = index;
            var paren_depth: usize = 0;
            while (index < end) : (index += 1) {
                if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                switch (trimmed[index]) {
                    '(' => paren_depth += 1,
                    ')' => {
                        if (paren_depth != 0) {
                            paren_depth -= 1;
                        } else {
                            break;
                        }
                    },
                    ',' => if (paren_depth == 0) break,
                    '=' => if (paren_depth == 0) break,
                    '$' => if (paren_depth == 0) break,
                    else => {},
                }
            }
            const field_type_end = index;
            var default_literal: ?[]const u8 = null;
            var default_is_hex_data = false;
            var has_explicit_default = false;
            var annotations: []const u8 = "";
            if (index < end and trimmed[index] != ',' and trimmed[index] != '=') {
                const annotation_start = index;
                var annotation_paren_depth: usize = 0;
                var annotation_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
                    if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                    switch (trimmed[index]) {
                        '(' => annotation_paren_depth += 1,
                        ')' => {
                            if (annotation_paren_depth != 0) annotation_paren_depth -= 1;
                        },
                        '[' => annotation_bracket_depth += 1,
                        ']' => {
                            if (annotation_bracket_depth != 0) annotation_bracket_depth -= 1;
                        },
                        ',' => if (annotation_paren_depth == 0 and annotation_bracket_depth == 0) break,
                        '=' => if (annotation_paren_depth == 0 and annotation_bracket_depth == 0) break,
                        else => {},
                    }
                }
                annotations = std.mem.trim(u8, trimmed[annotation_start..index], " \t\r\n");
            }
            // Method field syntax mirrors regular fields: defaults belong before
            // annotations.  Reject `$ann = value` instead of silently treating
            // it as an annotation followed by a default.
            if (annotations.len != 0 and index < end and trimmed[index] == '=') return error.UnexpectedToken;
            const field_type = std.mem.trim(u8, trimmed[type_start..field_type_end], " \t\r\n");
            if (field_type.len == 0) return error.UnexpectedToken;
            var parsed_field_type = try self.parseRawTypeSyntax(field_type);
            defer parsed_field_type.deinit(self.allocator);
            if (index < end and trimmed[index] == '=') {
                has_explicit_default = true;
                index += 1;
                index = try skipTriviaIndex(trimmed, index);
                const default_start = index;
                var default_paren_depth: usize = 0;
                var default_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
                    if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                    switch (trimmed[index]) {
                        '(' => default_paren_depth += 1,
                        ')' => {
                            if (default_paren_depth != 0) {
                                default_paren_depth -= 1;
                            } else if (default_bracket_depth == 0) {
                                break;
                            }
                        },
                        '[' => default_bracket_depth += 1,
                        ']' => {
                            if (default_bracket_depth != 0) default_bracket_depth -= 1;
                        },
                        ',' => if (default_paren_depth == 0 and default_bracket_depth == 0) break,
                        '$' => if (default_paren_depth == 0 and default_bracket_depth == 0) break,
                        else => {},
                    }
                }
                default_literal = std.mem.trim(u8, trimmed[default_start..index], " \t\r\n");
                if (default_literal.?.len == 0) return error.UnexpectedToken;
                try self.validateDefaultLiteralForTypeSyntax(parsed_field_type, default_literal.?);
                if (parsed_field_type == .data) {
                    if (default_literal) |literal| {
                        default_is_hex_data = std.mem.startsWith(u8, literal, "0x\"");
                    }
                }
            }
            if (index < end and trimmed[index] != ',' and annotations.len == 0) {
                const annotation_start = index;
                var annotation_paren_depth: usize = 0;
                var annotation_bracket_depth: usize = 0;
                while (index < end) : (index += 1) {
                    if (try skipRawStringOrCommentInPostLoop(trimmed, &index)) continue;
                    switch (trimmed[index]) {
                        '(' => annotation_paren_depth += 1,
                        ')' => {
                            if (annotation_paren_depth != 0) annotation_paren_depth -= 1;
                        },
                        '[' => annotation_bracket_depth += 1,
                        ']' => {
                            if (annotation_bracket_depth != 0) annotation_bracket_depth -= 1;
                        },
                        ',' => if (annotation_paren_depth == 0 and annotation_bracket_depth == 0) break,
                        else => {},
                    }
                }
                annotations = std.mem.trim(u8, trimmed[annotation_start..index], " \t\r\n");
            }
            try validateAnnotationSuffix(annotations);
            try fields.append(self.allocator, .{ .index = fields.items.len, .name = field_name, .ty = field_type, .default_literal = default_literal, .default_is_hex_data = default_is_hex_data, .has_explicit_default = has_explicit_default, .annotations = annotations });
            index = try skipTriviaIndex(trimmed, index);
            if (index < end) {
                if (trimmed[index] != ',') return error.UnexpectedToken;
                index += 1;
                index = try skipTriviaIndex(trimmed, index);
                if (index >= end or trimmed[index] == ',') return error.UnexpectedToken;
            }
        }
        return fields.toOwnedSlice(self.allocator);
    }

    pub fn parseRawTypeSyntax(self: *Parser, raw: []const u8) Error!Type {
        var parser = try Parser.init(self.allocator, raw);
        defer parser.deinitLiteralScratch();
        parser.parsed_imports = self.parsed_imports;
        parser.parsed_decl_names = self.parsed_decl_names;
        var ty = try parser.parseType();
        errdefer ty.deinit(self.allocator);
        if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
        return ty;
    }

    pub fn validateRawTypeSyntax(self: *Parser, raw: []const u8) Error!void {
        var ty = try self.parseRawTypeSyntax(raw);
        defer ty.deinit(self.allocator);
    }

    pub fn validateDefaultLiteralSyntax(self: *Parser, expression: []const u8) Error!void {
        const raw = std.mem.trim(u8, expression, " \t\r\n");
        if (raw.len == 0) return error.UnexpectedToken;
        if (raw[0] == '(' or raw[0] == '[') return self.validateInlineAggregateDefaultSyntax(raw);
        if (std.mem.startsWith(u8, raw, "0x\"")) {
            const next = try skipRawStringIndex(raw, 2);
            if (next != raw.len) return error.UnexpectedToken;
            return;
        }

        var parser = try Parser.init(self.allocator, raw);
        defer parser.deinitLiteralScratch();
        _ = (try parser.expectDefaultLiteral()) orelse return error.UnexpectedToken;
        if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
    }

    pub fn validateDefaultLiteralForTypeSyntax(self: *Parser, ty: Type, expression: []const u8) Error!void {
        try self.validateDefaultLiteralSyntax(expression);
        const raw = std.mem.trim(u8, expression, " \t\r\n");
        if (raw.len == 0) return error.UnexpectedToken;

        switch (ty) {
            .optional => |child| {
                if (std.mem.eql(u8, raw, "null")) return;
                return self.validateDefaultLiteralForTypeSyntax(child.*, raw);
            },
            .void => {
                if (std.mem.eql(u8, raw, "void")) return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .bool => {
                if (std.mem.eql(u8, raw, "true") or std.mem.eql(u8, raw, "false")) return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .int8 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i8, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .int16 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i16, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .int32 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i32, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .int64 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseSignedLiteral(i64, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint8 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u8, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint16 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u16, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint32 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u32, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .uint64 => if (defaultLiteralIsSignedNumber(raw)) {
                if (parseUnsignedLiteral(u64, raw) == null) return error.UnexpectedToken;
            } else if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .float32 => if (parseFloatLiteral(f32, raw) == null and !defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .float64 => if (parseFloatLiteral(f64, raw) == null and !defaultLiteralCanBeReference(raw)) return error.UnexpectedToken,
            .text => {
                if (raw[0] == '"') return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .data => {
                if (std.mem.startsWith(u8, raw, "0x\"")) {
                    const decoded = hexBytesAlloc(self.allocator, raw[3 .. raw.len - 1]) catch |err| switch (err) {
                        error.OutOfMemory => return error.OutOfMemory,
                        error.InvalidToken => return error.UnexpectedToken,
                        else => return error.UnexpectedToken,
                    };
                    self.allocator.free(decoded);
                    return;
                }
                if (raw[0] == '"') return;
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .list => |child| {
                if (raw[0] == '[') {
                    try self.validateInlineListDefaultForTypeSyntax(child.*, raw);
                    return;
                }
                if (!defaultLiteralCanBeReference(raw)) return error.UnexpectedToken;
            },
            .named => |type_name| {
                if (raw[0] == '(') {
                    try self.validateStructDefaultForTypeSyntax(type_name, raw);
                    return;
                }
            },
            .any_pointer, .any_struct, .any_list, .capability => {},
        }
    }

    pub fn validateInlineListDefaultForTypeSyntax(self: *Parser, child_ty: Type, expression: []const u8) Error!void {
        const items = parseInlineConstListElementsAlloc(self.allocator, expression) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnexpectedToken => return error.UnexpectedToken,
            error.InvalidToken => return error.InvalidToken,
            else => return error.UnexpectedToken,
        };
        defer self.allocator.free(items);
        for (items) |item| {
            const split = splitDefaultExpressionAndAnnotations(item);
            try Parser.validateAnnotationSuffix(split.annotations);
            try self.validateDefaultLiteralForTypeSyntax(child_ty, split.default_expression);
        }
    }

    pub fn validateStructDefaultForTypeSyntax(self: *Parser, type_name: []const u8, expression: []const u8) Error!void {
        const struct_fields = try parseConstStructFieldsAlloc(self.allocator, expression);
        defer self.allocator.free(struct_fields);
        const struct_decl = self.parsedStructDirect(type_name) orelse {
            for (struct_fields) |field| try self.validateDefaultLiteralSyntax(field.literal);
            return;
        };

        for (struct_fields) |const_field| {
            if (structFieldByName(struct_decl, const_field.name)) |schema_field| {
                try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
                continue;
            }
            if (structHasFlattenedGroupName(struct_decl, const_field.name) and std.mem.trim(u8, const_field.literal, " \t\r\n")[0] == '(') {
                try self.validateFlattenedGroupDefaultForTypeSyntax(struct_decl, const_field.name, const_field.literal);
                continue;
            }
            const schema_field = structFieldByNameOrGroupFirst(struct_decl, const_field.name) orelse return error.UnexpectedToken;
            try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
        }
    }

    pub fn validateFlattenedGroupDefaultForTypeSyntax(self: *Parser, struct_decl: *const Struct, group_name: []const u8, expression: []const u8) Error!void {
        const struct_fields = try parseConstStructFieldsAlloc(self.allocator, expression);
        defer self.allocator.free(struct_fields);
        for (struct_fields) |const_field| {
            const flattened_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_name, const_field.name });
            defer self.allocator.free(flattened_name);
            if (structFieldByName(struct_decl, flattened_name)) |schema_field| {
                try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
                continue;
            }
            if (structHasFlattenedGroupName(struct_decl, flattened_name) and std.mem.trim(u8, const_field.literal, " \t\r\n")[0] == '(') {
                try self.validateFlattenedGroupDefaultForTypeSyntax(struct_decl, flattened_name, const_field.literal);
                continue;
            }
            const schema_field = structFieldByNameOrGroupFirst(struct_decl, flattened_name) orelse return error.UnexpectedToken;
            try self.validateDefaultLiteralForTypeSyntax(schema_field.ty, const_field.literal);
        }
    }

    pub fn parsedStructDirect(self: *const Parser, type_name: []const u8) ?*const Struct {
        const structs = self.parsed_structs orelse return null;
        for (structs.items) |*decl| {
            if (typeNameEqualsCanonical(type_name, decl.name)) return decl;
        }
        return null;
    }

    pub fn structFieldByName(decl: *const Struct, name: []const u8) ?*const Field {
        for (decl.fields) |*field| {
            if (std.mem.eql(u8, field.name, name)) return field;
        }
        return null;
    }

    pub fn structHasFlattenedGroupName(decl: *const Struct, name: []const u8) bool {
        for (decl.fields) |field| {
            if (field.name.len > name.len + 1 and
                std.mem.startsWith(u8, field.name, name) and
                field.name[name.len] == '_')
            {
                return true;
            }
        }
        return false;
    }

    pub fn structFieldByNameOrGroupFirst(decl: *const Struct, name: []const u8) ?*const Field {
        if (structFieldByName(decl, name)) |field| return field;
        for (decl.fields) |*field| {
            if (field.name.len > name.len + 1 and
                std.mem.startsWith(u8, field.name, name) and
                field.name[name.len] == '_')
            {
                return field;
            }
        }
        return null;
    }

    pub fn validateInlineAggregateDefaultSyntax(self: *Parser, expression: []const u8) Error!void {
        const raw = std.mem.trim(u8, expression, " \t\r\n");
        if (raw.len == 0) return error.UnexpectedToken;
        switch (raw[0]) {
            '(' => {
                const fields = try parseConstStructFieldsAlloc(self.allocator, raw);
                defer self.allocator.free(fields);
                for (fields) |field| try self.validateInlineAggregateDefaultSyntax(field.literal);
            },
            '[' => {
                const items = parseInlineConstListElementsAlloc(self.allocator, raw) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.UnexpectedToken => return error.UnexpectedToken,
                    error.InvalidToken => return error.InvalidToken,
                    else => return error.UnexpectedToken,
                };
                defer self.allocator.free(items);
                for (items) |item| try self.validateInlineAggregateDefaultSyntax(item);
            },
            else => {},
        }
    }

    pub fn validateMethodParameterFieldNames(allocator: std.mem.Allocator, parameters: []const []const u8, fields: []const MethodField) Error!void {
        for (fields, 0..) |field, index| {
            for (fields[index + 1 ..]) |other| {
                if (try zigNamesEqual(allocator, field.name, other.name)) return error.NameCollision;
            }
            for (parameters) |parameter| {
                if (std.mem.eql(u8, parameter, field.name)) return error.NameCollision;
                if (try zigNamesEqual(allocator, parameter, field.name)) return error.NameCollision;
            }
        }
    }

    pub fn methodSignatureTypeName(raw: []const u8) []const u8 {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '(' or std.mem.eql(u8, trimmed, "stream")) return "";
        return trimmed;
    }

    pub fn validateMethodEndpointType(self: *Parser, raw: []const u8, allow_stream: bool) Error!void {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '(') return;
        if (std.mem.eql(u8, trimmed, "stream")) {
            if (allow_stream) return;
            return error.UnexpectedToken;
        }
        var parser = try Parser.init(self.allocator, trimmed);
        defer parser.deinitLiteralScratch();
        var ty = try parser.parseType();
        defer ty.deinit(self.allocator);
        if (parser.lookahead.tag != .eof) return error.UnexpectedToken;
    }

    const MethodSignatureParts = struct {
        params: []const u8,
        results: []const u8,
        annotations: []const u8,
    };

    pub fn splitMethodSignature(signature: []const u8) Error!MethodSignatureParts {
        var index = try skipTriviaIndex(signature, 0);
        if (index < signature.len and signature[index] == '[') {
            var bracket_depth: usize = 1;
            index += 1;
            while (index < signature.len and bracket_depth != 0) : (index += 1) {
                if (try skipRawStringOrCommentInPostLoop(signature, &index)) continue;
                switch (signature[index]) {
                    '[' => bracket_depth += 1,
                    ']' => bracket_depth -= 1,
                    else => {},
                }
            }
            index = try skipTriviaIndex(signature, index);
        }
        const params_start = index;
        var paren_depth: usize = 0;
        while (index < signature.len) : (index += 1) {
            if (try skipRawStringOrCommentInPostLoop(signature, &index)) continue;
            switch (signature[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '-' => if (paren_depth == 0 and index + 1 < signature.len and signature[index + 1] == '>') {
                    const params = std.mem.trim(u8, signature[params_start..index], " \t\r\n");
                    if (params.len == 0) return error.UnexpectedToken;
                    const result_parts = try splitResultAndAnnotations(signature[index + 2 ..]);
                    if (result_parts.results.len == 0) return error.UnexpectedToken;
                    return .{ .params = params, .results = result_parts.results, .annotations = result_parts.annotations };
                },
                else => {},
            }
        }
        return splitNoResultMethodSignature(signature, params_start);
    }

    pub fn splitNoResultMethodSignature(signature: []const u8, params_start: usize) Error!MethodSignatureParts {
        // Cap'n Proto allows methods whose return type is implicit Void to omit
        // the `-> ()` suffix entirely (`done @0 ();`).  Treat this as an empty
        // result struct while still requiring the parameter endpoint to be a
        // normal parenthesized field list, so malformed `method @0 Type;`
        // remains rejected rather than becoming a new endpoint shorthand.
        var index = try skipTriviaIndex(signature, params_start);
        if (index >= signature.len or signature[index] != '(') return error.UnexpectedToken;
        var paren_depth: usize = 1;
        index += 1;
        while (index < signature.len and paren_depth != 0) : (index += 1) {
            if (try skipRawStringOrCommentInPostLoop(signature, &index)) continue;
            switch (signature[index]) {
                '(' => paren_depth += 1,
                ')' => paren_depth -= 1,
                else => {},
            }
        }
        if (paren_depth != 0) return error.UnexpectedToken;
        const params = std.mem.trim(u8, signature[params_start..index], " \t\r\n");
        if (params.len == 0) return error.UnexpectedToken;
        const annotations_start = try skipTriviaIndex(signature, index);
        return .{
            .params = params,
            .results = "()",
            .annotations = if (annotations_start >= signature.len) "" else std.mem.trim(u8, signature[annotations_start..], " \t\r\n"),
        };
    }

    pub fn splitResultAndAnnotations(raw: []const u8) Error!struct { results: []const u8, annotations: []const u8 } {
        const start = try skipTriviaIndex(raw, 0);
        if (start >= raw.len) return .{ .results = "", .annotations = "" };
        var index: usize = start;
        if (raw[index] == '(') {
            var paren_depth: usize = 1;
            index += 1;
            while (index < raw.len and paren_depth != 0) : (index += 1) {
                if (try skipRawStringOrCommentInPostLoop(raw, &index)) continue;
                switch (raw[index]) {
                    '(' => paren_depth += 1,
                    ')' => paren_depth -= 1,
                    else => {},
                }
            }
            const result_end = index;
            const annotations_start = try skipTriviaIndex(raw, result_end);
            return .{
                .results = std.mem.trim(u8, raw[start..result_end], " \t\r\n"),
                .annotations = std.mem.trim(u8, raw[annotations_start..], " \t\r\n"),
            };
        }
        var paren_depth: usize = 0;
        while (index < raw.len) {
            if (paren_depth == 0) {
                const next = try skipTriviaIndex(raw, index);
                if (next != index) {
                    if (next >= raw.len or raw[next] == '$') {
                        return .{
                            .results = std.mem.trim(u8, raw[start..index], " \t\r\n"),
                            .annotations = if (next >= raw.len) "" else std.mem.trim(u8, raw[next..], " \t\r\n"),
                        };
                    }
                    index = next;
                    continue;
                }
            } else if (try skipRawStringOrCommentInPostLoop(raw, &index)) {
                index += 1;
                continue;
            }
            switch (raw[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '$' => if (paren_depth == 0) {
                    return .{
                        .results = std.mem.trim(u8, raw[start..index], " \t\r\n"),
                        .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
                    };
                },
                else => {},
            }
            index += 1;
        }
        return .{
            .results = std.mem.trim(u8, raw[start..index], " \t\r\n"),
            .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
        };
    }

    pub fn qualifiedDeclName(self: *Parser, prefix: ?[]const u8, local_name: []const u8) std.mem.Allocator.Error!QualifiedName {
        if (prefix) |parent| {
            return .{
                .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, local_name }),
                .owns_name = true,
            };
        }
        return .{ .name = local_name };
    }

    pub fn appendParsedStruct(self: *Parser, decl: Struct) Error!void {
        const structs = self.parsed_structs.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try structs.append(self.allocator, decl);
    }

    pub fn appendParsedEnum(self: *Parser, decl: EnumDecl) Error!void {
        const enums = self.parsed_enums.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try enums.append(self.allocator, decl);
    }

    pub fn appendParsedInterface(self: *Parser, decl: InterfaceDecl) Error!void {
        const interfaces = self.parsed_interfaces.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try interfaces.append(self.allocator, decl);
    }

    pub fn appendParsedAnnotation(self: *Parser, decl: AnnotationDecl) Error!void {
        const annotations = self.parsed_annotations.?;
        const decl_names = self.parsed_decl_names.?;
        const entry = try decl_names.getOrPut(decl.name);
        if (entry.found_existing) return error.NameCollision;
        try self.registerDeclarationId(decl.id);
        try annotations.append(self.allocator, decl);
    }

    pub fn registerDeclarationId(self: *Parser, id: ?u64) Error!void {
        const value = id orelse return;
        const decl_ids = self.parsed_decl_ids orelse return;
        const entry = try decl_ids.getOrPut(value);
        if (entry.found_existing) return error.OrdinalCollision;
    }

    pub fn addLocalTypeAlias(self: *Parser, aliases: *std.ArrayList(AliasDecl), decl_names: *std.StringHashMap(void), local_name: []const u8, target_name: []const u8) Error!void {
        const entry = try decl_names.getOrPut(local_name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = local_name, .target = .{ .named = target_name } });
    }

    pub fn parseConstOrSkip(self: *Parser, consts: *std.ArrayList(ConstDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        const name = try self.expectIdentifier();
        const decl_id = try self.parseOptionalDeclarationId();
        if (self.lookahead.tag != .colon) return error.UnexpectedToken;
        try self.expect(.colon);
        var ty = try self.parseType();
        errdefer ty.deinit(self.allocator);

        if (self.lookahead.tag != .equal) return error.UnexpectedToken;
        const block_text_literal = typeAcceptsTextLiteral(ty) and self.constLiteralFirstByte() == '`';
        const list_literal = !block_text_literal and self.constLiteralStartsList();
        if (!block_text_literal and self.constLiteralStartsUnsupported(list_literal)) {
            try self.expect(.equal);
            const raw_tail = try self.takeRawUntilSemicolon();
            const split = splitDefaultExpressionAndAnnotations(raw_tail);
            try Parser.validateAnnotationSuffix(split.annotations);
            const is_embed = std.mem.startsWith(u8, split.default_expression, "embed");
            const embed_path = if (is_embed) embedPathFromExpression(split.default_expression) orelse "" else "";
            const is_struct_literal = std.mem.startsWith(u8, split.default_expression, "(");
            var struct_fields: ?[]ConstStructField = null;
            errdefer if (struct_fields) |fields| self.allocator.free(fields);
            if (is_struct_literal) {
                try self.validateDefaultLiteralForTypeSyntax(ty, split.default_expression);
                struct_fields = try parseConstStructFieldsAlloc(self.allocator, split.default_expression);
            } else if (std.mem.startsWith(u8, split.default_expression, "[")) {
                try self.validateDefaultLiteralForTypeSyntax(ty, split.default_expression);
            }
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) {
                return error.NameCollision;
            }
            try self.registerDeclarationId(decl_id);
            try consts.append(self.allocator, .{
                .name = name,
                .id = decl_id,
                .ty = ty,
                .literal = split.default_expression,
                .is_embed = is_embed,
                .embed_path = embed_path,
                .is_struct_literal = is_struct_literal,
                .emit_value = false,
                .annotations = split.annotations,
                .struct_fields = struct_fields,
            });
            return;
        }

        var is_hex_data = false;
        var list_items: ?[]ConstListItem = null;
        var list_has_aggregate_items = false;
        errdefer if (list_items) |items| {
            deinitConstListItems(self.allocator, items);
            self.allocator.free(items);
        };
        var owns_literal = false;
        var literal_is_string = false;
        const literal: []const u8 = if (block_text_literal) blk: {
            literal_is_string = true;
            break :blk try self.parseBlockTextLiteralAfterEqual();
        } else blk: {
            try self.expect(.equal);
            break :blk if (list_literal) list_blk: {
                const list_start = self.currentTokenStart();
                list_items = try self.parseConstListItems(&list_has_aggregate_items);
                const list_end = self.currentTokenStart();
                break :list_blk std.mem.trim(u8, self.lexer.source[list_start..list_end], " \t\r\n");
            } else if (typeAcceptsDataLiteral(ty) and self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) data_blk: {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) return error.UnexpectedToken;
                const value = self.lookahead.lexeme;
                try self.advance();
                is_hex_data = true;
                break :data_blk value;
            } else value_blk: {
                literal_is_string = self.lookahead.tag == .string;
                const value = (try self.expectDefaultLiteral()) orelse return error.UnexpectedToken;
                owns_literal = self.ownsScratchLiteral(value);
                break :value_blk value;
            };
        };
        if (!block_text_literal) {
            if (is_hex_data) {
                const decoded = hexBytesAlloc(self.allocator, literal) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.InvalidToken => return error.UnexpectedToken,
                    else => return error.UnexpectedToken,
                };
                self.allocator.free(decoded);
            } else if (literal_is_string and (typeAcceptsTextLiteral(ty) or typeAcceptsDataLiteral(ty))) {
                // Const Text/Data literals are stored decoded rather than as raw
                // quoted syntax, so the token stream has already validated their
                // string grammar.  Re-parsing the decoded bytes would reject
                // perfectly valid text such as adjacent strings or C-style
                // escapes after they have been normalized.
            } else {
                try self.validateDefaultLiteralForTypeSyntax(ty, literal);
            }
        }

        if (!isSimpleConstType(ty) and list_items == null) {
            ty.deinit(self.allocator);
            try self.skipRawUntilSemicolon();
            return;
        }
        const const_annotations = try self.takeAnnotationSuffixUntilSemicolon();

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) {
            return error.NameCollision;
        }
        try self.registerDeclarationId(decl_id);
        try consts.append(self.allocator, .{
            .name = name,
            .id = decl_id,
            .ty = ty,
            .literal = literal,
            .owns_literal = owns_literal,
            .is_hex_data = is_hex_data,
            .literal_is_string = literal_is_string,
            .annotations = const_annotations,
            .list_items = list_items,
            .emit_value = !list_has_aggregate_items,
        });
        if (owns_literal) _ = self.takeOwnedLiteral(literal);
    }

    pub fn parseConstListItems(self: *Parser, has_aggregate_items: *bool) Error![]ConstListItem {
        var items = std.ArrayList(ConstListItem).empty;
        errdefer {
            deinitConstListItems(self.allocator, items.items);
            items.deinit(self.allocator);
        }

        try self.expect(.l_bracket);
        while (self.lookahead.tag != .r_bracket) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;

            var is_hex_data = false;
            var owns_literal = false;
            var annotations: []const u8 = "";
            var struct_fields: ?[]ConstStructField = null;
            errdefer if (struct_fields) |fields| self.allocator.free(fields);
            const literal = if (self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) blk: {
                try self.expect(.integer);
                if (self.lookahead.tag != .string) return error.UnexpectedToken;
                const value = self.lookahead.lexeme;
                try self.advance();
                is_hex_data = true;
                break :blk value;
            } else if (self.lookahead.tag == .l_paren or self.lookahead.tag == .l_bracket) blk: {
                has_aggregate_items.* = true;
                const raw_item = try self.takeRawUntilConstListItemEnd();
                const split = splitDefaultExpressionAndAnnotations(raw_item);
                annotations = split.annotations;
                try validateAnnotationSuffix(annotations);
                try self.validateDefaultLiteralSyntax(split.default_expression);
                if (std.mem.startsWith(u8, split.default_expression, "(")) {
                    struct_fields = try parseConstStructFieldsAlloc(self.allocator, split.default_expression);
                }
                break :blk split.default_expression;
            } else blk: {
                const value = (try self.expectDefaultLiteral()) orelse return error.UnexpectedToken;
                owns_literal = self.ownsScratchLiteral(value);
                break :blk value;
            };
            if (annotations.len == 0 and self.lookahead.tag == .dollar) {
                annotations = try self.takeRawUntilConstListItemEnd();
            }
            try validateAnnotationSuffix(annotations);
            try items.append(self.allocator, .{
                .index = items.items.len,
                .literal = literal,
                .owns_literal = owns_literal,
                .is_hex_data = is_hex_data,
                .annotations = annotations,
                .struct_field_count = if (struct_fields) |fields| fields.len else 0,
                .struct_fields = struct_fields orelse &.{},
                .owns_struct_fields = struct_fields != null,
            });
            struct_fields = null;
            if (owns_literal) _ = self.takeOwnedLiteral(literal);

            if (self.lookahead.tag == .comma) {
                try self.expect(.comma);
                if (self.lookahead.tag == .r_bracket) return error.UnexpectedToken;
            } else if (self.lookahead.tag != .r_bracket) {
                return error.UnexpectedToken;
            }
        }
        try self.expect(.r_bracket);
        return items.toOwnedSlice(self.allocator);
    }

    pub fn takeRawUntilConstListItemEnd(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        const start = self.currentTokenStart();
        var index = start;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
                '"' => {
                    index += 1;
                    while (index < source.len) : (index += 1) {
                        if (source[index] == '\\') {
                            index += 1;
                        } else if (source[index] == '"') {
                            break;
                        }
                    }
                    if (index >= source.len) return error.UnexpectedToken;
                },
                '#' => index = skipLineCommentIndex(source, index),
                '/' => {
                    if (index + 1 < source.len and source[index + 1] == '/') {
                        index = skipLineCommentIndex(source, index + 2);
                    } else if (index + 1 < source.len and source[index + 1] == '*') {
                        index = (try skipBlockCommentIndex(source, index)) - 1;
                    } else {
                        index += 1;
                    }
                },
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '[' => bracket_depth += 1,
                ']' => {
                    if (paren_depth == 0 and bracket_depth == 0) break;
                    if (bracket_depth != 0) bracket_depth -= 1;
                },
                ',' => if (paren_depth == 0 and bracket_depth == 0) break,
                else => {},
            }
            index += 1;
        }
        if (index >= source.len) return error.UnexpectedToken;
        self.lexer.index = index;
        try self.advance();
        return std.mem.trim(u8, source[start..index], " \t\r\n");
    }

    pub fn constLiteralStartsList(self: *const Parser) bool {
        return self.constLiteralFirstByte() == '[';
    }

    pub fn constLiteralStartsUnsupported(self: *const Parser, allow_list: bool) bool {
        if (self.constLiteralStartsKeyword("embed")) return true;
        const first = self.constLiteralFirstByte() orelse return true;
        return switch (first) {
            '(' => true,
            '[' => !allow_list,
            else => false,
        };
    }

    pub fn constLiteralFirstByte(self: *const Parser) ?u8 {
        const source = self.lexer.source;
        const index = self.constLiteralStartIndex() orelse return null;
        return source[index];
    }

    pub fn constLiteralStartsKeyword(self: *const Parser, keyword: []const u8) bool {
        const source = self.lexer.source;
        const start = self.constLiteralStartIndex() orelse return false;
        if (start + keyword.len > source.len) return false;
        if (!std.mem.eql(u8, source[start .. start + keyword.len], keyword)) return false;
        const end = start + keyword.len;
        return end == source.len or !isIdentContinue(source[end]);
    }

    pub fn embedPathFromExpression(expression: []const u8) ?[]const u8 {
        const first_quote = std.mem.indexOfScalar(u8, expression, '"') orelse return null;
        var index = first_quote + 1;
        while (index < expression.len) : (index += 1) {
            if (expression[index] == '\\') {
                index += 1;
            } else if (expression[index] == '"') {
                return expression[first_quote + 1 .. index];
            }
        }
        return null;
    }

    pub fn constLiteralStartIndex(self: *const Parser) ?usize {
        const source = self.lexer.source;
        const index = skipTriviaIndexOrNull(source, self.lexer.index) orelse return null;
        if (index >= source.len) return null;
        return index;
    }

    pub fn parseUsingOrSkip(self: *Parser, aliases: *std.ArrayList(AliasDecl), imports: ?*std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        if (self.isKeyword("import")) {
            if (imports) |imports_list| try self.parseAnonymousImport(imports_list, decl_names) else try self.skipRawUntilSemicolon();
            return;
        }
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        if ((try self.peekNext()).tag != .equal) {
            var target = try self.parseType();
            var keep_target = false;
            defer if (!keep_target) target.deinit(self.allocator);
            if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
            try self.expect(.semicolon);

            const name = anonymousAliasName(target) orelse {
                return;
            };
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) {
                return error.NameCollision;
            }
            try aliases.append(self.allocator, .{ .name = name, .target = target });
            keep_target = true;
            return;
        }

        const name = try self.expectIdentifier();
        try self.expect(.equal);
        if (self.isKeyword("import")) {
            try self.advance();
            if (self.lookahead.tag != .string) return error.UnexpectedToken;
            const path = self.lookahead.lexeme;
            if (path.len == 0) return error.UnexpectedToken;
            try self.advance();
            var member: ?[]const u8 = null;
            if (self.lookahead.tag == .dot) {
                try self.expect(.dot);
                const first = self.lookahead;
                _ = try self.expectIdentifier();
                var end = first.end;
                if (try self.skipTypeApplications()) |app_end| end = app_end;
                while (self.lookahead.tag == .dot) {
                    try self.expect(.dot);
                    const part = self.lookahead;
                    _ = try self.expectIdentifier();
                    end = part.end;
                    if (try self.skipTypeApplications()) |app_end| end = app_end;
                }
                member = self.lexer.source[first.start..end];
            }
            if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
            try self.expect(.semicolon);

            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
            if (imports) |imports_list| try imports_list.append(self.allocator, .{ .name = name, .path = path, .member = member });
            return;
        }

        var target = try self.parseType();
        var keep_target = false;
        defer if (!keep_target) target.deinit(self.allocator);
        if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
        try self.expect(.semicolon);

        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try aliases.append(self.allocator, .{ .name = name, .target = target });
        keep_target = true;
    }

    pub fn parseAnonymousImport(self: *Parser, imports: *std.ArrayList(ImportDecl), decl_names: *std.StringHashMap(void)) Error!void {
        try self.advance();
        if (self.lookahead.tag != .string) return error.UnexpectedToken;
        const path = self.lookahead.lexeme;
        if (path.len == 0) return error.UnexpectedToken;
        try self.advance();
        if (self.lookahead.tag != .dot) {
            if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
            try self.expect(.semicolon);
            const name = importNameFromPath(path);
            if (name.len == 0) return error.UnexpectedToken;
            try self.reserveBareImportName(decl_names, name);
            try imports.append(self.allocator, .{ .name = name, .path = path });
            return;
        }
        try self.expect(.dot);
        const first = self.lookahead;
        _ = try self.expectIdentifier();
        var end = first.end;
        if (try self.skipTypeApplications()) |app_end| end = app_end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
        }
        if (self.lookahead.tag != .semicolon) return error.UnexpectedToken;
        try self.expect(.semicolon);

        const member = self.lexer.source[first.start..end];
        const name = anonymousAliasNameFromRaw(member);
        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;
        try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
    }

    pub fn reserveBareImportName(self: *Parser, decl_names: *std.StringHashMap(void), name: []const u8) Error!void {
        const entry = try decl_names.getOrPut(name);
        if (entry.found_existing) return error.NameCollision;

        // Bare imports use the file stem as a schema-visible namespace.  File
        // stems are often lower-case (`foo.capnp`) while declarations normally
        // use UpperCamelCase (`Foo`), so reserve the leading-capital spelling as
        // well to prevent an imported namespace and a declaration from claiming
        // the same natural schema name in either declaration order.
        const capitalized = try capitalizedImportNameAlloc(self.allocator, name) orelse return;
        errdefer self.allocator.free(capitalized);
        const capitalized_entry = try decl_names.getOrPut(capitalized);
        if (capitalized_entry.found_existing) return error.NameCollision;
        try self.literal_scratch.append(self.allocator, capitalized);
    }

    pub fn parseFileId(self: *Parser) Error!u64 {
        try self.expect(.at);
        const id = try self.expectInteger();
        try self.expect(.semicolon);
        return id;
    }

    pub fn parseOptionalDeclarationId(self: *Parser) Error!?u64 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        const value = try self.expectInteger();
        if (self.lookahead.tag == .at) return error.UnexpectedToken;
        return value;
    }

    pub fn parseStruct(self: *Parser, name_prefix: ?[]const u8) Error!Struct {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const parameters = try self.parseDeclarationParameters(local_name);
        errdefer self.allocator.free(parameters);
        const annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try self.expect(.l_brace);

        var fields = std.ArrayList(Field).empty;
        errdefer {
            for (fields.items) |*field| field.deinit(self.allocator);
            fields.deinit(self.allocator);
        }
        var consts = std.ArrayList(ConstDecl).empty;
        errdefer {
            for (consts.items) |*c| c.deinit(self.allocator);
            consts.deinit(self.allocator);
        }
        var aliases = std.ArrayList(AliasDecl).empty;
        errdefer {
            for (aliases.items) |*a| a.deinit(self.allocator);
            aliases.deinit(self.allocator);
        }
        var groups = std.ArrayList(GroupDecl).empty;
        errdefer groups.deinit(self.allocator);
        var field_names = std.StringHashMap(void).init(self.allocator);
        defer field_names.deinit();
        var member_names = std.StringHashMap(void).init(self.allocator);
        defer member_names.deinit();
        try reserveParameterNames(parameters, &member_names);
        var unions = std.ArrayList(UnionBuilder).empty;
        errdefer {
            for (unions.items) |*u| u.deinit(self.allocator);
            unions.deinit(self.allocator);
        }

        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if (self.isKeyword("struct") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseStruct(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedStruct(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("enum") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseEnum(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedEnum(decl);
                keep = true;
                continue;
            }
            if (self.isKeyword("interface") and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                var decl = try self.parseInterfaceDeclaration(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedInterface(decl);
                keep = true;
                continue;
            }
            if (try self.eatKeyword("annotation")) {
                var decl = try self.parseAnnotationDeclaration(qualified.name);
                var keep = false;
                errdefer if (!keep) decl.deinit(self.allocator);
                try self.addLocalTypeAlias(&aliases, &member_names, anonymousAliasName(.{ .named = decl.name }).?, decl.name);
                try self.appendParsedAnnotation(decl);
                keep = true;
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(&fields, &field_names, &member_names, &unions, &groups, null);
                continue;
            }
            if (try self.isAnonymousUnionStart()) {
                try self.advance();
                const union_index = try checkedUnionIndex(unions.items.len);
                try unions.append(self.allocator, UnionBuilder.init(self.allocator));
                try self.parseAnonymousUnion(&unions.items[union_index], &member_names, union_index, &groups);
                continue;
            }
            if (try self.eatKeyword("const")) {
                try self.parseConstOrSkip(&consts, &member_names);
                continue;
            }
            if (try self.eatKeyword("using")) {
                try self.parseUsingOrSkip(&aliases, self.parsed_imports, &member_names);
                continue;
            }
            if (self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (try putFieldName(&field_names, field.name)) return error.NameCollision;
            const member_entry = try member_names.getOrPut(field.name);
            if (member_entry.found_existing) return error.NameCollision;
            try fields.append(self.allocator, field);
            keep_field = true;
        }
        try self.expect(.r_brace);
        for (unions.items) |*u| try appendUnionFields(self.allocator, &fields, &field_names, u);
        // Group and union lowering appends synthetic fields after their bodies are
        // parsed.  Validate ordinals once the flattened field list is complete so
        // every schema-visible struct member shares the same collision rules.
        try validateStructMemberOrdinals(self.allocator, fields.items, groups.items, unions.items);
        const union_decls = try unionDeclsFromBuilders(self.allocator, unions.items);
        errdefer self.allocator.free(union_decls);
        for (unions.items) |*u| u.deinit(self.allocator);
        unions.deinit(self.allocator);
        return .{
            .name = qualified.name,
            .owns_name = qualified.owns_name,
            .id = decl_id,
            .annotations = annotations,
            .parameters = parameters,
            .fields = try fields.toOwnedSlice(self.allocator),
            .unions = union_decls,
            .groups = try groups.toOwnedSlice(self.allocator),
            .consts = try consts.toOwnedSlice(self.allocator),
            .aliases = try aliases.toOwnedSlice(self.allocator),
        };
    }

    pub fn parseAnonymousUnion(self: *Parser, union_builder: *UnionBuilder, member_names: *std.StringHashMap(void), union_index: u32, groups: *std.ArrayList(GroupDecl)) Error!void {
        union_builder.name = "";
        union_builder.ordinal = null;
        union_builder.annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try self.expect(.l_brace);
        try self.parseAnonymousUnionBody("", union_builder, member_names, union_index, groups);
    }

    pub fn parseNamedAggregate(
        self: *Parser,
        fields: *std.ArrayList(Field),
        field_names: *std.StringHashMap(void),
        member_names: *std.StringHashMap(void),
        unions: *std.ArrayList(UnionBuilder),
        groups: *std.ArrayList(GroupDecl),
        parent_prefix: ?[]const u8,
    ) Error!void {
        const name = try self.expectIdentifier();
        const ordinal = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (std.mem.eql(u8, kind, "group")) {
            const group_entry = try member_names.getOrPut(name);
            if (group_entry.found_existing) return error.NameCollision;
            const group_prefix = if (parent_prefix) |prefix|
                try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ prefix, name })
            else
                try self.allocator.dupe(u8, name);
            defer self.allocator.free(group_prefix);
            const group_annotations = try self.takeAnnotationSuffixUntilLeftBrace();
            try groups.append(self.allocator, .{
                .index = groups.items.len,
                .name = name,
                .ordinal = ordinal,
                .annotations = group_annotations,
            });
            try self.parseNamedGroupBody(group_prefix, fields, field_names, member_names, unions, groups);
            return;
        }
        if (std.mem.eql(u8, kind, "union")) {
            const union_entry = try member_names.getOrPut(name);
            if (union_entry.found_existing) return error.NameCollision;
            const union_prefix = if (parent_prefix) |prefix|
                try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ prefix, name })
            else
                try self.allocator.dupe(u8, name);
            defer self.allocator.free(union_prefix);
            const union_index = try checkedUnionIndex(unions.items.len);
            try unions.append(self.allocator, UnionBuilder.init(self.allocator));
            unions.items[union_index].name = name;
            unions.items[union_index].ordinal = ordinal;
            unions.items[union_index].annotations = try self.takeAnnotationSuffixUntilLeftBrace();
            try self.parseNamedUnionBody(union_prefix, &unions.items[union_index], member_names, union_index, groups);
            return;
        }
        return error.UnexpectedToken;
    }

    pub fn parseNamedUnionBody(self: *Parser, union_prefix: []const u8, union_builder: *UnionBuilder, member_names: *std.StringHashMap(void), union_index: u32, groups: *std.ArrayList(GroupDecl)) Error!void {
        try self.expect(.l_brace);
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                if (try self.isNamedGroupStart()) {
                    try self.parseUnionGroupMember(union_prefix, union_builder, member_names, union_index, groups);
                    saw_field = true;
                } else {
                    try self.skipNamedAggregate();
                }
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (union_builder.field_names.contains(field.name) or member_names.contains(field.name)) return error.NameCollision;
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ union_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            field.union_index = union_index;
            field.union_member_index = try takeUnionMemberIndex(union_builder);
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    pub fn parseNamedGroupBody(
        self: *Parser,
        group_prefix: []const u8,
        fields: *std.ArrayList(Field),
        field_names: *std.StringHashMap(void),
        member_names: *std.StringHashMap(void),
        unions: *std.ArrayList(UnionBuilder),
        groups: *std.ArrayList(GroupDecl),
    ) Error!void {
        try self.expect(.l_brace);
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                try self.parseNamedAggregate(fields, field_names, member_names, unions, groups, group_prefix);
                saw_field = true;
                continue;
            }
            if (try self.isAnonymousUnionStart()) {
                try self.advance();
                _ = try self.takeAnnotationSuffixUntilLeftBrace();
                try self.skipCurrentBracedBody();
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (member_names.contains(field.name)) return error.NameCollision;
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            if (try putFieldName(field_names, field.name)) return error.NameCollision;
            const member_entry = try member_names.getOrPut(field.name);
            if (member_entry.found_existing) return error.NameCollision;
            try fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
    }

    pub fn appendSyntheticVoidField(self: *Parser, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), member_names: *std.StringHashMap(void), name: []const u8, ordinal: u32) Error!void {
        var field = Field{ .name = name, .ordinal = ordinal, .ty = .void };
        if (try putFieldName(field_names, field.name)) {
            field.deinit(self.allocator);
            return error.NameCollision;
        }
        const member_entry = try member_names.getOrPut(field.name);
        if (member_entry.found_existing) {
            field.deinit(self.allocator);
            return error.NameCollision;
        }
        try fields.append(self.allocator, field);
    }

    pub fn skipNamedAggregate(self: *Parser) Error!void {
        _ = try self.expectIdentifier();
        _ = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (!std.mem.eql(u8, kind, "union") and !std.mem.eql(u8, kind, "group")) return error.UnexpectedToken;
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    pub fn parseOptionalOrdinalBang(self: *Parser) Error!?u32 {
        if (self.lookahead.tag != .at) return null;
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        return @intCast(ordinal_u64);
    }

    pub fn parseUnionGroupMember(
        self: *Parser,
        parent_prefix: []const u8,
        union_builder: *UnionBuilder,
        member_names: *std.StringHashMap(void),
        union_index: u32,
        groups: *std.ArrayList(GroupDecl),
    ) Error!void {
        const group_name = try self.expectIdentifier();
        const ordinal = try self.parseOptionalOrdinalBang();
        try self.expect(.colon);
        const kind = try self.expectIdentifier();
        if (!std.mem.eql(u8, kind, "group")) return error.UnexpectedToken;
        if (member_names.contains(group_name)) return error.NameCollision;
        const group_entry = try union_builder.field_names.getOrPut(group_name);
        if (group_entry.found_existing) return error.NameCollision;
        const group_prefix = if (parent_prefix.len != 0)
            try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ parent_prefix, group_name })
        else
            try self.allocator.dupe(u8, group_name);
        defer self.allocator.free(group_prefix);
        const group_annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try groups.append(self.allocator, .{
            .index = groups.items.len,
            .name = group_name,
            .ordinal = ordinal,
            .annotations = group_annotations,
        });
        const member_index = try takeUnionMemberIndex(union_builder);

        try self.expect(.l_brace);
        var saw_field = false;
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
            if (try self.isAnonymousUnionStart()) {
                try self.advance();
                _ = try self.takeAnnotationSuffixUntilLeftBrace();
                try self.skipCurrentBracedBody();
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            const synthetic_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ group_prefix, field.name });
            field.name = synthetic_name;
            field.owns_name = true;
            field.union_index = union_index;
            field.union_member_index = member_index;
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
    }

    pub fn parseAnonymousUnionBody(self: *Parser, union_prefix: []const u8, union_builder: *UnionBuilder, member_names: *std.StringHashMap(void), union_index: u32, groups: *std.ArrayList(GroupDecl)) Error!void {
        var saw_field = false;
        while (self.lookahead.tag != .r_brace) {
            if (self.lookahead.tag == .eof) return error.UnexpectedToken;
            if ((self.isKeyword("struct") or self.isKeyword("enum") or self.isKeyword("interface")) and (try self.peekNext()).tag == .identifier) {
                try self.advance();
                try self.skipBracedDeclaration();
                continue;
            }
            if (try self.isNamedAggregateStart()) {
                if (try self.isNamedGroupStart()) {
                    try self.parseUnionGroupMember(union_prefix, union_builder, member_names, union_index, groups);
                    saw_field = true;
                } else {
                    try self.skipNamedAggregate();
                }
                continue;
            }
            if (try self.eatKeyword("using") or try self.eatKeyword("const") or try self.eatKeyword("annotation") or self.lookahead.tag == .dollar) {
                try self.skipRawUntilSemicolon();
                continue;
            }
            var field = try self.parseField();
            var keep_field = false;
            errdefer if (!keep_field) field.deinit(self.allocator);
            if (union_builder.field_names.contains(field.name) or member_names.contains(field.name)) return error.NameCollision;
            field.union_index = union_index;
            field.union_member_index = try takeUnionMemberIndex(union_builder);
            if (try putFieldName(&union_builder.field_names, field.name)) return error.NameCollision;
            try union_builder.fields.append(self.allocator, field);
            keep_field = true;
            saw_field = true;
        }
        if (!saw_field) return error.UnexpectedToken;
        try self.expect(.r_brace);
        try self.assignUnionDiscriminants(union_builder.fields.items);
    }

    pub fn assignUnionDiscriminants(self: *Parser, fields: []Field) Error!void {
        _ = self;
        for (fields) |*field| {
            const member_index = field.union_member_index orelse return error.InvalidOrdinal;
            if (member_index > std.math.maxInt(u16)) return error.InvalidOrdinal;
            field.union_discriminant = @intCast(member_index);
        }
    }

    pub fn takeUnionMemberIndex(union_builder: *UnionBuilder) Error!u32 {
        const member_index = union_builder.next_member_index;
        if (member_index > std.math.maxInt(u16)) return error.InvalidOrdinal;
        union_builder.next_member_index = std.math.add(u32, union_builder.next_member_index, 1) catch return error.InvalidOrdinal;
        return member_index;
    }

    pub fn parseEnum(self: *Parser, name_prefix: ?[]const u8) Error!EnumDecl {
        const local_name = try self.expectIdentifier();
        const qualified = try self.qualifiedDeclName(name_prefix, local_name);
        errdefer if (qualified.owns_name) self.allocator.free(qualified.name);
        const decl_id = try self.parseOptionalDeclarationId();
        const annotations = try self.takeAnnotationSuffixUntilLeftBrace();
        try self.expect(.l_brace);

        var values = std.ArrayList(EnumValue).empty;
        errdefer values.deinit(self.allocator);
        var occupied_ordinals = std.AutoHashMap(u16, void).init(self.allocator);
        defer occupied_ordinals.deinit();
        var value_names = std.StringHashMap(void).init(self.allocator);
        defer value_names.deinit();

        if (self.lookahead.tag == .r_brace) return error.UnexpectedToken;
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
            const value_annotations = try self.takeAnnotationSuffixUntilSemicolon();
            try values.append(self.allocator, .{ .index = values.items.len, .name = value_name, .ordinal = ordinal, .annotations = value_annotations });
        }
        try self.expect(.r_brace);
        return .{ .name = qualified.name, .owns_name = qualified.owns_name, .id = decl_id, .annotations = annotations, .values = try values.toOwnedSlice(self.allocator) };
    }

    pub fn parseField(self: *Parser) Error!Field {
        const name = try self.expectIdentifier();
        try self.expect(.at);
        const ordinal_u64 = try self.expectInteger();
        if (ordinal_u64 > std.math.maxInt(u32)) return error.InvalidOrdinal;
        if (self.lookahead.tag == .bang) try self.expect(.bang);
        try self.expect(.colon);
        var ty = try self.parseType();
        var keep_ty = false;
        errdefer if (!keep_ty) ty.deinit(self.allocator);
        if (isGroupType(ty) and self.lookahead.tag == .l_brace) {
            try self.skipCurrentBracedBody();
            ty.deinit(self.allocator);
            return .{ .name = name, .ordinal = @intCast(ordinal_u64), .ty = .void };
        }

        var default_literal: ?[]const u8 = null;
        var owns_default_literal = false;
        var default_is_hex_data = false;
        var default_expression: []const u8 = "";
        var annotations: []const u8 = "";
        var default_is_block_text = false;

        if (self.lookahead.tag == .equal) {
            if (ty == .text and self.constLiteralFirstByte() == '`') {
                const literal = try self.parseBlockTextLiteralAfterEqual();
                default_literal = literal;
                default_expression = literal;
                default_is_block_text = true;
                annotations = try self.takeAnnotationSuffixUntilSemicolon();
            } else {
                try self.expect(.equal);
                if (self.lookahead.tag == .l_paren or self.lookahead.tag == .l_bracket) {
                    const raw_tail = try self.takeRawUntilSemicolon();
                    const split = splitDefaultExpressionAndAnnotations(raw_tail);
                    default_expression = split.default_expression;
                    annotations = split.annotations;
                    try validateAnnotationSuffix(annotations);
                    try self.validateInlineAggregateDefaultSyntax(default_expression);
                } else {
                    const default_start = self.currentTokenStart();
                    if (ty == .data and self.lookahead.tag == .integer and std.mem.eql(u8, self.lookahead.lexeme, "0x")) {
                        try self.expect(.integer);
                        if (self.lookahead.tag != .string) return error.UnexpectedToken;
                        default_literal = self.lookahead.lexeme;
                        try self.advance();
                        default_is_hex_data = true;
                    } else {
                        default_literal = try self.expectDefaultLiteral();
                        if (default_literal) |literal| owns_default_literal = self.ownsScratchLiteral(literal);
                    }
                    const default_end = self.currentTokenStart();
                    default_expression = std.mem.trim(u8, self.lexer.source[default_start..default_end], " \t\r\n");
                    annotations = try self.takeAnnotationSuffixUntilSemicolon();
                }
            }
        } else {
            annotations = try self.takeAnnotationSuffixUntilSemicolon();
        }

        if (default_expression.len != 0 and !default_is_block_text) try self.validateDefaultLiteralForTypeSyntax(ty, default_expression);
        if (owns_default_literal) _ = self.takeOwnedLiteral(default_literal.?);
        keep_ty = true;
        return .{
            .name = name,
            .ordinal = @intCast(ordinal_u64),
            .ty = ty,
            .default_literal = default_literal,
            .owns_default_literal = owns_default_literal,
            .default_is_hex_data = default_is_hex_data,
            .default_expression = default_expression,
            .annotations = annotations,
        };
    }

    pub fn parseType(self: *Parser) Error!Type {
        if (self.lookahead.tag == .question) {
            try self.expect(.question);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            return .{ .optional = child };
        }
        if (self.isKeyword("import")) {
            return self.parseInlineImportType();
        }
        if (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const first = self.lookahead;
            _ = try self.expectIdentifier();
            var end = first.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
            while (self.lookahead.tag == .dot) {
                try self.expect(.dot);
                const part = self.lookahead;
                _ = try self.expectIdentifier();
                end = part.end;
                if (try self.skipTypeApplications()) |app_end| end = app_end;
            }
            return .{ .named = self.lexer.source[first.start..end] };
        }
        const first = self.lookahead;
        const name = try self.expectIdentifier();
        if (std.mem.eql(u8, name, "List")) {
            try self.expect(.l_paren);
            const child = try self.allocator.create(Type);
            errdefer self.allocator.destroy(child);
            child.* = try self.parseType();
            errdefer child.deinit(self.allocator);
            try self.expect(.r_paren);
            return .{ .list = child };
        }
        if (std.mem.eql(u8, name, "AnyList")) return .any_list;
        if (std.mem.endsWith(u8, name, "List") and name.len > "List".len) {
            const base_name = name[0 .. name.len - "List".len];
            const child = try self.allocator.create(Type);
            errdefer {
                child.deinit(self.allocator);
                self.allocator.destroy(child);
            }
            child.* = scalarOrNamed(base_name);
            return .{ .list = child };
        }
        var end = first.end;
        if (try self.skipTypeApplications()) |app_end| end = app_end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
        }
        if (end != first.end) return .{ .named = self.lexer.source[first.start..end] };
        return scalarOrNamed(name);
    }

    pub fn skipTypeApplications(self: *Parser) Error!?usize {
        var last_end: ?usize = null;
        var saw_application = false;
        while (self.lookahead.tag == .l_paren) {
            if (saw_application) return error.UnexpectedToken;
            saw_application = true;
            try self.expect(.l_paren);
            if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
            while (true) {
                var arg = try self.parseType();
                defer arg.deinit(self.allocator);
                switch (self.lookahead.tag) {
                    .comma => {
                        try self.expect(.comma);
                        if (self.lookahead.tag == .r_paren) return error.UnexpectedToken;
                    },
                    .r_paren => {
                        last_end = self.lexer.index;
                        try self.expect(.r_paren);
                        break;
                    },
                    else => return error.UnexpectedToken,
                }
            }
        }
        return last_end;
    }

    pub fn parseInlineImportType(self: *Parser) Error!Type {
        try self.advance();
        if (self.lookahead.tag != .string) return error.UnexpectedToken;
        const path = self.lookahead.lexeme;
        if (path.len == 0) return error.UnexpectedToken;
        try self.advance();
        try self.expect(.dot);

        const first = self.lookahead;
        _ = try self.expectIdentifier();
        var end = first.end;
        if (try self.skipTypeApplications()) |app_end| end = app_end;
        while (self.lookahead.tag == .dot) {
            try self.expect(.dot);
            const part = self.lookahead;
            _ = try self.expectIdentifier();
            end = part.end;
            if (try self.skipTypeApplications()) |app_end| end = app_end;
        }

        const member = self.lexer.source[first.start..end];
        const name = anonymousAliasName(.{ .named = member }) orelse return error.UnexpectedToken;
        try self.recordInlineImport(name, path, member);
        return .{ .named = name };
    }

    pub fn recordInlineImport(self: *Parser, name: []const u8, path: []const u8, member: []const u8) Error!void {
        const imports = self.parsed_imports orelse return;
        for (imports.items) |import_decl| {
            if (!std.mem.eql(u8, import_decl.name, name)) continue;
            if (std.mem.eql(u8, import_decl.path, path) and import_decl.member != null and std.mem.eql(u8, import_decl.member.?, member)) return;
            return error.NameCollision;
        }
        if (self.parsed_decl_names) |decl_names| {
            const entry = try decl_names.getOrPut(name);
            if (entry.found_existing) return error.NameCollision;
        }
        try imports.append(self.allocator, .{ .name = name, .path = path, .member = member });
    }

    pub fn scalarOrNamed(name: []const u8) Type {
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

    pub fn isNamedAggregateStart(self: *const Parser) Error!bool {
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

    pub fn isNamedGroupStart(self: *const Parser) Error!bool {
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
        return token.tag == .identifier and std.mem.eql(u8, token.lexeme, "group");
    }

    pub fn isAnonymousUnionStart(self: *const Parser) Error!bool {
        if (!self.isKeyword("union")) return false;
        var lexer = self.lexer;
        var token = try lexer.next();
        while (token.tag != .eof and token.tag != .semicolon and token.tag != .r_brace) : (token = try lexer.next()) {
            if (token.tag == .l_brace) return true;
        }
        return false;
    }

    pub fn eatKeyword(self: *Parser, keyword: []const u8) Error!bool {
        if (self.isKeyword(keyword)) {
            try self.advance();
            return true;
        }
        return false;
    }

    pub fn isKeyword(self: *const Parser, keyword: []const u8) bool {
        return self.lookahead.tag == .identifier and std.mem.eql(u8, self.lookahead.lexeme, keyword);
    }

    pub fn peekNext(self: *const Parser) Error!Token {
        var lexer = self.lexer;
        return lexer.next();
    }

    pub fn expectIdentifier(self: *Parser) Error![]const u8 {
        if (self.lookahead.tag != .identifier) return error.UnexpectedToken;
        const value = self.lookahead.lexeme;
        if (!isSchemaIdentifier(value)) return error.UnexpectedToken;
        try self.advance();
        return value;
    }

    pub fn expectInteger(self: *Parser) Error!u64 {
        if (self.lookahead.tag != .integer) return error.UnexpectedToken;
        if (std.mem.startsWith(u8, self.lookahead.lexeme, "+") or std.mem.startsWith(u8, self.lookahead.lexeme, "-")) return error.UnexpectedToken;
        const value = try parseInteger(self.lookahead.lexeme);
        try self.advance();
        return value;
    }

    pub fn parseBlockTextLiteralAfterEqual(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        var index = try skipTriviaIndex(source, self.lexer.index);
        if (index >= source.len or source[index] != '`') return error.UnexpectedToken;
        index += 1;
        const start = index;
        while (index < source.len and source[index] != ';') : (index += 1) {}
        if (index >= source.len) return error.UnexpectedToken;
        var end = index;
        while (end > start and (source[end - 1] == ' ' or source[end - 1] == '\t' or source[end - 1] == '\r' or source[end - 1] == '\n')) end -= 1;
        self.lexer.index = index;
        try self.advance();
        return source[start..end];
    }

    pub fn currentTokenStart(self: *const Parser) usize {
        if (self.lookahead.start != 0 or self.lookahead.end != 0) return self.lookahead.start;
        return if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
    }

    pub fn expectDefaultLiteral(self: *Parser) Error!?[]const u8 {
        switch (self.lookahead.tag) {
            .dot => {
                const start = self.currentTokenStart();
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
                return self.lexer.source[start..end];
            },
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
            .integer => {
                const value = self.lookahead.lexeme;
                try self.advance();
                return value;
            },
            .string => return try self.expectStringDefaultLiteral(),
            .l_paren, .l_bracket => return null,
            else => return error.UnexpectedToken,
        }
    }

    pub fn expectStringDefaultLiteral(self: *Parser) Error![]const u8 {
        const first = self.lookahead.lexeme;
        try self.expect(.string);
        if (self.lookahead.tag != .string) return first;

        var joined = std.ArrayList(u8).empty;
        errdefer joined.deinit(self.allocator);
        try joined.appendSlice(self.allocator, first);
        while (self.lookahead.tag == .string) {
            try joined.appendSlice(self.allocator, self.lookahead.lexeme);
            try self.expect(.string);
        }
        const owned = try joined.toOwnedSlice(self.allocator);
        errdefer self.allocator.free(owned);
        try self.literal_scratch.append(self.allocator, owned);
        return owned;
    }

    pub fn splitDefaultExpressionAndAnnotations(raw: []const u8) struct { default_expression: []const u8, annotations: []const u8 } {
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        var index: usize = 0;
        while (index < raw.len) : (index += 1) {
            switch (raw[index]) {
                '"' => {
                    index += 1;
                    while (index < raw.len) : (index += 1) {
                        if (raw[index] == '\\') {
                            index += 1;
                        } else if (raw[index] == '"') {
                            break;
                        }
                    }
                },
                '#' => index = skipLineCommentIndex(raw, index),
                '/' => {
                    if (index + 1 < raw.len and raw[index + 1] == '/') {
                        index = skipLineCommentIndex(raw, index + 2);
                    } else if (index + 1 < raw.len and raw[index + 1] == '*') {
                        index = skipBlockCommentIndexOrNull(raw, index) orelse raw.len;
                        if (index != 0) index -= 1;
                    }
                },
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth != 0) paren_depth -= 1;
                },
                '[' => bracket_depth += 1,
                ']' => {
                    if (bracket_depth != 0) bracket_depth -= 1;
                },
                '$' => if (paren_depth == 0 and bracket_depth == 0) {
                    return .{
                        .default_expression = std.mem.trim(u8, raw[0..index], " \t\r\n"),
                        .annotations = std.mem.trim(u8, raw[index..], " \t\r\n"),
                    };
                },
                else => {},
            }
        }
        return .{ .default_expression = std.mem.trim(u8, raw, " \t\r\n"), .annotations = "" };
    }

    pub fn parseAnnotationIdentifierIndex(raw: []const u8, start: usize) Error!usize {
        if (start >= raw.len or !isIdentStart(raw[start])) return error.UnexpectedToken;
        var index = start + 1;
        while (index < raw.len and isIdentContinue(raw[index])) index += 1;
        return index;
    }

    pub fn parseAnnotationNameIndex(raw: []const u8, start: usize) Error!usize {
        var index = try parseAnnotationIdentifierIndex(raw, start);
        while (true) {
            if (try skipAnnotationTypeApplicationBeforeDotIndex(raw, index)) |after_app| {
                index = after_app;
            }
            if (index >= raw.len or raw[index] != '.') break;
            index += 1;
            index = try skipTriviaIndex(raw, index);
            index = try parseAnnotationIdentifierIndex(raw, index);
        }
        return index;
    }

    pub fn skipAnnotationTypeApplicationBeforeDotIndex(raw: []const u8, start: usize) Error!?usize {
        const index = try skipTriviaIndex(raw, start);
        if (index >= raw.len or raw[index] != '(') return null;
        const after_args = try skipAnnotationArgumentListIndex(raw, index);
        const after_trivia = try skipTriviaIndex(raw, after_args);
        return if (after_trivia < raw.len and raw[after_trivia] == '.') after_trivia else null;
    }

    pub fn parseAnnotationImportNameIndex(raw: []const u8, start: usize) Error!?usize {
        const import_keyword = "import";
        if (!std.mem.startsWith(u8, raw[start..], import_keyword)) return null;
        const after_keyword = start + import_keyword.len;
        if (after_keyword < raw.len and isIdentContinue(raw[after_keyword])) return null;

        const path_start = try skipTriviaIndex(raw, after_keyword);
        if (path_start >= raw.len or raw[path_start] != '"') return null;
        const path_end = try skipRawStringIndex(raw, path_start);
        // This branch models Cap'n Proto's inline import expression used in
        // annotation references, e.g. `$import "c++.capnp".namespace(...)`.
        // Keep the same non-empty path invariant as `parseInlineImportType()`
        // instead of accepting a syntactically well-balanced but unusable
        // import designator.
        if (path_end == path_start + 2) return error.UnexpectedToken;

        var index = try skipTriviaIndex(raw, path_end);
        if (index >= raw.len or raw[index] != '.') return error.UnexpectedToken;
        index += 1;
        index = try skipTriviaIndex(raw, index);
        return try parseAnnotationNameIndex(raw, index);
    }

    pub fn parseAnnotationDesignatorIndex(raw: []const u8, start: usize) Error!usize {
        if (try parseAnnotationImportNameIndex(raw, start)) |index| return index;
        return parseAnnotationNameIndex(raw, start);
    }

    pub fn skipAnnotationArgumentListIndex(raw: []const u8, start: usize) Error!usize {
        var index = start;
        var paren_depth: usize = 0;
        while (index < raw.len) {
            if (try skipRawStringOrCommentIndex(raw, index)) |next| {
                index = next;
                continue;
            }
            switch (raw[index]) {
                '(' => paren_depth += 1,
                ')' => {
                    if (paren_depth == 0) return error.UnexpectedToken;
                    paren_depth -= 1;
                    index += 1;
                    if (paren_depth == 0) return index;
                    continue;
                },
                else => {},
            }
            index += 1;
        }
        return error.UnexpectedToken;
    }

    pub fn validateAnnotationSuffix(raw: []const u8) Error!void {
        var index = try skipTriviaIndex(raw, 0);
        while (index < raw.len) {
            if (raw[index] != '$') return error.UnexpectedToken;
            index += 1;

            index = try skipTriviaIndex(raw, index);
            index = try parseAnnotationDesignatorIndex(raw, index);

            index = try skipTriviaIndex(raw, index);
            if (index < raw.len and raw[index] == '(') {
                index = try skipAnnotationArgumentListIndex(raw, index);
            }

            index = try skipTriviaIndex(raw, index);
        }
    }

    pub fn takeAnnotationSuffixUntilSemicolon(self: *Parser) Error![]const u8 {
        const annotations = try self.takeRawUntilSemicolon();
        try validateAnnotationSuffix(annotations);
        return annotations;
    }

    pub fn takeAnnotationSuffixUntilLeftBrace(self: *Parser) Error![]const u8 {
        const annotations = try self.takeRawUntilLeftBrace();
        try validateAnnotationSuffix(annotations);
        return annotations;
    }

    pub fn skipUntilSemicolon(self: *Parser) Error!void {
        try self.skipUntil(.semicolon);
        try self.expect(.semicolon);
    }

    pub fn skipRawUntilSemicolon(self: *Parser) Error!void {
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
                '/' => index = try skipRawSlashIndex(source, index),
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

    pub fn takeRawUntilSemicolon(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        const start = if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
        var index = start;
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
                '/' => index = try skipRawSlashIndex(source, index),
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
                    const end = index;
                    index += 1;
                    if (paren_depth == 0 and bracket_depth == 0 and brace_depth == 0) {
                        self.lexer.index = index;
                        try self.advance();
                        return std.mem.trim(u8, source[start..end], " \t\r\n");
                    }
                },
                else => index += 1,
            }
        }
        return error.UnexpectedToken;
    }

    pub fn takeRawUntilLeftBrace(self: *Parser) Error![]const u8 {
        const source = self.lexer.source;
        const start = if (self.lookahead.tag == .eof) self.lexer.index else self.lexer.index - self.lookahead.lexeme.len;
        var index = start;
        var paren_depth: usize = 0;
        var bracket_depth: usize = 0;
        while (index < source.len) {
            const c = source[index];
            switch (c) {
                '"' => {
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
                },
                '#' => {
                    while (index < source.len and source[index] != '\n') index += 1;
                },
                '/' => index = try skipRawSlashIndex(source, index),
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
                    if (paren_depth == 0 and bracket_depth == 0) {
                        self.lexer.index = index;
                        try self.advance();
                        return std.mem.trim(u8, source[start..index], " \t\r\n");
                    }
                    index += 1;
                },
                else => index += 1,
            }
        }
        return error.UnexpectedToken;
    }

    pub fn skipUntil(self: *Parser, tag: TokenTag) Error!void {
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

    pub fn skipBracedDeclaration(self: *Parser) Error!void {
        try self.skipUntil(.l_brace);
        try self.skipCurrentBracedBody();
    }

    pub fn skipCurrentBracedBody(self: *Parser) Error!void {
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

    pub fn expect(self: *Parser, tag: TokenTag) Error!void {
        if (self.lookahead.tag != tag) return error.UnexpectedToken;
        try self.advance();
    }

    pub fn advance(self: *Parser) Error!void {
        self.lookahead = try self.lexer.next();
    }
};

/// Parse schema source into an AST. The caller owns the returned `File`.
pub fn parse(allocator: std.mem.Allocator, source: []const u8) Error!File {
    var parser = try Parser.init(allocator, source);
    defer parser.deinitLiteralScratch();
    return parser.parse();
}
