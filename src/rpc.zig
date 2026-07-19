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

pub const Finish = struct {
    question_id: QuestionId,
    release_result_caps: bool,
};

pub const Return = struct {
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
};

pub const PromisedAnswerTarget = struct {
    question_id: QuestionId,
};

pub const PromisedAnswerOp = union(enum) {
    noop,
    get_pointer_field: u16,
};

pub const PromisedAnswerTargetOwned = struct {
    question_id: QuestionId,
    transform: []PromisedAnswerOp,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.transform);
        self.* = undefined;
    }
};

pub const CallTarget = union(enum) {
    imported_cap: ImportId,
    promised_answer: PromisedAnswerTarget,

    pub fn importId(self: CallTarget) ?ImportId {
        return switch (self) {
            .imported_cap => |id| id,
            else => null,
        };
    }

    pub fn promisedQuestionId(self: CallTarget) ?QuestionId {
        return switch (self) {
            .promised_answer => |answer| answer.question_id,
            else => null,
        };
    }
};

pub const CallTargetOwned = union(enum) {
    imported_cap: ImportId,
    promised_answer: PromisedAnswerTargetOwned,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .promised_answer => |*answer| answer.deinit(allocator),
            else => {},
        }
        self.* = undefined;
    }
};

pub const CapDescriptor = union(enum) {
    none,
    sender_hosted: ExportId,
    sender_promise: ExportId,
    receiver_hosted: ImportId,
    receiver_answer: PromisedAnswerTarget,
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
    return_: Return,
    finish: Finish,
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
            .bootstrap, .call, .return_, .finish, .resolve, .provide, .accept, .third_party_answer, .join => true,
            .release => |release| release.reference_count != 0,
            else => false,
        };
    }

    pub fn isQuestionOpening(self: WireEvent) bool {
        return switch (self) {
            .bootstrap, .call, .provide, .accept, .join => true,
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
            .return_, .third_party_answer => true,
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
            .bootstrap, .call, .provide, .accept, .join => |id| id,
            .finish => |finish| finish.question_id,
            else => null,
        };
    }

    pub fn answerId(self: WireEvent) ?AnswerId {
        return switch (self) {
            .third_party_answer => |id| id,
            .return_ => |return_| return_.answer_id,
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
            .return_ => |return_| .{ .return_ = return_.answer_id },
            .finish => |finish| .{ .finish = finish.question_id },
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
        resolved: bool = false,

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

        pub fn resolve(self: *@This()) Error!void {
            if (self.state != .live) return error.InvalidTransition;
            if (self.resolved) return error.InvalidTransition;
            self.resolved = true;
        }

        pub fn isLive(self: @This()) bool {
            return self.state.isLive();
        }
    };
}

pub const ExportTracker = CapabilityTracker(ExportId, error.ExportAlreadyReleased);
pub const ImportTracker = CapabilityTracker(ImportId, error.ImportAlreadyReleased);

pub fn targetFromWireMessageTarget(target: anytype) !CallTarget {
    return switch (target.which() orelse return error.InvalidTransition) {
        .importedCap => .{ .imported_cap = try target.importedCap() },
        .promisedAnswer => blk: {
            const promised_answer = try target.promisedAnswer();
            break :blk .{ .promised_answer = .{ .question_id = promised_answer.questionId() } };
        },
    };
}

pub fn targetFromWireMessageTargetAlloc(allocator: std.mem.Allocator, target: anytype) !CallTargetOwned {
    return switch (target.which() orelse return error.InvalidTransition) {
        .importedCap => .{ .imported_cap = try target.importedCap() },
        .promisedAnswer => blk: {
            const promised_answer = try target.promisedAnswer();
            const transform = try promisedAnswerTransformFromWireAlloc(allocator, promised_answer);
            errdefer allocator.free(transform);
            break :blk .{ .promised_answer = .{
                .question_id = promised_answer.questionId(),
                .transform = transform,
            } };
        },
    };
}

