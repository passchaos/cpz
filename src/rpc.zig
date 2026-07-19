const std = @import("std");

pub const QuestionId = u32;
pub const AnswerId = u32;
pub const ExportId = u32;
pub const ImportId = u32;

pub const Error = error{
    InvalidTransition,
    QuestionAlreadyOpen,
    QuestionNotOpen,
    AnswerAlreadyResolved,
    ExportAlreadyReleased,
    ImportAlreadyReleased,
};

pub const CapabilityRef = union(enum) {
    export_id: ExportId,
    import_id: ImportId,
};

pub const CapabilityRelease = struct {
    id: ImportId,
    reference_count: u32,
};

/// Numeric tags from the top-level `Message` union in Cap'n Proto's
/// `rpc.capnp`. Keeping the mapping here lets code generated from that schema
/// be decoded without making this runtime module import a generated file.
pub const WireMessageTag = enum(u16) {
    unimplemented = 0,
    abort = 1,
    bootstrap = 2,
    call = 3,
    return_ = 4,
    finish = 5,
    resolve = 6,
    release = 7,
    disembargo = 8,
    obsolete_save = 9,
    obsolete_delete = 10,
    provide = 11,
    accept = 12,
    third_party_answer = 13,
    join = 14,
};

pub const WireEvent = union(WireMessageTag) {
    unimplemented: void,
    abort: void,
    bootstrap: QuestionId,
    call: QuestionId,
    return_: AnswerId,
    finish: QuestionId,
    resolve: ExportId,
    release: CapabilityRelease,
    disembargo: void,
    obsolete_save: void,
    obsolete_delete: void,
    provide: QuestionId,
    accept: QuestionId,
    third_party_answer: AnswerId,
    join: QuestionId,

    pub fn tag(self: WireEvent) WireMessageTag {
        return std.meta.activeTag(self);
    }

    pub fn isStateApplicable(self: WireEvent) bool {
        return switch (self) {
            .bootstrap, .call, .return_, .finish => true,
            .release => |release| release.reference_count != 0,
            else => false,
        };
    }

    pub fn isQuestionOpening(self: WireEvent) bool {
        return switch (self) {
            .bootstrap, .call => true,
            else => false,
        };
    }

    pub fn isQuestionClosing(self: WireEvent) bool {
        return switch (self) {
            .finish => true,
            else => false,
        };
    }

    pub fn isAnswerResolving(self: WireEvent) bool {
        return switch (self) {
            .return_ => true,
            else => false,
        };
    }

    pub fn isCapabilityRelease(self: WireEvent) bool {
        return switch (self) {
            .release => true,
            else => false,
        };
    }

    pub fn questionId(self: WireEvent) ?QuestionId {
        return switch (self) {
            .bootstrap, .call, .finish, .provide, .accept, .join => |id| id,
            else => null,
        };
    }

    pub fn answerId(self: WireEvent) ?AnswerId {
        return switch (self) {
            .return_, .third_party_answer => |id| id,
            else => null,
        };
    }

    pub fn exportId(self: WireEvent) ?ExportId {
        return switch (self) {
            .resolve => |id| id,
            else => null,
        };
    }

    pub fn importId(self: WireEvent) ?ImportId {
        return switch (self) {
            .release => |release| release.id,
            else => null,
        };
    }

    pub fn releaseReferenceCount(self: WireEvent) ?u32 {
        return switch (self) {
            .release => |release| release.reference_count,
            else => null,
        };
    }

    /// Project the decoded wire event into the small `State.apply()` vocabulary
    /// only when the ID semantics line up. Some rpc.capnp messages that look
    /// similar by name intentionally stay wire-only here: e.g. `Resolve` carries
    /// an `ExportId`, while the simplified state-machine `Event.resolve` still
    /// represents answer completion.
    pub fn toStateEvent(self: WireEvent) ?Event {
        return switch (self) {
            .bootstrap => |id| .{ .bootstrap = id },
            .call => |id| .{ .call = id },
            .return_ => |id| .{ .return_ = id },
            .finish => |id| .{ .finish = id },
            .release => |release| if (release.reference_count == 1) .{ .release = .{ .import_id = release.id } } else null,
            else => null,
        };
    }
};

