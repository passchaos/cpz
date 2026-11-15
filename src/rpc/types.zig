const std = @import("std");

pub const QuestionId = u32;
pub const AnswerId = u32;
pub const ExportId = u32;
pub const ImportId = u32;

/// Errors produced by RPC state transitions and wire helpers.
pub const Error = error{
    InvalidTransition,
    QuestionAlreadyOpen,
    QuestionNotOpen,
    AnswerAlreadyResolved,
    ExportAlreadyReleased,
    ImportAlreadyReleased,
};

/// A lightweight reference to a capability by index or tracked ID.
pub const CapabilityRef = union(enum) {
    export_id: ExportId,
    import_id: ImportId,

    pub fn isExport(self: @This()) bool {
        return self == .export_id;
    }

    pub fn isImport(self: @This()) bool {
        return self == .import_id;
    }

    pub fn exportId(self: @This()) ?ExportId {
        return switch (self) {
            .export_id => |id| id,
            else => null,
        };
    }

    pub fn importId(self: @This()) ?ImportId {
        return switch (self) {
            .import_id => |id| id,
            else => null,
        };
    }

    pub fn matchesExport(self: @This(), id: ExportId) bool {
        return self.exportId() == id;
    }

    pub fn matchesImport(self: @This(), id: ImportId) bool {
        return self.importId() == id;
    }
};

pub const CapabilityRelease = struct {
    id: ImportId,
    reference_count: u32,

    pub fn hasReferences(self: @This()) bool {
        return self.reference_count != 0;
    }

    pub fn isSingleReference(self: @This()) bool {
        return self.reference_count == 1;
    }
};

/// Finish message fields for closing a question.
pub const Finish = struct {
    question_id: QuestionId,
    release_result_caps: bool,

    pub fn releasesResultCaps(self: @This()) bool {
        return self.release_result_caps;
    }
};

/// Return message fields for resolving an answer.
pub const Return = struct {
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,

    pub fn releasesParamCaps(self: @This()) bool {
        return self.release_param_caps;
    }

    pub fn noFinishNeeded(self: @This()) bool {
        return self.no_finish_needed;
    }

    pub fn needsFinish(self: @This()) bool {
        return !self.no_finish_needed;
    }
};

/// Standard Cap'n Proto exception type codes.
pub const ExceptionType = enum(u16) {
    failed = 0,
    overloaded = 1,
    disconnected = 2,
    unimplemented = 3,
};

/// Decoded exception reason, type, and optional trace text.
pub const ExceptionInfo = struct {
    reason: ?[]const u8,
    type_raw: u16,
    trace: ?[]const u8 = null,

    pub fn hasReason(self: @This()) bool {
        return self.reason != null and self.reason.?.len != 0;
    }

    pub fn hasTrace(self: @This()) bool {
        return self.trace != null and self.trace.?.len != 0;
    }

    pub fn exceptionType(self: @This()) ?ExceptionType {
        return std.enums.fromInt(ExceptionType, self.type_raw);
    }

    pub fn matchesType(self: @This(), exception_type: ExceptionType) bool {
        return self.type_raw == @intFromEnum(exception_type);
    }

    pub fn isFailed(self: @This()) bool {
        return self.matchesType(.failed);
    }

    pub fn isOverloaded(self: @This()) bool {
        return self.matchesType(.overloaded);
    }

    pub fn isDisconnected(self: @This()) bool {
        return self.matchesType(.disconnected);
    }

    pub fn isUnimplemented(self: @This()) bool {
        return self.matchesType(.unimplemented);
    }
};

/// The possible semantic outcomes of a Return message.
pub const ReturnOutcome = union(enum) {
    results,
    exception: ExceptionInfo,
    canceled,
    results_sent_elsewhere,
    take_from_other_question: QuestionId,
    await_from_third_party: AnyPointerUsage,

    pub fn isResults(self: @This()) bool {
        return self == .results;
    }

    pub fn isException(self: @This()) bool {
        return self == .exception;
    }

    pub fn exceptionInfo(self: @This()) ?ExceptionInfo {
        return switch (self) {
            .exception => |exception| exception,
            else => null,
        };
    }

    pub fn isCanceled(self: @This()) bool {
        return self == .canceled;
    }

    pub fn isResultsSentElsewhere(self: @This()) bool {
        return self == .results_sent_elsewhere;
    }

    pub fn isTakeFromOtherQuestion(self: @This()) bool {
        return self == .take_from_other_question;
    }

    pub fn isAwaitFromThirdParty(self: @This()) bool {
        return self == .await_from_third_party;
    }

    pub fn isNonResult(self: @This()) bool {
        return !self.isResults();
    }

    pub fn takeFromOtherQuestionId(self: @This()) ?QuestionId {
        return switch (self) {
            .take_from_other_question => |id| id,
            else => null,
        };
    }

    pub fn awaitFromThirdPartyUsage(self: @This()) ?AnyPointerUsage {
        return switch (self) {
            .await_from_third_party => |usage| usage,
            else => null,
        };
    }

    pub fn awaitsThirdPartyCapability(self: @This(), capability_index: u32) bool {
        const usage = self.awaitFromThirdPartyUsage() orelse return false;
        return usage.matchesCapability(capability_index);
    }
};

/// A transport-independent result produced by a service dispatch callback.
pub const DispatchResult = union(enum) {
    empty,
    capability: ExportId,
    text: []const u8,
    data: []const u8,
    uint32_list: []const u32,
    exception: ExceptionInfo,
    canceled,
    results_sent_elsewhere,
    take_from_other_question: QuestionId,
    await_from_third_party: u32,

    pub fn isEmpty(self: @This()) bool {
        return self == .empty;
    }

    pub fn isCapability(self: @This()) bool {
        return self == .capability;
    }

    pub fn capabilityId(self: @This()) ?ExportId {
        return switch (self) {
            .capability => |id| id,
            else => null,
        };
    }

    pub fn textBytes(self: @This()) ?[]const u8 {
        return switch (self) {
            .text => |value| value,
            else => null,
        };
    }

    pub fn dataBytes(self: @This()) ?[]const u8 {
        return switch (self) {
            .data => |value| value,
            else => null,
        };
    }

    pub fn uint32Values(self: @This()) ?[]const u32 {
        return switch (self) {
            .uint32_list => |value| value,
            else => null,
        };
    }

    pub fn isException(self: @This()) bool {
        return self == .exception;
    }

    pub fn exceptionInfo(self: @This()) ?ExceptionInfo {
        return switch (self) {
            .exception => |exception| exception,
            else => null,
        };
    }

    pub fn isCanceled(self: @This()) bool {
        return self == .canceled;
    }

    pub fn isResultsSentElsewhere(self: @This()) bool {
        return self == .results_sent_elsewhere;
    }

    pub fn isTakeFromOtherQuestion(self: @This()) bool {
        return self == .take_from_other_question;
    }

    pub fn isAwaitFromThirdParty(self: @This()) bool {
        return self == .await_from_third_party;
    }

    pub fn isNonResult(self: @This()) bool {
        return switch (self) {
            .exception, .canceled, .results_sent_elsewhere, .take_from_other_question, .await_from_third_party => true,
            .empty, .capability, .text, .data, .uint32_list => false,
        };
    }

    pub fn isResult(self: @This()) bool {
        return !self.isNonResult();
    }

    pub fn takeFromOtherQuestionId(self: @This()) ?QuestionId {
        return switch (self) {
            .take_from_other_question => |id| id,
            else => null,
        };
    }

    pub fn awaitFromThirdPartyCapability(self: @This()) ?u32 {
        return switch (self) {
            .await_from_third_party => |capability_index| capability_index,
            else => null,
        };
    }

    pub fn awaitsThirdPartyCapability(self: @This(), capability_index: u32) bool {
        return self.awaitFromThirdPartyCapability() == capability_index;
    }
};

pub const WireDispatchOutcome = enum {
    response_initialized,
    /// The call target has already been resolved to another capability. The
    /// dispatcher recorded the inbound call in state, but deliberately did not
    /// initialize a response or invoke the local application handler; the
    /// transport/runtime layer should forward the original call instead.
    forward_required,
    state_applied,

    pub fn isResponseInitialized(self: @This()) bool {
        return self == .response_initialized;
    }

    pub fn isForwardRequired(self: @This()) bool {
        return self == .forward_required;
    }

    pub fn isStateApplied(self: @This()) bool {
        return self == .state_applied;
    }
};

pub const OutputRange = struct {
    start: usize,
    end: usize,

    pub fn len(self: @This()) usize {
        return self.end - self.start;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.start == self.end;
    }

    pub fn contains(self: @This(), index: usize) bool {
        return index >= self.start and index < self.end;
    }

    pub fn localIndex(self: @This(), index: usize) ?usize {
        if (!self.contains(index)) return null;
        return index - self.start;
    }

    pub fn validateCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.end) return error.InvalidTransition;
    }

    pub fn slice(self: @This(), items: anytype) !@TypeOf(items[self.start..self.end]) {
        try self.validateCapacity(items.len);
        return items[self.start..self.end];
    }
};

/// Aggregate counts for wire dispatch outputs and state-only actions.
pub const WireDispatchStats = struct {
    response_initialized: usize = 0,
    forward_required: usize = 0,
    state_applied: usize = 0,

    pub fn record(self: *@This(), outcome: WireDispatchOutcome) void {
        switch (outcome) {
            .response_initialized => self.response_initialized += 1,
            .forward_required => self.forward_required += 1,
            .state_applied => self.state_applied += 1,
        }
    }

    pub fn recordResponseInitialized(self: *@This()) void {
        self.record(.response_initialized);
    }

    pub fn recordForwardRequired(self: *@This()) void {
        self.record(.forward_required);
    }

    pub fn recordStateApplied(self: *@This()) void {
        self.record(.state_applied);
    }

    pub fn recordDenseOutputRole(self: *@This(), role: WireDispatchOutputRole) void {
        switch (role) {
            .response => self.response_initialized += 1,
            .forward => self.forward_required += 1,
        }
    }

    pub fn recordDenseOutputPosition(self: *@This(), position: WireDispatchOutputPosition) void {
        self.recordDenseOutputRole(position.role);
    }

    pub fn recordDenseOutputIndex(self: *@This(), source_stats: WireDispatchStats, output_index: usize) Error!void {
        const position = source_stats.unifiedDenseOutputPosition(output_index) orelse return error.InvalidTransition;
        self.recordDenseOutputPosition(position);
    }

    pub fn total(self: @This()) usize {
        return self.response_initialized + self.forward_required + self.state_applied;
    }

    pub fn hasWork(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
    }

    pub fn matchesStats(self: @This(), expected: WireDispatchStats) bool {
        return self.response_initialized == expected.response_initialized and
            self.forward_required == expected.forward_required and
            self.state_applied == expected.state_applied;
    }

    pub fn validateAgainstStats(self: @This(), expected: WireDispatchStats) Error!void {
        if (!self.matchesStats(expected)) return error.InvalidTransition;
    }

    pub fn denseResponseSlots(self: @This()) usize {
        return self.response_initialized;
    }

    pub fn denseForwardSlots(self: @This()) usize {
        return self.forward_required;
    }

    pub fn denseOutputSlots(self: @This()) usize {
        return self.response_initialized + self.forward_required;
    }

    pub fn denseOutputRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.denseOutputSlots() };
    }

    pub fn denseResponseRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.denseResponseSlots() };
    }

    pub fn denseForwardRange(self: @This()) OutputRange {
        const start = self.denseResponseSlots();
        return .{ .start = start, .end = start + self.denseForwardSlots() };
    }

    pub fn denseResponseLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.denseResponseRange().localIndex(output_index);
    }

    pub fn denseForwardLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.denseForwardRange().localIndex(output_index);
    }

    pub fn denseOutputLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.denseOutputRange().localIndex(output_index);
    }

    pub fn unifiedDenseOutputPosition(self: @This(), output_index: usize) ?WireDispatchOutputPosition {
        return wireDispatchUnifiedDenseOutputPosition(self, output_index);
    }

    pub fn nextDenseOutputPosition(self: @This(), role: WireDispatchOutputRole) WireDispatchOutputPosition {
        return switch (role) {
            .response => .{ .role = .response, .local_index = self.denseResponseSlots() },
            .forward => .{ .role = .forward, .local_index = self.denseForwardSlots() },
        };
    }

    pub fn denseOutputIndex(self: @This(), position: WireDispatchOutputPosition) ?usize {
        return switch (position.role) {
            .response => self.denseResponseOutputIndex(position.local_index),
            .forward => self.denseForwardOutputIndex(position.local_index),
        };
    }

    pub fn denseResponseOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.denseResponseSlots()) return null;
        return local_index;
    }

    pub fn denseForwardOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.denseForwardSlots()) return null;
        return self.denseResponseSlots() + local_index;
    }

    pub fn validateDenseResponseCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.denseResponseSlots()) return error.InvalidTransition;
    }

    pub fn validateDenseForwardCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.denseForwardSlots()) return error.InvalidTransition;
    }

    pub fn validateDenseOutputCapacity(self: @This(), response_capacity: usize, forward_capacity: usize) Error!void {
        try self.validateDenseResponseCapacity(response_capacity);
        try self.validateDenseForwardCapacity(forward_capacity);
    }

    pub fn validateDenseResponseBuilders(self: @This(), response_messages: anytype) Error!void {
        try self.validateDenseResponseCapacity(response_messages.len);
    }

    pub fn validateDenseForwardBuilders(self: @This(), forward_messages: anytype) Error!void {
        try self.validateDenseForwardCapacity(forward_messages.len);
    }

    pub fn validateDenseOutputBuilders(self: @This(), response_messages: anytype, forward_messages: anytype) Error!void {
        try self.validateDenseResponseBuilders(response_messages);
        try self.validateDenseForwardBuilders(forward_messages);
    }

    pub fn validateUnifiedDenseOutputCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.denseOutputSlots()) return error.InvalidTransition;
    }

    pub fn validateUnifiedDenseOutputBuilders(self: @This(), output_messages: anytype) Error!void {
        try self.validateUnifiedDenseOutputCapacity(output_messages.len);
    }

    pub fn initializedAnyResponse(self: @This()) bool {
        return self.response_initialized != 0;
    }

    pub fn requiredAnyForward(self: @This()) bool {
        return self.forward_required != 0;
    }

    pub fn appliedAnyState(self: @This()) bool {
        return self.state_applied != 0;
    }

    pub fn hasDenseResponses(self: @This()) bool {
        return self.denseResponseSlots() != 0;
    }

    pub fn hasDenseForwards(self: @This()) bool {
        return self.denseForwardSlots() != 0;
    }

    pub fn hasDenseOutputs(self: @This()) bool {
        return self.denseOutputSlots() != 0;
    }
};

pub const WireDispatchOutputRole = enum {
    response,
    forward,
};

pub const WireDispatchOutputPosition = struct {
    role: WireDispatchOutputRole,
    local_index: usize,

    pub fn isResponse(self: @This()) bool {
        return self.role == .response;
    }

    pub fn isForward(self: @This()) bool {
        return self.role == .forward;
    }
};

pub fn wireDispatchUnifiedDenseOutputPosition(stats: WireDispatchStats, output_index: usize) ?WireDispatchOutputPosition {
    if (stats.denseResponseLocalIndex(output_index)) |local_index| return .{ .role = .response, .local_index = local_index };
    if (stats.denseForwardLocalIndex(output_index)) |local_index| return .{ .role = .forward, .local_index = local_index };

    return null;
}

pub const StateCleanupStats = struct {
    questions: usize = 0,
    exports: usize = 0,
    imports: usize = 0,

    pub fn total(self: @This()) usize {
        return self.questions + self.exports + self.imports;
    }

    pub fn hasWork(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
    }

    pub fn hasQuestionWork(self: @This()) bool {
        return self.questions != 0;
    }

    pub fn hasExportWork(self: @This()) bool {
        return self.exports != 0;
    }

    pub fn hasImportWork(self: @This()) bool {
        return self.imports != 0;
    }

    pub fn hasCapabilityWork(self: @This()) bool {
        return self.exports != 0 or self.imports != 0;
    }
};

/// Aggregate counts for Provide/Accept/Join handoff state.
pub const StateHandoffStats = struct {
    provides: usize = 0,
    provide_recipients: usize = 0,
    accepts: usize = 0,
    pending_accept_embargos: usize = 0,
    ready_accept_provisions: usize = 0,
    joins: usize = 0,
    join_key_parts: usize = 0,

    pub fn tracked(self: @This()) usize {
        return self.provides + self.accepts + self.joins;
    }

    pub fn hasTracked(self: @This()) bool {
        return self.tracked() != 0;
    }

    pub fn hasProvides(self: @This()) bool {
        return self.provides != 0;
    }

    pub fn hasAccepts(self: @This()) bool {
        return self.accepts != 0;
    }

    pub fn hasJoins(self: @This()) bool {
        return self.joins != 0;
    }

    pub fn hasProvideRecipients(self: @This()) bool {
        return self.provide_recipients != 0;
    }

    pub fn hasPendingAcceptEmbargos(self: @This()) bool {
        return self.pending_accept_embargos != 0;
    }

    pub fn hasReadyAcceptProvisions(self: @This()) bool {
        return self.ready_accept_provisions != 0;
    }

    pub fn hasJoinKeyParts(self: @This()) bool {
        return self.join_key_parts != 0;
    }

    pub fn ready(self: @This()) usize {
        return self.provide_recipients + self.ready_accept_provisions + self.join_key_parts;
    }

    pub fn hasReady(self: @This()) bool {
        return self.ready() != 0;
    }

    pub fn blocked(self: @This()) usize {
        return self.pending_accept_embargos;
    }

    pub fn hasBlocked(self: @This()) bool {
        return self.blocked() != 0;
    }

    pub fn hasWork(self: @This()) bool {
        return self.hasTracked() or self.hasReady() or self.hasBlocked();
    }

    pub fn isEmpty(self: @This()) bool {
        return !self.hasWork();
    }
};