pub fn promisedAnswerTransformFromWireAlloc(allocator: std.mem.Allocator, promised_answer: anytype) ![]PromisedAnswerOp {
    const transform = promised_answer.transform() catch |err| switch (err) {
        error.NullPointer => return allocator.alloc(PromisedAnswerOp, 0),
        else => return err,
    };
    const ops = try allocator.alloc(PromisedAnswerOp, transform.len());
    errdefer allocator.free(ops);
    for (ops, 0..) |*op, index| {
        const wire_op = try transform.get(index);
        op.* = switch (wire_op.which() orelse return error.InvalidTransition) {
            .noop => .noop,
            .getPointerField => .{ .get_pointer_field = try wire_op.getPointerField() },
        };
    }
    return ops;
}

pub fn initWirePromisedAnswerTransform(promised_answer: anytype, ops: []const PromisedAnswerOp) !void {
    const transform = try promised_answer.init_transform(ops.len);
    for (ops, 0..) |op, index| {
        const wire_op = try transform.get(index);
        switch (op) {
            .noop => try wire_op.set_noop(),
            .get_pointer_field => |field_index| try wire_op.set_getPointerField(field_index),
        }
    }
}

pub fn callTargetFromWireCall(call: anytype) !CallTarget {
    return targetFromWireMessageTarget(try call.target());
}

pub fn callTargetFromWireCallAlloc(allocator: std.mem.Allocator, call: anytype) !CallTargetOwned {
    return targetFromWireMessageTargetAlloc(allocator, try call.target());
}

pub fn targetFromWireTargetedMessage(message: anytype) !CallTarget {
    return targetFromWireMessageTarget(try message.target());
}

pub fn capDescriptorFromWire(descriptor: anytype) !CapDescriptor {
    return switch (descriptor.which() orelse return error.InvalidTransition) {
        .none => .none,
        .senderHosted => .{ .sender_hosted = try descriptor.senderHosted() },
        .senderPromise => .{ .sender_promise = try descriptor.senderPromise() },
        .receiverHosted => .{ .receiver_hosted = try descriptor.receiverHosted() },
        .receiverAnswer => blk: {
            const promised_answer = try descriptor.receiverAnswer();
            break :blk .{ .receiver_answer = .{ .question_id = promised_answer.questionId() } };
        },
    };
}

pub fn writeCapDescriptorToWire(descriptor: CapDescriptor, builder: anytype) !void {
    switch (descriptor) {
        .none => try builder.set_none(),
        .sender_hosted => |id| try builder.set_senderHosted(id),
        .sender_promise => |id| try builder.set_senderPromise(id),
        .receiver_hosted => |id| try builder.set_receiverHosted(id),
        .receiver_answer => |answer| {
            const receiver_answer = try builder.init_receiverAnswer();
            try receiver_answer.set_questionId(answer.question_id);
        },
    }
}

pub fn initWirePayloadCapTable(payload: anytype, descriptors: []const CapDescriptor) !void {
    const cap_table = try payload.init_capTable(descriptors.len);
    for (descriptors, 0..) |descriptor, index| {
        try writeCapDescriptorToWire(descriptor, try cap_table.get(index));
    }
}

pub fn capTableFromWirePayload(allocator: std.mem.Allocator, payload: anytype) ![]CapDescriptor {
    const cap_table = payload.capTable() catch |err| switch (err) {
        error.NullPointer => return allocator.alloc(CapDescriptor, 0),
        else => return err,
    };
    const descriptors = try allocator.alloc(CapDescriptor, cap_table.len());
    errdefer allocator.free(descriptors);
    for (descriptors, 0..) |*descriptor, index| {
        descriptor.* = try capDescriptorFromWire(try cap_table.get(index));
    }
    return descriptors;
}

pub fn capTableFromWireCallParams(allocator: std.mem.Allocator, call: anytype) ![]CapDescriptor {
    return capTableFromWirePayload(allocator, try call.params());
}

pub fn capTableFromWireReturnResults(allocator: std.mem.Allocator, return_: anytype) ![]CapDescriptor {
    return capTableFromWirePayload(allocator, try return_.results());
}