/// Transport-independent subset of rpc.capnp message variants. This is only a
/// state-machine vocabulary; it deliberately does not read sockets, schedule
/// promises, or dispatch application methods.
pub const MessageKind = enum(u8) {
    bootstrap,
    call,
    return_,
    finish,
    resolve,
    release,
    disembargo,
    provide,
    accept,
    join,
    obsolete,

    pub fn isQuestionOpening(self: MessageKind) bool {
        return self == .bootstrap or self == .call;
    }

    pub fn isQuestionClosing(self: MessageKind) bool {
        return self == .finish;
    }

    pub fn isAnswerResolving(self: MessageKind) bool {
        return self == .return_ or self == .resolve;
    }

    pub fn isCapabilityTableMutation(self: MessageKind) bool {
        return switch (self) {
            .release, .provide, .accept, .join => true,
            else => false,
        };
    }
};

pub const Event = union(MessageKind) {
    bootstrap: QuestionId,
    call: QuestionId,
    return_: AnswerId,
    finish: QuestionId,
    resolve: AnswerId,
    release: CapabilityRef,
    disembargo: void,
    provide: ExportId,
    accept: ImportId,
    join: void,
    obsolete: void,

    pub fn kind(self: Event) MessageKind {
        return std.meta.activeTag(self);
    }

    pub fn questionId(self: Event) ?QuestionId {
        return switch (self) {
            .bootstrap, .call, .finish => |id| id,
            else => null,
        };
    }

    pub fn answerId(self: Event) ?AnswerId {
        return switch (self) {
            .return_, .resolve => |id| id,
            else => null,
        };
    }

    pub fn capabilityRef(self: Event) ?CapabilityRef {
        return switch (self) {
            .release => |ref| ref,
            .provide => |id| .{ .export_id = id },
            .accept => |id| .{ .import_id = id },
            else => null,
        };
    }
};

pub const QuestionState = enum(u8) {
    idle,
    open,
    finished,

    pub fn canSend(self: QuestionState, kind: MessageKind) bool {
        return switch (kind) {
            .bootstrap, .call => self == .idle,
            .finish => self == .open,
            else => false,
        };
    }
};

pub const AnswerState = enum(u8) {
    unresolved,
    resolved,

    pub fn canResolve(self: AnswerState) bool {
        return self == .unresolved;
    }
};

pub const CapabilityLifetime = enum(u8) {
    live,
    released,

    pub fn isLive(self: CapabilityLifetime) bool {
        return self == .live;
    }
};

pub const QuestionTracker = struct {
    id: QuestionId,
    state: QuestionState = .idle,

    pub fn open(self: *QuestionTracker, kind: MessageKind) Error!void {
        if (!kind.isQuestionOpening()) return error.InvalidTransition;
        if (self.state != .idle) return error.QuestionAlreadyOpen;
        self.state = .open;
    }

    pub fn finish(self: *QuestionTracker) Error!void {
        if (self.state != .open) return error.QuestionNotOpen;
        self.state = .finished;
    }

    pub fn canSend(self: QuestionTracker, kind: MessageKind) bool {
        return self.state.canSend(kind);
    }
};

pub const AnswerTracker = struct {
    id: AnswerId,
    state: AnswerState = .unresolved,

    pub fn resolve(self: *AnswerTracker, kind: MessageKind) Error!void {
        if (!kind.isAnswerResolving()) return error.InvalidTransition;
        if (!self.state.canResolve()) return error.AnswerAlreadyResolved;
        self.state = .resolved;
    }
};

pub fn CapabilityTracker(comptime Id: type, comptime already_released_error: Error) type {
    return struct {
        id: Id,
        state: CapabilityLifetime = .live,
        reference_count: u32 = 1,

        pub fn release(self: *@This()) Error!void {
            return self.releaseCount(1);
        }

        pub fn releaseCount(self: *@This(), count: u32) Error!void {
            if (count == 0) return error.InvalidTransition;
            if (self.state != .live) return already_released_error;
            if (count > self.reference_count) return error.InvalidTransition;
            self.reference_count -= count;
            if (self.reference_count == 0) self.state = .released;
        }

        pub fn isLive(self: @This()) bool {
            return self.state.isLive();
        }
    };
}