pub const StateReadyHandoffIds = struct {
    provides: []QuestionId,
    accepts: []QuestionId,
    joins: []QuestionId,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.provides);
        allocator.free(self.accepts);
        allocator.free(self.joins);
        self.* = undefined;
    }

    pub fn total(self: @This()) usize {
        return self.provides.len + self.accepts.len + self.joins.len;
    }

    pub fn hasReturns(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn hasProvides(self: @This()) bool {
        return self.provides.len != 0;
    }

    pub fn hasAccepts(self: @This()) bool {
        return self.accepts.len != 0;
    }

    pub fn hasJoins(self: @This()) bool {
        return self.joins.len != 0;
    }

    pub fn provideRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.provides.len };
    }

    pub fn acceptRange(self: @This()) OutputRange {
        const start = self.provides.len;
        return .{ .start = start, .end = start + self.accepts.len };
    }

    pub fn joinRange(self: @This()) OutputRange {
        const start = self.provides.len + self.accepts.len;
        return .{ .start = start, .end = start + self.joins.len };
    }

    pub fn provideLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.provideRange().localIndex(output_index);
    }

    pub fn acceptLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.acceptRange().localIndex(output_index);
    }

    pub fn joinLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.joinRange().localIndex(output_index);
    }

    pub fn unifiedOutputPosition(self: @This(), output_index: usize) ?HandoffReturnOutputPosition {
        return self.stats().unifiedOutputPosition(output_index);
    }

    pub fn questionIdAt(self: @This(), output_index: usize) ?QuestionId {
        if (self.provideLocalIndex(output_index)) |local_index| return self.provides[local_index];
        if (self.acceptLocalIndex(output_index)) |local_index| return self.accepts[local_index];
        if (self.joinLocalIndex(output_index)) |local_index| return self.joins[local_index];

        return null;
    }

    pub fn questionIdAtPosition(self: @This(), position: HandoffReturnOutputPosition) ?QuestionId {
        return switch (position.role) {
            .provide => if (position.local_index < self.provides.len) self.provides[position.local_index] else null,
            .accept => if (position.local_index < self.accepts.len) self.accepts[position.local_index] else null,
            .join => if (position.local_index < self.joins.len) self.joins[position.local_index] else null,
        };
    }

    pub fn stats(self: @This()) StateHandoffReturnStats {
        return .{
            .provides = self.provides.len,
            .accepts = self.accepts.len,
            .joins = self.joins.len,
        };
    }

    pub fn validateCapacity(self: @This(), capacity: usize) Error!void {
        try self.stats().validateCapacity(capacity);
    }
};

pub const HandoffReturnCapability = struct {
    question_id: QuestionId,
    export_id: ExportId,
};

pub const HandoffReturn = union(enum) {
    provide: HandoffReturnCapability,
    accept: HandoffReturnCapability,
    join: HandoffReturnCapability,

    pub fn isProvide(self: @This()) bool {
        return self == .provide;
    }

    pub fn isAccept(self: @This()) bool {
        return self == .accept;
    }

    pub fn isJoin(self: @This()) bool {
        return self == .join;
    }

    pub fn outputRole(self: @This()) HandoffReturnOutputRole {
        return switch (self) {
            .provide => .provide,
            .accept => .accept,
            .join => .join,
        };
    }

    pub fn capability(self: @This()) HandoffReturnCapability {
        return switch (self) {
            .provide, .accept, .join => |value| value,
        };
    }

    pub fn questionId(self: @This()) QuestionId {
        return self.capability().question_id;
    }

    pub fn exportId(self: @This()) ExportId {
        return self.capability().export_id;
    }
};

pub const HandoffReturnPlan = struct {
    provides: []const HandoffReturnCapability = &.{},
    accepts: []const HandoffReturnCapability = &.{},
    joins: []const HandoffReturnCapability = &.{},

    pub fn total(self: @This()) usize {
        return self.provides.len + self.accepts.len + self.joins.len;
    }

    pub fn hasReturns(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn hasProvides(self: @This()) bool {
        return self.provides.len != 0;
    }

    pub fn hasAccepts(self: @This()) bool {
        return self.accepts.len != 0;
    }

    pub fn hasJoins(self: @This()) bool {
        return self.joins.len != 0;
    }

    pub fn provideRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.provides.len };
    }

    pub fn acceptRange(self: @This()) OutputRange {
        const start = self.provides.len;
        return .{ .start = start, .end = start + self.accepts.len };
    }

    pub fn joinRange(self: @This()) OutputRange {
        const start = self.provides.len + self.accepts.len;
        return .{ .start = start, .end = start + self.joins.len };
    }

    pub fn provideLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.provideRange().localIndex(output_index);
    }

    pub fn acceptLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.acceptRange().localIndex(output_index);
    }

    pub fn joinLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.joinRange().localIndex(output_index);
    }

    pub fn unifiedOutputPosition(self: @This(), output_index: usize) ?HandoffReturnOutputPosition {
        return self.stats().unifiedOutputPosition(output_index);
    }

    pub fn completionAt(self: @This(), output_index: usize) ?HandoffReturn {
        if (self.provideLocalIndex(output_index)) |local_index| return .{ .provide = self.provides[local_index] };
        if (self.acceptLocalIndex(output_index)) |local_index| return .{ .accept = self.accepts[local_index] };
        if (self.joinLocalIndex(output_index)) |local_index| return .{ .join = self.joins[local_index] };

        return null;
    }

    pub fn completionAtPosition(self: @This(), position: HandoffReturnOutputPosition) ?HandoffReturn {
        return switch (position.role) {
            .provide => if (position.local_index < self.provides.len) .{ .provide = self.provides[position.local_index] } else null,
            .accept => if (position.local_index < self.accepts.len) .{ .accept = self.accepts[position.local_index] } else null,
            .join => if (position.local_index < self.joins.len) .{ .join = self.joins[position.local_index] } else null,
        };
    }

    pub fn capabilityAt(self: @This(), output_index: usize) ?HandoffReturnCapability {
        const completion = self.completionAt(output_index) orelse return null;
        return switch (completion) {
            .provide, .accept, .join => |value| value,
        };
    }

    pub fn capabilityAtPosition(self: @This(), position: HandoffReturnOutputPosition) ?HandoffReturnCapability {
        const completion = self.completionAtPosition(position) orelse return null;
        return switch (completion) {
            .provide, .accept, .join => |value| value,
        };
    }

    pub fn questionIdAt(self: @This(), output_index: usize) ?QuestionId {
        const completion = self.completionAt(output_index) orelse return null;
        return completion.questionId();
    }

    pub fn exportIdAt(self: @This(), output_index: usize) ?ExportId {
        const completion = self.completionAt(output_index) orelse return null;
        return completion.exportId();
    }

    pub fn questionIdAtPosition(self: @This(), position: HandoffReturnOutputPosition) ?QuestionId {
        const completion = self.completionAtPosition(position) orelse return null;
        return completion.questionId();
    }

    pub fn exportIdAtPosition(self: @This(), position: HandoffReturnOutputPosition) ?ExportId {
        const completion = self.completionAtPosition(position) orelse return null;
        return completion.exportId();
    }

    pub fn stats(self: @This()) StateHandoffReturnStats {
        return .{
            .provides = self.provides.len,
            .accepts = self.accepts.len,
            .joins = self.joins.len,
        };
    }

    pub fn validateCapacity(self: @This(), capacity: usize) Error!void {
        try self.stats().validateCapacity(capacity);
    }
};

pub const StateHandoffReturnStats = struct {
    provides: usize = 0,
    accepts: usize = 0,
    joins: usize = 0,

    pub fn record(self: *@This(), completion: HandoffReturn) void {
        self.recordRole(completion.outputRole());
    }

    pub fn recordRole(self: *@This(), role: HandoffReturnOutputRole) void {
        switch (role) {
            .provide => self.provides += 1,
            .accept => self.accepts += 1,
            .join => self.joins += 1,
        }
    }

    pub fn recordPosition(self: *@This(), position: HandoffReturnOutputPosition) void {
        self.recordRole(position.role);
    }

    pub fn recordOutputIndex(self: *@This(), source_stats: StateHandoffReturnStats, output_index: usize) Error!void {
        const position = source_stats.unifiedOutputPosition(output_index) orelse return error.InvalidTransition;
        self.recordPosition(position);
    }

    pub fn nextRolePosition(self: @This(), role: HandoffReturnOutputRole) HandoffReturnOutputPosition {
        return switch (role) {
            .provide => .{ .role = .provide, .local_index = self.provides },
            .accept => .{ .role = .accept, .local_index = self.accepts },
            .join => .{ .role = .join, .local_index = self.joins },
        };
    }

    pub fn nextPosition(self: @This(), completion: HandoffReturn) HandoffReturnOutputPosition {
        return self.nextRolePosition(completion.outputRole());
    }

    pub fn matchesStats(self: @This(), expected: StateHandoffReturnStats) bool {
        return self.provides == expected.provides and
            self.accepts == expected.accepts and
            self.joins == expected.joins;
    }

    pub fn matchesReadyIds(self: @This(), ready_ids: StateReadyHandoffIds) bool {
        return self.matchesStats(ready_ids.stats());
    }

    pub fn matchesPlan(self: @This(), plan: HandoffReturnPlan) bool {
        return self.matchesStats(plan.stats());
    }

    pub fn validateAgainstStats(self: @This(), expected: StateHandoffReturnStats) Error!void {
        if (!self.matchesStats(expected)) return error.InvalidTransition;
    }

    pub fn validateAgainstReadyIds(self: @This(), ready_ids: StateReadyHandoffIds) Error!void {
        try self.validateAgainstStats(ready_ids.stats());
    }

    pub fn validateAgainstPlan(self: @This(), plan: HandoffReturnPlan) Error!void {
        try self.validateAgainstStats(plan.stats());
    }

    pub fn total(self: @This()) usize {
        return self.provides + self.accepts + self.joins;
    }

    pub fn hasReturns(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn hasProvides(self: @This()) bool {
        return self.provides != 0;
    }

    pub fn hasAccepts(self: @This()) bool {
        return self.accepts != 0;
    }

    pub fn hasJoins(self: @This()) bool {
        return self.joins != 0;
    }

    pub fn provideRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.provides };
    }

    pub fn acceptRange(self: @This()) OutputRange {
        const start = self.provides;
        return .{ .start = start, .end = start + self.accepts };
    }

    pub fn joinRange(self: @This()) OutputRange {
        const start = self.provides + self.accepts;
        return .{ .start = start, .end = start + self.joins };
    }

    pub fn provideLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.provideRange().localIndex(output_index);
    }

    pub fn acceptLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.acceptRange().localIndex(output_index);
    }

    pub fn joinLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.joinRange().localIndex(output_index);
    }

    pub fn unifiedOutputPosition(self: @This(), output_index: usize) ?HandoffReturnOutputPosition {
        return handoffReturnUnifiedOutputPosition(self, output_index);
    }

    pub fn validateCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.total()) return error.InvalidTransition;
    }
};

pub const HandoffReturnOutputRole = enum {
    provide,
    accept,
    join,
};

pub const HandoffReturnOutputPosition = struct {
    role: HandoffReturnOutputRole,
    local_index: usize,

    pub fn isProvide(self: @This()) bool {
        return self.role == .provide;
    }

    pub fn isAccept(self: @This()) bool {
        return self.role == .accept;
    }

    pub fn isJoin(self: @This()) bool {
        return self.role == .join;
    }
};

pub fn handoffReturnUnifiedOutputPosition(stats: StateHandoffReturnStats, output_index: usize) ?HandoffReturnOutputPosition {
    if (stats.provideLocalIndex(output_index)) |local_index| return .{ .role = .provide, .local_index = local_index };
    if (stats.acceptLocalIndex(output_index)) |local_index| return .{ .role = .accept, .local_index = local_index };
    if (stats.joinLocalIndex(output_index)) |local_index| return .{ .role = .join, .local_index = local_index };

    return null;
}

/// Send grouped handoff Return outputs to a sink with their role/local-index.
///
/// The `StateHandoffReturnStats` ranges describe the grouped layout used by
/// ready handoff plans and handler-based ready return initialization: all
/// Provide Returns first, then Accept Returns, then Join Returns.  Callers that
/// initialize handoff returns from an arbitrary `[]HandoffReturn` sequence
/// should not use this helper unless they have already materialized that same
/// grouped layout.
pub fn sendHandoffReturnOutputsToTaggedSink(stats: StateHandoffReturnStats, response_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendHandoffReturnOutputsToTaggedSinkStats(stats, response_messages, sink_context, sink_handler);
}

pub fn sendHandoffReturnOutputsToTaggedSinkStats(stats: StateHandoffReturnStats, response_messages: anytype, sink_context: anytype, sink_handler: anytype) !StateHandoffReturnStats {
    try stats.validateCapacity(response_messages.len);
    for (response_messages[0..stats.total()], 0..) |message, output_index| {
        try sink_handler(sink_context, stats.unifiedOutputPosition(output_index).?, message);
    }
    return stats;
}

pub fn appendHandoffReturnOutputsToTaggedQueue(
    allocator: std.mem.Allocator,
    stats: StateHandoffReturnStats,
    response_messages: anytype,
    queue: anytype,
) !StateHandoffReturnStats {
    try stats.validateCapacity(response_messages.len);
    for (response_messages[0..stats.total()], 0..) |message, output_index| {
        try queue.append(allocator, .{ .position = stats.unifiedOutputPosition(output_index).?, .message = message });
    }
    return stats;
}