fn capDescriptorImportIdsAlloc(allocator: std.mem.Allocator, descriptors: []const CapDescriptor) std.mem.Allocator.Error![]ImportId {
    var count: usize = 0;
    for (descriptors) |descriptor| switch (descriptor) {
        .sender_hosted, .sender_promise => count += 1,
        else => {},
    };

    const ids = try allocator.alloc(ImportId, count);
    var index: usize = 0;
    for (descriptors) |descriptor| switch (descriptor) {
        .sender_hosted, .sender_promise => |id| {
            ids[index] = id;
            index += 1;
        },
        else => {},
    };
    return ids;
}

fn validateWirePayloadContent(payload: anytype, cap_count: usize) !void {
    const content = try payload.content();
    _ = try content.validateWithOptions(.{ .capability_count_limit = cap_count });
}

pub fn validateWirePayload(allocator: std.mem.Allocator, payload: anytype) !void {
    const descriptors = try capTableFromWirePayload(allocator, payload);
    defer allocator.free(descriptors);
    try validateWirePayloadContent(payload, descriptors.len);
}

pub fn eventFromWireMessage(message: anytype) !WireEvent {
    const raw_discriminant = message.whichDiscriminant();
    const tag = std.enums.fromInt(WireMessageTag, raw_discriminant) orelse return error.InvalidTransition;
    return switch (tag) {
        .unimplemented => .{ .unimplemented = {} },
        .abort => .{ .abort = {} },
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
    allocator: std.mem.Allocator,
    questions: std.AutoHashMap(QuestionId, QuestionTracker),
    answers: std.AutoHashMap(AnswerId, AnswerTracker),
    exports: std.AutoHashMap(ExportId, ExportTracker),
    imports: std.AutoHashMap(ImportId, ImportTracker),
    param_imports: std.AutoHashMap(QuestionId, []ImportId),
    result_imports: std.AutoHashMap(AnswerId, []ImportId),

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .allocator = allocator,
            .questions = std.AutoHashMap(QuestionId, QuestionTracker).init(allocator),
            .answers = std.AutoHashMap(AnswerId, AnswerTracker).init(allocator),
            .exports = std.AutoHashMap(ExportId, ExportTracker).init(allocator),
            .imports = std.AutoHashMap(ImportId, ImportTracker).init(allocator),
            .param_imports = std.AutoHashMap(QuestionId, []ImportId).init(allocator),
            .result_imports = std.AutoHashMap(AnswerId, []ImportId).init(allocator),
        };
    }

    pub fn deinit(self: *State) void {
        var result_imports = self.result_imports.valueIterator();
        while (result_imports.next()) |ids| self.allocator.free(ids.*);
        self.result_imports.deinit();
        var imports = self.param_imports.valueIterator();
        while (imports.next()) |ids| self.allocator.free(ids.*);
        self.param_imports.deinit();
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

    fn clearParamImports(self: *State, id: QuestionId) void {
        if (self.param_imports.fetchRemove(id)) |entry| {
            self.allocator.free(entry.value);
        }
    }

    fn clearResultImports(self: *State, id: AnswerId) void {
        if (self.result_imports.fetchRemove(id)) |entry| {
            self.allocator.free(entry.value);
        }
    }

    pub fn questionComplete(self: *const State, id: QuestionId) bool {
        const question = self.questions.get(id) orelse return false;
        const answer = self.answers.get(id) orelse return false;
        return question.state == .finished and answer.state == .resolved;
    }

    pub fn answerComplete(self: *const State, id: AnswerId) bool {
        const answer = self.answers.get(id) orelse return false;
        return answer.state == .resolved;
    }

    pub fn canReuseQuestionId(self: *const State, id: QuestionId) bool {
        return (!self.questions.contains(id) and !self.answers.contains(id)) or self.questionComplete(id);
    }

    pub fn openQuestion(self: *State, id: QuestionId, kind: MessageKind) (Error || std.mem.Allocator.Error)!void {
        if (!kind.isQuestionOpening()) return error.InvalidTransition;
        if (self.questions.getPtr(id)) |existing_question| {
            const existing_answer = self.answers.getPtr(id) orelse return error.AnswerAlreadyResolved;
            if (existing_question.state != .finished) return error.QuestionAlreadyOpen;
            if (existing_answer.state != .resolved) return error.AnswerAlreadyResolved;

            // Once both halves of the question/answer pair have completed,
            // rpc.capnp permits the ID to be reused. Reset in place instead of
            // removing/reinserting so any allocation failure cannot leave the
            // two hash maps out of sync.
            self.clearParamImports(id);
            self.clearResultImports(id);
            existing_question.* = .{ .id = id };
            try existing_question.open(kind);
            existing_answer.* = .{ .id = id };
            return;
        } else if (self.answers.contains(id)) {
            return error.AnswerAlreadyResolved;
        }

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

    pub fn receiveImport(self: *State, id: ImportId) (Error || std.mem.Allocator.Error)!void {
        if (self.imports.getPtr(id)) |tracker| {
            if (tracker.state != .live) return error.ImportAlreadyReleased;
            if (tracker.reference_count == std.math.maxInt(u32)) return error.InvalidTransition;
            tracker.reference_count += 1;
            return;
        }
        try self.imports.put(id, .{ .id = id });
    }

    fn validateCapDescriptor(self: *const State, descriptor: CapDescriptor) Error!void {
        switch (descriptor) {
            .none, .sender_hosted, .sender_promise => {},
            .receiver_hosted => |id| {
                const tracker = self.exports.get(id) orelse return error.InvalidTransition;
                if (tracker.state != .live) return error.ExportAlreadyReleased;
            },
            .receiver_answer => |answer| {
                if (!self.answers.contains(answer.question_id)) return error.QuestionNotOpen;
            },
        }
    }

    pub fn applyCapDescriptor(self: *State, descriptor: CapDescriptor) (Error || std.mem.Allocator.Error)!void {
        try self.validateCapDescriptor(descriptor);
        return switch (descriptor) {
            .none, .receiver_hosted, .receiver_answer => {},
            .sender_hosted => |id| self.receiveImport(id),
            .sender_promise => |id| self.receiveImport(id),
        };
    }

    pub fn applyCapTable(self: *State, descriptors: []const CapDescriptor) (Error || std.mem.Allocator.Error)!void {
        for (descriptors) |descriptor| try self.validateCapDescriptor(descriptor);
        for (descriptors) |descriptor| try self.applyCapDescriptor(descriptor);
    }

    pub fn paramImportCount(self: *const State, id: QuestionId) usize {
        const ids = self.param_imports.get(id) orelse return 0;
        return ids.len;
    }

    pub fn resultImportCount(self: *const State, id: AnswerId) usize {
        const ids = self.result_imports.get(id) orelse return 0;
        return ids.len;
    }

    fn trackParamImports(self: *State, question_id: QuestionId, descriptors: []const CapDescriptor) std.mem.Allocator.Error!void {
        const ids = try capDescriptorImportIdsAlloc(self.allocator, descriptors);
        errdefer self.allocator.free(ids);
        if (self.param_imports.fetchRemove(question_id)) |old| self.allocator.free(old.value);
        try self.param_imports.put(question_id, ids);
    }

    fn releaseParamImports(self: *State, question_id: QuestionId) Error!void {
        const entry = self.param_imports.fetchRemove(question_id) orelse return;
        defer self.allocator.free(entry.value);
        for (entry.value) |id| try self.releaseImport(id);
    }

    fn trackResultImports(self: *State, answer_id: AnswerId, descriptors: []const CapDescriptor) std.mem.Allocator.Error!void {
        const ids = try capDescriptorImportIdsAlloc(self.allocator, descriptors);
        errdefer self.allocator.free(ids);
        if (self.result_imports.fetchRemove(answer_id)) |old| self.allocator.free(old.value);
        try self.result_imports.put(answer_id, ids);
    }

    fn releaseResultImports(self: *State, answer_id: AnswerId) Error!void {
        const entry = self.result_imports.fetchRemove(answer_id) orelse return;
        defer self.allocator.free(entry.value);
        for (entry.value) |id| try self.releaseImport(id);
    }

    pub fn applyWireCallPayload(self: *State, allocator: std.mem.Allocator, call: anytype) !void {
        const descriptors = try capTableFromWireCallParams(allocator, call);
        defer allocator.free(descriptors);
        try self.applyCapTable(descriptors);
    }

    pub fn applyWireReturnPayload(self: *State, allocator: std.mem.Allocator, return_: anytype) !void {
        const descriptors = try capTableFromWireReturnResults(allocator, return_);
        defer allocator.free(descriptors);
        try self.applyCapTable(descriptors);
    }

    pub fn validateCallTarget(self: *const State, target: CallTarget) Error!void {
        switch (target) {
            .imported_cap => |id| {
                const tracker = self.imports.get(id) orelse return error.InvalidTransition;
                if (tracker.state != .live) return error.ImportAlreadyReleased;
            },
            .promised_answer => |answer| {
                if (!self.answers.contains(answer.question_id)) return error.QuestionNotOpen;
            },
        }
    }

    pub fn validateWireCallTarget(self: *const State, call: anytype) !void {
        try self.validateCallTarget(try callTargetFromWireCall(call));
    }

    pub fn applyWireCall(self: *State, allocator: std.mem.Allocator, call: anytype) !void {
        const question_id = call.questionId();
        const target = try callTargetFromWireCall(call);
        const descriptors = try capTableFromWireCallParams(allocator, call);
        defer allocator.free(descriptors);

        try self.validateCallTarget(target);
        try validateWirePayloadContent(try call.params(), descriptors.len);
        for (descriptors) |descriptor| try self.validateCapDescriptor(descriptor);
        try self.openQuestion(question_id, .call);
        for (descriptors) |descriptor| try self.applyCapDescriptor(descriptor);
        try self.trackParamImports(question_id, descriptors);
    }

    pub fn applyWireReturn(self: *State, allocator: std.mem.Allocator, return_: anytype) !void {
        const answer_id = return_.answerId();
        const release_param_caps = return_.releaseParamCaps();
        const no_finish_needed = return_.noFinishNeeded();
        const descriptors = try capTableFromWireReturnResults(allocator, return_);
        defer allocator.free(descriptors);

        try validateWirePayloadContent(try return_.results(), descriptors.len);
        for (descriptors) |descriptor| try self.validateCapDescriptor(descriptor);
        try self.resolveAnswer(answer_id, .return_);
        for (descriptors) |descriptor| try self.applyCapDescriptor(descriptor);
        try self.trackResultImports(answer_id, descriptors);
        if (release_param_caps) try self.releaseParamImports(answer_id);
        if (no_finish_needed and descriptors.len == 0) {
            try self.finishQuestion(answer_id);
        }
    }

    pub fn applyWireTargetedQuestion(self: *State, question_id: QuestionId, targeted: anytype) !void {
        try self.validateCallTarget(try targetFromWireTargetedMessage(targeted));
        try self.openQuestion(question_id, .call);
    }

    pub fn applyWireAccept(self: *State, accept: anytype) !void {
        try self.openQuestion(accept.questionId(), .call);
    }

    pub fn applyWireMessage(self: *State, allocator: std.mem.Allocator, message: anytype) !void {
        const event = try eventFromWireMessage(message);
        return switch (event) {
            .call => self.applyWireCall(allocator, try message.call()),
            .return_ => self.applyWireReturn(allocator, try message.return_()),
            .provide => |id| self.applyWireTargetedQuestion(id, try message.provide()),
            .accept => self.applyWireAccept(try message.accept()),
            .join => |id| self.applyWireTargetedQuestion(id, try message.join()),
            else => self.applyWireEvent(event),
        };
    }

    pub fn applyWireFinish(self: *State, finish: Finish) Error!void {
        try self.finishQuestion(finish.question_id);
        if (finish.release_result_caps) try self.releaseResultImports(finish.question_id);
    }

    pub fn releaseExport(self: *State, id: ExportId) Error!void {
        const tracker = self.exports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.release();
    }

    pub fn resolveExport(self: *State, id: ExportId) Error!void {
        const tracker = self.exports.getPtr(id) orelse return error.InvalidTransition;
        try tracker.resolve();
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

    pub fn exportResolved(self: *const State, id: ExportId) ?bool {
        const tracker = self.exports.get(id) orelse return null;
        return tracker.resolved;
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
        if (event == .resolve) return self.resolveExport(event.resolve);
        if (event == .release) return self.releaseImportCount(event.release);
        if (event == .finish) return self.applyWireFinish(event.finish);
        if (event == .provide) return self.openQuestion(event.provide, .call);
        if (event == .accept) return self.openQuestion(event.accept, .call);
        if (event == .third_party_answer) return self.resolveAnswer(event.third_party_answer, .return_);
        if (event == .join) return self.openQuestion(event.join, .call);
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

    const return_event = WireEvent{ .return_ = .{ .answer_id = 13, .release_param_caps = true, .no_finish_needed = false } };
    try testing.expect(return_event.isAnswerResolving());
    try testing.expectEqual(@as(?AnswerId, 13), return_event.answerId());

    const third_party_answer = WireEvent{ .third_party_answer = 18 };
    try testing.expect(third_party_answer.isStateApplicable());
    try testing.expect(third_party_answer.isAnswerResolving());
    try testing.expect(third_party_answer.toStateEvent() == null);
    try testing.expectEqual(@as(?AnswerId, 18), third_party_answer.answerId());

    const release_event = WireEvent{ .release = .{ .id = 14, .reference_count = 3 } };
    try testing.expect(release_event.isCapabilityRelease());
    try testing.expectEqual(@as(?ImportId, 14), release_event.importId());
    try testing.expectEqual(@as(?u32, 3), release_event.releaseReferenceCount());
    try testing.expectEqual(@as(?ExportId, null), release_event.exportId());

    const resolve_event = WireEvent{ .resolve = 15 };
    try testing.expect(resolve_event.isStateApplicable());
    try testing.expect(resolve_event.toStateEvent() == null);
    try testing.expectEqual(@as(?ExportId, 15), resolve_event.exportId());

    const provide_event = WireEvent{ .provide = 16 };
    try testing.expect(provide_event.isStateApplicable());
    try testing.expect(provide_event.isQuestionOpening());
    try testing.expect(provide_event.toStateEvent() == null);
    try testing.expectEqual(@as(?QuestionId, 16), provide_event.questionId());

    const join_event = WireEvent{ .join = 17 };
    try testing.expect(join_event.isStateApplicable());
    try testing.expect(join_event.isQuestionOpening());
    try testing.expect(join_event.toStateEvent() == null);
    try testing.expectEqual(@as(?QuestionId, 17), join_event.questionId());
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
    try testing.expect(!state.questionComplete(1));
    try testing.expect(!state.canReuseQuestionId(1));
    try testing.expectError(error.AnswerAlreadyResolved, state.openQuestion(1, .call));

    try state.resolveAnswer(1, .return_);
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(1));
    try testing.expect(state.answerComplete(1));
    try testing.expectError(error.AnswerAlreadyResolved, state.resolveAnswer(1, .resolve));
    try testing.expectError(error.QuestionNotOpen, state.resolveAnswer(99, .return_));

    try testing.expect(state.questionComplete(1));
    try testing.expect(state.canReuseQuestionId(1));
    try state.openQuestion(1, .bootstrap);
    try testing.expectEqual(@as(usize, 1), state.questionCount());
    try testing.expectEqual(@as(usize, 1), state.answerCount());
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(1));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(1));
    try testing.expect(!state.answerComplete(1));
    try testing.expect(!state.canReuseQuestionId(1));
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

test "rpc state applies capability descriptors to table lifetimes" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.applyCapDescriptor(.{ .sender_hosted = 30 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(30));
    try testing.expectEqual(@as(?u32, 1), state.importReferenceCount(30));
    try state.applyCapDescriptor(.{ .sender_promise = 30 });
    try testing.expectEqual(@as(?u32, 2), state.importReferenceCount(30));

    try state.addExport(31);
    try state.applyCapDescriptor(.{ .receiver_hosted = 31 });
    try state.openQuestion(32, .call);
    try state.applyCapDescriptor(.{ .receiver_answer = .{ .question_id = 32 } });
    try state.applyCapDescriptor(.none);

    try testing.expectError(error.InvalidTransition, state.applyCapDescriptor(.{ .receiver_hosted = 99 }));
    try testing.expectError(error.QuestionNotOpen, state.applyCapDescriptor(.{ .receiver_answer = .{ .question_id = 99 } }));

    try state.releaseExport(31);
    try testing.expectError(error.ExportAlreadyReleased, state.applyCapDescriptor(.{ .receiver_hosted = 31 }));
}

test "rpc state validates capability tables before mutating them" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectError(error.InvalidTransition, state.applyCapTable(&.{
        .{ .sender_hosted = 40 },
        .{ .receiver_hosted = 404 },
    }));
    try testing.expectEqual(@as(?CapabilityLifetime, null), state.importState(40));

    try state.addExport(41);
    try state.applyCapTable(&.{
        .{ .sender_hosted = 40 },
        .{ .receiver_hosted = 41 },
    });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.importState(40));
}