pub const ExportTracker = CapabilityTracker(ExportId, error.ExportAlreadyReleased);
pub const ImportTracker = CapabilityTracker(ImportId, error.ImportAlreadyReleased);

pub fn eventFromWireMessage(message: anytype) !WireEvent {
    const raw_discriminant = message.whichDiscriminant();
    const tag = std.enums.fromInt(WireMessageTag, raw_discriminant) orelse return error.InvalidTransition;
    return switch (tag) {
        .unimplemented => .{ .unimplemented = {} },
        .abort => .{ .abort = {} },
        .bootstrap => .{ .bootstrap = (try message.bootstrap()).questionId() },
        .call => .{ .call = (try message.call()).questionId() },
        .return_ => .{ .return_ = (try message.return_()).answerId() },
        .finish => .{ .finish = (try message.finish()).questionId() },
        .resolve => .{ .resolve = (try message.resolve()).promiseId() },
        .release => blk: {
            const release = try message.release();
            break :blk .{ .release = .{ .id = release.id(), .reference_count = release.referenceCount() } };
        },
        .disembargo => .{ .disembargo = {} },
        .obsolete_save => .{ .obsolete_save = {} },
        .obsolete_delete => .{ .obsolete_delete = {} },
        .provide => .{ .provide = (try message.provide()).questionId() },
        .accept => .{ .accept = (try message.accept()).questionId() },
        .third_party_answer => .{ .third_party_answer = (try message.thirdPartyAnswer()).answerId() },
        .join => .{ .join = (try message.join()).questionId() },
    };
}