pub fn sendHandoffReturnOutputsToSinks(
    stats: StateHandoffReturnStats,
    response_messages: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !void {
    _ = try sendHandoffReturnOutputsToSinksStats(
        stats,
        response_messages,
        provide_context,
        provide_handler,
        accept_context,
        accept_handler,
        join_context,
        join_handler,
    );
}

pub fn sendHandoffReturnOutputsToSinksStats(
    stats: StateHandoffReturnStats,
    response_messages: anytype,
    provide_context: anytype,
    provide_handler: anytype,
    accept_context: anytype,
    accept_handler: anytype,
    join_context: anytype,
    join_handler: anytype,
) !StateHandoffReturnStats {
    try stats.validateCapacity(response_messages.len);
    for (try stats.provideRange().slice(response_messages)) |message| try provide_handler(provide_context, message);
    for (try stats.acceptRange().slice(response_messages)) |message| try accept_handler(accept_context, message);
    for (try stats.joinRange().slice(response_messages)) |message| try join_handler(join_context, message);
    return stats;
}

pub fn appendHandoffReturnOutputsToQueues(
    allocator: std.mem.Allocator,
    stats: StateHandoffReturnStats,
    response_messages: anytype,
    provide_queue: anytype,
    accept_queue: anytype,
    join_queue: anytype,
) !StateHandoffReturnStats {
    try stats.validateCapacity(response_messages.len);
    for (try stats.provideRange().slice(response_messages)) |message| try provide_queue.append(allocator, message);
    for (try stats.acceptRange().slice(response_messages)) |message| try accept_queue.append(allocator, message);
    for (try stats.joinRange().slice(response_messages)) |message| try join_queue.append(allocator, message);
    return stats;
}

/// A validated plan combining dispatch responses, handoff Returns, and Disembargos.
pub const RpcTurnPlan = struct {
    dispatch: WireDispatchStats = .{},
    handoff_returns: StateHandoffReturnStats = .{},
    pending_disembargos: usize = 0,

    pub fn dispatchResponseMessages(self: @This()) usize {
        return self.dispatch.response_initialized;
    }

    pub fn hasDispatchResponses(self: @This()) bool {
        return self.dispatchResponseMessages() != 0;
    }

    pub fn handoffReturnMessages(self: @This()) usize {
        return self.handoff_returns.total();
    }

    pub fn hasHandoffReturns(self: @This()) bool {
        return self.handoffReturnMessages() != 0;
    }

    pub fn responseMessages(self: @This()) usize {
        return self.dispatchResponseMessages() + self.handoffReturnMessages();
    }

    pub fn dispatchResponseRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.dispatchResponseMessages() };
    }

    pub fn handoffReturnRange(self: @This()) OutputRange {
        const start = self.dispatchResponseMessages();
        return .{ .start = start, .end = start + self.handoffReturnMessages() };
    }

    pub fn dispatchResponseLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.dispatchResponseRange().localIndex(output_index);
    }

    pub fn handoffReturnLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.handoffReturnRange().localIndex(output_index);
    }

    pub fn responseSourcePosition(self: @This(), output_index: usize) ?RpcTurnResponseSourcePosition {
        return rpcTurnResponseSourcePosition(self, output_index);
    }

    pub fn responseSourceOutputIndex(self: @This(), position: RpcTurnResponseSourcePosition) ?usize {
        return rpcTurnResponseSourceOutputIndex(self, position);
    }

    pub fn dispatchResponseOutputIndex(self: @This(), local_index: usize) ?usize {
        return self.responseSourceOutputIndex(.{ .role = .dispatch, .local_index = local_index });
    }

    pub fn handoffReturnOutputIndex(self: @This(), local_index: usize) ?usize {
        return self.responseSourceOutputIndex(.{ .role = .handoff_return, .local_index = local_index });
    }

    pub fn responseSourceStats(self: @This()) RpcTurnResponseSourceStats {
        return RpcTurnResponseSourceStats.fromTurnPlan(self);
    }

    pub fn hasResponses(self: @This()) bool {
        return self.responseMessages() != 0;
    }

    pub fn forwardedMessages(self: @This()) usize {
        return self.dispatch.forward_required;
    }

    pub fn hasForwards(self: @This()) bool {
        return self.forwardedMessages() != 0;
    }

    pub fn stateOnlyMessages(self: @This()) usize {
        return self.dispatch.state_applied;
    }

    pub fn hasStateOnly(self: @This()) bool {
        return self.stateOnlyMessages() != 0;
    }

    pub fn disembargoMessages(self: @This()) usize {
        return self.pending_disembargos;
    }

    pub fn hasDisembargos(self: @This()) bool {
        return self.disembargoMessages() != 0;
    }

    pub fn totalOutputMessages(self: @This()) usize {
        return self.responseMessages() + self.forwardedMessages() + self.disembargoMessages();
    }

    pub fn hasOutputs(self: @This()) bool {
        return self.totalOutputMessages() != 0;
    }

    pub fn hasWork(self: @This()) bool {
        return self.hasOutputs() or self.hasStateOnly();
    }

    pub fn isEmpty(self: @This()) bool {
        return !self.hasWork();
    }

    pub fn responseMessageRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.responseMessages() };
    }

    pub fn forwardedMessageRange(self: @This()) OutputRange {
        const start = self.responseMessages();
        return .{ .start = start, .end = start + self.forwardedMessages() };
    }

    pub fn disembargoMessageRange(self: @This()) OutputRange {
        const start = self.responseMessages() + self.forwardedMessages();
        return .{ .start = start, .end = start + self.disembargoMessages() };
    }

    pub fn responseLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.responseMessageRange().localIndex(output_index);
    }

    pub fn forwardLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.forwardedMessageRange().localIndex(output_index);
    }

    pub fn disembargoLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.disembargoMessageRange().localIndex(output_index);
    }

    pub fn unifiedOutputPosition(self: @This(), output_index: usize) ?RpcTurnOutputPosition {
        return rpcTurnUnifiedOutputPosition(self, output_index);
    }

    pub fn outputIndex(self: @This(), position: RpcTurnOutputPosition) ?usize {
        return switch (position.role) {
            .response => self.responseOutputIndex(position.local_index),
            .forward => self.forwardOutputIndex(position.local_index),
            .disembargo => self.disembargoOutputIndex(position.local_index),
        };
    }

    pub fn responseOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.responseMessages()) return null;
        return local_index;
    }

    pub fn forwardOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.forwardedMessages()) return null;
        return self.responseMessages() + local_index;
    }

    pub fn disembargoOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.disembargoMessages()) return null;
        return self.responseMessages() + self.forwardedMessages() + local_index;
    }

    pub fn validateResponseCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.responseMessages()) return error.InvalidTransition;
    }

    pub fn validateForwardCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.forwardedMessages()) return error.InvalidTransition;
    }

    pub fn validateOutputCapacity(self: @This(), response_capacity: usize, forward_capacity: usize) Error!void {
        try self.validateResponseCapacity(response_capacity);
        try self.validateForwardCapacity(forward_capacity);
    }

    pub fn validateUnifiedOutputCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.totalOutputMessages()) return error.InvalidTransition;
    }

    pub fn validateUnifiedOutputBuilders(self: @This(), output_messages: anytype) Error!void {
        try self.validateUnifiedOutputCapacity(output_messages.len);
    }

    pub fn validateResponseBuilders(self: @This(), response_messages: anytype) Error!void {
        try self.validateResponseCapacity(response_messages.len);
    }

    pub fn validateForwardBuilders(self: @This(), forward_messages: anytype) Error!void {
        try self.validateForwardCapacity(forward_messages.len);
    }

    pub fn validateOutputBuilders(self: @This(), response_messages: anytype, forward_messages: anytype) Error!void {
        try self.validateOutputCapacity(response_messages.len, forward_messages.len);
    }

    pub fn validateDisembargoCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.disembargoMessages()) return error.InvalidTransition;
    }

    pub fn validateDisembargoBuilders(self: @This(), disembargo_messages: anytype) Error!void {
        try self.validateDisembargoCapacity(disembargo_messages.len);
    }

    pub fn validateOutputBuilderSets(self: @This(), response_messages: anytype, forward_messages: anytype, disembargo_messages: anytype) Error!void {
        try self.validateOutputBuilders(response_messages, forward_messages);
        try self.validateDisembargoBuilders(disembargo_messages);
    }
};

pub const RpcTurnResponseSourceRole = enum {
    dispatch,
    handoff_return,
};

pub const RpcTurnResponseSourcePosition = struct {
    role: RpcTurnResponseSourceRole,
    local_index: usize,

    pub fn isDispatch(self: @This()) bool {
        return self.role == .dispatch;
    }

    pub fn isHandoffReturn(self: @This()) bool {
        return self.role == .handoff_return;
    }
};

pub const RpcTurnResponseSourceStats = struct {
    dispatch: usize = 0,
    handoff_returns: usize = 0,

    pub fn fromTurnPlan(turn_plan: RpcTurnPlan) @This() {
        return .{
            .dispatch = turn_plan.dispatchResponseMessages(),
            .handoff_returns = turn_plan.handoffReturnMessages(),
        };
    }

    pub fn fromDispatchStats(dispatch: WireDispatchStats) @This() {
        return .{ .dispatch = dispatch.response_initialized };
    }

    pub fn dispatchRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.dispatch };
    }

    pub fn handoffReturnRange(self: @This()) OutputRange {
        const start = self.dispatch;
        return .{ .start = start, .end = start + self.handoff_returns };
    }

    pub fn dispatchLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.dispatchRange().localIndex(output_index);
    }

    pub fn handoffReturnLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.handoffReturnRange().localIndex(output_index);
    }

    pub fn sourcePosition(self: @This(), output_index: usize) ?RpcTurnResponseSourcePosition {
        if (self.dispatchLocalIndex(output_index)) |local_index| return .{ .role = .dispatch, .local_index = local_index };
        if (self.handoffReturnLocalIndex(output_index)) |local_index| return .{ .role = .handoff_return, .local_index = local_index };

        return null;
    }

    pub fn sourceOutputIndex(self: @This(), position: RpcTurnResponseSourcePosition) ?usize {
        return switch (position.role) {
            .dispatch => if (position.local_index < self.dispatch) position.local_index else null,
            .handoff_return => if (position.local_index < self.handoff_returns) self.dispatch + position.local_index else null,
        };
    }

    pub fn recordRole(self: *@This(), role: RpcTurnResponseSourceRole) void {
        switch (role) {
            .dispatch => self.dispatch += 1,
            .handoff_return => self.handoff_returns += 1,
        }
    }

    pub fn recordPosition(self: *@This(), position: RpcTurnResponseSourcePosition) void {
        self.recordRole(position.role);
    }

    pub fn nextPosition(self: @This(), role: RpcTurnResponseSourceRole) RpcTurnResponseSourcePosition {
        return switch (role) {
            .dispatch => .{ .role = .dispatch, .local_index = self.dispatch },
            .handoff_return => .{ .role = .handoff_return, .local_index = self.handoff_returns },
        };
    }

    pub fn recordOutputIndex(self: *@This(), turn_plan: RpcTurnPlan, output_index: usize) Error!void {
        const position = turn_plan.responseSourcePosition(output_index) orelse return error.InvalidTransition;
        self.recordPosition(position);
    }

    pub fn total(self: @This()) usize {
        return self.dispatch + self.handoff_returns;
    }

    pub fn hasResponses(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
    }

    pub fn hasDispatchResponses(self: @This()) bool {
        return self.dispatch != 0;
    }

    pub fn hasHandoffReturns(self: @This()) bool {
        return self.handoff_returns != 0;
    }

    pub fn validateResponseCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.total()) return error.InvalidTransition;
    }

    pub fn validateResponseBuilders(self: @This(), response_messages: anytype) Error!void {
        try self.validateResponseCapacity(response_messages.len);
    }

    pub fn matchesStats(self: @This(), expected: RpcTurnResponseSourceStats) bool {
        return self.dispatch == expected.dispatch and self.handoff_returns == expected.handoff_returns;
    }

    pub fn validateAgainstStats(self: @This(), expected: RpcTurnResponseSourceStats) Error!void {
        if (!self.matchesStats(expected)) return error.InvalidTransition;
    }

    pub fn matchesDispatchStats(self: @This(), dispatch: WireDispatchStats) bool {
        return self.matchesStats(@This().fromDispatchStats(dispatch));
    }

    pub fn validateAgainstDispatchStats(self: @This(), dispatch: WireDispatchStats) Error!void {
        try self.validateAgainstStats(@This().fromDispatchStats(dispatch));
    }

    pub fn matchesTurnPlan(self: @This(), turn_plan: RpcTurnPlan) bool {
        const expected = @This().fromTurnPlan(turn_plan);
        return self.matchesStats(expected);
    }

    pub fn validateAgainstTurnPlan(self: @This(), turn_plan: RpcTurnPlan) Error!void {
        try self.validateAgainstStats(@This().fromTurnPlan(turn_plan));
    }
};

pub fn rpcTurnResponseSourcePosition(turn_plan: RpcTurnPlan, output_index: usize) ?RpcTurnResponseSourcePosition {
    if (turn_plan.dispatchResponseLocalIndex(output_index)) |local_index| return .{ .role = .dispatch, .local_index = local_index };
    if (turn_plan.handoffReturnLocalIndex(output_index)) |local_index| return .{ .role = .handoff_return, .local_index = local_index };

    return null;
}

pub fn rpcTurnResponseSourceOutputIndex(turn_plan: RpcTurnPlan, position: RpcTurnResponseSourcePosition) ?usize {
    return switch (position.role) {
        .dispatch => if (position.local_index < turn_plan.dispatchResponseMessages()) position.local_index else null,
        .handoff_return => if (position.local_index < turn_plan.handoffReturnMessages())
            turn_plan.dispatchResponseMessages() + position.local_index
        else
            null,
    };
}

pub const RpcTurnOutputRole = enum {
    response,
    forward,
    disembargo,
};

pub const RpcTurnOutputPosition = struct {
    role: RpcTurnOutputRole,
    /// Index within the role-specific output range.  For example, a value of
    /// `0` for `.forward` means the first forwarded Call, even if it appears
    /// after several response messages in the unified queue.
    local_index: usize,

    pub fn isResponse(self: @This()) bool {
        return self.role == .response;
    }

    pub fn isForward(self: @This()) bool {
        return self.role == .forward;
    }

    pub fn isDisembargo(self: @This()) bool {
        return self.role == .disembargo;
    }
};

/// Counts and ranges for initialized RPC turn outputs.
pub const RpcOutputStats = struct {
    responses: usize = 0,
    forwards: usize = 0,
    disembargos: usize = 0,

    pub fn fromDispatchStats(dispatch: WireDispatchStats) @This() {
        return .{
            .responses = dispatch.response_initialized,
            .forwards = dispatch.forward_required,
        };
    }

    pub fn fromTurnPlan(turn_plan: RpcTurnPlan) @This() {
        return .{
            .responses = turn_plan.responseMessages(),
            .forwards = turn_plan.forwardedMessages(),
            .disembargos = turn_plan.disembargoMessages(),
        };
    }

    pub fn fromServiceActionStats(stats: TrackedCallServiceActionStats) @This() {
        return .{
            .responses = stats.responseMessages(),
            .forwards = stats.forward,
        };
    }

    pub fn fromResponseSourceStats(stats: RpcTurnResponseSourceStats) @This() {
        return .{ .responses = stats.total() };
    }

    pub fn matchesStats(self: @This(), expected: RpcOutputStats) bool {
        return self.responses == expected.responses and
            self.forwards == expected.forwards and
            self.disembargos == expected.disembargos;
    }

    pub fn validateAgainstStats(self: @This(), expected: RpcOutputStats) Error!void {
        if (!self.matchesStats(expected)) return error.InvalidTransition;
    }

    pub fn matchesDispatchStats(self: @This(), dispatch: WireDispatchStats) bool {
        return self.matchesStats(@This().fromDispatchStats(dispatch));
    }

    pub fn matchesTurnPlan(self: @This(), turn_plan: RpcTurnPlan) bool {
        return self.matchesStats(@This().fromTurnPlan(turn_plan));
    }

    pub fn matchesServiceActionStats(self: @This(), stats: TrackedCallServiceActionStats) bool {
        return self.matchesStats(@This().fromServiceActionStats(stats));
    }

    pub fn matchesResponseSourceStats(self: @This(), stats: RpcTurnResponseSourceStats) bool {
        return self.matchesStats(@This().fromResponseSourceStats(stats));
    }

    pub fn validateAgainstDispatchStats(self: @This(), dispatch: WireDispatchStats) Error!void {
        try self.validateAgainstStats(@This().fromDispatchStats(dispatch));
    }

    pub fn validateAgainstTurnPlan(self: @This(), turn_plan: RpcTurnPlan) Error!void {
        try self.validateAgainstStats(@This().fromTurnPlan(turn_plan));
    }

    pub fn validateAgainstServiceActionStats(self: @This(), stats: TrackedCallServiceActionStats) Error!void {
        try self.validateAgainstStats(@This().fromServiceActionStats(stats));
    }

    pub fn validateAgainstResponseSourceStats(self: @This(), stats: RpcTurnResponseSourceStats) Error!void {
        try self.validateAgainstStats(@This().fromResponseSourceStats(stats));
    }

    pub fn validateResponseCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.responses) return error.InvalidTransition;
    }

    pub fn validateForwardCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.forwards) return error.InvalidTransition;
    }

    pub fn validateDisembargoCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.disembargos) return error.InvalidTransition;
    }

    pub fn validateSplitCapacity(self: @This(), response_capacity: usize, forward_capacity: usize, disembargo_capacity: usize) Error!void {
        try self.validateResponseCapacity(response_capacity);
        try self.validateForwardCapacity(forward_capacity);
        try self.validateDisembargoCapacity(disembargo_capacity);
    }

    pub fn validateUnifiedOutputCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.total()) return error.InvalidTransition;
    }

    pub fn validateResponseBuilders(self: @This(), response_messages: anytype) Error!void {
        try self.validateResponseCapacity(response_messages.len);
    }

    pub fn validateForwardBuilders(self: @This(), forward_messages: anytype) Error!void {
        try self.validateForwardCapacity(forward_messages.len);
    }

    pub fn validateDisembargoBuilders(self: @This(), disembargo_messages: anytype) Error!void {
        try self.validateDisembargoCapacity(disembargo_messages.len);
    }

    pub fn validateSplitBuilders(self: @This(), response_messages: anytype, forward_messages: anytype, disembargo_messages: anytype) Error!void {
        try self.validateSplitCapacity(response_messages.len, forward_messages.len, disembargo_messages.len);
    }

    pub fn validateUnifiedOutputBuilders(self: @This(), output_messages: anytype) Error!void {
        try self.validateUnifiedOutputCapacity(output_messages.len);
    }

    pub fn responseRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.responses };
    }

    pub fn forwardRange(self: @This()) OutputRange {
        const start = self.responses;
        return .{ .start = start, .end = start + self.forwards };
    }

    pub fn disembargoRange(self: @This()) OutputRange {
        const start = self.responses + self.forwards;
        return .{ .start = start, .end = start + self.disembargos };
    }

    pub fn responseLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.responseRange().localIndex(output_index);
    }

    pub fn forwardLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.forwardRange().localIndex(output_index);
    }

    pub fn disembargoLocalIndex(self: @This(), output_index: usize) ?usize {
        return self.disembargoRange().localIndex(output_index);
    }

    pub fn unifiedOutputPosition(self: @This(), output_index: usize) ?RpcTurnOutputPosition {
        if (self.responseLocalIndex(output_index)) |local_index| return .{ .role = .response, .local_index = local_index };
        if (self.forwardLocalIndex(output_index)) |local_index| return .{ .role = .forward, .local_index = local_index };
        if (self.disembargoLocalIndex(output_index)) |local_index| return .{ .role = .disembargo, .local_index = local_index };

        return null;
    }

    pub fn outputIndex(self: @This(), position: RpcTurnOutputPosition) ?usize {
        return switch (position.role) {
            .response => if (position.local_index < self.responses) position.local_index else null,
            .forward => if (position.local_index < self.forwards) self.responses + position.local_index else null,
            .disembargo => if (position.local_index < self.disembargos) self.responses + self.forwards + position.local_index else null,
        };
    }

    pub fn responseOutputIndex(self: @This(), local_index: usize) ?usize {
        return self.outputIndex(.{ .role = .response, .local_index = local_index });
    }

    pub fn forwardOutputIndex(self: @This(), local_index: usize) ?usize {
        return self.outputIndex(.{ .role = .forward, .local_index = local_index });
    }

    pub fn disembargoOutputIndex(self: @This(), local_index: usize) ?usize {
        return self.outputIndex(.{ .role = .disembargo, .local_index = local_index });
    }

    pub fn recordRole(self: *@This(), role: RpcTurnOutputRole) void {
        switch (role) {
            .response => self.responses += 1,
            .forward => self.forwards += 1,
            .disembargo => self.disembargos += 1,
        }
    }

    pub fn recordPosition(self: *@This(), position: RpcTurnOutputPosition) void {
        self.recordRole(position.role);
    }

    pub fn recordOutputIndex(self: *@This(), source_stats: RpcOutputStats, output_index: usize) Error!void {
        const position = source_stats.unifiedOutputPosition(output_index) orelse return error.InvalidTransition;
        self.recordPosition(position);
    }

    pub fn nextPosition(self: @This(), role: RpcTurnOutputRole) RpcTurnOutputPosition {
        return switch (role) {
            .response => .{ .role = .response, .local_index = self.responses },
            .forward => .{ .role = .forward, .local_index = self.forwards },
            .disembargo => .{ .role = .disembargo, .local_index = self.disembargos },
        };
    }

    pub fn recordServiceActionPosition(self: *@This(), position: TrackedCallServiceActionOutputPosition) void {
        switch (position.role) {
            .response => self.responses += 1,
            .forward => self.forwards += 1,
        }
    }

    pub fn recordWireDispatchPosition(self: *@This(), position: WireDispatchOutputPosition) void {
        switch (position.role) {
            .response => self.responses += 1,
            .forward => self.forwards += 1,
        }
    }

    pub fn recordTurnOutputIndex(self: *@This(), turn_plan: RpcTurnPlan, output_index: usize) Error!void {
        const position = rpcTurnUnifiedOutputPosition(turn_plan, output_index) orelse return error.InvalidTransition;
        self.recordPosition(position);
    }

    pub fn recordServiceActionOutputIndex(self: *@This(), stats: TrackedCallServiceActionStats, output_index: usize) Error!void {
        const position = stats.unifiedOutputPosition(output_index) orelse return error.InvalidTransition;
        self.recordServiceActionPosition(position);
    }

    pub fn recordWireDispatchOutputIndex(self: *@This(), stats: WireDispatchStats, output_index: usize) Error!void {
        const position = stats.unifiedDenseOutputPosition(output_index) orelse return error.InvalidTransition;
        self.recordWireDispatchPosition(position);
    }

    pub fn total(self: @This()) usize {
        return self.responses + self.forwards + self.disembargos;
    }

    pub fn hasOutputs(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
    }

    pub fn hasResponses(self: @This()) bool {
        return self.responses != 0;
    }

    pub fn hasForwards(self: @This()) bool {
        return self.forwards != 0;
    }

    pub fn hasDisembargos(self: @This()) bool {
        return self.disembargos != 0;
    }
};

