const std = @import("std");
const message = @import("../../message.zig");
const serialize = @import("../../serialize.zig");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

/// Code generation state shared by the emitter modules.
pub threadlocal var emit_metadata_enabled: bool = true;

/// Emit per-pointer-field introspection helpers (kind, location, decoded
/// pointer, struct/list shape, stats, and match predicates).
pub threadlocal var emit_introspection_enabled: bool = true;

/// Emit Orphan wrapper types and orphan/copy helper methods.
pub threadlocal var emit_orphan_helpers_enabled: bool = true;

/// Distinguishes AnyPointer default payloads while encoding constants.
pub const AnyPointerDefaultKind = enum { any, struct_ptr, list };