pub const State = struct {
    questions: std.AutoHashMap(QuestionId, QuestionTracker),
    answers: std.AutoHashMap(AnswerId, AnswerTracker),
    exports: std.AutoHashMap(ExportId, ExportTracker),
    imports: std.AutoHashMap(ImportId, ImportTracker),

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .questions = std.AutoHashMap(QuestionId, QuestionTracker).init(allocator),
            .answers = std.AutoHashMap(AnswerId, AnswerTracker).init(allocator),
            .exports = std.AutoHashMap(ExportId, ExportTracker).init(allocator),
            .imports = std.AutoHashMap(ImportId, ImportTracker).init(allocator),
        };
    }

    pub fn deinit(self: *State) void {
        self.questions.deinit();
        self.answers.deinit();
        self.exports.deinit();
        self.imports.deinit();
        self.* = undefined;
    }

    pub fn questionCount(self: *const State) usize {
        return self.questions.count();
    }

    pub fn answerCount(self: *const State) usize {
        return self.answers.count();
    }

    /// Counts tracked export lifetime entries, including released tombstones.
    /// Keeping tombstones lets the state machine distinguish a duplicate
    /// release from a release of an id it never observed.
    pub fn exportCount(self: *const State) usize {
        return self.exports.count();
    }

    /// Counts tracked import lifetime entries, including released tombstones.
    pub fn importCount(self: *const State) usize {
        return self.imports.count();
    }

    pub fn hasQuestion(self: *const State, id: QuestionId) bool {
        return self.questions.contains(id);
    }

    pub fn hasAnswer(self: *const State, id: AnswerId) bool {
        return self.answers.contains(id);
    }

    pub fn hasExport(self: *const State, id: ExportId) bool {
        return self.exports.contains(id);
    }

    pub fn hasImport(self: *const State, id: ImportId) bool {
        return self.imports.contains(id);
    }

    pub fn openQuestion(self: *State, id: QuestionId, kind: MessageKind) (Error || std.mem.Allocator.Error)!void {
        if (!kind.isQuestionOpening()) return error.InvalidTransition;
        if (self.questions.contains(id)) return error.QuestionAlreadyOpen;
        if (self.answers.contains(id)) return error.AnswerAlreadyResolved;

        var question = QuestionTracker{ .id = id };
        try question.open(kind);
        try self.questions.put(id, question);
        errdefer _ = self.questions.remove(id);
        try self.answers.put(id, .{ .id = id });
    }

    pub fn finishQuestion(self: *State, id: QuestionId) Error!void {
        const question = self.questions.getPtr(id) orelse return error.QuestionNotOpen;
        try question.finish();
    }

    pub fn resolveAnswer(self: *State, id: AnswerId, kind: MessageKind) Error!void {
        const answer = self.answers.getPtr(id) orelse return error.QuestionNotOpen;
        try answer.resolve(kind);
    }

    pub fn addExport(self: *State, id: ExportId) (Error || std.mem.Allocator.Error)!void {
        if (self.exports.contains(id)) return error.InvalidTransition;
        try self.exports.put(id, .{ .id = id });
    }

    pub fn addImport(self: *State, id: ImportId) (Error || std.mem.Allocator.Error)!void {
        if (self.imports.contains(id)) return error.InvalidTransition;
        try self.imports.put(id, .{ .id = id });
    }

    pub fn releaseExport(self: *State, id: ExportId) Error!void {
        const tracker = self.exports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.release();
    }

    pub fn releaseImport(self: *State, id: ImportId) Error!void {
        const tracker = self.imports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.release();
    }

    pub fn releaseImportCount(self: *State, release: CapabilityRelease) Error!void {
        const tracker = self.imports.getPtr(release.id) orelse return error.InvalidTransition;
        try tracker.releaseCount(release.reference_count);
    }

    pub fn releaseCapability(self: *State, capability: CapabilityRef) Error!void {
        return switch (capability) {
            .export_id => |id| self.releaseExport(id),
            .import_id => |id| self.releaseImport(id),
        };
    }

    pub fn questionState(self: *const State, id: QuestionId) ?QuestionState {
        const question = self.questions.get(id) orelse return null;
        return question.state;
    }

    pub fn answerState(self: *const State, id: AnswerId) ?AnswerState {
        const answer = self.answers.get(id) orelse return null;
        return answer.state;
    }

    pub fn exportState(self: *const State, id: ExportId) ?CapabilityLifetime {
        const tracker = self.exports.get(id) orelse return null;
        return tracker.state;
    }

    pub fn importState(self: *const State, id: ImportId) ?CapabilityLifetime {
        const tracker = self.imports.get(id) orelse return null;
        return tracker.state;
    }

    pub fn importReferenceCount(self: *const State, id: ImportId) ?u32 {
        const tracker = self.imports.get(id) orelse return null;
        return tracker.reference_count;
    }

    pub fn apply(self: *State, event: Event) (Error || std.mem.Allocator.Error)!void {
        return switch (event) {
            .bootstrap => |id| self.openQuestion(id, .bootstrap),
            .call => |id| self.openQuestion(id, .call),
            .finish => |id| self.finishQuestion(id),
            .return_ => |id| self.resolveAnswer(id, .return_),
            .resolve => |id| self.resolveAnswer(id, .resolve),
            .release => |capability| self.releaseCapability(capability),
            .provide => |id| self.addExport(id),
            .accept => |id| self.addImport(id),
            else => error.InvalidTransition,
        };
    }

    pub fn applyWireEvent(self: *State, event: WireEvent) (Error || std.mem.Allocator.Error)!void {
        if (event == .release) return self.releaseImportCount(event.release);
        const state_event = event.toStateEvent() orelse return error.InvalidTransition;
        return self.apply(state_event);
    }
};