pub fn rpcTurnUnifiedOutputPosition(turn_plan: RpcTurnPlan, output_index: usize) ?RpcTurnOutputPosition {
    if (turn_plan.responseLocalIndex(output_index)) |local_index| return .{ .role = .response, .local_index = local_index };
    if (turn_plan.forwardLocalIndex(output_index)) |local_index| return .{ .role = .forward, .local_index = local_index };
    if (turn_plan.disembargoLocalIndex(output_index)) |local_index| return .{ .role = .disembargo, .local_index = local_index };

    return null;
}

pub fn sendRpcTurnResponsesToSourceTaggedSink(turn_plan: RpcTurnPlan, response_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcTurnResponsesToSourceTaggedSinkStats(turn_plan, response_messages, sink_context, sink_handler);
}

pub fn sendRpcTurnResponsesToSourceTaggedSinkStats(turn_plan: RpcTurnPlan, response_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcTurnResponseSourceStats {
    try turn_plan.responseMessageRange().validateCapacity(response_messages.len);
    var stats: RpcTurnResponseSourceStats = .{};
    for (response_messages[0..turn_plan.responseMessages()], 0..) |message, output_index| {
        const position = turn_plan.responseSourcePosition(output_index).?;
        try sink_handler(sink_context, position, message);
        stats.recordPosition(position);
    }
    return stats;
}

pub fn appendRpcTurnResponsesToSourceTaggedQueue(
    allocator: std.mem.Allocator,
    turn_plan: RpcTurnPlan,
    response_messages: anytype,
    queue: anytype,
) !RpcTurnResponseSourceStats {
    try turn_plan.responseMessageRange().validateCapacity(response_messages.len);
    var stats: RpcTurnResponseSourceStats = .{};
    for (response_messages[0..turn_plan.responseMessages()], 0..) |message, output_index| {
        const position = turn_plan.responseSourcePosition(output_index).?;
        try queue.append(allocator, .{ .position = position, .message = message });
        stats.recordPosition(position);
    }
    return stats;
}

pub fn sendRpcTurnResponsesToSourceSinks(
    turn_plan: RpcTurnPlan,
    response_messages: anytype,
    dispatch_context: anytype,
    dispatch_handler: anytype,
    handoff_context: anytype,
    handoff_handler: anytype,
) !void {
    _ = try sendRpcTurnResponsesToSourceSinksStats(
        turn_plan,
        response_messages,
        dispatch_context,
        dispatch_handler,
        handoff_context,
        handoff_handler,
    );
}

pub fn sendRpcTurnResponsesToSourceSinksStats(
    turn_plan: RpcTurnPlan,
    response_messages: anytype,
    dispatch_context: anytype,
    dispatch_handler: anytype,
    handoff_context: anytype,
    handoff_handler: anytype,
) !RpcTurnResponseSourceStats {
    try turn_plan.responseMessageRange().validateCapacity(response_messages.len);
    var stats: RpcTurnResponseSourceStats = .{};
    for (try turn_plan.dispatchResponseRange().slice(response_messages)) |message| {
        try dispatch_handler(dispatch_context, message);
        stats.recordRole(.dispatch);
    }
    for (try turn_plan.handoffReturnRange().slice(response_messages)) |message| {
        try handoff_handler(handoff_context, message);
        stats.recordRole(.handoff_return);
    }
    return stats;
}

pub fn appendRpcTurnResponsesToSourceQueues(
    allocator: std.mem.Allocator,
    turn_plan: RpcTurnPlan,
    response_messages: anytype,
    dispatch_queue: anytype,
    handoff_queue: anytype,
) !RpcTurnResponseSourceStats {
    try turn_plan.responseMessageRange().validateCapacity(response_messages.len);
    var stats: RpcTurnResponseSourceStats = .{};
    for (try turn_plan.dispatchResponseRange().slice(response_messages)) |message| {
        try dispatch_queue.append(allocator, message);
        stats.recordRole(.dispatch);
    }
    for (try turn_plan.handoffReturnRange().slice(response_messages)) |message| {
        try handoff_queue.append(allocator, message);
        stats.recordRole(.handoff_return);
    }
    return stats;
}

/// Send exactly the initialized prefix of a unified RPC turn output queue to an
/// embedding transport/enqueue callback.
///
/// Unified turn helpers lay out initialized messages as responses (including
/// ready handoff Returns), forwarded Calls, then pending Disembargos.  Callers
/// commonly allocate a larger scratch queue than a particular turn needs; this
/// helper validates capacity up front and only exposes the initialized prefix to
/// the sink so transports do not accidentally serialize unused builder slots.
pub fn sendRpcTurnUnifiedOutputsToSink(turn_plan: RpcTurnPlan, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcTurnUnifiedOutputsToSinkStats(turn_plan, output_messages, sink_context, sink_handler);
}

pub fn sendRpcTurnUnifiedOutputsToSinkStats(turn_plan: RpcTurnPlan, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcOutputStats {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    for (output_messages[0..turn_plan.totalOutputMessages()]) |output_message| {
        try sink_handler(sink_context, output_message);
    }
    return RpcOutputStats.fromTurnPlan(turn_plan);
}

pub fn appendRpcTurnUnifiedOutputsToQueue(allocator: std.mem.Allocator, turn_plan: RpcTurnPlan, output_messages: anytype, queue: anytype) !RpcOutputStats {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    for (output_messages[0..turn_plan.totalOutputMessages()]) |output_message| {
        try queue.append(allocator, output_message);
    }
    return RpcOutputStats.fromTurnPlan(turn_plan);
}

/// Append initialized unified turn outputs together with their role metadata.
///
/// Plain queue append is useful for transports with a single outbound lane, but
/// many embedders still need the precomputed role/local-index information that
/// tagged sinks receive.  Queue element types should provide `position` and
/// `message` fields, e.g. `struct { position: RpcTurnOutputPosition,
/// message: Message.Builder }`.
pub fn appendRpcTurnUnifiedOutputsToTaggedQueue(allocator: std.mem.Allocator, turn_plan: RpcTurnPlan, output_messages: anytype, queue: anytype) !RpcOutputStats {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    var stats: RpcOutputStats = .{};
    for (output_messages[0..turn_plan.totalOutputMessages()], 0..) |output_message, output_index| {
        const position = rpcTurnUnifiedOutputPosition(turn_plan, output_index).?;
        try queue.append(allocator, .{ .position = position, .message = output_message });
        stats.recordPosition(position);
    }
    return stats;
}

/// Append initialized unified turn outputs to role-specific queues.
///
/// This is the queue-oriented counterpart to `sendRpcTurnUnifiedOutputsToSinks`.
/// It preserves the compact response/forward/Disembargo layout while letting a
/// polling or event-loop embedder keep distinct outbound queues for local
/// responses, forwarded Calls, and Disembargo traffic.
pub fn appendRpcTurnUnifiedOutputsToQueues(
    allocator: std.mem.Allocator,
    turn_plan: RpcTurnPlan,
    output_messages: anytype,
    response_queue: anytype,
    forward_queue: anytype,
    disembargo_queue: anytype,
) !RpcOutputStats {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);

    for (try turn_plan.responseMessageRange().slice(output_messages)) |output_message| {
        try response_queue.append(allocator, output_message);
    }
    for (try turn_plan.forwardedMessageRange().slice(output_messages)) |output_message| {
        try forward_queue.append(allocator, output_message);
    }
    for (try turn_plan.disembargoMessageRange().slice(output_messages)) |output_message| {
        try disembargo_queue.append(allocator, output_message);
    }
    return RpcOutputStats.fromTurnPlan(turn_plan);
}

/// Send initialized unified turn outputs to a single callback while tagging
/// each message with its role and role-local index.
///
/// This is useful for transports that keep one physical enqueue path but still
/// need to distinguish locally-produced Returns from forwarded Calls and
/// Disembargo traffic without decoding the message union after it is built.
pub fn sendRpcTurnUnifiedOutputsToTaggedSink(turn_plan: RpcTurnPlan, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !void {
    _ = try sendRpcTurnUnifiedOutputsToTaggedSinkStats(turn_plan, output_messages, sink_context, sink_handler);
}

pub fn sendRpcTurnUnifiedOutputsToTaggedSinkStats(turn_plan: RpcTurnPlan, output_messages: anytype, sink_context: anytype, sink_handler: anytype) !RpcOutputStats {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);
    var stats: RpcOutputStats = .{};
    for (output_messages[0..turn_plan.totalOutputMessages()], 0..) |output_message, output_index| {
        const position = rpcTurnUnifiedOutputPosition(turn_plan, output_index).?;
        try sink_handler(sink_context, position, output_message);
        stats.recordPosition(position);
    }
    return stats;
}

/// Send initialized unified turn outputs to role-specific enqueue callbacks.
///
/// This keeps the compact single-buffer allocation strategy while letting
/// runtimes route locally-produced Returns, forwarded Calls, and pending
/// Disembargos to different transport queues.  The ranges are derived from the
/// validated plan rather than recomputed from message union tags so the enqueue
/// order stays identical to the no-sink unified turn helpers.
pub fn sendRpcTurnUnifiedOutputsToSinks(
    turn_plan: RpcTurnPlan,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !void {
    _ = try sendRpcTurnUnifiedOutputsToSinksStats(
        turn_plan,
        output_messages,
        response_context,
        response_handler,
        forward_context,
        forward_handler,
        disembargo_context,
        disembargo_handler,
    );
}

pub fn sendRpcTurnUnifiedOutputsToSinksStats(
    turn_plan: RpcTurnPlan,
    output_messages: anytype,
    response_context: anytype,
    response_handler: anytype,
    forward_context: anytype,
    forward_handler: anytype,
    disembargo_context: anytype,
    disembargo_handler: anytype,
) !RpcOutputStats {
    try turn_plan.validateUnifiedOutputBuilders(output_messages);

    for (try turn_plan.responseMessageRange().slice(output_messages)) |output_message| {
        try response_handler(response_context, output_message);
    }
    for (try turn_plan.forwardedMessageRange().slice(output_messages)) |output_message| {
        try forward_handler(forward_context, output_message);
    }
    for (try turn_plan.disembargoMessageRange().slice(output_messages)) |output_message| {
        try disembargo_handler(disembargo_context, output_message);
    }
    return RpcOutputStats.fromTurnPlan(turn_plan);
}

pub const StateQuestionStats = struct {
    questions: usize = 0,
    open_questions: usize = 0,
    finished_questions: usize = 0,
    answers: usize = 0,
    unresolved_answers: usize = 0,
    resolved_answers: usize = 0,
    complete_questions: usize = 0,

    pub fn active(self: @This()) usize {
        return self.open_questions + self.unresolved_answers;
    }

    pub fn total(self: @This()) usize {
        return self.questions + self.answers;
    }

    pub fn hasEntries(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
    }

    pub fn hasQuestions(self: @This()) bool {
        return self.questions != 0;
    }

    pub fn hasAnswers(self: @This()) bool {
        return self.answers != 0;
    }

    pub fn hasOpenQuestions(self: @This()) bool {
        return self.open_questions != 0;
    }

    pub fn hasFinishedQuestions(self: @This()) bool {
        return self.finished_questions != 0;
    }

    pub fn hasUnresolvedAnswers(self: @This()) bool {
        return self.unresolved_answers != 0;
    }

    pub fn hasResolvedAnswers(self: @This()) bool {
        return self.resolved_answers != 0;
    }

    pub fn hasActive(self: @This()) bool {
        return self.active() != 0;
    }

    pub fn hasCompleteQuestions(self: @This()) bool {
        return self.complete_questions != 0;
    }
};

pub const StateCapabilityStats = struct {
    exports: usize = 0,
    live_exports: usize = 0,
    released_exports: usize = 0,
    resolved_exports: usize = 0,
    imports: usize = 0,
    live_imports: usize = 0,
    released_imports: usize = 0,
    resolved_imports: usize = 0,
    import_references: usize = 0,

    pub fn live(self: @This()) usize {
        return self.live_exports + self.live_imports;
    }

    pub fn total(self: @This()) usize {
        return self.exports + self.imports;
    }

    pub fn hasCapabilities(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn isEmpty(self: @This()) bool {
        return self.total() == 0;
    }

    pub fn hasExports(self: @This()) bool {
        return self.exports != 0;
    }

    pub fn hasImports(self: @This()) bool {
        return self.imports != 0;
    }

    pub fn hasLive(self: @This()) bool {
        return self.live() != 0;
    }

    pub fn released(self: @This()) usize {
        return self.released_exports + self.released_imports;
    }

    pub fn hasReleased(self: @This()) bool {
        return self.released() != 0;
    }

    pub fn resolved(self: @This()) usize {
        return self.resolved_exports + self.resolved_imports;
    }

    pub fn hasResolved(self: @This()) bool {
        return self.resolved() != 0;
    }

    pub fn hasImportReferences(self: @This()) bool {
        return self.import_references != 0;
    }
};

pub const AnyPointerUsage = struct {
    max_capability_count: usize,
    capability: ?u32 = null,

    pub fn hasCapability(self: @This()) bool {
        return self.capability != null;
    }

    pub fn matchesCapability(self: @This(), index: u32) bool {
        return self.capability == index;
    }

    pub fn validate(self: @This()) Error!void {
        if (self.capability) |index| {
            if (@as(usize, index) >= self.max_capability_count) return error.InvalidTransition;
        }
    }
};

fn validateAnyPointerUsageCapability(usage: AnyPointerUsage) Error!void {
    try usage.validate();
}

pub const AcceptInfo = struct {
    question_id: QuestionId,
    has_provision: bool,
    provision_max_capability_count: usize,
    provision_capability: ?u32 = null,
    embargo: ?[]const u8,

    pub fn provisionUsage(self: @This()) ?AnyPointerUsage {
        return if (self.has_provision) .{
            .max_capability_count = self.provision_max_capability_count,
            .capability = self.provision_capability,
        } else null;
    }

    pub fn hasProvisionUsage(self: @This()) bool {
        return self.provisionUsage() != null;
    }

    pub fn provisionMatchesCapability(self: @This(), index: u32) bool {
        const usage = self.provisionUsage() orelse return false;
        return usage.matchesCapability(index);
    }

    pub fn hasEmbargo(self: @This()) bool {
        return self.embargo != null;
    }

    pub fn matchesEmbargo(self: @This(), value: []const u8) bool {
        const embargo = self.embargo orelse return false;
        return std.mem.eql(u8, embargo, value);
    }

    pub fn validate(self: @This()) Error!void {
        if (!self.has_provision and self.provision_capability != null) return error.InvalidTransition;
        if (self.has_provision and self.provision_capability == null) return error.InvalidTransition;
        if (self.provisionUsage()) |usage| try usage.validate();
    }
};

pub const ProvideInfo = struct {
    question_id: QuestionId,
    target: CallTarget,
    has_recipient: bool,
    recipient_max_capability_count: usize,
    recipient_capability: ?u32 = null,

    pub fn recipientUsage(self: @This()) ?AnyPointerUsage {
        return if (self.has_recipient) .{
            .max_capability_count = self.recipient_max_capability_count,
            .capability = self.recipient_capability,
        } else null;
    }

    pub fn hasRecipientUsage(self: @This()) bool {
        return self.recipientUsage() != null;
    }

    pub fn recipientMatchesCapability(self: @This(), index: u32) bool {
        const usage = self.recipientUsage() orelse return false;
        return usage.matchesCapability(index);
    }

    pub fn targetsImport(self: @This(), id: ImportId) bool {
        return self.target.matchesImport(id);
    }

    pub fn targetsPromisedQuestion(self: @This(), id: QuestionId) bool {
        return self.target.matchesPromisedQuestion(id);
    }

    pub fn validate(self: @This()) Error!void {
        if (!self.has_recipient and self.recipient_capability != null) return error.InvalidTransition;
        if (self.has_recipient and self.recipient_capability == null) return error.InvalidTransition;
        if (self.recipientUsage()) |usage| try usage.validate();
    }
};

pub const JoinInfo = struct {
    question_id: QuestionId,
    target: CallTarget,
    has_key_part: bool,
    key_part_max_capability_count: usize,
    key_part_capability: ?u32 = null,

    pub fn keyPartUsage(self: @This()) ?AnyPointerUsage {
        return if (self.has_key_part) .{
            .max_capability_count = self.key_part_max_capability_count,
            .capability = self.key_part_capability,
        } else null;
    }

    pub fn hasKeyPartUsage(self: @This()) bool {
        return self.keyPartUsage() != null;
    }

    pub fn keyPartMatchesCapability(self: @This(), index: u32) bool {
        const usage = self.keyPartUsage() orelse return false;
        return usage.matchesCapability(index);
    }

    pub fn targetsImport(self: @This(), id: ImportId) bool {
        return self.target.matchesImport(id);
    }

    pub fn targetsPromisedQuestion(self: @This(), id: QuestionId) bool {
        return self.target.matchesPromisedQuestion(id);
    }

    pub fn validate(self: @This()) Error!void {
        if (!self.has_key_part and self.key_part_capability != null) return error.InvalidTransition;
        if (self.has_key_part and self.key_part_capability == null) return error.InvalidTransition;
        if (self.keyPartUsage()) |usage| try usage.validate();
    }
};

pub const ThirdPartyAnswerInfo = struct {
    answer_id: AnswerId,
    has_completion: bool,
    completion: ?AnyPointerUsage = null,

    pub fn completionUsage(self: @This()) ?AnyPointerUsage {
        return if (self.has_completion) self.completion else null;
    }

    pub fn matchesAnswer(self: @This(), id: AnswerId) bool {
        return self.answer_id == id;
    }

    pub fn hasCompletionUsage(self: @This()) bool {
        return self.completionUsage() != null;
    }

    pub fn completionMatchesCapability(self: @This(), index: u32) bool {
        const usage = self.completionUsage() orelse return false;
        return usage.matchesCapability(index);
    }

    pub fn validate(self: @This()) Error!void {
        if (!self.has_completion and self.completion != null) return error.InvalidTransition;
        if (self.has_completion and (self.completion == null or self.completion.?.capability == null)) return error.InvalidTransition;
        if (self.completionUsage()) |usage| try usage.validate();
    }
};

pub const AcceptTracker = struct {
    question_id: QuestionId,
    has_provision: bool,
    provision: ?AnyPointerUsage = null,
    embargo: ?[]const u8 = null,
    embargo_released: bool = false,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        if (self.embargo) |bytes| allocator.free(bytes);
        self.* = undefined;
    }

    pub fn info(self: @This()) AcceptInfo {
        return .{
            .question_id = self.question_id,
            .has_provision = self.has_provision,
            .provision_max_capability_count = if (self.provision) |provision| provision.max_capability_count else 0,
            .provision_capability = if (self.provision) |provision| provision.capability else null,
            .embargo = self.embargo,
        };
    }

    pub fn hasProvisionUsage(self: @This()) bool {
        return self.info().hasProvisionUsage();
    }

    pub fn provisionMatchesCapability(self: @This(), index: u32) bool {
        return self.info().provisionMatchesCapability(index);
    }

    pub fn hasEmbargo(self: @This()) bool {
        return self.info().hasEmbargo();
    }

    pub fn matchesEmbargo(self: @This(), value: []const u8) bool {
        return self.info().matchesEmbargo(value);
    }

    pub fn ready(self: @This()) bool {
        return self.hasProvisionUsage() and (self.embargo == null or self.embargo_released);
    }
};

pub const JoinTracker = struct {
    question_id: QuestionId,
    target: CallTarget,
    has_key_part: bool,
    key_part: ?AnyPointerUsage = null,

    pub fn info(self: @This()) JoinInfo {
        return .{
            .question_id = self.question_id,
            .target = self.target,
            .has_key_part = self.has_key_part,
            .key_part_max_capability_count = if (self.key_part) |key_part| key_part.max_capability_count else 0,
            .key_part_capability = if (self.key_part) |key_part| key_part.capability else null,
        };
    }

    pub fn hasKeyPartUsage(self: @This()) bool {
        return self.info().hasKeyPartUsage();
    }

    pub fn keyPartMatchesCapability(self: @This(), index: u32) bool {
        return self.info().keyPartMatchesCapability(index);
    }

    pub fn targetsImport(self: @This(), id: ImportId) bool {
        return self.info().targetsImport(id);
    }

    pub fn targetsPromisedQuestion(self: @This(), id: QuestionId) bool {
        return self.info().targetsPromisedQuestion(id);
    }
};

pub const ProvideTracker = struct {
    question_id: QuestionId,
    target: CallTarget,
    has_recipient: bool,
    recipient: ?AnyPointerUsage = null,

    pub fn info(self: @This()) ProvideInfo {
        return .{
            .question_id = self.question_id,
            .target = self.target,
            .has_recipient = self.has_recipient,
            .recipient_max_capability_count = if (self.recipient) |recipient| recipient.max_capability_count else 0,
            .recipient_capability = if (self.recipient) |recipient| recipient.capability else null,
        };
    }

    pub fn hasRecipientUsage(self: @This()) bool {
        return self.info().hasRecipientUsage();
    }

    pub fn recipientMatchesCapability(self: @This(), index: u32) bool {
        return self.info().recipientMatchesCapability(index);
    }

    pub fn targetsImport(self: @This(), id: ImportId) bool {
        return self.info().targetsImport(id);
    }

    pub fn targetsPromisedQuestion(self: @This(), id: QuestionId) bool {
        return self.info().targetsPromisedQuestion(id);
    }
};

pub const CallInfo = struct {
    question_id: QuestionId,
    target: CallTarget,
    method: CallMethod,
    send_results_to: CallSendResultsTo,
    send_results_to_third_party: ?AnyPointerUsage = null,
    flags: CallFlags,

    pub fn init(question_id: QuestionId, target: CallTarget, options: CallOptions) @This() {
        return .{
            .question_id = question_id,
            .target = target,
            .method = options.method,
            .send_results_to = options.send_results_to,
            .send_results_to_third_party = options.send_results_to_third_party,
            .flags = options.flags,
        };
    }

    pub fn callMethod(self: @This()) CallMethod {
        return self.method;
    }

    pub fn matchesMethod(self: @This(), method: CallMethod) bool {
        return self.method.matches(method.interface_id, method.method_id);
    }

    pub fn matchesWireCall(self: @This(), call: anytype) bool {
        return self.callMethod().matchesWireCall(call);
    }

    pub fn matchesWireMessage(self: @This(), message: anytype) !bool {
        return self.callMethod().matchesWireMessage(message);
    }

    pub fn hasMethod(self: @This()) bool {
        return self.callOptions().hasMethod();
    }

    pub fn sendsResultsTo(self: @This(), target: CallSendResultsTo) bool {
        return self.send_results_to == target;
    }

    pub fn thirdPartyResultsUsage(self: @This()) ?AnyPointerUsage {
        return if (self.send_results_to == .third_party) self.send_results_to_third_party else null;
    }

    pub fn hasThirdPartyResultsUsage(self: @This()) bool {
        return self.thirdPartyResultsUsage() != null;
    }

    pub fn callOptions(self: @This()) CallOptions {
        return .{
            .method = self.method,
            .send_results_to = self.send_results_to,
            .send_results_to_third_party = self.thirdPartyResultsUsage(),
            .flags = self.flags,
        };
    }

    pub fn allowsThirdPartyTailCall(self: @This()) bool {
        return self.flags.allowsThirdPartyTailCall();
    }

    pub fn forbidsPromisePipelining(self: @This()) bool {
        return self.flags.forbidsPromisePipelining();
    }

    pub fn onlyAllowsPromisePipeline(self: @This()) bool {
        return self.flags.onlyAllowsPromisePipeline();
    }
};

pub const TrackedCallDispatchInfo = struct {
    info: CallInfo,
    options: CallOptions,
    resolution: ?CapDescriptor = null,
    forward_target: ?CallTarget = null,
    effective_target: CallTarget,
    transitive_forward_target: ?CallTarget = null,
    transitive_effective_target: CallTarget,

    pub fn needsForward(self: @This()) bool {
        return self.transitive_forward_target != null;
    }

    pub fn dispatchOutcome(self: @This()) WireDispatchOutcome {
        return if (self.needsForward()) .forward_required else .response_initialized;
    }

    pub fn methodEntryIndex(self: @This(), comptime entries: anytype) Error!?usize {
        return self.info.callMethod().entryIndex(entries);
    }

    pub fn serviceAction(self: @This(), comptime entries: anytype) Error!TrackedCallServiceAction {
        if (self.transitive_forward_target) |target| return .{ .forward = target };
        if (try self.methodEntryIndex(entries)) |index| return .{ .dispatch = index };
        return .unimplemented;
    }
};

pub const TrackedCallServiceAction = union(enum) {
    dispatch: usize,
    forward: CallTarget,
    unimplemented,

    pub fn isDispatch(self: @This()) bool {
        return self == .dispatch;
    }

    pub fn isForward(self: @This()) bool {
        return self == .forward;
    }

    pub fn isUnimplemented(self: @This()) bool {
        return self == .unimplemented;
    }

    pub fn needsResponse(self: @This()) bool {
        return switch (self) {
            .dispatch, .unimplemented => true,
            .forward => false,
        };
    }

    pub fn needsForward(self: @This()) bool {
        return self == .forward;
    }

    pub fn outputRole(self: @This()) TrackedCallServiceActionOutputRole {
        return switch (self) {
            .dispatch, .unimplemented => .response,
            .forward => .forward,
        };
    }
};

pub const TrackedCallServiceActionPlan = struct {
    source_index: usize,
    question_id: QuestionId,
    action: TrackedCallServiceAction,

    pub fn matchesSource(self: @This(), source_index: usize, question_id: QuestionId) bool {
        return self.source_index == source_index and self.question_id == question_id;
    }

    pub fn needsResponse(self: @This()) bool {
        return self.action.needsResponse();
    }

    pub fn needsForward(self: @This()) bool {
        return self.action.needsForward();
    }

    pub fn outputRole(self: @This()) TrackedCallServiceActionOutputRole {
        return self.action.outputRole();
    }
};

pub const TrackedCallServiceActionStats = struct {
    dispatch: usize = 0,
    forward: usize = 0,
    unimplemented: usize = 0,
    missing: usize = 0,
    skipped: usize = 0,

    pub fn record(self: *@This(), action: TrackedCallServiceAction) void {
        switch (action) {
            .dispatch => self.dispatch += 1,
            .forward => self.forward += 1,
            .unimplemented => self.unimplemented += 1,
        }
    }

    pub fn recordMissing(self: *@This()) void {
        self.missing += 1;
    }

    pub fn recordSkipped(self: *@This()) void {
        self.skipped += 1;
    }

    pub fn actions(self: @This()) usize {
        return self.dispatch + self.forward + self.unimplemented;
    }

    pub fn hasActions(self: @This()) bool {
        return self.actions() != 0;
    }

    pub fn responseMessages(self: @This()) usize {
        return self.dispatch + self.unimplemented;
    }

    pub fn hasResponses(self: @This()) bool {
        return self.responseMessages() != 0;
    }

    pub fn hasForwards(self: @This()) bool {
        return self.forward != 0;
    }

    pub fn total(self: @This()) usize {
        return self.actions() + self.missing + self.skipped;
    }

    pub fn hasGaps(self: @This()) bool {
        return self.missing != 0 or self.skipped != 0;
    }

    pub fn dispatchRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.dispatch };
    }

    pub fn forwardRange(self: @This()) OutputRange {
        const start = self.dispatch;
        return .{ .start = start, .end = start + self.forward };
    }

    pub fn unimplementedRange(self: @This()) OutputRange {
        const start = self.dispatch + self.forward;
        return .{ .start = start, .end = start + self.unimplemented };
    }

    pub fn responseRange(self: @This()) OutputRange {
        return .{ .start = 0, .end = self.responseMessages() };
    }

    pub fn outputResponseRange(self: @This()) OutputRange {
        return self.responseRange();
    }

    pub fn outputForwardRange(self: @This()) OutputRange {
        const start = self.responseMessages();
        return .{ .start = start, .end = start + self.forward };
    }

    pub fn dispatchResponseRange(self: @This()) OutputRange {
        return self.dispatchRange();
    }

    pub fn unimplementedResponseRange(self: @This()) OutputRange {
        const start = self.dispatch;
        return .{ .start = start, .end = start + self.unimplemented };
    }

    pub fn validateDispatchCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.dispatch) return error.InvalidTransition;
    }

    pub fn validateForwardCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.forward) return error.InvalidTransition;
    }

    pub fn validateUnimplementedCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.unimplemented) return error.InvalidTransition;
    }

    pub fn validateSplitCapacity(self: @This(), dispatch_capacity: usize, forward_capacity: usize, unimplemented_capacity: usize) Error!void {
        try self.validateDispatchCapacity(dispatch_capacity);
        try self.validateForwardCapacity(forward_capacity);
        try self.validateUnimplementedCapacity(unimplemented_capacity);
    }

    pub fn validateResponseCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.responseMessages()) return error.InvalidTransition;
    }

    pub fn validateOutputCapacity(self: @This(), response_capacity: usize, forward_capacity: usize) Error!void {
        try self.validateResponseCapacity(response_capacity);
        try self.validateForwardCapacity(forward_capacity);
    }

    pub fn validateOutputBuilders(self: @This(), response_messages: anytype, forward_messages: anytype) Error!void {
        try self.validateOutputCapacity(response_messages.len, forward_messages.len);
    }

    pub fn validateActionCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.actions()) return error.InvalidTransition;
    }

    pub fn unifiedOutputPosition(self: @This(), output_index: usize) ?TrackedCallServiceActionOutputPosition {
        return trackedCallServiceActionUnifiedOutputPosition(self, output_index);
    }

    pub fn responseLocalIndex(self: @This(), output_index: usize) ?usize {
        const position = self.unifiedOutputPosition(output_index) orelse return null;
        if (position.role != .response) return null;
        return position.local_index;
    }

    pub fn forwardLocalIndex(self: @This(), output_index: usize) ?usize {
        const position = self.unifiedOutputPosition(output_index) orelse return null;
        if (position.role != .forward) return null;
        return position.local_index;
    }

    pub fn outputIndex(self: @This(), position: TrackedCallServiceActionOutputPosition) ?usize {
        return switch (position.role) {
            .response => self.responseOutputIndex(position.local_index),
            .forward => self.forwardOutputIndex(position.local_index),
        };
    }

    pub fn responseOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.responseMessages()) return null;
        return local_index;
    }

    pub fn forwardOutputIndex(self: @This(), local_index: usize) ?usize {
        if (local_index >= self.forward) return null;
        return self.responseMessages() + local_index;
    }
};

