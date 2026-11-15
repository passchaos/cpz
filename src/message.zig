//! Dynamic Cap'n Proto message runtime facade. Readers, builders, pointers,
//! structs, lists, and validation live in `message/`.

const std = @import("std");
const wire = @import("wire.zig");
const serialize = @import("serialize.zig");

const builder_mod = @import("message/builder.zig");
const capability_mod = @import("message/capability.zig");
const list_mod = @import("message/list.zig");
const options_mod = @import("message/options.zig");
const pointer_mod = @import("message/pointer.zig");
const reader_mod = @import("message/reader.zig");
const struct_mod = @import("message/struct.zig");
const validate_mod = @import("message/validate.zig");

const wordsToBytesSaturating = options_mod.wordsToBytesSaturating;
const wordsToBytesChecked = options_mod.wordsToBytesChecked;
pub const Error = options_mod.Error;
pub const ReaderOptions = options_mod.ReaderOptions;
pub const MessageStats = options_mod.MessageStats;
pub const MessageSize = options_mod.MessageSize;
pub const CapabilityTable = capability_mod.CapabilityTable;
pub const CapabilityRegistry = capability_mod.CapabilityRegistry;
pub const OwnedMessageReader = reader_mod.OwnedMessageReader;
pub const MessageReaderView = reader_mod.MessageReaderView;
pub const BuilderOptions = builder_mod.BuilderOptions;
const SegmentBuilder = builder_mod.SegmentBuilder;
const SegmentCursor = builder_mod.SegmentCursor;
pub const Orphan = builder_mod.Orphan;
pub const Orphanage = builder_mod.Orphanage;
pub const MessageBuilder = builder_mod.MessageBuilder;
pub const MessageReader = reader_mod.MessageReader;
pub const toSingleSegmentFlatBytes = reader_mod.toSingleSegmentFlatBytes;
const messageToSingleSegmentFlatBytes = reader_mod.messageToSingleSegmentFlatBytes;
pub const toCanonicalSegmentBytes = reader_mod.toCanonicalSegmentBytes;
const messageToCanonicalSegmentBytes = reader_mod.messageToCanonicalSegmentBytes;
const ensureSingleSegment = reader_mod.ensureSingleSegment;
pub const PointerBuilder = pointer_mod.PointerBuilder;
const copyPrimitiveList = pointer_mod.copyPrimitiveList;
const copyPrimitiveBuilderList = pointer_mod.copyPrimitiveBuilderList;
const copyStructDataFromReader = pointer_mod.copyStructDataFromReader;
const listRangeShouldCopyBackward = pointer_mod.listRangeShouldCopyBackward;
const listElementBitRange = pointer_mod.listElementBitRange;
pub const PointerReader = pointer_mod.PointerReader;
const ResolvedPointer = pointer_mod.ResolvedPointer;
pub const StructBuilder = struct_mod.StructBuilder;
pub const StructReader = struct_mod.StructReader;
pub const ListBuilder = list_mod.ListBuilder;
pub const ListReader = list_mod.ListReader;
const tag_forFarWithZeroOffset = validate_mod.tag_forFarWithZeroOffset;
const primitiveDataWords = validate_mod.primitiveDataWords;
const primitivePointerCount = validate_mod.primitivePointerCount;
const listDataBitsPerElement = validate_mod.listDataBitsPerElement;
const upgradedStructListShape = validate_mod.upgradedStructListShape;
const validatePointer = validate_mod.validatePointer;
const collectStructStats = validate_mod.collectStructStats;
const collectListStats = validate_mod.collectListStats;
const addStat = validate_mod.addStat;
const canonicalStructSize = validate_mod.canonicalStructSize;
const canonicalStructListSize = validate_mod.canonicalStructListSize;
const wordRangesOverlap = validate_mod.wordRangesOverlap;
const structEndWord = validate_mod.structEndWord;
const textElementCount = validate_mod.textElementCount;
const exactBytesForBits = validate_mod.exactBytesForBits;
const exactWordsForBits = validate_mod.exactWordsForBits;
const checkedListBitLen = validate_mod.checkedListBitLen;
const checkedListByteLen = validate_mod.checkedListByteLen;
const checkedListWordLen = validate_mod.checkedListWordLen;
const checkedWordBitOffset = validate_mod.checkedWordBitOffset;
const checkedWordByteOffset = validate_mod.checkedWordByteOffset;
const segmentIdFromIndex = validate_mod.segmentIdFromIndex;
const empty_mutable_bytes = validate_mod.empty_mutable_bytes;
const emptyMutableBytes = validate_mod.emptyMutableBytes;

test {
    _ = @import("message/tests/integration_tests.zig");
}