test "rpc message kind predicates describe state-machine roles" {
    const testing = std.testing;
    try testing.expect(MessageKind.bootstrap.isQuestionOpening());
    try testing.expect(MessageKind.call.isQuestionOpening());
    try testing.expect(MessageKind.finish.isQuestionClosing());
    try testing.expect(MessageKind.return_.isAnswerResolving());
    try testing.expect(MessageKind.resolve.isAnswerResolving());
    try testing.expect(MessageKind.release.isCapabilityTableMutation());
    try testing.expect(!MessageKind.disembargo.isQuestionOpening());

    const call_event = Event{ .call = 12 };
    try testing.expectEqual(MessageKind.call, call_event.kind());
    try testing.expectEqual(@as(?QuestionId, 12), call_event.questionId());
    try testing.expectEqual(@as(?AnswerId, null), call_event.answerId());
    const return_event = Event{ .return_ = 12 };
    try testing.expectEqual(MessageKind.return_, return_event.kind());
    try testing.expectEqual(@as(?AnswerId, 12), return_event.answerId());

    const provide_event = Event{ .provide = 5 };
    try testing.expectEqual(MessageKind.provide, provide_event.kind());
    try testing.expectEqual(CapabilityRef{ .export_id = 5 }, provide_event.capabilityRef().?);
    const accept_event = Event{ .accept = 6 };
    try testing.expectEqual(CapabilityRef{ .import_id = 6 }, accept_event.capabilityRef().?);
}

test "rpc wire events expose classification and id helpers" {
    const testing = std.testing;

    const bootstrap = WireEvent{ .bootstrap = 12 };
    try testing.expectEqual(WireMessageTag.bootstrap, bootstrap.tag());
    try testing.expect(bootstrap.isStateApplicable());
    try testing.expect(bootstrap.isQuestionOpening());
    try testing.expect(!bootstrap.isQuestionClosing());
    try testing.expectEqual(@as(?QuestionId, 12), bootstrap.questionId());

    const return_event = WireEvent{ .return_ = 13 };
    try testing.expect(return_event.isAnswerResolving());
    try testing.expectEqual(@as(?AnswerId, 13), return_event.answerId());

    const release_event = WireEvent{ .release = .{ .id = 14, .reference_count = 3 } };
    try testing.expect(release_event.isCapabilityRelease());
    try testing.expectEqual(@as(?ImportId, 14), release_event.importId());
    try testing.expectEqual(@as(?u32, 3), release_event.releaseReferenceCount());
    try testing.expectEqual(@as(?ExportId, null), release_event.exportId());

    const resolve_event = WireEvent{ .resolve = 15 };
    try testing.expect(!resolve_event.isStateApplicable());
    try testing.expectEqual(@as(?ExportId, 15), resolve_event.exportId());

    const provide_event = WireEvent{ .provide = 16 };
    try testing.expect(!provide_event.isStateApplicable());
    try testing.expectEqual(@as(?QuestionId, 16), provide_event.questionId());
}

test "rpc question and answer trackers reject invalid transitions" {
    const testing = std.testing;

    var question = QuestionTracker{ .id = 7 };
    try testing.expect(question.canSend(.call));
    try question.open(.call);
    try testing.expect(!question.canSend(.bootstrap));
    try testing.expectError(error.QuestionAlreadyOpen, question.open(.bootstrap));
    try question.finish();
    try testing.expectError(error.QuestionNotOpen, question.finish());

    var answer = AnswerTracker{ .id = 9 };
    try answer.resolve(.return_);
    try testing.expectError(error.AnswerAlreadyResolved, answer.resolve(.resolve));
    try testing.expectError(error.InvalidTransition, answer.resolve(.call));
}

test "rpc capability trackers reject double release" {
    const testing = std.testing;

    var export_tracker = ExportTracker{ .id = 1 };
    try testing.expect(export_tracker.isLive());
    try export_tracker.release();
    try testing.expect(!export_tracker.isLive());
    try testing.expectError(error.ExportAlreadyReleased, export_tracker.release());

    var import_tracker = ImportTracker{ .id = 2 };
    try import_tracker.release();
    try testing.expectError(error.ImportAlreadyReleased, import_tracker.release());
}

