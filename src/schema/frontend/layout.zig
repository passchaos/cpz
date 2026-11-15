const std = @import("std");

const mod_resolve = @import("resolve.zig");
const mod_types = @import("types.zig");
const mod_validate = @import("validate.zig");

const alignForwardChecked = mod_resolve.alignForwardChecked;
const classifyScoped = mod_resolve.classifyScoped;
const Error = mod_types.Error;
const Field = mod_types.Field;
const FieldLayout = mod_types.FieldLayout;
const FieldSlot = mod_types.FieldSlot;
const File = mod_types.File;
const GroupDecl = mod_types.GroupDecl;
const LayoutError = mod_types.LayoutError;
const LayoutFile = mod_types.LayoutFile;
const Struct = mod_types.Struct;
const StructLayout = mod_types.StructLayout;
const Type = mod_types.Type;
const UnionBuilder = mod_types.UnionBuilder;
const UnionDecl = mod_types.UnionDecl;
const UnionLayout = mod_types.UnionLayout;
const validateFileAggregateDefaults = mod_validate.validateFileAggregateDefaults;
const validateFileConstReferenceCycles = mod_validate.validateFileConstReferenceCycles;
const validateFileSimpleNamedTypes = mod_validate.validateFileSimpleNamedTypes;
const validateFileTypeApplications = mod_validate.validateFileTypeApplications;

pub fn putFieldName(names: *std.StringHashMap(void), name: []const u8) std.mem.Allocator.Error!bool {
    const entry = try names.getOrPut(name);
    return entry.found_existing;
}