test "rpc state validates call targets against imports and answers" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try testing.expectError(error.InvalidTransition, state.validateCallTarget(.{ .imported_cap = 60 }));
    try state.addImport(60);
    try state.validateCallTarget(.{ .imported_cap = 60 });
    try state.releaseImport(60);
    try testing.expectError(error.ImportAlreadyReleased, state.validateCallTarget(.{ .imported_cap = 60 }));

    try testing.expectError(error.QuestionNotOpen, state.validateCallTarget(.{ .promised_answer = .{ .question_id = 61 } }));
    try state.openQuestion(61, .bootstrap);
    try state.validateCallTarget(.{ .promised_answer = .{ .question_id = 61 } });
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
    try state.applyWireEvent(.{ .finish = .{ .question_id = 41, .release_result_caps = true } });
    try state.applyWireEvent(.{ .return_ = .{ .answer_id = 41, .release_param_caps = true, .no_finish_needed = false } });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(41));

    try state.openQuestion(102, .call);
    try state.applyWireEvent(.{ .third_party_answer = 102 });
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(102));

    try state.addImport(42);
    try state.applyWireEvent(.{ .release = .{ .id = 42, .reference_count = 1 } });
    try testing.expectEqual(@as(?CapabilityLifetime, .released), state.importState(42));

    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 99 }));
    try state.applyWireEvent(.{ .provide = 99 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(99));
    try state.applyWireEvent(.{ .accept = 100 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(100));
    try state.applyWireEvent(.{ .join = 101 });
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(101));
}