test "rpc state tracks in-flight questions and answers" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectEqual(@as(usize, 0), state.questionCount());
    try state.openQuestion(1, .call);
    try testing.expect(state.hasQuestion(1));
    try testing.expect(state.hasAnswer(1));
    try testing.expectEqual(@as(usize, 1), state.questionCount());
    try testing.expectEqual(@as(usize, 1), state.answerCount());
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));

    try testing.expectError(error.QuestionAlreadyOpen, state.openQuestion(1, .bootstrap));
    try testing.expectError(error.InvalidTransition, state.openQuestion(2, .finish));
    try state.finishQuestion(1);
    try testing.expectEqual(@as(?QuestionState, .finished), state.questionState(1));
    try testing.expectError(error.QuestionNotOpen, state.finishQuestion(99));

    try state.resolveAnswer(1, .return_);
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(1));
    try testing.expectError(error.AnswerAlreadyResolved, state.resolveAnswer(1, .resolve));
    try testing.expectError(error.QuestionNotOpen, state.resolveAnswer(99, .return_));
}

test "rpc state tracks import and export lifetimes" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectEqual(@as(usize, 0), state.exportCount());
    try testing.expectEqual(@as(usize, 0), state.importCount());

    try state.addExport(10);
    try state.addImport(20);
    try testing.expect(state.hasExport(10));
    try testing.expect(state.hasImport(20));
    try testing.expectEqual(@as(usize, 1), state.exportCount());
    try testing.expectEqual(@as(usize, 1), state.importCount());
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(10));
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(20));

    try testing.expectError(error.InvalidTransition, state.addExport(10));
    try testing.expectError(error.InvalidTransition, state.addImport(20));
    try testing.expectError(error.InvalidTransition, state.releaseExport(99));
    try testing.expectError(error.InvalidTransition, state.releaseImport(99));

    try state.releaseExport(10);
    try state.releaseImport(20);
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.exportState(10));
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(20));
    try testing.expectError(error.ExportAlreadyReleased, state.releaseExport(10));
    try testing.expectError(error.ImportAlreadyReleased, state.releaseImport(20));
}

test "rpc state applies transport-independent events" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.apply(.{ .bootstrap = 3 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(3));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(3));
    try testing.expectError(error.QuestionAlreadyOpen, state.apply(.{ .call = 3 }));

    try state.apply(.{ .finish = 3 });
    try testing.expectEqual(@as(?QuestionState, .finished), state.questionState(3));
    try state.apply(.{ .resolve = 3 });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(3));
    try testing.expectError(error.AnswerAlreadyResolved, state.apply(.{ .return_ = 3 }));

    try state.apply(.{ .provide = 7 });
    try state.apply(.{ .accept = 8 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(7));
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(8));
    try state.apply(.{ .release = .{ .export_id = 7 } });
    try state.apply(.{ .release = .{ .import_id = 8 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.exportState(7));
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(8));
    try testing.expectError(error.ExportAlreadyReleased, state.apply(.{ .release = .{ .export_id = 7 } }));
    try testing.expectError(error.InvalidTransition, state.apply(.{ .join = {} }));
}

test "rpc state applies only the semantically aligned wire event subset" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.applyWireEvent(.{ .bootstrap = 41 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(41));
    try state.applyWireEvent(.{ .finish = 41 });
    try state.applyWireEvent(.{ .return_ = 41 });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(41));

    try state.addImport(42);
    try state.applyWireEvent(.{ .release = .{ .id = 42, .reference_count = 1 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(42));

    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 99 }));
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .provide = 99 }));
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .accept = 99 }));
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .join = 99 }));
}

test "rpc wire release counts decrement import references" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.imports.put(50, .{ .id = 50, .reference_count = 3 });
    try state.applyWireEvent(.{ .release = .{ .id = 50, .reference_count = 2 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(50));
    try testing.expectEqual(@as(?u32, 1), state.importReferenceCount(50));

    try state.applyWireEvent(.{ .release = .{ .id = 50, .reference_count = 1 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(50));
    try testing.expectEqual(@as(?u32, 0), state.importReferenceCount(50));
    try testing.expectError(error.ImportAlreadyReleased, state.applyWireEvent(.{ .release = .{ .id = 50, .reference_count = 1 } }));

    try state.imports.put(51, .{ .id = 51, .reference_count = 1 });
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .release = .{ .id = 51, .reference_count = 0 } }));
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .release = .{ .id = 51, .reference_count = 2 } }));
}