pub const TrackedCallServiceActionOutputRole = enum {
    response,
    forward,
};

pub const TrackedCallServiceActionOutputPosition = struct {
    role: TrackedCallServiceActionOutputRole,
    local_index: usize,

    pub fn isResponse(self: @This()) bool {
        return self.role == .response;
    }

    pub fn isForward(self: @This()) bool {
        return self.role == .forward;
    }
};

pub fn trackedCallServiceActionUnifiedOutputPosition(stats: TrackedCallServiceActionStats, output_index: usize) ?TrackedCallServiceActionOutputPosition {
    const response_end = stats.responseMessages();
    if (output_index < response_end) return .{ .role = .response, .local_index = output_index };

    const forward_end = response_end + stats.forward;
    if (output_index < forward_end) return .{ .role = .forward, .local_index = output_index - response_end };

    return null;
}

pub fn anyPointerUsageFromWire(pointer: anytype) !AnyPointerUsage {
    const capability = pointer.getCapabilityIndex() catch |err| switch (err) {
        error.InvalidPointerKind, error.NullPointer => null,
        else => return err,
    };
    const max_capability_count = pointer.maxCapabilityCount() catch |err| switch (err) {
        error.NullPointer => 0,
        else => return err,
    };
    return .{
        .max_capability_count = max_capability_count,
        .capability = capability,
    };
}

pub const DisembargoContext = union(enum) {
    sender_loopback: u32,
    receiver_loopback: u32,
    accept: []const u8,

    pub fn isSenderLoopback(self: @This()) bool {
        return self == .sender_loopback;
    }

    pub fn isReceiverLoopback(self: @This()) bool {
        return self == .receiver_loopback;
    }

    pub fn isAccept(self: @This()) bool {
        return self == .accept;
    }

    pub fn senderLoopbackId(self: @This()) ?u32 {
        return switch (self) {
            .sender_loopback => |id| id,
            else => null,
        };
    }

    pub fn receiverLoopbackId(self: @This()) ?u32 {
        return switch (self) {
            .receiver_loopback => |id| id,
            else => null,
        };
    }

    pub fn acceptEmbargo(self: @This()) ?[]const u8 {
        return switch (self) {
            .accept => |embargo| embargo,
            else => null,
        };
    }

    pub fn matchesAcceptEmbargo(self: @This(), value: []const u8) bool {
        const embargo = self.acceptEmbargo() orelse return false;
        return std.mem.eql(u8, embargo, value);
    }
};

pub const DisembargoInfo = struct {
    target: CallTarget,
    context: DisembargoContext,

    pub fn targetsImport(self: @This(), id: ImportId) bool {
        return self.target.matchesImport(id);
    }

    pub fn targetsPromisedQuestion(self: @This(), id: QuestionId) bool {
        return self.target.matchesPromisedQuestion(id);
    }

    pub fn isAcceptEmbargo(self: @This()) bool {
        return self.context.isAccept();
    }

    pub fn matchesAcceptEmbargo(self: @This(), value: []const u8) bool {
        return self.context.matchesAcceptEmbargo(value);
    }
};

