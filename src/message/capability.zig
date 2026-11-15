const std = @import("std");
const wire = @import("../wire.zig");

const mod_builder = @import("builder.zig");
const mod_list = @import("list.zig");
const mod_options = @import("options.zig");
const mod_pointer = @import("pointer.zig");

const MessageBuilder = mod_builder.MessageBuilder;
const Orphan = mod_builder.Orphan;
const ListBuilder = mod_list.ListBuilder;
const ListReader = mod_list.ListReader;
const Error = mod_options.Error;
const MessageStats = mod_options.MessageStats;
const PointerBuilder = mod_pointer.PointerBuilder;
const PointerReader = mod_pointer.PointerReader;

/// A non-owning view mapping wire capability indexes to application handles.
pub fn CapabilityTable(comptime T: type) type {
    return struct {
        /// Application-owned capability handles indexed by wire capability
        /// pointer values.  The table is intentionally a non-owning slice: RPC
        /// systems decide handle lifetime and synchronization, while cpz only
        /// provides the safe index-to-handle bridge.
        entries: []const T = &.{},

        pub fn init(entries: []const T) @This() {
            return .{ .entries = entries };
        }

        pub fn len(self: @This()) usize {
            return self.entries.len;
        }

        pub fn isEmpty(self: @This()) bool {
            return self.entries.len == 0;
        }

        pub fn hasIndex(self: @This(), index: u32) bool {
            const usize_index = std.math.cast(usize, index) orelse return false;
            return usize_index < self.entries.len;
        }

        pub fn get(self: @This(), index: u32) Error!T {
            const usize_index = std.math.cast(usize, index) orelse return error.InvalidCapabilityPointer;
            if (usize_index >= self.entries.len) return error.InvalidCapabilityPointer;
            return self.entries[usize_index];
        }

        pub fn getOrNull(self: @This(), index: u32) ?T {
            const usize_index = std.math.cast(usize, index) orelse return null;
            if (usize_index >= self.entries.len) return null;
            return self.entries[usize_index];
        }

        pub fn getPointer(self: @This(), pointer: PointerReader) Error!T {
            return self.get(try pointer.getCapabilityIndex());
        }

        pub fn getPointerOrNull(self: @This(), pointer: PointerReader) Error!?T {
            if (pointer.isNull()) return null;
            return try self.getPointer(pointer);
        }

        pub fn getPointerBuilder(self: @This(), pointer: PointerBuilder) Error!T {
            return self.get(try pointer.getCapabilityIndex());
        }

        pub fn getPointerBuilderOrNull(self: @This(), pointer: PointerBuilder) Error!?T {
            if (pointer.isNull()) return null;
            return try self.getPointerBuilder(pointer);
        }

        pub fn getListElement(self: @This(), list: ListReader, index: usize) Error!T {
            return self.getPointer(try list.getPointerElement(index));
        }

        pub fn getListElementOrNull(self: @This(), list: ListReader, index: usize) Error!?T {
            return self.getPointerOrNull(try list.getPointerElement(index));
        }

        pub fn getListBuilderElement(self: @This(), list: ListBuilder, index: usize) Error!T {
            return self.getPointerBuilder(try list.getPointerElement(index));
        }

        pub fn getListBuilderElementOrNull(self: @This(), list: ListBuilder, index: usize) Error!?T {
            return self.getPointerBuilderOrNull(try list.getPointerElement(index));
        }

        pub fn getOrphan(self: @This(), orphan: Orphan) Error!T {
            return self.get(try orphan.getCapabilityIndex());
        }

        pub fn getOrphanOrNull(self: @This(), orphan: Orphan) Error!?T {
            if (orphan.isNull()) return null;
            return try self.getOrphan(orphan);
        }

        pub fn maxCount(self: @This()) usize {
            return self.entries.len;
        }

        pub fn satisfiesStats(self: @This(), stats: MessageStats) bool {
            return stats.maxCapabilityCount() <= self.entries.len;
        }

        pub fn validateStats(self: @This(), stats: MessageStats) Error!void {
            if (!self.satisfiesStats(stats)) return error.InvalidCapabilityPointer;
        }
    };
}

/// An append-only registry that assigns outgoing capability indexes.
pub fn CapabilityRegistry(comptime T: type) type {
    return struct {
        entries: std.ArrayList(T) = .empty,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.entries.deinit(allocator);
            self.* = undefined;
        }

        pub fn asTable(self: *const @This()) CapabilityTable(T) {
            return .init(self.entries.items);
        }

        pub fn len(self: *const @This()) usize {
            return self.entries.items.len;
        }

        pub fn isEmpty(self: *const @This()) bool {
            return self.entries.items.len == 0;
        }

        pub fn hasIndex(self: *const @This(), index: u32) bool {
            const usize_index = std.math.cast(usize, index) orelse return false;
            return usize_index < self.entries.items.len;
        }

        pub fn get(self: *const @This(), index: u32) Error!T {
            const usize_index = std.math.cast(usize, index) orelse return error.InvalidCapabilityPointer;
            if (usize_index >= self.entries.items.len) return error.InvalidCapabilityPointer;
            return self.entries.items[usize_index];
        }

        pub fn getOrNull(self: *const @This(), index: u32) ?T {
            const usize_index = std.math.cast(usize, index) orelse return null;
            if (usize_index >= self.entries.items.len) return null;
            return self.entries.items[usize_index];
        }

        pub fn maxCount(self: *const @This()) usize {
            return self.entries.items.len;
        }

        pub fn satisfiesStats(self: *const @This(), stats: MessageStats) bool {
            return stats.maxCapabilityCount() <= self.entries.items.len;
        }

        pub fn validateStats(self: *const @This(), stats: MessageStats) Error!void {
            if (!self.satisfiesStats(stats)) return error.InvalidCapabilityPointer;
        }

        pub fn register(self: *@This(), allocator: std.mem.Allocator, handle: T) Error!u32 {
            if (self.entries.items.len > std.math.maxInt(u32)) return error.CountOutOfRange;
            const index: u32 = @intCast(self.entries.items.len);
            try self.entries.append(allocator, handle);
            return index;
        }

        pub fn registerPointer(self: *@This(), allocator: std.mem.Allocator, pointer: PointerBuilder, handle: T) Error!u32 {
            // Validate the destination slot before mutating the registry so an
            // invalid builder pointer cannot leak an unreachable handle.
            _ = try pointer.message.readWord(pointer.segment_id, pointer.word_index);
            const index = try self.register(allocator, handle);
            try pointer.message.writePtr(pointer.segment_id, pointer.word_index, wire.encodeCapability(index));
            return index;
        }

        pub fn registerRoot(self: *@This(), allocator: std.mem.Allocator, builder: *MessageBuilder, handle: T) Error!u32 {
            const root = try builder.getRootPointer();
            return self.registerPointer(allocator, root, handle);
        }

        pub fn registerListElement(self: *@This(), allocator: std.mem.Allocator, list: ListBuilder, index: usize, handle: T) Error!u32 {
            return self.registerPointer(allocator, try list.getPointerElement(index), handle);
        }
    };
}
