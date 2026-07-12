//! cpz: a Zig runtime for the Cap'n Proto wire format.
//!
//! This package intentionally starts at the low-level runtime layer: words,
//! pointers, segments, packing, stream framing, and dynamic readers/builders.
//! Generated schema APIs can be layered on top while preserving these stable
//! primitives.

pub const wire = @import("wire.zig");
pub const serialize = @import("serialize.zig");
pub const packing = @import("packing.zig");
pub const message = @import("message.zig");
pub const schema = @import("schema.zig");

pub const Word = wire.Word;
pub const ElementSize = wire.ElementSize;
pub const StructSize = wire.StructSize;

pub const MessageBuilder = message.MessageBuilder;
pub const MessageReader = message.MessageReader;
pub const StructBuilder = message.StructBuilder;
pub const StructReader = message.StructReader;
pub const ListBuilder = message.ListBuilder;
pub const ListReader = message.ListReader;
pub const PointerBuilder = message.PointerBuilder;
pub const PointerReader = message.PointerReader;
pub const Orphan = message.Orphan;
pub const ReaderOptions = message.ReaderOptions;
pub const BuilderOptions = message.BuilderOptions;
pub const MessageStats = message.MessageStats;
pub const MessageSize = message.MessageSize;
pub const toSingleSegmentFlatBytes = message.toSingleSegmentFlatBytes;
pub const toCanonicalSegmentBytes = message.toCanonicalSegmentBytes;
pub const expectedSizeInWordsFromPrefix = serialize.expectedSizeInWordsFromPrefix;

test {
    _ = wire;
    _ = serialize;
    _ = packing;
    _ = message;
    _ = schema;
}
