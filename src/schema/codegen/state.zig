const std = @import("std");
const message = @import("../../message.zig");
const serialize = @import("../../serialize.zig");
const wire = @import("../../wire.zig");
const frontend = @import("../frontend.zig");
const zig_names = @import("../zig_names.zig");

/// Code generation state shared by the emitter modules.
pub threadlocal var emit_metadata_enabled: bool = true;

/// Distinguishes AnyPointer default payloads while encoding constants.
pub const AnyPointerDefaultKind = enum { any, struct_ptr, list };