pub fn appendUnionFields(allocator: std.mem.Allocator, fields: *std.ArrayList(Field), field_names: *std.StringHashMap(void), union_builder: *UnionBuilder) Error!void {
    var appended: usize = 0;
    errdefer {
        var i = fields.items.len - appended;
        while (i < fields.items.len) : (i += 1) fields.items[i].deinit(allocator);
        fields.shrinkRetainingCapacity(fields.items.len - appended);
    }
    try fields.ensureUnusedCapacity(allocator, union_builder.fields.items.len);
    const additional_field_names = try hashMapCapacityCount(union_builder.fields.items.len);
    try field_names.ensureUnusedCapacity(additional_field_names);
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

pub fn validateStructMemberOrdinals(allocator: std.mem.Allocator, fields: []const Field, groups: []const GroupDecl, unions: []const UnionBuilder) Error!void {
    var occupied = std.AutoHashMap(u32, void).init(allocator);
    defer occupied.deinit();
    for (fields) |field| {
        const entry = try occupied.getOrPut(field.ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }
    for (groups) |group| {
        const ordinal = group.ordinal orelse continue;
        const entry = try occupied.getOrPut(ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }
    for (unions) |union_builder| {
        const ordinal = union_builder.ordinal orelse continue;
        const entry = try occupied.getOrPut(ordinal);
        if (entry.found_existing) return error.OrdinalCollision;
    }
}

pub fn unionDeclsFromBuilders(allocator: std.mem.Allocator, builders: []const UnionBuilder) std.mem.Allocator.Error![]UnionDecl {
    const decls = try allocator.alloc(UnionDecl, builders.len);
    for (builders, 0..) |builder, index| {
        decls[index] = .{ .name = builder.name, .ordinal = builder.ordinal, .annotations = builder.annotations };
    }
    return decls;
}

/// Plan ordinal-aware data/pointer layouts for every struct in `file`.
pub fn planLayouts(allocator: std.mem.Allocator, file: *const File) LayoutError!LayoutFile {
    try validateFileTypeApplications(allocator, file);
    try validateFileConstReferenceCycles(file);
    try validateFileAggregateDefaults(allocator, file);
    try validateFileSimpleNamedTypes(allocator, file);

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

/// Plan the physical layout for a single struct declaration.
pub fn planStructLayout(allocator: std.mem.Allocator, file: *const File, decl: *const Struct) LayoutError!StructLayout {
    const fields = try allocator.alloc(FieldLayout, decl.fields.len);
    errdefer allocator.free(fields);
    const union_count = try countUnions(decl.fields);
    const unions = try allocator.alloc(UnionLayout, union_count);
    errdefer allocator.free(unions);
    for (unions, 0..) |*u, index| u.* = .{
        .discriminant_byte = 0,
        .name = if (index < decl.unions.len) decl.unions[index].name else "",
        .ordinal = if (index < decl.unions.len) decl.unions[index].ordinal else null,
        .annotations = if (index < decl.unions.len) decl.unions[index].annotations else "",
    };
    const union_requirements = try allocator.alloc(UnionRequirement, union_count);
    defer allocator.free(union_requirements);
    for (union_requirements) |*req| req.* = .{};
    const union_relative_slots = try computeUnionRelativeSlotsAlloc(allocator, file, decl, union_requirements);
    defer allocator.free(union_relative_slots);
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
    }

    for (0..decl.fields.len) |_| {
        const field_index = try nextOrdinalFieldIndexChecked(decl.fields, assigned);
        assigned[field_index] = true;
        const field = &decl.fields[field_index];

        const slot: FieldSlot = if (field.union_index) |union_index| blk: {
            const index: usize = @intCast(union_index);
            if (!union_allocated[index]) {
                const discriminant_start = try allocateDataBits(allocator, &data_ranges, 16);
                data_end_bit = @max(data_end_bit, try dataRangeEnd(discriminant_start, 16));
                unions[index].discriminant_byte = discriminant_start / 8;
                if (union_requirements[index].data_bits != 0) {
                    const start = try allocateDataBits(allocator, &data_ranges, union_requirements[index].data_bits);
                    data_end_bit = @max(data_end_bit, try dataRangeEnd(start, union_requirements[index].data_bits));
                    unions[index].data_bit = start;
                    unions[index].data_bits = union_requirements[index].data_bits;
                }
                if (union_requirements[index].pointer_count != 0) {
                    unions[index].pointer = next_pointer;
                    unions[index].pointer_count = union_requirements[index].pointer_count;
                    next_pointer = std.math.add(usize, next_pointer, union_requirements[index].pointer_count) catch return error.InvalidOrdinal;
                }
                union_allocated[index] = true;
            }
            break :blk try absoluteUnionFieldSlot(union_relative_slots[field_index], unions[index]);
        } else switch (try classifyScoped(file, decl, field.ty)) {
            .void => .void,
            .data => |bits| blk: {
                const start = try allocateDataBits(allocator, &data_ranges, bits);
                data_end_bit = @max(data_end_bit, try dataRangeEnd(start, bits));
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

pub const UnionRequirement = struct {
    data_bits: usize = 0,
    pointer_count: usize = 0,
};

pub fn countUnions(fields: []const Field) Error!usize {
    var count: usize = 0;
    for (fields) |field| {
        if (field.union_index) |union_index| {
            const one_past = std.math.add(usize, @intCast(union_index), 1) catch return error.InvalidOrdinal;
            count = @max(count, one_past);
        }
    }
    return count;
}

pub fn dataRangeEnd(start: usize, bits: usize) Error!usize {
    return std.math.add(usize, start, bits) catch return error.InvalidOrdinal;
}

pub fn checkedUnionIndex(index: usize) Error!u32 {
    if (index > std.math.maxInt(u32)) return error.InvalidOrdinal;
    return @intCast(index);
}

pub fn hashMapCapacityCount(count: usize) Error!std.StringHashMap(void).Size {
    if (count > std.math.maxInt(std.StringHashMap(void).Size)) return error.InvalidOrdinal;
    return @intCast(count);
}

pub fn computeUnionRelativeSlotsAlloc(allocator: std.mem.Allocator, file: *const File, decl: *const Struct, union_requirements: []UnionRequirement) LayoutError![]FieldSlot {
    const slots = try allocator.alloc(FieldSlot, decl.fields.len);
    errdefer allocator.free(slots);
    @memset(slots, .void);

    for (0..union_requirements.len) |union_index| {
        const member_count = try countUnionMembers(decl.fields, @intCast(union_index));
        if (member_count == 0) continue;
        const member_data_offsets = try allocator.alloc(usize, member_count);
        defer allocator.free(member_data_offsets);
        const member_pointer_offsets = try allocator.alloc(usize, member_count);
        defer allocator.free(member_pointer_offsets);
        @memset(member_data_offsets, 0);
        @memset(member_pointer_offsets, 0);

        var assigned = try allocator.alloc(bool, decl.fields.len);
        defer allocator.free(assigned);
        @memset(assigned, false);
        for (0..decl.fields.len) |_| {
            const field_index = try nextOrdinalFieldIndexChecked(decl.fields, assigned);
            assigned[field_index] = true;
            const field = decl.fields[field_index];
            if (field.union_index == null or field.union_index.? != union_index) continue;
            const member_index = field.union_member_index orelse return error.InvalidOrdinal;
            slots[field_index] = try unionMemberRelativeSlot(file, decl, field.ty, &member_data_offsets[member_index], &member_pointer_offsets[member_index]);
        }
        for (member_data_offsets) |data_bits| {
            if (data_bits != 0) {
                union_requirements[union_index].data_bits = @max(union_requirements[union_index].data_bits, @max(data_bits, @as(usize, 8)));
            }
        }
        for (member_pointer_offsets) |pointer_count| {
            union_requirements[union_index].pointer_count = @max(union_requirements[union_index].pointer_count, pointer_count);
        }
    }

    return slots;
}

pub fn countUnionMembers(fields: []const Field, union_index: u32) Error!usize {
    var count: usize = 0;
    for (fields) |field| {
        if (field.union_index == null or field.union_index.? != union_index) continue;
        const member_index = field.union_member_index orelse return error.InvalidOrdinal;
        const one_past = std.math.add(usize, @intCast(member_index), 1) catch return error.InvalidOrdinal;
        count = @max(count, one_past);
    }
    return count;
}

pub fn unionMemberRelativeSlot(file: *const File, scope: ?*const Struct, ty: Type, next_data_bit: *usize, next_pointer: *usize) LayoutError!FieldSlot {
    return switch (try classifyScoped(file, scope, ty)) {
        .void => .void,
        .data => |bits| blk: {
            next_data_bit.* = try alignForwardChecked(next_data_bit.*, bits);
            const bit = next_data_bit.*;
            next_data_bit.* = try dataRangeEnd(next_data_bit.*, bits);
            break :blk if (bits == 1) .{ .data_bit = bit } else .{ .data_byte = bit / 8 };
        },
        .pointer => blk: {
            const index = next_pointer.*;
            next_pointer.* = std.math.add(usize, next_pointer.*, 1) catch return error.InvalidOrdinal;
            break :blk .{ .pointer = index };
        },
    };
}

pub fn absoluteUnionFieldSlot(relative: FieldSlot, layout: UnionLayout) LayoutError!FieldSlot {
    return switch (relative) {
        .void => .void,
        .data_bit => |bit| .{ .data_bit = try dataRangeEnd(layout.data_bit, bit) },
        .data_byte => |byte| .{ .data_byte = layout.data_bit / 8 + byte },
        .pointer => |index| .{ .pointer = (layout.pointer orelse return error.UnsupportedType) + index },
    };
}

pub const BitRange = struct {
    start: usize,
    end: usize,
};

pub fn allocateDataBits(allocator: std.mem.Allocator, ranges: *std.ArrayList(BitRange), bits: usize) LayoutError!usize {
    var start: usize = 0;
    while (true) {
        start = try alignForwardChecked(start, bits);
        const end = try dataRangeEnd(start, bits);
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

pub fn rangesOverlap(a_start: usize, a_end: usize, b_start: usize, b_end: usize) bool {
    return a_start < b_end and b_start < a_end;
}

pub fn nextOrdinalFieldIndex(fields: []const Field, assigned: []const bool) ?usize {
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

pub fn nextOrdinalFieldIndexChecked(fields: []const Field, assigned: []const bool) Error!usize {
    if (fields.len != assigned.len) return error.InvalidOrdinal;
    return nextOrdinalFieldIndex(fields, assigned) orelse error.InvalidOrdinal;
}