pub const DisembargoApplyInfo = struct {
    released_accepts: usize = 0,
    released_accept_ids: []const QuestionId = &.{},

    pub fn releasedAnyAccept(self: @This()) bool {
        return self.released_accepts != 0;
    }

    pub fn releasedAcceptCount(self: @This()) usize {
        return self.released_accepts;
    }

    pub fn containsReleasedAccept(self: @This(), id: QuestionId) bool {
        for (self.released_accept_ids) |released_id| {
            if (released_id == id) return true;
        }
        return false;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.released_accept_ids);
        self.* = undefined;
    }
};

pub const PendingAcceptEmbargo = struct {
    question_id: QuestionId,
    embargo: []const u8,

    pub fn matchesEmbargo(self: @This(), value: []const u8) bool {
        return std.mem.eql(u8, self.embargo, value);
    }
};

pub const PendingAcceptEmbargos = struct {
    items: []PendingAcceptEmbargo,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.items) |item| allocator.free(item.embargo);
        allocator.free(self.items);
        self.* = undefined;
    }

    pub fn len(self: @This()) usize {
        return self.items.len;
    }

    pub fn hasItems(self: @This()) bool {
        return self.items.len != 0;
    }

    pub fn containsQuestion(self: @This(), question_id: QuestionId) bool {
        for (self.items) |item| {
            if (item.question_id == question_id) return true;
        }
        return false;
    }

    pub fn embargoForQuestion(self: @This(), question_id: QuestionId) ?[]const u8 {
        for (self.items) |item| {
            if (item.question_id == question_id) return item.embargo;
        }
        return null;
    }

    pub fn containsQuestionEmbargo(self: @This(), question_id: QuestionId, embargo: []const u8) bool {
        const tracked = self.embargoForQuestion(question_id) orelse return false;
        return std.mem.eql(u8, tracked, embargo);
    }

    pub fn matchCount(self: @This(), embargo: []const u8) usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.matchesEmbargo(embargo)) count += 1;
        }
        return count;
    }

    pub fn containsEmbargo(self: @This(), embargo: []const u8) bool {
        return self.matchCount(embargo) != 0;
    }

    pub fn validateCapacity(self: @This(), capacity: usize) Error!void {
        if (capacity < self.len()) return error.InvalidTransition;
    }

    pub fn validateMatchCapacity(self: @This(), embargo: []const u8, capacity: usize) Error!void {
        if (capacity < self.matchCount(embargo)) return error.InvalidTransition;
    }

    pub fn initDisembargoMessages(self: @This(), message_builders: anytype, target: CallTarget) !usize {
        try self.validateCapacity(message_builders.len);
        var index: usize = 0;
        for (self.items) |item| {
            try initWireDisembargoMessage(message_builders[index], .{
                .target = target,
                .context = .{ .accept = item.embargo },
            });
            index += 1;
        }
        return index;
    }

    pub fn initDisembargoMessagesToQueue(self: @This(), allocator: std.mem.Allocator, message_builders: anytype, target: CallTarget, queue: anytype) !usize {
        const initialized = try self.initDisembargoMessages(message_builders, target);
        for (message_builders[0..initialized]) |message| {
            try queue.append(allocator, message);
        }
        return initialized;
    }

    pub fn initDisembargoMessagesToSink(self: @This(), message_builders: anytype, target: CallTarget, sink_context: anytype, sink_handler: anytype) !usize {
        const initialized = try self.initDisembargoMessages(message_builders, target);
        for (message_builders[0..initialized]) |message| {
            try sink_handler(sink_context, message);
        }
        return initialized;
    }

    pub fn initDisembargoMessagesForEmbargo(self: @This(), message_builders: anytype, target: CallTarget, embargo: []const u8) !usize {
        try self.validateMatchCapacity(embargo, message_builders.len);
        var index: usize = 0;
        for (self.items) |item| {
            if (item.matchesEmbargo(embargo)) {
                try initWireDisembargoMessage(message_builders[index], .{
                    .target = target,
                    .context = .{ .accept = item.embargo },
                });
                index += 1;
            }
        }
        return index;
    }

    pub fn initDisembargoMessagesForEmbargoToQueue(self: @This(), allocator: std.mem.Allocator, message_builders: anytype, target: CallTarget, embargo: []const u8, queue: anytype) !usize {
        const initialized = try self.initDisembargoMessagesForEmbargo(message_builders, target, embargo);
        for (message_builders[0..initialized]) |message| {
            try queue.append(allocator, message);
        }
        return initialized;
    }

    pub fn initDisembargoMessagesForEmbargoToSink(self: @This(), message_builders: anytype, target: CallTarget, embargo: []const u8, sink_context: anytype, sink_handler: anytype) !usize {
        const initialized = try self.initDisembargoMessagesForEmbargo(message_builders, target, embargo);
        for (message_builders[0..initialized]) |message| {
            try sink_handler(sink_context, message);
        }
        return initialized;
    }

    pub fn initDisembargoInfos(self: @This(), infos: []DisembargoInfo, target: CallTarget) Error!usize {
        try self.validateCapacity(infos.len);
        var index: usize = 0;
        for (self.items) |item| {
            infos[index] = .{
                .target = target,
                .context = .{ .accept = item.embargo },
            };
            index += 1;
        }
        return index;
    }

    pub fn appendDisembargoInfosToQueue(self: @This(), allocator: std.mem.Allocator, target: CallTarget, queue: anytype) !usize {
        for (self.items) |item| {
            try queue.append(allocator, DisembargoInfo{
                .target = target,
                .context = .{ .accept = item.embargo },
            });
        }
        return self.len();
    }

    pub fn appendDisembargoInfosToSink(self: @This(), target: CallTarget, sink_context: anytype, sink_handler: anytype) !usize {
        for (self.items) |item| {
            try sink_handler(sink_context, DisembargoInfo{
                .target = target,
                .context = .{ .accept = item.embargo },
            });
        }
        return self.len();
    }

    pub fn initDisembargoInfosForEmbargo(self: @This(), infos: []DisembargoInfo, target: CallTarget, embargo: []const u8) Error!usize {
        try self.validateMatchCapacity(embargo, infos.len);
        var index: usize = 0;
        for (self.items) |item| {
            if (item.matchesEmbargo(embargo)) {
                infos[index] = .{
                    .target = target,
                    .context = .{ .accept = item.embargo },
                };
                index += 1;
            }
        }
        return index;
    }

    pub fn appendDisembargoInfosForEmbargoToQueue(self: @This(), allocator: std.mem.Allocator, target: CallTarget, embargo: []const u8, queue: anytype) !usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.matchesEmbargo(embargo)) {
                try queue.append(allocator, DisembargoInfo{
                    .target = target,
                    .context = .{ .accept = item.embargo },
                });
                count += 1;
            }
        }
        return count;
    }

    pub fn appendDisembargoInfosForEmbargoToSink(self: @This(), target: CallTarget, embargo: []const u8, sink_context: anytype, sink_handler: anytype) !usize {
        var count: usize = 0;
        for (self.items) |item| {
            if (item.matchesEmbargo(embargo)) {
                try sink_handler(sink_context, DisembargoInfo{
                    .target = target,
                    .context = .{ .accept = item.embargo },
                });
                count += 1;
            }
        }
        return count;
    }
};

pub const WireMessageApplyResult = union(enum) {
    state_applied,
    disembargo: DisembargoApplyInfo,

    pub fn isStateApplied(self: @This()) bool {
        return self == .state_applied;
    }

    pub fn isDisembargo(self: @This()) bool {
        return self == .disembargo;
    }

    pub fn releasedAnyAccept(self: @This()) bool {
        return switch (self) {
            .disembargo => |info| info.releasedAnyAccept(),
            .state_applied => false,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .disembargo => |*info| info.deinit(allocator),
            else => {},
        }
        self.* = undefined;
    }
};

pub const WireMessageApplyStats = struct {
    state_applied: usize = 0,
    disembargos: usize = 0,
    released_accepts: usize = 0,

    pub fn record(self: *@This(), result: WireMessageApplyResult) void {
        switch (result) {
            .state_applied => self.state_applied += 1,
            .disembargo => |info| {
                self.disembargos += 1;
                self.released_accepts += info.released_accepts;
            },
        }
    }

    pub fn total(self: @This()) usize {
        return self.state_applied + self.disembargos;
    }

    pub fn hasWork(self: @This()) bool {
        return self.total() != 0;
    }

    pub fn appliedAnyState(self: @This()) bool {
        return self.state_applied != 0;
    }

    pub fn appliedAnyDisembargo(self: @This()) bool {
        return self.disembargos != 0;
    }

    pub fn releasedAnyAccept(self: @This()) bool {
        return self.released_accepts != 0;
    }
};

pub const ResolveInfo = struct {
    promise_id: ExportId,
    cap: ?CapDescriptor = null,
    exception: ?ExceptionInfo = null,

    pub fn matchesPromise(self: @This(), id: ExportId) bool {
        return self.promise_id == id;
    }

    pub fn hasCap(self: @This()) bool {
        return self.cap != null;
    }

    pub fn hasException(self: @This()) bool {
        return self.exception != null;
    }

    pub fn isBroken(self: @This()) bool {
        return self.hasException();
    }

    pub fn isForwardableToCallTarget(self: @This()) bool {
        const descriptor = self.cap orelse return false;
        return descriptor.isForwardableToCallTarget();
    }

    pub fn forwardableCallTarget(self: @This()) ?CallTarget {
        const descriptor = self.cap orelse return null;
        return descriptor.forwardableCallTarget();
    }

    pub fn validate(self: @This()) Error!void {
        if (self.hasCap() == self.hasException()) return error.InvalidTransition;
    }
};

pub const PromisedAnswerTarget = struct {
    question_id: QuestionId,

    pub fn matchesQuestion(self: @This(), id: QuestionId) bool {
        return self.question_id == id;
    }
};

pub const PromisedAnswerOp = union(enum) {
    noop,
    get_pointer_field: u16,

    pub fn isNoop(self: @This()) bool {
        return self == .noop;
    }

    pub fn isGetPointerField(self: @This()) bool {
        return self == .get_pointer_field;
    }

    pub fn pointerFieldIndex(self: @This()) ?u16 {
        return switch (self) {
            .get_pointer_field => |index| index,
            .noop => null,
        };
    }
};

pub const PromisedAnswerTargetOwned = struct {
    question_id: QuestionId,
    transform: []PromisedAnswerOp,

    pub fn matchesQuestion(self: @This(), id: QuestionId) bool {
        return self.question_id == id;
    }

    pub fn transformLen(self: @This()) usize {
        return self.transform.len;
    }

    pub fn hasTransform(self: @This()) bool {
        return self.transform.len != 0;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.transform);
        self.* = undefined;
    }
};

/// A Call target: imported capability or promised answer.
pub const CallTarget = union(enum) {
    imported_cap: ImportId,
    promised_answer: PromisedAnswerTarget,

    pub fn isImportedCap(self: CallTarget) bool {
        return self == .imported_cap;
    }

    pub fn isPromisedAnswer(self: CallTarget) bool {
        return self == .promised_answer;
    }

    pub fn importId(self: CallTarget) ?ImportId {
        return switch (self) {
            .imported_cap => |id| id,
            else => null,
        };
    }

    pub fn matchesImport(self: CallTarget, id: ImportId) bool {
        return self.importId() == id;
    }

    pub fn promisedQuestionId(self: CallTarget) ?QuestionId {
        return switch (self) {
            .promised_answer => |answer| answer.question_id,
            else => null,
        };
    }

    pub fn matchesPromisedQuestion(self: CallTarget, id: QuestionId) bool {
        return self.promisedQuestionId() == id;
    }
};

pub const CallTargetOwned = union(enum) {
    imported_cap: ImportId,
    promised_answer: PromisedAnswerTargetOwned,

    pub fn isImportedCap(self: @This()) bool {
        return self == .imported_cap;
    }

    pub fn isPromisedAnswer(self: @This()) bool {
        return self == .promised_answer;
    }

    pub fn importId(self: @This()) ?ImportId {
        return switch (self) {
            .imported_cap => |id| id,
            else => null,
        };
    }

    pub fn matchesImport(self: @This(), id: ImportId) bool {
        return self.importId() == id;
    }

    pub fn promisedQuestionId(self: @This()) ?QuestionId {
        return switch (self) {
            .promised_answer => |answer| answer.question_id,
            else => null,
        };
    }

    pub fn matchesPromisedQuestion(self: @This(), id: QuestionId) bool {
        return self.promisedQuestionId() == id;
    }

    pub fn asCallTarget(self: @This()) CallTarget {
        return switch (self) {
            .imported_cap => |id| .{ .imported_cap = id },
            .promised_answer => |answer| .{ .promised_answer = .{ .question_id = answer.question_id } },
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .promised_answer => |*answer| answer.deinit(allocator),
            else => {},
        }
        self.* = undefined;
    }
};

pub const CallSendResultsTo = enum {
    caller,
    yourself,
    third_party,

    pub fn isCaller(self: @This()) bool {
        return self == .caller;
    }

    pub fn isYourself(self: @This()) bool {
        return self == .yourself;
    }

    pub fn isThirdParty(self: @This()) bool {
        return self == .third_party;
    }
};

pub const CallFlags = struct {
    allow_third_party_tail_call: bool = false,
    no_promise_pipelining: bool = false,
    only_promise_pipeline: bool = false,

    pub fn isDefault(self: @This()) bool {
        return !self.allow_third_party_tail_call and !self.no_promise_pipelining and !self.only_promise_pipeline;
    }

    pub fn withAllowThirdPartyTailCall(self: @This(), enabled: bool) @This() {
        var flags = self;
        flags.allow_third_party_tail_call = enabled;
        return flags;
    }

    pub fn withNoPromisePipelining(self: @This(), enabled: bool) @This() {
        var flags = self;
        flags.no_promise_pipelining = enabled;
        return flags;
    }

    pub fn withOnlyPromisePipeline(self: @This(), enabled: bool) @This() {
        var flags = self;
        flags.only_promise_pipeline = enabled;
        return flags;
    }

    pub fn allowsThirdPartyTailCall(self: @This()) bool {
        return self.allow_third_party_tail_call;
    }

    pub fn forbidsPromisePipelining(self: @This()) bool {
        return self.no_promise_pipelining;
    }

    pub fn onlyAllowsPromisePipeline(self: @This()) bool {
        return self.only_promise_pipeline;
    }
};

/// An interface/method identifier pair.
pub const CallMethod = struct {
    interface_id: u64 = 0,
    method_id: u16 = 0,

    pub fn isDefault(self: @This()) bool {
        return self.interface_id == 0 and self.method_id == 0;
    }

    pub fn matches(self: @This(), interface_id: u64, method_id: u16) bool {
        return self.interface_id == interface_id and self.method_id == method_id;
    }

    pub fn matchesCallMethod(self: @This(), method: CallMethod) bool {
        return self.matches(method.interface_id, method.method_id);
    }

    pub fn matchesWireCall(self: @This(), call: anytype) bool {
        return self.matchesCallMethod(callMethodFromWireCall(call));
    }

    pub fn matchesWireMessage(self: @This(), message: anytype) !bool {
        const method = (try callMethodFromWireMessage(message)) orelse return false;
        return self.matchesCallMethod(method);
    }

    pub fn callOptions(self: @This()) CallOptions {
        return .{ .method = self };
    }

    pub fn methodEntry(self: @This(), handler: anytype) CallMethodEntry(@TypeOf(handler)) {
        return .{ .method = self, .handler = handler };
    }

    pub fn entryIndex(self: @This(), comptime entries: anytype) Error!?usize {
        return callMethodEntryIndex(self, entries);
    }
};

/// A method-table entry pairing a `CallMethod` with a handler.
pub fn CallMethodEntry(comptime Handler: type) type {
    return struct {
        method: CallMethod,
        handler: Handler,

        pub fn callMethod(self: @This()) CallMethod {
            return self.method;
        }

        pub fn matches(self: @This(), interface_id: u64, method_id: u16) bool {
            return self.method.matches(interface_id, method_id);
        }

        pub fn matchesCallMethod(self: @This(), method: CallMethod) bool {
            return self.method.matchesCallMethod(method);
        }

        pub fn matchesWireCall(self: @This(), call: anytype) bool {
            return self.method.matchesWireCall(call);
        }

        pub fn matchesWireMessage(self: @This(), message: anytype) !bool {
            return self.method.matchesWireMessage(message);
        }

        pub fn callOptions(self: @This()) CallOptions {
            return self.method.callOptions();
        }

        pub fn callInfo(self: @This(), question_id: QuestionId, target: CallTarget) CallInfo {
            return self.callOptions().callInfo(question_id, target);
        }

        pub fn entryIndex(self: @This(), comptime entries: anytype) Error!?usize {
            return self.method.entryIndex(entries);
        }
    };
}