test "rpc wire provide accept and join open questions without projecting to capability events" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    const provide = WireEvent{ .provide = 71 };
    try testing.expect(provide.toStateEvent() == null);
    try state.applyWireEvent(provide);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(71));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(71));

    const accept = WireEvent{ .accept = 72 };
    try testing.expect(accept.toStateEvent() == null);
    try state.applyWireEvent(accept);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(72));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(72));

    const join = WireEvent{ .join = 73 };
    try testing.expect(join.toStateEvent() == null);
    try state.applyWireEvent(join);
    try testing.expectEqual(@as(?QuestionState, .open), state.questionState(73));
    try testing.expectEqual(@as(?AnswerState, .unresolved), state.answerState(73));

    try testing.expectError(error.QuestionAlreadyOpen, state.applyWireEvent(.{ .provide = 71 }));
}

test "rpc wire third-party answers resolve existing answers without projecting to returns" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    const answer = WireEvent{ .third_party_answer = 81 };
    try testing.expect(answer.toStateEvent() == null);
    try testing.expectError(error.QuestionNotOpen, state.applyWireEvent(answer));

    try state.openQuestion(81, .call);
    try state.applyWireEvent(answer);
    try testing.expectEqual(@as(?AnswerState, .resolved), state.answerState(81));
    try testing.expectError(error.AnswerAlreadyResolved, state.applyWireEvent(answer));
}

test "rpc wire resolve marks existing exports resolved" {
    const testing = std.testing;
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.addExport(48);
    try testing.expectEqual(@as(?bool, false), state.exportResolved(48));
    try state.applyWireEvent(.{ .resolve = 48 });
    try testing.expectEqual(@as(?CapabilityLifetime, .live), state.exportState(48));
    try testing.expectEqual(@as(?bool, true), state.exportResolved(48));
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 48 }));

    try state.addExport(49);
    try state.releaseExport(49);
    try testing.expectError(error.InvalidTransition, state.applyWireEvent(.{ .resolve = 49 }));
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
