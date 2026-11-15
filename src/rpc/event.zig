const std = @import("std");
const types = @import("types.zig");

const CapDescriptor = types.CapDescriptor;
const Error = types.Error;
const ImportId = types.ImportId;
const ReturnOutcome = types.ReturnOutcome;
const WireEvent = types.WireEvent;
const WireMessageTag = types.WireMessageTag;
const anyPointerUsageFromWire = types.anyPointerUsageFromWire;
const disembargoInfoFromWireDisembargo = types.disembargoInfoFromWireDisembargo;
const exceptionInfoFromWireException = types.exceptionInfoFromWireException;
const wireMessageTag = types.wireMessageTag;

pub fn payloadContentCapabilityIndex(payload: anytype) !?u32 {
    return (try payload.content()).getCapabilityIndex() catch |err| switch (err) {
        error.InvalidPointerKind, error.NullPointer => null,
        else => return err,
    };
}

pub fn returnOutcomeFromWireReturn(return_: anytype) !ReturnOutcome {
    return switch (return_.which() orelse return error.InvalidTransition) {
        .results => .results,
        .exception => .{ .exception = try exceptionInfoFromWireException(try return_.exception()) },
        .canceled => .canceled,
        .resultsSentElsewhere => .results_sent_elsewhere,
        .takeFromOtherQuestion => .{ .take_from_other_question = try return_.takeFromOtherQuestion() },
        .awaitFromThirdParty => .{ .await_from_third_party = try anyPointerUsageFromWire(try return_.awaitFromThirdPartyAsPointer()) },
    };
}

pub fn capDescriptorImportIdsAlloc(allocator: std.mem.Allocator, descriptors: []const CapDescriptor) std.mem.Allocator.Error![]ImportId {
    var count: usize = 0;
    for (descriptors) |descriptor| switch (descriptor) {
        .sender_hosted, .sender_promise, .third_party_hosted => count += 1,
        else => {},
    };

    const ids = try allocator.alloc(ImportId, count);
    var index: usize = 0;
    for (descriptors) |descriptor| switch (descriptor) {
        .sender_hosted, .sender_promise, .third_party_hosted => |id| {
            ids[index] = id;
            index += 1;
        },
        else => {},
    };
    return ids;
}

pub fn unimplementedMessageTag(message: anytype) !?WireMessageTag {
    if ((try wireMessageTag(message)) != .unimplemented) return null;
    return try wireMessageTag(try message.unimplemented());
}

pub fn eventFromWireUnimplementedMessage(message: anytype) !?WireEvent {
    if ((try wireMessageTag(message)) != .unimplemented) return null;
    return try eventFromWireMessage(try message.unimplemented());
}

pub fn eventFromWireMessage(message: anytype) !WireEvent {
    return switch (try wireMessageTag(message)) {
        .unimplemented => .{ .unimplemented = try wireMessageTag(try message.unimplemented()) },
        .abort => .{ .abort = try exceptionInfoFromWireException(try message.abort()) },
        .bootstrap => .{ .bootstrap = (try message.bootstrap()).questionId() },
        .call => .{ .call = (try message.call()).questionId() },
        .return_ => blk: {
            const return_ = try message.return_();
            break :blk .{ .return_ = .{
                .answer_id = return_.answerId(),
                .release_param_caps = return_.releaseParamCaps(),
                .no_finish_needed = return_.noFinishNeeded(),
            } };
        },
        .finish => blk: {
            const finish = try message.finish();
            break :blk .{ .finish = .{ .question_id = finish.questionId(), .release_result_caps = finish.releaseResultCaps() } };
        },
        .resolve => .{ .resolve = (try message.resolve()).promiseId() },
        .release => blk: {
            const release = try message.release();
            break :blk .{ .release = .{ .id = release.id(), .reference_count = release.referenceCount() } };
        },
        .disembargo => .{ .disembargo = try disembargoInfoFromWireDisembargo(try message.disembargo()) },
        .obsolete_save => .{ .obsolete_save = {} },
        .obsolete_delete => .{ .obsolete_delete = {} },
        .provide => .{ .provide = (try message.provide()).questionId() },
        .accept => .{ .accept = (try message.accept()).questionId() },
        .third_party_answer => .{ .third_party_answer = (try message.thirdPartyAnswer()).answerId() },
        .join => .{ .join = (try message.join()).questionId() },
    };
}