/// Method ID, result routing, and call flags decoded from a Call.
pub const CallOptions = struct {
    method: CallMethod = .{},
    send_results_to: CallSendResultsTo = .caller,
    send_results_to_third_party: ?AnyPointerUsage = null,
    flags: CallFlags = .{},

    pub fn withMethod(self: @This(), method: CallMethod) @This() {
        var options = self;
        options.method = method;
        return options;
    }

    pub fn withSendResultsTo(self: @This(), target: CallSendResultsTo) @This() {
        var options = self;
        options.send_results_to = target;
        if (target != .third_party) options.send_results_to_third_party = null;
        return options;
    }

    pub fn withThirdPartyResults(self: @This(), usage: AnyPointerUsage) @This() {
        var options = self;
        options.send_results_to = .third_party;
        options.send_results_to_third_party = usage;
        return options;
    }

    pub fn withFlags(self: @This(), flags: CallFlags) @This() {
        var options = self;
        options.flags = flags;
        return options;
    }

    pub fn withAllowThirdPartyTailCall(self: @This(), enabled: bool) @This() {
        var options = self;
        options.flags = options.flags.withAllowThirdPartyTailCall(enabled);
        return options;
    }

    pub fn withNoPromisePipelining(self: @This(), enabled: bool) @This() {
        var options = self;
        options.flags = options.flags.withNoPromisePipelining(enabled);
        return options;
    }

    pub fn withOnlyPromisePipeline(self: @This(), enabled: bool) @This() {
        var options = self;
        options.flags = options.flags.withOnlyPromisePipeline(enabled);
        return options;
    }

    pub fn validate(self: @This()) Error!void {
        if (self.send_results_to_third_party != null and self.send_results_to != .third_party) return error.InvalidTransition;
        if (self.send_results_to_third_party) |usage| try validateAnyPointerUsageCapability(usage);
    }

    pub fn isDefault(self: @This()) bool {
        return self.method.isDefault() and self.send_results_to == .caller and self.send_results_to_third_party == null and self.flags.isDefault();
    }

    pub fn hasMethod(self: @This()) bool {
        return !self.method.isDefault();
    }

    pub fn callMethod(self: @This()) CallMethod {
        return self.method;
    }

    pub fn matchesMethod(self: @This(), method: CallMethod) bool {
        return self.method.matches(method.interface_id, method.method_id);
    }

    pub fn matchesWireCall(self: @This(), call: anytype) bool {
        return self.method.matchesWireCall(call);
    }

    pub fn matchesWireMessage(self: @This(), message: anytype) !bool {
        return self.method.matchesWireMessage(message);
    }

    pub fn methodEntry(self: @This(), handler: anytype) CallMethodEntry(@TypeOf(handler)) {
        return self.method.methodEntry(handler);
    }

    pub fn callInfo(self: @This(), question_id: QuestionId, target: CallTarget) CallInfo {
        return CallInfo.init(question_id, target, self);
    }

    pub fn entryIndex(self: @This(), comptime entries: anytype) Error!?usize {
        return self.method.entryIndex(entries);
    }

    pub fn sendsResultsTo(self: @This(), target: CallSendResultsTo) bool {
        return self.send_results_to == target;
    }

    pub fn thirdPartyResultsUsage(self: @This()) ?AnyPointerUsage {
        return if (self.send_results_to == .third_party) self.send_results_to_third_party else null;
    }

    pub fn hasThirdPartyResultsUsage(self: @This()) bool {
        return self.thirdPartyResultsUsage() != null;
    }

    pub fn allowsThirdPartyTailCall(self: @This()) bool {
        return self.flags.allowsThirdPartyTailCall();
    }

    pub fn forbidsPromisePipelining(self: @This()) bool {
        return self.flags.forbidsPromisePipelining();
    }

    pub fn onlyAllowsPromisePipeline(self: @This()) bool {
        return self.flags.onlyAllowsPromisePipeline();
    }
};

/// A capability descriptor used by payload cap tables.
pub const CapDescriptor = union(enum) {
    none,
    sender_hosted: ExportId,
    sender_promise: ExportId,
    receiver_hosted: ImportId,
    receiver_answer: PromisedAnswerTarget,
    third_party_hosted: ExportId,

    pub fn isNone(self: @This()) bool {
        return self == .none;
    }

    pub fn isSenderHosted(self: @This()) bool {
        return self == .sender_hosted;
    }

    pub fn isSenderPromise(self: @This()) bool {
        return self == .sender_promise;
    }

    pub fn isReceiverHosted(self: @This()) bool {
        return self == .receiver_hosted;
    }

    pub fn isReceiverAnswer(self: @This()) bool {
        return self == .receiver_answer;
    }

    pub fn isThirdPartyHosted(self: @This()) bool {
        return self == .third_party_hosted;
    }

    pub fn exportedId(self: @This()) ?ExportId {
        return switch (self) {
            .sender_hosted, .sender_promise, .third_party_hosted => |id| id,
            else => null,
        };
    }

    pub fn importedId(self: @This()) ?ImportId {
        return switch (self) {
            .receiver_hosted => |id| id,
            else => null,
        };
    }

    pub fn promisedAnswer(self: @This()) ?PromisedAnswerTarget {
        return switch (self) {
            .receiver_answer => |answer| answer,
            else => null,
        };
    }

    pub fn isForwardableToCallTarget(self: @This()) bool {
        return switch (self) {
            .sender_hosted, .sender_promise, .receiver_answer, .third_party_hosted => true,
            .none, .receiver_hosted => false,
        };
    }

    pub fn forwardableCallTarget(self: @This()) ?CallTarget {
        return switch (self) {
            .sender_hosted, .sender_promise, .third_party_hosted => |id| .{ .imported_cap = id },
            .receiver_answer => |answer| .{ .promised_answer = answer },
            .none, .receiver_hosted => null,
        };
    }
};

pub const CapDescriptorInfo = struct {
    pub const no_attached_fd: u8 = 0xff;

    descriptor: CapDescriptor,
    attached_fd: u8 = no_attached_fd,
    third_party_contact: ?AnyPointerUsage = null,

    pub fn hasAttachedFd(self: @This()) bool {
        return self.attached_fd != no_attached_fd;
    }

    pub fn attachedFd(self: @This()) ?u8 {
        return if (self.hasAttachedFd()) self.attached_fd else null;
    }

    pub fn thirdPartyContactUsage(self: @This()) ?AnyPointerUsage {
        return if (self.descriptor == .third_party_hosted) self.third_party_contact else null;
    }

    pub fn hasThirdPartyContactUsage(self: @This()) bool {
        return self.thirdPartyContactUsage() != null;
    }

    pub fn thirdPartyContactMatchesCapability(self: @This(), index: u32) bool {
        const contact = self.thirdPartyContactUsage() orelse return false;
        return contact.matchesCapability(index);
    }

    pub fn isForwardableToCallTarget(self: @This()) bool {
        return self.descriptor.isForwardableToCallTarget();
    }

    pub fn forwardableCallTarget(self: @This()) ?CallTarget {
        return self.descriptor.forwardableCallTarget();
    }

    pub fn validate(self: @This()) Error!void {
        if (self.third_party_contact != null and self.descriptor != .third_party_hosted) return error.InvalidTransition;
        if (self.thirdPartyContactUsage()) |contact| try contact.validate();
    }
};

pub fn callTargetFromForwardableCapDescriptor(descriptor: CapDescriptor) ?CallTarget {
    return descriptor.forwardableCallTarget();
}

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

pub fn wireMessageTag(message: anytype) !WireMessageTag {
    return std.enums.fromInt(WireMessageTag, message.whichDiscriminant()) orelse error.InvalidTransition;
}

/// A decoded top-level RPC message event.
pub const WireEvent = union(WireMessageTag) {
    unimplemented: WireMessageTag,
    abort: ExceptionInfo,
    bootstrap: QuestionId,
    call: QuestionId,
    return_: Return,
    finish: Finish,
    resolve: ExportId,
    release: CapabilityRelease,
    disembargo: DisembargoInfo,
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
            .bootstrap, .call, .return_, .finish, .resolve, .disembargo, .provide, .accept, .third_party_answer, .join => true,
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

    pub fn isAbort(self: WireEvent) bool {
        return self == .abort;
    }

    pub fn isObsolete(self: WireEvent) bool {
        return self == .obsolete_save or self == .obsolete_delete;
    }

    pub fn isObsoleteSave(self: WireEvent) bool {
        return self == .obsolete_save;
    }

    pub fn isObsoleteDelete(self: WireEvent) bool {
        return self == .obsolete_delete;
    }

    pub fn isUnimplemented(self: WireEvent) bool {
        return self == .unimplemented;
    }

    pub fn unimplementedOriginalTag(self: WireEvent) ?WireMessageTag {
        return switch (self) {
            .unimplemented => |original_tag| original_tag,
            else => null,
        };
    }

    pub fn isUnimplementedOf(self: WireEvent, original_tag: WireMessageTag) bool {
        return self.unimplementedOriginalTag() == original_tag;
    }

    pub fn abortException(self: WireEvent) ?ExceptionInfo {
        return switch (self) {
            .abort => |exception| exception,
            else => null,
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

    pub fn isQuestionOpening(self: Event) bool {
        return self.kind().isQuestionOpening();
    }

    pub fn isQuestionClosing(self: Event) bool {
        return self.kind().isQuestionClosing();
    }

    pub fn isAnswerResolving(self: Event) bool {
        return self.kind().isAnswerResolving();
    }

    pub fn isCapabilityTableMutation(self: Event) bool {
        return self.kind().isCapabilityTableMutation();
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

    pub fn isIdle(self: @This()) bool {
        return self == .idle;
    }

    pub fn isOpen(self: @This()) bool {
        return self == .open;
    }

    pub fn isFinished(self: @This()) bool {
        return self == .finished;
    }

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

    pub fn isUnresolved(self: @This()) bool {
        return self == .unresolved;
    }

    pub fn isResolved(self: @This()) bool {
        return self == .resolved;
    }

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

    pub fn isReleased(self: CapabilityLifetime) bool {
        return self == .released;
    }
};

pub const QuestionTracker = struct {
    id: QuestionId,
    state: QuestionState = .idle,
    kind: ?MessageKind = null,

    pub fn open(self: *QuestionTracker, kind: MessageKind) Error!void {
        if (!kind.isQuestionOpening()) return error.InvalidTransition;
        if (self.state != .idle) return error.QuestionAlreadyOpen;
        self.state = .open;
        self.kind = kind;
    }

    pub fn finish(self: *QuestionTracker) Error!void {
        if (self.state != .open) return error.QuestionNotOpen;
        self.state = .finished;
    }

    pub fn canSend(self: QuestionTracker, kind: MessageKind) bool {
        return self.state.canSend(kind);
    }

    pub fn isIdle(self: QuestionTracker) bool {
        return self.state.isIdle();
    }

    pub fn isOpen(self: QuestionTracker) bool {
        return self.state.isOpen();
    }

    pub fn isFinished(self: QuestionTracker) bool {
        return self.state.isFinished();
    }
};

pub const AnswerTracker = struct {
    id: AnswerId,
    state: AnswerState = .unresolved,
    kind: ?MessageKind = null,

    pub fn resolve(self: *AnswerTracker, kind: MessageKind) Error!void {
        if (!kind.isAnswerResolving()) return error.InvalidTransition;
        if (!self.state.canResolve()) return error.AnswerAlreadyResolved;
        self.state = .resolved;
        self.kind = kind;
    }

    pub fn isUnresolved(self: AnswerTracker) bool {
        return self.state.isUnresolved();
    }

    pub fn isResolved(self: AnswerTracker) bool {
        return self.state.isResolved();
    }
};

/// A small import/export lifetime tracker keyed by ID.
pub fn CapabilityTracker(comptime Id: type, comptime already_released_error: Error) type {
    return struct {
        id: Id,
        state: CapabilityLifetime = .live,
        reference_count: u32 = 1,
        resolved: bool = false,
        resolution: ?CapDescriptor = null,

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
            try self.resolveTo(null);
        }

        pub fn resolveTo(self: *@This(), resolution: ?CapDescriptor) Error!void {
            if (self.state != .live) return error.InvalidTransition;
            if (self.resolved) return error.InvalidTransition;
            self.resolved = true;
            self.resolution = resolution;
        }

        pub fn isLive(self: @This()) bool {
            return self.state.isLive();
        }

        pub fn isReleased(self: @This()) bool {
            return self.state.isReleased();
        }

        pub fn isResolved(self: @This()) bool {
            return self.resolved;
        }

        pub fn hasResolution(self: @This()) bool {
            return self.resolution != null;
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

pub fn writeCallTargetToWire(target: CallTarget, builder: anytype) !void {
    switch (target) {
        .imported_cap => |id| try builder.set_importedCap(id),
        .promised_answer => |answer| {
            const promised_answer = try builder.init_promisedAnswer();
            try promised_answer.set_questionId(answer.question_id);
        },
    }
}

pub fn writeCallTargetOwnedToWire(target: CallTargetOwned, builder: anytype) !void {
    switch (target) {
        .imported_cap => |id| try builder.set_importedCap(id),
        .promised_answer => |answer| {
            const promised_answer = try builder.init_promisedAnswer();
            try promised_answer.set_questionId(answer.question_id);
            try initWirePromisedAnswerTransform(promised_answer, answer.transform);
        },
    }
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

pub fn callTargetFromWireMessage(message: anytype) !?CallTarget {
    return switch (try wireMessageTag(message)) {
        .call => try callTargetFromWireCall(try message.call()),
        else => null,
    };
}

pub fn callTargetFromWireMessageAlloc(allocator: std.mem.Allocator, message: anytype) !?CallTargetOwned {
    return switch (try wireMessageTag(message)) {
        .call => try callTargetFromWireCallAlloc(allocator, try message.call()),
        else => null,
    };
}

pub fn callMethodFromWireCall(call: anytype) CallMethod {
    return .{
        .interface_id = call.interfaceId(),
        .method_id = call.methodId(),
    };
}

pub fn writeCallMethodToWire(method: CallMethod, call: anytype) !void {
    try call.set_interfaceId(method.interface_id);
    try call.set_methodId(method.method_id);
}

pub fn sendResultsToFromWireCall(call: anytype) !CallSendResultsTo {
    return switch (call.which() orelse return error.InvalidTransition) {
        .sendResultsTo_caller => .caller,
        .sendResultsTo_yourself => .yourself,
        .sendResultsTo_thirdParty => .third_party,
    };
}

pub fn writeSendResultsToToWire(value: CallSendResultsTo, call: anytype) !void {
    switch (value) {
        .caller => try call.set_sendResultsTo_caller(),
        .yourself => try call.set_sendResultsTo_yourself(),
        .third_party => try call.clear_sendResultsTo_thirdParty(),
    }
}

pub fn sendResultsToThirdPartyUsageFromWireCall(call: anytype) !?AnyPointerUsage {
    if ((try sendResultsToFromWireCall(call)) != .third_party) return null;
    return try anyPointerUsageFromWire(try call.sendResultsTo_thirdParty());
}

pub fn writeSendResultsToThirdPartyToWire(call: anytype, usage: AnyPointerUsage) !void {
    try validateAnyPointerUsageCapability(usage);
    try call.clear_sendResultsTo_thirdParty();
    if (usage.capability) |index| {
        (try call.get_sendResultsTo_thirdPartyAsPointer()).setCapability(index);
    }
}

pub fn callFlagsFromWireCall(call: anytype) CallFlags {
    return .{
        .allow_third_party_tail_call = call.allowThirdPartyTailCall(),
        .no_promise_pipelining = call.noPromisePipelining(),
        .only_promise_pipeline = call.onlyPromisePipeline(),
    };
}

pub fn writeCallFlagsToWire(flags: CallFlags, call: anytype) !void {
    try call.set_allowThirdPartyTailCall(flags.allow_third_party_tail_call);
    try call.set_noPromisePipelining(flags.no_promise_pipelining);
    try call.set_onlyPromisePipeline(flags.only_promise_pipeline);
}

pub fn callOptionsFromWireCall(call: anytype) !CallOptions {
    const options: CallOptions = .{
        .method = callMethodFromWireCall(call),
        .send_results_to = try sendResultsToFromWireCall(call),
        .send_results_to_third_party = try sendResultsToThirdPartyUsageFromWireCall(call),
        .flags = callFlagsFromWireCall(call),
    };
    try options.validate();
    return options;
}

pub fn callInfoFromWireCall(call: anytype) !CallInfo {
    const options = try callOptionsFromWireCall(call);
    return options.callInfo(call.questionId(), try callTargetFromWireCall(call));
}

pub fn writeCallOptionsToWire(options: CallOptions, call: anytype) !void {
    try options.validate();
    try writeCallMethodToWire(options.method, call);
    if (options.send_results_to_third_party) |usage|
        try writeSendResultsToThirdPartyToWire(call, usage)
    else
        try writeSendResultsToToWire(options.send_results_to, call);
    try writeCallFlagsToWire(options.flags, call);
}

pub fn callMethodFromWireMessage(message: anytype) !?CallMethod {
    return switch (try wireMessageTag(message)) {
        .call => callMethodFromWireCall(try message.call()),
        else => null,
    };
}

pub fn callOptionsFromWireMessage(message: anytype) !?CallOptions {
    return switch (try wireMessageTag(message)) {
        .call => try callOptionsFromWireCall(try message.call()),
        else => null,
    };
}

pub fn callInfoFromWireMessage(message: anytype) !?CallInfo {
    return switch (try wireMessageTag(message)) {
        .call => try callInfoFromWireCall(try message.call()),
        else => null,
    };
}

pub fn acceptInfoFromWireAccept(accept: anytype) !AcceptInfo {
    const has_provision = accept.has_provision();
    const provision_usage = if (has_provision)
        try anyPointerUsageFromWire(try accept.provisionAsPointer())
    else
        AnyPointerUsage{ .max_capability_count = 0 };
    return .{
        .question_id = accept.questionId(),
        .has_provision = has_provision,
        .provision_max_capability_count = provision_usage.max_capability_count,
        .provision_capability = provision_usage.capability,
        .embargo = try accept.embargoOrNull(),
    };
}

pub fn writeAcceptInfoToWire(info: AcceptInfo, accept: anytype) !void {
    try info.validate();
    try accept.set_questionId(info.question_id);
    if (info.provision_capability) |index| {
        (try accept.get_provisionAsPointer()).setCapability(index);
    }
    try accept.set_embargoOrNull(info.embargo);
}

pub fn initWireAcceptMessage(message: anytype, info: AcceptInfo) !void {
    try writeAcceptInfoToWire(info, try message.init_accept());
}

pub fn provideInfoFromWireProvide(provide: anytype) !ProvideInfo {
    const has_recipient = provide.has_recipient();
    const recipient_capability: ?u32 = if (has_recipient)
        (try provide.recipientAsPointer()).getCapabilityIndex() catch |err| switch (err) {
            error.InvalidPointerKind => null,
            else => return err,
        }
    else
        null;
    return .{
        .question_id = provide.questionId(),
        .target = try targetFromWireTargetedMessage(provide),
        .has_recipient = has_recipient,
        .recipient_max_capability_count = if (has_recipient) try provide.recipientMaxCapabilityCount() else 0,
        .recipient_capability = recipient_capability,
    };
}

pub fn writeProvideInfoToWire(info: ProvideInfo, provide: anytype) !void {
    try info.validate();
    try provide.set_questionId(info.question_id);
    try writeCallTargetToWire(info.target, try provide.init_target());
    if (info.recipient_capability) |index| {
        (try provide.get_recipientAsPointer()).setCapability(index);
    }
}

pub fn initWireProvideMessage(message: anytype, info: ProvideInfo) !void {
    try writeProvideInfoToWire(info, try message.init_provide());
}

pub fn joinInfoFromWireJoin(join: anytype) !JoinInfo {
    const has_key_part = join.has_keyPart();
    const key_part_capability: ?u32 = if (has_key_part)
        (try join.keyPartAsPointer()).getCapabilityIndex() catch |err| switch (err) {
            error.InvalidPointerKind => null,
            else => return err,
        }
    else
        null;
    return .{
        .question_id = join.questionId(),
        .target = try targetFromWireTargetedMessage(join),
        .has_key_part = has_key_part,
        .key_part_max_capability_count = if (has_key_part) try join.keyPartMaxCapabilityCount() else 0,
        .key_part_capability = key_part_capability,
    };
}

pub fn writeJoinInfoToWire(info: JoinInfo, join: anytype) !void {
    try info.validate();
    try join.set_questionId(info.question_id);
    try writeCallTargetToWire(info.target, try join.init_target());
    if (info.key_part_capability) |index| {
        (try join.get_keyPartAsPointer()).setCapability(index);
    }
}

pub fn initWireJoinMessage(message: anytype, info: JoinInfo) !void {
    try writeJoinInfoToWire(info, try message.init_join());
}

pub fn thirdPartyAnswerInfoFromWireThirdPartyAnswer(third_party_answer: anytype) !ThirdPartyAnswerInfo {
    const has_completion = third_party_answer.has_completion();
    return .{
        .answer_id = third_party_answer.answerId(),
        .has_completion = has_completion,
        .completion = if (has_completion) try anyPointerUsageFromWire(try third_party_answer.completionAsPointer()) else null,
    };
}

pub fn writeThirdPartyAnswerInfoToWire(info: ThirdPartyAnswerInfo, third_party_answer: anytype) !void {
    try info.validate();
    try third_party_answer.set_answerId(info.answer_id);
    if (info.completion) |completion| {
        if (completion.capability) |index| {
            (try third_party_answer.get_completionAsPointer()).setCapability(index);
        }
    }
}

pub fn initWireThirdPartyAnswerMessage(message: anytype, info: ThirdPartyAnswerInfo) !void {
    try writeThirdPartyAnswerInfoToWire(info, try message.init_thirdPartyAnswer());
}

pub fn disembargoInfoFromWireDisembargo(disembargo: anytype) !DisembargoInfo {
    const target = try targetFromWireTargetedMessage(disembargo);
    const context: DisembargoContext = switch (disembargo.which() orelse return error.InvalidTransition) {
        .senderLoopback => .{ .sender_loopback = try disembargo.senderLoopback() },
        .receiverLoopback => .{ .receiver_loopback = try disembargo.receiverLoopback() },
        .accept => .{ .accept = (try disembargo.acceptOrNull()) orelse "" },
    };
    return .{ .target = target, .context = context };
}

pub fn writeDisembargoInfoToWire(info: DisembargoInfo, disembargo: anytype) !void {
    try writeCallTargetToWire(info.target, try disembargo.init_target());
    switch (info.context) {
        .sender_loopback => |id| try disembargo.set_senderLoopback(id),
        .receiver_loopback => |id| try disembargo.set_receiverLoopback(id),
        .accept => |embargo| try disembargo.set_accept(embargo),
    }
}

pub fn initWireDisembargoMessage(message: anytype, info: DisembargoInfo) !void {
    try writeDisembargoInfoToWire(info, try message.init_disembargo());
}

pub fn initWireDisembargoMessages(message_builders: anytype, infos: []const DisembargoInfo) !usize {
    if (message_builders.len < infos.len) return error.InvalidTransition;
    for (infos, 0..) |info, index| {
        try initWireDisembargoMessage(message_builders[index], info);
    }
    return infos.len;
}

pub fn initWireDisembargoMessagesToSink(
    message_builders: anytype,
    infos: []const DisembargoInfo,
    sink_context: anytype,
    sink_handler: anytype,
) !usize {
    if (message_builders.len < infos.len) return error.InvalidTransition;
    for (infos, 0..) |info, index| {
        try initWireDisembargoMessage(message_builders[index], info);
        try sink_handler(sink_context, message_builders[index]);
    }
    return infos.len;
}

pub fn initWireDisembargoMessagesToQueue(
    allocator: std.mem.Allocator,
    message_builders: anytype,
    infos: []const DisembargoInfo,
    queue: anytype,
) !usize {
    if (message_builders.len < infos.len) return error.InvalidTransition;
    for (infos, 0..) |info, index| {
        try initWireDisembargoMessage(message_builders[index], info);
        try queue.append(allocator, message_builders[index]);
    }
    return infos.len;
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
        .thirdPartyHosted => .{ .third_party_hosted = (try descriptor.thirdPartyHosted()).vineId() },
    };
}

pub fn capDescriptorInfoFromWire(descriptor: anytype) !CapDescriptorInfo {
    const decoded = try capDescriptorFromWire(descriptor);
    const third_party_contact: ?AnyPointerUsage = switch (decoded) {
        .third_party_hosted => blk: {
            const third_party = try descriptor.thirdPartyHosted();
            break :blk if (third_party.has_id()) try anyPointerUsageFromWire(try third_party.idAsPointer()) else null;
        },
        else => null,
    };
    return .{
        .descriptor = decoded,
        .attached_fd = descriptor.attachedFd(),
        .third_party_contact = third_party_contact,
    };
}

pub fn capDescriptorsFromInfosAlloc(allocator: std.mem.Allocator, infos: []const CapDescriptorInfo) std.mem.Allocator.Error![]CapDescriptor {
    const descriptors = try allocator.alloc(CapDescriptor, infos.len);
    for (infos, 0..) |info, index| {
        descriptors[index] = info.descriptor;
    }
    return descriptors;
}

pub fn resolveInfoFromWireResolve(resolve: anytype) !ResolveInfo {
    return switch (resolve.which() orelse return error.InvalidTransition) {
        .cap => .{
            .promise_id = resolve.promiseId(),
            .cap = try capDescriptorFromWire(try resolve.cap()),
        },
        .exception => .{
            .promise_id = resolve.promiseId(),
            .exception = try exceptionInfoFromWireException(try resolve.exception()),
        },
    };
}

pub fn writeResolveInfoToWire(info: ResolveInfo, resolve: anytype) !void {
    try info.validate();
    try resolve.set_promiseId(info.promise_id);
    if (info.cap) |descriptor| {
        try writeCapDescriptorToWire(descriptor, try resolve.init_cap());
        return;
    }
    if (info.exception) |exception| {
        try writeExceptionInfoToWire(exception, try resolve.init_exception());
        return;
    }
}

pub fn initWireResolveMessage(message: anytype, info: ResolveInfo) !void {
    try writeResolveInfoToWire(info, try message.init_resolve());
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
        .third_party_hosted => |vine_id| {
            const third_party = try builder.init_thirdPartyHosted();
            try third_party.set_vineId(vine_id);
        },
    }
}

pub fn writeCapDescriptorInfoToWire(info: CapDescriptorInfo, builder: anytype) !void {
    try info.validate();
    try writeCapDescriptorToWire(info.descriptor, builder);
    if (info.third_party_contact) |contact| {
        if (contact.capability) |index| {
            (try (try builder.get_thirdPartyHosted()).get_idAsPointer()).setCapability(index);
        }
    }
    try builder.set_attachedFd(info.attached_fd);
}

pub fn initWirePayloadCapTable(payload: anytype, descriptors: []const CapDescriptor) !void {
    const cap_table = try payload.init_capTable(descriptors.len);
    for (descriptors, 0..) |descriptor, index| {
        try writeCapDescriptorToWire(descriptor, try cap_table.get(index));
    }
}

pub fn initWirePayloadCapTableInfo(payload: anytype, infos: []const CapDescriptorInfo) !void {
    const cap_table = try payload.init_capTable(infos.len);
    for (infos, 0..) |info, index| {
        try writeCapDescriptorInfoToWire(info, try cap_table.get(index));
    }
}

pub fn initWirePayloadCapability(payload: anytype, capability_index: u32, descriptors: []const CapDescriptor) !void {
    (try payload.get_contentAsPointer()).setCapability(capability_index);
    try initWirePayloadCapTable(payload, descriptors);
}

pub fn initWirePayloadCapabilityInfo(payload: anytype, capability_index: u32, infos: []const CapDescriptorInfo) !void {
    (try payload.get_contentAsPointer()).setCapability(capability_index);
    try initWirePayloadCapTableInfo(payload, infos);
}

pub fn initWirePayloadCapabilityFromRegistry(allocator: std.mem.Allocator, payload: anytype, capability_index: u32, registry: anytype) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWirePayloadCapability(payload, capability_index, descriptors);
}

pub fn initWirePayloadStructWith(
    payload: anytype,
    struct_size: anytype,
    descriptors: []const CapDescriptor,
    context: anytype,
    fill: anytype,
) !void {
    const content = try (try payload.get_contentAsPointer()).initStruct(struct_size);
    try fill(context, content);
    try initWirePayloadCapTable(payload, descriptors);
}

pub fn initWirePayloadStructInfoWith(
    payload: anytype,
    struct_size: anytype,
    infos: []const CapDescriptorInfo,
    context: anytype,
    fill: anytype,
) !void {
    const content = try (try payload.get_contentAsPointer()).initStruct(struct_size);
    try fill(context, content);
    try initWirePayloadCapTableInfo(payload, infos);
}

pub fn initWirePayloadStructFromRegistry(
    allocator: std.mem.Allocator,
    payload: anytype,
    struct_size: anytype,
    registry: anytype,
    context: anytype,
    fill: anytype,
) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWirePayloadStructWith(payload, struct_size, descriptors, context, fill);
}

pub fn initWirePayloadText(payload: anytype, text: []const u8, descriptors: []const CapDescriptor) !void {
    try (try payload.get_contentAsPointer()).setText(text);
    try initWirePayloadCapTable(payload, descriptors);
}

pub fn initWirePayloadData(payload: anytype, data: []const u8, descriptors: []const CapDescriptor) !void {
    try (try payload.get_contentAsPointer()).setData(data);
    try initWirePayloadCapTable(payload, descriptors);
}

pub fn initWirePayloadTextInfo(payload: anytype, text: []const u8, infos: []const CapDescriptorInfo) !void {
    try (try payload.get_contentAsPointer()).setText(text);
    try initWirePayloadCapTableInfo(payload, infos);
}

pub fn initWirePayloadDataInfo(payload: anytype, data: []const u8, infos: []const CapDescriptorInfo) !void {
    try (try payload.get_contentAsPointer()).setData(data);
    try initWirePayloadCapTableInfo(payload, infos);
}

pub fn initWirePayloadTextFromRegistry(allocator: std.mem.Allocator, payload: anytype, text: []const u8, registry: anytype) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWirePayloadText(payload, text, descriptors);
}

pub fn initWirePayloadDataFromRegistry(allocator: std.mem.Allocator, payload: anytype, data: []const u8, registry: anytype) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWirePayloadData(payload, data, descriptors);
}

pub fn initWirePayloadUInt32List(payload: anytype, values: []const u32, descriptors: []const CapDescriptor) !void {
    // Primitive list payloads cannot contain embedded capabilities, but they
    // still travel with the same cap-table envelope as struct/text/data
    // payloads.  Keeping construction in one helper prevents callers from
    // accidentally omitting descriptor metadata while moving away from the
    // capability-only payload path.
    const list = try (try payload.get_contentAsPointer()).initList(.four_bytes, values.len);
    for (values, 0..) |value, index| {
        try list.setUInt32(index, value);
    }
    try initWirePayloadCapTable(payload, descriptors);
}

pub fn initWirePayloadUInt32ListInfo(payload: anytype, values: []const u32, infos: []const CapDescriptorInfo) !void {
    const list = try (try payload.get_contentAsPointer()).initList(.four_bytes, values.len);
    for (values, 0..) |value, index| {
        try list.setUInt32(index, value);
    }
    try initWirePayloadCapTableInfo(payload, infos);
}

pub fn initWirePayloadUInt32ListFromRegistry(allocator: std.mem.Allocator, payload: anytype, values: []const u32, registry: anytype) !void {
    const descriptors = try senderHostedDescriptorsFromRegistryAlloc(allocator, registry);
    defer allocator.free(descriptors);
    try initWirePayloadUInt32List(payload, values, descriptors);
}

pub fn senderHostedDescriptorsFromRegistryAlloc(allocator: std.mem.Allocator, registry: anytype) ![]CapDescriptor {
    const descriptors = try allocator.alloc(CapDescriptor, registry.len());
    errdefer allocator.free(descriptors);
    for (descriptors, 0..) |*descriptor, index| {
        const export_id = std.math.cast(u32, index) orelse return error.InvalidTransition;
        descriptor.* = .{ .sender_hosted = export_id };
    }
    return descriptors;
}

pub fn initForwardedWireCall(call: anytype, source_call: anytype, target: CallTarget) !void {
    // Preserve the original call payload, method id, routing flags, and question
    // id exactly; forwarding should only rewrite the destination capability.
    // A later transport loop can then serialize this builder without asking the
    // application handler to reinterpret or rebuild params.
    try call.copyFrom(source_call);
    try writeCallTargetToWire(target, try call.init_target());
}

pub fn initForwardedWireCallMessage(message: anytype, source_call: anytype, target: CallTarget) !void {
    try initForwardedWireCall(try message.init_call(), source_call, target);
}

pub fn initForwardedWireCallMessagesFromServiceActionPlans(calls: anytype, plans: []const TrackedCallServiceActionPlan, forward_messages: anytype) !usize {
    var forward_count: usize = 0;
    for (plans) |plan| {
        switch (plan.action) {
            .forward => |target| {
                if (plan.source_index >= calls.len) return error.InvalidTransition;
                if (plan.question_id != calls[plan.source_index].questionId()) return error.InvalidTransition;
                if (forward_count >= forward_messages.len) return error.InvalidTransition;
                try initForwardedWireCallMessage(forward_messages[forward_count], calls[plan.source_index], target);
                forward_count += 1;
            },
            .dispatch, .unimplemented => {},
        }
    }
    return forward_count;
}

pub fn initUnimplementedReturnMessagesFromServiceActionPlans(calls: anytype, plans: []const TrackedCallServiceActionPlan, response_messages: anytype) !usize {
    var response_count: usize = 0;
    for (plans) |plan| {
        switch (plan.action) {
            .unimplemented => {
                if (plan.source_index >= calls.len) return error.InvalidTransition;
                if (plan.question_id != calls[plan.source_index].questionId()) return error.InvalidTransition;
                if (response_count >= response_messages.len) return error.InvalidTransition;
                try initWireReturnException(try response_messages[response_count].init_return_(), calls[plan.source_index].questionId(), true, false, .{
                    .reason = "unimplemented method",
                    .type_raw = 3,
                });
                response_count += 1;
            },
            .dispatch, .forward => {},
        }
    }
    return response_count;
}

pub fn validateCallMethodEntries(comptime entries: anytype) Error!void {
    inline for (entries, 0..) |entry, index| {
        inline for (entries, 0..) |other, other_index| {
            if (other_index > index and entry.method.matches(other.method.interface_id, other.method.method_id)) {
                return error.InvalidTransition;
            }
        }
    }
}

pub fn callMethodEntryIndex(method: CallMethod, comptime entries: anytype) Error!?usize {
    try validateCallMethodEntries(entries);
    inline for (entries, 0..) |entry, index| {
        if (method.matches(entry.method.interface_id, entry.method.method_id)) return index;
    }
    return null;
}

pub fn exceptionInfoFromWireException(exception: anytype) !ExceptionInfo {
    return .{
        .reason = try exception.reasonOrNull(),
        .type_raw = exception.type__raw(),
        .trace = try exception.traceOrNull(),
    };
}

pub fn writeExceptionInfoToWire(info: ExceptionInfo, exception: anytype) !void {
    try exception.set_reason(info.reason orelse "");
    try exception.set_type__raw(info.type_raw);
    try exception.set_traceOrNull(info.trace);
}

pub fn initWireReturnException(
    return_: anytype,
    answer_id: AnswerId,
    release_param_caps: bool,
    no_finish_needed: bool,
    exception: ExceptionInfo,
) !void {
    try return_.set_answerId(answer_id);
    try return_.set_releaseParamCaps(release_param_caps);
    try return_.set_noFinishNeeded(no_finish_needed);
    const wire_exception = try return_.init_exception();
    try writeExceptionInfoToWire(exception, wire_exception);
}
